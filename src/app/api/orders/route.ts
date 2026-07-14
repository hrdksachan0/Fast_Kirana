import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { OrderStatus, PaymentStatus, PaymentMethod, Role } from '@prisma/client'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { apiWriteLimiter, apiReadLimiter } from '@/lib/rate-limit'
import { revalidateStorefront } from '@/lib/revalidate'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '@/lib/distance'

export async function POST(request: NextRequest) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  const session = await auth()
  const userId = session?.user?.id
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { addressId, paymentMethod, items, couponCode, deliveryMethod = 'DELIVERY', isB2B = false, scheduledSlot = 'INSTANT', shopName = null, shopPhone = null, storeId = null } = await request.json()

    if (!paymentMethod || !items || items.length === 0) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (deliveryMethod !== 'PICKUP' && !addressId) {
      return NextResponse.json({ error: 'Delivery address is required' }, { status: 400 })
    }

    // Fetch contact phone from settings for the STORE_PICKUP address
    const contactSetting = await prisma.storeSetting.findUnique({
      where: { key: 'contact_phone' }
    })
    const defaultSupportPhone = contactSetting?.value || '+917054470303'

    // 1. Resolve address
    let finalAddressId = addressId
    if (deliveryMethod === 'PICKUP') {
      const addressSetting = await prisma.storeSetting.findUnique({
        where: { key: 'contact_address' }
      })
      const defaultPickupAddress = addressSetting?.value || 'Vikas Medical Store, NH34, Ghatampur, Kanpur Nagar, Kanpur, 209206'
      const addrParts = defaultPickupAddress.split(',').map(p => p.trim())
      const houseNo = addrParts[0] || 'Vikas Medical Store'
      const street = addrParts[1] || 'NH34, Ghatampur'
      const area = addrParts[2] || 'Kanpur Nagar'
      const city = addrParts[3] || 'Kanpur'
      const pincode = addrParts[4] || '209206'

      let pickupAddress = await prisma.address.findFirst({
        where: { userId, label: 'STORE_PICKUP' }
      })
      if (!pickupAddress) {
        pickupAddress = await prisma.address.create({
          data: {
            userId,
            label: 'STORE_PICKUP',
            houseNo,
            street,
            area,
            city,
            pincode,
            phone: defaultSupportPhone,
          }
        })
      } else {
        pickupAddress = await prisma.address.update({
          where: { id: pickupAddress.id },
          data: {
            houseNo,
            street,
            area,
            city,
            pincode,
            phone: defaultSupportPhone,
          }
        })
      }
      finalAddressId = pickupAddress.id
    }

    const address = await prisma.address.findUnique({
      where: { id: finalAddressId, userId: userId },
    })

    if (!address) {
      return NextResponse.json({ error: 'Selected address is invalid' }, { status: 400 })
    }

    // Distance-based delivery validation
    let deliveryRules: ReturnType<typeof getDeliveryRules> | null = null

    if (deliveryMethod === 'DELIVERY') {
      const p = address.pincode.trim()
      const c = address.city.trim().toLowerCase()
      if (p !== '209206') {
        return NextResponse.json({ error: 'Selected address is outside our delivery zone. Pincode must be 209206.' }, { status: 400 })
      }
      if (!c.includes('ghatampur') && !c.includes('kanpur')) {
        return NextResponse.json({ error: 'Selected address city is outside our delivery zone.' }, { status: 400 })
      }

      // Calculate distance if address has GPS coordinates
      if (address.lat && address.lng) {
        // Fetch store coordinates from settings (will be fetched below with other settings)
        const storeLatSetting = await prisma.storeSetting.findUnique({ where: { key: 'store_lat' } })
        const storeLngSetting = await prisma.storeSetting.findUnique({ where: { key: 'store_lng' } })
        const storeLat = storeLatSetting?.value ? parseFloat(storeLatSetting.value) : DEFAULT_STORE_LAT
        const storeLng = storeLngSetting?.value ? parseFloat(storeLngSetting.value) : DEFAULT_STORE_LNG

        const distanceKm = getDistanceKm(storeLat, storeLng, address.lat, address.lng)
        deliveryRules = getDeliveryRules(distanceKm)

        if (!deliveryRules.isServiceable) {
          return NextResponse.json({
            error: `Your address is ${distanceKm.toFixed(1)} km away. We deliver only within 4 km of our store.`
          }, { status: 400 })
        }
      }
    }

    // Fetch store settings for dynamic tax, miscellaneous fee, and store status
    const storeSettings = await prisma.storeSetting.findMany()
    const settingsMap = storeSettings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    function getStoreStatus(prefix: 'grocery' | 'cafe'): boolean {
      const autoTiming = settingsMap[`${prefix}_auto_timing`] === 'true'
      if (!autoTiming) {
        return settingsMap[prefix === 'grocery' ? 'grocery_mart_open' : 'cafe_open'] !== 'false'
      }

      const openTime = settingsMap[`${prefix}_open_time`] || '06:00'
      const closeTime = settingsMap[`${prefix}_close_time`] || '23:59'

      const now = new Date()
      const utcTime = now.getTime() + (now.getTimezoneOffset() * 60000)
      const istTime = new Date(utcTime + (3600000 * 5.5))
      const currentTotal = istTime.getHours() * 60 + istTime.getMinutes()

      const [openH, openM] = openTime.split(':').map(Number)
      const openTotal = openH * 60 + openM

      const [closeH, closeM] = closeTime.split(':').map(Number)
      const closeTotal = closeH * 60 + closeM

      if (closeTotal >= openTotal) {
        return currentTotal >= openTotal && currentTotal <= closeTotal
      } else {
        return currentTotal >= openTotal || currentTotal <= closeTotal
      }
    }

    const groceryMartOpen = getStoreStatus('grocery')
    const cafeOpen = getStoreStatus('cafe')

    // 2. Fetch products and calculate server-side subtotal (secure against client tampering)
    const productIds = items.map((i: any) => i.product.id.split('_')[0])
    const productSlugs = items.map((i: any) => i.product.slug).filter(Boolean)

    const dbProducts = await prisma.product.findMany({
      where: {
        OR: [
          { id: { in: productIds } },
          { slug: { in: productSlugs } }
        ]
      },
      include: {
        category: true
      }
    })

    // Define helper to check if a product is a Cafe/Restaurant product
    const isCafeProduct = (p: any) => {
      if (!p) return false
      const slug = p.category?.slug
      if (slug === 'cafe' || slug === 'restaurant') return true
      if (p.tags?.includes('cafe') || p.tags?.includes('restaurant')) return true
      return false
    }

    const cafeItems: any[] = []
    const groceryItems: any[] = []

    for (const item of items) {
      const isVariant = item.product.id.includes('_')
      const [productId, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]

      let dbProduct = dbProducts.find((p) => p.id === productId)
      if (!dbProduct && item.product.slug) {
        dbProduct = dbProducts.find((p) => p.slug === item.product.slug)
      }

      if (!dbProduct || !dbProduct.isAvailable) {
        return NextResponse.json({ error: `Product "${item.product.name}" is no longer available` }, { status: 400 })
      }

      let dbStock = dbProduct.stock
      if (isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          dbStock = variant.stock
        }
      }

      if (dbStock < item.quantity) {
        return NextResponse.json({ error: `Insufficient stock for product "${dbProduct.name} ${variantName ? `(${variantName})` : ''}"` }, { status: 400 })
      }

      const limit = isCafeProduct(dbProduct) ? 10 : 5
      if (item.quantity > limit) {
        return NextResponse.json({ error: `Maximum order limit of ${limit} units exceeded for product "${dbProduct.name} ${variantName ? `(${variantName})` : ''}"` }, { status: 400 })
      }

      const itemWithDb = {
        ...item,
        dbProduct
      }

      if (isCafeProduct(dbProduct)) {
        cafeItems.push(itemWithDb)
      } else {
        groceryItems.push(itemWithDb)
      }
    }

    if (groceryItems.length > 0 && !groceryMartOpen) {
      return NextResponse.json({ error: 'Grocery Mart is temporarily closed.' }, { status: 400 })
    }
    if (cafeItems.length > 0 && !cafeOpen) {
      return NextResponse.json({ error: 'FastKirana Cafe is temporarily closed.' }, { status: 400 })
    }

    const combinedSubtotal = items.reduce((sum: number, item: any) => {
      const isVariant = item.product.id.includes('_')
      const [productId, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]

      let dbProduct = dbProducts.find((p) => p.id === productId)
      if (!dbProduct && item.product.slug) {
        dbProduct = dbProducts.find((p) => p.slug === item.product.slug)
      }

      let itemPrice = dbProduct ? dbProduct.price : 0
      if (dbProduct && isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          itemPrice = variant.price
        }
      }

      return sum + itemPrice * item.quantity
    }, 0)

    // 3. Resolve Coupon Discount
    let combinedDiscount = 0
    let couponId = null

    if (couponCode) {
      const coupon = await prisma.coupon.findUnique({
        where: { code: couponCode.toUpperCase(), isActive: true },
      })

      if (coupon) {
        const hasExpired = coupon.expiresAt && new Date(coupon.expiresAt) < new Date()
        const limitReached = coupon.maxUses && coupon.usedCount >= coupon.maxUses

        if (!hasExpired && !limitReached) {
          // Check once per customer restriction
          let canUse = true
          if (coupon.oncePerCustomer) {
            const alreadyUsed = await prisma.order.findFirst({
              where: {
                userId: userId,
                couponCode: coupon.code,
                status: { not: 'CANCELLED' }
              }
            })
            if (alreadyUsed) {
              canUse = false
            }
          }

          if (canUse) {
            let eligibleSubtotal = combinedSubtotal
            let meetsMinOrder = true

            if (coupon.categoryId) {
              // Calculate category-specific subtotal
              const categoryItems = items.filter((item: any) => {
                const dbProduct = dbProducts.find((p) => p.id === item.product.id.split('_')[0])
                return dbProduct && dbProduct.categoryId === coupon.categoryId
              })
              const categorySubtotal = categoryItems.reduce((sum: number, item: any) => {
                const dbProduct = dbProducts.find((p) => p.id === item.product.id.split('_')[0])
                let itemPrice = dbProduct ? dbProduct.price : 0
                const isVariant = item.product.id.includes('_')
                if (dbProduct && isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
                  const [_, variantName] = item.product.id.split('_')
                  const variant = (dbProduct.variants as any[]).find((v) => v.name === variantName)
                  if (variant) {
                    itemPrice = variant.price
                  }
                }
                return sum + itemPrice * item.quantity
              }, 0)

              if (categorySubtotal === 0 || categorySubtotal < coupon.minOrder) {
                meetsMinOrder = false
              }
              eligibleSubtotal = categorySubtotal
            } else {
              if (combinedSubtotal < coupon.minOrder) {
                meetsMinOrder = false
              }
            }

            if (meetsMinOrder) {
              couponId = coupon.id
              if (coupon.discountType === 'FLAT') {
                combinedDiscount = Math.min(coupon.value, eligibleSubtotal)
              } else if (coupon.discountType === 'PERCENT') {
                combinedDiscount = (eligibleSubtotal * coupon.value) / 100
                if (coupon.maxDiscount) {
                  combinedDiscount = Math.min(combinedDiscount, coupon.maxDiscount)
                }
              }
            }
          }
        }
      }
    }

    // Reuse settingsMap from the beginning of POST handler for tax and miscellaneous fee calculations

    const taxPercent = parseFloat(settingsMap['tax_rate'] || '5')
    const serverTaxRate = taxPercent / 100
    const serverMiscFee = parseFloat(settingsMap['misc_fee'] || '0')

    // Calculate details for each order to create
    const ordersToCreate: any[] = []

    // Calculate subtotals first
    const grocerySubtotal = groceryItems.reduce((sum, item) => {
      const isVariant = item.product.id.includes('_')
      const [_, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]
      let itemPrice = item.dbProduct.price
      if (isVariant && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
        const variant = (item.dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          itemPrice = variant.price
        }
      }
      return sum + itemPrice * item.quantity
    }, 0)

    const cafeSubtotal = cafeItems.reduce((sum, item) => {
      const isVariant = item.product.id.includes('_')
      const [_, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]
      let itemPrice = item.dbProduct.price
      if (isVariant && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
        const variant = (item.dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          itemPrice = variant.price
        }
      }
      return sum + itemPrice * item.quantity
    }, 0)

    const deliveryFeeVal = settingsMap['delivery_fee'] ? parseFloat(settingsMap['delivery_fee']) : DELIVERY_FEE

    let groceryDeliveryFee = 0
    let cafeDeliveryFee = 0

    if (deliveryMethod === 'DELIVERY' && !isB2B) {
      if (deliveryRules && !deliveryRules.isServiceable) {
        return NextResponse.json({
          error: `Selected address is outside our delivery zone (${deliveryRules.distanceKm.toFixed(1)} km away). We deliver only up to 4 km.`
        }, { status: 400 })
      }

      const freeDeliveryThreshold = (deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : 200
      const appliesDeliveryFee = combinedSubtotal < freeDeliveryThreshold

      if (appliesDeliveryFee) {
        const feeToCharge = (deliveryRules && deliveryRules.isServiceable) ? deliveryRules.deliveryFee : deliveryFeeVal
        if (groceryItems.length > 0) {
          groceryDeliveryFee = feeToCharge
        } else if (cafeItems.length > 0) {
          cafeDeliveryFee = feeToCharge
        }
      }
    }

    if (groceryItems.length > 0) {
      const groceryDiscount = combinedSubtotal > 0 ? (grocerySubtotal / combinedSubtotal) * combinedDiscount : 0
      const groceryTaxes = (grocerySubtotal - groceryDiscount) * serverTaxRate
      const groceryTotal = grocerySubtotal - groceryDiscount + groceryDeliveryFee + groceryTaxes + serverMiscFee

      ordersToCreate.push({
        type: 'GROCERY',
        subtotal: grocerySubtotal,
        discount: groceryDiscount,
        deliveryFee: groceryDeliveryFee,
        taxes: groceryTaxes,
        miscFee: serverMiscFee,
        total: groceryTotal,
        items: groceryItems,
      })
    }

    if (cafeItems.length > 0) {
      const cafeDiscount = combinedSubtotal > 0 ? (cafeSubtotal / combinedSubtotal) * combinedDiscount : 0
      const cafeTaxes = (cafeSubtotal - cafeDiscount) * serverTaxRate
      const groceryChargedMisc = groceryItems.length > 0
      const appliedMiscFee = groceryChargedMisc ? 0 : serverMiscFee
      const cafeTotal = cafeSubtotal - cafeDiscount + cafeDeliveryFee + cafeTaxes + appliedMiscFee

      ordersToCreate.push({
        type: 'CAFE',
        subtotal: cafeSubtotal,
        discount: cafeDiscount,
        deliveryFee: cafeDeliveryFee,
        taxes: cafeTaxes,
        miscFee: appliedMiscFee,
        total: cafeTotal,
        items: cafeItems,
      })
    }

    // 5. Build payment settings
    // All orders start as PENDING payment status on creation; online payments are marked PAID upon gateway callback.
    const paymentStatus = PaymentStatus.PENDING


    // 6. Create orders inside a Prisma Transaction
    const createdOrders = await prisma.$transaction(async (tx) => {
      const results: any[] = []
      const now = new Date()
      const isCombined = ordersToCreate.length > 1
      const combinedId = isCombined ? `combined_${Math.random().toString(36).substring(2, 11)}_${Date.now().toString(36)}` : null


      for (const orderInfo of ordersToCreate) {
        const orderItemsData = orderInfo.items.map((item: any) => {
          const isVariant = item.product.id.includes('_')
          const [_, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]
          
          let itemPrice = item.dbProduct.price
          let itemCostPrice = item.dbProduct.costPrice || 0
          if (isVariant && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
            const variant = (item.dbProduct.variants as any[]).find((v) => v.name === variantName)
            if (variant) {
              itemPrice = variant.price
              if (variant.costPrice !== undefined) {
                itemCostPrice = parseFloat(variant.costPrice) || 0
              }
            }
          }

          return {
            productId: item.dbProduct.id,
            name: item.product.name,
            price: itemPrice,
            quantity: item.quantity,
            imageUrl: item.dbProduct.imageUrl,
            selectedVariant: variantName,
            costPrice: itemCostPrice,
            variants: item.dbProduct.variants || null,
            notes: item.notes || null,
          }
        })

        // Calculate estimated delivery time for this order (30 mins for Cafe, 10 mins for Grocery)
        let estimatedDelivery = new Date(Date.now() + (orderInfo.type === 'CAFE' ? 30 : 10) * 60 * 1000)

        if (scheduledSlot && scheduledSlot !== 'INSTANT') {
          let startHour = 0
          if (scheduledSlot.includes('07:00 AM')) {
            startHour = 7
          } else if (scheduledSlot.includes('12:00 PM')) {
            startHour = 12
          } else if (scheduledSlot.includes('06:00 PM')) {
            startHour = 18
          }

          if (startHour > 0) {
            estimatedDelivery = new Date(now)
            estimatedDelivery.setHours(startHour, 0, 0, 0)
            if (estimatedDelivery.getTime() < now.getTime()) {
              estimatedDelivery.setDate(estimatedDelivery.getDate() + 1)
            }
          }
        }

        // Create order
        const newOrder = await tx.order.create({
          data: {
            userId: userId,
            addressId: finalAddressId,
            combinedId: combinedId,
            status: OrderStatus.PENDING,

            subtotal: orderInfo.subtotal,
            discount: orderInfo.discount,
            deliveryFee: orderInfo.deliveryFee,
            taxes: orderInfo.taxes,
            miscFee: orderInfo.miscFee || 0,
            total: orderInfo.total,
            paymentMethod: paymentMethod as PaymentMethod,
            paymentStatus,
            estimatedDelivery,
            deliveryMethod,
            isB2B,
            storeId,
            couponCode: couponCode ? couponCode.toUpperCase() : null,
            shopName: orderInfo.type === 'CAFE' ? 'FastKirana Cafe Kitchen' : shopName,
            shopPhone: orderInfo.type === 'CAFE' ? (settingsMap['contact_phone'] || '+91 70544 70303') : shopPhone,
            deliveryLat: address.lat,
            deliveryLng: address.lng,
            items: {
              create: orderItemsData.map((item: any) => ({
                productId: item.productId,
                name: item.name,
                price: item.price,
                quantity: item.quantity,
                imageUrl: item.imageUrl,
                selectedVariant: item.selectedVariant,
                costPrice: item.costPrice,
                variants: item.variants,
                notes: item.notes,
              })),
            },
          },
          include: {
            items: true,
            address: true,
            user: true,
          },
        })

        results.push(newOrder)

        // Deduct stock
        for (const item of orderItemsData) {
          if (item.selectedVariant) {
            // Deduct stock from the variant in JSON variants
            const dbProd = await tx.product.findUnique({
              where: { id: item.productId }
            })
            if (dbProd && dbProd.variants && Array.isArray(dbProd.variants)) {
              const updatedVariants = (dbProd.variants as any[]).map((v) => {
                if (v.name === item.selectedVariant) {
                  return { ...v, stock: Math.max(0, v.stock - item.quantity) }
                }
                return v
              })
              const newTotalStock = updatedVariants.reduce((sum, v) => sum + v.stock, 0)
              
              await tx.product.update({
                where: { id: item.productId },
                data: {
                  variants: updatedVariants,
                  stock: newTotalStock,
                }
              })
            }
          } else {
            const batches = await tx.productBatch.findMany({
              where: {
                productId: item.productId,
                quantity: { gt: 0 }
              },
              orderBy: {
                expiryDate: 'asc'
              }
            })

            let remainingToDeduct = item.quantity

            if (batches.length > 0) {
              for (const batch of batches) {
                if (remainingToDeduct <= 0) break
                const deductFromThisBatch = Math.min(batch.quantity, remainingToDeduct)
                await tx.productBatch.update({
                  where: { id: batch.id },
                  data: { quantity: { decrement: deductFromThisBatch } }
                })
                remainingToDeduct -= deductFromThisBatch
              }
            }

            const activeBatches = await tx.productBatch.findMany({
              where: {
                productId: item.productId,
                quantity: { gt: 0 }
              },
              orderBy: { expiryDate: 'asc' }
            })

            const newTotalStock = activeBatches.reduce((sum, b) => sum + b.quantity, 0)
            const newEarliestExpiry = activeBatches.length > 0 ? activeBatches[0].expiryDate : null

            if (activeBatches.length > 0 || batches.length > 0) {
              await tx.product.update({
                where: { id: item.productId },
                data: {
                  stock: newTotalStock,
                  expiryDate: newEarliestExpiry
                }
              })
            } else {
              await tx.product.update({
                where: { id: item.productId },
                data: { stock: { decrement: item.quantity } }
              })
            }
          }
        }
      }

      // Update coupon usage
      if (couponId) {
        await tx.coupon.update({
          where: { id: couponId },
          data: {
            usedCount: {
              increment: 1,
            },
          },
        })
      }

      return results
    }, { timeout: 20000 })

    // Invalidate storefront caches on-demand since stock levels changed
    try {
      const uniqueCategorySlugs = new Set(
        dbProducts.map((p) => p.category?.slug).filter(Boolean)
      )
      // Revalidate main pages
      revalidateStorefront()
      // Revalidate affected categories
      for (const catSlug of uniqueCategorySlugs) {
        revalidateStorefront(catSlug)
      }
    } catch (revalErr) {
      console.error('Failed to revalidate paths after order placement:', revalErr)
    }

    // Emit real-time SSE event for each newly created order and send push notifications to staff roles
    try {
      // Build admin phones list to notify based on settings
      const adminPhones: string[] = []
      const notifyPhone1 = settingsMap['whatsapp_notify_7054470303'] !== 'false'
      const notifyPhone2 = settingsMap['whatsapp_notify_8112849854'] !== 'false'

      if (notifyPhone1) {
        adminPhones.push('7054470303')
      }
      if (notifyPhone2) {
        adminPhones.push('8112849854')
      }

      for (const order of createdOrders) {
        const shortId = order.id.slice(-6).toUpperCase()
        const orderType = order.shopName === 'FastKirana Cafe Kitchen' ? 'Cafe' : 'Grocery'

        sseEmitter.emit('order', {
          type: 'new-order',
          orderId: order.id,
          shopName: order.shopName,
          status: order.status,
          total: order.total,
          createdAt: order.createdAt,
        })

        // Send push notifications to all workers for any new order
        sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
          title: order.shopName === 'FastKirana Cafe Kitchen' ? 'New Cafe Order ☕' : 'New Grocery Order 📦',
          body: `Order #${shortId} of ₹${order.total} has been placed.`,
          tag: `order-${order.id}`,
          data: { orderId: order.id }
        }).catch((err: any) => console.error('Error sending push notification to workers:', err))

        const whatsappPromises: Promise<any>[] = []

        // 1. WhatsApp Alert to Customer (DISABLED per request)
        /*
        const customerPhone = order.address?.phone
        if (customerPhone) {
          const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
          const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
          const customerText = `Order #${shortId} of ₹${order.total} placed successfully. Track: ${cleanAppUrl}/order/${order.id}/track`
          whatsappPromises.push(
            sendWhatsAppOrderAlert(customerPhone, customerText)
              .catch((err: any) => console.error('Failed to send customer WhatsApp order alert:', err))
          )
        }
        */

        // 2. WhatsApp Alert to Admins/Staff
        if (adminPhones.length > 0) {
          const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
          const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
          const customerName = order.user?.name || 'Customer'
          const customerPhone = order.address?.phone || 'N/A'
          const adminText = `New ${orderType} Order #${shortId} of ₹${order.total} from ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`
          
          for (const adminPhone of adminPhones) {
            whatsappPromises.push(
              sendWhatsAppOrderAlert(adminPhone, adminText)
                .catch((err: any) => console.error(`Failed to send admin (${adminPhone}) WhatsApp order alert:`, err))
            )
          }
        }

        // Wait for all WhatsApp notifications to finish before continuing
        if (whatsappPromises.length > 0) {
          await Promise.allSettled(whatsappPromises)
        }
      }
    } catch (sseErr) {
      console.error('Failed to emit SSE/notifications for new orders:', sseErr)
    }

    const mainOrder = createdOrders.find((o) => o.shopName !== 'FastKirana Cafe Kitchen') || createdOrders[0]
    return NextResponse.json(mainOrder)
  } catch (error: any) {
    console.error('Order creation error:', error)
    return NextResponse.json({ error: error.message || 'Failed to place order' }, { status: 500 })
  }
}

