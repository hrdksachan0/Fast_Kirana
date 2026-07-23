import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const type = searchParams.get('type') // e.g. 'grocery' or 'cafe'

    const whereClause: any = {
      isActive: true
    }

    if (type === 'cafe') {
      whereClause.type = 'cafe'
    } else if (type === 'grocery') {
      whereClause.NOT = {
        type: 'cafe'
      }
    }

    const banners = await prisma.promoBanner.findMany({
      where: whereClause,
      orderBy: {
        sortOrder: 'asc'
      }
    })

    return NextResponse.json(banners, {
      headers: {
        'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120',
      }
    })
  } catch (error: any) {
    console.error('Error fetching promo banners:', error)
    return NextResponse.json({ error: 'Failed to fetch banners' }, { status: 500 })
  }
}
