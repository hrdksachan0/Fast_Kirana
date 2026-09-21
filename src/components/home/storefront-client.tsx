'use client'

import { useState, useEffect } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import { cn } from '@/lib/utils'
import { Category, Product } from '@/types'
import { CategoryGrid } from '@/components/home/category-grid'
import { HeroArea } from '@/components/home/hero-area'
import { SpeedStrip } from '@/components/home/speed-strip'
import { CafeSection } from '@/components/home/cafe-section'
import { RestaurantListing } from '@/components/home/restaurant-listing'
import { DealsCurationHub } from '@/components/home/deals-curation-hub'
import { DeliveryBanner } from '@/components/home/delivery-banner'
import { LastOrderBanner } from '@/components/home/last-order-banner'
import { ShoppingBag, Utensils, Zap, Percent } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import { FloatingEmojis } from '@/components/shared/floating-emojis'

import { FoodEditorialCuration } from '@/components/home/food-editorial-curation'
import { HubComingSoon } from '@/components/home/hub-coming-soon'
import { CuratedBrandOffersCarousel } from '@/components/home/curated-brand-offers-carousel'

interface StorefrontClientProps {
  categories: Category[]
  promoBanners: any[]
  allGroceryProducts?: Product[]
  flashDeals: Product[]
  bestSellers: Product[]
  topPicks: Product[]
  breakfastProducts: Product[]
  lunchProducts: Product[]
  teaProducts: Product[]
  nightProducts: Product[]
  settingsMap: Record<string, string>
  restaurants?: any[]
  sortRules?: Record<string, string>
}

