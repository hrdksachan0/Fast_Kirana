import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

async function checkAdmin() {
  const session = await auth()
  return session?.user && (session.user as any).role === 'ADMIN'
}

// 1. GET: Fetch all payouts
export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const type = searchParams.get('type') || undefined

    const payouts = await prisma.restaurantPayout.findMany({
      where: type ? { type } : {},
      orderBy: { createdAt: 'desc' }
    })
    return NextResponse.json(payouts)
  } catch (error: any) {
    console.error('Error fetching payouts:', error)
    return NextResponse.json({ error: 'Failed to load payouts' }, { status: 500 })
  }
}

// 2. POST: Create/Calculate a new payout draft
export async function POST(request: NextRequest) {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { startDate, endDate, notes, type = 'RESTAURANT' } = await request.json()
    if (!startDate || !endDate) {
      return NextResponse.json({ error: 'Start date and End date are required' }, { status: 400 })
    }

    const start = new Date(startDate)
    start.setHours(0, 0, 0, 0)
    const end = new Date(endDate)
    end.setHours(23, 59, 59, 999)

    // Set configuration based on Payout Type (RESTAURANT vs CAFE)
    const isCafe = type === 'CAFE'
    const shopName = isCafe ? 'FastKirana Cafe Kitchen' : 'FastKirana Restaurant Kitchen'
    const shareKey = isCafe ? 'cafe_profit_share' : 'restaurant_profit_share'

    // Fetch dynamic profit share setting
    const shareSetting = await prisma.storeSetting.findUnique({
      where: { key: shareKey }
    })
    const profitShareRate = parseFloat(shareSetting?.value || '15') / 100

    // Fetch all delivered orders in range
    const orders = await prisma.order.findMany({
      where: {
        status: 'DELIVERED',
        shopName,
        createdAt: {
          gte: start,
          lte: end
        }
      }
    })

    // Calculate total share
    let totalShare = 0
    orders.forEach(o => {
      const foodSales = (o.subtotal || 0) - (o.discount || 0)
      totalShare += foodSales * profitShareRate
    })

    const finalAmount = Math.round(totalShare * 100) / 100

    // Create payout entry
    const payout = await prisma.restaurantPayout.create({
      data: {
        type,
        startDate: start,
        endDate: end,
        amount: finalAmount,
        status: 'PENDING',
        notes: notes || `Payout calculation for ${startDate} to ${endDate}`
      }
    })

    return NextResponse.json(payout)
  } catch (error: any) {
    console.error('Error calculating payout:', error)
    return NextResponse.json({ error: error.message || 'Failed to create payout' }, { status: 500 })
  }
}

// 3. PATCH: Mark payout as paid (Settle)
export async function PATCH(request: NextRequest) {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { id, transactionId, notes } = await request.json()
    if (!id) {
      return NextResponse.json({ error: 'Payout ID is required' }, { status: 400 })
    }

    const payout = await prisma.restaurantPayout.update({
      where: { id },
      data: {
        status: 'PAID',
        transactionId: transactionId || null,
        paidAt: new Date(),
        notes: notes || undefined
      }
    })

    return NextResponse.json(payout)
  } catch (error: any) {
    console.error('Error settling payout:', error)
    return NextResponse.json({ error: error.message || 'Failed to settle payout' }, { status: 500 })
  }
}
