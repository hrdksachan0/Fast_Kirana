import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const session = await auth()
  const role = session?.user?.role

  if (role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized: Admin access required' }, { status: 403 })
  }

  try {
    const todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)

    // 1. Fetch all delivery riders
    const riders = await prisma.user.findMany({
      where: { role: 'DELIVERY' },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        image: true,
        riderWallet: true,
      },
      orderBy: { name: 'asc' }
    })

    // Ensure all riders have a RiderWallet record created
    const ridersWithWallets = await Promise.all(
      riders.map(async (r) => {
        let wallet = r.riderWallet
        if (!wallet) {
          wallet = await prisma.riderWallet.create({
            data: {
              userId: r.id,
              cashInHand: 0,
              cashLimit: 2000,
              totalCollected: 0,
              totalDeposited: 0,
            }
          })
        }

        // Today's delivered COD orders for this rider
        const todayCodOrders = await prisma.order.aggregate({
          where: {
            deliveryUserId: r.id,
            status: 'DELIVERED',
            paymentMethod: 'COD',
            deliveredAt: { gte: todayStart }
          },
          _sum: { total: true },
          _count: { id: true }
        })

        // Today's cash deposits for this rider
        const todayDeposits = await prisma.cashDepositTransaction.aggregate({
          where: {
            riderId: r.id,
            createdAt: { gte: todayStart }
          },
          _sum: { amount: true }
        })

        return {
          id: r.id,
          name: r.name || 'Unnamed Rider',
          email: r.email,
          phone: r.phone || 'N/A',
          image: r.image,
          cashInHand: wallet.cashInHand,
          cashLimit: wallet.cashLimit,
          totalCollected: wallet.totalCollected,
          totalDeposited: wallet.totalDeposited,
          todayCodOrdersCount: todayCodOrders._count.id || 0,
          todayCodTotal: todayCodOrders._sum.total || 0,
          todayDepositedTotal: todayDeposits._sum.amount || 0,
        }
      })
    )

    // 2. Global Finance Summary metrics for Today
    const todayDeliveredOrders = await prisma.order.findMany({
      where: {
        status: 'DELIVERED',
        deliveredAt: { gte: todayStart }
      },
      select: {
        id: true,
        total: true,
        paymentMethod: true,
        paymentStatus: true,
        deliveryUserId: true,
        cashSettledToAdmin: true
      }
    })

    let onlineRevenueToday = 0
    let counterCashToday = 0
    let deliveredCodToday = 0

    todayDeliveredOrders.forEach(o => {
      if (o.paymentMethod !== 'COD' && o.paymentStatus === 'PAID') {
        onlineRevenueToday += o.total
      } else if (o.paymentMethod === 'COD') {
        deliveredCodToday += o.total
        if (!o.deliveryUserId) {
          counterCashToday += o.total
        }
      }
    })

    const todayAllDeposits = await prisma.cashDepositTransaction.aggregate({
      where: { createdAt: { gte: todayStart } },
      _sum: { amount: true }
    })

    const totalCashDepositedToday = todayAllDeposits._sum.amount || 0
    const pendingRiderCash = ridersWithWallets.reduce((sum, r) => sum + Math.max(0, r.cashInHand), 0)

    // Recent deposit transactions
    const recentDeposits = await prisma.cashDepositTransaction.findMany({
      take: 20,
      orderBy: { createdAt: 'desc' },
      include: {
        rider: { select: { name: true, phone: true } },
        admin: { select: { name: true } }
      }
    })

    return NextResponse.json({
      riders: ridersWithWallets,
      summary: {
        onlineRevenueToday,
        deliveredCodToday,
        counterCashToday,
        totalCashDepositedToday,
        pendingRiderCash,
        activeRidersCount: ridersWithWallets.length
      },
      recentDeposits: recentDeposits.map(d => ({
        id: d.id,
        riderName: d.rider?.name || 'Rider',
        riderPhone: d.rider?.phone || '',
        adminName: d.admin?.name || 'Admin',
        amount: d.amount,
        notes: d.notes,
        createdAt: d.createdAt
      }))
    })

  } catch (err: any) {
    console.error('Error fetching admin rider cash:', err)
    return NextResponse.json({ error: err.message || 'Internal Server Error' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const session = await auth()
  if (session?.user?.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized: Admin access required' }, { status: 403 })
  }

  try {
    const { riderId, amount, notes } = await request.json()

    if (!riderId || typeof amount !== 'number' || amount <= 0) {
      return NextResponse.json({ error: 'Invalid riderId or amount' }, { status: 400 })
    }

    const rider = await prisma.user.findUnique({
      where: { id: riderId },
      include: { riderWallet: true }
    })

    if (!rider) {
      return NextResponse.json({ error: 'Rider not found' }, { status: 404 })
    }

    const adminId = session.user.id

    // Perform database transaction to ensure atomicity
    const depositTx = await prisma.$transaction(async (tx) => {
      // 1. Create deposit transaction log
      const txLog = await tx.cashDepositTransaction.create({
        data: {
          riderId,
          adminId,
          amount,
          notes: notes || 'Cash Handover to Admin',
          status: 'APPROVED'
        }
      })

      // 2. Update RiderWallet
      let wallet = rider.riderWallet
      if (!wallet) {
        wallet = await tx.riderWallet.create({
          data: { userId: riderId, cashInHand: 0, cashLimit: 2000, totalCollected: 0, totalDeposited: 0 }
        })
      }

      const updatedCashInHand = Math.max(0, wallet.cashInHand - amount)
      const updatedTotalDeposited = wallet.totalDeposited + amount

      await tx.riderWallet.update({
        where: { userId: riderId },
        data: {
          cashInHand: updatedCashInHand,
          totalDeposited: updatedTotalDeposited
        }
      })

      // 3. Mark un-settled COD orders for this rider as settled
      await tx.order.updateMany({
        where: {
          deliveryUserId: riderId,
          status: 'DELIVERED',
          paymentMethod: 'COD',
          cashSettledToAdmin: false
        },
        data: {
          cashSettledToAdmin: true,
          cashSettledAt: new Date()
        }
      })

      return txLog
    })

    return NextResponse.json({
      success: true,
      deposit: depositTx,
      message: `Successfully collected ₹${amount} cash from ${rider.name || 'Rider'}`
    })

  } catch (err: any) {
    console.error('Error settling rider cash:', err)
    return NextResponse.json({ error: err.message || 'Failed to settle cash' }, { status: 500 })
  }
}
