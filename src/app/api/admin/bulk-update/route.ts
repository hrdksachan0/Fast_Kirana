import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function generateBatchId(): string {
  return `batch_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

function computeNewValue(
  oldValue: number,
  mode: string,
  value: number,
): number {
  switch (mode) {
    case 'FLAT_INCREASE':
      return oldValue + value
    case 'FLAT_DECREASE':
      return Math.max(0, oldValue - value)
    case 'PERCENT_INCREASE':
      return oldValue * (1 + value / 100)
    case 'PERCENT_DECREASE':
      return Math.max(0, oldValue * (1 - value / 100))
    case 'SET_VALUE':
      return value
    default:
      return oldValue
  }
}

// Round to 2 decimal places for currency values
function round2(n: number): number {
  return Math.round(n * 100) / 100
}

// ---------------------------------------------------------------------------
// POST – Apply (or preview) a bulk update
// ---------------------------------------------------------------------------

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const {
      categoryId,
      productIds,
      updateType,
      mode,
      value,
      preview = false,
    } = body as {
      categoryId?: string
      productIds?: string[]
      updateType: 'PRICE' | 'STOCK' | 'AVAILABILITY'
      mode: 'FLAT_INCREASE' | 'FLAT_DECREASE' | 'PERCENT_INCREASE' | 'PERCENT_DECREASE' | 'SET_VALUE'
      value: number
      preview?: boolean
    }

    // Validate required fields
    if (!updateType || !mode || value === undefined || value === null) {
      return NextResponse.json(
        { error: 'Missing required fields: updateType, mode, value' },
        { status: 400 },
      )
    }

    if (!['PRICE', 'STOCK', 'AVAILABILITY'].includes(updateType)) {
      return NextResponse.json(
        { error: 'Invalid updateType. Must be PRICE, STOCK, or AVAILABILITY' },
        { status: 400 },
      )
    }

    if (
      !['FLAT_INCREASE', 'FLAT_DECREASE', 'PERCENT_INCREASE', 'PERCENT_DECREASE', 'SET_VALUE'].includes(mode)
    ) {
      return NextResponse.json(
        { error: 'Invalid mode' },
        { status: 400 },
      )
    }

    // Build the where clause to select products
    const whereClause: any = {}
    if (productIds && productIds.length > 0) {
      whereClause.id = { in: productIds }
    } else if (categoryId) {
      whereClause.categoryId = categoryId
    }
    // If neither is provided, we target ALL products

    const products = await prisma.product.findMany({
      where: whereClause,
      select: {
        id: true,
        name: true,
        price: true,
        mrp: true,
        stock: true,
        isAvailable: true,
      },
    })

    if (products.length === 0) {
      return NextResponse.json(
        { error: 'No products found matching the criteria' },
        { status: 404 },
      )
    }

    const batchId = generateBatchId()
    const changes: {
      productId: string
      name: string
      oldValue: number | boolean
      newValue: number | boolean
    }[] = []

    // Compute changes for each product
    for (const product of products) {
      if (updateType === 'PRICE') {
        const oldValue = product.price
        const newValue = round2(computeNewValue(oldValue, mode, value))
        changes.push({
          productId: product.id,
          name: product.name,
          oldValue,
          newValue,
        })
      } else if (updateType === 'STOCK') {
        const oldValue = product.stock
        const rawNew = computeNewValue(oldValue, mode, value)
        const newValue = Math.max(0, Math.round(rawNew))
        changes.push({
          productId: product.id,
          name: product.name,
          oldValue,
          newValue,
        })
      } else if (updateType === 'AVAILABILITY') {
        const oldValue = product.isAvailable
        const newValue = value === 1
        changes.push({
          productId: product.id,
          name: product.name,
          oldValue,
          newValue,
        })
      }
    }

    // If preview mode, return the computed changes without persisting
    if (preview) {
      return NextResponse.json({
        success: true,
        preview: true,
        updated: changes.length,
        batchId,
        changes,
      })
    }

    // Apply changes inside a transaction
    await prisma.$transaction(async (tx) => {
      for (const change of changes) {
        const product = products.find((p) => p.id === change.productId)!

        if (updateType === 'PRICE') {
          await tx.product.update({
            where: { id: change.productId },
            data: { price: change.newValue as number },
          })

          // Record price history
          await tx.priceHistory.create({
            data: {
              productId: change.productId,
              oldPrice: product.price,
              newPrice: change.newValue as number,
              oldMrp: product.mrp,
              newMrp: product.mrp, // MRP stays unchanged
              changeType: `BULK_${mode}`,
              changedBy: (session.user as any).email ?? session.user.name ?? 'ADMIN',
              batchId,
            },
          })
        } else if (updateType === 'STOCK') {
          await tx.product.update({
            where: { id: change.productId },
            data: { stock: change.newValue as number },
          })
        } else if (updateType === 'AVAILABILITY') {
          await tx.product.update({
            where: { id: change.productId },
            data: { isAvailable: change.newValue as boolean },
          })
        }
      }
    })

    return NextResponse.json({
      success: true,
      updated: changes.length,
      batchId,
      changes,
    })
  } catch (error: any) {
    console.error('Bulk update failed:', error)
    return NextResponse.json(
      { error: 'Internal Server Error', details: error.message || error },
      { status: 500 },
    )
  }
}

// ---------------------------------------------------------------------------
// GET – Price change history
// ---------------------------------------------------------------------------

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const batchId = searchParams.get('batchId')
    const limit = parseInt(searchParams.get('limit') || '20', 10)

    if (batchId) {
      // Return all records for a specific batch
      const records = await prisma.priceHistory.findMany({
        where: { batchId },
        orderBy: { createdAt: 'desc' },
        include: {
          product: { select: { name: true, slug: true } },
        },
      })

      return NextResponse.json({
        success: true,
        batchId,
        count: records.length,
        records: records.map((r) => ({
          id: r.id,
          productId: r.productId,
          productName: r.product.name,
          productSlug: r.product.slug,
          oldPrice: r.oldPrice,
          newPrice: r.newPrice,
          oldMrp: r.oldMrp,
          newMrp: r.newMrp,
          changeType: r.changeType,
          changedBy: r.changedBy,
          batchId: r.batchId,
          createdAt: r.createdAt.toISOString(),
        })),
      })
    }

    // Return recent price history grouped by batchId
    // First, get distinct batchIds ordered by most recent
    const recentBatches = await prisma.priceHistory.findMany({
      where: { batchId: { not: null } },
      distinct: ['batchId'],
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { batchId: true, createdAt: true, changeType: true },
    })

    const batchIds = recentBatches
      .map((b) => b.batchId)
      .filter((id): id is string => id !== null)

    // Now fetch all records for those batches
    const allRecords = await prisma.priceHistory.findMany({
      where: { batchId: { in: batchIds } },
      orderBy: { createdAt: 'desc' },
      include: {
        product: { select: { name: true, slug: true } },
      },
    })

    // Group by batchId
    const grouped: Record<
      string,
      {
        batchId: string
        changeType: string
        createdAt: string
        count: number
        records: any[]
      }
    > = {}

    for (const r of allRecords) {
      const bid = r.batchId!
      if (!grouped[bid]) {
        grouped[bid] = {
          batchId: bid,
          changeType: r.changeType,
          createdAt: r.createdAt.toISOString(),
          count: 0,
          records: [],
        }
      }
      grouped[bid].count++
      grouped[bid].records.push({
        id: r.id,
        productId: r.productId,
        productName: r.product.name,
        productSlug: r.product.slug,
        oldPrice: r.oldPrice,
        newPrice: r.newPrice,
        oldMrp: r.oldMrp,
        newMrp: r.newMrp,
        changedBy: r.changedBy,
        createdAt: r.createdAt.toISOString(),
      })
    }

    // Return in chronological order (most recent batch first)
    const batches = batchIds.map((bid) => grouped[bid]).filter(Boolean)

    return NextResponse.json({
      success: true,
      totalBatches: batches.length,
      batches,
    })
  } catch (error: any) {
    console.error('Failed to fetch price history:', error)
    return NextResponse.json(
      { error: 'Internal Server Error', details: error.message || error },
      { status: 500 },
    )
  }
}

// ---------------------------------------------------------------------------
// DELETE – Undo a bulk update by batchId
// ---------------------------------------------------------------------------

export async function DELETE(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { batchId } = body as { batchId: string }

    if (!batchId) {
      return NextResponse.json(
        { error: 'Missing required field: batchId' },
        { status: 400 },
      )
    }

    // Fetch all PriceHistory records for this batch
    const records = await prisma.priceHistory.findMany({
      where: { batchId },
    })

    if (records.length === 0) {
      return NextResponse.json(
        { error: 'No records found for the given batchId' },
        { status: 404 },
      )
    }

    // Revert each product and delete history in a transaction
    await prisma.$transaction(async (tx) => {
      for (const record of records) {
        // Revert product price and mrp to old values
        await tx.product.update({
          where: { id: record.productId },
          data: {
            price: record.oldPrice,
            mrp: record.oldMrp,
          },
        })
      }

      // Delete all PriceHistory records for this batch
      await tx.priceHistory.deleteMany({
        where: { batchId },
      })
    })

    return NextResponse.json({
      success: true,
      reverted: records.length,
    })
  } catch (error: any) {
    console.error('Failed to undo bulk update:', error)
    return NextResponse.json(
      { error: 'Internal Server Error', details: error.message || error },
      { status: 500 },
    )
  }
}
