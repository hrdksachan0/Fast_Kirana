import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const type = searchParams.get('type') // e.g. 'grocery' or 'cafe'

    const whereClause: any = {
      isActive: true
    }

    if (type === 'cafe' || type === 'food') {
      whereClause.OR = [
        { type: { in: ['cafe', 'food'] } },
        { linkUrl: { startsWith: '/restaurant' } }
      ]
    } else if (type === 'brand_offer' || type === 'curated_card') {
      whereClause.type = { in: ['brand_offer', 'curated_card', 'dark_showcase', 'bento_grid', 'editorial'] }
    } else if (type === 'festive') {
      whereClause.type = 'festive'
    } else if (type === 'grocery') {
      whereClause.AND = [
        { type: { notIn: ['cafe', 'food'] } },
        { NOT: { linkUrl: { startsWith: '/restaurant' } } }
      ]
    }

    const banners = await prisma.promoBanner.findMany({
      where: whereClause,
      orderBy: {
        sortOrder: 'asc'
      }
    })

    const parsedBanners = banners.map(b => {
      let extra: any = {}
      if (b.code && b.code.startsWith('{') && b.code.endsWith('}')) {
        try {
          extra = JSON.parse(b.code)
        } catch (_) {}
      }
      return {
        ...b,
        ...extra,
        rawCode: b.code,
        couponCode: extra.couponCode !== undefined ? extra.couponCode : null,
        code: b.code,
        cardType: extra.cardType || b.type || 'standard',
      }
    })

    return NextResponse.json(parsedBanners, {
      headers: {
        'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120',
      }
    })
  } catch (error: any) {
    console.error('Error fetching promo banners:', error)
    return NextResponse.json({ error: 'Failed to fetch banners' }, { status: 500 })
  }
}
