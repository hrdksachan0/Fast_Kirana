import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized. Please sign in.' }, { status: 401 })
    }

    const sessionId = session.user.id
    const sessionEmail = session.user.email?.trim().toLowerCase()

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          ...(sessionId ? [{ id: sessionId }] : []),
          ...(sessionEmail ? [{ email: { equals: sessionEmail, mode: 'insensitive' as const } }] : []),
        ],
      },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        createdAt: true,
        updatedAt: true,
        addresses: {
          select: {
            id: true,
            label: true,
            houseNo: true,
            street: true,
            area: true,
            city: true,
            pincode: true,
            phone: true,
            isDefault: true,
          },
        },
        orders: {
          take: 100,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            readableId: true,
            status: true,
            paymentMethod: true,
            paymentStatus: true,
            subtotal: true,
            deliveryFee: true,
            discount: true,
            total: true,
            createdAt: true,
            items: {
              select: {
                id: true,
                name: true,
                quantity: true,
                price: true,
              },
            },
          },
        },
        customerWallet: {
          select: {
            balance: true,
            isActive: true,
            transactions: {
              take: 50,
              orderBy: { createdAt: 'desc' },
              select: {
                id: true,
                amount: true,
                type: true,
                status: true,
                description: true,
                createdAt: true,
              },
            },
          },
        },
      },
    })

    if (!user) {
      return NextResponse.json({ error: 'User account not found' }, { status: 404 })
    }

    const exportPayload = {
      exportMetadata: {
        platform: 'FastMinute Quick-Commerce (fastminute.in)',
        requestDate: new Date().toISOString(),
        regulationCompliance: 'Digital Personal Data Protection Act, 2023 (DPDP Act) & Consumer Protection Rules',
        accountReferenceId: user.id,
      },
      userProfile: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        memberSince: user.createdAt,
      },
      savedAddresses: user.addresses,
      orderHistory: user.orders,
      wallet: user.customerWallet || { balance: 0, transactions: [] },
    }

    const fileContent = JSON.stringify(exportPayload, null, 2)
    const filename = `fastminute-user-data-${user.id.slice(0, 8)}.json`

    return new NextResponse(fileContent, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Cache-Control': 'no-store, no-cache, must-revalidate',
      },
    })
  } catch (error: any) {
    console.error('[ExportData] Failed to export user data:', error)
    return NextResponse.json(
      { error: 'Failed to generate data export. Please try again or contact support.' },
      { status: 500 }
    )
  }
}
