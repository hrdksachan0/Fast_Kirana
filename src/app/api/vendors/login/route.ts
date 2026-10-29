import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getLast10Digits } from '@/lib/phone'

export const dynamic = 'force-dynamic'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const rawPhone = (body.phone || body.username || '').toString().trim()
    const phoneDigits = getLast10Digits(rawPhone)

    if (!phoneDigits) {
      return NextResponse.json({ error: 'Valid 10-digit mobile number required' }, { status: 400 })
    }

    const vendor = await prisma.vendor.findFirst({
      where: {
        OR: [
          { phone: phoneDigits },
          { phone: `+91${phoneDigits}` },
          { phone: `91${phoneDigits}` },
        ],
        isActive: true,
      },
      select: {
        id: true,
        vendorCode: true,
        name: true,
        phone: true,
        email: true,
        companyName: true,
        storeId: true,
        isActive: true,
      },
    })

    if (!vendor) {
      return NextResponse.json(
        { error: 'No active supplier/vendor found linked to this mobile number' },
        { status: 404 }
      )
    }

    // Ensure user account role is set to VENDOR
    await prisma.user.updateMany({
      where: {
        OR: [
          { phone: `+91${phoneDigits}` },
          { phone: phoneDigits },
          { phone: `91${phoneDigits}` },
        ],
      },
      data: {
        role: 'VENDOR',
      },
    }).catch(() => {})

    return NextResponse.json({
      success: true,
      vendorId: vendor.id,
      vendor: {
        id: vendor.id,
        vendorCode: vendor.vendorCode || `VND-${vendor.id.slice(-4).toUpperCase()}`,
        name: vendor.name,
        phone: vendor.phone,
        email: vendor.email,
        companyName: vendor.companyName,
        storeId: vendor.storeId,
      },
    })
  } catch (error: any) {
    console.error('[VendorLogin] Error verifying vendor:', error)
    return NextResponse.json({ error: 'Failed to verify vendor account' }, { status: 500 })
  }
}
