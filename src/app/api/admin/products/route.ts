import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { revalidateStorefront } from '@/lib/revalidate'

export async function GET(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(request.url)
  const page = parseInt(searchParams.get('page') || '1')
  const limit = parseInt(searchParams.get('limit') || '20')
  const categoryId = searchParams.get('categoryId')
  const search = searchParams.get('search')
  const lowStock = searchParams.get('lowStock') === 'true'
  const flashDeals = searchParams.get('flashDeals') === 'true'
  const topPicks = searchParams.get('topPicks') === 'true'
  const bestSellers = searchParams.get('bestSellers') === 'true'
  const type = searchParams.get('type')
  
  const skip = (page - 1) * limit

  try {
    const where: any = {}
    const andClauses: any[] = []

    if (categoryId && categoryId !== 'ALL' && categoryId !== 'undefined' && categoryId !== 'null') {
      andClauses.push({ categoryId })
    }

    if (lowStock) {
      andClauses.push({ stock: { lt: 15 } })
    }

    if (flashDeals) {
      andClauses.push({ isFlashDeal: true })
    }

    if (topPicks) {
      andClauses.push({ isTopPick: true })
    }

    if (bestSellers) {
      andClauses.push({ isBestSeller: true })
    }

    if (search) {
      andClauses.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { slug: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          { tags: { has: search } },
        ]
      })
    }

    if (type === 'cafe' || type === 'restaurant') {
      andClauses.push({
        restaurantId: { not: null }
      })
    } else if (type === 'grocery') {
      andClauses.push({
        restaurantId: null
      })
    }

    if (andClauses.length > 0) {
      where.AND = andClauses
    }

    const [productsRaw, total] = await Promise.all([
      prisma.product.findMany({
        where,
        include: {
          category: true,
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: limit,
      }),
      prisma.product.count({ where }),
    ])

    const products = productsRaw.map((p) => ({
      id: p.id,
      name: p.name,
      slug: p.slug,
      description: p.description,
      imageUrl: p.imageUrl,
      categoryId: p.categoryId,
      restaurantId: p.restaurantId,
      mrp: p.mrp,
      price: p.price,
      discount: p.discount,
      unit: p.unit,
      stock: p.stock,
      isAvailable: p.isAvailable,
      tags: p.tags,
      variants: p.variants,
      costPrice: p.costPrice ?? 0,
      minStock: p.minStock ?? 10,
      location: p.location,
      barcode: p.barcode || '',
      sortOrder: p.sortOrder ?? 0,
      isFlashDeal: p.isFlashDeal,
      isTopPick: p.isTopPick,
      isBestSeller: p.isBestSeller,
      category: {
        id: p.category.id,
        name: p.category.name,
        slug: p.category.slug,
      },
    }))

    return NextResponse.json({ products, total, page, limit })
  } catch (error: any) {
    console.error('Failed to fetch admin products:', error)
    return NextResponse.json({ error: 'Failed to fetch products' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const { name, categoryId, barcode, mrp, price, stock, unit, imageUrl, brand, isAvailable } = body

    if (!name || mrp === undefined || price === undefined) {
      return NextResponse.json({ error: 'Name, MRP, and Price are required' }, { status: 400 })
    }

    let finalCategoryId = categoryId
    if (!finalCategoryId) {
      const firstCat = await prisma.category.findFirst({
        where: { slug: { notIn: ['restaurant-food', 'restaurant', 'cafe'] } },
        orderBy: { sortOrder: 'asc' }
      })
      if (firstCat) finalCategoryId = firstCat.id
    }

    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')

    const existingSlug = await prisma.product.findUnique({ where: { slug } })
    const finalSlug = existingSlug ? `${slug}-${Date.now().toString().slice(-4)}` : slug

    const parsedMrp = parseFloat(String(mrp)) || 0
    const parsedPrice = parseFloat(String(price)) || parsedMrp
    const discount = parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0

    const lastProduct = await prisma.product.findFirst({
      orderBy: { readableId: 'desc' },
      select: { readableId: true }
    })
    const nextReadableId = lastProduct?.readableId ? lastProduct.readableId + 1 : 200001

    const product = await prisma.product.create({
      data: {
        name: name.trim(),
        slug: finalSlug,
        readableId: nextReadableId,
        categoryId: finalCategoryId,
        barcode: barcode && typeof barcode === 'string' ? barcode.trim() : null,
        mrp: parsedMrp,
        price: parsedPrice,
        discount,
        stock: parseInt(String(stock), 10) || 0,
        unit: (unit && typeof unit === 'string') ? unit.trim() : '1 pc',
        imageUrl: imageUrl || null,
        isAvailable: isAvailable !== undefined ? !!isAvailable : true,
      },
      include: {
        category: true,
      }
    })

    revalidateStorefront(product.category?.slug)

    return NextResponse.json(product, { status: 201 })
  } catch (err: any) {
    console.error('Failed to create product in admin API:', err)
    return NextResponse.json({ error: err.message || 'Failed to create product' }, { status: 500 })
  }
}
