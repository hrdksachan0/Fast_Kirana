import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Role } from '@prisma/client'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  try {
    const adminResult = await requireAdmin(req)
    if (adminResult.error) return adminResult.error
    const session = adminResult.session

    const { searchParams } = new URL(req.url)
    const dateStr = searchParams.get('date') // YYYY-MM-DD
    const rawStoreId = searchParams.get('storeId')
    const storeId = getEffectiveStoreId(session, rawStoreId)

    // Time calculation for IST (UTC + 5:30)
    const now = new Date()
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

    // ── CATEGORIZATION LOGIC ──
    // Cashfree is the SOLE payment gateway. Therefore:
    //   - Any UPI/CARD/WALLET order with paymentStatus=PAID that is NOT a doorstep QR = Cashfree PG
    //   - Doorstep QR = rider collected UPI at customer's door (notes contain 'Doorstep UPI' / 'QR Scan' / 'Rider QR')
    //   - COD PAID + DELIVERED = Rider Cash
    //   - COD PAID + settled = Counter Cash
    //   - No need to probe Cashfree API per-order (slow, rate-limited, IDs may not match)

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

      // Doorstep QR detection: rider showed QR to customer at delivery
      const isDoorstepQr = notes.includes('Doorstep UPI') || notes.includes('QR Scan') || notes.includes('Rider QR')

      // Cashfree PG detection: notes written by verify/webhook route
      const hasCashfreeNote = notes.includes('Cashfree PG') || notes.includes('CF_') || notes.includes('Cashfree Auto-Paid')

      // Admin manual verification
      const isAdminVerified = notes.includes('Admin Verified')
      const adminNameMatch = notes.match(/Admin Verified by (.+?)(?:\s*\||$)/)
      const adminVerifierName = adminNameMatch ? adminNameMatch[1].trim() : 'Admin'

      // Is this a non-COD online payment method?
      const isOnlineMethod = pMethod !== 'COD' // UPI, CARD, WALLET

      let category = 'PENDING_DELIVERY'
      let verifiedBy = 'Pending'

      if (oStatus === 'CANCELLED') {
        // ── CANCELLED ──
        category = 'CANCELLED'
        verifiedBy = 'Order Cancelled'

      } else if (pStatus === 'PAID' && isDoorstepQr) {
        // ── RIDER DOORSTEP QR ── (check BEFORE Cashfree so doorstep UPI isn't misclassified)
        riderQrTotal += tot
        riderQrCount += 1
        category = 'RIDER_QR'
        verifiedBy = `Rider QR (${o.deliveryUser?.name || 'Rider'})`

      } else if (pStatus === 'PAID' && isOnlineMethod) {
        // ── CASHFREE PG ONLINE ──
        // Since Cashfree is the ONLY gateway, every non-COD non-doorstep-QR PAID order = Cashfree
        cashfreeOnlineTotal += tot
        cashfreeOnlineCount += 1
        category = 'CASHFREE_ONLINE'

        if (isAdminVerified) {
          verifiedBy = `Cashfree PG (Admin: ${adminVerifierName})`
        } else if (hasCashfreeNote) {
          verifiedBy = 'Cashfree PG (Auto ✓)'
        } else {
          verifiedBy = 'Cashfree PG (Online)'
        }

      } else if (pStatus === 'PAID' && pMethod === 'COD') {
        // ── COD PAID ──
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
          verifiedBy = 'Counter Cash'
        }

      } else {
        // ── PENDING (not yet paid) ──
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
          // Online method but not yet PAID
          pendingOnlineTotal += tot
          pendingOnlineCount += 1
          category = 'PENDING_ONLINE'
          verifiedBy = 'Awaiting Cashfree Payment'
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
        const todayCashCollected = riderDelivered
          .filter((t: any) => t.category === 'RIDER_CASH' || (t.paymentMethod === 'COD' && !t.cashSettled))
          .reduce((s: number, t: any) => s + t.total, 0)

        return {
          id: r.id,
          name: r.name || 'Rider',
          phone: r.phone || '',
          cashInHand,
          todayCashCollected,
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
