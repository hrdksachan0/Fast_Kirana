import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const addresses = await prisma.address.findMany({
      where: { userId: session.user.id },
      orderBy: { isDefault: 'desc' },
    })
    return NextResponse.json(addresses)
  } catch (error) {
    return NextResponse.json({ error: 'Failed to fetch addresses' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { label, houseNo, street, area, city, pincode, phone, isDefault } = await request.json()

    if (!label || !houseNo || !street || !area || !city || !pincode || !phone) {
      return NextResponse.json({ error: 'Missing required fields (including phone number)' }, { status: 400 })
    }

    // If setting default, reset existing defaults
    if (isDefault) {
      await prisma.address.updateMany({
        where: { userId: session.user.id },
        data: { isDefault: false },
      })
    }

    const address = await prisma.address.create({
      data: {
        userId: session.user.id,
        label,
        houseNo,
        street,
        area,
        city,
        pincode,
        phone,
        isDefault: !!isDefault,
      },
    })

    return NextResponse.json(address)
  } catch (error) {
    return NextResponse.json({ error: 'Failed to create address' }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await request.json()
    if (!id) {
      return NextResponse.json({ error: 'Address ID is required' }, { status: 400 })
    }

    const address = await prisma.address.findUnique({ where: { id } })
    if (!address || address.userId !== session.user.id) {
      return NextResponse.json({ error: 'Address not found or unauthorized' }, { status: 404 })
    }

    await prisma.address.delete({ where: { id } })
    return NextResponse.json({ message: 'Address deleted successfully' })
  } catch (error) {
    return NextResponse.json({ error: 'Failed to delete address' }, { status: 500 })
  }
}
