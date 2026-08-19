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
      window.scrollTo({ top: 0, behavior: 'smooth' })
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
      {/* Grocery ambient glow (lightweight CSS) */}
      <AnimatePresence>
        {activeTab === 'grocery' && (
          <div className="absolute top-0 left-0 right-0 h-[380px] bg-gradient-to-b from-red-500/[0.06] via-rose-500/[0.02] to-transparent pointer-events-none select-none z-0" />
        )}
      </AnimatePresence>

      {/* Food ambient glow (lightweight CSS) */}
      <AnimatePresence>
        {activeTab === 'food' && (
          <div className="absolute top-0 left-0 right-0 h-[380px] bg-gradient-to-b from-amber-500/[0.07] via-orange-500/[0.02] to-transparent pointer-events-none select-none z-0" />
        )}
      </AnimatePresence>

      {/* Premium Sticky Grocery / Food Slider */}
      <div className="sticky top-[90px] md:top-[64px] z-40 bg-[#fafafa]/95 dark:bg-[#09090b]/95 backdrop-blur-xl py-1.5 px-4 flex justify-center transition-all duration-300 border-b border-zinc-200/40 dark:border-zinc-800/40 shadow-xs mb-3 sm:mb-4">
        <div className="relative flex items-center w-full max-w-[420px] h-[56px] sm:h-[62px] p-1.5 rounded-full bg-white/90 dark:bg-zinc-950/90 backdrop-blur-xl shadow-[0_16px_36px_-12px_rgba(0,0,0,0.08),0_4px_8px_rgba(0,0,0,0.03)] dark:shadow-[0_16px_36px_-12px_rgba(0,0,0,0.4)] border border-zinc-200/60 dark:border-zinc-800/70" role="tablist" aria-label="Store mode">
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
            <div className="section-lazy-render">
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
            <div className="section-lazy-render">
              <DeliveryBanner />
            </div>

            {/* 6. Last Order Banner */}
            <div className="section-lazy-render">
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
            {/* Swiggy-style restaurant listing — banner + cards */}
            <FoodBanner />
            <RestaurantListing initialRestaurants={restaurants} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}function FoodBanner() {
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
              <span className="bg-amber-400 text-zinc-950 text-[8.5px] sm:text-[9.5px] font-black uppercase tracking-widest px-2 py-0.5 rounded-md shadow-xs">
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
