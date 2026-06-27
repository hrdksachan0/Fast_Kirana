import { prisma } from '@/lib/prisma'
import { HeroArea } from '@/components/home/hero-area'
import { CategoryGrid } from '@/components/home/category-grid'
import { DeliveryBanner } from '@/components/home/delivery-banner'
import { ProductCard } from '@/components/product/product-card'
import { CountdownTimer } from '@/components/shared/countdown-timer'
import { LastOrderBanner } from '@/components/home/last-order-banner'
import { TimeSuggestions } from '@/components/home/time-suggestions'
import { SpeedStrip } from '@/components/home/speed-strip'
import { CafeSection } from '@/components/home/cafe-section'
import { DealsCurationHub } from '@/components/home/deals-curation-hub'
import { Category, Product } from '@/types'
import Link from 'next/link'

import { unstable_cache } from 'next/cache'

// Revalidate home page every 24 hours (on-demand revalidation handles updates)
export const revalidate = 86400

const productSelect = {
  id: true,
  name: true,
  slug: true,
  description: true,
  imageUrl: true,
  categoryId: true,
  mrp: true,
  price: true,
  discount: true,
  unit: true,
  stock: true,
  isAvailable: true,
  tags: true,
  minStock: true,
  variants: true,
  category: {
    select: {
      id: true,
      name: true,
      slug: true,
      imageUrl: true,
      parentId: true,
      sortOrder: true,
    }
  }
}

// ── Cache Functions to Prevent Heavy Database Queries ──

const getCachedBanners = unstable_cache(
  async () => {
    return prisma.promoBanner.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    })
  },
  ['storefront-banners'],
  { revalidate: 3600, tags: ['banners'] }
)

const getCachedCategories = unstable_cache(
  async () => {
    return prisma.category.findMany({
      orderBy: { sortOrder: 'asc' },
      include: {
        _count: {
          select: { products: true },
        },
      },
    })
  },
  ['storefront-categories'],
  { revalidate: 3600, tags: ['categories'] }
)

const getCachedTrendingOrderItems = unstable_cache(
  async () => {
    return prisma.orderItem.groupBy({
      by: ['productId'],
      _sum: {
        quantity: true,
      },
      orderBy: {
        _sum: {
          quantity: 'desc',
        },
      },
      take: 12,
    })
  },
  ['storefront-trending-order-items'],
  { revalidate: 3600, tags: ['trending'] }
)

const getCachedFlashDeals = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
        OR: [
          { isFlashDeal: true },
          { discount: { gt: 10 } }
        ]
      },
      orderBy: [
        { isFlashDeal: 'desc' },
        { discount: 'desc' }
      ],
      take: 400,
      select: productSelect,
    })
  },
  ['storefront-flash-deals'],
  { revalidate: 3600, tags: ['products', 'flash-deals'] }
)

const getCachedBestSellers = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
      },
      orderBy: [
        { isBestSeller: 'desc' },
        { createdAt: 'desc' }
      ],
      take: 400,
      select: productSelect,
    })
  },
  ['storefront-best-sellers'],
  { revalidate: 3600, tags: ['products', 'best-sellers'] }
)

const getCachedBreakfastDeals = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
        OR: [
          { tags: { has: 'breakfast' } },
          { tags: { has: 'dairy' } },
          { category: { slug: 'dairy-breakfast' } },
        ],
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } },
        ],
      },
      take: 16,
      select: productSelect,
    })
  },
  ['storefront-breakfast-deals'],
  { revalidate: 3600, tags: ['products', 'breakfast-deals'] }
)

const getCachedLunchDeals = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
        OR: [
          { tags: { has: 'staples' } },
          { category: { slug: 'atta-rice-dal' } },
        ],
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } },
        ],
      },
      take: 16,
      select: productSelect,
    })
  },
  ['storefront-lunch-deals'],
  { revalidate: 3600, tags: ['products', 'lunch-deals'] }
)

const getCachedTeaDeals = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
        OR: [
          { tags: { has: 'snacks' } },
          { category: { slug: 'snacks-munchies' } },
        ],
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } },
        ],
      },
      take: 16,
      select: productSelect,
    })
  },
  ['storefront-tea-deals'],
  { revalidate: 3600, tags: ['products', 'tea-deals'] }
)