export async function GET(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  const session = await auth()
  const userId = session?.user?.id
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { searchParams } = new URL(request.url)
    const all = searchParams.get('all') === 'true'
    const isAdmin = session.user?.role === 'ADMIN'

    let orders: any[] = []

    if (isAdmin && all) {
      // Admin queries all orders with associated customer details
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
               u.name as "userName", u.email as "userEmail"
        FROM orders o
        LEFT JOIN users u ON o."userId" = u.id
        ORDER BY o."createdAt" DESC
        LIMIT 5000
      `
    } else {
      // Normal user only queries their own orders
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
               o."combinedId"
        FROM orders o WHERE o."userId" = ${userId}
        ORDER BY o."createdAt" DESC
      `
    }

    // Fetch items and addresses for all orders
    const orderIds = orders.map(o => o.id)
    const allItems = orderIds.length > 0
      ? await prisma.orderItem.findMany({ where: { orderId: { in: orderIds } } })
      : []
    const addressIds = [...new Set(orders.map(o => o.addressId))]
    const allAddresses = addressIds.length > 0
      ? await prisma.address.findMany({ where: { id: { in: addressIds } } })
      : []

    const result = orders.map(o => ({
      ...o,
      userName: o.userName || undefined,
      userEmail: o.userEmail || undefined,
      items: allItems.filter(item => item.orderId === o.id),
      address: allAddresses.find(a => a.id === o.addressId),
    }))

    if (isAdmin && all) {
      return NextResponse.json(result)
    }

    function getCombinedStatus(statuses: string[]): string {
      const active = statuses.filter(s => s !== 'CANCELLED')
      if (active.length === 0) return 'CANCELLED'
      if (active.includes('PENDING')) return 'PENDING'
      if (active.includes('CONFIRMED')) return 'CONFIRMED'
      if (active.includes('PACKED')) return 'PACKED'
      if (active.includes('SHIPPED')) return 'SHIPPED'
      return 'DELIVERED'
    }

    // Customer grouping
    const groupedResult: any[] = []
    const combinedGroups = new Map<string, any[]>()

    result.forEach((order: any) => {
      if (order.combinedId) {
        if (!combinedGroups.has(order.combinedId)) {
          combinedGroups.set(order.combinedId, [])
        }
        combinedGroups.get(order.combinedId)!.push(order)
      } else {
        groupedResult.push(order)
      }
    })

    combinedGroups.forEach((groupOrders, combinedId) => {
      const mainOrder = groupOrders.find(o => o.shopName !== 'FastKirana Cafe Kitchen') || groupOrders[0]
      const statuses = groupOrders.map(o => o.status)
      const combinedStatus = getCombinedStatus(statuses)

      const subOrders = groupOrders.map(o => ({
        id: o.id,
        type: o.shopName === 'FastKirana Cafe Kitchen' ? 'CAFE' : 'GROCERY',
        status: o.status,
        total: o.total,
        itemsCount: o.items?.length || 0
      }))

      const mergedOrder = {
        ...mainOrder,
        id: mainOrder.id,
        status: combinedStatus,
        subtotal: groupOrders.reduce((sum, o) => sum + (o.subtotal || 0), 0),
        discount: groupOrders.reduce((sum, o) => sum + (o.discount || 0), 0),
        deliveryFee: groupOrders.reduce((sum, o) => sum + (o.deliveryFee || 0), 0),
        taxes: groupOrders.reduce((sum, o) => sum + (o.taxes || 0), 0),
        miscFee: groupOrders.reduce((sum, o) => sum + (o.miscFee || 0), 0),
        total: groupOrders.reduce((sum, o) => sum + (o.total || 0), 0),
        items: groupOrders.flatMap(o => o.items || []),
        isCombined: true,
        subOrders
      }
      groupedResult.push(mergedOrder)
    })

    groupedResult.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())

    return NextResponse.json(groupedResult)
  } catch (error) {
    console.error('Orders list API error:', error)
    return NextResponse.json({ error: 'Failed to fetch orders' }, { status: 500 })
  }
}

