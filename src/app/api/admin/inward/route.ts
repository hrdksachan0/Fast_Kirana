import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { requireAdmin } from '@/lib/auth-guard'

export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { productId, barcode, batchCode, quantity, costPrice, expiryDate, name } = body as {
      productId?: string
      barcode?: string
      batchCode?: string
      quantity: string | number
      costPrice?: string | number
      expiryDate?: string
      name?: string
    }

    if (!productId && !barcode && !name) {
      return NextResponse.json(
        { error: 'Missing required field: please provide productId, barcode, or product name' },
        { status: 400 }
      )
    }

    const parsedQty = parseInt(String(quantity), 10)
    if (isNaN(parsedQty) || parsedQty <= 0) {
      return NextResponse.json({ error: 'Quantity must be a positive number' }, { status: 400 })
    }

    // Auto-generate batch code if blank
    const finalBatchCode = (batchCode && typeof batchCode === 'string' && batchCode.trim().length > 0)
      ? batchCode.trim()
      : `GRN_${new Date().toISOString().slice(0, 10).replace(/-/g, '')}_${Math.random().toString(36).slice(2, 6).toUpperCase()}`

    // Expiry date: default to 180 days from now if not provided or invalid
    let parsedExpiry = new Date(Date.now() + 180 * 24 * 60 * 60 * 1000)
    if (expiryDate) {
      const candidate = new Date(expiryDate)
      if (!isNaN(candidate.getTime())) {
        parsedExpiry = candidate
      }
    }

    // Process inward and aggregate updates inside a transaction
    const result = await prisma.$transaction(async (tx) => {
      // 1. Verify product exists (by id, barcode, or name)
      let product = null
      if (productId) {
        product = await tx.product.findUnique({
          where: { id: productId }
        })
      }
      if (!product && barcode) {
        product = await tx.product.findUnique({
          where: { barcode: String(barcode).trim() }
        })
      }
      if (!product && name) {
        product = await tx.product.findFirst({
          where: { name: { equals: String(name).trim(), mode: 'insensitive' } }
        })
      }

      if (!product) {
        throw new Error('Product not found in catalog. Please check the barcode or product name.')
      }

      const activeProductId = product.id
      const parsedCost = (costPrice !== undefined && !isNaN(parseFloat(String(costPrice))))
        ? parseFloat(String(costPrice))
        : (product.costPrice && product.costPrice > 0 ? product.costPrice : Math.round(product.price * 0.75))

      // 2. Create the new batch record
      let newBatch = null
      try {
        newBatch = await tx.productBatch.create({
          data: {
            productId: activeProductId,
            batchCode: finalBatchCode,
            quantity: parsedQty,
            initialQty: parsedQty,
            costPrice: parsedCost,
            expiryDate: parsedExpiry,
          }
        })
      } catch (batchErr) {
        console.warn('Non-fatal warning creating productBatch:', batchErr)
      }

      // 3. Compute new total stock
      const prevStock = product.stock ?? 0
      const newTotalStock = prevStock + parsedQty

      // 4. Update the aggregate fields on the parent Product
      const updatedProduct = await tx.product.update({
        where: { id: activeProductId },
        data: {
          stock: newTotalStock,
          costPrice: parsedCost,
          isAvailable: true, // Automatically ensure item is available upon inward
          ...(product.expiryDate ? {} : { expiryDate: parsedExpiry }),
        },
        include: {
          category: true
        }
      })

      // 5. Create StockLog entry for audit trail
      try {
        await tx.stockLog.create({
          data: {
            productId: activeProductId,
            quantity: parsedQty,
            type: 'INWARD_GRN',
            prevStock,
            newStock: newTotalStock
          }
        })
      } catch (logErr) {
        console.warn('Non-fatal warning creating stockLog:', logErr)
      }

      return { updatedProduct, newBatch }
    })

    // Invalidate storefront caches on-demand since stock levels updated
    try {
      revalidateStorefront(result.updatedProduct.category?.slug)
    } catch (e) {
      console.error('Storefront revalidation failed:', e)
    }

    return NextResponse.json({
      success: true,
      message: `Successfully inwarded ${parsedQty} units for "${result.updatedProduct.name}" (Batch: ${finalBatchCode}).`,
      batch: result.newBatch,
      product: result.updatedProduct
    })

  } catch (error: any) {
    console.error('Failed to inward batch:', error)
    return NextResponse.json(
      { error: error.message || 'Failed to inward product batch' },
      { status: 500 }
    )
  }
}
