export const dynamic = 'force-dynamic'

import { notFound } from 'next/navigation'
import { Metadata } from 'next'
import { prisma } from '@/lib/prisma'
import { RestaurantStorefront } from '@/components/food/restaurant-storefront'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID, OUTLET_BAL_UDYAN_ID } from '@/lib/constants'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'

async function findRestaurantBySlug(rawSlug: string) {
  const decodedSlug = decodeURIComponent(rawSlug || '').trim().toLowerCase().replace(/\/+$/, '')
  if (!decodedSlug) return null

  // Known alias flags
  const isAsRestaurant =
    decodedSlug === 'as-restaurant' ||
    decodedSlug === 'as-cafe' ||
    decodedSlug === 'as' ||
    decodedSlug === 'a-s-cafe' ||
    decodedSlug === 'a-s-restaurant' ||
    decodedSlug.startsWith('as-rest') ||
    decodedSlug.startsWith('as-cafe') ||
    decodedSlug === 'asrestaurant' ||
    decodedSlug === 'ascafe'

  const isWedson =
    decodedSlug === 'wedson' ||
    decodedSlug === 'wedson-restaurant' ||
    decodedSlug.startsWith('wedson') ||
    decodedSlug === 'restaurant-kitchen'

  const isBalUdyan =
    decodedSlug.includes('bal') ||
    decodedSlug.includes('udyan')

  // 1. Primary search: exact slug, ID, or known alias ID
  const restaurant = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { equals: decodedSlug, mode: 'insensitive' } },
        { id: rawSlug },
        { id: decodedSlug },
        ...(isAsRestaurant
          ? [
              { id: OUTLET_AS_RESTAURANT_ID },
              { slug: { in: ['as-cafe', 'as-restaurant', 'a-s-cafe', 'a-s-restaurant'] } },
              { name: { contains: 'A.S', mode: 'insensitive' as const } },
            ]
          : []),
        ...(isWedson
          ? [
              { id: OUTLET_WEDSON_ID },
              { slug: { in: ['wedson', 'wedson-restaurant', 'restaurant-kitchen'] } },
              { name: { contains: 'Wedson', mode: 'insensitive' as const } },
            ]
          : []),
        ...(isBalUdyan
          ? [
              { id: OUTLET_BAL_UDYAN_ID },
              { slug: { in: ['bal-udyan', 'bal-udyan-restaurant', 'baludyan'] } },
              { name: { contains: 'Bal Udyan', mode: 'insensitive' as const } },
            ]
          : []),
        // Fuzzy startsWith fallback
        { slug: { startsWith: decodedSlug, mode: 'insensitive' } },
      ],
      isActive: true,
    },
  })

  if (restaurant) return restaurant

  // 2. Secondary fallback: contains search on name or slug
  return await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { contains: decodedSlug, mode: 'insensitive' } },
        { name: { contains: decodedSlug, mode: 'insensitive' } },
      ],
      isActive: true,
    },
  })
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const restaurant = await findRestaurantBySlug(slug)

  if (!restaurant) {
    return { title: 'Restaurant Not Found - FastKirana' }
  }

  return {
    title: `${restaurant.name} - Order Online | FastKirana`,
    description: restaurant.description || `Order delicious food from ${restaurant.name} online at FastKirana. Fast delivery in Ghatampur!`,
    keywords: [`${restaurant.name}`, 'online food delivery', 'fast delivery', 'Ghatampur', 'Kanpur', 'cafe', 'restaurant'],
  }
}

export default async function FoodRestaurantPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const restaurant = await findRestaurantBySlug(slug)

  if (!restaurant) {
    notFound()
  }

  const [restaurantProducts, darkstoreProducts] = await Promise.all([
    prisma.product.findMany({
      where: {
        isAvailable: true,
        restaurantId: restaurant.id,
      },
      include: {
        category: true,
        images: true,
        restaurant: true,
      },
      orderBy: [
        { sortOrder: 'desc' },
        { createdAt: 'desc' },
      ],
    }),
    prisma.product.findMany({
      where: {
        isAvailable: true,
        restaurantId: null,
        category: {
          slug: { in: ['beverages', 'ice-cream'] }
        }
      },
      include: {
        category: true,
        images: true,
        restaurant: true,
      },
      orderBy: [
        { isBestSeller: 'desc' },
        { sortOrder: 'desc' },
      ],
    })
  ])

  const products = [...restaurantProducts, ...darkstoreProducts]

  const opStatus = checkStoreOperatingStatus(restaurant)
  const mappedRestaurant = {
    ...restaurant,
    isOpen: opStatus.isOpen,
    isClosedBySchedule: opStatus.isClosedBySchedule,
    isClosedByOwner: opStatus.isClosedByOwner,
    formattedScheduleStr: opStatus.formattedScheduleStr,
  }

  // Serialize dates for client component
  const serializedRestaurant = JSON.parse(JSON.stringify(mappedRestaurant))
  const serializedProducts = JSON.parse(JSON.stringify(products))

  return (
    <RestaurantStorefront
      restaurant={serializedRestaurant}
      products={serializedProducts}
    />
  )
}
