import { NextRequest, NextResponse, after } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { OrderStatus, PaymentStatus, PaymentMethod, Role } from '@prisma/client'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { STORE_PINCODE, GROCERY_PICKUP_ADDRESS, RESTAURANT_PICKUP_ADDRESS, resolvePincode } from '@/lib/store-config'
import { orderLimiter, apiReadLimiter } from '@/lib/rate-limit'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { buildOrderFcmPayload, sendTopicWithRetry } from '@/lib/fcm-utils'
import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '@/lib/distance'
import { getProductLimit } from '@/lib/utils'
import { getLast10Digits } from '@/lib/phone'
import { checkIsStoreOpen } from '@/app/api/settings/route'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { resolveDarkStoreForCustomer, extractCityFromStoreName, extractPincodeFromStoreId } from '@/lib/store-resolver'
import { evaluateSurgeStatus } from '@/lib/surge-manager'

const inFlightOrderPlacements = new Set<string>()

export async function POST(request: NextRequest) {
  const limited = await orderLimiter.check(request)
  if (limited) return limited

  let body: any = {}
  try {
    body = await request.json()
  } catch (e) {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 })
  }
  const session = await auth()
  let userId = session?.user?.id
  const isStaffSession = Boolean(session?.user?.role && session.user.role !== Role.USER)

  // If mobile app request without NextAuth cookie OR admin placing order on behalf of customer:
  const rawPhone = body.phone || body.customerPhone || request.headers.get('x-user-phone')
  const cleanPhone = rawPhone ? getLast10Digits(rawPhone.toString()) : ''

  if (!userId || (isStaffSession && cleanPhone && cleanPhone.length === 10)) {
    if (!cleanPhone || cleanPhone.length < 10) {
      if (!userId) {
        return NextResponse.json({ error: 'Valid 10-digit customer phone is required' }, { status: 400 })
      }
    } else {
      const userName = body.userName || body.customerName || `Customer ${cleanPhone.slice(-4)}`

      let dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: cleanPhone },
            { phone: `+91${cleanPhone}` },
            { phone: { contains: cleanPhone } },
            ...(body.userId ? [{ id: body.userId }] : []),
          ]
        }
      })

      if (!dbUser) {
        dbUser = await prisma.user.create({
          data: {
            phone: `+91${cleanPhone}`,
            email: body.email || `customer_${cleanPhone}@fastkirana.in`,
            name: userName.toString(),
            role: Role.USER,
          }
        })
      }
      userId = dbUser.id
    }
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

  if (inFlightOrderPlacements.has(userId)) {
    return NextResponse.json({
      error: 'An order is already being processed for this account. Please wait a moment.'
    }, { status: 429 })
  }
  inFlightOrderPlacements.add(userId)

  try {
    const { addressId, paymentMethod, items, couponCode, deliveryMethod = 'DELIVERY', isB2B = false, scheduledSlot = 'INSTANT', shopName = null, shopPhone = null, storeId = null, packagingOption = 'NORMAL', packagingFee = 0 } = body

    if (!paymentMethod || !items || items.length === 0) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (deliveryMethod !== 'PICKUP' && !addressId && !body.customerAddress) {
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

    let address: any = null
    if (finalAddressId && finalAddressId !== 'addr_default' && finalAddressId !== 'STORE_PICKUP') {
      address = await prisma.address.findUnique({
        where: { id: finalAddressId }
      })
    }

    if (!address && finalAddressId && finalAddressId !== 'addr_default' && finalAddressId !== 'STORE_PICKUP') {
      address = await prisma.address.findFirst({
        where: { id: finalAddressId }
      })
    }

    // If still not found, check if mobile app sent customerAddress text
    if (!address && body.customerAddress && typeof body.customerAddress === 'string' && body.customerAddress.trim().length > 0) {
      const rawCustomerPhone = body.phone || body.customerPhone || ''
      const cleanPhone = getLast10Digits(rawCustomerPhone.toString())
      const formattedPhone = cleanPhone && cleanPhone.length === 10 ? `+91${cleanPhone}` : (rawCustomerPhone || '+917054470303')
      
      address = await prisma.address.create({
        data: {
          userId,
          label: 'DELIVERY',
          houseNo: '.',
          street: body.customerAddress.trim(),
          area: '.',
          city: 'Ghatampur',
          pincode: '209206',
          phone: formattedPhone,
          lat: body.latitude ? parseFloat(body.latitude) : null,
          lng: body.longitude ? parseFloat(body.longitude) : null,
        }
      })
    }

    if (!address) {
      address = await prisma.address.findFirst({
        where: { userId: userId },
        orderBy: [
          { isDefault: 'desc' },
        ]
      })
    }

    if (!address) {
      const rawCustomerPhone = body.phone || body.customerPhone || '+917054470303'
      const cleanPhone = getLast10Digits(rawCustomerPhone.toString())
      const formattedPhone = cleanPhone && cleanPhone.length === 10 ? `+91${cleanPhone}` : rawCustomerPhone

      address = await prisma.address.create({
        data: {
          userId,
          label: 'HOME',
          houseNo: 'Main Market',
          street: 'Station Road',
          area: 'Ghatampur',
          city: 'Ghatampur',
          pincode: '209206',
          phone: formattedPhone,
        }
      })
    }
    finalAddressId = address.id

    // Update address recipient phone number if customer entered a phone for this delivery address (account phone remains untouched)
    const rawCustomerPhone = body.phone || body.customerPhone
    if (rawCustomerPhone) {
      const cleanPhone = getLast10Digits(rawCustomerPhone.toString())
      if (cleanPhone && cleanPhone.length === 10) {
        const formattedPhone = `+91${cleanPhone}`
        
        if (address && (!address.phone || address.phone.trim() === '' || address.phone !== formattedPhone)) {
          await prisma.address.update({
            where: { id: address.id },
            data: { phone: formattedPhone }
          }).catch(() => {})
          address.phone = formattedPhone
        }
      }
    }

    // Fetch store settings early (needed for pincode check, tax, misc fee, store status)
    const storeSettings = await prisma.storeSetting.findMany()
    const settingsMap = storeSettings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    // Distance-based delivery validation
    let deliveryRules: ReturnType<typeof getDeliveryRules> | null = null
    let resolvedLat: number | null = null
    let resolvedLng: number | null = null
    let storeLat: number = DEFAULT_STORE_LAT
    let storeLng: number = DEFAULT_STORE_LNG
    let maxRadiusKm: number = 5.0
    let storeDisplayName: string = 'FastKirana Store'

    // Resolve target dark store for multi-hub routing and geofencing dynamically
    const addrPincode = (address?.pincode || '').trim().replace(/\s+/g, '')
    const addrCity = (address?.city || '').trim().toLowerCase()

    const storeResolveResult = await resolveDarkStoreForCustomer(address, storeId)
    const resolvedStoreId = storeResolveResult.storeId
    const targetDarkStore = storeResolveResult.store || await prisma.darkStore.findUnique({
      where: { id: resolvedStoreId }
    })

    const targetStoreCity = targetDarkStore ? extractCityFromStoreName(targetDarkStore.name).toLowerCase() : ''
    const targetStorePincode = targetDarkStore ? extractPincodeFromStoreId(targetDarkStore.id) : null

    if (deliveryMethod === 'DELIVERY') {
      const p = addrPincode
      const serviceablePincode = (resolvePincode(settingsMap) || '209206').replace(/\s+/g, '')
      const allowedPincodes = targetStorePincode
        ? [targetStorePincode]
        : [serviceablePincode, '209206', '209201', '209214', '209208', '208001', '208002', '208011', '208012', '208020']

      if (p && !allowedPincodes.includes(p) && !/^\d{6}$/.test(p)) {
        return NextResponse.json({ error: `Selected address pincode (${p}) is outside our delivery zone.` }, { status: 400 })
      }
      const c = addrCity
      const allowedCities = targetStoreCity
        ? [targetStoreCity, 'up', 'uttar pradesh']
        : ['ghatampur', 'kanpur', 'akbarpur', 'ambedkar', 'nagar', 'dehat', 'up', 'uttar pradesh']

      if (c && !allowedCities.some(cityKeyword => c.includes(cityKeyword))) {
        return NextResponse.json({ error: 'Selected address city is outside our delivery zone.' }, { status: 400 })
      }

      // Calculate distance if address has GPS coordinates
      const targetLat = address.lat ?? ((address as any).latitude ? parseFloat((address as any).latitude) : null)
      const targetLng = address.lng ?? ((address as any).longitude ? parseFloat((address as any).longitude) : null)

      const geoSettings = await prisma.storeSetting.findMany({
        where: { key: { in: ['store_lat', 'store_lng', 'delivery_radius', 'max_delivery_radius', 'surge_charge'] } }
      })
      const geoSettingMap = new Map(geoSettings.map(s => [s.key, s.value]))

      storeLat = targetDarkStore ? targetDarkStore.latitude : (geoSettingMap.get('store_lat') ? parseFloat(geoSettingMap.get('store_lat')!) : DEFAULT_STORE_LAT)
      storeLng = targetDarkStore ? targetDarkStore.longitude : (geoSettingMap.get('store_lng') ? parseFloat(geoSettingMap.get('store_lng')!) : DEFAULT_STORE_LNG)
      maxRadiusKm = targetDarkStore?.deliveryRadiusKm ? targetDarkStore.deliveryRadiusKm : (geoSettingMap.get('delivery_radius') ? parseFloat(geoSettingMap.get('delivery_radius')!) : (geoSettingMap.get('max_delivery_radius') ? parseFloat(geoSettingMap.get('max_delivery_radius')!) : 5.0))
      const surgeFee = targetDarkStore?.surgeCharge ? targetDarkStore.surgeCharge : (geoSettingMap.get('surge_charge') ? parseFloat(geoSettingMap.get('surge_charge')!) : 0)
      storeDisplayName = targetDarkStore?.name || 'FastKirana Store'

      resolvedLat = targetLat
      resolvedLng = targetLng

      if (!resolvedLat || !resolvedLng) {
        try {
          const fallbackCity = targetStoreCity || 'Ghatampur'
          const fallbackPincode = targetStorePincode || STORE_PINCODE
          const addressQuery = `${address.houseNo || ''} ${address.street || ''} ${address.area || ''}, ${address.city || fallbackCity}, ${address.pincode || fallbackPincode}`
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
      }
    }

    // settingsMap already fetched above (before delivery validation)
    const groceryMartOpen = checkIsStoreOpen(settingsMap, 'grocery')

    // 2. Normalize items from both Web App and Flutter Mobile App
    const normalizedItems = (items || []).map((i: any) => {
      const p = i.product || i
      let rawId = (i.productId || p.productId || p.id || i.id || '').toString().trim()
      // Strip 'item_' prefix if passed from Flutter / cart item ID
      if (rawId.startsWith('item_')) {
        rawId = rawId.replace(/^item_/, '')
      }
      return {
        product: {
          id: rawId,
          name: p.name || i.name || 'FastKirana Item',
          price: typeof p.price === 'number' ? p.price : (parseFloat(p.price || i.price || '0') || 0),
          slug: p.slug || i.slug,
          imageUrl: p.imageUrl || i.imageUrl || p.image || i.image,
          restaurantId: p.restaurantId || i.restaurantId,
        },
        quantity: typeof i.quantity === 'number' ? i.quantity : (parseInt(i.quantity || '1', 10) || 1),
        selectedVariant: i.selectedVariant,
      }
    })

    const productIds = normalizedItems.map((i: any) => {
      const rawId = i.product.id
      return rawId.includes('_') ? rawId.split('_')[0] : rawId
    }).filter(Boolean)
    const productSlugs = normalizedItems.map((i: any) => i.product.slug).filter(Boolean)

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

    for (const item of normalizedItems) {
      const rawId = item.product.id
      const isVariant = rawId.includes('_')
      const [productId, variantNameFromId] = isVariant ? rawId.split('_') : [rawId, null]
      const variantName = item.selectedVariant || variantNameFromId

      let dbProduct: any = dbProducts.find((p) => p.id === productId)
      if (!dbProduct && item.product.slug) {
        dbProduct = dbProducts.find((p) => p.slug === item.product.slug)
      }
      if (!dbProduct) {
        // Strip variant suffix like " (Small)" or " (250g)" from item name for fuzzy lookup
        const cleanName = item.product.name.replace(/\s*\([^)]*\)\s*$/, '').trim()
        dbProduct = await prisma.product.findFirst({
          where: {
            OR: [
              { id: productId },
              { name: { equals: item.product.name, mode: 'insensitive' } },
              { name: { equals: cleanName, mode: 'insensitive' } },
              { name: { contains: cleanName, mode: 'insensitive' } },
            ]
          },
          include: { category: true, restaurant: true }
        })
      }
      if (!dbProduct) {
        let defaultCat = await prisma.category.findFirst()
        if (!defaultCat) {
          defaultCat = await prisma.category.create({
            data: { name: 'General', slug: 'general' }
          })
        }
        dbProduct = await prisma.product.create({
          data: {
            name: item.product.name,
            slug: (item.product.slug || item.product.name.toLowerCase().replace(/[^a-z0-9]/g, '-')) + '-' + Date.now().toString().slice(-4),
            mrp: Number(item.product.price || 50),
            price: Number(item.product.price || 50),
            unit: '1 unit',
            stock: 9999,
            isAvailable: true,
            categoryId: defaultCat.id,
            imageUrl: item.product.imageUrl || '/images/placeholder.png',
          },
          include: { category: true, restaurant: true }
        })
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
      if (!r || !r.isActive) {
        return NextResponse.json({ error: `${r?.name || 'Restaurant'} is temporarily unavailable.` }, { status: 400 })
      }
      const opStatus = checkStoreOperatingStatus(r)
      if (!opStatus.isOpen) {
        return NextResponse.json({
          error: `${r.name || 'Restaurant'} is currently closed (${opStatus.formattedScheduleStr || 'Outside operating hours'}).`,
        }, { status: 400 })
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
    let hubSurgeFee = 0
    let hubSurgeReason = ''

    if (deliveryMethod === 'DELIVERY' && !isB2B) {
      // Evaluate active surge for target DarkStore hub
      try {
        const activeSurge = await evaluateSurgeStatus(
          settingsMap,
          targetDarkStore?.id,
          targetDarkStore ? { lat: targetDarkStore.latitude, lng: targetDarkStore.longitude } : null
        )
        if (activeSurge.isSurgeActive && activeSurge.surgeFee > 0) {
          hubSurgeFee = activeSurge.surgeFee
          hubSurgeReason = activeSurge.surgeReason || 'Safety & Weather Surge'
        }
      } catch (surgeErr) {
        console.error('Failed to evaluate hub surge fee:', surgeErr)
      }

      // 1. Process Grocery Items Delivery Fee & Validation from DarkStore Hub
      if (groceryItems.length > 0) {
        const defaultThreshold = settingsMap['grocery_free_delivery_threshold'] ? parseFloat(settingsMap['grocery_free_delivery_threshold']) : GROCERY_FREE_DELIVERY_THRESHOLD

        if (resolvedLat && resolvedLng) {
          const groceryDistKm = getDistanceKm(storeLat, storeLng, resolvedLat, resolvedLng)
          const groceryRules = getDeliveryRules(groceryDistKm, { maxRadiusKm, surgeFee: hubSurgeFee })

          if (!groceryRules.isServiceable || groceryDistKm > maxRadiusKm) {
            return NextResponse.json({
              error: `Your delivery address is ${groceryDistKm.toFixed(1)} km away. Grocery delivery is strictly limited to ${maxRadiusKm.toFixed(1)} km from ${storeDisplayName}.`
            }, { status: 400 })
          }

          if (grocerySubtotal < groceryRules.freeDeliveryThreshold) {
            groceryDeliveryFee = groceryRules.deliveryFee
          } else {
            groceryDeliveryFee = 0
          }
        } else {
          groceryDeliveryFee = (grocerySubtotal < defaultThreshold ? deliveryFeeVal : 0) + hubSurgeFee
        }
      }

      // 2. Process EACH Restaurant's Delivery Fee & Validation based on THAT restaurant's GPS location!
      for (const rData of restaurantData) {
        const r = rData.restaurant
        const rLat = r?.lat ?? (r?.latitude ? parseFloat(String(r.latitude)) : null)
        const rLng = r?.lng ?? (r?.longitude ? parseFloat(String(r.longitude)) : null)
        const rMaxRadius = r?.deliveryRadiusKm ? parseFloat(String(r.deliveryRadiusKm)) : 5.0
        const rName = r?.name || 'Restaurant'

        const rDefaultThreshold = settingsMap['restaurant_free_delivery_threshold']
          ? parseFloat(settingsMap['restaurant_free_delivery_threshold'])
          : (settingsMap['combined_free_delivery_threshold'] ? parseFloat(settingsMap['combined_free_delivery_threshold']) : 200)

        if (resolvedLat && resolvedLng && rLat && rLng) {
          // Calculate real distance from the restaurant to the customer's home!
          const rDistKm = getDistanceKm(rLat, rLng, resolvedLat, resolvedLng)
          const rRules = getDeliveryRules(rDistKm, { maxRadiusKm: rMaxRadius, surgeFee: hubSurgeFee })

          if (!rRules.isServiceable || rDistKm > rMaxRadius) {
            return NextResponse.json({
              error: `Your delivery address is ${rDistKm.toFixed(1)} km away from ${rName}. Delivery from this restaurant is strictly limited to ${rMaxRadius.toFixed(1)} km.`
            }, { status: 400 })
          }

          if (rData.subtotal < rRules.freeDeliveryThreshold) {
            rData.deliveryFee = rRules.deliveryFee
          } else {
            rData.deliveryFee = 0
          }
        } else {
          // Fallback if restaurant has no GPS saved
          if (rData.subtotal < rDefaultThreshold) {
            rData.deliveryFee = deliveryFeeVal + hubSurgeFee
          } else {
            rData.deliveryFee = 0
          }
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

      const gSurgeNote = (hubSurgeFee > 0 && groceryDeliveryFee > 0) ? `⚡ Surge Fee Applied: ₹${hubSurgeFee} (${hubSurgeReason})` : null
      const gPackagingNote = isPremiumPackaging ? '✨ Premium Thermal Packaging Requested (+₹15)' : null
      const gCombinedNotes = [body.notes, gPackagingNote, gSurgeNote].filter(Boolean).join(' | ')

      ordersToCreate.push({
        type: 'GROCERY',
        subtotal: grocerySubtotal,
        discount: groceryDiscount,
        deliveryFee: groceryDeliveryFee,
        taxes: groceryTaxes,
        miscFee: appliedMiscFee,
        total: groceryTotal,
        items: groceryItems,
        notes: gCombinedNotes || undefined,
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

      const rSurgeNote = (hubSurgeFee > 0 && rData.deliveryFee > 0) ? `⚡ Surge Fee Applied: ₹${hubSurgeFee} (${hubSurgeReason})` : null
      const rPackagingNote = isPremiumPackaging ? '✨ Premium Thermal Packaging Requested (+₹15)' : null
      const rCombinedNotes = [body.notes, rPackagingNote, rSurgeNote].filter(Boolean).join(' | ')

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
        notes: rCombinedNotes || undefined,
      })
    }

    // 5. Build payment settings
    const isOnlinePaid = Boolean(
      body.paymentStatus === 'PAID' ||
      body.paymentId ||
      body.razorpayPaymentId ||
      body.razorpay_payment_id
    )
    const paymentStatus = isOnlinePaid ? PaymentStatus.PAID : PaymentStatus.PENDING

    let resolvedPaymentMethod: PaymentMethod = PaymentMethod.COD
    const rawMethod = String(paymentMethod || '').toUpperCase()
    if (rawMethod === 'RAZORPAY' || rawMethod === 'UPI' || rawMethod === 'ONLINE') {
      resolvedPaymentMethod = PaymentMethod.UPI
    } else if (rawMethod === 'CARD') {
      resolvedPaymentMethod = PaymentMethod.CARD
    } else if (rawMethod === 'WALLET') {
      resolvedPaymentMethod = PaymentMethod.WALLET
    }


    // 6. Create orders inside a Prisma Transaction
    const createdOrders = await prisma.$transaction(async (tx) => {
      const results: any[] = []
      const now = new Date()
      const isCombined = ordersToCreate.length > 1
      const combinedId = isCombined ? `combined_${Math.random().toString(36).substring(2, 11)}_${Date.now().toString(36)}` : null

      // Get single atomic base readableId for this entire checkout
      let baseReadableId = String(Math.floor(100000 + Math.random() * 900000))
      try {
        const seqResult = await tx.$queryRaw<{ nextval: number }[]>`SELECT nextval('order_readable_id_seq')::int as nextval`
        if (seqResult && seqResult[0]?.nextval) {
          baseReadableId = String(seqResult[0].nextval)
        }
      } catch (seqErr) {
        console.warn('Warning: order_readable_id_seq query fallback:', seqErr)
      }

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
          const rawId = item.product.id || ''
          const isVariant = rawId.includes('_')
          const [_, variantNameFromId] = isVariant ? rawId.split('_') : [rawId, null]
          const variantName = item.selectedVariant || variantNameFromId
          
          let itemPrice = item.dbProduct.price
          let itemCostPrice = item.dbProduct.costPrice || 0
          if (variantName && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
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


        // Check if there is an existing PENDING & UNPAID order to reuse (Prevents duplicate ghost orders on payment retry)
        const targetExistingId = body.existingOrderId || body.orderId
        let existingPendingOrder: any = null

        if (targetExistingId) {
          existingPendingOrder = await tx.order.findFirst({
            where: {
              id: targetExistingId,
              userId: userId,
              status: OrderStatus.PENDING,
              paymentStatus: PaymentStatus.PENDING,
            },
            include: { items: true, address: true, user: true }
          })
        } else if (userId && orderInfo.total > 0) {
          const threeMinutesAgo = new Date(Date.now() - 180 * 1000)
          existingPendingOrder = await tx.order.findFirst({
            where: {
              userId: userId,
              status: OrderStatus.PENDING,
              paymentStatus: PaymentStatus.PENDING,
              createdAt: { gte: threeMinutesAgo },
              total: orderInfo.total,
              orderType: (orderInfo.type === 'RESTAURANT' || orderInfo.restaurantId) ? 'RESTAURANT' : 'GROCERY',
            },
            orderBy: { createdAt: 'desc' },
            include: { items: true, address: true, user: true }
          })
        }

        let newOrder: any
        if (existingPendingOrder) {
          // Delete old order items before re-attaching updated snapshot
          await tx.orderItem.deleteMany({
            where: { orderId: existingPendingOrder.id }
          })

          newOrder = await tx.order.update({
            where: { id: existingPendingOrder.id },
            data: {
              addressId: orderAddressId,
              paymentMethod: resolvedPaymentMethod,
              paymentStatus,
              notes: body.notes || orderInfo.notes || null,
              deliveryMethod,
              deliveryLat: address.lat,
              deliveryLng: address.lng,
              updatedAt: new Date(),
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
        } else {
          // Create new order
          newOrder = await tx.order.create({
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
              paymentMethod: resolvedPaymentMethod,
              paymentStatus,
              estimatedDelivery,
              deliveryMethod,
              isB2B: Boolean(isB2B),
              storeId: resolvedStoreId || storeId || null,
              couponCode: couponCode ? couponCode.toUpperCase() : null,
              shopName: orderInfo.type === 'RESTAURANT'
                ? (orderInfo.restaurant?.name || 'Restaurant')
                : (shopName || 'FastKirana Dark Store'),
              shopPhone: orderInfo.type === 'RESTAURANT'
                ? (orderInfo.restaurant?.ownerPhone || settingsMap['contact_phone'] || '+91 81128 49854')
                : shopPhone,
              notes: body.notes || orderInfo.notes || null,
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
        }

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

      if (isOnlinePaymentOrder && paymentStatus !== PaymentStatus.PAID) {
        // Don't send SSE, push, or WhatsApp for UNPAID online orders yet.
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
        if (settingsMap['order_alert_phone']) {
          const clean = settingsMap['order_alert_phone'].replace(/\D/g, '').slice(-10)
          if (clean && !adminPhones.includes(clean)) adminPhones.push(clean)
        }
        if (settingsMap['contact_phone']) {
          const clean = settingsMap['contact_phone'].replace(/\D/g, '').slice(-10)
          if (clean && !adminPhones.includes(clean)) adminPhones.push(clean)
        }

        const sentFcmTokensThisCheckout = new Set<string>()
        const notifiedWebRoles = new Set<string>()

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
            paymentStatus: order.paymentStatus,
            paymentMethod: order.paymentMethod,
            createdAt: order.createdAt,
            restaurantId: order.restaurantId,
          })

          // Send push notifications to workers (deduplicated per checkout across combined orders)
          if (isRestaurant) {
            // 1. Notify Admin & Delivery with full info
            const rolesToNotify = [Role.ADMIN, Role.DELIVERY].filter(r => !notifiedWebRoles.has(r))
            if (rolesToNotify.length > 0) {
              rolesToNotify.forEach(r => notifiedWebRoles.add(r))
              sendPushNotificationToRoles(rolesToNotify, {
                title: isOnlinePaid ? '💳 Online Payment Order Confirmed!' : notificationTitle,
                body: isOnlinePaid ? `Order #${displayId} of ₹${order.total} — PAID Online ✅` : `Order #${displayId} of ₹${order.total} has been placed.`,
                tag: `order-${order.id}`,
                data: { orderId: order.id }
              }).catch((err: any) => console.error('Error sending push notification to admins:', err))
            }

            // 2. Notify ONLY the specific Restaurant Owner / Chef WITHOUT ANY AMOUNT
            sendPushNotificationToRestaurant(order.restaurantId, {
              title: `👨‍🍳 New Food Order #${displayId}!`,
              body: `New order #${displayId} received for ${order.shopName || 'Kitchen'}. Tap to prepare dishes.`,
              tag: `restaurant-order-${order.id}`,
              data: { orderId: order.id, restaurantId: order.restaurantId }
            }).catch((err: any) => console.error('Error sending push notification to restaurant:', err))
          } else {
            // Pure Grocery order — ONLY notify Admin, Picker, Delivery. (CHEF/RESTAURANT NEVER NOTIFIED)
            const rolesToNotify = [Role.ADMIN, Role.PICKER, Role.DELIVERY].filter(r => !notifiedWebRoles.has(r))
            if (rolesToNotify.length > 0) {
              rolesToNotify.forEach(r => notifiedWebRoles.add(r))
              sendPushNotificationToRoles(rolesToNotify, {
                title: isOnlinePaid ? '💳 Online Payment Order Confirmed!' : notificationTitle,
                body: isOnlinePaid ? `Order #${displayId} of ₹${order.total} — PAID Online ✅` : `Order #${displayId} of ₹${order.total} has been placed.`,
                tag: `order-${order.id}`,
                data: { orderId: order.id }
              }).catch((err: any) => console.error('Error sending push notification to grocery staff:', err))
            }
          }

          // Send FCM Push Notification to Staff (Admin, Delivery, Picker, Restaurant)
          // Strictly deduplicated: each physical device token receives at most ONE notification per checkout
          try {
            const { fcmMessaging } = await import('@/lib/firebase-admin')
            if (fcmMessaging) {
              // 1. Direct device token push to Admin & Grocery Staff (Admin, Delivery, Picker)
              const staffRoles = isRestaurant ? ['ADMIN', 'DELIVERY'] : ['ADMIN', 'PICKER', 'DELIVERY']
              const staffPayload = buildOrderFcmPayload(
                isOnlinePaid ? '💳 New PAID Order Received!' : '🛎️ New Order Received!',
                `New order #${displayId} of ₹${order.total} has been placed.`,
                {
                  title: isOnlinePaid ? '💳 New PAID Order Received!' : '🛎️ New Order Received!',
                  body: `New order #${displayId} of ₹${order.total} has been placed.`,
                  orderId: order.id,
                  readableId: displayId,
                  status: order.status,
                  screen: 'admin-orders',
                  timestamp: Date.now().toString(),
                }
              )
              // Send FCM Push Notification to Staff (Admin, Delivery, Picker)
              // Broadcast to admin_orders (reaches all admins) and staff_orders (reaches delivery & pickers)
              // This guarantees EXACTLY ONE notification per device instead of 3x duplicates
              sendTopicWithRetry(fcmMessaging, { topic: 'admin_orders', ...staffPayload }).catch(() => {})
              if (!isRestaurant) {
                sendTopicWithRetry(fcmMessaging, { topic: 'staff_orders', ...staffPayload }).catch(() => {})
              }

              // 3. Direct device token push STRICTLY to the specific restaurant owner ONLY (WITHOUT AMOUNT)
              if (isRestaurant && order.restaurantId) {
                const restInfo = await prisma.restaurant.findUnique({
                  where: { id: order.restaurantId },
                  select: { ownerPhone: true }
                })
                const cleanRestPhone = restInfo?.ownerPhone ? getLast10Digits(restInfo.ownerPhone) : ''

                const restaurantPayload = buildOrderFcmPayload(
                  `👨‍🍳 New Order for ${order.shopName || 'Kitchen'}!`,
                  `Order #${displayId} received! Open kitchen console to prepare dishes.`,
                  {
                    title: `👨‍🍳 New Order for ${order.shopName || 'Kitchen'}!`,
                    body: `Order #${displayId} received! Open kitchen console to prepare dishes.`,
                    orderId: order.id,
                    readableId: displayId,
                    restaurantId: order.restaurantId,
                    status: order.status,
                    screen: 'restaurant-console',
                    timestamp: Date.now().toString(),
                  }
                )
                const restTokens = await prisma.fcmToken.findMany({
                  where: {
                    user: {
                      OR: [
                        { assignedRestaurantId: order.restaurantId },
                        ...(cleanRestPhone ? [{ phone: { contains: cleanRestPhone } }] : []),
                      ]
                    }
                  },
                  select: { token: true },
                  orderBy: { createdAt: 'desc' },
                  take: 10,
                })
                const uniqueRestTokens = Array.from(new Set(restTokens.map(t => t.token)))
                if (uniqueRestTokens.length > 0) {
                  // Direct token delivery to registered restaurant devices (Fastest, exactly 1 delivery per device)
                  for (const token of uniqueRestTokens) {
                    if (!sentFcmTokensThisCheckout.has(token)) {
                      sentFcmTokensThisCheckout.add(token)
                      fcmMessaging.send({ token, ...restaurantPayload }).catch(() => {})
                    }
                  }
                }
                // Always broadcast to canonical restaurant topic for guaranteed delivery
                if (order.restaurantId) {
                  sendTopicWithRetry(fcmMessaging, { topic: `restaurant_${order.restaurantId}`, ...restaurantPayload }).catch(() => {})
                  sendTopicWithRetry(fcmMessaging, { topic: `kitchen_${order.restaurantId}`, ...restaurantPayload }).catch(() => {})
                }
              }
            }
          } catch (fcmErr) {
            console.error('Customer order placement FCM error:', fcmErr)
          }

          const whatsappPromises: Promise<any>[] = []

          // 2. Automated KOT Remote Broadcast: DISABLED by business rule.
          // KOT is strictly controlled by Admin and is ONLY dispatched when Admin clicks "Send KOT" in the Admin Dashboard (/admin).


          // 3. WhatsApp Alert to Admins/Staff
          if (adminPhones.length > 0) {
            const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
            const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
            const outletName = order.shopName || (isRestaurant ? 'Restaurant' : 'FastKirana Dark Store')
            const customerName = order.user?.name || 'Customer'
            const customerPhone = order.address?.phone || order.user?.phone || 'N/A'
            const adminText = isOnlinePaid
              ? `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${order.total} from ${customerName} (${customerPhone}). Payment: Online PAID ✅. Manage: ${cleanAppUrl}/admin`
              : `New Order #${displayId} for [${outletName}] of ₹${order.total} from ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`
            
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

        // =========================================================================
        // Send EXACTLY 1 Customer Notification for the entire checkout
        // Consolidates Combined Orders (Grocery + Food) into a single notification!
        // =========================================================================
        try {
          const primaryOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
          const isCombined = createdOrders.length > 1
          const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')
          const combinedTotal = createdOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
          const customerPhone = primaryOrder.address?.phone || primaryOrder.user?.phone || body.phone || ''
          const cleanPhone = getLast10Digits(customerPhone)

          const { fcmMessaging } = await import('@/lib/firebase-admin')
          if (fcmMessaging) {
            const notifTitle = isOnlinePaid
              ? (isCombined ? '💳 Combined Order Confirmed & Paid!' : '💳 Order Confirmed & Paid!')
              : (isCombined ? '📦 Combined Order Placed Successfully!' : '📦 Order Placed Successfully!')
            const notifBody = isCombined
              ? `Your FastKirana combined order #${baseDisplayId} (₹${combinedTotal.toFixed(0)}) is confirmed and being prepared.`
              : `Your FastKirana order #${primaryOrder.readableId || primaryOrder.id} (₹${Number(primaryOrder.total).toFixed(0)}) is confirmed and being prepared.`

            const dataPayload: Record<string, string> = {
              title: notifTitle,
              body: notifBody,
              orderId: primaryOrder.id,
              readableId: baseDisplayId,
              status: primaryOrder.status,
              screen: 'order-tracking',
              url: `/orders/${primaryOrder.id}`,
              timestamp: Date.now().toString(),
            }

            const custPayload = buildOrderFcmPayload(notifTitle, notifBody, dataPayload)

            // Direct device token push to customer's latest active device (Exact 1 push)
            const customerTokens = await prisma.fcmToken.findMany({
              where: {
                OR: [
                  ...(primaryOrder.userId ? [{ userId: primaryOrder.userId }] : []),
                  ...(cleanPhone ? [{ user: { phone: { contains: cleanPhone } } }] : []),
                ],
              },
              select: { token: true },
              orderBy: { createdAt: 'desc' },
              take: 1,
            })

            if (customerTokens.length > 0) {
              const custToken = customerTokens[0].token
              if (!sentFcmTokensThisCheckout.has(custToken)) {
                sentFcmTokensThisCheckout.add(custToken)
                fcmMessaging.send({ token: custToken, ...custPayload }).catch((e) => console.error('Error sending customer FCM:', e))
              }
            } else if (cleanPhone && cleanPhone.length === 10) {
              await sendTopicWithRetry(fcmMessaging, { topic: `phone_${cleanPhone}`, ...custPayload }).catch((e) => console.error('Error sending customer topic FCM:', e))
            }
          }
        } catch (custNotifErr) {
          console.error('Unified customer order FCM notification error:', custNotifErr)
        }
      } catch (sseErr) {
        console.error('Failed to emit SSE/notifications for new orders:', sseErr)
      }
    })

    const mainOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
    return NextResponse.json({
      ...mainOrder,
      order: mainOrder,
      orders: createdOrders,
      readableId: mainOrder.readableId,
      id: mainOrder.id,
    })
  } catch (error: any) {
    console.error('Order creation error:', error)
    return NextResponse.json({ error: error.message || 'Failed to place order' }, { status: 500 })
  } finally {
    if (userId) {
      inFlightOrderPlacements.delete(userId)
    }
  }
}

export async function GET(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  const session = await auth()
  const { searchParams } = new URL(request.url)
  const queryUserId = searchParams.get('userId')
  const queryPhone = searchParams.get('phone') || searchParams.get('customerPhone')

  let userId = session?.user?.id || request.headers.get('x-user-id') || queryUserId
  const headerPhone = request.headers.get('x-user-phone') || queryPhone
  let sessionPhone = (session?.user as any)?.phone ? getLast10Digits((session.user as any).phone) : (headerPhone ? getLast10Digits(headerPhone) : '')

  if (!userId && sessionPhone) {
    const dbUser = await prisma.user.findFirst({
      where: {
        OR: [
          { phone: sessionPhone },
          { phone: `+91${sessionPhone}` },
          { phone: { contains: sessionPhone } }
        ]
      }
    })
    if (dbUser) userId = dbUser.id
  }

  if (!userId && !sessionPhone) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { searchParams } = new URL(request.url)
    const all = searchParams.get('all') === 'true'
    const storeId = searchParams.get('storeId') || (session?.user as any)?.assignedStoreId || null
    const isStaff = session?.user?.role === 'ADMIN' || session?.user?.role === 'CHEF' || session?.user?.role === 'PICKER' || session?.user?.role === 'DELIVERY'

    let orders: any[] = []

    if (isStaff && all) {
      // Staff queries orders with associated customer details, filtered by store
      if (storeId && storeId !== 'all') {
        orders = await prisma.$queryRaw`
          SELECT o.id, o."userId", o."addressId", o."readableId",
                 o.status::text as status,
                 o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                 o."paymentMethod"::text as "paymentMethod",
                 o."paymentStatus"::text as "paymentStatus",
                 o."estimatedDelivery", o."createdAt", o."updatedAt",
                 o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone", o."restaurantId", o."storeId",
                 u.name as "userName", u.email as "userEmail", u.phone as "userPhone"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o."storeId" = ${storeId}
          ORDER BY o."createdAt" DESC
          LIMIT 1000
        `
      } else {
        orders = await prisma.$queryRaw`
          SELECT o.id, o."userId", o."addressId", o."readableId",
                 o.status::text as status,
                 o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                 o."paymentMethod"::text as "paymentMethod",
                 o."paymentStatus"::text as "paymentStatus",
                 o."estimatedDelivery", o."createdAt", o."updatedAt",
                 o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone", o."restaurantId", o."storeId",
                 u.name as "userName", u.email as "userEmail", u.phone as "userPhone"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          ORDER BY o."createdAt" DESC
          LIMIT 1000
        `
      }
    } else {
      // Normal user queries their orders by userId, email, or phone match
      const sessionEmail = session?.user?.email ? session.user.email.toLowerCase().trim() : ''

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
        WHERE (o."userId" = ${userId || ''})
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
          readableId: o.readableId,
          type: o.restaurantId ? 'RESTAURANT' : 'GROCERY',
          restaurantId: o.restaurantId,
          shopName: o.restaurantId ? (o.shopName || (o.restaurant?.name) || 'Restaurant') : (o.shopName || 'FastKirana Dark Store'),
          status: o.status,
          total: o.total,
          itemsCount: o.items?.length || 0,
          items: o.items || [],
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

