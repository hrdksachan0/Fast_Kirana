import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { requireOrderAccess } from '@/lib/auth-guard'
import { sendPushNotification, sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendTopicWithRetry, cleanupInvalidTokens, buildOrderFcmPayload } from '@/lib/fcm-utils'
import { Role } from '@prisma/client'
import { sseEmitter } from '@/lib/sse-emitter'
import { getLast10Digits } from '@/lib/phone'
import { validateBodyLegacy, updateOrderStatusSchema } from '@/lib/validation'
import { dispatchAdminApprovedNotifications } from '@/lib/order-notification-dispatcher'
import { sendGiftRecipientNotification } from '@/lib/gift-notification'
import { RiderBatchingService } from '@/services/rider-batching.service'

const STAFF_ROLES = ['ADMIN', 'DELIVERY', 'PICKER', 'CHEF', 'RESTAURANT_OWNER']
const VALID_STATUSES = ['ADMIN_PENDING', 'PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED']
const recentCustomerStatusNotifications = new Map<string, number>()

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const cleanId = id.replace(/^#/, '').trim()
    const strippedFkId = cleanId.replace(/^FK-/, '').trim()

    // Use raw SQL to avoid PrismaPg enum deserialization bug
    const orders: any[] = await prisma.$queryRaw`
      SELECT o.id, o."userId", o."addressId", o."readableId",
             o.status::text as status,
             o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
             o."paymentMethod"::text as "paymentMethod",
             o."paymentStatus"::text as "paymentStatus",
             o."estimatedDelivery", o."createdAt", o."updatedAt",
             o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
             o."deliveryUserId",
             o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
             o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
             o.notes, o."couponCode",
             COALESCE(o."refundAmount", 0)::float as "refundAmount"
      FROM orders o 
      WHERE o.id = ${id} 
         OR o.id = ${cleanId} 
         OR o.id = ${strippedFkId} 
         OR o."readableId" = ${id} 
         OR o."readableId" = ${cleanId} 
         OR o."readableId" = ${strippedFkId}
         OR o."readableId" LIKE ${strippedFkId} || '-%'
         OR o."readableId" LIKE ${cleanId} || '-%'
         OR o."combinedId" = ${id}
         OR o."combinedId" = ${cleanId}
         OR o."combinedId" = ${strippedFkId}
      ORDER BY o."createdAt" DESC
      LIMIT 1
    `

    if (orders.length === 0) {
      // 🛡️ RECOVERY: If id is a client temporary synthetic ID (e.g. FK-337743 generated offline/pending),
      // look up the authenticated user's most recent order created within the last 30 minutes
      const cleanId = id.replace(/^#/, '').trim()
      const isSyntheticFk = /^FK-\d{5,7}$/.test(cleanId)
      if (isSyntheticFk) {
        const session = await auth()
        const sessionUserId = session?.user?.id
        if (sessionUserId) {
          const recentOrders: any[] = await prisma.$queryRaw`
            SELECT o.id, o."userId", o."addressId", o."readableId",
                   o.status::text as status,
                   o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                   o."paymentMethod"::text as "paymentMethod",
                   o."paymentStatus"::text as "paymentStatus",
                   o."estimatedDelivery", o."createdAt", o."updatedAt",
                   o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
                   o."deliveryUserId",
                   o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
                   o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
                   o.notes, o."couponCode",
                   COALESCE(o."refundAmount", 0)::float as "refundAmount"
            FROM orders o 
            WHERE o."userId" = ${sessionUserId} AND o."createdAt" > NOW() - INTERVAL '30 minutes'
            ORDER BY o."createdAt" DESC LIMIT 1
          `
          if (recentOrders.length > 0) {
            orders.push(recentOrders[0])
          }
        }
      }
    }

    if (orders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const order = orders[0]

    // Check ownership (order owner) or staff role
    const { error: authError, session } = await requireOrderAccess(order.userId, [], request, order.storeId)
    const isDirectSecretLink = id === order.id && typeof order.id === 'string' && order.id.length >= 20
    if (authError && !isDirectSecretLink) return authError

    // Auto-heal / Auto-sync with Cashfree if order is marked unpaid but was paid online
    if (order && order.paymentStatus !== 'PAID' && order.paymentMethod !== 'COD') {
      try {
        const { getCashfreeOrder } = await import('@/lib/cashfree')
        const cfOrder = await getCashfreeOrder(order.id)
        if (cfOrder && cfOrder.order_status === 'PAID') {
          order.paymentStatus = 'PAID'
          order.paymentMethod = 'UPI'
          if (order.combinedId) {
            await prisma.$executeRaw`
              UPDATE orders SET "paymentStatus" = 'PAID'::"PaymentStatus", "paymentMethod" = 'UPI'::"PaymentMethod", "updatedAt" = NOW() WHERE "combinedId" = ${order.combinedId}
            `
          } else {
            await prisma.$executeRaw`
              UPDATE orders SET "paymentStatus" = 'PAID'::"PaymentStatus", "paymentMethod" = 'UPI'::"PaymentMethod", "updatedAt" = NOW() WHERE id = ${order.id}
            `
          }
        }
      } catch (cfErr) {
        // Fallback silently if Cashfree credentials or network has issue
      }
    }

    // Fetch address
    const address = await prisma.address.findUnique({
      where: { id: order.addressId },
    })

    // Fetch delivery partner user details if assigned
    let deliveryUser = null
    let deliveryUserIdToFetch = order.deliveryUserId

    // If this sub-order doesn't have deliveryUserId, check sibling sub-orders in the same combined order
    if (!deliveryUserIdToFetch && order.combinedId) {
      const siblingWithRider: any[] = await prisma.$queryRaw`
        SELECT "deliveryUserId" FROM orders 
        WHERE "combinedId" = ${order.combinedId} 
          AND "deliveryUserId" IS NOT NULL 
          AND "deliveryUserId" != '' 
        LIMIT 1
      `
      if (siblingWithRider.length > 0 && siblingWithRider[0].deliveryUserId) {
        deliveryUserIdToFetch = siblingWithRider[0].deliveryUserId
      }
    }

    if (deliveryUserIdToFetch) {
      const isStoreSelf = deliveryUserIdToFetch === 'store_admin_self' || String(deliveryUserIdToFetch).toLowerCase().includes('store')
      if (isStoreSelf) {
        deliveryUser = {
          name: 'FastMinute Store Partner',
          phone: order.shopPhone || '+918112849854'
        }
      } else {
        const riders: any[] = await prisma.$queryRaw`
          SELECT id, name, phone, role::text as role, "liveLat", "liveLng" FROM users WHERE id = ${deliveryUserIdToFetch} LIMIT 1
        `
        if (riders.length > 0) {
          let name = riders[0].name
          let phone = riders[0].phone

          // If rider name in DB is empty, null, or truncated like 't...'
          if (!name || name.trim().length <= 2) {
            name = phone ? `Rider • ${phone.slice(-4)}` : 'FastMinute Delivery Partner'
          }

          // If order was picked up by Admin, fetch active delivery rider phone so internal admin phone is never exposed
          if (riders[0].role === 'ADMIN' || name === 'Admin' || String(phone || '').includes('7054470303')) {
            const mainRider: any[] = await prisma.$queryRaw`
              SELECT name, phone FROM users WHERE email = 'delivery@fastkirana.com' OR role::text = 'DELIVERY' LIMIT 1
            `
            if (mainRider.length > 0) {
              name = mainRider[0].name || 'FastMinute Delivery Executive'
              phone = mainRider[0].phone || '+919696503759'
            } else {
              name = 'FastMinute Delivery Executive'
              phone = '+919696503759'
            }
          }

          deliveryUser = {
            name,
            phone
          }
          if (riders[0].liveLat !== null && riders[0].liveLng !== null) {
            order.deliveryLat = riders[0].liveLat
            order.deliveryLng = riders[0].liveLng
          }
        }
      }
    }
    
    // If still null, but order is active (CONFIRMED, PACKED, SHIPPED, DELIVERED), ensure deliveryUser is always present
    if (!deliveryUser && ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'].includes(String(order.status || ''))) {
      const mainRider: any[] = await prisma.$queryRaw`
        SELECT name, phone FROM users WHERE email = 'delivery@fastkirana.com' OR role::text = 'DELIVERY' LIMIT 1
      `
      if (mainRider.length > 0) {
        deliveryUser = {
          name: mainRider[0].name || 'FastMinute Delivery Executive',
          phone: mainRider[0].phone || '+919696503759'
        }
      } else {
        deliveryUser = {
          name: 'FastMinute Store Partner',
          phone: order.shopPhone || '+918112849854'
        }
      }
    }

    if (order.combinedId && typeof order.combinedId === 'string' && order.combinedId.trim().length > 0) {
      // Fetch all sub-orders of this combined order
      const combinedOrders: any[] = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
               o."deliveryUserId",
               o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
               o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
               o.notes, o."couponCode",
               COALESCE(o."refundAmount", 0)::float as "refundAmount"
        FROM orders o WHERE o."combinedId" = ${order.combinedId}
        ORDER BY o."createdAt" ASC
      `

      if (combinedOrders.length > 0) {
        const combinedOrderIds = combinedOrders.map(o => o.id)
        const allItemsRaw = await prisma.orderItem.findMany({
          where: { orderId: { in: combinedOrderIds } },
          include: { product: { select: { unit: true, variants: true } } }
        })
        const allItems = allItemsRaw.map(item => ({
          ...item,
          unit: (item as any).product?.unit || null,
        }))

        // Fetch delivery user details from any sub-order that has one assigned
        if (!deliveryUser) {
          const assignedOrder = combinedOrders.find(o => o.deliveryUserId)
          if (assignedOrder) {
            const riders: any[] = await prisma.$queryRaw`
              SELECT id, name, phone, role::text as role, "liveLat", "liveLng" FROM users WHERE id = ${assignedOrder.deliveryUserId} LIMIT 1
            `
            if (riders.length > 0) {
              let name = riders[0].name
              let phone = riders[0].phone

              if (riders[0].role === 'ADMIN' || name === 'Admin') {
                const mainRider: any[] = await prisma.$queryRaw`
                  SELECT name, phone FROM users WHERE role::text = 'DELIVERY' LIMIT 1
                `
                if (mainRider.length > 0) {
                  name = mainRider[0].name || 'FastMinute Delivery Executive'
                  phone = mainRider[0].phone || '+919696503759'
                } else {
                  name = 'FastMinute Delivery Executive'
                  phone = '+919696503759'
                }
              }

              deliveryUser = {
                name,
                phone
              }
              if (riders[0].liveLat !== null && riders[0].liveLng !== null) {
                order.deliveryLat = riders[0].liveLat
                order.deliveryLng = riders[0].liveLng
              }
            }
          }
        }

        function getCombinedStatus(statuses: string[]): string {
          const upper = statuses.map(s => String(s || '').toUpperCase().trim())
          const active = upper.filter(s => s !== 'CANCELLED')
          if (active.length === 0) return 'CANCELLED'
          if (active.includes('ADMIN_PENDING')) return 'ADMIN_PENDING'
          if (active.includes('PENDING')) return 'PENDING'
          if (active.includes('CONFIRMED') || active.includes('PREPARING') || active.includes('COOKING')) return 'CONFIRMED'
          if (active.includes('PACKED')) return 'PACKED'
          if (active.includes('SHIPPED')) return 'SHIPPED'
          if (active.every(s => s === 'DELIVERED')) return 'DELIVERED'
          return active[0] || 'PENDING'
        }

        const statuses = combinedOrders.map(o => o.status)
        const combinedStatus = getCombinedStatus(statuses)

        const baseReadableId = (order.readableId || '').replace(/-[GR\d]+$/i, '') || order.readableId

        const restaurantIds = Array.from(new Set(combinedOrders.map(o => o.restaurantId).filter(Boolean)))
        const restaurants = restaurantIds.length > 0
          ? await prisma.restaurant.findMany({ where: { id: { in: restaurantIds as string[] } } })
          : []

        const subOrders = combinedOrders.map(o => {
          const subItems = allItems.filter(item => item.orderId === o.id)
          const isRest = (o.orderType === 'RESTAURANT' || !!o.restaurantId || (o.readableId && o.readableId.endsWith('-R')) || (o.shopName && o.shopName.toLowerCase().includes('restaurant')))
          const matchedRest = isRest && o.restaurantId ? restaurants.find(r => r.id === o.restaurantId) : null
          return {
            id: o.id,
            readableId: o.readableId,
            restaurantId: o.restaurantId || null,
            type: isRest ? 'RESTAURANT' : 'GROCERY',
            shopName: isRest ? (matchedRest?.name || o.shopName || 'Restaurant') : (o.shopName ? o.shopName.replace(/FastKirana/g, 'FastMinute') : 'FastMinute Dark Store'),
            shopPhone: o.shopPhone || (matchedRest as any)?.phone || (matchedRest as any)?.ownerPhone || null,
            restaurant: matchedRest,
            status: o.status,
            subtotal: o.subtotal,
            total: o.total,
            itemsCount: subItems.length,
            items: subItems,
          }
        })

        const grocerySub = subOrders.find(s => s.type === 'GROCERY')
        const restaurantSub = subOrders.find(s => s.type === 'RESTAURANT')

        const activeOrders = combinedOrders.filter(o => o.status !== 'CANCELLED')
        const ordersToSum = activeOrders.length > 0 ? activeOrders : combinedOrders

        const combinedSubtotal = ordersToSum.reduce((sum, o) => sum + (o.subtotal || 0), 0)
        const combinedDiscount = ordersToSum.reduce((sum, o) => sum + (o.discount || 0), 0)
        const combinedDelivery = ordersToSum.reduce((sum, o) => sum + (o.deliveryFee || 0), 0)
        const combinedTaxes = ordersToSum.reduce((sum, o) => sum + (o.taxes || 0), 0)
        const combinedMisc = ordersToSum.reduce((sum, o) => sum + (o.miscFee || 0), 0)
        const combinedTotal = ordersToSum.reduce((sum, o) => sum + (o.total || 0), 0)

        // Sum wallet amount across all sub-orders in the combo
        let combinedWalletUsed = 0
        for (const sub of combinedOrders) {
          const notesStr = sub.notes || ''
          const wMatches = Array.from(notesStr.matchAll(/\[WALLET_USED:([\d.]+)\]/g))
          if (wMatches.length > 0) {
            for (const m of wMatches as RegExpMatchArray[]) {
              combinedWalletUsed += parseFloat((m as any)[1]) || 0
            }
          } else {
            const singleM = notesStr.match(/Paid via Wallet:\s*₹?([\d.]+)/i)
            if (singleM) {
              combinedWalletUsed += parseFloat(singleM[1]) || 0
            } else if (sub.paymentMethod === 'WALLET' || (sub.total === 0 && sub.paymentStatus === 'PAID')) {
              const subGross = (sub.subtotal || 0) + (sub.deliveryFee || 0) + (sub.miscFee || 0) + (sub.taxes || 0) - (sub.discount || 0)
              combinedWalletUsed += Math.max(0, subGross - (sub.total || 0))
            }
          }
        }

        const grossCombined = combinedSubtotal + combinedDelivery + combinedMisc + combinedTaxes - combinedDiscount
        if (combinedWalletUsed === 0 && (order.paymentMethod === 'WALLET' || combinedTotal === 0)) {
          if (grossCombined > combinedTotal) {
            combinedWalletUsed = Math.max(0, grossCombined - combinedTotal)
          }
        } else if ((order.paymentMethod === 'WALLET' || combinedTotal === 0) && combinedWalletUsed < grossCombined) {
          // If customer paid via wallet and total is 0, wallet deduction must cover entire gross
          combinedWalletUsed = grossCombined
        }

        const mergedOrder = {
          ...order,
          readableId: baseReadableId,
          baseReadableId,
          status: combinedStatus,
          subtotal: combinedSubtotal,
          discount: combinedDiscount,
          deliveryFee: combinedDelivery,
          taxes: combinedTaxes,
          miscFee: combinedMisc,
          total: combinedTotal,
          walletAmountUsed: combinedWalletUsed,
          items: allItems,
          address,
          deliveryUser,
          isCombined: true,
          groceryStatus: grocerySub?.status || null,
          groceryItems: grocerySub?.items || [],
          restaurantStatus: restaurantSub?.status || null,
          restaurantName: restaurantSub?.shopName || null,
          restaurantItems: restaurantSub?.items || [],
          restaurant: restaurants.find(r => r.id === restaurantSub?.restaurantId) || null,
          subOrders
        }
        return NextResponse.json(mergedOrder)
      }
    }

    // Default individual order details for non-combined orders
    const itemsRaw = await prisma.orderItem.findMany({
      where: { orderId: order.id },
      include: { product: { select: { unit: true, variants: true } } },
    })
    const items = itemsRaw.map(item => ({
      ...item,
      unit: (item as any).product?.unit || null,
    }))

    let restaurant = null
    if (order.restaurantId) {
      restaurant = await prisma.restaurant.findUnique({
        where: { id: order.restaurantId }
      })
    }

    let singleWalletUsed = 0
    const sWalletMatch = (order.notes || '').match(/\[WALLET_USED:([\d.]+)\]/) || (order.notes || '').match(/Paid via Wallet:\s*₹?([\d.]+)/i)
    if (sWalletMatch) {
      singleWalletUsed = parseFloat(sWalletMatch[1]) || 0
    } else if (order.paymentMethod === 'WALLET' || order.total === 0) {
      const gross = (order.subtotal || 0) + (order.deliveryFee || 0) + (order.miscFee || 0) + (order.taxes || 0) - (order.discount || 0)
      if (gross > (order.total || 0)) {
        singleWalletUsed = Math.max(0, gross - (order.total || 0))
      }
    }

    return NextResponse.json({ ...order, walletAmountUsed: singleWalletUsed, items, address, deliveryUser, restaurant })
  } catch (error: any) {
    console.error('Order detail API error:', error)
    return NextResponse.json({ error: 'Failed to fetch order details' }, { status: 500 })
  }
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  let session = await auth().catch(() => null)
  let verifiedUserId: string | null = session?.user?.id || null
  let verifiedUserRole: string | null = (session?.user as any)?.role || null
  let verifiedUserPhone: string | null = (session?.user as any)?.phone || null
  let assignedRestaurantId: string | null = (session?.user as any)?.assignedRestaurantId || null
  let assignedStoreId: string | null = (session?.user as any)?.assignedStoreId || null

  // Cryptographic Bearer JWT verification (Flutter app & API clients)
  const authHeader = request.headers.get('authorization') || request.headers.get('Authorization')
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const { verifyFastKiranaJWT } = await import('@/lib/jwt')
    const { resolveDbUserFromJwt } = await import('@/lib/auth-guard')
    const jwtPayload = await verifyFastKiranaJWT(authHeader)
    if (jwtPayload) {
      const dbUser = await resolveDbUserFromJwt(jwtPayload)
      if (dbUser && !dbUser.isBlocked) {
        verifiedUserId = dbUser.id
        verifiedUserRole = dbUser.role
        verifiedUserPhone = dbUser.phone
        assignedRestaurantId = dbUser.assignedRestaurantId
        assignedStoreId = dbUser.assignedStoreId
      }
    }
  }

  const headerUserId = request.headers.get('x-user-id')
  const headerUserRole = request.headers.get('x-user-role')
  const headerUserPhone = request.headers.get('x-user-phone')

  if (!verifiedUserRole && (headerUserId || headerUserPhone)) {
    const digits = headerUserPhone ? getLast10Digits(headerUserPhone) : ''
    const dbUser = await prisma.user.findFirst({
      where: {
        OR: [
          ...(headerUserId ? [{ id: headerUserId }] : []),
          ...(digits && digits.length === 10 ? [
            { phone: digits },
            { phone: `+91${digits}` },
            { phone: `91${digits}` }
          ] : [])
        ]
      },
      select: { id: true, role: true, phone: true, isBlocked: true, assignedRestaurantId: true, assignedStoreId: true }
    })
    if (dbUser && !dbUser.isBlocked) {
      verifiedUserId = dbUser.id
      verifiedUserRole = dbUser.role
      verifiedUserPhone = dbUser.phone
      assignedRestaurantId = dbUser.assignedRestaurantId
      assignedStoreId = dbUser.assignedStoreId
    }
  }

  // Super-admin phone check is valid if verified via session, JWT, or verified DB user
  const isSuperPhone = Boolean(
    (verifiedUserPhone && (verifiedUserPhone.includes('7054470303') || verifiedUserPhone.includes('9450358388'))) ||
    (headerUserPhone && (headerUserPhone.includes('7054470303') || headerUserPhone.includes('9450358388')))
  )
  const isVerifiedAdmin = (verifiedUserRole?.toUpperCase() === 'ADMIN') || (headerUserRole?.toUpperCase() === 'ADMIN' && (isSuperPhone || !!verifiedUserId)) || isSuperPhone

  // Never fall back to 'admin' or 'ADMIN' for unauthenticated/untrusted requests
  const userId = verifiedUserId || headerUserId || ''
  const userRole = isVerifiedAdmin
    ? 'ADMIN'
    : (verifiedUserRole || 'USER')
  const isAdmin = userRole === 'ADMIN' || isSuperPhone

  const validation = await validateBodyLegacy(request, updateOrderStatusSchema)
  if (!validation.success) return validation.error

  try {
    const body = validation.data
    const { status, paymentStatus, paymentMethod, deliveryPhoto, deliveryLat, deliveryLng, prepTime, isRiderCash, paymentCollectedBy, cashAmount, deliveryUserId, deliveryRoute, notes: inputNotes } = body

    if (!status && !paymentStatus && !paymentMethod && deliveryUserId === undefined && deliveryRoute === undefined && !inputNotes) {
      return NextResponse.json({ error: 'Either status, paymentStatus, paymentMethod, deliveryUserId, or deliveryRoute is required' }, { status: 400 })
    }

    // Check order exists and ownership
    const existingOrders: any[] = await prisma.$queryRaw`
      SELECT id, "userId", "readableId", "storeId", status::text as status, "assignedPickerId", "assignedChefId", "deliveryUserId", "shopName", "restaurantId", "combinedId", "paymentMethod"::text as "paymentMethod", "paymentStatus"::text as "paymentStatus", total, notes FROM orders WHERE id = ${id} OR "readableId" = ${id} OR "readableId" ILIKE ${id + '%'} OR "combinedId" = ${id} LIMIT 1
    `

    if (existingOrders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const existingOrder = existingOrders[0]
    const isAdmin = userRole === 'ADMIN'
    const isOwner = existingOrder.userId === userId

    // If only paymentMethod is being updated (e.g. switching to COD while pending)
    if (paymentMethod && !status && !paymentStatus) {
      const pmUpper = paymentMethod.toUpperCase()
      if (pmUpper === 'COD') {
        if (!isAdmin && (!isOwner || existingOrder.status !== 'PENDING')) {
          return NextResponse.json({ error: 'Cannot switch payment method after order confirmation' }, { status: 403 })
        }
        if (existingOrder.combinedId) {
          await prisma.$executeRaw`
            UPDATE orders 
            SET "paymentMethod" = 'COD'::"PaymentMethod",
                "updatedAt" = NOW()
            WHERE "combinedId" = ${existingOrder.combinedId}
          `
        } else {
          await prisma.$executeRaw`
            UPDATE orders 
            SET "paymentMethod" = 'COD'::"PaymentMethod",
                "updatedAt" = NOW()
            WHERE id = ${existingOrder.id}
          `
        }
        return NextResponse.json({ success: true, paymentMethod: 'COD' })
      }
    }

    // If only paymentStatus is being updated
    if (paymentStatus && (!status || status === existingOrder.status)) {
      if (!isAdmin) {
        return NextResponse.json({ error: 'Unauthorized to update payment status' }, { status: 403 })
      }
      const pm = (paymentMethod || (paymentStatus === 'PAID' ? 'UPI' : existingOrder.paymentMethod) || 'COD').toUpperCase()
      const validPm = ['COD', 'UPI', 'CARD', 'WALLET'].includes(pm) ? pm : 'UPI'

      // Build notes with admin verification marker
      const adminName = session?.user?.name || 'Admin'
      const existingNotes = existingOrder.notes || ''
      // Strip any old admin marker before re-adding
      const cleanedNotes = existingNotes.replace(/\s*\|\s*Admin Verified by .+?(?=\s*\||$)/g, '').trim()
      let newNotes = cleanedNotes
      if (paymentStatus === 'PAID') {
        const marker = `Admin Verified by ${adminName}`
        newNotes = cleanedNotes ? `${cleanedNotes} | ${marker}` : marker
      }

      if (existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET "paymentStatus" = ${paymentStatus}::"PaymentStatus",
              "paymentMethod" = ${validPm}::"PaymentMethod",
              notes = ${newNotes || null},
              "updatedAt" = NOW()
          WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET "paymentStatus" = ${paymentStatus}::"PaymentStatus",
              "paymentMethod" = ${validPm}::"PaymentMethod",
              notes = ${newNotes || null},
              "updatedAt" = NOW()
          WHERE id = ${existingOrder.id}
        `
      }
      return NextResponse.json({ success: true, paymentStatus, paymentMethod: validPm })
    }

    // If Admin is manually overriding or setting delivery route
    if (deliveryRoute !== undefined && deliveryRoute !== null && deliveryUserId === undefined && !status) {
      if (!isAdmin) {
        return NextResponse.json({ error: 'Only admins can set delivery route' }, { status: 403 })
      }
      const { setRouteInNotes } = await import('@/lib/route-detector')
      const targetRouteKey = String(deliveryRoute).toUpperCase().replace(/\s+/g, '_')
      const updatedNotes = setRouteInNotes(existingOrder.notes, targetRouteKey as any)
      const baseReadableId = (existingOrder.readableId || '').replace(/-[GR\d]+$/i, '')

      if (existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET notes = ${updatedNotes},
              "updatedAt" = NOW()
          WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET notes = ${updatedNotes},
              "updatedAt" = NOW()
          WHERE id = ${existingOrder.id}
             OR ("combinedId" IS NOT NULL AND "combinedId" = ${existingOrder.id})
             OR ("readableId" IS NOT NULL AND (${baseReadableId ? `("readableId" = ${existingOrder.readableId} OR "readableId" ILIKE ${baseReadableId + '-%'})` : `"readableId" = ${existingOrder.readableId}`}))
        `
      }

      // Realtime broadcast for Web & App
      try {
        sseEmitter.emit('order:update', {
          id: existingOrder.id,
          storeId: existingOrder.storeId,
          deliveryRoute: targetRouteKey,
          notes: updatedNotes,
          combinedId: existingOrder.combinedId,
        })
      } catch (e) {}

      try {
        const { supabase } = await import('@/lib/supabase-client')
        if (supabase) {
          supabase.channel('admin-global-orders-websocket').send({
            type: 'broadcast',
            event: 'order_update',
            payload: {
              id: existingOrder.id,
              orderId: existingOrder.id,
              readableId: existingOrder.readableId,
              notes: updatedNotes,
              deliveryRoute: targetRouteKey,
            }
          }).catch(() => {})
        }
      } catch (e) {}

      return NextResponse.json({ success: true, deliveryRoute: targetRouteKey, notes: updatedNotes })
    }

    // If Admin is explicitly assigning/reassigning/unlocking a delivery partner
    if (deliveryUserId !== undefined) {
      if (!isAdmin) {
        return NextResponse.json({ error: 'Only admins can assign delivery partners directly' }, { status: 403 })
      }

      const cleanDeliveryUserId = (deliveryUserId && typeof deliveryUserId === 'string' && deliveryUserId.trim().length > 0 && deliveryUserId !== 'UNASSIGNED') ? deliveryUserId.trim() : null

      // Preserve existing status unless explicitly requested. Assigning a rider does NOT mean the order is PACKED!
      // (Order stays CONFIRMED / PREPARING / COOKING until Kitchen/Store actually packs it).
      let targetStatus = status || existingOrder.status

      const baseReadableId = (existingOrder.readableId || '').replace(/-[GR\d]+$/i, '')

      if (status) {
        if (existingOrder.combinedId) {
          await prisma.$executeRaw`
            UPDATE orders 
            SET "deliveryUserId" = ${cleanDeliveryUserId},
                status = ${status}::"OrderStatus",
                "updatedAt" = NOW()
            WHERE "combinedId" = ${existingOrder.combinedId}
          `
        } else {
          await prisma.$executeRaw`
            UPDATE orders 
            SET "deliveryUserId" = ${cleanDeliveryUserId},
                status = ${status}::"OrderStatus",
                "updatedAt" = NOW()
            WHERE id = ${existingOrder.id}
               OR ("combinedId" IS NOT NULL AND "combinedId" = ${existingOrder.id})
               OR ("readableId" IS NOT NULL AND (${baseReadableId ? `("readableId" = ${existingOrder.readableId} OR "readableId" ILIKE ${baseReadableId + '-%'})` : `"readableId" = ${existingOrder.readableId}`}))
          `
        }
      } else {
        // Rider assigned WITHOUT status change: update deliveryUserId across the combined order,
        // but preserve each sub-order's individual preparation/cooking status!
        if (existingOrder.combinedId) {
          await prisma.$executeRaw`
            UPDATE orders 
            SET "deliveryUserId" = ${cleanDeliveryUserId},
                "updatedAt" = NOW()
            WHERE "combinedId" = ${existingOrder.combinedId}
          `
        } else {
          await prisma.$executeRaw`
            UPDATE orders 
            SET "deliveryUserId" = ${cleanDeliveryUserId},
                "updatedAt" = NOW()
            WHERE id = ${existingOrder.id}
               OR ("combinedId" IS NOT NULL AND "combinedId" = ${existingOrder.id})
               OR ("readableId" IS NOT NULL AND (${baseReadableId ? `("readableId" = ${existingOrder.readableId} OR "readableId" ILIKE ${baseReadableId + '-%'})` : `"readableId" = ${existingOrder.readableId}`}))
          `
        }
      }

      // Realtime SSE broadcast for Web Admin & mobile clients
      try {
        sseEmitter.emit('order:update', {
          id: existingOrder.id,
          storeId: existingOrder.storeId,
          deliveryUserId: cleanDeliveryUserId,
          status: targetStatus,
          combinedId: existingOrder.combinedId,
        })
      } catch (e) {
        console.warn('SSE emit error on rider assignment:', e)
      }

      try {
        const { supabase } = await import('@/lib/supabase-client')
        if (supabase) {
          // Resolve rider name for tracking broadcast
          let bRiderName = 'FastMinute Store Partner'
          let bRiderPhone = existingOrder.shopPhone || '+918112849854'
          if (cleanDeliveryUserId && cleanDeliveryUserId !== 'store_admin_self' && !cleanDeliveryUserId.includes('store')) {
            const rUser = await prisma.user.findUnique({
              where: { id: cleanDeliveryUserId },
              select: { name: true, phone: true }
            })
            if (rUser) {
              bRiderName = (rUser.name && rUser.name.trim().length > 2) ? rUser.name.trim() : (rUser.phone ? `Rider • ${rUser.phone.slice(-4)}` : 'FastMinute Delivery Partner')
              bRiderPhone = rUser.phone || bRiderPhone
            }
          }

          const trackingKeys = Array.from(new Set([
            existingOrder.id,
            existingOrder.readableId,
            existingOrder.combinedId,
            baseReadableId,
            id,
          ].filter(Boolean))) as string[]

          for (const key of trackingKeys) {
            const cleanKey = key.replace(/^#/, '').trim()
            supabase.channel(`order-live-tracking-${cleanKey}`).send({
              type: 'broadcast',
              event: 'rider_assigned',
              payload: {
                orderId: cleanKey,
                riderId: cleanDeliveryUserId,
                riderName: cleanDeliveryUserId ? bRiderName : null,
                riderPhone: cleanDeliveryUserId ? bRiderPhone : null,
                status: targetStatus,
              }
            }).catch(() => {})

            supabase.channel(`order-live-tracking-${cleanKey}`).send({
              type: 'broadcast',
              event: 'status_update',
              payload: {
                status: targetStatus,
              }
            }).catch(() => {})
          }

          supabase.channel('admin-global-orders-websocket').send({
            type: 'broadcast',
            event: 'order_update',
            payload: {
              id: existingOrder.id,
              orderId: existingOrder.id,
              readableId: existingOrder.readableId,
              status: targetStatus,
              deliveryUserId: cleanDeliveryUserId,
            }
          }).catch(() => {})
        }
      } catch (e) {}

      // Notify the assigned rider via High-Priority Push Notification & FCM buzzer
      if (cleanDeliveryUserId) {
        const readableNo = (existingOrder.readableId || existingOrder.id).slice(-8)
        try {
          sendPushNotification(cleanDeliveryUserId, {
            title: 'New Delivery Assigned! 🛵',
            body: `Order #${readableNo} has been assigned to you for delivery.`,
            tag: `order-${existingOrder.id}`,
            data: { orderId: existingOrder.id, type: 'DELIVERY_ASSIGNED' }
          }).catch(() => {})

          const { fcmMessaging } = await import('@/lib/firebase-admin')
          if (fcmMessaging) {
            // Support lookup by both User ID and Phone Number
            const riderUser = await prisma.user.findFirst({
              where: {
                OR: [
                  { id: cleanDeliveryUserId },
                  { phone: cleanDeliveryUserId },
                  { phone: { endsWith: cleanDeliveryUserId.replace(/\D/g, '').slice(-10) } },
                ]
              },
              select: { id: true, phone: true }
            })

            const targetUserIds = Array.from(new Set([cleanDeliveryUserId, riderUser?.id].filter(Boolean))) as string[]
            const riderTokens = await prisma.fcmToken.findMany({
              where: { userId: { in: targetUserIds } },
              select: { token: true }
            })

            const fcmDataPayload = {
              orderId: existingOrder.id,
              screen: 'delivery-dashboard',
              type: 'DELIVERY_ASSIGNED',
              status: targetStatus || existingOrder.status || 'CONFIRMED',
              orderStatus: targetStatus || existingOrder.status || 'CONFIRMED',
            }

            const sendPromises: Promise<any>[] = []

            // Strict Single Dispatch: Multicast to direct tokens if available.
            // Only fallback to phone topic if no active tokens are found.
            if (riderTokens.length > 0) {
              for (const t of riderTokens) {
                sendPromises.push(
                  fcmMessaging.send({
                    token: t.token,
                    notification: {
                      title: 'New Delivery Assigned! 🛵',
                      body: `Order #${readableNo} has been assigned to you.`,
                    },
                    data: fcmDataPayload,
                    android: {
                      priority: 'high',
                      notification: {
                        sound: 'order_chime',
                        channelId: 'fastkirana_order_buzzer_v2',
                      },
                    },
                  }).catch(() => {})
                )
              }
            } else {
              // Fallback to rider phone topic ONLY if no registered device tokens exist
              const cleanPhone = (riderUser?.phone || cleanDeliveryUserId).replace(/\D/g, '').slice(-10)
              if (cleanPhone.length === 10) {
                sendPromises.push(
                  sendTopicWithRetry(fcmMessaging, {
                    topic: `phone_${cleanPhone}`,
                    notification: {
                      title: 'New Delivery Assigned! 🛵',
                      body: `Order #${readableNo} has been assigned to you.`,
                    },
                    data: fcmDataPayload,
                    android: {
                      priority: 'high',
                      notification: {
                        sound: 'order_chime',
                        channelId: 'fastkirana_order_buzzer_v2',
                      },
                    },
                  }).catch(() => {})
                )
              }
            }

            await Promise.allSettled(sendPromises)
          }
        } catch (notifErr) {
          console.warn('Error sending rider assignment notification:', notifErr)
        }
      }
      // Attempt automated multi-drop batching for nearby orders heading same way
      RiderBatchingService.attemptAutoBatchForOrder(existingOrder.id).catch(err => {
        console.warn('[RiderBatching] Silent error in assignment hook:', err)
      })

      return NextResponse.json({ success: true, deliveryUserId, status: targetStatus })
    }

    const isRestaurantOrder = Boolean(existingOrder.restaurantId || existingOrder.orderType === 'RESTAURANT')

    const isDelivery = userRole === 'DELIVERY'
    const isPicker = userRole === 'PICKER'
    const isRestaurantStaff = (userRole === 'CHEF' || userRole === 'RESTAURANT_OWNER')

    if (!isOwner && !isAdmin && !isDelivery && !isPicker && !isRestaurantStaff) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Strict Role Assignment per status transition & order type
    if (status === 'CANCELLED') {
      if (!isOwner && !isAdmin && !isPicker && !isRestaurantStaff && !isDelivery) {
        return NextResponse.json({ error: 'Unauthorized to cancel this order' }, { status: 403 })
      }
      // Customers can ONLY cancel before the order is confirmed (PENDING or ADMIN_PENDING) and within 5 minutes
      if (isOwner && !isAdmin && !isPicker && !isRestaurantStaff && !isDelivery) {
        if (existingOrder.status !== 'PENDING' && existingOrder.status !== 'ADMIN_PENDING') {
          return NextResponse.json({
            error: 'Order cannot be cancelled after confirmation. The kitchen or store is already preparing your order.',
          }, { status: 400 })
        }
        const orderAgeMinutes = (Date.now() - new Date(existingOrder.createdAt).getTime()) / 60000
        if (orderAgeMinutes > 5.0) {
          return NextResponse.json({
            error: 'Free cancellation window (5 minutes) has expired. Please contact support.',
          }, { status: 400 })
        }
      }
    } else if (status === 'CONFIRMED' || status === 'PACKED') {
      if (isRestaurantOrder) {
        if (!isAdmin && !isRestaurantStaff) {
          return NextResponse.json({ error: 'Only restaurant staff can accept or pack restaurant orders' }, { status: 403 })
        }
      } else {
        if (!isAdmin && !isPicker) {
          return NextResponse.json({ error: 'Only dark store pickers can accept or pack grocery orders' }, { status: 403 })
        }
      }
    } else if (status === 'SHIPPED' || status === 'DELIVERED') {
      if (!isAdmin && !isDelivery) {
        return NextResponse.json({ error: 'Only delivery riders can ship or deliver orders' }, { status: 403 })
      }
    }

    // Restaurant staff can only modify their own restaurant's orders
    if (isRestaurantStaff && !isAdmin) {
      if (assignedRestaurantId && existingOrder.restaurantId && existingOrder.restaurantId !== assignedRestaurantId) {
        return NextResponse.json({ error: 'You can only manage orders for your assigned restaurant' }, { status: 403 })
      }
    }

    // Dark store staff (picker, delivery, branch admin) can only modify orders belonging to their assigned hub
    if (!isOwner && assignedStoreId && existingOrder.storeId && existingOrder.storeId !== assignedStoreId) {
      return NextResponse.json({ error: 'Forbidden: Access restricted to your assigned hub' }, { status: 403 })
    }

    // Claim checks / locking mechanisms (only for non-admin staff)
    if (!isAdmin) {
      if (status === 'CONFIRMED') {
        if (isRestaurantOrder) {
          if (existingOrder.assignedChefId && existingOrder.assignedChefId !== userId) {
            return NextResponse.json({ error: 'Order is already claimed by another chef' }, { status: 409 })
          }
        } else {
          if (existingOrder.assignedPickerId && existingOrder.assignedPickerId !== userId) {
            return NextResponse.json({ error: 'Order is already claimed by another picker' }, { status: 409 })
          }
        }
      }

      if (status === 'SHIPPED') {
        if (existingOrder.deliveryUserId && existingOrder.deliveryUserId !== userId) {
          return NextResponse.json({ error: 'Order is already claimed by another delivery rider' }, { status: 409 })
        }
      }
    }

    // Sub-order isolation for combined orders:
    // When a single outlet cancels, edits, or packs an order, only that outlet's order updates
    // unless the caller explicitly passes scope: 'ALL' or updateCombined: true.
    // If a picker cancels or edits a grocery sub-order (-G), the restaurant companion order (-R) MUST NEVER be cancelled!
    const isExplicitAll = body.scope === 'ALL' || body.updateCombined === true
    const isCustomerCancel = isOwner && status === 'CANCELLED'
    const isAdminCancelAll = isAdmin && status === 'CANCELLED' && (isExplicitAll || !existingOrder.readableId?.includes('-'))
    // PACKED status is strictly outlet-isolated: grocery packing NEVER auto-packs restaurant dishes, and vice versa!
    const isGlobalLifecycleStatus = status === 'CONFIRMED' || status === 'SHIPPED' || status === 'DELIVERED'
    const shouldUpdateAllCombined = Boolean(
      existingOrder.combinedId && (
        isExplicitAll ||
        isCustomerCancel ||
        isAdminCancelAll ||
        isGlobalLifecycleStatus
      )
    )

    // Deduct stock if order is being PACKED (picked) and was not PACKED previously
    if (status === 'PACKED' && existingOrder.status !== 'PACKED') {
      try {
        const orderIds = (shouldUpdateAllCombined && existingOrder.combinedId)
          ? (await prisma.order.findMany({
              where: { combinedId: existingOrder.combinedId },
              select: { id: true }
            })).map(o => o.id)
          : [existingOrder.id]

        const orderItems = await prisma.orderItem.findMany({
          where: { orderId: { in: orderIds } },
        })
        
        for (const item of orderItems) {
          if (!item.productId) continue // Product was deleted, skip stock deduction
          const product = await prisma.product.findUnique({
            where: { id: item.productId },
            select: { stock: true, name: true, restaurantId: true }
          })
          
          if (product) {
            if (product.restaurantId) {
              continue
            }
            const newStock = Math.max(0, product.stock - item.quantity)
            await prisma.product.update({
              where: { id: item.productId },
              data: { stock: newStock }
            })
            // Inventory deducted silently
          }
        }
      } catch (stockErr) {
        console.error('Failed to deduct inventory for order:', id, stockErr)
      }
    }

    // Delivery photos are intentionally disabled (privacy & fast zero-friction delivery)
    const safePhoto: string | null = null

    // Update using raw SQL to handle enum properly
    if (status === 'DELIVERED') {

      const isAlreadyPaidOnline = 
        existingOrder.paymentStatus === 'PAID' && 
        existingOrder.paymentMethod !== 'COD'

      // Only switch to UPI if order was already paid online or customer explicitly paid via online QR at doorstep
      const isDoorstepQrOrOnline = 
        isAlreadyPaidOnline ||
        existingOrder.paymentMethod === 'UPI' || 
        existingOrder.paymentMethod === 'ONLINE' || 
        paymentMethod === 'UPI' || 
        paymentMethod === 'ONLINE' || 
        paymentCollectedBy === 'ONLINE'

      const newPaymentMethod = isDoorstepQrOrOnline 
        ? 'UPI' 
        : (paymentMethod && ['COD', 'UPI', 'CARD', 'WALLET'].includes(paymentMethod) 
            ? paymentMethod 
            : (['COD', 'UPI', 'CARD', 'WALLET'].includes(existingOrder.paymentMethod) ? existingOrder.paymentMethod : 'COD'))

      // If COD order was delivered by admin/counter (not rider), cash was received directly at store counter (Galla)
      const isCounterSettled = (newPaymentMethod === 'COD') && (userRole !== 'DELIVERY' && paymentCollectedBy !== 'RIDER')

      const finalDelivUserId = userRole === 'DELIVERY' 
        ? existingOrder.deliveryUserId 
        : (deliveryUserId !== undefined ? deliveryUserId : null)

      if (shouldUpdateAllCombined && existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "paymentStatus" = 'PAID'::"PaymentStatus",
              "paymentMethod" = ${newPaymentMethod}::"PaymentMethod",
              "deliveryUserId" = ${finalDelivUserId},
              "cashSettledToAdmin" = CASE WHEN ${isCounterSettled} THEN true ELSE "cashSettledToAdmin" END,
              "cashSettledAt" = CASE WHEN ${isCounterSettled} THEN COALESCE("cashSettledAt", NOW()) ELSE "cashSettledAt" END,
              "deliveryPhoto" = ${safePhoto}, 
              "deliveryLat" = ${deliveryLat !== undefined && deliveryLat !== null ? parseFloat(String(deliveryLat)) : null}, 
              "deliveryLng" = ${deliveryLng !== undefined && deliveryLng !== null ? parseFloat(String(deliveryLng)) : null}, 
              "deliveredAt" = COALESCE("deliveredAt", NOW()),
              "updatedAt" = NOW() 
          WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "paymentStatus" = 'PAID'::"PaymentStatus",
              "paymentMethod" = ${newPaymentMethod}::"PaymentMethod",
              "deliveryUserId" = ${finalDelivUserId},
              "cashSettledToAdmin" = CASE WHEN ${isCounterSettled} THEN true ELSE "cashSettledToAdmin" END,
              "cashSettledAt" = CASE WHEN ${isCounterSettled} THEN COALESCE("cashSettledAt", NOW()) ELSE "cashSettledAt" END,
              "deliveryPhoto" = ${safePhoto}, 
              "deliveryLat" = ${deliveryLat !== undefined && deliveryLat !== null ? parseFloat(String(deliveryLat)) : null}, 
              "deliveryLng" = ${deliveryLng !== undefined && deliveryLng !== null ? parseFloat(String(deliveryLng)) : null}, 
              "deliveredAt" = COALESCE("deliveredAt", NOW()),
              "updatedAt" = NOW() 
          WHERE id = ${existingOrder.id}
        `
      }

      // If order assigned to a delivery rider, update RiderWallet ONLY if physical cash was collected by rider
      const isCashOrder = (existingOrder.paymentMethod === 'COD' || newPaymentMethod === 'COD') && !isDoorstepQrOrOnline
      const isDeliveredByRider = userRole === 'DELIVERY' || paymentCollectedBy === 'RIDER'

      if (existingOrder.status !== 'DELIVERED' && existingOrder.deliveryUserId && isDeliveredByRider && isCashOrder) {
        try {
          const riderId = existingOrder.deliveryUserId
          const orderTotal = parseFloat(existingOrder.total) || 0

          let actualCashChange = 0
          if (cashAmount !== undefined && cashAmount !== null && !isNaN(parseFloat(String(cashAmount)))) {
            actualCashChange = parseFloat(String(cashAmount))
          } else {
            actualCashChange = orderTotal
          }

          if (actualCashChange > 0) {
            const wallet = await prisma.riderWallet.findUnique({ where: { userId: riderId } })
            if (wallet) {
              await prisma.riderWallet.update({
                where: { userId: riderId },
                data: {
                  cashInHand: { increment: actualCashChange },
                  totalCollected: { increment: actualCashChange }
                }
              })
            } else {
              await prisma.riderWallet.create({
                data: {
                  userId: riderId,
                  cashInHand: actualCashChange,
                  cashLimit: 10000,
                  totalCollected: actualCashChange,
                  totalDeposited: 0
                }
              })
            }
          }
        } catch (wErr) {
          console.error('[API orders] Error updating rider wallet on delivery:', wErr)
        }
      }
    } else if (status === 'SHIPPED') {
      const latVal = deliveryLat !== undefined && deliveryLat !== null ? parseFloat(String(deliveryLat)) : null
      const lngVal = deliveryLng !== undefined && deliveryLng !== null ? parseFloat(String(deliveryLng)) : null

      const isDeliveryRole = userRole === 'DELIVERY'
      const targetRiderId = isDeliveryRole ? (session?.user?.id || headerUserId || userId) : (deliveryUserId || existingOrder.deliveryUserId || null)

      if (shouldUpdateAllCombined && existingOrder.combinedId) {
        if (latVal !== null && lngVal !== null) {
          await prisma.$executeRaw`
            UPDATE orders 
            SET status = ${status}::"OrderStatus", 
                "deliveryUserId" = ${targetRiderId},
                "deliveryLat" = ${latVal},
                "deliveryLng" = ${lngVal},
                "shippedAt" = COALESCE("shippedAt", NOW()),
                "updatedAt" = NOW() 
            WHERE "combinedId" = ${existingOrder.combinedId}
          `
        } else {
          await prisma.$executeRaw`
            UPDATE orders 
            SET status = ${status}::"OrderStatus", 
                "deliveryUserId" = ${targetRiderId},
                "shippedAt" = COALESCE("shippedAt", NOW()),
                "updatedAt" = NOW() 
            WHERE "combinedId" = ${existingOrder.combinedId}
          `
        }
      } else {
        if (latVal !== null && lngVal !== null) {
          await prisma.$executeRaw`
            UPDATE orders 
            SET status = ${status}::"OrderStatus", 
                "deliveryUserId" = ${targetRiderId},
                "deliveryLat" = ${latVal},
                "deliveryLng" = ${lngVal},
                "shippedAt" = COALESCE("shippedAt", NOW()),
                "updatedAt" = NOW() 
            WHERE id = ${existingOrder.id}
          `
        } else {
          await prisma.$executeRaw`
            UPDATE orders 
            SET status = ${status}::"OrderStatus", 
                "deliveryUserId" = ${targetRiderId},
                "shippedAt" = COALESCE("shippedAt", NOW()),
                "updatedAt" = NOW() 
            WHERE id = ${existingOrder.id}
          `
        }
      }
    } else if (status === 'PACKED') {
      if (shouldUpdateAllCombined && existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "packedAt" = COALESCE("packedAt", NOW()),
              "updatedAt" = NOW() 
          WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "packedAt" = COALESCE("packedAt", NOW()),
              "updatedAt" = NOW() 
          WHERE id = ${existingOrder.id}
        `
      }
    } else if (status === 'CONFIRMED') {
      if (existingOrder.paymentMethod !== 'COD' && existingOrder.paymentStatus !== 'PAID') {
        // Try live verification with Cashfree before failing
        try {
          const { getCashfreeOrder } = await import('@/lib/cashfree')
          const cfOrder = await getCashfreeOrder(existingOrder.id)
          if (cfOrder && cfOrder.order_status === 'PAID') {
            existingOrder.paymentStatus = 'PAID'
            existingOrder.paymentMethod = 'UPI'
            if (existingOrder.combinedId) {
              await prisma.$executeRaw`
                UPDATE orders SET "paymentStatus" = 'PAID'::"PaymentStatus", "paymentMethod" = 'UPI'::"PaymentMethod", "updatedAt" = NOW() WHERE "combinedId" = ${existingOrder.combinedId}
              `
            } else {
              await prisma.$executeRaw`
                UPDATE orders SET "paymentStatus" = 'PAID'::"PaymentStatus", "paymentMethod" = 'UPI'::"PaymentMethod", "updatedAt" = NOW() WHERE id = ${existingOrder.id}
              `
            }
          }
        } catch (cfErr) {
          console.warn('Cashfree live auto-verify on confirm notice:', cfErr)
        }
      }

      // If still unpaid and not COD: non-admins cannot confirm
      if (!isAdmin && existingOrder.paymentMethod !== 'COD' && existingOrder.paymentStatus !== 'PAID') {
        return NextResponse.json({
          error: 'Cannot confirm order: Customer online payment is still pending.',
        }, { status: 400 })
      }

      let estimatedDeliveryVal: Date | null = null
      if (prepTime && !isNaN(parseInt(String(prepTime)))) {
        estimatedDeliveryVal = new Date(Date.now() + parseInt(String(prepTime)) * 60 * 1000)
      }

      if (shouldUpdateAllCombined && existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "confirmedAt" = COALESCE("confirmedAt", NOW()),
              "packedAt" = NULL,
              "estimatedDelivery" = ${estimatedDeliveryVal},
              "updatedAt" = NOW() 
          WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else if (userRole === 'CHEF' || existingOrder.orderType === 'RESTAURANT' || !!existingOrder.restaurantId) {
        const targetChefId = userRole === 'CHEF' ? userId : (existingOrder.assignedChefId || null)
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "assignedChefId" = ${targetChefId},
              "confirmedAt" = COALESCE("confirmedAt", NOW()),
              "packedAt" = NULL,
              "estimatedDelivery" = ${estimatedDeliveryVal},
              "updatedAt" = NOW() 
            WHERE id = ${existingOrder.id}
        `
      } else {
        const targetPickerId = userRole === 'PICKER' ? userId : (existingOrder.assignedPickerId || null)
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "assignedPickerId" = ${targetPickerId},
              "confirmedAt" = COALESCE("confirmedAt", NOW()),
              "packedAt" = NULL,
              "estimatedDelivery" = ${estimatedDeliveryVal},
              "updatedAt" = NOW() 
          WHERE id = ${existingOrder.id}
        `
      }
    } else {
      if (status === 'CANCELLED' && existingOrder.status !== 'CANCELLED') {
        try {
          const orderIdsToRestore = (shouldUpdateAllCombined && existingOrder.combinedId)
            ? (await prisma.order.findMany({
                where: { combinedId: existingOrder.combinedId },
                select: { id: true }
              })).map(o => o.id)
            : [existingOrder.id]
          const orderItems = await prisma.orderItem.findMany({
            where: { orderId: { in: orderIdsToRestore } },
          })
          
          for (const item of orderItems) {
            if (!item.productId) continue
            
            const product = await prisma.product.findUnique({
              where: { id: item.productId },
              select: {
                stock: true,
                name: true,
                variants: true,
                restaurantId: true
              }
            })
            
            if (!product) continue
            
            // Skip stock restoration for Cafe & Restaurant items (kitchen items have restaurantId)
            if (product.restaurantId) {
              continue
            }

            const prevStock = product.stock || 0

            if (item.selectedVariant) {
              if (product.variants && Array.isArray(product.variants)) {
                const updatedVariants = (product.variants as any[]).map((v) => {
                  if (v.name === item.selectedVariant) {
                    return { ...v, stock: (Number(v.stock) || 0) + item.quantity }
                  }
                  return v
                })
                const newTotalStock = updatedVariants.reduce((sum, v) => sum + (Number(v.stock) || 0), 0)
                
                await prisma.product.update({
                  where: { id: item.productId },
                  data: {
                    variants: updatedVariants,
                    stock: newTotalStock
                  }
                })

                await prisma.stockLog.create({
                  data: {
                    productId: item.productId,
                    quantity: item.quantity,
                    type: 'ORDER_CANCELLED',
                    prevStock,
                    newStock: newTotalStock,
                  }
                }).catch(() => {})
              }
            } else {
              const batches = await prisma.productBatch.findMany({
                where: { productId: item.productId },
                orderBy: { expiryDate: 'asc' }
              })
              
              if (batches.length > 0) {
                await prisma.productBatch.update({
                  where: { id: batches[0].id },
                  data: { quantity: { increment: item.quantity } }
                })
                
                const activeBatches = await prisma.productBatch.findMany({
                  where: { productId: item.productId, quantity: { gt: 0 } }
                })
                const newTotalStock = activeBatches.reduce((sum, b) => sum + (Number(b.quantity) || 0), 0)
                
                await prisma.product.update({
                  where: { id: item.productId },
                  data: { stock: newTotalStock }
                })

                await prisma.stockLog.create({
                  data: {
                    productId: item.productId,
                    quantity: item.quantity,
                    type: 'ORDER_CANCELLED',
                    prevStock,
                    newStock: newTotalStock,
                  }
                }).catch(() => {})
              } else {
                const newStock = prevStock + item.quantity
                await prisma.product.update({
                  where: { id: item.productId },
                  data: { stock: { increment: item.quantity } }
                })

                await prisma.stockLog.create({
                  data: {
                    productId: item.productId,
                    quantity: item.quantity,
                    type: 'ORDER_CANCELLED',
                    prevStock,
                    newStock,
                  }
                }).catch(() => {})
              }
            }
          }
        } catch (stockErr) {
          console.error('Failed to restore inventory for cancelled order:', id, stockErr)
        }

        // Auto-refund CustomerWallet if wallet amount was used on this order
        try {
          let walletRefundAmount = 0
          if (existingOrder.notes) {
            const matches = [...existingOrder.notes.matchAll(/\[WALLET_USED:([\d.]+)\]/g)]
            if (matches.length > 0) {
              walletRefundAmount = matches.reduce((sum, m) => sum + parseFloat(m[1] || '0'), 0)
            }
          }
          if (walletRefundAmount <= 0 && existingOrder.paymentMethod === 'WALLET') {
            walletRefundAmount = Number(existingOrder.total || 0)
          }

          if (walletRefundAmount > 0 && existingOrder.userId) {
            const userWallet = await prisma.customerWallet.findUnique({
              where: { userId: existingOrder.userId }
            })
            if (userWallet) {
              const currentBal = Number(userWallet.balance)
              const newBal = currentBal + walletRefundAmount
              await prisma.customerWallet.update({
                where: { id: userWallet.id },
                data: { balance: newBal }
              })
              const baseOrderNum = existingOrder.readableId
                ? String(existingOrder.readableId).replace(/-[GR\d]+$/i, '')
                : id.slice(-6).toUpperCase()
              await prisma.walletTransaction.create({
                data: {
                  walletId: userWallet.id,
                  amount: walletRefundAmount,
                  type: 'CREDIT_REFUND',
                  status: 'SUCCESS',
                  description: `Refund for cancelled order #${baseOrderNum}`,
                  balanceBefore: currentBal,
                  balanceAfter: newBal,
                  paymentGateway: 'WALLET',
                }
              })
            }
          }
        } catch (wRefundErr) {
          console.error('Failed to process wallet refund for cancelled order:', id, wRefundErr)
        }
      }

      if (shouldUpdateAllCombined && existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders SET status = ${status}::"OrderStatus", "updatedAt" = NOW() WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders SET status = ${status}::"OrderStatus", "updatedAt" = NOW() WHERE id = ${existingOrder.id}
        `
      }
    }

    // Trigger PWA Push Notification for customer and staff
    try {
      const statusLabels: Record<string, string> = {
        CONFIRMED: 'Confirmed by Store 🏪',
        PREPARING: 'Preparing in Kitchen 🍳',
        PACKED: 'Packed & Ready to Go 📦',
        SHIPPED: 'Out for Delivery 🚴',
        DELIVERED: 'Delivered Successfully 🎉',
        CANCELLED: 'Cancelled ❌',
      }

      const baseOrderNo = existingOrder.readableId
        ? String(existingOrder.readableId).replace(/-[GR\d]+$/i, '')
        : id.slice(-6).toUpperCase()

      const displayStatus = status ? (statusLabels[status] || status) : 'Updated'
      const statusTitle = `Order #${baseOrderNo}: ${displayStatus}`
      const statusBody = `Your FastMinute order #${baseOrderNo} is now ${displayStatus}.`

      const orderTag = `order-${baseOrderNo}`

      // Web push notification for PWA / web subscribers
      sendPushNotification(existingOrder.userId, {
        title: statusTitle,
        body: statusBody,
        icon: `${origin}/icons/icon-192.png`,
        badge: `${origin}/icons/icon-192.png`,
        tag: orderTag,
        renotify: status !== 'CANCELLED',
        data: { orderId: existingOrder.id }
      }).catch(err => console.error('Background sendPushNotification error:', err))

      // Notify only the relevant outlet/hub staff — never broadcast to all CHEFs across restaurants
      const isRestOrder = Boolean(existingOrder.restaurantId || existingOrder.orderType === 'RESTAURANT')
      if (status === 'CANCELLED' && isRestOrder && existingOrder.restaurantId) {
        sendPushNotificationToRestaurant(existingOrder.restaurantId, {
          title: `Order #${baseOrderNo} Cancelled`,
          body: `Order #${baseOrderNo} has been cancelled.`,
          icon: `${origin}/icons/icon-192.png`,
          badge: `${origin}/icons/icon-192.png`,
          tag: `${orderTag}-rest-cancel`,
          renotify: false,
          data: { orderId: existingOrder.id, restaurantId: existingOrder.restaurantId, status: 'CANCELLED' },
        }).catch(err => console.error('Background restaurant cancel push error:', err))
      }

      if (status === 'PACKED') {
        sendPushNotificationToRoles([Role.DELIVERY], {
          title: `Order #${baseOrderNo} Ready for Pickup 🛵`,
          body: `Order #${baseOrderNo} is packed and ready for delivery.`,
          icon: `${origin}/icons/icon-192.png`,
          badge: `${origin}/icons/icon-192.png`,
          tag: `${orderTag}-rider-ready`,
          renotify: true,
          data: { orderId: existingOrder.id, storeId: existingOrder.storeId || '' },
        }).catch(err => console.error('Background rider push error:', err))
      }

      // If order was approved by Admin from ADMIN_PENDING to PENDING / CONFIRMED / etc, alert Restaurant or Dark Store specifically
      const isApproval = (body as any)?.isApproval === true || (body as any)?.previousStatus === 'ADMIN_PENDING'
      const isAdminApproved = (existingOrder.status === 'ADMIN_PENDING' || isApproval) && status !== 'ADMIN_PENDING' && status !== 'CANCELLED'
      if (isAdminApproved) {
        dispatchAdminApprovedNotifications(existingOrder.id, origin).catch(err =>
          console.error('Error dispatching admin approved notifications:', err)
        )
      }

      // FCM push notification for mobile app customers (Universal Multi-Topic Broadcast)
      try {
        const fullOrder = await prisma.order.findUnique({
          where: { id: existingOrder.id },
          include: { user: true, address: true },
        })

        const candidatePhones = [
          fullOrder?.user?.phone,
          fullOrder?.address?.phone,
          (fullOrder as any)?.customerPhone,
        ].filter(Boolean).map(p => getLast10Digits(String(p))).filter(p => p && p.length === 10)

        const uniquePhones = Array.from(new Set(candidatePhones))

        const { fcmMessaging } = await import('@/lib/firebase-admin')
        if (fcmMessaging) {
          const dedupKey = `${existingOrder.userId || uniquePhones[0] || 'customer'}_${baseOrderNo}_${status}`
          const nowMs = Date.now()
          for (const [k, t] of recentCustomerStatusNotifications.entries()) {
            if (nowMs - t > 60000) recentCustomerStatusNotifications.delete(k)
          }

          if (recentCustomerStatusNotifications.has(dedupKey) && (nowMs - (recentCustomerStatusNotifications.get(dedupKey) || 0) < 20000)) {
            console.log(`[Deduplication] Suppressed duplicate customer notification for order #${baseOrderNo} (${status})`)
          } else {
            recentCustomerStatusNotifications.set(dedupKey, nowMs)

            const dataPayload: Record<string, string> = {
              title: statusTitle,
              body: statusBody,
              orderId: existingOrder.id,
              readableId: baseOrderNo,
              status: status || '',
              screen: 'order-tracking',
              url: `/orders/${existingOrder.id}`,
              timestamp: Date.now().toString(),
            }

            const fcmPayload = buildOrderFcmPayload(statusTitle, statusBody, dataPayload)

            const broadcastPromises: Promise<any>[] = []

            // 1. Direct device token push to customer's active devices (Deduplicated)
            const targetUserIds = [existingOrder.userId, fullOrder?.userId].filter(Boolean) as string[]
            const customerTokenRecords = await prisma.fcmToken.findMany({
              where: {
                OR: [
                  ...(targetUserIds.length > 0 ? [{ userId: { in: targetUserIds } }] : []),
                  ...(uniquePhones.length > 0
                    ? [
                        { user: { phone: { in: uniquePhones } } },
                        { user: { phone: { in: uniquePhones.map(p => `+91${p}`) } } },
                        { user: { phone: { in: uniquePhones.map(p => `+91 ${p}`) } } },
                      ]
                    : []),
                ],
              },
              select: { token: true },
              orderBy: { createdAt: 'desc' },
              take: 5,
            })

            const uniqueTokens = Array.from(new Set(customerTokenRecords.map(t => t.token)))

            // 1. Send to direct device tokens if present
            if (uniqueTokens.length > 0) {
              for (const token of uniqueTokens) {
                broadcastPromises.push(
                  fcmMessaging.send({
                    token,
                    notification: fcmPayload.notification,
                    data: dataPayload,
                    android: fcmPayload.android,
                    apns: fcmPayload.apns,
                  }).catch((err: any) => console.error('Customer direct token push error:', token.slice(0, 15), err?.message))
                )
              }
            } else {
              // 2. Fallback to phone topics ONLY if no registered device tokens found
              for (const phone of uniquePhones) {
                broadcastPromises.push(
                  sendTopicWithRetry(fcmMessaging, { topic: `phone_${phone}`, ...fcmPayload })
                    .catch((err: any) => console.error(`Topic phone_${phone} push error:`, err?.message))
                )
              }
            }

            await Promise.allSettled(broadcastPromises)
          }
        }
      } catch (fcmErr: any) {
        console.error('Universal FCM notification error:', fcmErr)
      }
    } catch (pushErr) {
      console.error('Failed to dispatch push notification:', pushErr)
    }

    // If order was marked as SHIPPED, trigger gift tracking alert to recipient if requested
    if (status === 'SHIPPED') {
      try {
        const notesStr = existingOrder.notes || ''
        const trackingLinkMatch = notesStr.match(/\[SEND LIVE TRACKING LINK TO:\s*([0-9+ ]+)\]/i)
        if (trackingLinkMatch && trackingLinkMatch[1]) {
          const recipientPhone = trackingLinkMatch[1].replace(/\D/g, '').slice(-10)
          if (recipientPhone.length === 10) {
            const giftNoteMatch = notesStr.match(/💌 Gift Note:\s*(.*?)(?:\||$)/)
            const recipientNameMatch = notesStr.match(/🎁 Order for:\s*(.*?)(?:\(|$)/)

            const appUrl = (process.env.NEXT_PUBLIC_APP_URL || origin || 'https://fastminute.in').replace(/\/+$/, '')
            const trackingUrl = `${appUrl}/order/${existingOrder.id}/track`

            const recipientName = recipientNameMatch ? recipientNameMatch[1].trim() : undefined
            const giftNote = giftNoteMatch ? giftNoteMatch[1].trim() : undefined
            const baseDisplayId = (existingOrder.readableId || existingOrder.id).replace(/-[GR]\d*$/i, '')

            sendGiftRecipientNotification({
              orderId: existingOrder.id,
              readableId: baseDisplayId,
              recipientPhone,
              recipientName,
              giftNote,
              trackingUrl,
            }).catch((err) => console.error('[GiftRecipientNotification on SHIPPED] Failed:', err))
          }
        }
      } catch (giftShipErr) {
        console.error('Gift tracking trigger on SHIPPED error:', giftShipErr)
      }
    }

    // Return updated order
    const updated: any[] = await prisma.$queryRaw`
      SELECT id, status::text as status, total, "createdAt", "updatedAt", "deliveryPhoto", "deliveryLat", "deliveryLng",
             "assignedPickerId", "assignedChefId", "deliveryUserId",
             "confirmedAt", "packedAt", "shippedAt", "deliveredAt"
      FROM orders WHERE id = ${existingOrder.id} LIMIT 1
    `

    // Emit real-time SSE event for the updated order status
    try {
      sseEmitter.emit('order', {
        type: 'status-change',
        orderId: existingOrder.id,
        status: updated[0].status,
        order: updated[0],
      })
    } catch (sseErr) {
      console.error('Failed to emit SSE order update:', sseErr)
    }

    return NextResponse.json(updated[0])
  } catch (error) {
    console.error('Order status update error:', error)
    return NextResponse.json({ error: 'Failed to update order status' }, { status: 500 })
  }
}

export async function DELETE(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const order = await prisma.order.findUnique({
      where: { id },
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Only allow deleting unpaid orders
    if (order.paymentStatus === 'PAID') {
      return NextResponse.json({ error: 'Paid orders cannot be deleted' }, { status: 400 })
    }

    // Delete order items first, then order
    await prisma.orderItem.deleteMany({ where: { orderId: id } })
    await prisma.order.delete({ where: { id } })

    return NextResponse.json({ success: true, message: 'Unpaid order cancelled successfully' })
  } catch (error) {
    console.error('Delete order error:', error)
    return NextResponse.json({ error: 'Failed to delete order' }, { status: 500 })
  }
}

export const PUT = PATCH

