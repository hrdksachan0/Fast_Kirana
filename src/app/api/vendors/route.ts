import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const storeId = searchParams.get('storeId')
    const phone = searchParams.get('phone')

    const vendorWhere: any = { isActive: true }
    if (storeId && storeId !== 'all') {
      vendorWhere.OR = [
        { storeId },
        { storeId: null },
      ]
    }
    if (phone) {
      const cleanPhone = phone.replace(/\D/g, '').slice(-10)
      vendorWhere.OR = [
        { phone: cleanPhone },
        { phone: `+91${cleanPhone}` },
        { phone: `91${cleanPhone}` },
      ]
    }

    const vendors = await (prisma as any).vendor.findMany({
      where: vendorWhere,
      orderBy: { name: 'asc' },
      include: {
        _count: {
          select: {
            products: true,
            payouts: true,
          },
        },
      },
    })

    const formattedVendors = vendors.map((v: any) => ({
      id: v.id,
      vendorCode: v.vendorCode || `VND-${v.id.slice(-4).toUpperCase()}`,
      name: v.name,
      phone: v.phone || '',
      email: v.email || '',
      companyName: v.companyName || '',
      gstin: v.gstin || '',
      upiId: v.upiId || '',
      bankName: v.bankName || '',
      accountNo: v.accountNo || '',
      ifscCode: v.ifscCode || '',
      address: v.address || '',
      isActive: v.isActive,
      storeId: v.storeId || null,
      productCount: v._count?.products || 0,
      payoutCount: v._count?.payouts || 0,
      createdAt: v.createdAt,
      updatedAt: v.updatedAt,
    }))

    return NextResponse.json({
      success: true,
      vendors: formattedVendors,
    })
  } catch (error: any) {
    console.error('[VendorsAPI] Error fetching vendors:', error)
    return NextResponse.json({ success: false, error: error.message, vendors: [] }, { status: 500 })
  }
}