const getCachedNightCravings = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
        OR: [
          { category: { slug: { in: ['cafe', 'beverages', 'ice-cream'] } } },
          { tags: { hasSome: ['snacks', 'drinks', 'dessert', 'ice-cream', 'midnight', 'munchies', 'fastfood', 'late-night'] } }
        ]
      },
      orderBy: [
        { isBestSeller: 'desc' },
        { createdAt: 'desc' }
      ],
      take: 24,
      select: productSelect,
    })
  },
  ['storefront-night-cravings'],
  { revalidate: 3600, tags: ['products', 'night-cravings'] }
)

const getCachedStoreSettings = unstable_cache(
  async () => {
    return prisma.storeSetting.findMany({
      where: {
        key: {
          in: ['avg_delivery_time', 'delivered_today', 'fresh_stock_loaded', 'happy_families']
        }
      }
    })
  },
  ['storefront-settings'],
  { revalidate: 3600, tags: ['settings'] }
)

const getCachedManualTopPicks = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isTopPick: true,
        isAvailable: true,
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } },
        ]
      },
      select: productSelect,
    })
  },
  ['storefront-manual-top-picks'],
  { revalidate: 3600, tags: ['products', 'top-picks'] }
)

const getCachedProductsByIds = unstable_cache(
  async (ids: string[]) => {
    if (ids.length === 0) return []
    return prisma.product.findMany({
      where: {
        id: { in: ids },
        isAvailable: true,
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } },
        ]
      },
      select: productSelect,
    })
  },
  ['storefront-products-by-ids'],
  { revalidate: 3600, tags: ['products'] }
)

const getCachedPopularProducts = unstable_cache(
  async () => {
    return prisma.product.findMany({
      where: {
        isAvailable: true,
        tags: { has: 'popular' },
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } },
        ]
      },
      take: 12,
      select: productSelect,
    })
  },
  ['storefront-popular-products'],
  { revalidate: 3600, tags: ['products', 'popular-products'] }
)

