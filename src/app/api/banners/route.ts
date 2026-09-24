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

    const placement = searchParams.get('placement') // 'hero' | 'brand_card'
    const platform = searchParams.get('platform') // 'mobile' | 'web'
    const storeId = searchParams.get('storeId') // active darkstore hub id

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
        placement: extra.placement || (['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(b.type) ? 'brand_card' : 'hero'),
        platform: extra.platform || 'all',
        storeId: extra.storeId || (b as any).storeId || null,
      }
    })

    const filteredBanners = parsedBanners.filter(b => {
      if (placement && b.placement !== placement) return false
      if (platform && b.platform !== 'all' && b.platform !== platform) return false

      // Hub / Store Scoping:
      // If storeId is provided, show banners matching this storeId OR global banners (storeId is null, empty, or 'all')
      // If banner has a specific storeId that does NOT match the requested storeId, filter it out!
      if (storeId && storeId !== 'all') {
        if (b.storeId !== storeId) {
          return false
        }
      }
      return true
    })

    return NextResponse.json(filteredBanners, {
      headers: {
        'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120',
      }
    })
  } catch (error: any) {
    console.error('Error fetching promo banners:', error)
    return NextResponse.json({ error: 'Failed to fetch banners' }, { status: 500 })
  }
}
