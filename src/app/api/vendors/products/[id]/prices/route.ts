import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    const body = await request.json()
    const { costPrice, price, mrp, stock, variants } = body

    const updateData: any = {}
    if (costPrice !== undefined) updateData.costPrice = Number(costPrice)
    if (price !== undefined) updateData.price = Number(price)
    if (mrp !== undefined) updateData.mrp = Number(mrp)
    if (stock !== undefined) updateData.stock = Number(stock)
    if (variants !== undefined) {
      let parsedVariants = Array.isArray(variants)
        ? variants
        : (typeof variants === 'string' && variants.trim().length > 0
            ? JSON.parse(variants)
            : variants)

      if (Array.isArray(parsedVariants) && parsedVariants.length > 0) {
        const fallbackCost = parsedVariants.length === 1 && updateData.costPrice !== undefined ? updateData.costPrice : 0
        parsedVariants = parsedVariants.map((v: any) => {
          const vCost = Number(v.costPrice ?? v.cp ?? v.cost ?? 0) || 0
          return {
            ...v,
            costPrice: vCost > 0 ? vCost : (fallbackCost > 0 ? fallbackCost : 0),
          }
        })
      }
      updateData.variants = parsedVariants
    }

    const updated = await prisma.product.update({
      where: { id },
      data: updateData,
    })

    return NextResponse.json({ success: true, product: updated })
  } catch (error: any) {
    return NextResponse.json({ error: error.message || 'Failed to update product price' }, { status: 500 })
  }
}

export async function PATCH(
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  return PUT(request, context)
}
