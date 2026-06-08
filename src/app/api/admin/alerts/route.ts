import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

// GET - Fetch all active inventory alerts (computed from current product state)
export async function GET() {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const now = new Date()
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000)

    // Run queries in parallel
    const [outOfStockProducts, lowStockProducts, expiringSoonProducts, expiredProducts, confirmedOrdersRaw] =
      await Promise.all([
        // 1. OUT_OF_STOCK: stock === 0 AND isAvailable === true
        prisma.product.findMany({
          where: {
            stock: 0,
            isAvailable: true,
          },
          select: {
            id: true,
            name: true,
            slug: true,
            imageUrl: true,
            stock: true,
            minStock: true,
            expiryDate: true,
            categoryId: true,
          },
        }),

        // 2. LOW_STOCK: stock > 0 AND stock <= minStock AND isAvailable === true
        // Using raw SQL because Prisma doesn't support field-to-field comparisons natively
        prisma.$queryRaw<
          Array<{
            id: string
            name: string
            slug: string
            imageUrl: string | null
            stock: number
            minStock: number
            expiryDate: Date | null
            categoryId: string
          }>
        >`
          SELECT id, name, slug, "imageUrl", stock, "minStock", "expiryDate", "categoryId"
          FROM products
          WHERE stock > 0
            AND stock <= "minStock"
            AND "isAvailable" = true
        `,

        // 3. EXPIRING_SOON: expiryDate is not null AND expiryDate <= 7 days from now AND expiryDate > now
        prisma.product.findMany({
          where: {
            expiryDate: {
              not: null,
              gt: now,
              lte: sevenDaysFromNow,
            },
          },
          select: {
            id: true,
            name: true,
            slug: true,
            imageUrl: true,
            stock: true,
            minStock: true,
            expiryDate: true,
            categoryId: true,
          },
        }),

        // 4. EXPIRED: expiryDate is not null AND expiryDate <= now
        prisma.product.findMany({
          where: {
            expiryDate: {
              not: null,
              lte: now,
            },
          },
          select: {
            id: true,
            name: true,
            slug: true,
            imageUrl: true,
            stock: true,
            minStock: true,
            expiryDate: true,
            categoryId: true,
          },
        }),

        // 5. CONFIRMED ORDERS: Accepted but not packed orders
        prisma.order.findMany({
          where: {
            status: 'CONFIRMED',
          },
          select: {
            id: true,
            updatedAt: true,
            shopName: true,
          },
        }),
      ])

    // Retrieve existing snoozed alerts from StoreSetting
    const setting = await prisma.storeSetting.findUnique({
      where: { key: 'snoozed_alerts' }
    }).catch(() => null)

    let snoozedMap: Record<string, string> = {}
    if (setting) {
      try {
        snoozedMap = JSON.parse(setting.value)
      } catch {
        snoozedMap = {}
      }
    }

    const thirtyMinutesAgoTimestamp = now.getTime() - 30 * 60 * 1000

    // Filter delayed accepted orders
    const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000)
    const thirtyMinutesAgo = new Date(now.getTime() - 30 * 60 * 1000)

    const packingDelays = confirmedOrdersRaw.filter((o) => {
      const isCafe = o.shopName === 'FastKirana Cafe Kitchen'
      const updatedTime = new Date(o.updatedAt).getTime()
      if (isCafe) {
        return updatedTime < thirtyMinutesAgo.getTime()
      } else {
        return updatedTime < tenMinutesAgo.getTime()
      }
    })

    const packingDelayAlerts = packingDelays.map((o) => {
      const isCafe = o.shopName === 'FastKirana Cafe Kitchen'
      const delayMin = Math.floor((now.getTime() - new Date(o.updatedAt).getTime()) / 60000)
      return {
        id: o.id,
        name: `${isCafe ? 'Cafe Order' : 'Grocery Order'} #${o.id.slice(0, 8)} accepted but not packed yet`,
        slug: `order-${o.id}`,
        imageUrl: null,
        stock: 0,
        minStock: 0,
        expiryDate: o.updatedAt instanceof Date ? o.updatedAt.toISOString() : String(o.updatedAt),
        categoryId: 'orders',
        alertType: 'PACKING_DELAY' as const,
      }
    })

    // Filter out snoozed alerts from each category
    const filteredOutOfStock = outOfStockProducts.filter(p => {
      const key = `${p.id}:OUT_OF_STOCK`
      const snoozedAt = snoozedMap[key]
      return !snoozedAt || new Date(snoozedAt).getTime() < thirtyMinutesAgoTimestamp
    })

    const filteredLowStock = lowStockProducts.filter(p => {
      const key = `${p.id}:LOW_STOCK`
      const snoozedAt = snoozedMap[key]
      return !snoozedAt || new Date(snoozedAt).getTime() < thirtyMinutesAgoTimestamp
    })

    const filteredExpiringSoon = expiringSoonProducts.filter(p => {
      const key = `${p.id}:EXPIRING_SOON`
      const snoozedAt = snoozedMap[key]
      return !snoozedAt || new Date(snoozedAt).getTime() < thirtyMinutesAgoTimestamp
    })

    const filteredExpired = expiredProducts.filter(p => {
      const key = `${p.id}:EXPIRED`
      const snoozedAt = snoozedMap[key]
      return !snoozedAt || new Date(snoozedAt).getTime() < thirtyMinutesAgoTimestamp
    })

    const filteredPackingDelays = packingDelayAlerts.filter(o => {
      const key = `${o.id}:PACKING_DELAY`
      const snoozedAt = snoozedMap[key]
      return !snoozedAt || new Date(snoozedAt).getTime() < thirtyMinutesAgoTimestamp
    })

    // Map products into alert objects with alertType
    const alerts = [
      ...filteredOutOfStock.map((p) => ({
        ...p,
        expiryDate: p.expiryDate?.toISOString() ?? null,
        alertType: 'OUT_OF_STOCK' as const,
      })),
      ...filteredLowStock.map((p) => ({
        ...p,
        expiryDate: p.expiryDate?.toISOString() ?? null,
        alertType: 'LOW_STOCK' as const,
      })),
      ...filteredExpiringSoon.map((p) => ({
        ...p,
        expiryDate: p.expiryDate?.toISOString() ?? null,
        alertType: 'EXPIRING_SOON' as const,
      })),
      ...filteredExpired.map((p) => ({
        ...p,
        expiryDate: p.expiryDate?.toISOString() ?? null,
        alertType: 'EXPIRED' as const,
      })),
      ...filteredPackingDelays,
    ]

    const counts = {
      outOfStock: filteredOutOfStock.length,
      lowStock: filteredLowStock.length,
      expiringSoon: filteredExpiringSoon.length,
      expired: filteredExpired.length,
      packingDelay: filteredPackingDelays.length,
      total: alerts.length,
    }

    return NextResponse.json({ alerts, counts })
  } catch (error: any) {
    console.error('Failed to fetch alerts:', error)
    return NextResponse.json(
      { error: 'Failed to fetch alerts' },
      { status: 500 }
    )
  }
}

