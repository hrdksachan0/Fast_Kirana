'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import Link from 'next/link'
import Image from 'next/image'
import { ChevronLeft, ChevronRight, Gift, Apple, Milk, Leaf, Salad, Zap, Sparkles, ShoppingBag } from 'lucide-react'

interface BannerItem {
  id: string | number
  title?: string
  description?: string
  code?: string
  gradient?: string
  type?: string
  imageUrl?: string | null
  videoUrl?: string | null
  linkUrl?: string | null
  isActive?: boolean
}

const DEFAULT_BANNERS: BannerItem[] = []

const INTERVAL_MS = 3500

function BannerInner({ currentBanner }: { currentBanner: BannerItem }) {
  const isVideo = Boolean(
    currentBanner.videoUrl ||
    (currentBanner.imageUrl && (
      currentBanner.imageUrl.toLowerCase().split('?')[0].endsWith('.mp4') ||
      currentBanner.imageUrl.toLowerCase().split('?')[0].endsWith('.webm') ||
      currentBanner.imageUrl.toLowerCase().split('?')[0].endsWith('.mov')
    ))
  )

  if (isVideo) {
    return (
      <div className="relative w-full h-full overflow-hidden bg-black flex items-center justify-center">
        <video
          src={currentBanner.videoUrl || currentBanner.imageUrl!}
          autoPlay
          loop
          muted
          playsInline
          className="w-full h-full object-cover pointer-events-none"
        />
      </div>
    )
  }

  if (currentBanner.imageUrl) {
    return (
      <div className="relative w-full h-full overflow-hidden bg-zinc-950 flex items-center justify-center">
        <Image
          src={currentBanner.imageUrl}
          alt={currentBanner.title || 'Promo Banner'}
          fill
          sizes="(max-width: 768px) 100vw, 1200px"
          className="object-cover pointer-events-none relative z-10"
          priority
        />
      </div>
    )
  }

  return <div className="relative w-full h-full bg-zinc-900" />
}

// Ultra-smooth cubic bezier curve for 3D physics (similar to iOS cube transition)
const CUBIC_EASE = [0.16, 1, 0.3, 1] as const

const cubeVariants = {
  enter: (direction: number) => ({
    x: direction > 0 ? '100%' : direction < 0 ? '-100%' : '0%',
    rotateY: direction > 0 ? 65 : direction < 0 ? -65 : 0,
    transformOrigin: direction > 0 ? '0% 50%' : '100% 50%',
    scale: 0.9,
    opacity: 0.8,
    transformPerspective: 1000,
  }),
  center: (direction: number) => ({
    zIndex: 2,
    x: '0%',
    rotateY: 0,
    transformOrigin: direction > 0 ? '0% 50%' : '100% 50%',
    scale: 1,
    opacity: 1,
    transformPerspective: 1000,
    transition: {
      x: { duration: 0.7, ease: CUBIC_EASE },
      rotateY: { duration: 0.7, ease: CUBIC_EASE },
      scale: { duration: 0.7, ease: CUBIC_EASE },
      opacity: { duration: 0.35, ease: 'easeOut' as const },
    },
  }),
  exit: (direction: number) => ({
    zIndex: 1,
    x: direction > 0 ? '-100%' : '100%',
    rotateY: direction > 0 ? -65 : 65,
    transformOrigin: direction > 0 ? '100% 50%' : '0% 50%',
    scale: 0.9,
    opacity: 0.2,
    transformPerspective: 1000,
    transition: {
      x: { duration: 0.7, ease: CUBIC_EASE },
      rotateY: { duration: 0.7, ease: CUBIC_EASE },
      scale: { duration: 0.7, ease: CUBIC_EASE },
      opacity: { duration: 0.55, ease: 'easeIn' as const },
    },
  }),
}

