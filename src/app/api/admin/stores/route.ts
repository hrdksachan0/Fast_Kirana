import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

// GET - Retrieve all dark stores (Admin authenticated)
export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
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
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const {
      id,
      name,
      pincode,
      latitude,
      longitude,
      deliveryRadiusKm,
      deliveryPolygon,
      isActive,
      surgeCharge,
      groceryOpen,
      seedInventory,
      managerPhone,
      address,
      contactAddress,
      pickupAddress,
      groceryPickupAddress,
      phone,
      storePhone,
      upiVpa,
      storeUpiVpa
    } = body

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

    // Automatically initialize isolated store-scoped settings for this new hub
    try {
      const cityName = name.replace(/\s+(Hub|Market|Central|Dark\s*Store|Branch).*$/i, '').trim()
      const resolvedAddress = (address || contactAddress || `${cityName}${cleanPincode ? `, ${cleanPincode}` : ''}`).trim()
      const resolvedPickup = (pickupAddress || groceryPickupAddress || `FastKirana Dark Store, ${cityName}${cleanPincode ? ` - ${cleanPincode}` : ''}`).trim()
      const resolvedPhone = (phone || storePhone || managerPhone || '+918112849854').trim()
      const resolvedUpi = (upiVpa || storeUpiVpa || '').trim()

      const initialSettings = [
        { key: `store:${store.id}:store_address`, value: resolvedAddress },
        { key: `store:${store.id}:contact_address`, value: resolvedAddress },
        { key: `store:${store.id}:grocery_pickup_address`, value: resolvedPickup },
        { key: `store:${store.id}:contact_phone`, value: resolvedPhone },
        { key: `store:${store.id}:store_phone`, value: resolvedPhone },
        { key: `store:${store.id}:store_pincode`, value: cleanPincode || (store.id.match(/\b\d{6}\b/)?.[0] || '') },
        { key: `store:${store.id}:store_lat`, value: String(store.latitude) },
        { key: `store:${store.id}:store_lng`, value: String(store.longitude) },
        { key: `store:${store.id}:delivery_radius`, value: String(store.deliveryRadiusKm || 5.0) },
        { key: `store:${store.id}:grocery_mart_open`, value: store.groceryOpen ? 'true' : 'false' },
        { key: `store:${store.id}:trusted_text`, value: `✨ Trusted by families in ${cityName}` },
        { key: `store:${store.id}:delivery_fee_tier1`, value: '25' },
        { key: `store:${store.id}:delivery_threshold_tier1`, value: '199' },
        { key: `store:${store.id}:delivery_fee_tier2`, value: '35' },
        { key: `store:${store.id}:delivery_threshold_tier2`, value: '299' },
        { key: `store:${store.id}:delivery_fee_tier3`, value: '50' },
        { key: `store:${store.id}:delivery_threshold_tier3`, value: '399' },
        ...(resolvedUpi ? [{ key: `store:${store.id}:store_upi_vpa`, value: resolvedUpi }] : []),
      ]

      await Promise.all(
        initialSettings.map(s =>
          prisma.storeSetting.upsert({
            where: { key: s.key },
            update: { value: s.value },
            create: { key: s.key, value: s.value },
          })
        )
      )
    } catch (settingErr) {
      console.error('Failed to initialize isolated settings for new store (non-fatal):', settingErr)
    }

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

    // Every new store hub starts clean with zero cross-hub inventory contamination.
    // Stock and products must be explicitly inwarded/added per hub via GRN.
    if (seedInventory === true) {
      console.log(`[StoreCreation] Store ${store.id} initialized clean with zero cross-hub dummy inventory.`)
    }

    return NextResponse.json(store)
  } catch (error: any) {
    console.error('Error creating dark store:', error)
    return NextResponse.json({ error: error.message || 'Failed to create dark store' }, { status: 500 })
  }
}

// PATCH - Update dark store details/toggles (Admin authenticated)
export async function PATCH(request: NextRequest) {
  const adminResult = await requireAdmin(request)
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