export function StorefrontClient({
  categories,
  promoBanners,
  allGroceryProducts = [],
  flashDeals,
  bestSellers,
  topPicks,
  breakfastProducts,
  lunchProducts,
  teaProducts,
  nightProducts,
  settingsMap,
  restaurants = [],
  sortRules = {}
}: StorefrontClientProps) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const modeParam = searchParams.get('mode')
  const [activeTab, setActiveTab] = useState<'grocery' | 'food'>('grocery')

  useEffect(() => {
    if (modeParam === 'food' || modeParam === 'grocery') {
      setActiveTab(modeParam as any)
    }
  }, [modeParam])

  const handleTabChange = (tab: 'grocery' | 'food') => {
    triggerHaptic('selection')
    setActiveTab(tab)
    router.replace(`/?mode=${tab}`, { scroll: false })
  }

  return (
    <div className="flex flex-col gap-3 md:gap-5 relative pb-12">
      {/* Dynamic Celebration Floating Emojis */}
      <FloatingEmojis type={activeTab === 'food' ? 'food' : 'grocery'} />

      {/* Ultra-Catchy Top Store Mode Switcher (Grocery vs Food) - Sticky under fixed Navbar (top-[96px] md:top-[68px]) */}
      <div className="w-full flex items-center justify-center py-2 sticky top-[96px] md:top-[68px] z-40 px-3 pointer-events-auto backdrop-blur-md">
        <div 
          className="relative flex items-center w-full max-w-[440px] h-[56px] sm:h-[62px] p-1.5 rounded-full bg-white/95 dark:bg-zinc-950/95 backdrop-blur-2xl shadow-[0_12px_36px_-8px_rgba(0,0,0,0.16),0_4px_16px_rgba(0,0,0,0.08)] dark:shadow-[0_16px_40px_-10px_rgba(0,0,0,0.8)] border-2 border-zinc-200/90 dark:border-zinc-800/90" 
          role="tablist" 
          aria-label="Store mode"
        >
          {/* 1. Grocery Tab (Fast Delivery) */}
          <motion.button
            onClick={() => handleTabChange('grocery')}
            whileTap={{ scale: 0.95 }}
            className={cn(
              "relative z-10 flex items-center justify-center rounded-full cursor-pointer outline-none transition-all duration-300 h-full flex-1 select-none border-none bg-transparent px-2",
              activeTab === 'grocery' ? "" : "hover:text-zinc-900 dark:hover:text-white"
            )}
            role="tab"
            aria-selected={activeTab === 'grocery'}
          >
            {activeTab === 'grocery' && (
              <motion.div
                layoutId="activePillCatchy"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#e8153a] via-[#ff2d55] to-[#ff5533] shadow-[0_6px_24px_rgba(232,21,58,0.45),inset_0_1px_1px_rgba(255,255,255,0.4)]"
                transition={{ type: 'spring', stiffness: 450, damping: 28 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-2.5 transition-colors duration-300", activeTab === 'grocery' ? "text-white" : "text-zinc-600 dark:text-zinc-400")}>
              <div className={cn(
                "w-8 h-8 sm:w-9 sm:h-9 rounded-full flex items-center justify-center shrink-0 transition-transform duration-300",
                activeTab === 'grocery' ? "bg-white/20 backdrop-blur-md border border-white/30 scale-105" : "bg-zinc-100 dark:bg-zinc-900"
              )}>
                <ShoppingBag className="w-4.5 h-4.5 sm:w-5 sm:h-5 stroke-[2.4]" />
              </div>
              <div className="flex flex-col items-start text-left">
                <div className="flex items-center gap-1">
                  <span className="text-[13px] sm:text-[15px] font-black tracking-tight leading-none">Grocery</span>
                  {activeTab === 'grocery' && (
                    <span className="bg-white/25 border border-white/30 text-white text-[8px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded-full leading-none">
                      10-MIN
                    </span>
                  )}
                </div>
                <span className="text-[8px] sm:text-[9.5px] font-extrabold uppercase tracking-wider leading-none mt-1 opacity-90">
                  ⚡ Fast Delivery
                </span>
              </div>
            </div>
          </motion.button>

          {/* 2. Food Tab (Cafe & Restaurant) */}
          <motion.button
            onClick={() => handleTabChange('food')}
            whileTap={{ scale: 0.95 }}
            className={cn(
              "relative z-10 flex items-center justify-center rounded-full cursor-pointer outline-none transition-all duration-300 h-full flex-1 select-none border-none bg-transparent px-2",
              activeTab === 'food' ? "" : "hover:text-zinc-900 dark:hover:text-white"
            )}
            role="tab"
            aria-selected={activeTab === 'food'}
          >
            {activeTab === 'food' && (
              <motion.div
                layoutId="activePillCatchy"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#ff4500] via-[#ff6600] to-[#ffa500] shadow-[0_6px_24px_rgba(255,69,0,0.45),inset_0_1px_1px_rgba(255,255,255,0.4)]"
                transition={{ type: 'spring', stiffness: 450, damping: 28 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-2.5 transition-colors duration-300", activeTab === 'food' ? "text-white" : "text-zinc-600 dark:text-zinc-400")}>
              <div className={cn(
                "w-8 h-8 sm:w-9 sm:h-9 rounded-full flex items-center justify-center shrink-0 transition-transform duration-300",
                activeTab === 'food' ? "bg-white/20 backdrop-blur-md border border-white/30 scale-105" : "bg-zinc-100 dark:bg-zinc-900"
              )}>
                <Utensils className="w-4.5 h-4.5 sm:w-5 sm:h-5 stroke-[2.4]" />
              </div>
              <div className="flex flex-col items-start text-left">
                <div className="flex items-center gap-1">
                  <span className="text-[13px] sm:text-[15px] font-black tracking-tight leading-none">Food</span>
                  {activeTab === 'food' && (
                    <span className="bg-white/25 border border-white/30 text-white text-[8px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded-full leading-none">
                      HOT CAFES
                    </span>
                  )}
                </div>
                <span className="text-[8px] sm:text-[9.5px] font-extrabold uppercase tracking-wider leading-none mt-1 opacity-90">
                  🍳 Cafe & Dining
                </span>
              </div>
            </div>
          </motion.button>
        </div>
      </div>

      {/* Tab Content Views */}
      <AnimatePresence mode="wait">
        {/* Tab 1: GROCERY */}
        {activeTab === 'grocery' && (
          <motion.div
            key="grocery-content"
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -15 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="container mx-auto px-4 pt-2 flex flex-col gap-5 sm:gap-6 md:gap-8 max-w-7xl relative z-10 min-h-[50vh]"
          >
            {allGroceryProducts.length === 0 ? (
              <HubComingSoon />
            ) : (
              <>
                {/* 1. Hero Banners */}
                <div>
                  <HeroArea initialBanners={promoBanners} />
                </div>

                {/* 2. Trending Categories */}
                <div>
                  <CategoryGrid categories={categories} />
                </div>

                {/* 3. Speed Strip */}
                <div>
                  <SpeedStrip
                    avgDelivery={settingsMap.avg_delivery_time}
                    deliveredCount={settingsMap.delivered_today}
                    freshStock={settingsMap.fresh_stock_loaded}
                    happyFamilies={settingsMap.happy_families}
                  />
                </div>

                {/* 4. Deals & Curations Hub (Products & Curated For You) */}
                <div className="section-lazy-render">
                  <DealsCurationHub
                    categories={categories}
                    allProducts={allGroceryProducts}
                    flashDeals={flashDeals}
                    bestSellers={bestSellers}
                    topPicks={topPicks}
                    breakfastProducts={breakfastProducts}
                    lunchProducts={lunchProducts}
                    teaProducts={teaProducts}
                    nightProducts={nightProducts}
                    sortRules={sortRules}
                  />
                </div>

                {/* 5. Value Proposition Banner */}
                <div className="section-lazy-render">
                  <DeliveryBanner />
                </div>

                {/* 6. Last Order Banner */}
                <div className="section-lazy-render">
                  <LastOrderBanner />
                </div>
              </>
            )}
          </motion.div>
        )}

        {/* Tab 2: FOOD */}
        {activeTab === 'food' && (
          <motion.div
            key="food-content"
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -15 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="container mx-auto px-4 pt-4 flex flex-col gap-5 max-w-7xl relative z-10 min-h-[50vh]"
          >
            <CuratedBrandOffersCarousel initialBanners={promoBanners} mode="food" sectionTitle="Trending Restaurant & Cafe Specials" />
            {!restaurants || restaurants.length === 0 ? (
              <HubComingSoon city="Local Restaurants & Kitchens" />
            ) : (
              <RestaurantListing initialRestaurants={restaurants} />
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

function FoodBanner() {
  return (
    <div className="w-full overflow-hidden rounded-[24px] border border-white/10 dark:border-white/5 bg-gradient-to-r from-amber-500 via-primary to-rose-700 text-white px-4.5 py-4 sm:px-6 sm:py-5 relative shadow-[0_12px_36px_-12px_rgba(226,10,34,0.18)] select-none">
      {/* Dynamic Glass Glow Layers */}
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_30%,rgba(255,255,255,0.15),transparent_45%)] pointer-events-none" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_85%_75%,rgba(251,191,36,0.15),transparent_40%)] pointer-events-none" />
      
      {/* Decorative clean line accents */}
      <div className="absolute -top-10 -left-10 w-24 h-24 rounded-full border border-white/10 pointer-events-none" />
      <div className="absolute -bottom-10 -right-10 w-32 h-32 rounded-full border border-white/5 pointer-events-none" />

      <div className="flex items-center justify-between gap-4 relative z-10">
        <div className="flex items-center gap-3.5 min-w-0">
          {/* Glowing hot food badge */}
          <div className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-white/20 backdrop-blur-md border border-white/25 flex items-center justify-center shrink-0 shadow-md">
            <span className="text-xl sm:text-2xl">🍔</span>
          </div>

          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="bg-amber-400 text-amber-950 text-[8.5px] sm:text-[9.5px] font-black uppercase tracking-widest px-2 py-0.5 rounded-md shadow-xs">
                ⚡ SPECIAL CAFE
              </span>
              <span className="text-[10px] font-bold text-orange-100 flex items-center gap-1">
                • FastKirana Kitchen
              </span>
            </div>
            <h3 className="text-sm sm:text-[16px] font-black text-white tracking-tight mt-1 leading-snug drop-shadow-xs">
              Tasty &amp; delicious food delivered by Fastkirana
            </h3>
            <p className="text-[10.5px] text-orange-50/90 font-medium mt-0.5">
              “Good food is good mood” • Freshly prepared &amp; delivered in minutes
            </p>
          </div>
        </div>

        {/* Explore Button */}
        <div className="shrink-0 hidden min-[440px]:flex items-center gap-1.5 bg-white text-primary hover:bg-orange-50 px-4 py-2.5 rounded-2xl text-[10.5px] font-black uppercase tracking-wider shadow-md transition-all active:scale-95 cursor-pointer select-none">
          <span>Explore</span>
          <span>→</span>
        </div>
      </div>
    </div>
  )
}
