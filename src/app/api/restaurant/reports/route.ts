import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { formatDate } from '@/lib/date-helpers'
import { getLast10Digits } from '@/lib/phone'
import { normalizeRestaurantId } from '@/lib/restaurant-ids'
import { logger } from '@/lib/logger'
import { restaurantReportService } from '@/services/restaurant-report.service'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const email = session.user.email || ''
    const phone = session.user.phone || ''
    const cleanPhone = phone ? getLast10Digits(phone) : ''
    let assignedRestId = session.user.assignedRestaurantId

    if (!assignedRestId && cleanPhone) {
      const dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: { endsWith: cleanPhone } },
            { phone: `+91${cleanPhone}` }
          ],
          assignedRestaurantId: { not: null }
        },
        select: { assignedRestaurantId: true }
      })
      if (dbUser?.assignedRestaurantId) {
        assignedRestId = dbUser.assignedRestaurantId
      } else {
        const rest = await prisma.restaurant.findFirst({
          where: { ownerPhone: { contains: cleanPhone } },
          select: { id: true }
        })
        if (rest) assignedRestId = rest.id
      }
    }

    const isAllowed = role === 'ADMIN' || role === 'RESTAURANT_OWNER' || role === 'CHEF'
    
    if (!isAllowed) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { searchParams } = new URL(request.url)
    const startDateParam = searchParams.get('startDate')
    const endDateParam = searchParams.get('endDate')
    const paramRestId = searchParams.get('restaurantId')

    const isPlatformAdmin = role === 'ADMIN'
    let effectiveRestId = (!isPlatformAdmin && assignedRestId) 
      ? assignedRestId 
      : (paramRestId || assignedRestId || null)

    if (!effectiveRestId) {
      return NextResponse.json({ error: 'No restaurant specified' }, { status: 400 })
    }
    
    effectiveRestId = normalizeRestaurantId(effectiveRestId)

    const now = new Date()
    let start: Date
    let end: Date

    if (startDateParam) {
      start = new Date(`${startDateParam}T00:00:00.000`)
    } else {
      start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
      start.setHours(0, 0, 0, 0)
    }

    if (endDateParam) {
      end = new Date(`${endDateParam}T23:59:59.999`)
    } else {
      end = new Date(now.getTime())
      end.setHours(23, 59, 59, 999)
    }

    const reportData = await restaurantReportService.getReports(effectiveRestId, start, end)
    return NextResponse.json(reportData)
  } catch (error: unknown) {
    logger.error('restaurant-reports', 'Restaurant reports API error', error)
    const message = error instanceof Error ? error.message : 'Failed to fetch restaurant reports'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
