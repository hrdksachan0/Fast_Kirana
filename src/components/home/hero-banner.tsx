'use client'

import { useState, useEffect, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import Link from 'next/link'
import { ChevronLeft, ChevronRight, Gift, Apple, Milk, Leaf, Salad, Cookie, CupSoda, Zap } from 'lucide-react'

interface BannerItem {
  id: string | number
  title: string
  description: string
  code: string
  gradient: string
  type: string
  imageUrl?: string | null
  linkUrl?: string | null
}

const DEFAULT_BANNERS: BannerItem[] = [
  {
    id: 1,
    title: 'Super Savings on First Order!',
    description: 'Get flat 50% off up to ₹100 on fruits, veggies, dairy, and snacks.',
    code: 'WELCOME50',
    gradient: 'from-rose-600 via-rose-500 to-orange-400',
    type: 'first-order',
  },
  {
    id: 2,
    title: 'Farm Fresh Vegetables & Fruits',
    description: 'Directly sourced from local farms. Handpicked for premium quality.',
    code: 'SAVE20',
    gradient: 'from-emerald-600 via-emerald-500 to-teal-400',
    type: 'fresh',
  },
  {
    id: 3,
    title: 'Midnight Snack Craving?',
    description: 'Get chocolates, chips, ice creams, and cold drinks delivered instantly.',
    code: 'MEGA200',
    gradient: 'from-orange-500 via-orange-500 to-amber-400',
    type: 'snacks',
  },
]

const INTERVAL_MS = 5000

function BannerInner({ currentBanner }: { currentBanner: BannerItem }) {
  return currentBanner.imageUrl ? (
    <div className="relative w-full h-full">
      <img
        src={currentBanner.imageUrl}
        alt={currentBanner.title}
        className="w-full h-full object-cover pointer-events-none"
      />
      {currentBanner.code && (
        <div className="absolute top-2 left-2 md:top-4 md:left-4 z-10">
          <span className="inline-flex items-center gap-1 bg-black/45 border border-white/10 px-2 py-0.5 rounded-full text-[9px] md:text-xs font-black text-white backdrop-blur-md shadow-sm">
            <Gift className="h-3 w-3" />
            Code: {currentBanner.code}
          </span>
        </div>
      )}
    </div>
  ) : (
    <div className={`absolute inset-0 flex items-center justify-between p-4 md:p-12 text-white bg-gradient-to-br ${currentBanner.gradient}`}>
      {/* Floating Decorative Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-2 right-[30%] h-10 w-10 md:h-16 md:w-16 rounded-full bg-white/10 animate-float-slow" />
        <div className="absolute bottom-3 right-[20%] h-6 w-6 md:h-10 md:w-10 rounded-full bg-white/10 animate-float-reverse" />
        <div className="absolute top-[65%] left-[10%] h-5 w-5 md:h-8 md:w-8 rounded-full bg-white/5 animate-float" />
      </div>

      {/* Content */}
      <div className="relative z-10 max-w-[75%] md:max-w-[70%] space-y-1 md:space-y-4 text-left">
        {/* Promo Code Badge with Glassmorphism */}
        <span className="inline-flex items-center gap-1 bg-white/20 border border-white/20 px-2 py-0.5 md:px-3 md:py-1 rounded-full text-[9px] md:text-xs font-black backdrop-blur-md shadow-sm">
          <Gift className="h-3 w-3" />
          Code: {currentBanner.code}
        </span>

        <h2 className="text-sm sm:text-xl md:text-4xl font-black tracking-tight leading-tight drop-shadow-sm select-none">
          {currentBanner.title}
        </h2>
        <p className="text-[9px] sm:text-xs md:text-sm text-white/90 font-bold max-w-md line-clamp-1 md:line-clamp-none leading-relaxed">
          {currentBanner.description}
        </p>

        {/* Delivery ETA Display */}
        <div className="inline-flex items-center gap-1 bg-white/25 backdrop-blur-sm px-2 py-0.5 rounded-full text-[8px] md:text-xs font-black mt-1">
          <Zap className="h-2.5 w-2.5 text-amber-300 fill-amber-300" />
          <span>Instant Delivery</span>
        </div>
      </div>

      {/* Interactive Premium Visual Badge */}
      <div className="relative z-10 flex items-center justify-center h-14 w-14 sm:h-20 sm:w-20 md:h-36 md:w-36 rounded-xl md:rounded-3xl bg-white/10 backdrop-blur-md border border-white/20 shadow-lg overflow-hidden group-hover:scale-105 transition-transform duration-500 mr-1 md:mr-6 flex-shrink-0">
        {/* Glow effect */}
        <div className="absolute inset-0 bg-gradient-to-tr from-white/10 to-transparent pointer-events-none" />
        
        {currentBanner.type === 'first-order' && (
          <div className="relative flex items-center justify-center w-full h-full">
            <div className="absolute top-1 left-1 md:top-4 md:left-4 h-7 w-7 md:h-16 md:w-16 rounded-full bg-white/25 flex items-center justify-center shadow-md animate-float">
              <Apple className="h-4 w-4 md:h-9 md:w-9 text-rose-100 fill-rose-600/20" />
            </div>
            <div className="absolute bottom-1 right-1 md:bottom-4 md:right-4 h-7 w-7 md:h-16 md:w-16 rounded-full bg-white/25 flex items-center justify-center shadow-md animate-float-reverse">
              <Milk className="h-4 w-4 md:h-9 md:w-9 text-blue-100 fill-blue-600/20" />
            </div>
          </div>
        )}

        {currentBanner.type === 'fresh' && (
          <div className="relative flex items-center justify-center w-full h-full">
            <div className="absolute top-1 right-1 md:top-4 md:right-4 h-7 w-7 md:h-16 md:w-16 rounded-full bg-white/25 flex items-center justify-center shadow-md animate-float">
              <Leaf className="h-4 w-4 md:h-9 md:w-9 text-emerald-100 fill-emerald-600/20" />
            </div>
            <div className="absolute bottom-1 left-1 md:bottom-4 md:left-4 h-7 w-7 md:h-16 md:w-16 rounded-full bg-white/25 flex items-center justify-center shadow-md animate-float-reverse">
              <Salad className="h-4 w-4 md:h-9 md:w-9 text-green-100 fill-green-600/20" />
            </div>
          </div>
        )}

        {currentBanner.type === 'snacks' && (
          <div className="relative flex items-center justify-center w-full h-full">
            <div className="absolute top-1 left-1 md:top-4 md:left-4 h-7 w-7 md:h-16 md:w-16 rounded-full bg-white/25 flex items-center justify-center shadow-md animate-float">
              <Cookie className="h-4 w-4 md:h-9 md:w-9 text-amber-100 fill-amber-600/20" />
            </div>
            <div className="absolute bottom-1 right-1 md:bottom-4 md:right-4 h-7 w-7 md:h-16 md:w-16 rounded-full bg-white/25 flex items-center justify-center shadow-md animate-float-reverse">
              <CupSoda className="h-4 w-4 md:h-9 md:w-9 text-purple-100 fill-purple-600/20" />
            </div>
          </div>
        )}

        {(currentBanner.type === 'festival' || currentBanner.type === 'custom') && (
          <div className="relative flex items-center justify-center w-full h-full text-white text-xl md:text-5xl font-black">
            {currentBanner.type === 'festival' ? '🪔' : '📦'}
          </div>
        )}
      </div>
    </div>
  )
}

export function HeroBanner({ initialBanners }: { initialBanners?: any[] }) {
  const displayBanners = useMemo(() => {
    return initialBanners && initialBanners.length > 0 ? initialBanners : DEFAULT_BANNERS
  }, [initialBanners])

  const [current, setCurrent] = useState(0)
  const [progressKey, setProgressKey] = useState(0)

  // Auto-slide effect
  useEffect(() => {
    if (displayBanners.length <= 1) return
    
    if (current >= displayBanners.length) {
      setCurrent(0)
    }

    const timer = setInterval(() => {
      setCurrent((prev) => (prev + 1) % displayBanners.length)
      setProgressKey((prev) => prev + 1)
    }, INTERVAL_MS)

    return () => clearInterval(timer)
  }, [displayBanners, current])

  const handleNext = () => {
    if (displayBanners.length <= 1) return
    setCurrent((prev) => (prev + 1) % displayBanners.length)
    setProgressKey((prev) => prev + 1)
  }

  const handlePrev = () => {
    if (displayBanners.length <= 1) return
    setCurrent((prev) => (prev - 1 + displayBanners.length) % displayBanners.length)
    setProgressKey((prev) => prev + 1)
  }

  const currentBanner = displayBanners[current] || displayBanners[0]

  if (!currentBanner) return null

  return (
    <div className="relative w-full overflow-hidden rounded-2xl md:rounded-3xl h-[120px] sm:h-[180px] md:h-[260px] shadow-elevated select-none group">
      <AnimatePresence mode="wait">
        <motion.div
          key={current}
          initial={{ opacity: 0, x: 80 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -80 }}
          transition={{
            type: 'spring',
            stiffness: 180,
            damping: 24,
            mass: 0.8
          }}
          className="absolute inset-0 w-full h-full"
        >
          {currentBanner.linkUrl ? (
            <Link href={currentBanner.linkUrl} className="block w-full h-full cursor-pointer">
              <BannerInner currentBanner={currentBanner} />
            </Link>
          ) : (
            <BannerInner currentBanner={currentBanner} />
          )}
        </motion.div>
      </AnimatePresence>

      {/* Slide Navigation Buttons (hidden on mobile, visible on hover on desktop) */}
      {displayBanners.length > 1 && (
        <>
          <button
            onClick={handlePrev}
            className="absolute left-3 top-1/2 -translate-y-1/2 hidden md:flex h-8 w-8 items-center justify-center rounded-full bg-white/20 text-white backdrop-blur-sm opacity-0 group-hover:opacity-100 hover:bg-white/30 transition-all shadow-sm z-20 cursor-pointer"
            aria-label="Previous slide"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          <button
            onClick={handleNext}
            className="absolute right-3 top-1/2 -translate-y-1/2 hidden md:flex h-8 w-8 items-center justify-center rounded-full bg-white/20 text-white backdrop-blur-sm opacity-0 group-hover:opacity-100 hover:bg-white/30 transition-all shadow-sm z-20 cursor-pointer"
            aria-label="Next slide"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        </>
      )}

      {/* Auto-Progress Bar at bottom */}
      {displayBanners.length > 1 && (
        <div className="absolute bottom-0 left-0 right-0 z-20 flex gap-1 px-4 pb-1.5 md:pb-2">
          {displayBanners.map((_, idx) => (
            <div key={idx} className="h-0.5 md:h-1 flex-1 rounded-full bg-white/20 overflow-hidden">
              {idx === current ? (
                <div
                  key={progressKey}
                  className="h-full rounded-full bg-white animate-progress"
                />
              ) : idx < current ? (
                <div className="h-full w-full rounded-full bg-white/50" />
              ) : null}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
