import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
      include: {
        staff: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            role: true,
          }
        },
        _count: {
          select: {
            products: true,
            orders: true
          }
        }
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    return NextResponse.json(restaurant)
  } catch (error: any) {
    console.error('Restaurant API GET Error:', error)
    return NextResponse.json({ error: 'Failed to fetch restaurant' }, { status: 500 })
  }
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  const role = session?.user?.role
  const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId

  try {
    const { id } = await params
    const body = await request.json()
    const { ownerUserId, ...updateFields } = body

    // Find the restaurant first
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    // Allow access if ADMIN, or if OWNER/CHEF assigned to this specific restaurant
    const isAuthorized = role === 'ADMIN' || 
      ((role === 'RESTAURANT_OWNER' || role === 'CHEF') && assignedRestaurantId === restaurant.id)

    if (!session || !isAuthorized) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })
    }

    let finalSlug = restaurant.slug
    if (updateFields.name && updateFields.name !== restaurant.name) {
      const slug = updateFields.name
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .replace(/-+/g, '-')
        .trim()

      const existing = await prisma.restaurant.findUnique({
        where: { slug }
      })

      if (existing && existing.id !== restaurant.id) {
        finalSlug = `${slug}-${Date.now().toString().slice(-4)}`
      } else {
        finalSlug = slug
      }
    }

    const allowedKeys = [
      'name', 'description', 'logoUrl', 'bannerUrl', 'address', 'city',
      'cuisineTags', 'deliveryTime', 'distance', 'lat', 'lng', 'isVeg',
      'isPureVeg', 'isOpen', 'openTime', 'closeTime', 'sortOrder',
      'discountOffer', 'discountBadge', 'commissionRate', 'ownerPhone',
      'ownerEmail', 'isActive', 'rating'
    ]

    const updateData: any = {}
    for (const key of allowedKeys) {
      if (updateFields[key] !== undefined) {
        updateData[key] = updateFields[key]
      }
    }
    updateData.slug = finalSlug

    const updatedRestaurant = await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: updateData
    })

    // Update owner assignment if requested by ADMIN
    if (ownerUserId && role === 'ADMIN') {
      await prisma.user.update({
        where: { id: ownerUserId },
        data: {
          assignedRestaurantId: restaurant.id,
          role: 'RESTAURANT_OWNER'
        }
      }).catch(err => console.error('Failed to update owner user assignment:', err))
    }

    revalidateStorefront('restaurants')

    return NextResponse.json(updatedRestaurant)
  } catch (error: any) {
    console.error('Failed to update restaurant:', error)
    return NextResponse.json({ error: 'Failed to update restaurant' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })
  }

  try {
    const { id } = await params

    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    // Soft-delete
    await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: { isActive: false },
    })

    revalidateStorefront('restaurants')

    return NextResponse.json({ message: 'Restaurant successfully deactivated' })
  } catch (error: any) {
    console.error('Failed to delete restaurant:', error)
    return NextResponse.json({ error: 'Failed to delete restaurant' }, { status: 500 })
  }
}
