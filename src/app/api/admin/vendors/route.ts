import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  const { searchParams } = new URL(request.url)
  const format = searchParams.get('format') // 'names' for legacy string array
  const storeId = searchParams.get('storeId')

  const vendorWhere: any = {}
  if (storeId && storeId !== 'all') {
    vendorWhere.OR = [
      { storeId },
      { storeId: null },
    ]
  }

  try {
    const [vendors, legacyProducts] = await Promise.all([
      (prisma as any).vendor.findMany({
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
      }),
      prisma.product.findMany({
        where: { vendor: { not: null } },
        distinct: ['vendor'],
        select: { vendor: true },
      }),
    ])

    const vendorNamesSet = new Set<string>()
    vendors.forEach((v: any) => {
      if (v.name?.trim()) vendorNamesSet.add(v.name.trim())
    })
    legacyProducts.forEach((p) => {
      if (p.vendor?.trim()) vendorNamesSet.add(p.vendor.trim())
    })

    const vendorNames = Array.from(vendorNamesSet).sort()

    // If caller specifically wants strings (legacy compatibility)
    if (format === 'names') {
      return NextResponse.json({ vendors: vendorNames })
    }

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
      vendorNames,
    })
  } catch (error: any) {
    console.error('Error fetching vendors:', error)
    return NextResponse.json({ success: false, error: error.message, vendors: [], vendorNames: [] }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const {
      id,
      name,
      phone,
      email,
      companyName,
      gstin,
      upiId,
      bankName,
      accountNo,
      ifscCode,
      address,
      isActive = true,
      storeId,
    } = body

    if (!name || !name.trim()) {
      return NextResponse.json({ error: 'Vendor name is required' }, { status: 400 })
    }

    const cleanName = name.trim()
    const cleanPhone = phone?.trim() || null
    const cleanUpi = upiId?.trim() || null

    if (id) {
      // Update existing vendor
      const updated = await (prisma as any).vendor.update({
        where: { id },
        data: {
          name: cleanName,
          phone: cleanPhone,
          email: email?.trim() || null,
          companyName: companyName?.trim() || null,
          gstin: gstin?.trim() || null,
          upiId: cleanUpi,
          bankName: bankName?.trim() || null,
          accountNo: accountNo?.trim() || null,
          ifscCode: ifscCode?.trim() || null,
          address: address?.trim() || null,
          isActive: Boolean(isActive),
          storeId: storeId || null,
        },
      })

      // Sync name in linked products for backward compatibility
      await prisma.product.updateMany({
        where: { vendorId: id },
        data: { vendor: cleanName },
      })

      return NextResponse.json({ success: true, vendor: updated })
    } else {
      // Check if vendor with same name already exists
      const existing = await (prisma as any).vendor.findFirst({
        where: { name: { equals: cleanName, mode: 'insensitive' } },
      })

      if (existing) {
        return NextResponse.json(
          { error: `Vendor "${cleanName}" already exists with ID: ${existing.id}` },
          { status: 409 }
        )
      }

      // Generate unique short Vendor Code (e.g. VND-001, VND-002)
      const existingWithCodes = await (prisma as any).vendor.findMany({
        where: { vendorCode: { not: null } },
        select: { vendorCode: true }
      })
      let maxNum = 0
      for (const item of existingWithCodes) {
        if (item.vendorCode && item.vendorCode.startsWith('VND-')) {
          const parsed = parseInt(item.vendorCode.replace('VND-', ''), 10)
          if (!isNaN(parsed) && parsed > maxNum) {
            maxNum = parsed
          }
        }
      }
      const vendorCode = `VND-${String(maxNum + 1).padStart(3, '0')}`

      const created = await (prisma as any).vendor.create({
        data: {
          vendorCode,
          name: cleanName,
          phone: cleanPhone,
          email: email?.trim() || null,
          companyName: companyName?.trim() || null,
          gstin: gstin?.trim() || null,
          upiId: cleanUpi,
          bankName: bankName?.trim() || null,
          accountNo: accountNo?.trim() || null,
          ifscCode: ifscCode?.trim() || null,
          address: address?.trim() || null,
          isActive: Boolean(isActive),
          storeId: storeId || null,
        },
      })

      // Link any legacy products that had this vendor name as a plain string
      await prisma.product.updateMany({
        where: {
          vendor: { equals: cleanName, mode: 'insensitive' },
          vendorId: null,
        },
        data: {
          vendorId: created.id,
          vendor: cleanName,
        },
      })

      return NextResponse.json({ success: true, vendor: created }, { status: 201 })
    }
  } catch (error: any) {
    console.error('Error saving vendor:', error)
    return NextResponse.json({ error: error.message || 'Failed to save vendor' }, { status: 500 })
  }
}
