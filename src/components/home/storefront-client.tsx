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
    <div className="w-full min-h-screen bg-[#fafafa] dark:bg-[#09090b] pb-12 mt-3 relative">
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
      <div className="flex justify-center my-3 sm:my-4 px-4">
        <div className="relative flex items-center w-full max-w-[420px] h-[60px] sm:h-[66px] p-1.5 rounded-full bg-white/80 dark:bg-zinc-950/85 backdrop-blur-xl shadow-[0_20px_50px_-15px_rgba(0,0,0,0.10),0_4px_8px_rgba(0,0,0,0.03),inset_0_1px_2px_rgba(255,255,255,0.9)] dark:shadow-[0_20px_50px_-15px_rgba(0,0,0,0.5),0_4px_8px_rgba(0,0,0,0.25),inset_0_1px_1px_rgba(255,255,255,0.06)] border border-zinc-200/50 dark:border-zinc-800/70">
          <motion.button
            onClick={() => handleTabChange('grocery')}
            whileTap={{ scale: 0.96 }}
            whileHover={activeTab === 'grocery' ? {} : { scale: 1.02 }}
            className={cn(
              "relative z-10 flex items-center justify-center gap-2.5 rounded-full cursor-pointer outline-none transition-colors duration-300 h-full flex-1 select-none border-none bg-transparent",
              activeTab === 'grocery' ? "" : "hover:text-zinc-800 dark:hover:text-zinc-200"
            )}
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
            {/* Swiggy-style restaurant listing — banner + cards */}
            <FoodBanner />
            <RestaurantListing />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

