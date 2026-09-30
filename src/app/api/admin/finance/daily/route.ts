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

    // Check Cashfree Gateway in parallel for today's orders
    const cashfreePaidIds = new Set<string>()
    const cfAppId = process.env.CASHFREE_APP_ID
    const cfSecret = process.env.CASHFREE_SECRET_KEY
    const cfEnv = (process.env.CASHFREE_ENV || 'PRODUCTION').toUpperCase()
    const cfBaseUrl = cfEnv === 'PRODUCTION' ? 'https://api.cashfree.com/pg' : 'https://sandbox.cashfree.com/pg'

    if (cfAppId && cfSecret && orders.length > 0) {
      try {
        // Only check Cashfree for orders that could be prepaid gateway payments
        // Skip: COD orders, Rider QR / doorstep UPI, cancelled orders
        const eligibleForCfCheck = orders.filter((o: any) => {
          const pMethod = String(o.paymentMethod || 'COD').toUpperCase()
          const oStatus = String(o.status || 'PENDING').toUpperCase()
          const notes = String(o.notes || '')
          const isDoorstepQr = notes.includes('Doorstep UPI') || notes.includes('QR Scan') || notes.includes('Rider QR')

          // Skip COD orders — they never go through Cashfree
          if (pMethod === 'COD') return false
          // Skip doorstep QR orders — rider collected UPI, not Cashfree PG
          if (isDoorstepQr) return false
          // Skip cancelled orders
          if (oStatus === 'CANCELLED') return false

          return true
        })

        const cfChecks = eligibleForCfCheck.map(async (o: any) => {
          const idsToProbe = [
            o.id,
            o.readableId,
            o.readableId ? String(o.readableId).replace(/-[GR\d]+$/i, '') : null,
            o.combinedId
          ].filter(Boolean) as string[]

          for (const cid of idsToProbe) {
            try {
              const res = await fetch(`${cfBaseUrl}/orders/${cid}`, {
                headers: {
                  'Content-Type': 'application/json',
                  'x-api-version': '2023-08-01',
                  'x-client-id': cfAppId,
                  'x-client-secret': cfSecret,
                },
                signal: AbortSignal.timeout(3000),
              })
              if (res.ok) {
                const data = await res.json()
                if (data.order_status === 'PAID') {
                  cashfreePaidIds.add(o.id)
                  if (o.combinedId) {
                    cashfreePaidIds.add(o.combinedId)
                  }
                  break
                }
              }
            } catch (_) {}
          }
        })
        await Promise.all(cfChecks)
      } catch (err) {
        console.warn('Could not batch check Cashfree status in Next.js route:', err)
      }
    }

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
      const isInCashfree = cashfreePaidIds.has(o.id) || (o.combinedId && cashfreePaidIds.has(o.combinedId)) || notes.includes('Cashfree PG') || notes.includes('CF_')
      const isAdminVerified = notes.includes('Admin Verified')
      // Extract admin name from notes (e.g. "Admin Verified by Sooraj")
      const adminNameMatch = notes.match(/Admin Verified by (.+?)(?:\s*\||$)/)
      const adminVerifierName = adminNameMatch ? adminNameMatch[1].trim() : 'Admin'

      let category = 'PENDING_DELIVERY'
      let verifiedBy = 'Pending'

      if (oStatus === 'CANCELLED') {
        category = 'CANCELLED'
        verifiedBy = 'Order Cancelled'
      } else if (pStatus === 'PAID' && isAdminVerified) {
        // Admin manually marked as PAID — goes to Online/Bank bucket, NOT rider
        cashfreeOnlineTotal += tot
        cashfreeOnlineCount += 1
        category = 'ONLINE_BANK'
        verifiedBy = `Admin (${adminVerifierName})`
      } else if (isInCashfree) {
        // Cashfree API confirmed PAID — authoritative, check BEFORE rider QR
        cashfreeOnlineTotal += tot
        cashfreeOnlineCount += 1
        category = 'CASHFREE_ONLINE'
        verifiedBy = 'Cashfree Gateway (Auto)'
      } else if (pStatus === 'PAID' && isDoorstepQr) {
        // Rider collected UPI at doorstep (notes have Doorstep UPI / QR Scan / Rider QR markers)
        riderQrTotal += tot
        riderQrCount += 1
        category = 'RIDER_QR'
        verifiedBy = `Rider QR (${o.deliveryUser?.name || 'Rider'})`
      } else if (pStatus === 'PAID') {
        if (pMethod !== 'COD') {
          // Online / UPI payment: credit to Bank/Online, NOT counter cash
          cashfreeOnlineTotal += tot
          cashfreeOnlineCount += 1
          category = 'ONLINE_BANK'
          verifiedBy = `${pMethod} (Online)`
        } else if (o.cashSettledToAdmin) {
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
