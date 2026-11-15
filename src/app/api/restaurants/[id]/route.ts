import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export const dynamic = 'force-dynamic'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [{ id }, { slug: id }]
      },
      include: {
        _count: {
          select: { products: true }
        }
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    return NextResponse.json({
      id: restaurant.id,
      name: restaurant.name,
      slug: restaurant.slug,
      description: restaurant.description,
      logoUrl: restaurant.logoUrl,
      bannerUrl: restaurant.bannerUrl,
      address: restaurant.address,
      city: restaurant.city,
      storeId: restaurant.storeId,
      cuisineTags: restaurant.cuisineTags,
      deliveryTime: restaurant.deliveryTime,
      distance: restaurant.distance,
      lat: restaurant.lat,
      lng: restaurant.lng,
      isVeg: restaurant.isVeg,
      isPureVeg: restaurant.isPureVeg,
      isOpen: restaurant.isOpen,
      isActive: restaurant.isActive,
      menuSections: restaurant.menuSections,
      rating: restaurant.rating,
      commissionRate: restaurant.commissionRate,
      ownerPhone: restaurant.ownerPhone,
      ownerEmail: restaurant.ownerEmail,
    })
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Failed to fetch restaurant' }, { status: 500 })
  }
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized: Please log in' }, { status: 401 })
    }

    const { id } = await params
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [{ id }, { slug: id }]
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    const userRole = (session.user.role || '').toUpperCase()
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN'
    const userAssignedRestId = (session.user as any)?.assignedRestaurantId || null

    if (!isAdmin) {
      const allowed = userAssignedRestId === restaurant.id || userAssignedRestId === restaurant.slug
      if (!allowed) {
        return NextResponse.json({ error: 'Unauthorized to edit this restaurant' }, { status: 403 })
      }
    }

    const body = await request.json()
    const updateData: any = {}

    if (body.menuSections !== undefined) {
      updateData.menuSections = body.menuSections
    }

    if (body.isOpen !== undefined) updateData.isOpen = !!body.isOpen
    if (body.isActive !== undefined && isAdmin) updateData.isActive = !!body.isActive
    if (body.name !== undefined) updateData.name = String(body.name).trim()
    if (body.description !== undefined) updateData.description = body.description ? String(body.description).trim() : null
    if (body.logoUrl !== undefined) updateData.logoUrl = body.logoUrl ? String(body.logoUrl).trim() : null
    if (body.bannerUrl !== undefined) updateData.bannerUrl = body.bannerUrl ? String(body.bannerUrl).trim() : null
    if (body.address !== undefined) updateData.address = body.address ? String(body.address).trim() : null
    if (body.city !== undefined) updateData.city = body.city ? String(body.city).trim() : null
    if (body.cuisineTags !== undefined && Array.isArray(body.cuisineTags)) updateData.cuisineTags = body.cuisineTags
    if (body.deliveryTime !== undefined) updateData.deliveryTime = body.deliveryTime
    if (body.distance !== undefined) updateData.distance = body.distance
    if (body.isVeg !== undefined) updateData.isVeg = !!body.isVeg
    if (body.isPureVeg !== undefined) updateData.isPureVeg = !!body.isPureVeg
    if (body.commissionRate !== undefined && isAdmin) updateData.commissionRate = parseFloat(String(body.commissionRate)) || 0.15
    if (body.ownerPhone !== undefined) updateData.ownerPhone = body.ownerPhone ? String(body.ownerPhone).trim() : null
    if (body.ownerEmail !== undefined) updateData.ownerEmail = body.ownerEmail ? String(body.ownerEmail).trim().toLowerCase() : null
    if (body.storeId !== undefined && isAdmin) updateData.storeId = body.storeId ? String(body.storeId).trim() : null

    const updated = await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: updateData
    })

    revalidateStorefront(updated.slug)

    return NextResponse.json({
      success: true,
      message: 'Restaurant updated successfully',
      restaurant: updated
    })
  } catch (err: any) {
    console.error('Error in PATCH /api/restaurants/[id]:', err)
    return NextResponse.json({ error: err.message || 'Failed to update restaurant' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await auth()
    const userRole = (session?.user?.role || '').toUpperCase()
    if (userRole !== 'ADMIN' && userRole !== 'SUPER_ADMIN') {
      return NextResponse.json({ error: 'Forbidden: Only administrators can delete restaurants' }, { status: 403 })
    }

    const { id } = await params
    const restaurant = await prisma.restaurant.findFirst({
      where: { OR: [{ id }, { slug: id }] }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    await prisma.restaurant.delete({
      where: { id: restaurant.id }
    })

    return NextResponse.json({ success: true, message: `Restaurant "${restaurant.name}" deleted` })
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Failed to delete restaurant' }, { status: 500 })
  }
}
