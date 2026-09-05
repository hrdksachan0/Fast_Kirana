import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { apiReadLimiter, apiWriteLimiter } from '@/lib/rate-limit'
import { revalidateStorefront } from '@/lib/revalidate'

import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'

export async function GET(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { searchParams } = new URL(request.url)
    const cuisine = searchParams.get('cuisine')
    const search = searchParams.get('search')
    const all = searchParams.get('all') === 'true'

    const where: Prisma.RestaurantWhereInput = {}

    let isAdmin = false
    if (all) {
      const session = await auth()
      isAdmin = session?.user?.role === 'ADMIN'
    }

    if (!isAdmin || !all) {
      where.isActive = true
    }

    if (cuisine) {
      where.cuisineTags = {
        has: cuisine
      }
    }

    if (search) {
      where.name = {
        contains: search,
        mode: 'insensitive'
      }
    }

    const city = searchParams.get('city')
    if (city && city !== 'ALL') {
      where.city = {
        contains: city.trim(),
        mode: 'insensitive'
      }
    }

    const restaurants = await prisma.restaurant.findMany({
      where,
      orderBy: [
        { sortOrder: 'desc' },
        { createdAt: 'desc' }
      ],
      include: {
        staff: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            role: true,
            assignedRestaurantId: true,
          }
        },
        _count: {
          select: { products: true }
        }
      }
    })

    const mapped = restaurants.map(r => {
      const opStatus = checkStoreOperatingStatus(r)
      return {
        ...r,
        isOpen: opStatus.isOpen,
        isClosedBySchedule: opStatus.isClosedBySchedule,
        isClosedByOwner: opStatus.isClosedByOwner,
        formattedScheduleStr: opStatus.formattedScheduleStr,
      }
    })

    return NextResponse.json(mapped)
  } catch (error: any) {
    console.error('Restaurants API GET Error:', error)
    return NextResponse.json({ error: 'Failed to fetch restaurants' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { name, ownerUserId, ...rest } = body

    if (!name) {
      return NextResponse.json({ error: 'Missing required field: name' }, { status: 400 })
    }

    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim()

    // Check slug uniqueness
    const existing = await prisma.restaurant.findUnique({
      where: { slug }
    })

    let finalSlug = slug
    if (existing) {
      finalSlug = `${slug}-${Date.now().toString().slice(-4)}`
    }

    const allowedKeys = [
      'id', 'description', 'logoUrl', 'bannerUrl', 'address', 'city',
      'cuisineTags', 'deliveryTime', 'distance', 'lat', 'lng', 'isVeg',
      'isPureVeg', 'isOpen', 'openTime', 'closeTime', 'sortOrder',
      'discountOffer', 'discountBadge', 'commissionRate', 'ownerPhone',
      'ownerEmail', 'isActive', 'rating', 'menuSections'
    ]

    const createData: any = {
      name,
      slug: finalSlug,
    }
    for (const key of allowedKeys) {
      if (rest[key] !== undefined) {
        createData[key] = rest[key]
      }
    }

    // Auto-generate Series ID (REST-1xx for Ghatampur, REST-2xx for Hamirpur, etc.)
    if (!createData.id) {
      let seriesBase = 100
      const cityLower = (createData.city || '').toLowerCase()
      if (cityLower.includes('hamirpur') || cityLower.includes('210301')) seriesBase = 200
      else if (cityLower.includes('pukhrayan') || cityLower.includes('209111')) seriesBase = 300
      else if (cityLower.includes('kanpur') || cityLower.includes('208001')) seriesBase = 400

      const existingInSeries = await prisma.restaurant.findMany({
        where: { id: { startsWith: `REST-${seriesBase.toString().slice(0, 1)}` } },
        select: { id: true }
      })

      const numbers = existingInSeries
        .map(r => parseInt(r.id.replace('REST-', '')))
        .filter(n => !isNaN(n))
      
      const maxNum = numbers.length > 0 ? Math.max(...numbers) : seriesBase
      const nextNum = maxNum + 1
      createData.id = `REST-${nextNum}`
    }

    if (!createData.menuSections || (Array.isArray(createData.menuSections) && createData.menuSections.length === 0)) {
      const shortCode = createData.id.replace('REST-', '')
      createData.menuSections = [
        { id: `SEC-${shortCode}-01`, title: "Chef's Special", emoji: "⭐", matchTags: ["special", "recommended"] },
        { id: `SEC-${shortCode}-02`, title: "Main Dishes", emoji: "🍽️", matchTags: ["main", "dishes"] },
        { id: `SEC-${shortCode}-03`, title: "Drinks & Beverages", emoji: "🥤", matchTags: ["beverages", "drinks"] }
      ]
    }

    if (createData.lat !== undefined && createData.lat !== null) {
      const p = parseFloat(createData.lat)
      createData.lat = isNaN(p) ? null : p
    }
    if (createData.lng !== undefined && createData.lng !== null) {
      const p = parseFloat(createData.lng)
      createData.lng = isNaN(p) ? null : p
    }
    if (createData.sortOrder !== undefined && createData.sortOrder !== null) {
      const p = parseInt(createData.sortOrder)
      createData.sortOrder = isNaN(p) ? 0 : p
    }
    if (createData.commissionRate !== undefined && createData.commissionRate !== null) {
      const p = parseFloat(createData.commissionRate)
      createData.commissionRate = isNaN(p) ? 0 : p
    }
    if (createData.rating !== undefined && createData.rating !== null) {
      const p = parseFloat(createData.rating)
      createData.rating = isNaN(p) ? 4.0 : p
    }

    const restaurant = await prisma.restaurant.create({
      data: createData
    })

    // Assign owner by ownerUserId or ownerPhone
    if (ownerUserId) {
      await prisma.user.update({
        where: { id: ownerUserId },
        data: {
          assignedRestaurantId: restaurant.id,
          role: 'RESTAURANT_OWNER'
        }
      }).catch(err => console.error('Failed to assign owner user:', err))
    } else if (createData.ownerPhone) {
      const cleanPhone = createData.ownerPhone.replace(/\D/g, '').slice(-10)
      if (cleanPhone.length === 10) {
        const formattedPhone = `+91${cleanPhone}`
        const existingStaff = await prisma.user.findFirst({
          where: {
            OR: [
              { phone: formattedPhone },
              { phone: cleanPhone },
              { phone: { endsWith: cleanPhone } }
            ]
          }
        })
        if (existingStaff) {
          await prisma.user.update({
            where: { id: existingStaff.id },
            data: {
              role: 'RESTAURANT_OWNER',
              assignedRestaurantId: restaurant.id
            }
          })
        } else {
          await prisma.user.create({
            data: {
              phone: formattedPhone,
              name: `${createData.name} Owner`,
              email: `kitchen.${restaurant.id.toLowerCase()}@fastkirana.in`,
              role: 'RESTAURANT_OWNER',
              assignedRestaurantId: restaurant.id
            }
          })
        }
      }
    }

    revalidateStorefront('restaurants')

    return NextResponse.json(restaurant, { status: 201 })
  } catch (error: any) {
    console.error('Restaurants API POST Error:', error)
    return NextResponse.json({ error: error.message || 'Failed to create restaurant' }, { status: 500 })
  }
}
