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
    if (!positions || !Array.isArray(positions) || positions.length === 0) {
      return NextResponse.json({ error: 'positions array is required' }, { status: 400 })
    }

    // Chunk updates into batches of 10 to avoid transaction limits
    const CHUNK_SIZE = 10
    let updatedCount = 0

    for (let i = 0; i < positions.length; i += CHUNK_SIZE) {
      const chunk = positions.slice(i, i + CHUNK_SIZE)
      await prisma.$transaction(
        chunk.map((p: { id: string; sortOrder: number }) =>
          prisma.product.update({
            where: { id: p.id },
            data: { sortOrder: typeof p.sortOrder === 'number' ? p.sortOrder : parseInt(p.sortOrder) || 0 }
          })
        )
      )
      updatedCount += chunk.length
    }

    // Clear Next.js cache so storefront shows new positions immediately
    try {
      await revalidateStorefront()
    } catch (e) {
      console.warn('Revalidation failed, cache will refresh eventually:', e)
    }

    return NextResponse.json({ success: true, updated: updatedCount })
  } catch (error: any) {
    console.error('Bulk sort update failed:', error)
    return NextResponse.json({ error: error.message || 'Failed to update positions' }, { status: 500 })
  }
}
