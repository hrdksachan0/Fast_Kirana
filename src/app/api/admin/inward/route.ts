import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { productId, batchCode, quantity, costPrice, expiryDate } = body as {
      productId: string
      batchCode: string
      quantity: string | number
      costPrice: string | number
      expiryDate: string
    }

    if (!productId || !batchCode || !quantity || costPrice === undefined || !expiryDate) {
      return NextResponse.json(
        { error: 'Missing required fields: productId, batchCode, quantity, costPrice, expiryDate' },
        { status: 400 }
      )
    }

    const parsedQty = parseInt(String(quantity), 10)
    const parsedCost = parseFloat(String(costPrice))
    const parsedExpiry = new Date(expiryDate)

    if (isNaN(parsedQty) || parsedQty <= 0) {
      return NextResponse.json({ error: 'Quantity must be a positive integer' }, { status: 400 })
    }

    if (isNaN(parsedCost) || parsedCost < 0) {
      return NextResponse.json({ error: 'Cost price must be a non-negative number' }, { status: 400 })
    }

    if (isNaN(parsedExpiry.getTime())) {
      return NextResponse.json({ error: 'Invalid expiry date format' }, { status: 400 })
    }

    // Process inward and aggregate updates inside a transaction
    const result = await prisma.$transaction(async (tx) => {
      // 1. Verify product exists
      const product = await tx.product.findUnique({
        where: { id: productId }
      })

      if (!product) {
        throw new Error('Product not found')
      }

      // 2. Create the new batch record
      const newBatch = await tx.productBatch.create({
        data: {
          productId,
          batchCode,
          quantity: parsedQty,
          initialQty: parsedQty,
          costPrice: parsedCost,
          expiryDate: parsedExpiry,
        }
      })

      // 3. Query all active batches to compute new stock level and earliest expiry
      const activeBatches = await tx.productBatch.findMany({
        where: {
          productId,
          quantity: { gt: 0 }
        },
        orderBy: {
          expiryDate: 'asc'
        }
      })

      const newTotalStock = activeBatches.reduce((sum, b) => sum + b.quantity, 0)
      const newEarliestExpiry = activeBatches.length > 0 ? activeBatches[0].expiryDate : null

      // 4. Update the aggregate fields on the parent Product
      const updatedProduct = await tx.product.update({
        where: { id: productId },
        data: {
          stock: newTotalStock,
          expiryDate: newEarliestExpiry,
          costPrice: parsedCost, // Latest batch cost price becomes current cost price
        },
        include: {
          category: true
        }
      })

      return { updatedProduct, newBatch }
    })

    // Invalidate storefront caches on-demand since stock levels updated
    revalidateStorefront(result.updatedProduct.category?.slug)

    return NextResponse.json({
      success: true,
      message: `Successfully registered batch ${batchCode} with ${parsedQty} units.`,
      batch: result.newBatch,
      product: result.updatedProduct
    })

  } catch (error: any) {
    console.error('Failed to inward batch:', error)
    return NextResponse.json(
      { error: error.message || 'Failed to register batch in database' },
      { status: 500 }
    )
  }
}
