import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const session = await auth()
  const searchParams = request.nextUrl.searchParams
  const queryUserId = searchParams.get('userId')
  const queryPhone = searchParams.get('phone')

  let userId = session?.user?.id || queryUserId || null

  if (!userId && queryPhone) {
    const cleanPhone = queryPhone.replace(/\D/g, '').slice(-10)
    const riderUser = await prisma.user.findFirst({
      where: { phone: { contains: cleanPhone } },
      select: { id: true }
    })
    if (riderUser) userId = riderUser.id
  }

  if (!userId) {
    // Return empty wallet stats instead of error for unlinked sessions
    return NextResponse.json({
      wallet: {
        cashInHand: 0,
        cashLimit: 10000,
        totalCollected: 0,
        totalDeposited: 0,
        isLocked: false,
        isWarning: false,
        remainingLimit: 10000
      },
      todayCodOrders: [],
      recentDeposits: []
    })
  }

  try {
    const todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)

    // Ensure wallet exists
    let wallet = await prisma.riderWallet.findUnique({
      where: { userId }
    })

    if (!wallet) {
      wallet = await prisma.riderWallet.create({
        data: {
          userId,
          cashInHand: 0,
          cashLimit: 10000,
          totalCollected: 0,
          totalDeposited: 0
        }
      })
    }

    // Fetch today's COD delivered orders
    const todayCodOrders = await prisma.order.findMany({
      where: {
        deliveryUserId: userId,
        status: 'DELIVERED',
        paymentMethod: 'COD',
        deliveredAt: { gte: todayStart }
      },
      select: {
        id: true,
        readableId: true,
        total: true,
        deliveredAt: true,
        cashSettledToAdmin: true,
        shopName: true
      },
      orderBy: { deliveredAt: 'desc' }
    })

    // Fetch recent deposits made by rider
    const recentDeposits = await prisma.cashDepositTransaction.findMany({
      where: { riderId: userId },
      take: 10,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        amount: true,
        notes: true,
        createdAt: true,
        admin: { select: { name: true } }
      }
    })

    const isLocked = wallet.cashInHand >= wallet.cashLimit
    const isWarning = wallet.cashInHand >= wallet.cashLimit * 0.75

    const riderUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, phone: true, role: true }
    })

    return NextResponse.json({
      rider: {
        id: riderUser?.id || userId,
        name: riderUser?.name || 'Partner',
        phone: riderUser?.phone || ''
      },
      wallet: {
        cashInHand: wallet.cashInHand,
        cashLimit: wallet.cashLimit,
        totalCollected: wallet.totalCollected,
        totalDeposited: wallet.totalDeposited,
        isLocked,
        isWarning,
        remainingLimit: Math.max(0, wallet.cashLimit - wallet.cashInHand)
      },
      todayCodOrders,
      recentDeposits: recentDeposits.map((d: any) => ({
        id: d.id,
        amount: d.amount,
        adminName: d.admin?.name || 'Admin',
        notes: d.notes,
        createdAt: d.createdAt
      }))
    })

  } catch (err: any) {
    console.error('Error fetching rider wallet:', err)
    return NextResponse.json({ error: err.message || 'Server error' }, { status: 500 })
  }
}