// POST - Generate/refresh StockAlert records based on current inventory state
export async function POST() {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const now = new Date()
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000)

    // Clear old unread alerts
    await prisma.stockAlert.deleteMany({
      where: { isRead: false },
    })

    // Fetch current inventory state in parallel
    const [outOfStockProducts, lowStockProducts, expiringSoonProducts, expiredProducts] =
      await Promise.all([
        prisma.product.findMany({
          where: { stock: 0, isAvailable: true },
          select: { id: true, name: true, stock: true },
        }),

        prisma.$queryRaw<Array<{ id: string; name: string; stock: number; minStock: number }>>`
          SELECT id, name, stock, "minStock"
          FROM products
          WHERE stock > 0
            AND stock <= "minStock"
            AND "isAvailable" = true
        `,

        prisma.product.findMany({
          where: {
            expiryDate: { not: null, gt: now, lte: sevenDaysFromNow },
          },
          select: { id: true, name: true, expiryDate: true },
        }),

        prisma.product.findMany({
          where: {
            expiryDate: { not: null, lte: now },
          },
          select: { id: true, name: true, expiryDate: true },
        }),
      ])

    // Build alert records
    const alertRecords: Array<{
      productId: string
      alertType: string
      message: string
    }> = []

    for (const p of outOfStockProducts) {
      alertRecords.push({
        productId: p.id,
        alertType: 'OUT_OF_STOCK',
        message: `${p.name} is out of stock`,
      })
    }

    for (const p of lowStockProducts) {
      alertRecords.push({
        productId: p.id,
        alertType: 'LOW_STOCK',
        message: `${p.name} is low on stock (${p.stock}/${p.minStock})`,
      })
    }

    for (const p of expiringSoonProducts) {
      const daysLeft = Math.ceil(
        ((p.expiryDate as Date).getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
      )
      alertRecords.push({
        productId: p.id,
        alertType: 'EXPIRING_SOON',
        message: `${p.name} expires in ${daysLeft} day${daysLeft !== 1 ? 's' : ''}`,
      })
    }

    for (const p of expiredProducts) {
      alertRecords.push({
        productId: p.id,
        alertType: 'EXPIRED',
        message: `${p.name} has expired`,
      })
    }

    // Bulk create all alerts
    if (alertRecords.length > 0) {
      await prisma.stockAlert.createMany({
        data: alertRecords,
      })
    }

    return NextResponse.json({
      success: true,
      message: `Generated ${alertRecords.length} alert(s)`,
      count: alertRecords.length,
    })
  } catch (error: any) {
    console.error('Failed to generate alerts:', error)
    return NextResponse.json(
      { error: 'Failed to generate alerts' },
      { status: 500 }
    )
  }
}

