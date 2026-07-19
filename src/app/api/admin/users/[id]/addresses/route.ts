import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const addresses = await prisma.address.findMany({
      where: { 
        userId: id,
        label: { notIn: ['STORE_PICKUP', 'STORE_PICKUP_RESTAURANT', 'STORE_PICKUP_CAFE'] }
      },
      orderBy: { isDefault: 'desc' }
    })
    return NextResponse.json(addresses)
  } catch (error) {
    console.error('Failed to fetch user addresses:', error)
    return NextResponse.json({ error: 'Failed to fetch addresses' }, { status: 500 })
  }
}

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const { label, houseNo, street, area, city, pincode, phone } = await request.json()

    if (!label || !houseNo || !street || !area || !city || !pincode || !phone) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const cleanPhone = phone.toString().trim().replace(/\D/g, '')

    const address = await prisma.address.create({
      data: {
        userId: id,
        label: label.trim(),
        houseNo: houseNo.trim(),
        street: street.trim(),
        area: area.trim(),
        city: city.trim(),
        pincode: pincode.trim(),
        phone: cleanPhone,
        isDefault: false,
      }
    })

    return NextResponse.json(address)
  } catch (error: any) {
    console.error('Failed to create user address by admin:', error)
    return NextResponse.json({ error: error.message || 'Failed to create address' }, { status: 500 })
  }
}