export default async function Home() {
  let promoBanners: any[] = []
  let categoriesRaw: any[] = []
  let trendingOrderItems: any[] = []
  let flashDealsRaw: any[] = []
  let bestSellersRaw: any[] = []
  let topPicksRaw: any[] = []
  let breakfastRaw: any[] = []
  let lunchRaw: any[] = []
  let teaRaw: any[] = []
  let nightRaw: any[] = []
  let settingsRaw: any[] = []

  // Fetch independent data pools in parallel using cached functions to avoid sequence waterfalls and DB load
  let manualTopPicks: any[] = []
  let popularProducts: any[] = []

  try {
    const [
      bannersRes,
      categoriesRes,
      trendingRes,
      flashRes,
      sellersRes,
      breakfastRes,
      lunchRes,
      teaRes,
      nightRes,
      settingsRes,
      manualTopPicksRes,
      popularProductsRes,
    ] = await Promise.all([
      getCachedBanners(),
      getCachedCategories(),
      getCachedTrendingOrderItems(),
      getCachedFlashDeals(),
      getCachedBestSellers(),
      getCachedBreakfastDeals(),
      getCachedLunchDeals(),
      getCachedTeaDeals(),
      getCachedNightCravings(),
      getCachedStoreSettings(),
      getCachedManualTopPicks(),
      getCachedPopularProducts(),
    ])

    promoBanners = bannersRes
    categoriesRaw = categoriesRes
    trendingOrderItems = trendingRes
    flashDealsRaw = flashRes
    bestSellersRaw = sellersRes
    breakfastRaw = breakfastRes
    lunchRaw = lunchRes
    teaRaw = teaRes
    nightRaw = nightRes
    settingsRaw = settingsRes
    manualTopPicks = manualTopPicksRes
    popularProducts = popularProductsRes
  } catch (error) {
    console.error('Failed to execute parallel queries on home page:', error)
  }

  const trendingProductIds = trendingOrderItems.map((item) => item.productId).filter((id): id is string => id !== null)
  let dynamicTopPicks: any[] = []
  if (trendingProductIds.length > 0) {
    try {
      const orderHistoryProducts = await getCachedProductsByIds(trendingProductIds)
      // Sort in order of sales popularity
      dynamicTopPicks = orderHistoryProducts.sort(
        (a, b) => trendingProductIds.indexOf(a.id) - trendingProductIds.indexOf(b.id)
      )
    } catch (error) {
      console.warn('Database error in home page: failed to load dynamic trending product list', error)
    }
  }

  // Combine manual and dynamic trending (without duplicates)
  const manualIds = new Set(manualTopPicks.map(p => p.id))
  topPicksRaw = [
    ...manualTopPicks,
    ...dynamicTopPicks.filter(p => !manualIds.has(p.id))
  ]

  // Fallback/fill: If we don't have enough dynamic trending products, pad with popular fallback products from cache
  if (topPicksRaw.length < 6) {
    const existingIds = topPicksRaw.map((p) => p.id)
    const remainingPopular = popularProducts.filter(p => !existingIds.includes(p.id))
    topPicksRaw = [...topPicksRaw, ...remainingPopular.slice(0, 12 - topPicksRaw.length)]
  }

  // Map database categories to UI schema
  const categories: Category[] = categoriesRaw.map((c) => ({
    id: c.id,
    name: c.name,
    slug: c.slug,
    imageUrl: c.imageUrl,
    parentId: c.parentId,
    sortOrder: c.sortOrder,
    _count: c._count,
  }))

  const mapProduct = (p: any): Product => ({
    id: p.id,
    name: p.name,
    slug: p.slug,
    description: p.description,
    imageUrl: p.imageUrl,
    categoryId: p.categoryId,
    mrp: p.mrp,
    price: p.price,
    discount: p.discount,
    unit: p.unit,
    stock: p.stock,
    isAvailable: p.isAvailable,
    tags: p.tags,
    minStock: p.minStock,
    variants: p.variants,
    category: p.category ? {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
      imageUrl: p.category.imageUrl,
      parentId: p.category.parentId,
      sortOrder: p.category.sortOrder,
    } : undefined,
  })

  const topPicks = topPicksRaw.map(mapProduct)
  const flashDeals = flashDealsRaw.map(mapProduct)
  const bestSellers = bestSellersRaw.map(mapProduct)
  const breakfastProducts = breakfastRaw.map(mapProduct)
  const lunchProducts = lunchRaw.map(mapProduct)
  const teaProducts = teaRaw.map(mapProduct)
  const nightProducts = nightRaw.map(mapProduct)

  const settingsMap: Record<string, string> = {
    avg_delivery_time: '8 min',
    delivered_today: '1,231+',
    fresh_stock_loaded: '2 hrs ago',
    happy_families: '5,000+',
  }
  settingsRaw.forEach((s) => {
    settingsMap[s.key] = s.value
  })

  return (
    <div className="container mx-auto px-4 pt-3 pb-0 flex flex-col gap-1.5 md:gap-8 max-w-7xl">
      {/* 1. Trending Categories (order-1) */}
      <div className="order-1 md:order-1">
        <CategoryGrid categories={categories} />
      </div>

      {/* 2. Cafe Section (order-2) */}
      <div className="order-2 md:order-2">
        <CafeSection />
      </div>

      {/* 3. Greeting Card & Hero Banners (order-3) */}
      <div className="order-3 md:order-3">
        <HeroArea initialBanners={promoBanners} />
      </div>

      {/* 4. Branding Speed Ticker Strip (order-4) */}
      <div className="order-4 md:order-4">
        <SpeedStrip
          avgDelivery={settingsMap.avg_delivery_time}
          deliveredCount={settingsMap.delivered_today}
          freshStock={settingsMap.fresh_stock_loaded}
          happyFamilies={settingsMap.happy_families}
        />
      </div>

      {/* 5. Menu / Deals & Curations Hub (order-5) */}
      <div className="order-5 md:order-5">
        <DealsCurationHub
          flashDeals={flashDeals}
          bestSellers={bestSellers}
          topPicks={topPicks}
          breakfastProducts={breakfastProducts}
          lunchProducts={lunchProducts}
          teaProducts={teaProducts}
          nightProducts={nightProducts}
        />
      </div>

      {/* 6. Branding Value Proposition Banner (order-6) */}
      <div className="order-6 md:order-6">
        <DeliveryBanner />
      </div>

      {/* 7. Your Last Order (order-7) */}
      <div className="order-7 md:order-7">
        <LastOrderBanner />
      </div>
    </div>
  )
}