// PATCH - Mark alerts as read
export async function PATCH(request: NextRequest) {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { alertIds, markAllRead } = body as {
      alertIds?: string[]
      markAllRead?: boolean
    }

    if (!markAllRead && (!alertIds || !Array.isArray(alertIds) || alertIds.length === 0)) {
      return NextResponse.json(
        { error: 'Provide alertIds array or set markAllRead to true' },
        { status: 400 }
      )
    }

    let updatedCount: number

    if (markAllRead) {
      const result = await prisma.stockAlert.updateMany({
        where: { isRead: false },
        data: { isRead: true },
      })
      updatedCount = result.count
    } else {
      const result = await prisma.stockAlert.updateMany({
        where: {
          id: { in: alertIds! },
          isRead: false,
        },
        data: { isRead: true },
      })
      updatedCount = result.count
    }

    return NextResponse.json({
      success: true,
      message: `Marked ${updatedCount} alert(s) as read`,
      updatedCount,
    })
  } catch (error: any) {
    console.error('Failed to update alerts:', error)
    return NextResponse.json(
      { error: 'Failed to update alerts' },
      { status: 500 }
    )
  }
}

// PUT - Take action on an alert (snooze/hide for 30 minutes)
export async function PUT(request: NextRequest) {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { targetId, alertType } = await request.json()
    if (!targetId || !alertType) {
      return NextResponse.json({ error: 'targetId and alertType are required' }, { status: 400 })
    }

    const now = new Date()

    // Retrieve existing snoozed alerts from StoreSetting
    const setting = await prisma.storeSetting.findUnique({
      where: { key: 'snoozed_alerts' }
    })

    let snoozedMap: Record<string, string> = {}
    if (setting) {
      try {
        snoozedMap = JSON.parse(setting.value)
      } catch {
        snoozedMap = {}
      }
    }

    // Add/Update current action
    const alertKey = `${targetId}:${alertType}`
    snoozedMap[alertKey] = now.toISOString()

    // Clean up old entries (older than 30 minutes)
    const thirtyMinutesAgo = now.getTime() - 30 * 60 * 1000
    for (const key in snoozedMap) {
      if (new Date(snoozedMap[key]).getTime() < thirtyMinutesAgo) {
        delete snoozedMap[key]
      }
    }

    // Save back to StoreSetting
    await prisma.storeSetting.upsert({
      where: { key: 'snoozed_alerts' },
      update: { value: JSON.stringify(snoozedMap) },
      create: { key: 'snoozed_alerts', value: JSON.stringify(snoozedMap) }
    })

    return NextResponse.json({ success: true, message: 'Alert actioned successfully' })
  } catch (error: any) {
    console.error('Failed to snooze alert:', error)
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
