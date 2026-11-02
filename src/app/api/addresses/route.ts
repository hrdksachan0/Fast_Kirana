import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'
import { prisma } from '@/lib/prisma'
import { ApiResponder } from '@/lib/api-response'
import { createAddressSchema, updateAddressSchema, patchAddressSchema, deleteAddressSchema, validateBody, validateBodyLegacy } from '@/lib/validation'

async function resolveUserId(request: NextRequest | Request, session: any): Promise<string | null> {
  let userId = session?.user?.id

  const internalSecret = process.env.INTERNAL_API_SECRET?.trim()
  const headerInternalSecret = (request.headers as any).get?.('x-internal-secret')?.trim()
  const isInternalService = Boolean(internalSecret && headerInternalSecret === internalSecret)

  if (!userId && isInternalService) {
    userId = (request.headers as any).get?.('x-user-id')
  }

  // Verify userId actually exists in the database
  if (userId) {
    const dbUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, isBlocked: true },
    })
    if (dbUser && !dbUser.isBlocked) return dbUser.id
    userId = null
  }

  // Fallback to session email lookup
  if (session?.user?.email) {
    const cleanEmail = session.user.email.trim().toLowerCase()
    const dbUser = await prisma.user.findFirst({
      where: { email: { equals: cleanEmail, mode: 'insensitive' } },
      select: { id: true, isBlocked: true },
    })
    if (dbUser && !dbUser.isBlocked) return dbUser.id
  }

  // Fallback to session phone lookup
  if (session?.user?.phone) {
    const cleanPhone = getLast10Digits(session.user.phone)
    if (cleanPhone) {
      const dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: cleanPhone },
            { phone: `+91${cleanPhone}` },
            { phone: { contains: cleanPhone } },
          ],
        },
        select: { id: true, isBlocked: true },
      })
      if (dbUser && !dbUser.isBlocked) return dbUser.id
    }
  }

  // Fallback to header x-user-phone ONLY for verified internal service callers
  if (isInternalService) {
    const headerPhone = (request.headers as any).get?.('x-user-phone')
    if (headerPhone) {
      const cleanPhone = getLast10Digits(headerPhone)
      let dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: cleanPhone },
            { phone: `+91${cleanPhone}` },
            { phone: { contains: cleanPhone } },
          ],
        },
        select: { id: true, isBlocked: true },
      })
      if (!dbUser && cleanPhone.length === 10) {
        dbUser = await prisma.user.create({
          data: {
            phone: `+91${cleanPhone}`,
            name: `Customer ${cleanPhone.slice(-4)}`,
            role: 'USER',
          },
          select: { id: true, isBlocked: true },
        })
      }
      if (dbUser && !dbUser.isBlocked) return dbUser.id
    }
  }

  return null
}

function resolveFallbackCoordinates(
  lat: any,
  lng: any,
  pincode: string,
  city: string,
  street?: string,
  area?: string
): { lat: number | null; lng: number | null } {
  const parsedLat = lat != null ? parseFloat(lat.toString()) : null
  const parsedLng = lng != null ? parseFloat(lng.toString()) : null

  if (parsedLat != null && !isNaN(parsedLat) && parsedLng != null && !isNaN(parsedLng) && (parsedLat !== 0 || parsedLng !== 0)) {
    return { lat: parsedLat, lng: parsedLng }
  }

  const pin = (pincode || '').toString().trim()
  const c = (city || '').toString().toLowerCase().trim()
  const s = (street || '').toString().toLowerCase().trim()
  const a = (area || '').toString().toLowerCase().trim()

  // Ghatampur Central Hub (209206)
  if (pin === '209206' || c.includes('ghatampur') || s.includes('ghatampur') || a.includes('ghatampur')) {
    return { lat: 26.1534185, lng: 80.1714024 }
  }

  // Akbarpur Central Hub (224122)
  if (pin === '224122' || c.includes('akbarpur') || s.includes('akbarpur')) {
    return { lat: 26.4289124, lng: 82.5399322 }
  }

  // Pakur Central Hub (816107)
  if (pin === '816107' || c.includes('pakur') || s.includes('pakur')) {
    return { lat: 24.857778, lng: 87.774167 }
  }

  return { lat: null, lng: null }
}

export async function GET(request: NextRequest) {
  const session = await auth()
  const userId = await resolveUserId(request, session)
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const addresses = await prisma.address.findMany({
      where: {
        userId,
        NOT: [
          { label: { startsWith: 'STORE_PICKUP' } },
        ],
      },
      orderBy: [{ isDefault: 'desc' }, { id: 'desc' }],
    })
    return NextResponse.json(addresses)
  } catch (error: any) {
    console.error('Error in GET /api/addresses:', error)
    return ApiResponder.error('Failed to fetch addresses', 500, 'INTERNAL_ERROR', error?.stack, request)
  }
}

