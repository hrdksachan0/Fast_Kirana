import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { revalidateTag } from 'next/cache'
import { revalidateStorefront } from '@/lib/revalidate'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const includeAll = searchParams.get('admin') === 'true' || searchParams.get('all') === 'true'

    const categories = await prisma.category.findMany({
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
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

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

    // Auto-generate clean series ID (Blinkit style: CAT-1xx for Ghatampur, CAT-2xx for Hamirpur)
    let categoryId = body.id?.trim()
    if (!categoryId) {
      const isHamirpur = body.city?.toLowerCase().includes('hamirpur') || body.hubId?.includes('210301')
      const prefix = isHamirpur ? 'CAT-2' : 'CAT-1'
      const startNum = isHamirpur ? 201 : 101

      if (body.parentId) {
        // Subcategory ID format: SUB-<cleanParentId>-01
        const cleanParent = body.parentId.replace(/^CAT-/, '')
        const existingSubs = await prisma.category.findMany({
          where: { parentId: body.parentId, id: { startsWith: `SUB-${cleanParent}-` } },
          select: { id: true },
        })
        const nextSubNum = existingSubs.length + 1
        categoryId = `SUB-${cleanParent}-${String(nextSubNum).padStart(2, '0')}`
      } else {
        const existingCats = await prisma.category.findMany({
          where: { id: { startsWith: prefix } },
          select: { id: true },
        })
        let maxNum = startNum - 1
        for (const c of existingCats) {
          const num = parseInt(c.id.replace('CAT-', ''), 10)
          if (!isNaN(num) && num > maxNum) {
            maxNum = num
          }
        }
        categoryId = `CAT-${maxNum + 1}`
      }
    }

    const category = await prisma.category.create({
      data: {
        id: categoryId,
        name,
        slug: finalSlug,
        imageUrl: imageUrl || '📦',
        sortOrder: sortOrder !== undefined ? parseInt(sortOrder) : 0,
        parentId: body.parentId || null,
      }
    })

    // Revalidate category lists cache immediately
    try {
      revalidateTag('categories', 'max')
      revalidateStorefront()
    } catch (e) {
      console.error('Failed to trigger category revalidation:', e)
    }

    return NextResponse.json(category, { status: 201 })
  } catch (error: any) {
    console.error('Failed to create category:', error)
    return NextResponse.json({ error: 'Failed to create category' }, { status: 500 })
  }
}