export function HeroBanner({ initialBanners, mode = 'grocery' }: { initialBanners?: any[]; mode?: 'grocery' | 'food' | 'all' }) {
  const displayBanners = useMemo(() => {
    const raw = initialBanners || DEFAULT_BANNERS
    const modeFiltered = raw.filter((b: any) => {
      const bType = (b.type || 'grocery').toLowerCase()
      if (mode === 'grocery') return bType === 'grocery' || bType === 'all' || bType === 'express-delivery'
      if (mode === 'food') return bType === 'food' || bType === 'cafe'
      return true
    })
    const cleanBanners = modeFiltered.filter((b: any) => {
      const hasMedia = (b.imageUrl && b.imageUrl.trim().length > 0) || (b.videoUrl && b.videoUrl.trim().length > 0)
      return hasMedia && b.isActive !== false
    })
    return cleanBanners.slice(0, 6)
  }, [initialBanners, mode])

  const [[current, direction], setCurrentAndDirection] = useState([0, 0])
  const [progressKey, setProgressKey] = useState(0)
  const [isDragging, setIsDragging] = useState(false)
  const [isHovered, setIsHovered] = useState(false)

  const handleNext = useCallback(() => {
    if (displayBanners.length <= 1) return
    setCurrentAndDirection(([prev]) => [(prev + 1) % displayBanners.length, 1])
    setProgressKey((prev) => prev + 1)
  }, [displayBanners.length])

  const handlePrev = useCallback(() => {
    if (displayBanners.length <= 1) return
    setCurrentAndDirection(([prev]) => [(prev - 1 + displayBanners.length) % displayBanners.length, -1])
    setProgressKey((prev) => prev + 1)
  }, [displayBanners.length])

  // Auto-slide effect (slows down to 5.5s on hover, never freezes)
  useEffect(() => {
    if (displayBanners.length <= 1 || isDragging) return

    const timer = setInterval(() => {
      handleNext()
    }, isHovered ? 5500 : INTERVAL_MS)

    return () => clearInterval(timer)
  }, [displayBanners.length, isHovered, isDragging, handleNext])

  const swipePower = (offset: number, velocity: number) => {
    return Math.abs(offset) * velocity
  }

  const handleDragEnd = (e: any, info: any) => {
    setTimeout(() => setIsDragging(false), 50)
    
    const swipeThreshold = 50
    const offset = info.offset.x
    const velocity = info.velocity.x
    
    if (Math.abs(offset) > swipeThreshold) {
      if (offset < 0) {
        handleNext()
      } else {
        handlePrev()
      }
    } else {
      const swipe = swipePower(offset, velocity)
      if (swipe < -10000) {
        handleNext()
      } else if (swipe > 10000) {
        handlePrev()
      }
    }
  }

  const currentBanner = displayBanners[current] || displayBanners[0]

  if (!currentBanner) return null

  return (
    <div 
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      className="relative w-full overflow-hidden rounded-2xl md:rounded-3xl h-[135px] min-[375px]:h-[145px] sm:h-[195px] md:h-[270px] shadow-elevated select-none group transition-transform duration-300 hover:scale-[1.006] bg-zinc-900/5 dark:bg-zinc-900/30 [perspective:1000px]"
    >
      <AnimatePresence initial={false} custom={direction}>
        <motion.div
          key={current}
          custom={direction}
          variants={cubeVariants}
          initial="enter"
          animate="center"
          exit="exit"
          drag="x"
          dragConstraints={{ left: 0, right: 0 }}
          dragElastic={0.2}
          onDragStart={() => setIsDragging(true)}
          onDragEnd={handleDragEnd}
          className="absolute inset-0 w-full h-full touch-pan-y [backface-visibility:hidden] [transform-style:preserve-3d]"
        >
          {currentBanner.linkUrl ? (
            <Link 
              href={currentBanner.linkUrl} 
              prefetch={false}
              className="block w-full h-full cursor-pointer"
              onClick={(e) => {
                if (isDragging) {
                  e.preventDefault()
                }
              }}
            >
              <BannerInner currentBanner={currentBanner} />
            </Link>
          ) : (
            <BannerInner currentBanner={currentBanner} />
          )}
        </motion.div>
      </AnimatePresence>

      {/* Slide Navigation Buttons */}
      {displayBanners.length > 1 && (
        <>
          <button
            onClick={handlePrev}
            className="absolute left-3 top-1/2 -translate-y-1/2 hidden md:flex h-9 w-9 items-center justify-center rounded-full bg-black/30 hover:bg-black/50 text-white backdrop-blur-md opacity-0 group-hover:opacity-100 transition-all shadow-md z-20 cursor-pointer border border-white/20 active:scale-95"
            aria-label="Previous slide"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          <button
            onClick={handleNext}
            className="absolute right-3 top-1/2 -translate-y-1/2 hidden md:flex h-9 w-9 items-center justify-center rounded-full bg-black/30 hover:bg-black/50 text-white backdrop-blur-md opacity-0 group-hover:opacity-100 transition-all shadow-md z-20 cursor-pointer border border-white/20 active:scale-95"
            aria-label="Next slide"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        </>
      )}

      {/* Signature Floating Counter Pill at Bottom Right */}
      {displayBanners.length > 1 && (
        <div className="absolute bottom-3 right-3 z-20 flex flex-col items-center gap-1 bg-black/75 backdrop-blur-md px-3 py-1 rounded-full border border-white/20 text-white shadow-lg pointer-events-auto">
          <div className="flex items-center gap-1.5">
            <button 
              onClick={(e) => { e.stopPropagation(); handlePrev(); }}
              className="h-2 w-2 rounded-full bg-white/60 hover:bg-white hover:scale-125 cursor-pointer transition-all border-none p-0" 
              aria-label="Previous slide"
            />
            <span className="text-[9px] md:text-[10px] font-black tracking-widest px-1 font-mono">
              {current + 1}/{displayBanners.length}
            </span>
            <button 
              onClick={(e) => { e.stopPropagation(); handleNext(); }}
              className="h-2 w-2 rounded-full bg-white/60 hover:bg-white hover:scale-125 cursor-pointer transition-all border-none p-0" 
              aria-label="Next slide"
            />
          </div>
          {/* Animated timer progress line */}
          <div className="w-10 h-[2px] bg-white/20 rounded-full overflow-hidden">
            <motion.div
              key={progressKey}
              initial={{ width: '0%' }}
              animate={{ width: '100%' }}
              transition={{ duration: isHovered ? 5.5 : 3.5, ease: 'linear' }}
              className="h-full bg-gradient-to-r from-amber-400 to-rose-400 rounded-full"
            />
          </div>
        </div>
      )}
    </div>
  )
}