export async function POST(request: NextRequest) {
  const session = await auth()
  const userId = await resolveUserId(request, session)
  if (!userId) {
    return NextResponse.json({ error: 'Please log in to save an address' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, createAddressSchema)
  if (!validation.success) return validation.error

  const { label, houseNo, street, area, city, pincode, phone, isDefault, lat, lng } = validation.data

  try {
    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId },
        data: { isDefault: false },
      })
    }

    const address = await prisma.address.create({
      data: {
        userId,
        label: label.trim(),
        houseNo: houseNo || '.',
        street: street.trim(),
        area: area || '.',
        city: city || 'Ghatampur',
        pincode: pincode.trim(),
        phone: phone.trim(),
        isDefault: !!isDefault,
        lat: resolveFallbackCoordinates(lat, lng, pincode, city, street, area).lat,
        lng: resolveFallbackCoordinates(lat, lng, pincode, city, street, area).lng,
      },
    })

    return NextResponse.json(address)
  } catch (error: any) {
    console.error('Error in POST /api/addresses:', error)
    return NextResponse.json({ error: error?.message || 'Failed to create address' }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  const session = await auth()
  const userId = await resolveUserId(request, session)
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, deleteAddressSchema)
  if (!validation.success) return validation.error

  const { id } = validation.data

  try {
    const address = await prisma.address.findUnique({ where: { id } })
    if (!address || address.userId !== userId) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    const userAddressCount = await prisma.address.count({
      where: {
        userId,
        label: { notIn: ['STORE_PICKUP', 'STORE_PICKUP_RESTAURANT', 'STORE_PICKUP_CAFE'] },
      },
    })
    if (userAddressCount <= 1) {
      return NextResponse.json(
        { error: 'You must keep at least one delivery address. Add a new address before deleting this one.' },
        { status: 400 }
      )
    }

    const linkedOrdersCount = await prisma.order.count({
      where: { addressId: id },
    })
    if (linkedOrdersCount > 0) {
      return NextResponse.json(
        { error: `This address is linked to ${linkedOrdersCount} order(s) and cannot be deleted.` },
        { status: 400 }
      )
    }

    await prisma.address.delete({ where: { id } })
    return NextResponse.json({ message: 'Address deleted successfully' })
  } catch (error: any) {
    console.error('Error in DELETE /api/addresses:', error)
    return NextResponse.json({ error: error?.message || 'Failed to delete address' }, { status: 500 })
  }
}

export async function PUT(request: Request) {
  const session = await auth()
  const userId = await resolveUserId(request, session)
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, updateAddressSchema)
  if (!validation.success) return validation.error

  const { id, label, houseNo, street, area, city, pincode, phone, isDefault, lat, lng } = validation.data

  try {
    const existing = await prisma.address.findUnique({ where: { id } })
    if (!existing || existing.userId !== userId) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId },
        data: { isDefault: false },
      })
    }

    const updatedAddress = await prisma.address.update({
      where: { id },
      data: {
        label: label.trim(),
        houseNo: houseNo || '.',
        street: street.trim(),
        area: area || '.',
        city: city || 'Ghatampur',
        pincode: pincode.trim(),
        phone: phone.trim(),
        isDefault: !!isDefault,
        lat: resolveFallbackCoordinates(lat, lng, pincode, city, street, area).lat,
        lng: resolveFallbackCoordinates(lat, lng, pincode, city, street, area).lng,
      },
    })

    return NextResponse.json(updatedAddress)
  } catch (error: any) {
    console.error('Error in PUT /api/addresses:', error)
    return NextResponse.json({ error: error?.message || 'Failed to update address' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const session = await auth()
  const userId = await resolveUserId(request, session)
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, patchAddressSchema)
  if (!validation.success) return validation.error

  const { id, lat, lng } = validation.data

  try {
    const address = await prisma.address.findUnique({ where: { id } })
    if (!address || address.userId !== userId) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    const updatedAddress = await prisma.address.update({
      where: { id },
      data: {
        lat: resolveFallbackCoordinates(lat, lng, address.pincode, address.city, address.street, address.area).lat,
        lng: resolveFallbackCoordinates(lat, lng, address.pincode, address.city, address.street, address.area).lng,
      },
    })

    return NextResponse.json(updatedAddress)
  } catch (error: any) {
    console.error('Error in PATCH /api/addresses:', error)
    return NextResponse.json({ error: error?.message || 'Failed to update address' }, { status: 500 })
  }
}