function FoodBanner() {
  return (
    <div className="w-full overflow-hidden rounded-2xl md:rounded-3xl border border-zinc-200/50 dark:border-zinc-800/60 shadow-lg hover:shadow-xl transition-all duration-400 select-none">
      {/* Background */}
      <div className="relative bg-gradient-to-br from-[#fff5f0] via-[#fff9f5] to-[#fef3eb] dark:from-zinc-900 dark:via-zinc-900 dark:to-zinc-850 px-4 sm:px-6 md:px-8 py-5 sm:py-6 md:py-7">
        
        {/* Decorative circles */}
        <div className="absolute top-0 right-0 w-40 h-40 bg-gradient-to-bl from-red-500/5 to-transparent rounded-full -translate-y-1/2 translate-x-1/4" />
        <div className="absolute bottom-0 left-0 w-32 h-32 bg-gradient-to-tr from-orange-500/5 to-transparent rounded-full translate-y-1/2 -translate-x-1/4" />

        {/* Top Row: Logo + Category Pills */}
        <div className="flex items-center justify-between mb-3 sm:mb-4">
          {/* Logo */}
          <div className="flex items-center gap-1.5 sm:gap-2">
            <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-lg bg-gradient-to-br from-[#e20a22] to-[#ff4444] flex items-center justify-center shadow-md shadow-red-500/20">
              <span className="text-white font-black text-[11px] sm:text-xs">F</span>
            </div>
            <div>
              <h4 className="text-[13px] sm:text-[15px] font-black text-[#e20a22] leading-none tracking-tight">
                Fast<span className="text-zinc-800 dark:text-zinc-200">Kirana</span>
              </h4>
              <p className="text-[7px] sm:text-[8px] font-bold text-zinc-400 italic leading-none mt-0.5">Sab kuch, super fast!</p>
            </div>
          </div>

          {/* Category Pills */}
          <div className="hidden min-[400px]:flex items-center gap-1.5 sm:gap-2">
            <div className="flex items-center gap-1 sm:gap-1.5 bg-white dark:bg-zinc-800 border border-zinc-200/70 dark:border-zinc-700 rounded-full px-2.5 sm:px-3 py-1.5 shadow-sm">
              <span className="text-[10px] sm:text-[11px]">☕</span>
              <div>
                <p className="text-[9px] sm:text-[10px] font-black text-zinc-800 dark:text-zinc-200 leading-none">Cafe</p>
                <p className="text-[6.5px] sm:text-[7px] text-zinc-400 font-bold leading-none mt-0.5">Coffee, Snacks & More</p>
              </div>
            </div>
            <div className="flex items-center gap-1 sm:gap-1.5 bg-[#e20a22] rounded-full px-2.5 sm:px-3 py-1.5 shadow-sm shadow-red-500/20">
              <span className="text-[10px] sm:text-[11px]">🍴</span>
              <div>
                <p className="text-[9px] sm:text-[10px] font-black text-white leading-none">Restaurant</p>
                <p className="text-[6.5px] sm:text-[7px] text-white/80 font-bold leading-none mt-0.5">Meals, Combos & More</p>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="flex items-center gap-3 sm:gap-5">
          {/* Left: Text */}
          <div className="flex-1 min-w-0">
            <p className="text-[10px] sm:text-xs font-bold text-zinc-500 dark:text-zinc-400 mb-1">Your Favourite</p>
            <h3 className="text-[20px] sm:text-[26px] md:text-[32px] font-black text-zinc-900 dark:text-zinc-50 leading-[1.1] tracking-tight group-hover:scale-[1.01] transition-transform origin-left">
              Cafe & Restaurant
              <br />
              <span className="text-[#e20a22]">Delivered Fast!</span>
            </h3>
            
            {/* Offer Badge */}
            <div className="mt-3 sm:mt-4 flex flex-wrap items-center gap-2">
              <div className="bg-[#e20a22] text-white rounded-xl px-3 py-1.5 sm:px-4 sm:py-2 flex items-center gap-1.5 shadow-md shadow-red-500/25">
                <span className="text-[9px] sm:text-[10px] font-black uppercase tracking-wide">Flat</span>
                <span className="text-[18px] sm:text-[22px] font-black leading-none">5%</span>
                <span className="text-[9px] sm:text-[10px] font-black uppercase tracking-wide">OFF</span>
              </div>
              <div className="flex flex-col">
                <div className="flex items-center gap-1">
                  <span className="text-[8px] sm:text-[9px] font-bold text-zinc-500 dark:text-zinc-400">Use code:</span>
                  <span className="text-[10px] sm:text-[11px] font-black text-[#e20a22] bg-red-50 dark:bg-red-950/30 border border-dashed border-red-300 dark:border-red-800 px-2 py-0.5 rounded-md tracking-wider">FIRST5</span>
                </div>
                <span className="text-[7px] sm:text-[8px] text-zinc-400 font-bold mt-0.5">On your first food order</span>
              </div>
            </div>

            {/* CTA Button */}
            <div className="mt-3 sm:mt-4">
              <span className="inline-flex items-center gap-1.5 text-[9px] sm:text-[10px] font-black uppercase tracking-wider bg-zinc-900 dark:bg-white text-white dark:text-zinc-900 px-4 sm:px-5 py-2 sm:py-2.5 rounded-full shadow-lg group-hover:shadow-xl group-hover:scale-105 transition-all duration-300">
                Order Now
                <svg className="w-3 h-3 transition-transform group-hover:translate-x-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" /></svg>
              </span>
            </div>
          </div>

          {/* Right: Premium Food Visual */}
          <div className="relative w-[110px] h-[110px] sm:w-[140px] sm:h-[140px] md:w-[170px] md:h-[170px] shrink-0">
            {/* Outer glow ring */}
            <div className="absolute inset-[-6px] sm:inset-[-8px] rounded-full bg-gradient-to-br from-[#e20a22]/10 via-orange-400/5 to-amber-300/10 blur-sm" />
            {/* Main circle bg */}
            <div className="absolute inset-0 rounded-full bg-gradient-to-br from-[#fff0e6] via-white to-[#ffecd6] dark:from-zinc-800 dark:via-zinc-850 dark:to-zinc-800 border border-orange-200/40 dark:border-orange-800/20 shadow-lg shadow-orange-500/10 overflow-hidden">
              {/* Decorative pattern */}
              <div className="absolute inset-0 opacity-[0.04]" style={{backgroundImage: 'radial-gradient(circle, #e20a22 1px, transparent 1px)', backgroundSize: '12px 12px'}} />
            </div>
            {/* Center emoji - static, clean */}
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-[44px] sm:text-[56px] md:text-[68px] drop-shadow-lg select-none" style={{filter: 'drop-shadow(0 4px 12px rgba(226,10,34,0.15))'}}>🍔</span>
            </div>
            {/* Static accent food items — no bouncing, just subtle placement */}
            <span className="absolute -top-1 left-1/2 -translate-x-1/2 text-[16px] sm:text-[20px] select-none opacity-90" style={{filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))'}}>🍕</span>
            <span className="absolute top-[15%] -right-1 text-[14px] sm:text-[18px] select-none opacity-80" style={{filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))'}}>☕</span>
            <span className="absolute -bottom-1 left-1/2 -translate-x-1/2 text-[15px] sm:text-[19px] select-none opacity-85" style={{filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))'}}>🍟</span>
            <span className="absolute top-[15%] -left-1 text-[14px] sm:text-[18px] select-none opacity-80" style={{filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))'}}>🥤</span>
            {/* Red accent dot */}
            <div className="absolute -bottom-1 -right-1 w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-gradient-to-br from-[#e20a22] to-[#ff4444] flex items-center justify-center shadow-md shadow-red-500/30 border-2 border-white dark:border-zinc-900">
              <span className="text-[8px] sm:text-[10px] text-white font-black">5%</span>
            </div>
          </div>
        </div>

        {/* Trust Badges */}
        <div className="mt-4 sm:mt-5 pt-3 sm:pt-4 border-t border-zinc-200/60 dark:border-zinc-800/50 flex items-center justify-between sm:justify-start sm:gap-6 md:gap-10">
          <div className="flex items-center gap-1.5 sm:gap-2">
            <div className="w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-red-50 dark:bg-red-950/30 flex items-center justify-center">
              <span className="text-[10px] sm:text-xs">🏆</span>
            </div>
            <div>
              <p className="text-[8px] sm:text-[9px] font-black text-zinc-800 dark:text-zinc-200 uppercase tracking-wider leading-none">Top Quality</p>
              <p className="text-[6.5px] sm:text-[7px] text-zinc-450 font-bold leading-none mt-0.5">You can trust</p>
            </div>
          </div>
          <div className="flex items-center gap-1.5 sm:gap-2">
            <div className="w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-orange-50 dark:bg-orange-950/30 flex items-center justify-center">
              <span className="text-[10px] sm:text-xs">🚀</span>
            </div>
            <div>
              <p className="text-[8px] sm:text-[9px] font-black text-zinc-800 dark:text-zinc-200 uppercase tracking-wider leading-none">Super Fast</p>
              <p className="text-[6.5px] sm:text-[7px] text-zinc-450 font-bold leading-none mt-0.5">At your doorstep</p>
            </div>
          </div>
          <div className="flex items-center gap-1.5 sm:gap-2">
            <div className="w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-green-50 dark:bg-green-950/30 flex items-center justify-center">
              <span className="text-[10px] sm:text-xs">✅</span>
            </div>
            <div>
              <p className="text-[8px] sm:text-[9px] font-black text-zinc-800 dark:text-zinc-200 uppercase tracking-wider leading-none">Safe & Hygienic</p>
              <p className="text-[6.5px] sm:text-[7px] text-zinc-455 font-bold leading-none mt-0.5">Packed with care</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
