import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const userId = session.user.id
  const role = session.user.role

  if (role !== 'DELIVERY' && role !== 'ADMIN') {
    return NextResponse.json({ error: 'Forbidden: Delivery role required' }, { status: 403 })
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
          cashLimit: 2000,
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

    return NextResponse.json({
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
      recentDeposits: recentDeposits.map(d => ({
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
