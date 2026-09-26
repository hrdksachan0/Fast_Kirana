import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { Role } from '@prisma/client'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  try {
    const session = await auth()
    if (!session || !session.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = (session.user.role || '').toUpperCase()
    if (role !== 'ADMIN' && role !== 'SUPER_ADMIN') {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { searchParams } = new URL(req.url)
    const dateStr = searchParams.get('date') // YYYY-MM-DD
    const storeId = searchParams.get('storeId')

    // Time calculation for IST (UTC + 5:30)
    const now = new Date()
    // Current IST date string
    const istOffset = 5.5 * 60 * 60 * 1000
    const currentIst = new Date(now.getTime() + istOffset)
    const targetDateStr = dateStr || currentIst.toISOString().slice(0, 10)

    // Construct start and end in UTC for the target IST date
    const [y, m, d] = targetDateStr.split('-').map(Number)
    const istStart = new Date(Date.UTC(y, m - 1, d, 0, 0, 0) - istOffset)
    const istEnd = new Date(Date.UTC(y, m - 1, d, 23, 59, 59, 999) - istOffset)

    // Base query
    const whereClause: any = {
      createdAt: {
        gte: istStart,
        lte: istEnd,
      },
    }

    if (storeId && storeId.toLowerCase() !== 'all') {
      whereClause.storeId = storeId
    }

    const orders = await prisma.order.findMany({
      where: whereClause,
      include: {
        user: { select: { id: true, name: true, phone: true } },
        deliveryUser: { select: { id: true, name: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    })

    let cashfreeOnlineTotal = 0
    let cashfreeOnlineCount = 0
    let riderQrTotal = 0
    let riderQrCount = 0
    let counterCashTotal = 0
    let counterCashCount = 0
    let riderCashTotal = 0
    let riderCashCount = 0
    let pendingCodTotal = 0
    let pendingCodCount = 0
    let pendingOnlineTotal = 0
    let pendingOnlineCount = 0

    const transactions = orders.map((o: any) => {
      const tot = Number(o.total || 0)
      const pStatus = String(o.paymentStatus || 'PENDING').toUpperCase()
      const pMethod = String(o.paymentMethod || 'COD').toUpperCase()
      const oStatus = String(o.status || 'PENDING').toUpperCase()
      const notes = String(o.notes || '')
      const isDoorstepQr = notes.includes('Doorstep UPI') || notes.includes('QR Scan') || notes.includes('Rider QR')

      let category = 'PENDING_DELIVERY'
      let verifiedBy = 'Pending'

      if (oStatus === 'CANCELLED') {
        category = 'CANCELLED'
        verifiedBy = 'Order Cancelled'
      } else if (pStatus === 'PAID') {
        if (isDoorstepQr) {
          // Rider collected UPI at doorstep
          riderQrTotal += tot
          riderQrCount += 1
          category = 'RIDER_QR'
          verifiedBy = `Rider QR (${o.deliveryUser?.name || 'Rider'})`
        } else if (['UPI', 'CARD', 'WALLET', 'ONLINE', 'RAZORPAY', 'CASHFREE'].includes(pMethod)) {
          // Paid directly via Cashfree / Online Gateway
          cashfreeOnlineTotal += tot
          cashfreeOnlineCount += 1
          category = 'CASHFREE_ONLINE'
          verifiedBy = 'Cashfree Gateway (Auto)'
        } else {
          // COD Paid in Cash
          if (o.cashSettledToAdmin) {
            counterCashTotal += tot
            counterCashCount += 1
            category = 'COUNTER_CASH'
            verifiedBy = 'Settled to Counter'
          } else if (oStatus === 'DELIVERED') {
            riderCashTotal += tot
            riderCashCount += 1
            category = 'RIDER_CASH'
            verifiedBy = `Rider Cash (${o.deliveryUser?.name || 'Rider'})`
          } else {
            counterCashTotal += tot
            counterCashCount += 1
            category = 'COUNTER_CASH'
            verifiedBy = 'Cash Paid'
          }
        }
      } else {
        // Pending
        if (pMethod === 'COD') {
          if (oStatus === 'DELIVERED') {
            riderCashTotal += tot
            riderCashCount += 1
            category = 'RIDER_CASH'
            verifiedBy = `Rider Cash (${o.deliveryUser?.name || 'Rider'})`
          } else {
            pendingCodTotal += tot
            pendingCodCount += 1
            category = 'PENDING_DELIVERY'
            verifiedBy = 'COD at Doorstep'
          }
        } else {
          pendingOnlineTotal += tot
          pendingOnlineCount += 1
          category = 'PENDING_ONLINE'
          verifiedBy = 'Awaiting Online Payment'
        }
      }

      const orderIst = new Date(new Date(o.createdAt).getTime() + istOffset)
      const hours = orderIst.getUTCHours()
      const mins = orderIst.getUTCMinutes()
      const ampm = hours >= 12 ? 'PM' : 'AM'
      const formattedHours = hours % 12 || 12
      const timeStr = `${String(formattedHours).padStart(2, '0')}:${String(mins).padStart(2, '0')} ${ampm}`

      return {
        id: o.id,
        readableId: String(o.readableId || o.id.slice(-6)).toUpperCase(),
        createdAt: o.createdAt.toISOString(),
        timeStr,
        total: tot,
        customerName: o.user?.name || 'Customer',
        customerPhone: o.user?.phone || '',
        shopName: o.shopName || (o.restaurantId ? 'Restaurant' : 'FastKirana Grocery'),
        paymentMethod: pMethod,
        paymentStatus: pStatus,
        orderStatus: oStatus,
        category,
        verifiedBy,
        riderName: o.deliveryUser?.name || null,
        cashSettled: Boolean(o.cashSettledToAdmin),
        cashSettledAt: o.cashSettledAt?.toISOString() || null,
      }
    })

    // Fetch active riders
    const riders = await prisma.user.findMany({
      where: {
        role: Role.DELIVERY,
        ...(storeId && storeId.toLowerCase() !== 'all' ? { assignedStoreId: storeId } : {}),
      },
      include: {
        riderWallet: true,
      },
    })

    const riderSummary = riders
      .map((r: any) => {
        const cashInHand = Number(r.riderWallet?.cashInHand || 0)
        const riderDelivered = transactions.filter(
          (t: any) => t.riderName === r.name && t.orderStatus === 'DELIVERED'
        )

        return {
          id: r.id,
          name: r.name || 'Rider',
          phone: r.phone || '',
          cashInHand,
          todayDeliveredCount: riderDelivered.length,
          todayDeliveredTotal: riderDelivered.reduce((s: number, t: any) => s + t.total, 0),
        }
      })
      .filter((r: any) => r.cashInHand > 0 || r.todayDeliveredCount > 0)

    const onlineBankTotal = cashfreeOnlineTotal + riderQrTotal
    const onlineOrderCount = cashfreeOnlineCount + riderQrCount
    const totalReconciled = onlineBankTotal + counterCashTotal + riderCashTotal

    return NextResponse.json({
      date: targetDateStr,
      isToday: targetDateStr === currentIst.toISOString().slice(0, 10),
      summary: {
        cashfreeOnlineTotal: Math.round(cashfreeOnlineTotal * 100) / 100,
        cashfreeOnlineCount,
        riderQrTotal: Math.round(riderQrTotal * 100) / 100,
        riderQrCount,
        onlineBankTotal: Math.round(onlineBankTotal * 100) / 100,
        onlineOrderCount,
        counterCashTotal: Math.round(counterCashTotal * 100) / 100,
        counterCashCount,
        riderCashTotal: Math.round(riderCashTotal * 100) / 100,
        riderCashCount,
        pendingCodTotal: Math.round(pendingCodTotal * 100) / 100,
        pendingCodCount,
        pendingOnlineTotal: Math.round(pendingOnlineTotal * 100) / 100,
        pendingOnlineCount,
        totalReconciled: Math.round(totalReconciled * 100) / 100,
        totalOrdersCount: orders.length,
      },
      riders: riderSummary,
      transactions,
    })
  } catch (err: any) {
    console.error('Finance API error:', err)
    return NextResponse.json({ error: err.message || 'Failed to fetch finance report' }, { status: 500 })
  }
}
