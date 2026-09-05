import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

// GET - Retrieve all dark stores (Admin authenticated)
export async function GET() {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const stores = await prisma.darkStore.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        _count: {
          select: { staffMembers: true }
        },
        staffMembers: {
          where: { role: 'ADMIN' },
          select: { id: true, name: true, phone: true, email: true }
        }
      }
    })
    const formatted = stores.map(s => ({
      ...s,
      manager: s.staffMembers?.[0] || null
    }))
    return NextResponse.json(formatted)
  } catch (error: any) {
    console.error('Error fetching dark stores:', error)
    return NextResponse.json({ error: 'Failed to fetch dark stores' }, { status: 500 })
  }
}

// POST - Create a new dark store with polygon geofence (Admin authenticated)
export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { id, name, pincode, latitude, longitude, deliveryRadiusKm, deliveryPolygon, isActive, surgeCharge, groceryOpen, seedInventory, managerPhone } = body

    if (!name || latitude === undefined || longitude === undefined) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const cleanPincode = pincode ? pincode.toString().replace(/\D/g, '').slice(0, 6) : ''
    const storeId = id ? id.trim() : (cleanPincode.length === 6 ? `hub-${cleanPincode}` : `hub-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}`)

    const store = await prisma.darkStore.create({
      data: {
        id: storeId,
        name: name.trim(),
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        deliveryRadiusKm: deliveryRadiusKm !== undefined ? parseFloat(deliveryRadiusKm) : 5.0,
        deliveryPolygon: deliveryPolygon ? deliveryPolygon : null,
        isActive: isActive ?? true,
        surgeCharge: surgeCharge !== undefined ? parseFloat(surgeCharge) : 0.0,
        groceryOpen: groceryOpen ?? true
      }
    })

    // Assign Hub Manager / Admin Phone Number
    if (managerPhone && typeof managerPhone === 'string') {
      try {
        const cleanPhone = managerPhone.replace(/\D/g, '').slice(-10)
        if (cleanPhone.length === 10) {
          const formattedPhone = `+91${cleanPhone}`
          const existingUser = await prisma.user.findFirst({
            where: {
              OR: [
                { phone: formattedPhone },
                { phone: cleanPhone },
                { phone: { endsWith: cleanPhone } }
              ]
            }
          })
          if (existingUser) {
            await prisma.user.update({
              where: { id: existingUser.id },
              data: {
                role: 'ADMIN',
                assignedStoreId: store.id
              }
            })
          } else {
            await prisma.user.create({
              data: {
                phone: formattedPhone,
                name: `${name.trim()} Admin`,
                email: `admin.${store.id}@fastkirana.in`,
                role: 'ADMIN',
                assignedStoreId: store.id
              }
            })
          }
        }
      } catch (adminErr) {
        console.error('Hub Admin assignment error (non-fatal):', adminErr)
      }
    }

    // Auto-seed initial store inventory for grocery dark store
    if (seedInventory !== false) {
      try {
        const products = await prisma.product.findMany({
          where: { isAvailable: true },
          select: { id: true, stock: true }
        })
        if (products.length > 0) {
          await prisma.storeInventory.createMany({
            data: products.map(p => ({
              storeId: store.id,
              productId: p.id,
              stock: p.stock > 0 ? p.stock : 30
            })),
            skipDuplicates: true
          })
        }
      } catch (seedErr) {
        console.error('Inventory seed error (non-fatal):', seedErr)
      }
    }

    return NextResponse.json(store)
  } catch (error: any) {
    console.error('Error creating dark store:', error)
    return NextResponse.json({ error: error.message || 'Failed to create dark store' }, { status: 500 })
  }
}

// PATCH - Update dark store details/toggles (Admin authenticated)
export async function PATCH(request: NextRequest) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { id, name, latitude, longitude, deliveryPolygon, isActive, surgeCharge, groceryOpen, managerPhone } = body

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

    const updatedStore = await prisma.darkStore.update({
      where: { id },
      data: updateData
    })

    // Update / Reassign Hub Manager if phone provided
    if (managerPhone && typeof managerPhone === 'string') {
      try {
        const cleanPhone = managerPhone.replace(/\D/g, '').slice(-10)
        if (cleanPhone.length === 10) {
          const formattedPhone = `+91${cleanPhone}`
          const existingUser = await prisma.user.findFirst({
            where: {
              OR: [
                { phone: formattedPhone },
                { phone: cleanPhone },
                { phone: { endsWith: cleanPhone } }
              ]
            }
          })
          if (existingUser) {
            await prisma.user.update({
              where: { id: existingUser.id },
              data: {
                role: 'ADMIN',
                assignedStoreId: id
              }
            })
          } else {
            await prisma.user.create({
              data: {
                phone: formattedPhone,
                name: `${name || updatedStore.name} Admin`,
                email: `admin.${id}@fastkirana.in`,
                role: 'ADMIN',
                assignedStoreId: id
              }
            })
          }
        }
      } catch (adminErr) {
        console.error('Hub Admin re-assignment error (non-fatal):', adminErr)
      }
    }

    return NextResponse.json(updatedStore)
  } catch (error: any) {
    console.error('Error updating dark store:', error)
    return NextResponse.json({ error: error.message || 'Failed to update dark store' }, { status: 500 })
  }
}
