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
import { Category, Product } from '@/types'

// Revalidate home page every 60 seconds to keep catalog fresh
export const revalidate = 60

export default async function Home() {
  let promoBanners: any[] = []
  let categoriesRaw: any[] = []
  let topPicksRaw: any[] = []
  let flashDealsRaw: any[] = []
  let bestSellersRaw: any[] = []

  // Fetch active banners from database
  try {
    promoBanners = await prisma.promoBanner.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    })
  } catch (error) {
    console.warn('Database connection error in home page: failed to fetch promo banners')
  }

  // 1. Fetch categories
  try {
    categoriesRaw = await prisma.category.findMany({
      orderBy: { sortOrder: 'asc' },
    })
  } catch (error) {
    console.warn('Database connection error in home page: failed to fetch categories')
  }

  // 2. Fetch Trending Items (automatically calculated based on order history quantities, fallback to 'popular' tags)
  try {
    const trendingOrderItems = await prisma.orderItem.groupBy({
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

    const trendingProductIds = trendingOrderItems.map((item) => item.productId)

    if (trendingProductIds.length > 0) {
      const orderHistoryProducts = await prisma.product.findMany({
        where: {
          id: { in: trendingProductIds },
          isAvailable: true,
        },
        include: { category: true },
      })
      // Sort in order of sales popularity
      topPicksRaw = orderHistoryProducts.sort(
        (a, b) => trendingProductIds.indexOf(a.id) - trendingProductIds.indexOf(b.id)
      )
    }
  } catch (error) {
    console.warn('Database connection error in home page: failed to calculate dynamic trending items')
  }

  // Fallback/fill: If we don't have enough dynamic trending products, pad with products tagged 'popular'
  if (topPicksRaw.length < 6) {
    const existingIds = topPicksRaw.map((p) => p.id)
    try {
      const popularProducts = await prisma.product.findMany({
        where: {
          isAvailable: true,
          tags: { has: 'popular' },
          id: { notIn: existingIds },
        },
        take: 12 - topPicksRaw.length,
        include: { category: true },
      })
      topPicksRaw = [...topPicksRaw, ...popularProducts]
    } catch (error) {
      console.warn('Database connection error in home page: failed to fetch popular fallback products')
    }
  }

  // 3. Fetch Flash Deals (Discount > 10%)
  try {
    flashDealsRaw = await prisma.product.findMany({
      where: {
        isAvailable: true,
        discount: { gt: 10 },
      },
      orderBy: { discount: 'desc' },
      take: 10,
      include: { category: true },
    })
  } catch (error) {
    console.warn('Database connection error in home page: failed to fetch flash deals')
  }

  // 4. Fetch Best Sellers
  try {
    bestSellersRaw = await prisma.product.findMany({
      where: {
        isAvailable: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 12,
      include: { category: true },
    })
  } catch (error) {
    console.warn('Database connection error in home page: failed to fetch best sellers')
  }

  // 5. Fetch smart time suggestions dynamically depending on current hour in Indian Standard Time (IST / UTC+5.5)
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

  // Fetch all matching suggestion items
  let suggestionsRaw: any[] = []
  try {
    suggestionsRaw = await prisma.product.findMany({
      where: suggestionWhereClause,
      include: { category: true },
    })
  } catch (error) {
    console.warn('Database connection error in home page: failed to fetch suggestion items')
  }

  // Sort: Put products matching explicitly desired smart tags (like 'late-night' for late-night hour) at the very front
  const preferredTag = currentHour >= 20 || currentHour < 6 ? 'late-night' : (currentHour >= 6 && currentHour < 11 ? 'breakfast' : '')
  if (preferredTag) {
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
    <div className="container mx-auto px-4 py-4 space-y-2.5 md:space-y-8 max-w-7xl">
      {/* Shop Categories Circular List */}
      <CategoryGrid categories={categories} />

      {/* Top Banner Promos */}
      <HeroBanner initialBanners={promoBanners} />

      {/* Speed ticker strip */}
      <SpeedStrip />

      {/* Your Last Order - Track active or reorder */}
      <LastOrderBanner />

      {/* Café Section (Hot & Fresh South Indian / Chinese) */}
      <CafeSection />

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

      {/* Value Proposition Grid */}
      <DeliveryBanner />

      {/* Best Sellers Grid */}
      <section className="py-2.5 md:py-6">
        <h2 className="text-xl md:text-2xl font-bold text-text-primary tracking-tight mb-2 px-1">
          Best Sellers
        </h2>
        <p className="text-sm text-text-secondary mb-6 px-1">
          Our customer favorites
        </p>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 px-1">
          {bestSellers.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </section>
    </div>
  )
}
