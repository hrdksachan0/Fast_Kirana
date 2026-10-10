import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'
import { revalidateTag } from 'next/cache'
import { revalidateStorefront } from '@/lib/revalidate'

export const dynamic = 'force-dynamic'
export const revalidate = 0

function formatPromoBanner(b: any) {
  let extra: any = {}
  if (b.code && b.code.startsWith('{') && b.code.endsWith('}')) {
    try {
      extra = JSON.parse(b.code)
    } catch (_) {}
  }
  return {
    ...extra,
    ...b,
    isActive: b.isActive,
    rawCode: b.code,
    code: extra.couponCode !== undefined ? extra.couponCode : b.code,
    cardType: extra.cardType || b.type || 'standard',
    storeId: b.storeId || extra.storeId || null,
  }
}

// GET: Retrieve banners scoped by store hub
export async function GET(request: NextRequest) {
  try {
    const adminResult = await requireAdmin(request)
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const { searchParams } = new URL(request.url)
    const effectiveStoreId = getEffectiveStoreId(session, searchParams.get('storeId'))

    const where: any = {}
    if (effectiveStoreId && effectiveStoreId !== 'all' && effectiveStoreId !== 'ALL') {
      where.OR = [
        { storeId: effectiveStoreId },
        { storeId: null },
      ]
    }

    const banners = await prisma.promoBanner.findMany({
      where,
      orderBy: {
        sortOrder: 'asc'
      }
    })

    const parsedBanners = banners.map(formatPromoBanner)

    return NextResponse.json(parsedBanners, {
      headers: {
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }
    })
  } catch (error: any) {
    console.error('Error fetching admin banners from Prisma, attempting FastAPI proxy fallback:', error)
    try {
      const apiDest = process.env.NEXT_PUBLIC_FASTAPI_URL || process.env.NEXT_PUBLIC_API_URL || 'https://api.fastkirana.in'
      const { searchParams } = new URL(request.url)
      const q = searchParams.toString() ? `?${searchParams.toString()}` : ''
      const res = await fetch(`${apiDest}/api/banners${q}`, {
        headers: { 'Content-Type': 'application/json' },
        next: { revalidate: 0 },
      })
      if (res.ok) {
        const data = await res.json()
        if (Array.isArray(data)) {
          return NextResponse.json(data)
        }
      }
    } catch (fallbackErr) {
      console.error('FastAPI fallback also failed:', fallbackErr)
    }
    return NextResponse.json([], { status: 200 })
  }
}

// POST: Create a new promo banner / curated card
export async function POST(request: NextRequest) {
  try {
    const adminResult = await requireAdmin(request)
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const body = await request.json()
    const { title, description, code, gradient, type, imageUrl, linkUrl, isActive, sortOrder } = body

    const finalTitle = (title && String(title).trim()) || 'Promo Banner'
    const finalDescription = (description && String(description).trim()) || 'Media Banner'

    const effectiveStoreId = getEffectiveStoreId(session, body.storeId)

    // Verify foreign key integrity with dark_stores
    let validStoreId: string | null = null
    if (effectiveStoreId && effectiveStoreId !== 'all' && effectiveStoreId !== 'ALL') {
      try {
        const storeExists = await prisma.darkStore.findUnique({
          where: { id: effectiveStoreId },
          select: { id: true },
        })
        if (storeExists) {
          validStoreId = storeExists.id
        }
      } catch (_) {}
    }

    let serializedCode = code || ''
    const cardMeta = {
      cardType: body.cardType || type || 'standard',
      placement: body.placement || (['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(type) ? 'brand_card' : 'hero'),
      platform: body.platform || 'all',
      storeId: validStoreId,
      eyebrowTag: body.eyebrowTag || null,
      primaryBrand: body.primaryBrand || null,
      secondaryBrand: body.secondaryBrand || null,
      cashbackTitle: body.cashbackTitle || null,
      cashbackSubtitle: body.cashbackSubtitle || null,
      disclaimerText: body.disclaimerText || null,
      ctaText: body.ctaText || null,
      ctaUrl: body.ctaUrl || null,
      ctaBgColorHex: body.ctaBgColorHex || null,
      ctaTextColorHex: body.ctaTextColorHex || null,
      gridImages: body.gridImages || null,
      hasWireframeGrid: body.hasWireframeGrid || false,
      videoUrl: body.videoUrl || null,
      couponCode: code || null,
    }
    serializedCode = JSON.stringify(cardMeta)

    const banner = await prisma.promoBanner.create({
      data: {
        title: finalTitle,
        description: finalDescription,
        code: serializedCode,
        gradient: gradient || 'from-primary via-rose-500 to-orange-400',
        type: type || 'custom',
        imageUrl: imageUrl || null,
        linkUrl: linkUrl || null,
        storeId: validStoreId,
        isActive: isActive !== undefined ? isActive : true,
        sortOrder: sortOrder !== undefined ? parseInt(String(sortOrder), 10) : 0,
      }
    })

    await purgeBannersCacheEverywhere()

    return NextResponse.json({ success: true, banner: formatPromoBanner(banner) })
  } catch (error: any) {
    console.error('Error creating banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to create banner' }, { status: 500 })
  }
}

async function purgeBannersCacheEverywhere() {
  try {
    revalidateTag('banners', 'max')
    revalidateStorefront()
  } catch (revalErr) {
    console.warn('[CacheRevalidation] non-fatal revalidate error:', revalErr)
  }

  // Ping FastAPI on both primary domain and Railway domain to invalidate in-memory & Redis cache
  const fastApiUrls = [
    process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://api.fastkirana.in',
    'https://fastkirana-production-a4b8.up.railway.app'
  ]

  for (const url of fastApiUrls) {
    try {
      fetch(`${url}/api/banners/clear-cache`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(3000),
      }).catch(() => {})
    } catch (_) {}
  }
}

