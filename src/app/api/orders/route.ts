import { NextRequest, NextResponse, after } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { OrderStatus, PaymentStatus, PaymentMethod, Role } from '@prisma/client'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { STORE_PINCODE, GROCERY_PICKUP_ADDRESS, RESTAURANT_PICKUP_ADDRESS, resolvePincode } from '@/lib/store-config'
import { apiWriteLimiter, apiReadLimiter } from '@/lib/rate-limit'
import { revalidateStorefront } from '@/lib/revalidate'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '@/lib/distance'
import { getProductLimit } from '@/lib/utils'
import { getLast10Digits } from '@/lib/phone'
import { checkIsStoreOpen } from '@/app/api/settings/route'

export async function POST(request: NextRequest) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  const session = await auth()
  const userId = session?.user?.id
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Check if account is blocked
  const currentUser = await prisma.user.findUnique({
    where: { id: userId },
    select: { isBlocked: true, blockReason: true }
  })

  if (currentUser?.isBlocked) {
    return NextResponse.json({
      error: `Your account has been blocked from placing orders.${currentUser.blockReason ? ` Reason: ${currentUser.blockReason}` : ' Please contact support.'}`
    }, { status: 403 })
  }

  try {
    const { addressId, paymentMethod, items, couponCode, deliveryMethod = 'DELIVERY', isB2B = false, scheduledSlot = 'INSTANT', shopName = null, shopPhone = null, storeId = null, packagingOption = 'NORMAL', packagingFee = 0 } = await request.json()

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
      const defaultPickupAddress = addressSetting?.value || GROCERY_PICKUP_ADDRESS
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

    // Fetch store settings early (needed for pincode check, tax, misc fee, store status)
    const storeSettings = await prisma.storeSetting.findMany()
    const settingsMap = storeSettings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    // Distance-based delivery validation
    let deliveryRules: ReturnType<typeof getDeliveryRules> | null = null

    if (deliveryMethod === 'DELIVERY') {
      const p = (address.pincode || '').trim().replace(/\s+/g, '')
      const serviceablePincode = (resolvePincode(settingsMap) || '209206').replace(/\s+/g, '')
      if (!p || p !== serviceablePincode) {
        return NextResponse.json({ error: `Selected address is outside our delivery zone. FastKirana delivers strictly to Ghatampur (Pincode: ${serviceablePincode}).` }, { status: 400 })
      }
      const c = (address.city || '').trim().toLowerCase()
      if (!c.includes('ghatampur')) {
        return NextResponse.json({ error: 'Selected address city is outside our delivery zone. Delivery is available in Ghatampur only.' }, { status: 400 })
      }

      // Calculate distance if address has GPS coordinates
      const targetLat = address.lat ?? ((address as any).latitude ? parseFloat((address as any).latitude) : null)
      const targetLng = address.lng ?? ((address as any).longitude ? parseFloat((address as any).longitude) : null)

      const geoSettings = await prisma.storeSetting.findMany({
        where: { key: { in: ['store_lat', 'store_lng', 'delivery_radius', 'max_delivery_radius', 'surge_charge'] } }
      })
      const geoSettingMap = new Map(geoSettings.map(s => [s.key, s.value]))

      const storeLat = geoSettingMap.get('store_lat') ? parseFloat(geoSettingMap.get('store_lat')!) : DEFAULT_STORE_LAT
      const storeLng = geoSettingMap.get('store_lng') ? parseFloat(geoSettingMap.get('store_lng')!) : DEFAULT_STORE_LNG
      const maxRadiusKm = geoSettingMap.get('delivery_radius') ? parseFloat(geoSettingMap.get('delivery_radius')!) : (geoSettingMap.get('max_delivery_radius') ? parseFloat(geoSettingMap.get('max_delivery_radius')!) : 2.0)
      const surgeFee = geoSettingMap.get('surge_charge') ? parseFloat(geoSettingMap.get('surge_charge')!) : 0

      let resolvedLat = targetLat
      let resolvedLng = targetLng

      if (!resolvedLat || !resolvedLng) {
        try {
          const addressQuery = `${address.houseNo || ''} ${address.street || ''} ${address.area || ''}, ${address.city || 'Ghatampur'}, ${address.pincode || STORE_PINCODE}`
          const apiKey = process.env.GOOGLE_MAPS_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
          if (apiKey) {
            const geoController = new AbortController()
            const geoTimeout = setTimeout(() => geoController.abort(), 2000)
            try {
              const geoRes = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(addressQuery)}&key=${apiKey.trim()}`, { signal: geoController.signal })
              clearTimeout(geoTimeout)
              if (geoRes.ok) {
                const geoData = await geoRes.json()
                if (geoData.results && geoData.results[0]?.geometry?.location) {
                  resolvedLat = geoData.results[0].geometry.location.lat
                  resolvedLng = geoData.results[0].geometry.location.lng
                }
              }
            } catch (err) {
              clearTimeout(geoTimeout)
              console.error('Server-side geocode error or timeout:', err)
            }
          }
        } catch (err) {
          console.error('Server-side geocode setup error:', err)
        }
      }

      if (resolvedLat && resolvedLng) {
        const distanceKm = getDistanceKm(storeLat, storeLng, resolvedLat, resolvedLng)
        deliveryRules = getDeliveryRules(distanceKm, { maxRadiusKm, surgeFee })

        if (!deliveryRules.isServiceable || distanceKm > maxRadiusKm) {
          return NextResponse.json({
            error: `Your location is ${distanceKm.toFixed(1)} km away. Delivery is strictly limited to ${maxRadiusKm.toFixed(1)} km from Ghatampur Store.`
          }, { status: 400 })
        }
      }
    }

    // settingsMap already fetched above (before delivery validation)

    const groceryMartOpen = checkIsStoreOpen(settingsMap, 'grocery')

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
        category: true,
        restaurant: true
      }
    })

    const groceryItems: any[] = []
    const restaurantGroups: Record<string, { restaurant: any; items: any[] }> = {}

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

      const isRestaurantItem = !!dbProduct.restaurantId

      if (isRestaurantItem) {
        dbStock = 999999
      }

      if (dbStock < item.quantity) {
        return NextResponse.json({ error: `Insufficient stock for product "${dbProduct.name} ${variantName ? `(${variantName})` : ''}"` }, { status: 400 })
      }

      const limit = getProductLimit(dbProduct)
      if (item.quantity > limit) {
        return NextResponse.json({ error: `Maximum order limit of ${limit} units exceeded for product "${dbProduct.name} ${variantName ? `(${variantName})` : ''}"` }, { status: 400 })
      }

      const itemWithDb = {
        ...item,
        dbProduct
      }

      if (isRestaurantItem) {
        const rId = dbProduct.restaurantId as string
        if (!restaurantGroups[rId]) {
          restaurantGroups[rId] = {
            restaurant: dbProduct.restaurant,
            items: []
          }
        }
        restaurantGroups[rId].items.push(itemWithDb)
      } else {
        groceryItems.push(itemWithDb)
      }
    }

    if (groceryItems.length > 0 && !groceryMartOpen) {
      return NextResponse.json({ error: 'Grocery Mart is temporarily closed.' }, { status: 400 })
    }
    
    for (const rId in restaurantGroups) {
      const r = restaurantGroups[rId].restaurant
      if (!r || !r.isOpen || !r.isActive) {
        return NextResponse.json({ error: `${r?.name || 'Restaurant'} is temporarily closed.` }, { status: 400 })
      }
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

    if (combinedSubtotal < 20) {
      return NextResponse.json({ error: 'Minimum order value of ₹20 is required to place an order.' }, { status: 400 })
    }

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
            } else if (coupon.restaurantId) {
              const restaurantItems = items.filter((item: any) => {
                const dbProduct = dbProducts.find((p) => p.id === item.product.id.split('_')[0])
                return dbProduct && dbProduct.restaurantId === coupon.restaurantId
              })
              const restaurantSubtotal = restaurantItems.reduce((sum: number, item: any) => {
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

              if (restaurantSubtotal === 0 || restaurantSubtotal < coupon.minOrder) {
                meetsMinOrder = false
              }
              eligibleSubtotal = restaurantSubtotal
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
    const serverTaxRate = 0.00
    const serverMiscFee = parseFloat(settingsMap['misc_fee'] || '0')

    // Calculate details for each order to create
    const ordersToCreate: any[] = []

    // Helper to calculate subtotal
    const getSubtotal = (itemList: any[]) => itemList.reduce((sum, item) => {
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

    const grocerySubtotal = getSubtotal(groceryItems)
    
    const restaurantData = Object.keys(restaurantGroups).map(rId => {
      const group = restaurantGroups[rId]
      const sub = getSubtotal(group.items)
      return { rId, restaurant: group.restaurant, items: group.items, subtotal: sub, deliveryFee: 0 }
    })

    const deliveryFeeVal = settingsMap['delivery_fee'] ? parseFloat(settingsMap['delivery_fee']) : DELIVERY_FEE

    let groceryDeliveryFee = 0

    if (deliveryMethod === 'DELIVERY' && !isB2B) {
      if (deliveryRules && !deliveryRules.isServiceable) {
        return NextResponse.json({
          error: `Selected address is outside our delivery zone (${deliveryRules.distanceKm.toFixed(1)} km away). We deliver only up to 3 km.`
        }, { status: 400 })
      }

      const defaultThreshold = settingsMap['grocery_free_delivery_threshold'] ? parseFloat(settingsMap['grocery_free_delivery_threshold']) : GROCERY_FREE_DELIVERY_THRESHOLD
      const freeDeliveryThreshold = (deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : defaultThreshold
      const appliesDeliveryFee = combinedSubtotal < freeDeliveryThreshold

      if (appliesDeliveryFee) {
        const feeToCharge = (deliveryRules && deliveryRules.isServiceable) ? deliveryRules.deliveryFee : deliveryFeeVal
        if (groceryItems.length > 0) {
          groceryDeliveryFee = feeToCharge
        } else if (restaurantData.length > 0) {
          restaurantData[0].deliveryFee = feeToCharge
        }
      }
    }

    const isPremiumPackaging = packagingOption === 'PREMIUM' || packagingFee === 15
    const resolvedPackagingFee = isPremiumPackaging ? 15 : 0

    let hasChargedMiscFee = false

    if (groceryItems.length > 0) {
      const groceryDiscount = combinedSubtotal > 0 ? (grocerySubtotal / combinedSubtotal) * combinedDiscount : 0
      const groceryTaxes = (grocerySubtotal - groceryDiscount) * serverTaxRate
      
      // When Premium Packaging (+₹15) is selected, standard handling fee (₹5) is completely waived
      const appliedMiscFee = (deliveryMethod !== 'PICKUP' && !hasChargedMiscFee && !isPremiumPackaging) ? serverMiscFee : 0
      if (appliedMiscFee > 0) hasChargedMiscFee = true

      const groceryTotal = grocerySubtotal - groceryDiscount + groceryDeliveryFee + groceryTaxes + appliedMiscFee

      ordersToCreate.push({
        type: 'GROCERY',
        subtotal: grocerySubtotal,
        discount: groceryDiscount,
        deliveryFee: groceryDeliveryFee,
        taxes: groceryTaxes,
        miscFee: appliedMiscFee,
        total: groceryTotal,
        items: groceryItems,
      })
    }

    for (const rData of restaurantData) {
      const rDiscount = combinedSubtotal > 0 ? (rData.subtotal / combinedSubtotal) * combinedDiscount : 0
      const rTaxes = (rData.subtotal - rDiscount) * serverTaxRate
      
      const isFirstRestOrder = restaurantData.indexOf(rData) === 0
      const rPackagingFee = isFirstRestOrder ? resolvedPackagingFee : 0

      // If Premium Packaging (₹15) is selected, it covers packaging/handling, so standard serverMiscFee (₹5) is waived
      const appliedMiscFee = (rPackagingFee > 0)
        ? rPackagingFee 
        : ((deliveryMethod !== 'PICKUP' && !hasChargedMiscFee && !isPremiumPackaging) ? serverMiscFee : 0)
      if (appliedMiscFee > 0) hasChargedMiscFee = true

      const rTotal = rData.subtotal - rDiscount + rData.deliveryFee + rTaxes + appliedMiscFee

      ordersToCreate.push({
        type: 'RESTAURANT',
        restaurantId: rData.rId,
        restaurant: rData.restaurant,
        subtotal: rData.subtotal,
        discount: rDiscount,
        deliveryFee: rData.deliveryFee,
        taxes: rTaxes,
        miscFee: appliedMiscFee,
        total: rTotal,
        items: rData.items,
        notes: isPremiumPackaging ? '✨ Premium Thermal Packaging Requested (+₹15)' : undefined,
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

      // Get single atomic base readableId for this entire checkout
      const seqResult = await tx.$queryRaw<{ nextval: number }[]>`SELECT nextval('order_readable_id_seq')::int as nextval`
      const baseReadableId = String(seqResult[0].nextval)

      let restIndex = 0

      for (const orderInfo of ordersToCreate) {
        let orderReadableId = baseReadableId
        if (isCombined) {
          if (orderInfo.type === 'RESTAURANT' || orderInfo.restaurantId) {
            restIndex++
            orderReadableId = restIndex === 1 ? `${baseReadableId}-R` : `${baseReadableId}-R${restIndex}`
          } else {
            orderReadableId = `${baseReadableId}-G`
          }
        }
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

        // Calculate estimated delivery time for this order
        let estMins = 10
        if (orderInfo.type === 'RESTAURANT') {
          estMins = 30
          if (orderInfo.restaurant?.deliveryTime) {
             const match = orderInfo.restaurant.deliveryTime.match(/(\d+)/)
             if (match) estMins = parseInt(match[1], 10)
          }
        }
        let estimatedDelivery = new Date(Date.now() + estMins * 60 * 1000)

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

        let orderAddressId = finalAddressId

        if (deliveryMethod === 'PICKUP') {
          let label = 'STORE_PICKUP'
          let defaultPickupAddress = 'Vikas Medical Store, NH34, Ghatampur, Kanpur Nagar, Kanpur, 209206'
          let phone = defaultSupportPhone

          if (orderInfo.type === 'RESTAURANT') {
            label = `STORE_PICKUP_${orderInfo.restaurantId}`
            defaultPickupAddress = orderInfo.restaurant?.address ? `${orderInfo.restaurant.address}, ${orderInfo.restaurant.city || 'Ghatampur'}` : (settingsMap['restaurant_pickup_address'] || RESTAURANT_PICKUP_ADDRESS)
            phone = orderInfo.restaurant?.ownerPhone || settingsMap['contact_phone'] || '+91 81128 49854'
          } else {
            label = 'STORE_PICKUP'
            defaultPickupAddress = settingsMap['grocery_pickup_address'] || GROCERY_PICKUP_ADDRESS
            phone = defaultSupportPhone
          }

          const addrParts = defaultPickupAddress.split(',').map(p => p.trim())
          const houseNo = addrParts[0] || 'Store Pickup'
          const street = addrParts[1] || 'Ghatampur'
          const area = addrParts[2] || 'Kanpur Nagar'
          const city = addrParts[3] || 'Kanpur'
          const pincode = addrParts[4] || STORE_PINCODE

          let pickupAddress = await tx.address.findFirst({
            where: { userId, label }
          })

          if (!pickupAddress) {
            pickupAddress = await tx.address.create({
              data: {
                userId,
                label,
                houseNo,
                street,
                area,
                city,
                pincode,
                phone,
              }
            })
          } else {
            pickupAddress = await tx.address.update({
              where: { id: pickupAddress.id },
              data: {
                houseNo,
                street,
                area,
                city,
                pincode,
                phone,
              }
            })
          }
          orderAddressId = pickupAddress.id
        }

        // Sync address phone number to user profile if currently missing in system
        if (address && address.phone) {
          const userObj = await tx.user.findUnique({
            where: { id: userId },
            select: { phone: true }
          })
          if (userObj && (!userObj.phone || userObj.phone.trim() === '')) {
            await tx.user.update({
              where: { id: userId },
              data: { phone: address.phone.trim() }
            })
          }
        }

        // Create order
        const newOrder = await tx.order.create({
          data: {
            userId: userId,
            readableId: orderReadableId,
            addressId: orderAddressId,
            combinedId: combinedId,
            orderType: (orderInfo.type === 'RESTAURANT' || orderInfo.restaurantId) ? 'RESTAURANT' : 'GROCERY',
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
            shopName: orderInfo.type === 'RESTAURANT'
              ? (orderInfo.restaurant?.name || 'Restaurant')
              : shopName,
            shopPhone: orderInfo.type === 'RESTAURANT'
              ? (orderInfo.restaurant?.ownerPhone || settingsMap['contact_phone'] || '+91 81128 49854')
              : shopPhone,
            restaurantId: orderInfo.type === 'RESTAURANT' ? orderInfo.restaurantId : null,
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
          const dbProd = await tx.product.findUnique({
            where: { id: item.productId },
            include: { category: true }
          })

          if (dbProd && dbProd.restaurantId) {
            continue
          }

          if (item.selectedVariant) {
            // Deduct stock from the variant in JSON variants
            if (dbProd && dbProd.variants && Array.isArray(dbProd.variants)) {
              const prevStock = dbProd.stock
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

              await tx.stockLog.create({
                data: {
                  productId: item.productId,
                  quantity: -item.quantity,
                  type: 'ONLINE_ORDER',
                  prevStock,
                  newStock: newTotalStock
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

            const prevStock = dbProd ? dbProd.stock : 0
            const newTotalStock = activeBatches.length > 0 
              ? activeBatches.reduce((sum, b) => sum + b.quantity, 0)
              : Math.max(0, prevStock - item.quantity)
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

            await tx.stockLog.create({
              data: {
                productId: item.productId,
                quantity: -item.quantity,
                type: 'ONLINE_ORDER',
                prevStock,
                newStock: newTotalStock
              }
            })
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
    }, { maxWait: 20000, timeout: 25000 })

    // Perform notifications asynchronously in the background
    // SKIP notifications for online payment orders — they fire AFTER payment verification
    const isOnlinePaymentOrder = paymentMethod !== 'COD'
    after(async () => {

      if (isOnlinePaymentOrder) {
        // Don't send SSE, push, or WhatsApp for online orders yet.
        // Notifications will be sent when payment is verified via /api/payment/razorpay/verify-signature
        return
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
          const displayId = order.readableId || order.id.slice(-6).toUpperCase()
          const isRestaurant = !!order.restaurantId
          const orderType = isRestaurant ? 'Restaurant' : 'Grocery'
          const notificationTitle = isRestaurant ? `New Order for ${order.shopName} 🍲` : 'New Grocery Order 📦'

          sseEmitter.emit('order', {
            type: 'new-order',
            orderId: order.id,
            readableId: order.readableId,
            shopName: order.shopName,
            status: order.status,
            total: order.total,
            createdAt: order.createdAt,
            restaurantId: order.restaurantId,
          })

          // Send push notifications to all workers for any new order
          sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
            title: notificationTitle,
            body: `Order #${displayId} of ₹${order.total} has been placed.`,
            tag: `order-${order.id}`,
            data: { orderId: order.id }
          }).catch((err: any) => console.error('Error sending push notification to workers:', err))

          const whatsappPromises: Promise<any>[] = []

          // 2. WhatsApp Alert to Admins/Staff
          if (adminPhones.length > 0) {
            const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
            const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
            const outletName = order.shopName || (isRestaurant ? 'Restaurant' : 'FastKirana Grocery')
            const customerName = order.user?.name || 'Customer'
            const customerPhone = order.address?.phone || order.user?.phone || 'N/A'
            const adminText = `New Order #${displayId} for [${outletName}] of ₹${order.total} from ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`
            
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
    })

    const mainOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
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
    const isStaff = session.user?.role === 'ADMIN' || session.user?.role === 'CHEF' || session.user?.role === 'PICKER' || session.user?.role === 'DELIVERY'

    let orders: any[] = []

    if (isStaff && all) {
      // Staff queries all orders with associated customer details
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone", o."restaurantId",
               u.name as "userName", u.email as "userEmail", u.phone as "userPhone"
        FROM orders o
        LEFT JOIN users u ON o."userId" = u.id
        ORDER BY o."createdAt" DESC
        LIMIT 1000
      `
    } else {
      // Normal user queries their orders by userId, email, or phone match
      const sessionEmail = session.user.email ? session.user.email.toLowerCase().trim() : ''
      const sessionPhone = (session.user as any).phone ? getLast10Digits((session.user as any).phone) : ''

      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone", o."restaurantId",
               o."combinedId"
        FROM orders o 
        WHERE o."userId" = ${userId}
           OR (${sessionEmail} != '' AND o."userId" IN (SELECT id FROM users WHERE LOWER(email) = ${sessionEmail}))
           OR (${sessionPhone} != '' AND o."userId" IN (SELECT id FROM users WHERE REPLACE(REPLACE(phone, '+', ''), ' ', '') LIKE ${'%' + sessionPhone}))
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

    const result = orders.map(o => {
      const resolvedAddress = allAddresses.find(a => a.id === o.addressId)
      const resolvedPhone = o.userPhone || o.shopPhone || (resolvedAddress ? (resolvedAddress as any).phone : undefined)
      return {
        ...o,
        userName: o.userName || undefined,
        userEmail: o.userEmail || undefined,
        userPhone: resolvedPhone,
        user: {
          name: o.userName || 'Customer',
          email: o.userEmail || '',
          phone: resolvedPhone || null,
        },
        items: allItems.filter(item => item.orderId === o.id),
        address: resolvedAddress,
      }
    })

    if (isStaff && all) {
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

    // Customer grouping (Group by combinedId or creation timestamp within 10 seconds)
    const groupedResult: any[] = []
    const processedIds = new Set<string>()

    result.forEach((order: any) => {
      if (processedIds.has(order.id)) return

      // Find all orders that belong to the same combined group
      const relatedOrders = result.filter((o: any) => {
        if (processedIds.has(o.id)) return false
        if (o.id === order.id) return true
        if (order.combinedId && typeof order.combinedId === 'string' && o.combinedId === order.combinedId) return true
        return false
      })

      relatedOrders.forEach((o: any) => processedIds.add(o.id))

      if (relatedOrders.length === 1) {
        groupedResult.push(relatedOrders[0])
      } else {
        const mainOrder = relatedOrders.find(o => !o.restaurantId) || relatedOrders[0]
        const statuses = relatedOrders.map(o => o.status)
        const combinedStatus = getCombinedStatus(statuses)

        const subOrders = relatedOrders.map(o => ({
          id: o.id,
          type: o.restaurantId ? 'RESTAURANT' : 'GROCERY',
          restaurantId: o.restaurantId,
          status: o.status,
          total: o.total,
          itemsCount: o.items?.length || 0
        }))

        // Deduplicate items if any overlap
        const itemMap = new Map<string, any>()
        relatedOrders.flatMap(o => o.items || []).forEach(item => {
          if (!itemMap.has(item.id)) {
            itemMap.set(item.id, item)
          }
        })

        const baseReadableId = (mainOrder.readableId || '').replace(/-[GR\d]+$/i, '') || mainOrder.readableId

        const mergedOrder = {
          ...mainOrder,
          id: mainOrder.id,
          readableId: baseReadableId,
          status: combinedStatus,
          subtotal: relatedOrders.reduce((sum, o) => sum + (o.subtotal || 0), 0),
          discount: relatedOrders.reduce((sum, o) => sum + (o.discount || 0), 0),
          deliveryFee: relatedOrders.reduce((sum, o) => sum + (o.deliveryFee || 0), 0),
          taxes: relatedOrders.reduce((sum, o) => sum + (o.taxes || 0), 0),
          miscFee: relatedOrders.reduce((sum, o) => sum + (o.miscFee || 0), 0),
          total: relatedOrders.reduce((sum, o) => sum + (o.total || 0), 0),
          items: Array.from(itemMap.values()),
          isCombined: true,
          subOrders
        }
        groupedResult.push(mergedOrder)
      }
    })

    groupedResult.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())

    return NextResponse.json(groupedResult)
  } catch (error) {
    console.error('Orders list API error:', error)
    return NextResponse.json({ error: 'Failed to fetch orders' }, { status: 500 })
  }
}

