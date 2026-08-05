import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { apiReadLimiter, apiWriteLimiter } from '@/lib/rate-limit'
import { revalidateStorefront } from '@/lib/revalidate'

export async function GET(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { searchParams } = new URL(request.url)
    const cuisine = searchParams.get('cuisine')
    const search = searchParams.get('search')
    const all = searchParams.get('all') === 'true'

    const where: Prisma.RestaurantWhereInput = {}

    let isAdmin = false
    if (all) {
      const session = await auth()
      isAdmin = session?.user?.role === 'ADMIN'
    }

    if (!isAdmin || !all) {
      where.isActive = true
    }

    if (cuisine) {
      where.cuisineTags = {
        has: cuisine
      }
    }

    if (search) {
      where.name = {
        contains: search,
        mode: 'insensitive'
      }
    }

    const restaurants = await prisma.restaurant.findMany({
      where,
      orderBy: [
        { sortOrder: 'desc' },
        { createdAt: 'desc' }
      ],
      include: {
        staff: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            role: true,
            assignedRestaurantId: true,
          }
        },
        _count: {
          select: { products: true }
        }
      }
    })

    return NextResponse.json(restaurants)
  } catch (error: any) {
    console.error('Restaurants API GET Error:', error)
    return NextResponse.json({ error: 'Failed to fetch restaurants' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { name, ownerUserId, ...rest } = body

    if (!name) {
      return NextResponse.json({ error: 'Missing required field: name' }, { status: 400 })
    }

    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim()

    // Check slug uniqueness
    const existing = await prisma.restaurant.findUnique({
      where: { slug }
    })

    let finalSlug = slug
    if (existing) {
      finalSlug = `${slug}-${Date.now().toString().slice(-4)}`
    }

    const restaurant = await prisma.restaurant.create({
      data: {
        name,
        slug: finalSlug,
        ...rest
      }
    })

    // Assign owner if ownerUserId provided
    if (ownerUserId) {
      await prisma.user.update({
        where: { id: ownerUserId },
        data: {
          assignedRestaurantId: restaurant.id,
          role: 'RESTAURANT_OWNER'
        }
      }).catch(err => console.error('Failed to assign owner user:', err))
    }

    revalidateStorefront('restaurants')

    return NextResponse.json(restaurant, { status: 201 })
  } catch (error: any) {
    console.error('Restaurants API POST Error:', error)
    return NextResponse.json({ error: 'Failed to create restaurant' }, { status: 500 })
  }
}
