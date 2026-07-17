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

    const { positions } = await request.json()
    if (!positions || !Array.isArray(positions)) {
      return NextResponse.json({ error: 'positions array is required' }, { status: 400 })
    }

    // Perform bulk updates inside a transaction
    await prisma.$transaction(
      positions.map((p: { id: string; sortOrder: number }) =>
        prisma.product.update({
          where: { id: p.id },
          data: { sortOrder: p.sortOrder }
        })
      )
    )

    // Clear Next.js cache so storefront shows new positions immediately
    try {
      await revalidateStorefront()
    } catch (e) {
      console.warn('Revalidation failed, cache will refresh eventually:', e)
    }

    return NextResponse.json({ success: true, updated: positions.length })
  } catch (error: any) {
    console.error('Bulk sort update failed:', error)
    return NextResponse.json({ error: error.message || 'Failed to update positions' }, { status: 500 })
  }
}
