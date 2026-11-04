'use client'

import { useRef, useMemo, useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { motion, AnimatePresence } from 'framer-motion'
import { ChevronLeft, ChevronRight } from 'lucide-react'

interface BannerItem {
  id: string | number
  title?: string
  subtitle?: string
  description?: string
  code?: string
  gradient?: string
  type?: string
  imageUrl?: string | null
  videoUrl?: string | null
  linkUrl?: string | null
  ctaUrl?: string | null
  redirectUrl?: string | null
  isActive?: boolean
}

/**
 * FastMinute Ultra-Premium Animated Hero Carousel (Next.js Web)
 * Matches Flutter Mobile architecture:
 * - 86% active width with partial peek of previous and next banners (Amazon side-peek)
 * - 1.8:1 aspect ratio
 * - 22px border radius with subtle ambient shadow & white inner glass rim
 * - 10-12px horizontal gaps
 * - 4.5s autoplay with smooth 550ms easeInOutCubic slide motion
 * - Active scale: 1.0, Inactive scale: 0.94, Inactive opacity: 0.85
 * - Elongated FastMinute red active pill indicator + grey dots + count badge
 * - Pause on touch/drag/hover
 */
const DEFAULT_GROCERY_BANNERS = [
  {
    id: 'default-diwali-delights',
    title: 'Diwali Delights, Delivered in 10-15 Mins',
    imageUrl: 'https://images.unsplash.com/photo-1605371924599-2d0365da1ae0?auto=format&fit=crop&w=1080&q=80',
    linkUrl: '/search?q=diwali',
  },
  {
    id: 'default-express-groceries',
    title: 'Fast Delivery in 10-15 Mins',
    imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1080&q=80',
    linkUrl: '/category/packaged-items',
  },
]

const DEFAULT_FOOD_BANNERS = [
  {
    id: 'default-food-special',
    title: 'Hot & Fresh Food in 20-25 Mins',
    imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1080&q=80',
    linkUrl: '/food',
  },
]

export function HeroBanner({
  initialBanners,
  mode = 'grocery',
}: {
  initialBanners?: any[]
  mode?: 'grocery' | 'food' | 'all'
}) {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isPaused, setIsPaused] = useState(false)
  const [isDragging, setIsDragging] = useState(false)
  const timerRef = useRef<NodeJS.Timeout | null>(null)

  const displayBanners = useMemo(() => {
    const raw = initialBanners || []
    const modeFiltered = raw.filter((b: any) => {
      const bType = (b.type || 'grocery').toLowerCase()
      if (mode === 'grocery') return bType === 'grocery' || bType === 'all' || bType === 'express-delivery'
      if (mode === 'food') return bType === 'food' || bType === 'cafe'
      return true
    })
    const cleanBanners = modeFiltered.filter((b: any) => {
      const hasMedia =
        (b.imageUrl && b.imageUrl.trim().length > 0) ||
        (b.videoUrl && b.videoUrl.trim().length > 0)
      return hasMedia && b.isActive !== false
    })
    return cleanBanners
  }, [initialBanners, mode])

  const total = displayBanners.length

  // Reset index when category/mode switches
  useEffect(() => {
    setCurrentIndex(0)
  }, [mode])

  // Autoplay timer
  const nextSlide = useCallback(() => {
    if (total <= 1) return
    setCurrentIndex((prev) => (prev + 1) % total)
  }, [total])

  const prevSlide = useCallback(() => {
    if (total <= 1) return
    setCurrentIndex((prev) => (prev - 1 + total) % total)
  }, [total])

  useEffect(() => {
    if (total <= 1 || isPaused || isDragging) {
      if (timerRef.current) clearInterval(timerRef.current)
      return
    }

    timerRef.current = setInterval(nextSlide, 4500)
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [total, isPaused, isDragging, nextSlide])

  if (total === 0) return null

  if (total === 0) return null

  return (
    <div
      className="w-full relative z-10 select-none py-1 group/banner"
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => setIsPaused(false)}
      onTouchStart={() => setIsPaused(true)}
      onTouchEnd={() => setIsPaused(false)}
    >
      {/* Desktop Left / Right Navigation Controls */}
      {total > 1 && (
        <>
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation()
              prevSlide()
            }}
            className="hidden md:flex absolute left-2 top-1/2 -translate-y-1/2 z-30 h-10 w-10 rounded-full bg-white/95 dark:bg-zinc-900/95 border border-zinc-200/80 dark:border-zinc-800 items-center justify-center text-zinc-800 dark:text-zinc-200 shadow-xl hover:scale-105 active:scale-95 transition-all cursor-pointer opacity-0 group-hover/banner:opacity-100"
            aria-label="Previous banner"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation()
              nextSlide()
            }}
            className="hidden md:flex absolute right-2 top-1/2 -translate-y-1/2 z-30 h-10 w-10 rounded-full bg-white/95 dark:bg-zinc-900/95 border border-zinc-200/80 dark:border-zinc-800 items-center justify-center text-zinc-800 dark:text-zinc-200 shadow-xl hover:scale-105 active:scale-95 transition-all cursor-pointer opacity-0 group-hover/banner:opacity-100"
            aria-label="Next banner"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        </>
      )}

      {/* Viewport: 86% active card width with 7% left & right peek */}
      <div className="relative w-full overflow-hidden flex justify-center items-center">
        <motion.div
          className="flex items-center w-full cursor-grab active:cursor-grabbing"
          drag={total > 1 ? 'x' : false}
          dragConstraints={{ left: 0, right: 0 }}
          dragElastic={0.25}
          onDragStart={() => setIsDragging(true)}
          onDragEnd={(_, info) => {
            setIsDragging(false)
            if (info.offset.x < -40 || info.velocity.x < -300) {
              nextSlide()
            } else if (info.offset.x > 40 || info.velocity.x > 300) {
              prevSlide()
            }
          }}
          animate={{
            // Center the active slide (86% width + 10px gap, leaving 7% peek on both sides)
            x: `calc(7% - ${currentIndex * 86}% - ${currentIndex * 11}px)`,
          }}
          transition={{
            type: 'spring',
            stiffness: 260,
            damping: 28,
            mass: 0.8,
          }}
          style={{ width: `${total * 86}%` }}
        >
          {displayBanners.map((banner: any, idx: number) => {
            const isActive = idx === currentIndex
            const targetUrl =
              banner.linkUrl ||
              banner.ctaUrl ||
              banner.redirectUrl ||
              (banner.type === 'food' ? '/food' : '/category/fruits-vegetables')
            const isVideo = Boolean(
              banner.videoUrl ||
                (banner.imageUrl &&
                  (banner.imageUrl.toLowerCase().split('?')[0].endsWith('.mp4') ||
                    banner.imageUrl.toLowerCase().split('?')[0].endsWith('.webm') ||
                    banner.imageUrl.toLowerCase().split('?')[0].endsWith('.mov')))
            )

            return (
              <motion.div
                key={banner.id || idx}
                animate={{
                  scale: isActive ? 1.0 : 0.94,
                  opacity: isActive ? 1.0 : 0.85,
                }}
                transition={{ duration: 0.45, ease: [0.65, 0, 0.35, 1] }}
                className="shrink-0 aspect-[1.8/1] rounded-[22px] overflow-hidden bg-zinc-900 border border-black/10 dark:border-white/10 shadow-[0_8px_24px_rgba(0,0,0,0.12)] relative"
                style={{
                  width: '86%',
                  maxWidth: '440px',
                  marginRight: '11px',
                }}
              >
                <Link
                  href={targetUrl}
                  prefetch={false}
                  onClick={(e) => {
                    if (isDragging) e.preventDefault()
                  }}
                  className="relative block w-full h-full"
                >
                  {isVideo ? (
                    <video
                      src={banner.videoUrl || banner.imageUrl!}
                      autoPlay
                      loop
                      muted
                      playsInline
                      className="w-full h-full object-cover pointer-events-none"
                    />
                  ) : (
                    banner.imageUrl && (
                      <Image
                        src={banner.imageUrl}
                        alt={banner.title || 'FastMinute Hero Banner'}
                        fill
                        sizes="(max-width: 768px) 86vw, 440px"
                        className="object-cover select-none"
                        priority={idx === 0}
                      />
                    )
                  )}

                  {/* Hardware Double-Bezel Inner Glass Rim Overlay */}
                  <div className="absolute inset-0 rounded-[22px] border border-white/20 pointer-events-none" />
                </Link>
              </motion.div>
            )
          })}
        </motion.div>
      </div>

      {/* Animated Pagination Bar (FastMinute Red Active Pill + Dots + Counter Badge) */}
      {total > 1 && (
        <div className="flex items-center justify-center gap-1.5 mt-2.5">
          <div className="flex items-center gap-1.5">
            {displayBanners.map((_, idx) => {
              const isActive = idx === currentIndex
              return (
                <button
                  key={idx}
                  type="button"
                  onClick={() => setCurrentIndex(idx)}
                  className="focus:outline-none py-1 cursor-pointer"
                  aria-label={`Go to slide ${idx + 1}`}
                >
                  <motion.div
                    animate={{
                      width: isActive ? 22 : 6,
                      backgroundColor: isActive ? '#E11D48' : '#CBD5E1',
                    }}
                    transition={{ type: 'spring', stiffness: 350, damping: 25 }}
                    className="h-1.5 rounded-full"
                  />
                </button>
              )
            })}
          </div>

          {/* Counter Badge ("1/5") */}
          <div className="ml-1.5 px-2 py-0.5 rounded-full bg-slate-100 dark:bg-zinc-800 border border-slate-200 dark:border-zinc-700/60 text-[10px] font-extrabold text-slate-600 dark:text-zinc-300">
            {currentIndex + 1}/{total}
          </div>
        </div>
      )}
    </div>
  )
}
