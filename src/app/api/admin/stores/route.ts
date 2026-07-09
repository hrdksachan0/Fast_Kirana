import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

// GET - Retrieve all dark stores (Admin authenticated)
export async function GET() {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const stores = await prisma.darkStore.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        _count: {
          select: { staffMembers: true }
        }
      }
    })
    return NextResponse.json(stores)
  } catch (error: any) {
    console.error('Error fetching dark stores:', error)
    return NextResponse.json({ error: 'Failed to fetch dark stores' }, { status: 500 })
  }
}

// POST - Create a new dark store with polygon geofence (Admin authenticated)
export async function POST(request: NextRequest) {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { name, latitude, longitude, deliveryPolygon, isActive, surgeCharge, groceryOpen, cafeOpen } = body

    if (!name || latitude === undefined || longitude === undefined) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const store = await prisma.darkStore.create({
      data: {
        name,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        deliveryPolygon: deliveryPolygon ? deliveryPolygon : null,
        isActive: isActive ?? true,
        surgeCharge: surgeCharge !== undefined ? parseFloat(surgeCharge) : 0.0,
        groceryOpen: groceryOpen ?? true,
        cafeOpen: cafeOpen ?? true
      }
    })

    return NextResponse.json(store)
  } catch (error: any) {
    console.error('Error creating dark store:', error)
    return NextResponse.json({ error: error.message || 'Failed to create dark store' }, { status: 500 })
  }
}

// PATCH - Update dark store details/toggles (Admin authenticated)
export async function PATCH(request: NextRequest) {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { id, name, latitude, longitude, deliveryPolygon, isActive, surgeCharge, groceryOpen, cafeOpen } = body

    if (!id) {
      return NextResponse.json({ error: 'Store ID is required' }, { status: 400 })
    }

    const updateData: any = {}
    if (name !== undefined) updateData.name = name
    if (latitude !== undefined) updateData.latitude = parseFloat(latitude)
    if (longitude !== undefined) updateData.longitude = parseFloat(longitude)
    if (deliveryPolygon !== undefined) updateData.deliveryPolygon = deliveryPolygon
    if (isActive !== undefined) updateData.isActive = isActive
    if (surgeCharge !== undefined) updateData.surgeCharge = parseFloat(surgeCharge)
    if (groceryOpen !== undefined) updateData.groceryOpen = groceryOpen
    if (cafeOpen !== undefined) updateData.cafeOpen = cafeOpen

    const updatedStore = await prisma.darkStore.update({
      where: { id },
      data: updateData
    })

    return NextResponse.json(updatedStore)
  } catch (error: any) {
    console.error('Error updating dark store:', error)
    return NextResponse.json({ error: error.message || 'Failed to update dark store' }, { status: 500 })
  }
}
