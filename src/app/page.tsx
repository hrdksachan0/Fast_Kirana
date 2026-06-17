import { prisma } from '@/lib/prisma'
import { HeroBanner } from '@/components/home/hero-banner'
import { CategoryGrid } from '@/components/home/category-grid'
import { DeliveryBanner } from '@/components/home/delivery-banner'
import { ProductScrollSection } from '@/components/product/product-scroll-section'
import { ProductCard } from '@/components/product/product-card'
import { CountdownTimer } from '@/components/shared/countdown-timer'
import { LastOrderBanner } from '@/components/home/last-order-banner'
import { TimeSuggestions } from '@/components/home/time-suggestions'
import { TrendingSection } from '@/components/home/trending-section'
import { SpeedStrip } from '@/components/home/speed-strip'
import { CafeSection } from '@/components/home/cafe-section'
import { DealsCurationHub } from '@/components/home/deals-curation-hub'
import { Category, Product } from '@/types'
import { FlashDealsBanner } from '@/components/home/flash-deals-banner'
import Link from 'next/link'

// Revalidate home page every 24 hours (on-demand revalidation handles updates)
export const revalidate = 86400

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

  // 2. Fetch independent data pools in parallel to eliminate database sequential waterfall latency
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
    ] = await Promise.all([
      prisma.promoBanner.findMany({
        where: { isActive: true },
        orderBy: { sortOrder: 'asc' },
      }).catch((err) => { console.warn('Failed to fetch promo banners:', err); return []; }),
      prisma.category.findMany({
        orderBy: { sortOrder: 'asc' },
        include: {
          _count: {
            select: { products: true },
          },
        },
      }).catch((err) => { console.warn('Failed to fetch categories:', err); return []; }),
      prisma.orderItem.groupBy({
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
      }).catch((err) => { console.warn('Failed to fetch trending order items:', err); return []; }),
      prisma.product.findMany({
        where: {
          isAvailable: true,
          OR: [
            { isFlashDeal: true },
            { discount: { gt: 10 } }
          ],
        },
        orderBy: [
          { isFlashDeal: 'desc' },
          { discount: 'desc' }
        ],
        take: 48,
        select: productSelect,
      }).catch((err) => { console.warn('Failed to fetch flash deals:', err); return []; }),
      prisma.product.findMany({
        where: {
          isAvailable: true,
        },
        orderBy: [
          { isBestSeller: 'desc' },
          { createdAt: 'desc' }
        ],
        take: 48,
        select: productSelect,
      }).catch((err) => { console.warn('Failed to fetch best sellers:', err); return []; }),
      prisma.product.findMany({
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
      }).catch((err) => { console.warn('Failed to fetch breakfast deals:', err); return []; }),
      prisma.product.findMany({
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
      }).catch((err) => { console.warn('Failed to fetch lunch deals:', err); return []; }),
      prisma.product.findMany({
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
      }).catch((err) => { console.warn('Failed to fetch tea deals:', err); return []; }),
      prisma.product.findMany({
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
      }).catch((err) => { console.warn('Failed to fetch night cravings:', err); return []; }),
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
  } catch (error) {
    console.error('Failed to execute parallel queries on home page:', error)
  }

  // 3. Process Top Picks: Load manually pinned top picks first, then append dynamic sales trending
  let manualTopPicks: any[] = []
  try {
    manualTopPicks = await prisma.product.findMany({
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
  } catch (err) {
    console.warn('Failed to load manual top picks:', err)
  }

  const trendingProductIds = trendingOrderItems.map((item) => item.productId).filter((id): id is string => id !== null)
  let dynamicTopPicks: any[] = []
  if (trendingProductIds.length > 0) {
    try {
      const orderHistoryProducts = await prisma.product.findMany({
        where: {
          id: { in: trendingProductIds },
          isAvailable: true,
          NOT: [
            { tags: { has: 'cafe' } },
            { category: { slug: 'cafe' } },
          ]
        },
        select: productSelect,
      })
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

  // Fallback/fill: If we don't have enough dynamic trending products, pad with products tagged 'popular'
  if (topPicksRaw.length < 6) {
    const existingIds = topPicksRaw.map((p) => p.id)
    try {
      const popularProducts = await prisma.product.findMany({
        where: {
          isAvailable: true,
          tags: { has: 'popular' },
          id: { notIn: existingIds },
          NOT: [
            { tags: { has: 'cafe' } },
            { category: { slug: 'cafe' } },
          ]
        },
        take: 12 - topPicksRaw.length,
        select: productSelect,
      })
      topPicksRaw = [...topPicksRaw, ...popularProducts]
    } catch (error) {
      console.warn('Database error in home page: failed to fetch popular fallback products', error)
    }
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

  return (
    <div className="container mx-auto px-4 pt-3 pb-0 space-y-1.5 md:space-y-8 max-w-7xl">
      {/* Shop Categories Circular List */}
      <CategoryGrid categories={categories} />

      {/* Top Banner Promos */}
      <HeroBanner initialBanners={promoBanners} />

      {/* Speed ticker strip */}
      <SpeedStrip />

      {/* Cafe Banner with sliding menu categories */}
      <CafeSection />

      {/* Your Last Order - Track active or reorder */}
      <LastOrderBanner />

      {/* Deals & Curations Hub */}
      <DealsCurationHub
        flashDeals={flashDeals}
        bestSellers={bestSellers}
        topPicks={topPicks}
        breakfastProducts={breakfastProducts}
        lunchProducts={lunchProducts}
        teaProducts={teaProducts}
        nightProducts={nightProducts}
      />

      <FlashDealsBanner />

      {/* Trending in Town with Social Proof */}
      <TrendingSection products={topPicks} />

      {/* Top Picks Row */}
      <ProductScrollSection
        title="Top Picks"
        subtitle="Highly rated and popular in your neighborhood"
        products={topPicks}
      />

      {/* Value Proposition Grid */}
      <DeliveryBanner />
    </div>
  )
}
