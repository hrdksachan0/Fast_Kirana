import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { searchParams } = new URL(request.url)
  const page = parseInt(searchParams.get('page') || '1')
  const limit = parseInt(searchParams.get('limit') || '20')
  const categoryId = searchParams.get('categoryId')
  const search = searchParams.get('search')
  const lowStock = searchParams.get('lowStock') === 'true'
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

    if (type === 'cafe') {
      andClauses.push({
        OR: [
          { category: { slug: 'cafe' } },
          { tags: { has: 'cafe' } }
        ]
      })
    } else if (type === 'grocery') {
      andClauses.push({
        category: { slug: { not: 'cafe' } }
      })
      andClauses.push({
        NOT: { tags: { has: 'cafe' } }
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
      mrp: p.mrp,
      price: p.price,
      discount: p.discount,
      unit: p.unit,
      stock: p.stock,
      isAvailable: p.isAvailable,
      tags: p.tags,
      variants: p.variants,
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
