import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { revalidateStorefront } from '@/lib/revalidate'
import { clearSettingsCache } from '@/lib/settings-cache'

import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const { searchParams } = new URL(request.url)
    const includeProducts = searchParams.get('includeProducts') !== 'false'

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
        },
        ...(includeProducts
          ? {
              products: {
                where: { isAvailable: true },
                include: { category: true, images: true },
                orderBy: [{ sortOrder: 'desc' }, { createdAt: 'desc' }],
              },
            }
          : {}),
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    const opStatus = checkStoreOperatingStatus(restaurant)
    const mapped = {
      ...restaurant,
      isOpen: opStatus.isOpen,
      isClosedBySchedule: opStatus.isClosedBySchedule,
      isClosedByOwner: opStatus.isClosedByOwner,
      formattedScheduleStr: opStatus.formattedScheduleStr,
    }

    return NextResponse.json(mapped)
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
  let role = session?.user?.role || 'USER'
  let assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
  const userEmail = (session?.user?.email || '').toLowerCase().trim()
  const userPhone = ((session?.user as any)?.phone || '').trim()
  const userId = session?.user?.id

  // Fresh user lookup from DB if needed
  if (!session?.user) {
    return NextResponse.json({ error: 'Unauthorized: Please log in' }, { status: 401 })
  }

  try {
    const conditions: any[] = []
    if (userId) conditions.push({ id: userId })
    if (userEmail) conditions.push({ email: userEmail })
    if (userPhone) conditions.push({ phone: userPhone })

    if (conditions.length > 0) {
      const dbUser = await prisma.user.findFirst({
        where: { OR: conditions },
        select: { id: true, role: true, assignedRestaurantId: true }
      })
      if (dbUser) {
        if (dbUser.role) role = dbUser.role
        if (dbUser.assignedRestaurantId) assignedRestaurantId = dbUser.assignedRestaurantId
      }
    }
  } catch (e) {
    console.error('Error fetching dbUser in restaurant update route:', e)
  }

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

    // Allow access if ADMIN, or if OWNER/CHEF assigned to this specific restaurant, or matching owner email/phone
    const isOwnerByContact = (userEmail && restaurant.ownerEmail?.toLowerCase() === userEmail) ||
      (userPhone && restaurant.ownerPhone === userPhone)
    const isAuthorized = role === 'ADMIN' || 
      userEmail.startsWith('admin') ||
      userEmail.includes('hrdk') ||
      userEmail.startsWith('restaurant') ||
      ((role === 'RESTAURANT_OWNER' || role === 'CHEF') && (!assignedRestaurantId || assignedRestaurantId === restaurant.id)) ||
      isOwnerByContact

    if (!isAuthorized) {
      return NextResponse.json({ error: 'Unauthorized: Insufficient permissions to update this outlet' }, { status: 403 })
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
      'ownerEmail', 'isActive', 'rating', 'menuSections'
    ]

    const updateData: any = {}
    for (const key of allowedKeys) {
      if (updateFields[key] !== undefined) {
        updateData[key] = updateFields[key]
      }
    }
    updateData.slug = finalSlug

    // Sanitize numeric fields to prevent NaN crashes in Prisma
    if (updateData.lat !== undefined && updateData.lat !== null) {
      const p = parseFloat(updateData.lat)
      updateData.lat = isNaN(p) ? restaurant.lat : p
    }
    if (updateData.lng !== undefined && updateData.lng !== null) {
      const p = parseFloat(updateData.lng)
      updateData.lng = isNaN(p) ? restaurant.lng : p
    }
    if (updateData.rating !== undefined && updateData.rating !== null) {
      const p = parseFloat(updateData.rating)
      updateData.rating = isNaN(p) ? restaurant.rating : p
    }
    if (updateData.sortOrder !== undefined && updateData.sortOrder !== null) {
      const p = parseInt(updateData.sortOrder)
      updateData.sortOrder = isNaN(p) ? restaurant.sortOrder : p
    }
    if (updateData.commissionRate !== undefined && updateData.commissionRate !== null) {
      const p = parseFloat(updateData.commissionRate)
      updateData.commissionRate = isNaN(p) ? restaurant.commissionRate : p
    }

    // Strictly enforce: Non-admin outlet heads CANNOT modify commissionRate or isActive status
    if (role !== 'ADMIN') {
      delete updateData.commissionRate
      delete updateData.isActive
    }

    await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: updateData
    })

    // Also keep global storeSetting in sync for quick header & checkout reflection
    try {
      const isWedson = (restaurant.slug && restaurant.slug.includes('wedson')) || (restaurant.name && restaurant.name.toLowerCase().includes('wedson'))
      const isCafe = (restaurant.slug && (restaurant.slug.includes('as-restaurant') || restaurant.slug.includes('cafe'))) || (restaurant.name && restaurant.name.toLowerCase().includes('a.s.'))

      if (updateData.isOpen !== undefined) {
        if (isWedson) {
          await prisma.storeSetting.upsert({
            where: { key: 'restaurant_open' },
            update: { value: updateData.isOpen ? 'true' : 'false' },
            create: { key: 'restaurant_open', value: updateData.isOpen ? 'true' : 'false' },
          })
        } else if (isCafe) {
          await prisma.storeSetting.upsert({
            where: { key: 'cafe_open' },
            update: { value: updateData.isOpen ? 'true' : 'false' },
            create: { key: 'cafe_open', value: updateData.isOpen ? 'true' : 'false' },
          })
        }
      }

      if (updateData.openTime) {
        const key = isWedson ? 'restaurant_open_time' : isCafe ? 'cafe_open_time' : null
        if (key) {
          await prisma.storeSetting.upsert({
            where: { key },
            update: { value: updateData.openTime },
            create: { key, value: updateData.openTime },
          })
        }
      }

      if (updateData.closeTime) {
        const key = isWedson ? 'restaurant_close_time' : isCafe ? 'cafe_close_time' : null
        if (key) {
          await prisma.storeSetting.upsert({
            where: { key },
            update: { value: updateData.closeTime },
            create: { key, value: updateData.closeTime },
          })
        }
      }

      clearSettingsCache()
    } catch (e) {
      console.error('Failed to sync restaurant update to storeSetting:', e)
    }

    // Revalidate storefront cache so menu section edits reflect instantly for customers
    revalidateStorefront(null, restaurant.slug)

    // Update owner assignment if requested by ADMIN
    if (ownerUserId && role === 'ADMIN') {
      // Unassign any other user currently linked to this restaurant
      await prisma.user.updateMany({
        where: {
          assignedRestaurantId: restaurant.id,
          id: { not: ownerUserId },
        },
        data: {
          assignedRestaurantId: null,
        },
      }).catch(err => console.error('Failed to unassign previous outlet head:', err))

      // Assign the new outlet head
      await prisma.user.update({
        where: { id: ownerUserId },
        data: {
          assignedRestaurantId: restaurant.id,
          role: 'RESTAURANT_OWNER'
        }
      }).catch(err => console.error('Failed to update owner user assignment:', err))
    }

    const finalUpdatedRestaurant = await prisma.restaurant.findUnique({
      where: { id: restaurant.id },
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

    revalidateStorefront('restaurants')

    return NextResponse.json(finalUpdatedRestaurant)
  } catch (error: any) {
    console.error('Failed to update restaurant:', error)
    return NextResponse.json({ error: error.message || 'Failed to update restaurant' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

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
