import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { OrderStatus, PaymentStatus, PaymentMethod, Role, OrderType } from '@prisma/client'
import { requireAdmin } from '@/lib/auth-guard'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { revalidateStorefront } from '@/lib/revalidate'
import { getLast10Digits } from '@/lib/phone'

export async function POST(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const {
      customerId,
      phone,
      customerName,
      addressId,
      paymentMethod = PaymentMethod.COD,
      items,
      couponCode,
      deliveryMethod = 'DELIVERY',
      isB2B = false,
      scheduledSlot = 'INSTANT',
      shopName = null,
      customDeliveryFee = null,
      customDiscount = 0,
      notes = null
    } = body

    if (!items || items.length === 0) {
      return NextResponse.json({ error: 'Order must contain at least one item' }, { status: 400 })
    }

    // 1. Resolve Customer (By customerId, phone, or auto-create)
    let customer: any = null
    if (customerId) {
      customer = await prisma.user.findUnique({ where: { id: customerId } })
    }

    if (!customer && phone) {
      const cleanPhone = getLast10Digits(phone)
      if (cleanPhone) {
        customer = await prisma.user.findFirst({
          where: {
            OR: [
              { phone: cleanPhone },
              { phone: `+91${cleanPhone}` }
            ]
          }
        })

        if (!customer) {
          customer = await prisma.user.create({
            data: {
              email: `${cleanPhone}@customer.fastkirana.in`,
              phone: `+91${cleanPhone}`,
              name: customerName || 'FastKirana Customer',
              role: Role.USER
            }
          })
        }
      }
    }

    if (!customer) {
      return NextResponse.json({ error: 'Customer or valid phone number is required' }, { status: 400 })
    }

    // 2. Resolve Address
    let address: any = null
    if (addressId) {
      address = await prisma.address.findFirst({
        where: { id: addressId }
      })
    }

    if (!address) {
      address = await prisma.address.findFirst({
        where: { userId: customer.id }
      })
    }

    if (!address) {
      // Create default Ghatampur address for manual admin orders
      address = await prisma.address.create({
        data: {
          userId: customer.id,
          label: deliveryMethod === 'PICKUP' ? 'STORE_PICKUP' : 'HOME',
          houseNo: 'Ghatampur Express',
          street: 'Main Market Road',
          area: 'Ghatampur',
          city: 'Ghatampur',
          pincode: '209206',
          phone: customer.phone || '7054470303'
        }
      })
    }

    // 3. Normalize Items & Fetch DB Products
    const normalizedItems = items.map((i: any) => {
      const p = i.product || i
      const rawId = (p.id || i.productId || '').toString()
      const isVariant = rawId.includes('_')
      const [productId, variantName] = isVariant ? rawId.split('_') : [rawId, i.selectedVariant || null]

      return {
        productId,
        variantName,
        selectedVariant: variantName,
        name: p.name || i.name || 'Item',
        price: typeof p.price === 'number' ? p.price : (parseFloat(p.price || i.price || '0') || 0),
        quantity: typeof i.quantity === 'number' ? i.quantity : (parseInt(i.quantity || '1', 10) || 1),
        imageUrl: p.imageUrl || i.imageUrl || '/images/placeholder.png'
      }
    })

    const productIds = normalizedItems.map((i: any) => i.productId).filter(Boolean)
    const dbProducts = await prisma.product.findMany({
      where: { id: { in: productIds } },
      include: { category: true, restaurant: true }
    })

    // Determine Restaurant / Shop context
    const restaurantProduct = dbProducts.find((p) => p.restaurantId !== null)
    const restaurantId = restaurantProduct?.restaurantId || null
    const restaurant = restaurantProduct?.restaurant || null
    const finalShopName = shopName || restaurant?.name || (restaurantId ? 'Restaurant Kitchen' : 'FastKirana Grocery')

    // 4. Calculate Subtotal & Totals
    let subtotal = 0
    const orderItemsData: any[] = []

    for (const item of normalizedItems) {
      const dbProd = dbProducts.find((p) => p.id === item.productId)
      let unitPrice = item.price

      if (dbProd) {
        unitPrice = dbProd.price
        if (item.variantName && Array.isArray(dbProd.variants)) {
          const v = (dbProd.variants as any[]).find((v: any) => v.name === item.variantName)
          if (v && v.price) unitPrice = v.price
        }
      }

      const itemTotal = unitPrice * item.quantity
      subtotal += itemTotal

      orderItemsData.push({
        productId: item.productId || undefined,
        name: item.name || dbProd?.name || 'Item',
        price: unitPrice,
        quantity: item.quantity,
        total: itemTotal,
        selectedVariant: item.selectedVariant || null,
        imageUrl: item.imageUrl || dbProd?.imageUrl || null
      })
    }

    // Handle Coupon / Discount
    let discount = typeof customDiscount === 'number' ? customDiscount : 0
    let couponId: string | null = null

    if (couponCode) {
      const coupon = await prisma.coupon.findUnique({
        where: { code: couponCode.toUpperCase(), isActive: true }
      })
      if (coupon) {
        couponId = coupon.id
        if (coupon.discountType === 'FLAT') {
          discount = Math.min(coupon.value, subtotal)
        } else if (coupon.discountType === 'PERCENT') {
          discount = (subtotal * coupon.value) / 100
          if (coupon.maxDiscount) discount = Math.min(discount, coupon.maxDiscount)
        }
      }
    }

    const deliveryFee = customDeliveryFee !== null ? Number(customDeliveryFee) : (deliveryMethod === 'PICKUP' ? 0 : (subtotal >= 199 ? 0 : 25))
    const total = Math.max(0, subtotal - discount + deliveryFee)

    // Generate unique IDs
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '')
    const randomNum = Math.floor(1000 + Math.random() * 9000)
    const readableId = `FK-${dateStr}-${randomNum}`
    const orderId = `ord_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`

    // 5. Create Unified Order in Database Transaction
    const newOrder = await prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
        data: {
          id: orderId,
          readableId,
          userId: customer.id,
          addressId: address.id,
          orderType: restaurantId ? OrderType.RESTAURANT : OrderType.GROCERY,
          status: OrderStatus.CONFIRMED,
          paymentStatus: PaymentStatus.PAID,
          paymentMethod: paymentMethod as PaymentMethod,
          subtotal,
          discount,
          deliveryFee,
          taxes: 0,
          miscFee: 0,
          total,
          notes: notes || 'Admin Manual Order',
          couponCode: couponCode ? couponCode.toUpperCase() : null,
          deliveryMethod,
          isB2B,
          shopName: finalShopName,
          restaurantId,
          items: {
            create: orderItemsData.map((item) => ({
              productId: item.productId,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              total: item.total,
              selectedVariant: item.selectedVariant,
              imageUrl: item.imageUrl
            }))
          }
        },
        include: {
          items: true,
          address: true,
          user: true,
          restaurant: true
        }
      })

      // Stock decrement for Darkstore grocery items
      for (const item of normalizedItems) {
        if (item.productId) {
          const dbProd = dbProducts.find((p) => p.id === item.productId)
          if (dbProd && !dbProd.restaurantId && dbProd.stock > 0) {
            await tx.product.update({
              where: { id: item.productId },
              data: {
                stock: { decrement: Math.min(dbProd.stock, item.quantity) }
              }
            }).catch(() => {})
          }
        }
      }

      // Increment coupon use count
      if (couponId) {
        await tx.coupon.update({
          where: { id: couponId },
          data: { usedCount: { increment: 1 } }
        }).catch(() => {})
      }

      return order
    })

    // 6. Real-time SSE & Push Alerts
    try {
      revalidateStorefront()

      sseEmitter.emit('order', {
        type: 'new-order',
        orderId: newOrder.id,
        readableId: newOrder.readableId,
        shopName: newOrder.shopName,
        status: newOrder.status,
        total: newOrder.total,
        createdAt: newOrder.createdAt
      })

      sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
        title: `New Admin Order #${newOrder.readableId} 🛍️`,
        body: `Order for ${customer.name || 'Customer'} of ₹${newOrder.total} placed successfully.`,
        tag: `order-${newOrder.id}`,
        data: { orderId: newOrder.id }
      }).catch(() => {})

      // Send WhatsApp alert to admin phones
      const adminPhone = '7054470303'
      const alertMsg = `New Admin Order #${newOrder.readableId} for [${finalShopName}] of ₹${newOrder.total} created for ${customer.name} (${customer.phone}).`
      sendWhatsAppOrderAlert(adminPhone, alertMsg).catch(() => {})
    } catch (notifyErr) {
      console.error('Notification dispatch warning:', notifyErr)
    }

    return NextResponse.json({
      success: true,
      order: newOrder,
      orders: [newOrder]
    })
  } catch (error: any) {
    console.error('Admin create order on behalf error:', error)
    return NextResponse.json({ error: error.message || 'Failed to create order' }, { status: 500 })
  }
}
