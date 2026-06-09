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
  
  const skip = (page - 1) * limit

  try {
    const where: any = {}

    if (categoryId && categoryId !== 'ALL') {
      where.categoryId = categoryId
    }

    if (lowStock) {
      where.stock = { lt: 15 }
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { slug: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { tags: { has: search } },
      ]
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
