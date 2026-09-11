import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { apiReadLimiter, apiWriteLimiter } from '@/lib/rate-limit'
import { revalidateStorefront, revalidateRestaurant } from '@/lib/revalidate'

import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { extractCityFromStoreName } from '@/lib/store-resolver'

export async function GET(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { searchParams } = new URL(request.url)
    const cuisine = searchParams.get('cuisine')
    const search = searchParams.get('search')
    const all = searchParams.get('all') === 'true'

    const where: Prisma.RestaurantWhereInput = {}

    const session = await auth()
    const userRole = session?.user?.role
    const userAssignedRestaurantId = (session?.user as any)?.assignedRestaurantId
    const isAdmin = userRole === 'ADMIN'

    // 1. Strict Isolation: If logged in as RESTAURANT_OWNER or CHEF, lock to their assigned restaurant!
    if (userRole === 'RESTAURANT_OWNER' || userRole === 'CHEF') {
      if (userAssignedRestaurantId) {
        where.id = userAssignedRestaurantId
      }
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

    // 2. Filter by storeId: If browsing by dark store hub (or store-assigned admin), only restaurants from that store's city!
    const userAssignedStoreId = (session?.user as any)?.assignedStoreId
    const storeId = searchParams.get('storeId') || userAssignedStoreId
    if (storeId && storeId !== 'all') {
      const store = await prisma.darkStore.findUnique({
        where: { id: storeId },
        select: { name: true }
      })
      const storeCity = store ? extractCityFromStoreName(store.name) : ''
      if (storeCity) {
        where.city = { contains: storeCity, mode: 'insensitive' }
      } else if (store) {
        where.city = { contains: store.name, mode: 'insensitive' }
      } else {
        where.city = '__NO_MATCHING_CITY__'
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
          select: {
            products: true,
            orders: {
              where: {
                status: { in: ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED'] }
              }
            }
          }
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
        activeOrdersCount: r._count?.orders ?? 0,
      }
    })

    const isPublic = !isAdmin && !all
    return NextResponse.json(mapped, {
      headers: {
        'Cache-Control': isPublic
          ? 'public, s-maxage=60, stale-while-revalidate=120'
          : 'no-store, max-age=0, must-revalidate',
      }
    })
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

    const targetStoreId = body.storeId || (session?.user as any)?.assignedStoreId
    if (targetStoreId && (!createData.city || createData.city.trim() === '')) {
      const store = await prisma.darkStore.findUnique({
        where: { id: targetStoreId },
        select: { name: true }
      })
      if (store) {
        createData.city = extractCityFromStoreName(store.name) || store.name
      }
    }

    // Auto-generate Series ID (REST-1xx for Ghatampur, REST-2xx for Hamirpur, etc.)
    if (!createData.id) {
      let seriesBase = 100
      const cityLower = (createData.city || '').toLowerCase()
      if (cityLower.includes('hamirpur') || cityLower.includes('210301')) seriesBase = 200
      else if (cityLower.includes('pukhrayan') || cityLower.includes('pukhraya') || cityLower.includes('209111')) seriesBase = 300
      else if (cityLower.includes('akbarpur') || cityLower.includes('224122')) seriesBase = 500
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

    revalidateRestaurant(restaurant.slug)

    return NextResponse.json(restaurant, { status: 201 })
  } catch (error: any) {
    console.error('Restaurants API POST Error:', error)
    return NextResponse.json({ error: error.message || 'Failed to create restaurant' }, { status: 500 })
  }
}
