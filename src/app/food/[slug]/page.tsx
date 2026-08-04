import { notFound } from 'next/navigation'
import { prisma } from '@/lib/prisma'
import { RestaurantStorefront } from '@/components/food/restaurant-storefront'
import { Metadata } from 'next'

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const restaurant = await prisma.restaurant.findFirst({
    where: { slug, isActive: true },
  })

  if (!restaurant) {
    return { title: 'Restaurant Not Found - FastKirana' }
  }

  return {
    title: `${restaurant.name} - Order Online | FastKirana`,
    description: restaurant.description || `Order delicious food from ${restaurant.name} online at FastKirana. Fast delivery in Ghatampur!`,
  }
}

export default async function FoodRestaurantPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const restaurant = await prisma.restaurant.findFirst({
    where: { slug, isActive: true },
  })

  if (!restaurant) {
    notFound()
  }

  const isASCafe = restaurant.slug === 'as-cafe' || restaurant.slug === 'as-restaurant' || restaurant.id === 'cms2p1lap0000n0id8alldboy'

  const productWhere: any = {
    isAvailable: true,
  }

  if (isASCafe) {
    productWhere.OR = [
      { restaurantId: restaurant.id },
      { restaurant: { slug: restaurant.slug } },
      { category: { slug: { in: ['beverages', 'ice-cream', 'cold-beverages', 'hot-beverages', 'desserts', 'cafe', 'fastkirana-cafe'] } } },
      { tags: { hasSome: ['beverages', 'beverage', 'drinks', 'cold-drinks', 'ice-cream', 'ice cream', 'desserts', 'shake', 'shakes'] } }
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
