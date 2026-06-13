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
import { Category, Product } from '@/types'
import Link from 'next/link'

// Revalidate home page every 60 seconds to keep catalog fresh
export const revalidate = 60

export default async function Home() {
  let promoBanners: any[] = []
  let categoriesRaw: any[] = []
  let trendingOrderItems: any[] = []
  let flashDealsRaw: any[] = []
  let bestSellersRaw: any[] = []
  let suggestionsRaw: any[] = []
  let topPicksRaw: any[] = []

  // 1. Fetch smart time suggestions dynamically depending on current hour in Indian Standard Time (IST / UTC+5.5)
  const istOffset = 5.5 * 60 * 60 * 1000
  const serverTime = new Date()
  const istTime = new Date(serverTime.getTime() + (serverTime.getTimezoneOffset() * 60000) + istOffset)
  const currentHour = istTime.getHours()

  let suggestionWhereClause: any = { isAvailable: true }

  if (currentHour >= 6 && currentHour < 11) {
    // Breakfast Essentials: dairy-breakfast category or breakfast/dairy tags
    suggestionWhereClause = {
      isAvailable: true,
      OR: [
        { tags: { has: 'breakfast' } },
        { tags: { has: 'dairy' } },
        { category: { slug: 'dairy-breakfast' } },
      ],
    }
  } else if (currentHour >= 11 && currentHour < 16) {
    // Lunch Time Picks: staples or atta-rice-dal category
    suggestionWhereClause = {
      isAvailable: true,
      OR: [
        { tags: { has: 'staples' } },
        { category: { slug: 'atta-rice-dal' } },
      ],
    }
  } else if (currentHour >= 16 && currentHour < 20) {
    // Snack O'Clock: snacks/munchies category or snacks tag
    suggestionWhereClause = {
      isAvailable: true,
      OR: [
        { tags: { has: 'snacks' } },
        { category: { slug: 'snacks-munchies' } },
      ],
    }
  } else {
    // Late Night Cravings (8 PM - 5 AM): Admin explicitly marked 'late-night' tag, or category/tag fallbacks
    suggestionWhereClause = {
      isAvailable: true,
      OR: [
        { tags: { has: 'late-night' } }, // Admin explicitly selected night craving items
        { tags: { has: 'snacks' } },
        { tags: { has: 'beverages' } },
        { category: { slug: 'snacks-munchies' } },
        { category: { slug: 'beverages' } },
      ],
    }
  }

  // Ensure Cafe items do not leak into general grocery suggestions
  suggestionWhereClause.NOT = [
    { tags: { has: 'cafe' } },
    { category: { slug: 'cafe' } },
  ]

  // 2. Fetch independent data pools in parallel to eliminate database sequential waterfall latency
  try {
    const [
      bannersRes,
      categoriesRes,
      trendingRes,
      flashRes,
      sellersRes,
      suggestionsRes,
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
          NOT: [
            { tags: { has: 'cafe' } },
            { category: { slug: 'cafe' } },
          ]
        },
        orderBy: [
          { isFlashDeal: 'desc' },
          { discount: 'desc' }
        ],
        take: 10,
        include: { category: true },
      }).catch((err) => { console.warn('Failed to fetch flash deals:', err); return []; }),
      prisma.product.findMany({
        where: {
          isAvailable: true,
          NOT: [
            { tags: { has: 'cafe' } },
            { category: { slug: 'cafe' } },
          ]
        },
        orderBy: [
          { isBestSeller: 'desc' },
          { createdAt: 'desc' }
        ],
        take: 12,
        include: { category: true },
      }).catch((err) => { console.warn('Failed to fetch best sellers:', err); return []; }),
      prisma.product.findMany({
        where: suggestionWhereClause,
        include: { category: true },
      }).catch((err) => { console.warn('Failed to fetch time suggestions:', err); return []; }),
    ])

    promoBanners = bannersRes
    categoriesRaw = categoriesRes
    trendingOrderItems = trendingRes
    flashDealsRaw = flashRes
    bestSellersRaw = sellersRes
    suggestionsRaw = suggestionsRes
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
      include: { category: true },
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
        include: { category: true },
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
        include: { category: true },
      })
      topPicksRaw = [...topPicksRaw, ...popularProducts]
    } catch (error) {
      console.warn('Database error in home page: failed to fetch popular fallback products', error)
    }
  }

  // Sort suggestions: Put products matching preferred tag first
  const preferredTag = currentHour >= 20 || currentHour < 6 ? 'late-night' : (currentHour >= 6 && currentHour < 11 ? 'breakfast' : '')
  if (preferredTag && suggestionsRaw.length > 0) {
    suggestionsRaw.sort((a: any, b: any) => {
      const aPref = a.tags.includes(preferredTag) ? 1 : 0
      const bPref = b.tags.includes(preferredTag) ? 1 : 0
      return bPref - aPref // 1 comes before 0
    })
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
  const suggestionProducts = suggestionsRaw.slice(0, 15).map(mapProduct)

  return (
    <div className="container mx-auto px-4 pt-3 pb-0 space-y-1.5 md:space-y-8 max-w-7xl">
      {/* Shop Categories Circular List */}
      <CategoryGrid categories={categories} />

      {/* Top Banner Promos */}
      <HeroBanner initialBanners={promoBanners} />

      {/* Speed ticker strip */}
      <SpeedStrip />

      {/* Cafe Banner - Quick Link */}
      <Link href="/cafe" className="block group">
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-amber-900 via-amber-800 to-rose-900 p-4 md:p-5 flex items-center justify-between shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.01]">
          <div className="flex items-center gap-3">
            <span className="text-3xl md:text-4xl">☕</span>
            <div>
              <h3 className="text-white font-extrabold text-sm md:text-base tracking-tight">FastKirana Café</h3>
              <p className="text-amber-200/80 text-[10px] md:text-xs font-medium">Fresh sandwiches, pasta, shakes & more — order now!</p>
            </div>
          </div>
          <div className="flex items-center gap-1.5 bg-white/15 backdrop-blur-sm px-3 py-1.5 rounded-xl border border-white/20 group-hover:bg-white/25 transition-all">
            <span className="text-white text-xs font-bold hidden sm:inline">Explore Menu</span>
            <span className="text-white text-xs font-bold sm:hidden">Menu</span>
            <svg className="w-4 h-4 text-white group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" /></svg>
          </div>
          {/* Decorative circles */}
          <div className="absolute -top-6 -right-6 w-20 h-20 bg-white/5 rounded-full" />
          <div className="absolute -bottom-4 -left-4 w-16 h-16 bg-white/5 rounded-full" />
        </div>
      </Link>

      {/* Your Last Order - Track active or reorder */}
      <LastOrderBanner />

      {/* Flash Deals Row */}
      <ProductScrollSection
        title="Flash Deals"
        subtitle="Instant discounts on daily cravings"
        products={flashDeals}
        rightElement={
          <div key="flash-deals-countdown-timer" className="flex items-center gap-2">
            <span className="text-xs font-bold text-text-secondary">Ends in:</span>
            <CountdownTimer />
          </div>
        }
      />

      {/* Contextual Time of Day Suggestions */}
      <TimeSuggestions products={suggestionProducts} />

      {/* Trending in Town with Social Proof */}
      <TrendingSection products={topPicks} />

      {/* Top Picks Row */}
      <ProductScrollSection
        title="Top Picks"
        subtitle="Highly rated and popular in your neighborhood"
        products={topPicks}
      />

      {/* Best Sellers Grid */}
      <section className="py-2.5 md:py-6">
        <h2 className="text-lg md:text-2xl font-bold text-text-primary tracking-tight mb-2 px-1">
          Best Sellers
        </h2>
        <p className="text-xs md:text-sm text-text-secondary mb-3 md:mb-6 px-1">
          Our customer favorites
        </p>
        <div className="grid grid-cols-2 min-[375px]:grid-cols-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 px-1">
          {bestSellers.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>

      {/* Value Proposition Grid */}
      <DeliveryBanner />
    </div>
  )
}
