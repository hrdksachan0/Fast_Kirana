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

  const products = await prisma.product.findMany({
    where: {
      restaurantId: restaurant.id,
      isAvailable: true,
    },
    include: {
      category: true,
      images: true,
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
