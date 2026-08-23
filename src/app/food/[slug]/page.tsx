export const dynamic = 'force-dynamic'

import { notFound } from 'next/navigation'
import { Metadata } from 'next'
import { prisma } from '@/lib/prisma'
import { RestaurantStorefront } from '@/components/food/restaurant-storefront'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID, OUTLET_BAL_UDYAN_ID } from '@/lib/constants'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const decodedSlug = decodeURIComponent(slug).toLowerCase()
  
  const restaurant = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { equals: decodedSlug, mode: 'insensitive' } },
        { id: slug },
        ...(decodedSlug === 'as-restaurant' || decodedSlug === 'as-cafe' || decodedSlug === 'as' || decodedSlug === 'a-s-cafe'
          ? [
              { id: OUTLET_AS_RESTAURANT_ID },
              { slug: { in: ['as-cafe', 'as-restaurant', 'a-s-cafe', 'a-s-restaurant'] } },
              { name: { contains: 'A.S', mode: 'insensitive' as const } },
            ]
          : []),
        ...(decodedSlug === 'wedson' || decodedSlug === 'restaurant-kitchen'
          ? [
              { id: OUTLET_WEDSON_ID },
              { slug: { in: ['wedson', 'restaurant-kitchen'] } },
              { name: { contains: 'Wedson', mode: 'insensitive' as const } },
            ]
          : []),
        ...(decodedSlug.includes('bal') || decodedSlug.includes('udyan')
          ? [
              { id: OUTLET_BAL_UDYAN_ID },
              { slug: { in: ['bal-udyan', 'bal-udyan-restaurant', 'baludyan'] } },
              { name: { contains: 'Bal Udyan', mode: 'insensitive' as const } },
            ]
          : []),
      ],
      isActive: true,
    },
  })

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
  const decodedSlug = decodeURIComponent(slug).toLowerCase()

  const restaurant = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { equals: decodedSlug, mode: 'insensitive' } },
        { id: slug },
        ...(decodedSlug === 'as-restaurant' || decodedSlug === 'as-cafe' || decodedSlug === 'as' || decodedSlug === 'a-s-cafe'
          ? [
              { id: OUTLET_AS_RESTAURANT_ID },
              { slug: { in: ['as-cafe', 'as-restaurant', 'a-s-cafe', 'a-s-restaurant'] } },
              { name: { contains: 'A.S', mode: 'insensitive' as const } },
            ]
          : []),
        ...(decodedSlug === 'wedson' || decodedSlug === 'restaurant-kitchen'
          ? [
              { id: OUTLET_WEDSON_ID },
              { slug: { in: ['wedson', 'restaurant-kitchen'] } },
              { name: { contains: 'Wedson', mode: 'insensitive' as const } },
            ]
          : []),
        ...(decodedSlug.includes('bal') || decodedSlug.includes('udyan')
          ? [
              { id: OUTLET_BAL_UDYAN_ID },
              { slug: { in: ['bal-udyan', 'bal-udyan-restaurant', 'baludyan'] } },
              { name: { contains: 'Bal Udyan', mode: 'insensitive' as const } },
            ]
          : []),
      ],
      isActive: true,
    },
  })

  if (!restaurant) {
    notFound()
  }

  const productWhere: any = {
    isAvailable: true,
    restaurantId: restaurant.id,
  }

  const products = await prisma.product.findMany({
    where: productWhere,
    include: {
      category: true,
      images: true,
      restaurant: true,
    },
    orderBy: [
      { sortOrder: 'desc' },
      { createdAt: 'desc' },
    ],
  })

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
