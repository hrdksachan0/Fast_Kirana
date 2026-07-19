import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { OrderStatus, PaymentStatus, PaymentMethod } from '@prisma/client'
import { revalidateStorefront } from '@/lib/revalidate'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { items, paymentMethod, subtotal, discount, total } = body as {
      items: Array<{
        productId: string
        quantity: number
        price: number // Billed selling price (can be MRP or custom or discounted)
      }>
      paymentMethod: string
      subtotal: number
      discount: number
      total: number
    }

    if (!items || items.length === 0) {
      return NextResponse.json({ error: 'No items in transaction' }, { status: 400 })
    }

    // 1. Get or Create Default Walk-in Customer User
    const walkinEmail = 'walkin@fastkirana.in'
    let walkinUser = await prisma.user.findUnique({
      where: { email: walkinEmail }
    })

    if (!walkinUser) {
      walkinUser = await prisma.user.create({
        data: {
          email: walkinEmail,
          name: 'Walk-in Customer',
          phone: '0000000000',
          role: 'USER',
          passwordHash: 'WALKIN_NO_PASS'
        }
      })
    }

    // 2. Get or Create Default Walk-in Customer Address
    let walkinAddress = await prisma.address.findFirst({
      where: { userId: walkinUser.id, label: 'RETAIL_COUNTER' }
    })

    if (!walkinAddress) {
      walkinAddress = await prisma.address.create({
        data: {
          userId: walkinUser.id,
          label: 'RETAIL_COUNTER',
          houseNo: 'Retail Counter',
          street: 'Ghatampur Store',
          area: 'Vikas Medical Store, NH34',
          city: 'Kanpur',
          pincode: '209206',
          phone: '0000000000',
          isDefault: true
        }
      })
    }

    // Determine PaymentMethod enum
    let pm: PaymentMethod = PaymentMethod.COD
    if (paymentMethod === 'UPI') pm = PaymentMethod.UPI
    if (paymentMethod === 'CARD') pm = PaymentMethod.CARD
    if (paymentMethod === 'WALLET') pm = PaymentMethod.WALLET

    // 3. Process the checkout inside a database transaction
    const order = await prisma.$transaction(async (tx) => {
      // Find the highest readableId for the order counter
      const lastOrder = await tx.order.findFirst({
        orderBy: { readableId: 'desc' }
      })
      const nextReadableId = (lastOrder?.readableId || 0) + 1

      // Create Order
      const newOrder = await tx.order.create({
        data: {
          readableId: nextReadableId,
          userId: walkinUser.id,
          addressId: walkinAddress.id,
          status: OrderStatus.DELIVERED,
          subtotal,
          discount,
          total,
          paymentMethod: pm,
          paymentStatus: PaymentStatus.PAID,
          deliveryMethod: 'RETAIL',
          deliveredAt: new Date(),
          confirmedAt: new Date(),
          packedAt: new Date(),
          shippedAt: new Date()
        }
      })

      // Process each item
      for (const item of items) {
        const product = await tx.product.findUnique({
          where: { id: item.productId }
        })

        if (!product) {
          throw new Error(`Product with ID ${item.productId} not found`)
        }

        // Write order item
        const costPrice = product.costPrice || product.price * 0.75 // Fallback if no cost price loaded
        await tx.orderItem.create({
          data: {
            orderId: newOrder.id,
            productId: item.productId,
            name: product.name,
            quantity: item.quantity,
            price: item.price,
            costPrice
          }
        })

        // Decrement product stock (FIFO batch calculation if active batches exist)
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

        // Query active batches again to compute new aggregate stock level
        const activeBatches = await tx.productBatch.findMany({
          where: {
            productId: item.productId,
            quantity: { gt: 0 }
          },
          orderBy: { expiryDate: 'asc' }
        })

        const prevStock = product.stock
        const newTotalStock = activeBatches.length > 0 
          ? activeBatches.reduce((sum, b) => sum + b.quantity, 0)
          : Math.max(0, prevStock - item.quantity)
        
        const newEarliestExpiry = activeBatches.length > 0 ? activeBatches[0].expiryDate : null

        // Update product stock aggregate
        await tx.product.update({
          where: { id: item.productId },
          data: {
            stock: newTotalStock,
            expiryDate: newEarliestExpiry
          }
        })

        // Create Stock Log entry
        await tx.stockLog.create({
          data: {
            productId: item.productId,
            quantity: -item.quantity, // negative representing sale
            type: 'RETAIL_POS',
            prevStock,
            newStock: newTotalStock
          }
        })
      }

      return newOrder
    })

    // Revalidate storefront cache
    try {
      revalidateStorefront()
    } catch (e) {
      console.error('POS revalidation error:', e)
    }

    return NextResponse.json({
      success: true,
      message: 'Retail counter sale registered successfully!',
      orderId: order.id,
      readableId: order.readableId
    })
  } catch (error: any) {
    console.error('POS checkout endpoint error:', error)
    return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 })
  }
}
