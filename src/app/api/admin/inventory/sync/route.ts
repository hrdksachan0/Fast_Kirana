import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const apiKey = searchParams.get('apiKey')

    const serverToken = process.env.INVENTORY_SYNC_TOKEN
    if (!serverToken || apiKey !== serverToken) {
      return NextResponse.json({ error: 'Unauthorized: Invalid API Key' }, { status: 401 })
    }

    const products = await prisma.product.findMany({
      orderBy: { name: 'asc' },
      select: {
        slug: true,
        name: true,
        mrp: true,
        price: true,
        stock: true,
        isAvailable: true,
        unit: true,
      },
    })

    return NextResponse.json({
      success: true,
      products,
    })
  } catch (error: any) {
    console.error('Failed to fetch inventory for sync:', error)
    return NextResponse.json({
      error: 'Internal Server Error',
      details: error.message || error,
    }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { apiKey, products } = body

    const serverToken = process.env.INVENTORY_SYNC_TOKEN
    if (!serverToken || apiKey !== serverToken) {
      return NextResponse.json({ error: 'Unauthorized: Invalid API Key' }, { status: 401 })
    }

    if (!products || !Array.isArray(products)) {
      return NextResponse.json({ error: 'Invalid payload: products list is required' }, { status: 400 })
    }

    let updatedCount = 0
    let skippedCount = 0
    const skippedSlugs: string[] = []

    // Execute updates in a database transaction to keep data consistent
    await prisma.$transaction(async (tx) => {
      for (const p of products) {
        if (!p.slug) {
          skippedCount++
          continue
        }

        // Verify if product exists before updating
        const existing = await tx.product.findUnique({
          where: { slug: p.slug },
          select: { id: true },
        })

        if (!existing) {
          skippedCount++
          skippedSlugs.push(p.slug)
          continue
        }

        // Apply pricing/stock inventory updates
        await tx.product.update({
          where: { slug: p.slug },
          data: {
            price: parseFloat(p.price) || 0,
            mrp: parseFloat(p.mrp) || 0,
            stock: parseInt(p.stock) || 0,
            isAvailable: p.isAvailable === true,
          },
        })
        updatedCount++
      }
    })

    return NextResponse.json({
      success: true,
      message: `Successfully synchronized inventory`,
      updated: updatedCount,
      skipped: skippedCount,
      skippedDetails: skippedSlugs,
    })

  } catch (error: any) {
    console.error('Failed to sync inventory from Google Sheets:', error)
    return NextResponse.json({
      error: 'Internal Server Error',
      details: error.message || error,
    }, { status: 500 })
  }
}
