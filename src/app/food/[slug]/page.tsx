import { notFound } from 'next/navigation'
import { Metadata } from 'next'
import { prisma } from '@/lib/prisma'
import { RestaurantStorefront } from '@/components/food/restaurant-storefront'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID } from '@/lib/constants'

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
      ],
      isActive: true,
    },
  })

  if (!restaurant) {
    notFound()
  }

  const isASCafe = restaurant.slug === 'as-cafe' || restaurant.slug === 'as-restaurant' || restaurant.id === OUTLET_AS_RESTAURANT_ID
  const isWedson = restaurant.slug === 'wedson' || restaurant.id === OUTLET_WEDSON_ID || restaurant.slug === 'restaurant-kitchen'

  const productWhere: any = {
    isAvailable: true,
  }

  if (isASCafe) {
    productWhere.OR = [
      { restaurantId: restaurant.id },
      { restaurant: { slug: { in: ['as-restaurant', 'as-cafe'] } } },
      { tags: { hasSome: ['as-restaurant', 'as-cafe', 'as_restaurant', 'a.s restaurant', 'a.s. restaurant'] } }
    ]
  } else if (isWedson) {
    productWhere.OR = [
      { restaurantId: restaurant.id },
      { restaurant: { slug: { in: ['wedson', 'restaurant-kitchen'] } } },
      { tags: { hasSome: ['wedson', 'wedson-restaurant'] } }
    ]
  } else {
    productWhere.OR = [
      { restaurantId: restaurant.id },
      { restaurant: { slug: restaurant.slug } },
    ]
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

  // Serialize dates for client component
  const serializedRestaurant = JSON.parse(JSON.stringify(restaurant))
  const serializedProducts = JSON.parse(JSON.stringify(products))

  return (
    <RestaurantStorefront
      restaurant={serializedRestaurant}
      products={serializedProducts}
    />
  )
}
