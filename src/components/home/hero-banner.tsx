'use client'

import { useRef, useMemo, useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { motion } from 'framer-motion'
import { ChevronLeft, ChevronRight } from 'lucide-react'

export function HeroBanner({
  initialBanners,
  mode = 'grocery',
}: {
  initialBanners?: any[]
  mode?: 'grocery' | 'food' | 'all'
}) {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isPaused, setIsPaused] = useState(false)
  const timerRef = useRef<NodeJS.Timeout | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)
  const isUserInteractingRef = useRef(false)
  const isDraggingMouseRef = useRef(false)
  const mouseStartXRef = useRef(0)
  const mouseScrollLeftRef = useRef(0)

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

  // Center target slide smoothly
  const scrollToIndex = useCallback(
    (index: number, smooth = true) => {
      if (!scrollRef.current || total <= 0) return
      const container = scrollRef.current
      const cards = container.querySelectorAll<HTMLElement>('[data-banner-item]')
      const targetCard = cards[index]
      if (targetCard) {
        const targetLeft = targetCard.offsetLeft - (container.offsetWidth - targetCard.offsetWidth) / 2
        container.scrollTo({
          left: targetLeft,
          behavior: smooth ? 'smooth' : 'auto',
        })
      }
    },
    [total]
  )

  // Sync currentIndex in real-time as user swipes on mobile touch or drags
  const handleScroll = useCallback(() => {
    if (!scrollRef.current || total <= 0) return
    const container = scrollRef.current
    const scrollLeft = container.scrollLeft
    const containerCenter = scrollLeft + container.offsetWidth / 2
    const cards = container.querySelectorAll<HTMLElement>('[data-banner-item]')
    if (!cards.length) return

    let closestIndex = 0
    let minDistance = Infinity
    cards.forEach((card, i) => {
      const cardCenter = card.offsetLeft + card.offsetWidth / 2
      const distance = Math.abs(containerCenter - cardCenter)
      if (distance < minDistance) {
        minDistance = distance
        closestIndex = i
      }
    })

    if (closestIndex !== currentIndex) {
      setCurrentIndex(closestIndex)
    }
  }, [total, currentIndex])

  // Reset index & scroll on mode switch
  useEffect(() => {
    setCurrentIndex(0)
    if (scrollRef.current) {
      scrollRef.current.scrollTo({ left: 0, behavior: 'auto' })
    }
  }, [mode])

  // Next / Previous navigation
  const nextSlide = useCallback(() => {
    if (total <= 1) return
    const nextIdx = (currentIndex + 1) % total
    scrollToIndex(nextIdx, true)
  }, [total, currentIndex, scrollToIndex])

  const prevSlide = useCallback(() => {
    if (total <= 1) return
    const prevIdx = (currentIndex - 1 + total) % total
    scrollToIndex(prevIdx, true)
  }, [total, currentIndex, scrollToIndex])

  // Autoplay timer with pause guard
  useEffect(() => {
    if (total <= 1 || isPaused) {
      if (timerRef.current) clearInterval(timerRef.current)
      return
    }

    timerRef.current = setInterval(() => {
      if (!isUserInteractingRef.current) {
        nextSlide()
      }
    }, 4500)

    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [total, isPaused, nextSlide])

  // Mouse drag handlers for desktop smooth swipe
  const onMouseDown = (e: React.MouseEvent) => {
    if (!scrollRef.current) return
    isDraggingMouseRef.current = true
    mouseStartXRef.current = e.pageX - scrollRef.current.offsetLeft
    mouseScrollLeftRef.current = scrollRef.current.scrollLeft
    setIsPaused(true)
  }

  const onMouseMove = (e: React.MouseEvent) => {
    if (!isDraggingMouseRef.current || !scrollRef.current) return
    e.preventDefault()
    const x = e.pageX - scrollRef.current.offsetLeft
    const walk = (x - mouseStartXRef.current) * 1.4
    scrollRef.current.scrollLeft = mouseScrollLeftRef.current - walk
  }

  const onMouseUpOrLeave = () => {
    if (isDraggingMouseRef.current) {
      isDraggingMouseRef.current = false
      setIsPaused(false)
      // Snap to closest card on mouse release
      handleScroll()
    }
  }

  if (total === 0) return null

  return (
    <div
      className="w-full relative z-10 select-none py-1 group/banner"
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => setIsPaused(false)}
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

      {/* Viewport: 86% active card width with 7% left & right peek + 120Hz smooth touch snapping */}
      <div
        ref={scrollRef}
        onScroll={handleScroll}
        onTouchStart={() => {
          isUserInteractingRef.current = true
          setIsPaused(true)
        }}
        onTouchEnd={() => {
          isUserInteractingRef.current = false
          setIsPaused(false)
        }}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUpOrLeave}
        className="w-full flex items-center gap-[11px] overflow-x-auto snap-x snap-mandatory scrollbar-none py-1.5 px-[7%] cursor-grab active:cursor-grabbing"
        style={{
          WebkitOverflowScrolling: 'touch',
          scrollbarWidth: 'none',
          msOverflowStyle: 'none',
          scrollBehavior: 'smooth',
        }}
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
            <div
              key={banner.id || idx}
              data-banner-item
              onClick={() => {
                if (!isActive) scrollToIndex(idx, true)
              }}
              className={`shrink-0 aspect-[1.8/1] rounded-[22px] overflow-hidden bg-zinc-900 border border-black/10 dark:border-white/10 snap-center relative transition-all duration-300 ease-out ${
                isActive
                  ? 'scale-100 opacity-100 shadow-[0_12px_28px_rgba(0,0,0,0.18)]'
                  : 'scale-[0.93] opacity-80 shadow-sm'
              }`}
              style={{
                width: '86vw',
                maxWidth: '440px',
              }}
            >
              <Link
                href={targetUrl}
                prefetch={false}
                onClick={(e) => {
                  if (isDraggingMouseRef.current) e.preventDefault()
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
                      className="object-cover select-none pointer-events-none"
                      priority={idx === 0}
                    />
                  )
                )}

                {/* Hardware Double-Bezel Inner Glass Rim Overlay */}
                <div className="absolute inset-0 rounded-[22px] border border-white/20 pointer-events-none" />
              </Link>
            </div>
          )
        })}
      </div>

      {/* Animated Pagination Bar (FastMinute Red Active Pill + Dots + Counter Badge) */}
      {total > 1 && (
        <div className="flex items-center justify-center gap-1.5 mt-2">
          <div className="flex items-center gap-1.5">
            {displayBanners.map((_, idx) => {
              const isActive = idx === currentIndex
              return (
                <button
                  key={idx}
                  type="button"
                  onClick={() => scrollToIndex(idx, true)}
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

          {/* Counter Badge ("1/2") */}
          <div className="ml-1.5 px-2 py-0.5 rounded-full bg-slate-100 dark:bg-zinc-800 border border-slate-200 dark:border-zinc-700/60 text-[10px] font-extrabold text-slate-600 dark:text-zinc-300">
            {currentIndex + 1}/{total}
          </div>
        </div>
      )}
    </div>
  )
}
