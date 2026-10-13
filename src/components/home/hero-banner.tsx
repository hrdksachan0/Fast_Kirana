'use client'

import { useRef, useMemo } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { motion } from 'framer-motion'
import { ChevronLeft, ChevronRight } from 'lucide-react'

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
  ctaUrl?: string | null
  isActive?: boolean
}

export function HeroBanner({
  initialBanners,
  mode = 'grocery',
}: {
  initialBanners?: any[]
  mode?: 'grocery' | 'food' | 'all'
}) {
  const scrollRef = useRef<HTMLDivElement>(null)

  const displayBanners = useMemo(() => {
    const raw = initialBanners || []
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
    return cleanBanners
  }, [initialBanners, mode])

  const scroll = (direction: 'left' | 'right') => {
    if (!scrollRef.current) return
    const offset = direction === 'left' ? -260 : 260
    scrollRef.current.scrollBy({ left: offset, behavior: 'smooth' })
  }

  if (displayBanners.length === 0) return null

  return (
    <div className="w-full relative z-10 group/banner select-none py-1">
      {/* Desktop Left / Right Navigation Buttons */}
      {displayBanners.length > 2 && (
        <>
          <button
            type="button"
            onClick={() => scroll('left')}
            className="hidden md:flex absolute -left-3 top-1/2 -translate-y-1/2 z-20 h-9 w-9 rounded-full bg-white/90 dark:bg-zinc-900/90 border border-zinc-200 dark:border-zinc-800 items-center justify-center text-zinc-800 dark:text-zinc-200 shadow-lg hover:scale-105 active:scale-95 transition-all cursor-pointer opacity-0 group-hover/banner:opacity-100"
            aria-label="Scroll left"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          <button
            type="button"
            onClick={() => scroll('right')}
            className="hidden md:flex absolute -right-3 top-1/2 -translate-y-1/2 z-20 h-9 w-9 rounded-full bg-white/90 dark:bg-zinc-900/90 border border-zinc-200 dark:border-zinc-800 items-center justify-center text-zinc-800 dark:text-zinc-200 shadow-lg hover:scale-105 active:scale-95 transition-all cursor-pointer opacity-0 group-hover/banner:opacity-100"
            aria-label="Scroll right"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        </>
      )}

      {/* Horizontal Multi-Status Card Row (WhatsApp / Instagram Stories Style) */}
      <div
        ref={scrollRef}
        className="flex items-center gap-2.5 sm:gap-3.5 overflow-x-auto scrollbar-none px-1 py-1 scroll-smooth"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
      >
        {displayBanners.map((banner: any, idx: number) => {
          const targetUrl =
            banner.linkUrl ||
            banner.ctaUrl ||
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
              whileTap={{ scale: 0.96 }}
              className="relative w-[180px] min-[375px]:w-[205px] sm:w-[245px] md:w-[275px] h-[255px] min-[375px]:h-[290px] sm:h-[345px] md:h-[390px] rounded-[20px] sm:rounded-[24px] overflow-hidden bg-zinc-900 border border-black/10 dark:border-white/10 shadow-md hover:shadow-xl transition-all duration-300 shrink-0 group cursor-pointer"
            >
              <Link href={targetUrl} prefetch={false} className="relative block w-full h-full">
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
                      alt={banner.title || 'Status Banner'}
                      fill
                      sizes="(max-width: 768px) 210px, 280px"
                      className="object-cover transition-transform duration-500 group-hover:scale-105 select-none"
                      priority={idx < 2}
                    />
                  )
                )}

                {/* Subtle Glass Rim Overlay */}
                <div className="absolute inset-0 rounded-[20px] sm:rounded-[24px] border border-white/15 pointer-events-none" />
              </Link>
            </motion.div>
          )
        })}
      </div>
    </div>
  )
}
