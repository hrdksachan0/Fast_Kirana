'use client'

import { useState, useRef, useMemo, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { ChevronLeft, ChevronRight, Play, Pause, Sparkles } from 'lucide-react'

export interface BrandCardItem {
  id: string | number
  title?: string
  description?: string
  code?: string
  gradient?: string
  type?: string
  cardType?: string
  placement?: string
  imageUrl?: string | null
  videoUrl?: string | null
  linkUrl?: string | null
  ctaUrl?: string | null
  isActive?: boolean
  sortOrder?: number
}



function BrandCardMedia({
  imageUrl,
  videoUrl,
  alt = 'Brand Offer',
}: {
  imageUrl?: string | null
  videoUrl?: string | null
  alt?: string
}) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isPlaying, setIsPlaying] = useState(true)
  const [progress, setProgress] = useState(0)

  const isVideo = Boolean(
    videoUrl ||
    (imageUrl && (
      imageUrl.toLowerCase().split('?')[0].endsWith('.mp4') ||
      imageUrl.toLowerCase().split('?')[0].endsWith('.webm') ||
      imageUrl.toLowerCase().split('?')[0].endsWith('.mov')
    ))
  )

  const resolvedVideo = videoUrl || (isVideo ? imageUrl : null)

  // IntersectionObserver: Auto-play when visible, pause when scrolled away
  useEffect(() => {
    if (!resolvedVideo || !videoRef.current) return
    const el = videoRef.current

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            el.play().then(() => setIsPlaying(true)).catch(() => {})
          } else {
            el.pause()
            setIsPlaying(false)
          }
        })
      },
      { threshold: 0.3 }
    )

    observer.observe(el)
    return () => observer.disconnect()
  }, [resolvedVideo])

  const togglePlayPause = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (!videoRef.current) return
    if (videoRef.current.paused) {
      videoRef.current.play()
      setIsPlaying(true)
    } else {
      videoRef.current.pause()
      setIsPlaying(false)
    }
  }

  const handleTimeUpdate = () => {
    if (videoRef.current && videoRef.current.duration) {
      const pct = (videoRef.current.currentTime / videoRef.current.duration) * 100
      setProgress(pct)
    }
  }

  if (resolvedVideo) {
    return (
      <div className="relative w-full h-full overflow-hidden bg-black select-none group">
        {/* Instant Poster Fallback for 0ms black flicker */}
        {imageUrl && !imageUrl.toLowerCase().endsWith('.mp4') && (
          <img
            src={imageUrl}
            alt={alt}
            className="absolute inset-0 w-full h-full object-cover -z-10"
          />
        )}

        <video
          ref={videoRef}
          src={resolvedVideo}
          autoPlay
          loop
          muted
          playsInline
          onTimeUpdate={handleTimeUpdate}
          className="w-full h-full object-cover pointer-events-none transition-transform duration-700 ease-out group-hover:scale-[1.03]"
          onPlay={() => setIsPlaying(true)}
          onPause={() => setIsPlaying(false)}
        />

        {/* 1. Instagram / Story Style Looping Progress Bar */}
        <div className="absolute top-2.5 inset-x-3.5 h-[2.5px] rounded-full bg-white/20 backdrop-blur-xs overflow-hidden z-20 pointer-events-none">
          <div
            className="h-full bg-gradient-to-r from-amber-300 via-rose-400 to-white rounded-full transition-all duration-75 shadow-[0_0_8px_rgba(255,255,255,0.85)]"
            style={{ width: `${progress}%` }}
          />
        </div>

        {/* 2. Live Motion Luxury Spotlight Badge */}
        <div className="absolute top-4 left-3.5 z-20 flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-black/60 backdrop-blur-md border border-white/20 text-white shadow-md pointer-events-none select-none">
          <span className="relative flex h-1.5 w-1.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-500" />
          </span>
          <span className="text-[7.5px] font-black uppercase tracking-widest text-white/95">
            SPOTLIGHT
          </span>
        </div>

        {/* 3. Subtle bottom vignette for razor-sharp button contrast */}
        <div className="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-black/60 to-transparent pointer-events-none z-10" />

        {/* 4. Floating Tactile Pause/Play Corner Pill */}
        <button
          type="button"
          onClick={togglePlayPause}
          className="absolute bottom-3 right-3 z-30 flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/65 hover:bg-black/85 backdrop-blur-md border border-white/25 hover:border-white/40 text-white shadow-[0_4px_16px_rgba(0,0,0,0.45)] cursor-pointer hover:scale-105 active:scale-95 transition-all text-[9px] font-black tracking-wider pointer-events-auto"
          aria-label={isPlaying ? 'Pause video' : 'Play video'}
        >
          {isPlaying ? (
            <>
              <Pause className="h-2.5 w-2.5 fill-white text-white" />
              <span>PAUSE</span>
            </>
          ) : (
            <>
              <Play className="h-2.5 w-2.5 fill-white text-white" />
              <span>PLAY</span>
            </>
          )}
        </button>

        {/* 5. Centered Big Play Indicator when paused */}
        {!isPlaying && (
          <button
            type="button"
            onClick={togglePlayPause}
            className="absolute inset-0 m-auto w-12 h-12 rounded-full bg-black/75 backdrop-blur-md border border-white/35 flex items-center justify-center text-white shadow-[0_8px_32px_rgba(0,0,0,0.6)] cursor-pointer hover:scale-110 active:scale-95 transition-all z-30 pointer-events-auto"
            aria-label="Play video"
          >
            <Play className="h-6 w-6 fill-white text-white ml-0.5" />
          </button>
        )}
      </div>
    )
  }

  if (imageUrl) {
    return (
      <div className="absolute inset-0 w-full h-full overflow-hidden bg-zinc-950">
        <Image
          src={imageUrl}
          alt={alt}
          fill
          unoptimized
          sizes="(max-width: 640px) 220px, 260px"
          className="object-cover transition-transform duration-500 group-hover:scale-105 pointer-events-none"
          priority
        />
      </div>
    )
  }

  return (
    <div className="w-full h-full bg-zinc-900 flex items-center justify-center text-zinc-600">
      <Sparkles className="h-8 w-8" />
    </div>
  )
}

