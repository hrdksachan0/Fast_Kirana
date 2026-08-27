import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'
import { prisma } from '@/lib/prisma'
import { createAddressSchema, updateAddressSchema, patchAddressSchema, deleteAddressSchema, validateBody, validateBodyLegacy } from '@/lib/validation'

async function resolveUserId(request: NextRequest | Request, session: any) {
  let userId = session?.user?.id || (request.headers as any).get?.('x-user-id')
  const headerPhone = (request.headers as any).get?.('x-user-phone')
  if (!userId && headerPhone) {
    const cleanPhone = headerPhone.replace('+91', '').replaceAll(' ', '').trim()
    let dbUser = await prisma.user.findFirst({
      where: {
        OR: [
          { phone: cleanPhone },
          { phone: `+91${cleanPhone}` },
          { phone: { contains: cleanPhone } },
        ]
      }
    })
    if (!dbUser && cleanPhone.length === 10) {
      dbUser = await prisma.user.create({
        data: {
          phone: `+91${cleanPhone}`,
          name: `Customer ${cleanPhone.slice(-4)}`,
          email: `customer_${cleanPhone}@fastkirana.in`,
          role: 'USER',
        }
      })
    }
    if (dbUser) userId = dbUser.id
  }
  return userId
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
        label: { notIn: ['STORE_PICKUP', 'STORE_PICKUP_RESTAURANT', 'STORE_PICKUP_CAFE'] }
      },
      orderBy: { isDefault: 'desc' },
    })
    return NextResponse.json(addresses)
  } catch (error) {
    console.error('Error in GET /api/addresses:', error)
    return NextResponse.json({ error: 'Failed to fetch addresses' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const session = await auth()
  const userId = await resolveUserId(request, session)
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, createAddressSchema)
  if (!validation.success) return validation.error

  const { label, houseNo, street, area, city, pincode, phone, isDefault, lat, lng } = validation.data

  try {
    let cleanPhone = getLast10Digits(phone.toString().trim())

    if (cleanPhone.length !== 10) {
      return NextResponse.json({ error: 'Mobile number must be a valid 10-digit number' }, { status: 400 })
    }

    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId },
        data: { isDefault: false },
      })
    }

    const address = await prisma.address.create({
      data: {
        userId,
        label,
        houseNo,
        street,
        area,
        city,
        pincode,
        phone: cleanPhone,
        isDefault: !!isDefault,
        lat: lat ? parseFloat(lat.toString()) : null,
        lng: lng ? parseFloat(lng.toString()) : null,
      },
    })

    return NextResponse.json(address)
  } catch (error) {
    console.error('Error in POST /api/addresses:', error)
    return NextResponse.json({ error: 'Failed to create address' }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, deleteAddressSchema)
  if (!validation.success) return validation.error

  const { id } = validation.data

  try {
    const address = await prisma.address.findUnique({ where: { id } })
    if (!address || address.userId !== session.user.id) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    const userAddressCount = await prisma.address.count({
      where: {
        userId: session.user.id,
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
  } catch (error) {
    console.error('Error in DELETE /api/addresses:', error)
    return NextResponse.json({ error: 'Failed to delete address' }, { status: 500 })
  }
}

export async function PUT(request: Request) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, updateAddressSchema)
  if (!validation.success) return validation.error

  const { id, label, houseNo, street, area, city, pincode, phone, isDefault, lat, lng } = validation.data

  try {
    const existing = await prisma.address.findUnique({ where: { id } })
    if (!existing || existing.userId !== session.user.id) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    let cleanPhone = getLast10Digits(phone.toString().trim())

    if (cleanPhone.length !== 10) {
      return NextResponse.json({ error: 'Mobile number must be a valid 10-digit number' }, { status: 400 })
    }

    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId: session.user.id },
        data: { isDefault: false },
      })
    }

    const updatedAddress = await prisma.address.update({
      where: { id },
      data: {
        label,
        houseNo,
        street,
        area,
        city,
        pincode,
        phone: cleanPhone,
        isDefault: !!isDefault,
        lat: lat ? parseFloat(lat.toString()) : null,
        lng: lng ? parseFloat(lng.toString()) : null,
      },
    })

    return NextResponse.json(updatedAddress)
  } catch (error) {
    console.error('Error in PUT /api/addresses:', error)
    return NextResponse.json({ error: 'Failed to update address' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const validation = await validateBodyLegacy(request, patchAddressSchema)
  if (!validation.success) return validation.error

  const { id, lat, lng } = validation.data

  try {
    const address = await prisma.address.findUnique({ where: { id } })
    if (!address || address.userId !== session.user.id) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    const updatedAddress = await prisma.address.update({
      where: { id },
      data: {
        lat: lat ? parseFloat(lat.toString()) : null,
        lng: lng ? parseFloat(lng.toString()) : null,
      },
    })

    return NextResponse.json(updatedAddress)
  } catch (error) {
    console.error('Error in PATCH /api/addresses:', error)
    return NextResponse.json({ error: 'Failed to update address' }, { status: 500 })
  }
}
