import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'
import { revalidateTag } from 'next/cache'
import { revalidateStorefront } from '@/lib/revalidate'

// GET: Retrieve banners scoped by store hub
export async function GET(request: NextRequest) {
  try {
    const adminResult = await requireAdmin(request)
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const { searchParams } = new URL(request.url)
    const effectiveStoreId = getEffectiveStoreId(session, searchParams.get('storeId'))

    const where: any = {}
    if (effectiveStoreId && effectiveStoreId !== 'all') {
      where.storeId = effectiveStoreId
    }

    const banners = await prisma.promoBanner.findMany({
      where,
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
        code: extra.couponCode !== undefined ? extra.couponCode : b.code,
        cardType: extra.cardType || b.type || 'standard',
        storeId: b.storeId || extra.storeId || null,
      }
    })

    return NextResponse.json(parsedBanners)
  } catch (error: any) {
    console.error('Error fetching admin banners from Prisma, attempting FastAPI proxy fallback:', error)
    try {
      const apiDest = process.env.NEXT_PUBLIC_FASTAPI_URL || process.env.NEXT_PUBLIC_API_URL || 'https://fastkirana-production-0cdd.up.railway.app'
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
    const adminResult = await requireAdmin()
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const body = await request.json()
    const { title, description, code, gradient, type, imageUrl, linkUrl, isActive, sortOrder } = body

    const finalTitle = (title && String(title).trim()) || 'Promo Banner'
    const finalDescription = (description && String(description).trim()) || 'Media Banner'

    const isCardType = true
    let serializedCode = code || ''
    const cardMeta = {
      cardType: body.cardType || type || 'standard',
      placement: body.placement || (['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(type) ? 'brand_card' : 'hero'),
      platform: body.platform || 'all',
      storeId: body.storeId || null,
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
    const effectiveStoreId = getEffectiveStoreId(session, body.storeId)
    cardMeta.storeId = effectiveStoreId || null
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
        storeId: effectiveStoreId || null,
        isActive: isActive !== undefined ? isActive : true,
        sortOrder: sortOrder !== undefined ? parseInt(String(sortOrder), 10) : 0,
      }
    })

    // Purge caches immediately
    revalidateTag('banners', 'max')
    revalidateStorefront()

    return NextResponse.json({ success: true, banner })
  } catch (error: any) {
    console.error('Error creating banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to create banner' }, { status: 500 })
  }
}

// PUT: Update an existing promo banner / curated card
export async function PUT(request: NextRequest) {
  try {
    const adminResult = await requireAdmin()
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

    const cardMeta = {
      cardType: body.cardType || type || existing.type || 'standard',
      placement: body.placement !== undefined ? body.placement : (existingMeta.placement || 'hero'),
      platform: body.platform !== undefined ? body.platform : (existingMeta.platform || 'all'),
      storeId: body.storeId !== undefined ? body.storeId : (existingMeta.storeId || null),
      eyebrowTag: body.eyebrowTag !== undefined ? body.eyebrowTag : null,
      primaryBrand: body.primaryBrand !== undefined ? body.primaryBrand : null,
      secondaryBrand: body.secondaryBrand !== undefined ? body.secondaryBrand : null,
      cashbackTitle: body.cashbackTitle !== undefined ? body.cashbackTitle : null,
      cashbackSubtitle: body.cashbackSubtitle !== undefined ? body.cashbackSubtitle : null,
      disclaimerText: body.disclaimerText !== undefined ? body.disclaimerText : null,
      ctaText: body.ctaText !== undefined ? body.ctaText : null,
      ctaUrl: body.ctaUrl !== undefined ? body.ctaUrl : null,
      ctaBgColorHex: body.ctaBgColorHex !== undefined ? body.ctaBgColorHex : null,
      ctaTextColorHex: body.ctaTextColorHex !== undefined ? body.ctaTextColorHex : null,
      gridImages: body.gridImages !== undefined ? body.gridImages : null,
      hasWireframeGrid: body.hasWireframeGrid !== undefined ? body.hasWireframeGrid : false,
      videoUrl: body.videoUrl !== undefined ? body.videoUrl : null,
      couponCode: code || null,
    }
    const serializedCode = JSON.stringify(cardMeta)

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
        storeId: body.storeId !== undefined ? body.storeId : existing.storeId,
        isActive: isActive !== undefined ? isActive : existing.isActive,
        sortOrder: sortOrder !== undefined ? parseInt(String(sortOrder), 10) : existing.sortOrder,
      }
    })

    // Purge caches immediately
    revalidateTag('banners', 'max')
    revalidateStorefront()

    return NextResponse.json({ success: true, banner: updated })
  } catch (error: any) {
    console.error('Error updating banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to update banner' }, { status: 500 })
  }
}

// DELETE: Delete a promo banner
export async function DELETE(request: NextRequest) {
  try {
    const adminResult = await requireAdmin()
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

    // Purge caches immediately
    revalidateTag('banners', 'max')
    revalidateStorefront()

    return NextResponse.json({ success: true, message: 'Banner deleted successfully' })
  } catch (error: any) {
    console.error('Error deleting banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to delete banner' }, { status: 500 })
  }
}
