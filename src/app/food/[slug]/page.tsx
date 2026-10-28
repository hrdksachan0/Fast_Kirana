export const revalidate = 86400 // Cache for 24 hours, purged on-demand when restaurant or products update

import { notFound } from 'next/navigation'
import { Metadata } from 'next'
import { prisma } from '@/lib/prisma'
import { RestaurantStorefront } from '@/components/food/restaurant-storefront'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID, OUTLET_BAL_UDYAN_ID, OUTLET_PIZZA_LOVERS_ID } from '@/lib/constants'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { resolveProductBogoBadge } from '@/lib/coupon-rules'

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

  const isPizzaLovers =
    decodedSlug.includes('pizza') ||
    decodedSlug.includes('hot-pizza')

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
        ...(isPizzaLovers
          ? [
              { id: OUTLET_PIZZA_LOVERS_ID },
              { slug: { in: ['hot-pizza-lovers', 'pizza-lovers', 'pizza-lover'] } },
              { name: { contains: 'Pizza', mode: 'insensitive' as const } },
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
    return { title: 'Restaurant Not Found - FastMinute' }
  }

  const title = `${restaurant.name} - Order Online | FastMinute Ghatampur`
  const description = restaurant.description || `Order delicious food, pizza, burgers & meals from ${restaurant.name} online at FastMinute. Fast delivery in Ghatampur, Kanpur Nagar!`
  const canonicalUrl = `https://www.fastminute.in/food/${restaurant.slug || slug}`

  return {
    title,
    description,
    keywords: [`${restaurant.name}`, `${restaurant.name} Ghatampur`, 'online food delivery', 'fast food delivery', 'Ghatampur food', 'Kanpur', 'cafe', 'restaurant'],
    alternates: {
      canonical: canonicalUrl,
    },
    openGraph: {
      title,
      description,
      url: canonicalUrl,
      siteName: 'FastMinute',
      images: [restaurant.bannerUrl || restaurant.logoUrl ? { url: (restaurant.bannerUrl || restaurant.logoUrl)! } : { url: '/brand/fastkirana_app_icon.png' }],
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [restaurant.bannerUrl || restaurant.logoUrl || '/brand/fastkirana_app_icon.png'],
    },
  }
}

export default async function FoodRestaurantPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const restaurant = await findRestaurantBySlug(slug)

  if (!restaurant) {
    notFound()
  }

  const now = new Date()
  const [restaurantProducts, darkstoreProducts, activeCoupons] = await Promise.all([
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
    }),
    prisma.coupon.findMany({
      where: {
        restaurantId: restaurant.id,
        isActive: true,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: now } },
        ],
      },
      select: {
        id: true,
        code: true,
        discountType: true,
        bogoType: true,
        badgeText: true,
        menuSection: true,
        categoryId: true,
        restaurantId: true,
        bogoDishId: true,
        isActive: true,
        expiresAt: true,
      },
    }),
  ])

  // Attach bogoBadge strictly to qualifying dishes
  const decoratedProducts = restaurantProducts.map((p) => ({
    ...p,
    bogoBadge: resolveProductBogoBadge(p, activeCoupons),
  }))

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
  const serializedProducts = JSON.parse(JSON.stringify(decoratedProducts))
  const serializedRecommendedAddons = JSON.parse(JSON.stringify(darkstoreProducts))

  const restaurantJsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Restaurant',
    name: restaurant.name,
    image: restaurant.bannerUrl || restaurant.logoUrl || 'https://www.fastminute.in/brand/fastkirana_app_icon.png',
    url: `https://www.fastminute.in/food/${restaurant.slug || slug}`,
    telephone: '+91-9450358388',
    priceRange: '₹₹',
    servesCuisine: (restaurant as any).cuisineTags?.join(', ') || 'Fast Food, North Indian, Snacks',
    address: {
      '@type': 'PostalAddress',
      addressLocality: 'Ghatampur',
      addressRegion: 'Uttar Pradesh',
      postalCode: '209206',
      addressCountry: 'IN',
    },
    geo: {
      '@type': 'GeoCoordinates',
      latitude: 26.1554,
      longitude: 80.1633,
    },
    breadcrumb: {
      '@type': 'BreadcrumbList',
      itemListElement: [
        {
          '@type': 'ListItem',
          position: 1,
          name: 'Home',
          item: 'https://www.fastminute.in',
        },
        {
          '@type': 'ListItem',
          position: 2,
          name: 'Food & Restaurants',
          item: 'https://www.fastminute.in/food',
        },
        {
          '@type': 'ListItem',
          position: 3,
          name: restaurant.name,
          item: `https://www.fastminute.in/food/${restaurant.slug || slug}`,
        },
      ],
    },
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(restaurantJsonLd) }}
      />
      <RestaurantStorefront
        restaurant={serializedRestaurant}
        products={serializedProducts}
        recommendedAddons={serializedRecommendedAddons}
      />
    </>
  )
}