export function CuratedBrandOffersCarousel({
  initialBanners,
  mode = 'grocery',
  sectionTitle = 'Top Brands & Exclusive Spotlights',
}: {
  initialBanners?: any[]
  mode?: 'grocery' | 'food' | 'all'
  sectionTitle?: string
}) {
  const scrollRef = useRef<HTMLDivElement>(null)

  const cards = useMemo(() => {
    const raw = initialBanners && initialBanners.length > 0 ? initialBanners : []
    const modeFiltered = raw.filter((b: any) => {
      const bType = (b.type || 'grocery').toLowerCase()
      const isFood = bType === 'food' || bType === 'cafe' || (b.linkUrl && b.linkUrl.startsWith('/restaurant')) || (b.ctaUrl && b.ctaUrl.startsWith('/restaurant'))
      if (mode === 'food') return isFood
      if (mode === 'grocery') return !isFood
      return true
    })
    const cleanBanners = modeFiltered.filter((b: any) => {
      const hasMedia = (b.imageUrl && b.imageUrl.trim().length > 0) || (b.videoUrl && b.videoUrl.trim().length > 0)
      if (!hasMedia || b.isActive === false) return false
      if (b.platform && b.platform !== 'all' && b.platform !== 'web') return false

      // Placement check: Show items explicitly created as brand_card or default brand cards
      const bPlacement = b.placement || (['dark_showcase', 'bento_grid', 'editorial', 'brand_offer', 'brand_card'].includes(b.type) ? 'brand_card' : 'brand_card')
      if (bPlacement !== 'brand_card' && b.placement) return false

      return true
    })

    // Zero dummy fallbacks: When user removes all brand cards or count is 0, return [] so section collapses completely to 0 height
    return cleanBanners
  }, [initialBanners, mode])

  const scroll = (direction: 'left' | 'right') => {
    if (!scrollRef.current) return
    const offset = direction === 'left' ? -300 : 300
    scrollRef.current.scrollBy({ left: offset, behavior: 'smooth' })
  }

  if (cards.length === 0) return null

  return (
    <section className="w-full relative z-10 space-y-2 sm:space-y-3 select-none" aria-label={sectionTitle}>
      {/* Shelf Header */}
      <div className="flex items-center justify-between px-1">
        <div className="flex items-center gap-2">
          <div className="h-6 w-6 sm:h-7 sm:w-7 rounded-lg sm:rounded-xl bg-primary/10 text-primary flex items-center justify-center font-black text-xs border border-primary/20">
            <Sparkles className="h-3 w-3 sm:h-3.5 sm:w-3.5" />
          </div>
          <div>
            <h2 className="text-sm min-[375px]:text-base sm:text-lg font-black text-text-primary tracking-tight">
              {sectionTitle}
            </h2>
          </div>
        </div>

        {/* Scroll Controls (Desktop) */}
        <div className="hidden sm:flex items-center gap-1.5">
          <button
            type="button"
            onClick={() => scroll('left')}
            className="h-8 w-8 rounded-full bg-card hover:bg-muted border border-border flex items-center justify-center text-text-primary shadow-xs transition-all active:scale-95 cursor-pointer"
            aria-label="Scroll left"
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
          <button
            type="button"
            onClick={() => scroll('right')}
            className="h-8 w-8 rounded-full bg-card hover:bg-muted border border-border flex items-center justify-center text-text-primary shadow-xs transition-all active:scale-95 cursor-pointer"
            aria-label="Scroll right"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Horizontal Multi-Card Shelf (Balanced 195x265 / 240x330 Proportions, Zero Text Overlay) */}
      <div
        ref={scrollRef}
        className="flex items-center gap-2.5 sm:gap-3.5 overflow-x-auto scrollbar-none py-0.5 px-0.5 scroll-smooth"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
      >
        {cards.map((card, idx) => {
          const targetUrl = card.linkUrl || card.ctaUrl || (mode === 'food' ? '/restaurant' : '/category/fruits-vegetables')
          return (
            <div
              key={card.id || idx}
              className="relative w-[170px] min-[375px]:w-[195px] sm:w-[240px] h-[235px] min-[375px]:h-[265px] sm:h-[330px] rounded-[18px] sm:rounded-[24px] overflow-hidden bg-neutral-900 border border-black/10 dark:border-white/15 shadow-md hover:shadow-xl transition-all duration-300 hover:scale-[1.015] active:scale-[0.985] shrink-0 group cursor-pointer"
            >
              <Link href={targetUrl} prefetch={false} className="relative block w-full h-full">
                <BrandCardMedia
                  imageUrl={card.imageUrl}
                  videoUrl={card.videoUrl}
                  alt={card.title || 'Brand Offer Card'}
                />

                {/* Subtle Inner Glass Rim */}
                <div className="absolute inset-0 rounded-[18px] sm:rounded-[24px] border border-white/10 pointer-events-none" />
              </Link>
            </div>
          )
        })}
      </div>
    </section>
  )
}
