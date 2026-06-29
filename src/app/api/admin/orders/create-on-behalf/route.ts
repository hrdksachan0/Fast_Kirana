import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { OrderStatus, PaymentStatus, PaymentMethod, Role } from '@prisma/client'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { revalidateStorefront } from '@/lib/revalidate'
import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '@/lib/distance'

export async function POST(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const {
      customerId,
      addressId,
      paymentMethod,
      items,
      couponCode,
      deliveryMethod = 'DELIVERY',
      isB2B = false,
      scheduledSlot = 'INSTANT',
      shopName = null,
      shopPhone = null,
      noGst = false
    } = await request.json()

    if (!customerId || !paymentMethod || !items || items.length === 0) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (deliveryMethod !== 'PICKUP' && !addressId) {
      return NextResponse.json({ error: 'Delivery address is required' }, { status: 400 })
    }

    // 1. Verify Customer
    const customer = await prisma.user.findUnique({
      where: { id: customerId }
    })
    if (!customer) {
      return NextResponse.json({ error: 'Customer not found' }, { status: 404 })
    }

    // 2. Resolve address
    let finalAddressId = addressId
    if (deliveryMethod === 'PICKUP') {
      const contactSetting = await prisma.storeSetting.findUnique({
        where: { key: 'contact_phone' }
      })
      const defaultSupportPhone = contactSetting?.value || '+917054470303'

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
        where: { userId: customerId, label: 'STORE_PICKUP' }
      })
      if (!pickupAddress) {
        pickupAddress = await prisma.address.create({
          data: {
            userId: customerId,
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
      where: { id: finalAddressId, userId: customerId },
    })

    if (!address) {
      return NextResponse.json({ error: 'Selected address is invalid for this customer' }, { status: 400 })
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

    // Fetch store settings for tax, fees, and status
    const storeSettings = await prisma.storeSetting.findMany()
    const settingsMap = storeSettings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    const groceryMartOpen = settingsMap['grocery_mart_open'] !== 'false'
    const cafeOpen = settingsMap['cafe_open'] !== 'false'

    // Fetch products and calculate server-side subtotal
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

    const isCafeProduct = (p: any) => {
      if (!p) return false
      if (p.category?.slug === 'cafe') return true
      if (p.tags?.includes('cafe')) return true
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

      if (isCafeProduct(dbProduct) && item.quantity > 10) {
        return NextResponse.json({ error: `Maximum order limit of 10 units exceeded for product "${dbProduct.name} ${variantName ? `(${variantName})` : ''}"` }, { status: 400 })
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

    // Force open checks (Admin orders can bypass closed status if they wish, but default warnings are useful)
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

    let combinedDiscount = 0
    let couponId = null

    if (couponCode) {
      const coupon = await prisma.coupon.findUnique({
        where: { code: couponCode.toUpperCase(), isActive: true },
      })

      if (coupon) {
        const hasExpired = coupon.expiresAt && new Date(coupon.expiresAt) < new Date()
        const limitReached = coupon.maxUses && coupon.usedCount >= coupon.maxUses
        const minOrderMet = combinedSubtotal >= coupon.minOrder

        if (!hasExpired && !limitReached && minOrderMet) {
          couponId = coupon.id
          if (coupon.discountType === 'FLAT') {
            combinedDiscount = coupon.value
          } else if (coupon.discountType === 'PERCENT') {
            combinedDiscount = (combinedSubtotal * coupon.value) / 100
            if (coupon.maxDiscount) {
              combinedDiscount = Math.min(combinedDiscount, coupon.maxDiscount)
            }
          }
        }
      }
    }

    const taxPercent = parseFloat(settingsMap['tax_rate'] || '5')
    const serverTaxRate = noGst ? 0 : (taxPercent / 100)
    const serverMiscFee = parseFloat(settingsMap['misc_fee'] || '0')

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

    const ordersToCreate: any[] = []

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

    // Process DB changes inside a Transaction
    const createdOrders = await prisma.$transaction(async (tx) => {
      const results: any[] = []

      for (const orderInfo of ordersToCreate) {
        const orderItemsData = orderInfo.items.map((item: any) => {
          const isVariant = item.product.id.includes('_')
          const [productId, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]

          let price = item.dbProduct.price
          if (isVariant && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
            const variant = (item.dbProduct.variants as any[]).find((v) => v.name === variantName)
            if (variant) {
              price = variant.price
            }
          }

          return {
            productId,
            name: isVariant ? `${item.dbProduct.name} (${variantName})` : item.dbProduct.name,
            price,
            quantity: item.quantity,
            imageUrl: item.dbProduct.imageUrl,
            selectedVariant: variantName,
            costPrice: item.dbProduct.costPrice || 0,
            variants: item.dbProduct.variants,
            notes: item.notes || null,
          }
        })

        // Determine payment status
        const paymentStatus = paymentMethod === 'COD' ? PaymentStatus.PENDING : PaymentStatus.PAID

        // Resolve estimated delivery
        const estimatedDelivery = new Date()
        if (scheduledSlot === 'INSTANT') {
          estimatedDelivery.setMinutes(estimatedDelivery.getMinutes() + 15)
        }

        const newOrder = await tx.order.create({
          data: {
            userId: customerId,
            addressId: finalAddressId,
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

        // Deduct inventory stock
        for (const item of orderItemsData) {
          if (item.selectedVariant) {
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

    // Invalidate caches
    try {
      const uniqueCategorySlugs = new Set(
        dbProducts.map((p) => p.category?.slug).filter(Boolean)
      )
      revalidateStorefront()
      for (const catSlug of uniqueCategorySlugs) {
        revalidateStorefront(catSlug)
      }
    } catch (revalErr) {
      console.error('Failed to revalidate paths after order placement:', revalErr)
    }

    // Emit real-time events and push/WhatsApp alerts
    try {
      const adminPhones: string[] = []
      const notifyPhone1 = settingsMap['whatsapp_notify_7054470303'] !== 'false'
      const notifyPhone2 = settingsMap['whatsapp_notify_8112849854'] !== 'false'

      if (notifyPhone1) adminPhones.push('7054470303')
      if (notifyPhone2) adminPhones.push('8112849854')

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

        sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
          title: order.shopName === 'FastKirana Cafe Kitchen' ? 'New Cafe Order ☕' : 'New Grocery Order 📦',
          body: `Admin placed order #${shortId} for ${order.user?.name || 'customer'} of ₹${order.total}.`,
          tag: `order-${order.id}`,
          data: { orderId: order.id }
        }).catch((err: any) => console.error('Error sending push notification to workers:', err))

        const whatsappPromises: Promise<any>[] = []

        if (adminPhones.length > 0) {
          const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
          const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
          const customerName = order.user?.name || 'Customer'
          const customerPhone = order.address?.phone || 'N/A'
          const adminText = `New Admin-Placed ${orderType} Order #${shortId} of ₹${order.total} for ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`

          for (const adminPhone of adminPhones) {
            whatsappPromises.push(
              sendWhatsAppOrderAlert(adminPhone, adminText)
                .catch((err: any) => console.error(`Failed to send admin (${adminPhone}) WhatsApp order alert:`, err))
            )
          }
        }

        if (whatsappPromises.length > 0) {
          await Promise.allSettled(whatsappPromises)
        }
      }
    } catch (sseErr) {
      console.error('Failed to emit SSE/notifications for admin order:', sseErr)
    }

    return NextResponse.json({ success: true, orders: createdOrders })
  } catch (error: any) {
    console.error('Failed to place order on behalf:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}
