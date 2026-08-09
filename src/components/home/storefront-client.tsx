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
import { ShoppingBag, Utensils } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import { FloatingEmojis } from '@/components/shared/floating-emojis'

import { FoodEditorialCuration } from '@/components/home/food-editorial-curation'

interface StorefrontClientProps {
  categories: Category[]
  promoBanners: any[]
  flashDeals: Product[]
  bestSellers: Product[]
  topPicks: Product[]
  breakfastProducts: Product[]
  lunchProducts: Product[]
  teaProducts: Product[]
  nightProducts: Product[]
  settingsMap: Record<string, string>
  sortRules: Record<string, string>
  restaurants?: any[]
}

type ActiveTab = 'grocery' | 'food'

export function StorefrontClient({
  categories,
  promoBanners,
  flashDeals,
  bestSellers,
  topPicks,
  breakfastProducts,
  lunchProducts,
  teaProducts,
  nightProducts,
  settingsMap,
  sortRules,
  restaurants,
}: StorefrontClientProps) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const initialTab = (searchParams.get('mode') === 'food') ? 'food' : 'grocery'
  const [activeTab, setActiveTab] = useState<ActiveTab>(initialTab)

  // Scroll to top on tab change to avoid footer-jump
  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.scrollTo({ top: 0, behavior: 'instant' as any })
    }
  }, [activeTab])

  const handleTabChange = (tab: ActiveTab) => {
    triggerHaptic('medium')
    setActiveTab(tab)
    const params = new URLSearchParams(window.location.search)
    if (tab === 'grocery') {
      params.delete('mode')
    } else {
      params.set('mode', 'food')
    }
    const qs = params.toString()
    router.replace(qs ? `/?${qs}` : '/', { scroll: false })
  }

  return (
    <div className="w-full min-h-screen bg-[#fafafa] dark:bg-[#09090b] pb-28 md:pb-12 mt-3 relative">
      {/* Grocery ambient glow (red) */}
      <AnimatePresence>
        {activeTab === 'grocery' && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4 }}
            className="absolute top-0 left-0 right-0 h-[600px] overflow-hidden pointer-events-none select-none z-0"
          >
            <div
              className="absolute -top-[350px] left-1/2 -translate-x-1/2 w-[850px] h-[650px] rounded-full blur-[150px] opacity-[0.25] dark:opacity-[0.14]"
              style={{
                background: 'radial-gradient(circle, rgba(239,68,68,0.22) 0%, rgba(244,63,94,0.08) 50%, transparent 100%)'
              }}
            />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Food ambient glow (orange) */}
      <AnimatePresence>
        {activeTab === 'food' && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4 }}
            className="absolute top-0 left-0 right-0 h-[600px] overflow-hidden pointer-events-none select-none z-0"
          >
            <div
              className="absolute -top-[350px] left-1/2 -translate-x-1/2 w-[850px] h-[650px] rounded-full blur-[150px] opacity-[0.22] dark:opacity-[0.13]"
              style={{
                background: 'radial-gradient(circle, rgba(249,115,22,0.26) 0%, rgba(244,63,94,0.10) 50%, transparent 100%)'
              }}
            />
          </motion.div>
        )}
      </AnimatePresence>

      {/* Premium Grocery / Food Slider */}
      <div className="flex justify-center mt-6 sm:mt-8 mb-4 sm:mb-5 px-4">
        <div className="relative flex items-center w-full max-w-[420px] h-[60px] sm:h-[66px] p-1.5 rounded-full bg-white/80 dark:bg-zinc-950/85 backdrop-blur-xl shadow-[0_20px_50px_-15px_rgba(0,0,0,0.10),0_4px_8px_rgba(0,0,0,0.03),inset_0_1px_2px_rgba(255,255,255,0.9)] dark:shadow-[0_20px_50px_-15px_rgba(0,0,0,0.5),0_4px_8px_rgba(0,0,0,0.25),inset_0_1px_1px_rgba(255,255,255,0.06)] border border-zinc-200/50 dark:border-zinc-800/70" role="tablist" aria-label="Store mode">
          <motion.button
            onClick={() => handleTabChange('grocery')}
            whileTap={{ scale: 0.96 }}
            whileHover={activeTab === 'grocery' ? {} : { scale: 1.02 }}
            className={cn(
              "relative z-10 flex items-center justify-center gap-2.5 rounded-full cursor-pointer outline-none transition-colors duration-300 h-full flex-1 select-none border-none bg-transparent",
              activeTab === 'grocery' ? "" : "hover:text-zinc-800 dark:hover:text-zinc-200"
            )}
            aria-label="Switch to grocery mode"
            role="tab"
            aria-selected={activeTab === 'grocery'}
          >
            {activeTab === 'grocery' && (
              <motion.div
                layoutId="activePill"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#e8153a] via-[#ff2d55] to-[#ff5533] shadow-[0_8px_24px_rgba(255,26,67,0.35),0_2px_6px_rgba(255,26,67,0.15),inset_0_1px_0_rgba(255,255,255,0.25)]"
                transition={{ type: 'spring', stiffness: 380, damping: 28, mass: 0.7 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-2.5 transition-colors duration-300", activeTab === 'grocery' ? "text-white" : "text-zinc-500 dark:text-zinc-400")}>
              <ShoppingBag className="w-5 h-5 sm:w-[22px] sm:h-[22px] stroke-[2.2]" />
              <div className="flex flex-col items-start">
                <span className="text-[13px] sm:text-[14px] font-black tracking-tight leading-none">Grocery</span>
                <span className="text-[8px] sm:text-[9px] font-bold uppercase tracking-wider leading-none mt-1 opacity-85">Fast Delivery</span>
              </div>
            </div>
          </motion.button>

          {/* Divider dot */}
          <div className="w-1 h-1 rounded-full bg-zinc-300 dark:bg-zinc-700 shrink-0 z-20" />

          <motion.button
            onClick={() => handleTabChange('food')}
            whileTap={{ scale: 0.96 }}
            whileHover={activeTab === 'food' ? {} : { scale: 1.02 }}
            className={cn(
              "relative z-10 flex items-center justify-center gap-2.5 rounded-full cursor-pointer outline-none transition-colors duration-300 h-full flex-1 select-none border-none bg-transparent",
              activeTab === 'food' ? "" : "hover:text-zinc-800 dark:hover:text-zinc-200"
            )}
            aria-label="Switch to food mode"
            role="tab"
            aria-selected={activeTab === 'food'}
          >
            {activeTab === 'food' && (
              <motion.div
                layoutId="activePill"
                className="absolute inset-0 rounded-full bg-gradient-to-r from-[#ff5500] via-[#ff7700] to-[#ffaa00] shadow-[0_8px_24px_rgba(255,102,34,0.35),0_2px_6px_rgba(255,102,34,0.15),inset_0_1px_0_rgba(255,255,255,0.25)]"
                transition={{ type: 'spring', stiffness: 380, damping: 28, mass: 0.7 }}
              />
            )}
            <div className={cn("relative z-10 flex items-center gap-2.5 transition-colors duration-300", activeTab === 'food' ? "text-white" : "text-zinc-500 dark:text-zinc-400")}>
              <Utensils className="w-5 h-5 sm:w-[22px] sm:h-[22px] stroke-[2.2]" />
              <div className="flex flex-col items-start">
                <span className="text-[13px] sm:text-[14px] font-black tracking-tight leading-none">Food</span>
                <span className="text-[8px] sm:text-[9px] font-bold uppercase tracking-wider leading-none mt-1 opacity-85">Cafe & Restaurant</span>
              </div>
            </div>
          </motion.button>
        </div>
      </div>

      {/* Tab content */}
      <AnimatePresence mode="wait">
        {activeTab === 'grocery' ? (
          <motion.div
            key="grocery-content"
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -15 }}
            transition={{ duration: 0.35, ease: 'easeInOut' }}
            className="container mx-auto px-4 pt-1 flex flex-col gap-1.5 md:gap-8 max-w-7xl relative z-10 min-h-[50vh]"
          >
            <FloatingEmojis type="grocery" />
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

            {/* 4. Deals & Curations Hub */}
            <div>
              <DealsCurationHub
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
            <div>
              <DeliveryBanner />
            </div>

            {/* 6. Last Order Banner */}
            <div>
              <LastOrderBanner />
            </div>
          </motion.div>
        ) : (
          <motion.div
            key="food-content"
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -15 }}
            transition={{ duration: 0.35, ease: 'easeInOut' }}
            className="container mx-auto px-4 pt-4 flex flex-col gap-5 max-w-7xl relative z-10 min-h-[50vh]"
          >
            <FloatingEmojis type="food" />
            {/* Swiggy-style restaurant listing — banner + editorial curations + cards */}
            <FoodBanner />
            <FoodEditorialCuration />
            <RestaurantListing initialRestaurants={restaurants} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}function FoodBanner() {
  return (
    <div className="w-full overflow-hidden rounded-xl md:rounded-2xl border border-orange-500/20 shadow-xs select-none bg-gradient-to-r from-orange-600 via-rose-600 to-amber-600 text-white px-3.5 py-2.5 sm:px-5 sm:py-3 relative">
      <div className="flex items-center justify-between gap-3 relative z-10">
        {/* Left: Text & Icon */}
        <div className="flex items-center gap-2.5 min-w-0">
          <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-xl bg-white/15 backdrop-blur-md flex items-center justify-center shrink-0 border border-white/20">
            <span className="text-base sm:text-xl">🍔</span>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="text-[11px] sm:text-sm font-black tracking-tight text-white leading-tight">
                Hot Cafe &amp; Restaurant Meals
              </span>
              <span className="bg-amber-400 text-zinc-950 text-[8px] sm:text-[9.5px] font-black uppercase tracking-wider px-1.5 py-0.2 rounded-md">
                5% OFF
              </span>
            </div>
            <p className="text-[9.5px] sm:text-[11px] text-white/90 font-medium truncate mt-0.5">
              Order fresh food super fast · Use code <span className="font-black bg-white/20 px-1 py-0.2 rounded border border-dashed border-white/30 text-white">FIRST5</span>
            </p>
          </div>
        </div>

        {/* Right: Compact Badge */}
        <div className="shrink-0 hidden min-[420px]:flex items-center gap-1 bg-white/20 backdrop-blur-md border border-white/30 px-3 py-1.5 rounded-xl text-[10px] sm:text-xs font-black uppercase tracking-wider">
          <span>Explore</span>
          <span>→</span>
        </div>
      </div>
    </div>
  )
}
