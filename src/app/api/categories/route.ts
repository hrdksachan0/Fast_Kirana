import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET() {
  try {
    const categories = await prisma.category.findMany({
      where: {
        slug: { notIn: ['cafe', 'restaurant'] },
      },
      orderBy: {
        sortOrder: 'asc',
      },
      include: {
        _count: {
          select: { products: true },
        },
      },
    })
    return NextResponse.json(categories, {
      headers: {
        'Cache-Control': 'public, s-maxage=120, stale-while-revalidate=300',
      }
    })
  } catch (error: any) {
    return NextResponse.json({ error: 'Failed to fetch categories' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { name, imageUrl, sortOrder } = body

    if (!name) {
      return NextResponse.json({ error: 'Name is required' }, { status: 400 })
    }

    // Generate slug from name
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')

    const existing = await prisma.category.findUnique({
      where: { slug }
    })

    let finalSlug = slug
    if (existing) {
      finalSlug = `${slug}-${Date.now().toString().slice(-4)}`
    }

    const category = await prisma.category.create({
      data: {
        name,
        slug: finalSlug,
        imageUrl: imageUrl || '📦',
        sortOrder: sortOrder !== undefined ? parseInt(sortOrder) : 0,
        parentId: body.parentId || null,
      }
    })

    return NextResponse.json(category, { status: 201 })
  } catch (error: any) {
    console.error('Failed to create category:', error)
    return NextResponse.json({ error: 'Failed to create category' }, { status: 500 })
  }
}
