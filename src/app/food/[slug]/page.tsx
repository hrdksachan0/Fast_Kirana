export const revalidate = 86400 // Cache for 24 hours, purged on-demand when restaurant or products update

import { notFound } from 'next/navigation'
import { Metadata } from 'next'
import { prisma } from '@/lib/prisma'
import { RestaurantStorefront } from '@/components/food/restaurant-storefront'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID, OUTLET_BAL_UDYAN_ID, OUTLET_PIZZA_LOVERS_ID, OUTLET_RADHA_RANI_ID, OUTLET_ZAYKA_ID } from '@/lib/constants'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { resolveProductBogoBadge } from '@/lib/coupon-rules'

async function findRestaurantBySlug(rawSlug: string) {
  const decodedSlug = decodeURIComponent(rawSlug || '').trim().toLowerCase().replace(/\/+$/, '')
  if (!decodedSlug) return null

  const slugHyphenated = decodedSlug.replace(/\s+/g, '-')
  const slugSpaced = decodedSlug.replace(/-+/g, ' ')

  // 1. Exact match on ID or Slug (Highest priority - 0 false positives)
  const exactMatch = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { id: { equals: rawSlug, mode: 'insensitive' } },
        { id: { equals: decodedSlug, mode: 'insensitive' } },
        { slug: { equals: decodedSlug, mode: 'insensitive' } },
        { slug: { equals: slugHyphenated, mode: 'insensitive' } },
        { slug: { equals: slugSpaced, mode: 'insensitive' } },
      ],
      isActive: true,
    },
  })
  if (exactMatch) return exactMatch

  // 2. Specific Known Outlet Aliases (Never match generic single words like "pizza")
  const isHotPizzaLovers =
    decodedSlug === 'hot-pizza-lovers' ||
    decodedSlug === 'hot pizza lovers' ||
    decodedSlug === 'pizza-lovers' ||
    decodedSlug === 'pizza lovers' ||
    decodedSlug === 'pizza-lover' ||
    decodedSlug === 'pizza lover' ||
    decodedSlug === 'hot-pizza' ||
    decodedSlug === 'hot pizza' ||
    decodedSlug.includes('hot-pizza') ||
    decodedSlug.includes('hot pizza') ||
    decodedSlug.includes('pizza-lover') ||
    decodedSlug.includes('pizza lover')

  const isRajdhani =
    decodedSlug.includes('rajdhani')

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
    decodedSlug.includes('bal udyan') ||
    decodedSlug.includes('bal-udyan') ||
    decodedSlug.includes('baludyan')

  const isRadhaRani =
    decodedSlug.includes('radha rani') ||
    decodedSlug.includes('radha-rani') ||
    decodedSlug.includes('radharani')

  const isZayka =
    decodedSlug.includes('zayka')

  const aliasOrConditions: any[] = []

  if (isHotPizzaLovers) {
    aliasOrConditions.push(
      { id: OUTLET_PIZZA_LOVERS_ID },
      { id: 'cmtn66nhy000004k0fu84b7ke' },
      { slug: { in: ['hot-pizza-lovers', 'pizza-lovers', 'pizza-lover', 'hot-pizza'] } },
      { name: { contains: 'Hot Pizza', mode: 'insensitive' as const } },
      { name: { contains: 'Pizza Lovers', mode: 'insensitive' as const } }
    )
  }

  if (isRajdhani) {
    aliasOrConditions.push(
      { slug: { contains: 'rajdhani', mode: 'insensitive' as const } },
      { name: { contains: 'Rajdhani', mode: 'insensitive' as const } }
    )
  }

  if (isAsRestaurant) {
    aliasOrConditions.push(
      { id: OUTLET_AS_RESTAURANT_ID },
      { slug: { in: ['as-cafe', 'as-restaurant', 'a-s-cafe', 'a-s-restaurant'] } },
      { name: { contains: 'A.S', mode: 'insensitive' as const } }
    )
  }

  if (isWedson) {
    aliasOrConditions.push(
      { id: OUTLET_WEDSON_ID },
      { slug: { in: ['wedson', 'wedson-restaurant', 'restaurant-kitchen'] } },
      { name: { contains: 'Wedson', mode: 'insensitive' as const } }
    )
  }

  if (isBalUdyan) {
    aliasOrConditions.push(
      { id: OUTLET_BAL_UDYAN_ID },
      { slug: { in: ['bal-udyan', 'bal-udyan-restaurant', 'baludyan'] } },
      { name: { contains: 'Bal Udyan', mode: 'insensitive' as const } }
    )
  }

  if (isRadhaRani) {
    aliasOrConditions.push(
      { id: OUTLET_RADHA_RANI_ID },
      { slug: { in: ['radha-rani', 'radha-rani-restaurant', 'radharani'] } },
      { name: { contains: 'Radha', mode: 'insensitive' as const } }
    )
  }

  if (isZayka) {
    aliasOrConditions.push(
      { id: OUTLET_ZAYKA_ID },
      { slug: { in: ['zayka', 'zayka-non-veg', 'zayka-non-veg-hotel'] } },
      { name: { contains: 'Zayka', mode: 'insensitive' as const } }
    )
  }

  if (aliasOrConditions.length > 0) {
    const aliasMatch = await prisma.restaurant.findFirst({
      where: {
        OR: aliasOrConditions,
        isActive: true,
      },
    })
    if (aliasMatch) return aliasMatch
  }

  // 3. Fallback: Prefix / StartsWith match
  const startsWithMatch = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { startsWith: slugHyphenated, mode: 'insensitive' } },
        { slug: { startsWith: decodedSlug, mode: 'insensitive' } },
        { name: { startsWith: decodedSlug, mode: 'insensitive' } },
        { name: { startsWith: slugSpaced, mode: 'insensitive' } },
      ],
      isActive: true,
    },
  })
  if (startsWithMatch) return startsWithMatch

  // 4. Final Fallback: Full contains match
  return await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { contains: slugHyphenated, mode: 'insensitive' } },
        { slug: { contains: decodedSlug, mode: 'insensitive' } },
        { name: { contains: decodedSlug, mode: 'insensitive' } },
        { name: { contains: slugSpaced, mode: 'insensitive' } },
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
