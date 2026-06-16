import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { OrderStatus, PaymentStatus, PaymentMethod } from '@prisma/client'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { apiWriteLimiter, apiReadLimiter } from '@/lib/rate-limit'
import { revalidateStorefront } from '@/lib/revalidate'

export async function POST(request: NextRequest) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  const session = await auth()
  const userId = session?.user?.id
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { addressId, paymentMethod, items, couponCode, deliveryMethod = 'DELIVERY', isB2B = false, scheduledSlot = 'INSTANT', shopName = null, shopPhone = null } = await request.json()

    if (!paymentMethod || !items || items.length === 0) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (deliveryMethod !== 'PICKUP' && !addressId) {
      return NextResponse.json({ error: 'Delivery address is required' }, { status: 400 })
    }

    // 1. Resolve address
    let finalAddressId = addressId
    if (deliveryMethod === 'PICKUP') {
      // Find or create a STORE_PICKUP address for the user to satisfy DB FK constraints
      let pickupAddress = await prisma.address.findFirst({
        where: { userId, label: 'STORE_PICKUP' }
      })
      if (!pickupAddress) {
        pickupAddress = await prisma.address.create({
          data: {
            userId,
            label: 'STORE_PICKUP',
            houseNo: 'Vikas Medical Store',
            street: 'NH34, Ghatampur',
            area: 'Kanpur Nagar',
            city: 'Kanpur',
            pincode: '209206',
            phone: '+917054470303',
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

    if (deliveryMethod === 'DELIVERY') {
      const p = address.pincode.trim()
      const c = address.city.trim().toLowerCase()
      if (p !== '209206' && p !== '560034') {
        return NextResponse.json({ error: 'Selected address is outside our delivery zone. Pincode must be 209206.' }, { status: 400 })
      }
      if (!c.includes('ghatampur') && !c.includes('kanpur') && !c.includes('bangalore')) {
        return NextResponse.json({ error: 'Selected address city is outside our delivery zone.' }, { status: 400 })
      }
    }

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

    // Define helper to check if a product is a Cafe product
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

    // Enforce B2B Wholesale minimum order value
    if (isB2B && combinedSubtotal < 1000) {
      return NextResponse.json({ error: 'B2B Wholesale orders require a minimum subtotal of ₹1,000' }, { status: 400 })
    }

    // 3. Resolve Coupon/Wholesale Discount
    let combinedDiscount = 0
    let couponId = null

    if (isB2B) {
      combinedDiscount = combinedSubtotal * 0.1 // Flat 10% wholesale discount
    } else if (couponCode) {
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

    // Fetch store settings for dynamic tax and miscellaneous fee
    const storeSettings = await prisma.storeSetting.findMany()
    const settingsMap = storeSettings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    const taxPercent = parseFloat(settingsMap['tax_rate'] || '5')
    const serverTaxRate = taxPercent / 100
    const serverMiscFee = parseFloat(settingsMap['misc_fee'] || '0')

    // Calculate details for each order to create
    const ordersToCreate: any[] = []

    if (groceryItems.length > 0) {
      const grocerySubtotal = groceryItems.reduce((sum, item) => sum + item.dbProduct.price * item.quantity, 0)
      const groceryDiscount = combinedSubtotal > 0 ? (grocerySubtotal / combinedSubtotal) * combinedDiscount : 0
      const groceryDeliveryFee = (deliveryMethod === 'PICKUP' || isB2B) ? 0 : (grocerySubtotal >= FREE_DELIVERY_THRESHOLD ? 0 : DELIVERY_FEE)
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
      const cafeSubtotal = cafeItems.reduce((sum, item) => sum + item.dbProduct.price * item.quantity, 0)
      const cafeDiscount = combinedSubtotal > 0 ? (cafeSubtotal / combinedSubtotal) * combinedDiscount : 0
      const cafeDeliveryFee = (deliveryMethod === 'PICKUP' || isB2B) ? 0 : (cafeSubtotal >= 200 ? 0 : 25)
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

      for (const orderInfo of ordersToCreate) {
        const orderItemsData = orderInfo.items.map((item: any) => {
          const isVariant = item.product.id.includes('_')
          const [_, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]
          
          let itemPrice = item.dbProduct.price
          if (isVariant && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
            const variant = (item.dbProduct.variants as any[]).find((v) => v.name === variantName)
            if (variant) {
              itemPrice = variant.price
            }
          }

          return {
            productId: item.dbProduct.id,
            name: item.product.name,
            price: itemPrice,
            quantity: item.quantity,
            imageUrl: item.dbProduct.imageUrl,
            selectedVariant: variantName,
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
            shopPhone: orderInfo.type === 'CAFE' ? '+91 70544 70303' : shopPhone,
            items: {
              create: orderItemsData.map((item: any) => ({
                productId: item.productId,
                name: item.name,
                price: item.price,
                quantity: item.quantity,
                imageUrl: item.imageUrl,
                selectedVariant: item.selectedVariant,
              })),
            },
          },
          include: {
            items: true,
            address: true,
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
    })

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

    // Emit real-time SSE event for each newly created order
    try {
      const { sseEmitter } = require('@/lib/sse-emitter')
      for (const order of createdOrders) {
        sseEmitter.emit('order', {
          type: 'new-order',
          orderId: order.id,
          shopName: order.shopName,
          status: order.status,
          total: order.total,
          createdAt: order.createdAt,
        })
      }
    } catch (sseErr) {
      console.error('Failed to emit SSE for new orders:', sseErr)
    }

    const mainOrder = createdOrders.find((o) => o.shopName !== 'FastKirana Cafe Kitchen') || createdOrders[0]
    return NextResponse.json(mainOrder)
  } catch (error: any) {
    console.error('Order creation error:', error)
    return NextResponse.json({ error: 'Failed to place order' }, { status: 500 })
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
        LIMIT 100
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
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone"
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

    return NextResponse.json(result)
  } catch (error) {
    console.error('Orders list API error:', error)
    return NextResponse.json({ error: 'Failed to fetch orders' }, { status: 500 })
  }
}
