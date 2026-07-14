'use client'

import { useState, useEffect } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { motion, AnimatePresence } from 'framer-motion'
import { cn } from '@/lib/utils'
import { Category, Product } from '@/types'
import { CategoryGrid } from '@/components/home/category-grid'
import { CafeSection } from '@/components/home/cafe-section'
import { HeroArea } from '@/components/home/hero-area'
import { SpeedStrip } from '@/components/home/speed-strip'
import { DealsCurationHub } from '@/components/home/deals-curation-hub'
import { DeliveryBanner } from '@/components/home/delivery-banner'
import { LastOrderBanner } from '@/components/home/last-order-banner'
import { ShoppingBag, Utensils } from 'lucide-react'

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
}

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
}: StorefrontClientProps) {
  const searchParams = useSearchParams()
  const router = useRouter()
  
  // Tab state: 'grocery' | 'cafe'
  const [activeTab, setActiveTab] = useState<'grocery' | 'cafe'>('grocery')

  // Sync tab state with query parameters on load
  useEffect(() => {
    const mode = searchParams.get('mode')
    if (mode === 'cafe') {
      setActiveTab('cafe')
    } else if (mode === 'grocery') {
      setActiveTab('grocery')
    }
  }, [searchParams])

  const handleTabChange = (tab: 'grocery' | 'cafe') => {
    setActiveTab(tab)
    // Update URL query params without full page reload
    const params = new URLSearchParams(window.location.search)
    params.set('mode', tab)
    router.replace(`/?${params.toString()}`, { scroll: false })
    
    // Add tiny touch vibration if available
    if (typeof window !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate(10)
    }
  }

  return (
    <div
      className={cn(
        "w-full min-h-screen transition-all duration-700 ease-in-out bg-[#fafafa] dark:bg-[#09090b] pb-12 mt-3 relative overflow-hidden",
        activeTab === 'grocery'
          ? "bg-gradient-to-b from-red-500/[0.02] via-transparent to-transparent"
          : "bg-gradient-to-b from-orange-500/[0.02] via-transparent to-transparent"
      )}
    >
      {/* Premium ambient radial mesh glows */}
      <div className="absolute top-0 left-0 right-0 h-[600px] overflow-hidden pointer-events-none select-none z-0">
        <div 
          className="absolute -top-[350px] left-1/2 -translate-x-1/2 w-[850px] h-[650px] rounded-full blur-[150px] opacity-[0.25] dark:opacity-[0.14] transition-all duration-1000"
          style={{
            background: activeTab === 'grocery' 
              ? 'radial-gradient(circle, rgba(239,68,68,0.22) 0%, rgba(244,63,94,0.08) 50%, transparent 100%)'
              : 'radial-gradient(circle, rgba(249,115,22,0.22) 0%, rgba(245,158,11,0.08) 50%, transparent 100%)'
          }}
        />
      </div>

      <div className="container mx-auto px-4 pt-4 flex flex-col gap-1.5 md:gap-8 max-w-7xl relative z-10">
        {/* Premium ambient glow background effects */}
        <div className="relative w-full mb-0 select-none">
          <div 
            className="absolute -top-12 left-1/4 -translate-x-1/2 w-48 h-32 rounded-full blur-3xl pointer-events-none transition-opacity duration-700"
            style={{ 
              opacity: activeTab === 'grocery' ? 0.35 : 0,
              background: 'radial-gradient(circle, rgba(239,68,68,0.25) 0%, transparent 70%)'
            }} 
          />
          <div 
            className="absolute -top-12 left-3/4 -translate-x-1/2 w-48 h-32 rounded-full blur-3xl pointer-events-none transition-opacity duration-700"
            style={{ 
              opacity: activeTab === 'cafe' ? 0.35 : 0,
              background: 'radial-gradient(circle, rgba(249,115,22,0.25) 0%, transparent 70%)'
            }} 
          />

          {/* Full-width premium Segment Controller */}
          <div className="relative flex w-full h-12 p-1 bg-zinc-100/80 dark:bg-zinc-900/50 backdrop-blur-xl rounded-2xl shadow-[0_8px_32px_rgba(0,0,0,0.02)] dark:shadow-[0_8px_32px_rgba(0,0,0,0.15)] border border-zinc-200/50 dark:border-zinc-800/60 overflow-hidden items-center">
            <button
              onClick={() => handleTabChange('grocery')}
              className={cn(
                "relative flex-1 h-full text-xs sm:text-sm font-bold tracking-wider uppercase transition-all duration-300 z-10 flex items-center justify-center gap-2 cursor-pointer active:scale-95",
                activeTab === 'grocery'
                  ? "text-white scale-102 font-extrabold"
                  : "text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white"
              )}
            >
              <ShoppingBag className="h-4 w-4 sm:h-5 sm:w-5" strokeWidth={2} />
              <span>Grocery</span>
            </button>
            <button
              onClick={() => handleTabChange('cafe')}
              className={cn(
                "relative flex-1 h-full text-xs sm:text-sm font-bold tracking-wider uppercase transition-all duration-300 z-10 flex items-center justify-center gap-2 cursor-pointer active:scale-95",
                activeTab === 'cafe'
                  ? "text-white scale-102 font-extrabold"
                  : "text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white"
              )}
            >
              <Utensils className="h-4 w-4 sm:h-5 sm:w-5" strokeWidth={2} />
              <span>Food</span>
            </button>
            
            {/* Sliding Pill Indicator with Framer Motion spanning exactly half width */}
            <motion.div
              className={cn(
                "absolute top-1 bottom-1 rounded-xl -z-0",
                activeTab === 'grocery'
                  ? "bg-gradient-to-r from-red-600 to-rose-500 shadow-[0_4px_16px_rgba(239,68,68,0.25)]"
                  : "bg-gradient-to-r from-orange-600 to-amber-500 shadow-[0_4px_16px_rgba(249,115,22,0.25)]"
              )}
              layoutId="activeTabIndicator"
              transition={{ type: 'spring', stiffness: 360, damping: 26 }}
              style={{
                width: 'calc(50% - 4px)',
                left: activeTab === 'grocery' ? '4px' : 'calc(50% + 2px)',
              }}
            />
          </div>
        </div>

        {/* Tab Contents with animations */}
        <AnimatePresence mode="wait">
          {activeTab === 'grocery' ? (
            <motion.div
              key="grocery-content"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -15 }}
              transition={{ duration: 0.35, ease: 'easeInOut' }}
              className="flex flex-col gap-1.5 md:gap-8"
            >
              {/* 1. Trending Categories */}
              <div>
                <CategoryGrid categories={categories} />
              </div>

              {/* 2. Hero Banners */}
              <div>
                <HeroArea initialBanners={promoBanners} />
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
              key="cafe-content"
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -15 }}
              transition={{ duration: 0.35, ease: 'easeInOut' }}
              className="flex flex-col gap-0"
            >
              {/* 1. Cafe Categories & Banner */}
              <div>
                <CafeSection showProducts={true} />
              </div>

              {/* 3. Last Order Banner */}
              <div>
                <LastOrderBanner />
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  )
}
