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
  const [activeTab, setActiveTab] = useState<'grocery' | 'food' | 'deals'>('grocery')

  useEffect(() => {
    if (modeParam === 'food' || modeParam === 'deals' || modeParam === 'grocery') {
      setActiveTab(modeParam as any)
    }
  }, [modeParam])

  const handleTabChange = (tab: 'grocery' | 'food' | 'deals') => {
    triggerHaptic('selection')
    setActiveTab(tab)
    router.replace(`/?mode=${tab}`, { scroll: false })
  }

  return (
    <div className="flex flex-col gap-3 md:gap-5 relative pb-12">
      {/* Dynamic Celebration Floating Emojis */}
      <FloatingEmojis type={activeTab === 'food' ? 'food' : 'grocery'} />

      {/* Top Header Mode Selector Switcher (3 Distinct Tabs) */}
      <div className="w-full flex items-center justify-center pt-1 pb-1 relative z-20 px-2">
        <div 
          className="relative flex items-center w-full max-w-[560px] h-[52px] sm:h-[60px] p-1.5 rounded-full bg-white/95 dark:bg-zinc-950/95 backdrop-blur-xl shadow-[0_12px_32px_-10px_rgba(0,0,0,0.1),0_2px_6px_rgba(0,0,0,0.04)] dark:shadow-[0_16px_36px_-12px_rgba(0,0,0,0.5)] border border-zinc-200/70 dark:border-zinc-800/80" 
          role="tablist" 
          aria-label="Store mode"
        >
          {/* 1. Grocery Tab */}
          <motion.button
            onClick={() => handleTabChange('grocery')}
            whileTap={{ scale: 0.96 }}
            className={cn(
              "relative z-10 flex items-center justify-center gap-1.5 sm:gap-2 rounded-full cursor-pointer outline-none transition-colors duration-300 h-full flex-1 select-none border-none bg-transparent px-1",
              activeTab === 'grocery' ? "" : "hover:text-zinc-800 dark:hover:text-zinc-200"
            )}
            role="tab"
            aria-selected={activeTab === 'grocery'}
          >
            {activeTab === 'grocery' && (
              <motion.div
                layoutId="activePill3"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#e8153a] via-[#ff2d55] to-[#ff5533] shadow-[0_6px_20px_rgba(255,26,67,0.35),inset_0_1px_0_rgba(255,255,255,0.25)]"
                transition={{ type: 'spring', stiffness: 400, damping: 30 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-1.5 sm:gap-2 transition-colors duration-300", activeTab === 'grocery' ? "text-white" : "text-zinc-500 dark:text-zinc-400")}>
              <ShoppingBag className="w-4 h-4 sm:w-5 sm:h-5 stroke-[2.2]" />
              <div className="flex flex-col items-start text-left">
                <span className="text-[12px] sm:text-[14px] font-black tracking-tight leading-none">Grocery</span>
                <span className="text-[7.5px] sm:text-[9px] font-bold uppercase tracking-wider leading-none mt-0.5 opacity-85">Mart Staples</span>
              </div>
            </div>
          </motion.button>

          {/* 2. Food Tab */}
          <motion.button
            onClick={() => handleTabChange('food')}
            whileTap={{ scale: 0.96 }}
            className={cn(
              "relative z-10 flex items-center justify-center gap-1.5 sm:gap-2 rounded-full cursor-pointer outline-none transition-colors duration-300 h-full flex-1 select-none border-none bg-transparent px-1",
              activeTab === 'food' ? "" : "hover:text-zinc-800 dark:hover:text-zinc-200"
            )}
            role="tab"
            aria-selected={activeTab === 'food'}
          >
            {activeTab === 'food' && (
              <motion.div
                layoutId="activePill3"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#ff5500] via-[#ff7700] to-[#ffaa00] shadow-[0_6px_20px_rgba(255,102,34,0.35),inset_0_1px_0_rgba(255,255,255,0.25)]"
                transition={{ type: 'spring', stiffness: 400, damping: 30 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-1.5 sm:gap-2 transition-colors duration-300", activeTab === 'food' ? "text-white" : "text-zinc-500 dark:text-zinc-400")}>
              <Utensils className="w-4 h-4 sm:w-5 sm:h-5 stroke-[2.2]" />
              <div className="flex flex-col items-start text-left">
                <span className="text-[12px] sm:text-[14px] font-black tracking-tight leading-none">Food</span>
                <span className="text-[7.5px] sm:text-[9px] font-bold uppercase tracking-wider leading-none mt-0.5 opacity-85">Cafe & Eats</span>
              </div>
            </div>
          </motion.button>

          {/* 3. Deals Tab */}
          <motion.button
            onClick={() => handleTabChange('deals')}
            whileTap={{ scale: 0.96 }}
            className={cn(
              "relative z-10 flex items-center justify-center gap-1.5 sm:gap-2 rounded-full cursor-pointer outline-none transition-colors duration-300 h-full flex-1 select-none border-none bg-transparent px-1",
              activeTab === 'deals' ? "" : "hover:text-zinc-800 dark:hover:text-zinc-200"
            )}
            role="tab"
            aria-selected={activeTab === 'deals'}
          >
            {activeTab === 'deals' && (
              <motion.div
                layoutId="activePill3"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#10b981] via-[#059669] to-[#047857] shadow-[0_6px_20px_rgba(16,185,129,0.35),inset_0_1px_0_rgba(255,255,255,0.25)]"
                transition={{ type: 'spring', stiffness: 400, damping: 30 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-1.5 sm:gap-2 transition-colors duration-300", activeTab === 'deals' ? "text-white" : "text-zinc-500 dark:text-zinc-400")}>
              <Zap className="w-4 h-4 sm:w-5 sm:h-5 stroke-[2.2] text-amber-300 fill-amber-300" />
              <div className="flex flex-col items-start text-left">
                <span className="text-[12px] sm:text-[14px] font-black tracking-tight leading-none">Offers</span>
                <span className="text-[7.5px] sm:text-[9px] font-bold uppercase tracking-wider leading-none mt-0.5 opacity-85">Flash Sales</span>
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

                {/* 4. Value Proposition Banner */}
                <div className="section-lazy-render">
                  <DeliveryBanner />
                </div>

                {/* 5. Last Order Banner */}
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
            <FoodBanner />
            {!restaurants || restaurants.length === 0 ? (
              <HubComingSoon city="Local Restaurants & Kitchens" />
            ) : (
              <RestaurantListing initialRestaurants={restaurants} />
            )}
          </motion.div>
        )}

        {/* Tab 3: DEALS & OFFERS */}
        {activeTab === 'deals' && (
          <motion.div
            key="deals-content"
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -15 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="container mx-auto px-4 pt-2 flex flex-col gap-5 sm:gap-6 md:gap-8 max-w-7xl relative z-10 min-h-[50vh]"
          >
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