// PUT: Update an existing promo banner / curated card
export async function PUT(request: NextRequest) {
  try {
    const adminResult = await requireAdmin(request)
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const body = await request.json()
    const { id, title, description, code, gradient, type, imageUrl, linkUrl, isActive, sortOrder } = body

    if (!id) {
      return NextResponse.json({ error: 'Missing banner ID' }, { status: 400 })
    }

    // Verify banner exists
    const existing = await prisma.promoBanner.findUnique({
      where: { id }
    })

    if (!existing) {
      return NextResponse.json({ error: 'Banner not found' }, { status: 404 })
    }

    let existingMeta: any = {}
    if (existing.code && existing.code.startsWith('{') && existing.code.endsWith('}')) {
      try { existingMeta = JSON.parse(existing.code) } catch (_) {}
    }

    const targetStoreId = body.storeId !== undefined ? body.storeId : existing.storeId
    let validStoreId: string | null = null
    if (targetStoreId && targetStoreId !== 'all' && targetStoreId !== 'ALL') {
      try {
        const storeExists = await prisma.darkStore.findUnique({
          where: { id: targetStoreId },
          select: { id: true },
        })
        if (storeExists) {
          validStoreId = storeExists.id
        }
      } catch (_) {}
    }

    const cardMeta = {
      ...existingMeta,
      ...(body.cardMeta || {}),
      cardType: body.cardType || type || existingMeta.cardType || existing.type || 'standard',
      placement: body.placement !== undefined ? body.placement : (existingMeta.placement || 'hero'),
      platform: body.platform !== undefined ? body.platform : (existingMeta.platform || 'all'),
      storeId: validStoreId !== null ? validStoreId : (existingMeta.storeId || existing.storeId),
      eyebrowTag: body.eyebrowTag !== undefined ? body.eyebrowTag : (existingMeta.eyebrowTag || null),
      primaryBrand: body.primaryBrand !== undefined ? body.primaryBrand : (existingMeta.primaryBrand || null),
      secondaryBrand: body.secondaryBrand !== undefined ? body.secondaryBrand : (existingMeta.secondaryBrand || null),
      cashbackTitle: body.cashbackTitle !== undefined ? body.cashbackTitle : (existingMeta.cashbackTitle || null),
      cashbackSubtitle: body.cashbackSubtitle !== undefined ? body.cashbackSubtitle : (existingMeta.cashbackSubtitle || null),
      disclaimerText: body.disclaimerText !== undefined ? body.disclaimerText : (existingMeta.disclaimerText || null),
      ctaText: body.ctaText !== undefined ? body.ctaText : (existingMeta.ctaText || null),
      ctaUrl: body.ctaUrl !== undefined ? body.ctaUrl : (existingMeta.ctaUrl || null),
      ctaBgColorHex: body.ctaBgColorHex !== undefined ? body.ctaBgColorHex : (existingMeta.ctaBgColorHex || null),
      ctaTextColorHex: body.ctaTextColorHex !== undefined ? body.ctaTextColorHex : (existingMeta.ctaTextColorHex || null),
      gridImages: body.gridImages !== undefined ? body.gridImages : (existingMeta.gridImages || null),
      hasWireframeGrid: body.hasWireframeGrid !== undefined ? body.hasWireframeGrid : (existingMeta.hasWireframeGrid || false),
      videoUrl: body.videoUrl !== undefined ? body.videoUrl : (existingMeta.videoUrl || null),
      couponCode: code !== undefined ? code : (existingMeta.couponCode || null),
    }
    const serializedCode = JSON.stringify(cardMeta)

    const resolvedIsActive = isActive !== undefined
      ? (typeof isActive === 'boolean' ? isActive : (isActive === 'true' || isActive === '1' || isActive === 1))
      : existing.isActive

    const updated = await prisma.promoBanner.update({
      where: { id },
      data: {
        title: title !== undefined ? title : existing.title,
        description: description !== undefined ? description : existing.description,
        code: serializedCode,
        gradient: gradient !== undefined ? gradient : existing.gradient,
        type: type !== undefined ? type : existing.type,
        imageUrl: imageUrl !== undefined ? imageUrl : existing.imageUrl,
        linkUrl: linkUrl !== undefined ? linkUrl : existing.linkUrl,
        storeId: validStoreId,
        isActive: resolvedIsActive,
        sortOrder: sortOrder !== undefined ? parseInt(String(sortOrder), 10) : existing.sortOrder,
      }
    })

    await purgeBannersCacheEverywhere()

    return NextResponse.json({ success: true, banner: formatPromoBanner(updated) })
  } catch (error: any) {
    console.error('Error updating banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to update banner' }, { status: 500 })
  }
}

// DELETE: Delete a promo banner
export async function DELETE(request: NextRequest) {
  try {
    const adminResult = await requireAdmin(request)
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const { searchParams } = new URL(request.url)
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json({ error: 'Missing banner ID' }, { status: 400 })
    }

    // Verify banner exists
    const existing = await prisma.promoBanner.findUnique({
      where: { id }
    })

    if (!existing) {
      return NextResponse.json({ error: 'Banner not found' }, { status: 404 })
    }

    await prisma.promoBanner.delete({
      where: { id }
    })

    await purgeBannersCacheEverywhere()

    return NextResponse.json({ success: true, message: 'Banner deleted successfully' })
  } catch (error: any) {
    console.error('Error deleting banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to delete banner' }, { status: 500 })
  }
}
