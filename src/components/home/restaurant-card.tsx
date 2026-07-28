'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Star, Heart, MoreVertical, Leaf } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Restaurant } from '@/types'
import { motion } from 'framer-motion'
import { triggerHaptic } from '@/lib/haptic'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'

interface RestaurantCardProps {
  restaurant: Restaurant
  index?: number
}

export function RestaurantCard({ restaurant, index = 0 }: RestaurantCardProps) {
  const [isFavourite, setIsFavourite] = useState(false)

  const handleFavourite = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')
    setIsFavourite(!isFavourite)
  }

  const operatingStatus = checkStoreOperatingStatus(restaurant)
  const offerText = restaurant.discountOffer || restaurant.discountBadge || 'FLAT 5% OFF'

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25, delay: index * 0.03, ease: 'easeOut' }}
    >
      <Link
        href={`/food/${restaurant.slug}`}
        className="block group"
      >
        <div className={cn(
          "relative bg-white dark:bg-zinc-900/90 rounded-2xl border border-zinc-200/80 dark:border-zinc-800/80",
          "shadow-2xs hover:shadow-md dark:shadow-none",
          "transition-all duration-300 overflow-hidden",
          !operatingStatus.isOpen && "opacity-60"
        )}>
          <div className="flex gap-3 p-3">
            {/* Left: Restaurant Image with Offer Overlay */}
            <div className="relative w-[110px] h-[130px] sm:w-[140px] sm:h-[145px] flex-shrink-0 rounded-xl overflow-hidden bg-zinc-100 dark:bg-zinc-800">
              {restaurant.bannerUrl || restaurant.logoUrl ? (
                <Image
                  src={restaurant.bannerUrl || restaurant.logoUrl || ''}
                  alt={restaurant.name}
                  fill
                  className="object-cover group-hover:scale-105 transition-transform duration-500"
                  sizes="140px"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-4xl bg-gradient-to-br from-orange-50 to-amber-100 dark:from-zinc-800 dark:to-zinc-700">
                  🍽️
                </div>
              )}

              {/* Favourite Heart */}
              <button
                onClick={handleFavourite}
                className="absolute top-1.5 right-1.5 z-10"
              >
                <Heart
                  size={19}
                  className={cn(
                    "drop-shadow-md transition-all duration-200",
                    isFavourite
                      ? "fill-red-500 text-red-500 scale-110"
                      : "fill-black/40 text-white stroke-[2]"
                  )}
                />
              </button>

              {/* Closed Badge with Schedule */}
              {!operatingStatus.isOpen && (
                <div className="absolute inset-0 bg-black/60 backdrop-blur-[2px] flex items-center justify-center p-2 text-center">
                  <span className="bg-rose-600 text-white text-[9px] font-black px-2 py-0.5 rounded-full uppercase tracking-wider shadow-md">
                    {operatingStatus.formattedScheduleStr || 'Closed'}
                  </span>
                </div>
              )}
            </div>

            {/* Right: Restaurant Info */}
            <div className="flex-1 min-w-0 flex flex-col justify-between py-0.5">
              <div className="space-y-1">
                
                {/* Full Width Restaurant Name */}
                <div className="pr-5">
                  <h3 className="text-sm sm:text-base font-black text-zinc-900 dark:text-zinc-100 leading-tight group-hover:text-orange-600 transition-colors line-clamp-1">
                    {restaurant.name}
                  </h3>
                </div>

                {/* Badges Row: Top Rated & Pure Veg */}
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-amber-500/10 text-amber-700 dark:text-amber-400 border border-amber-500/25 rounded-md text-[9px] font-black uppercase tracking-wider shrink-0">
                    🏆 Top Rated
                  </span>
                  {restaurant.isPureVeg && (
                    <span className="inline-flex items-center gap-0.5 text-[9px] font-extrabold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-1.5 py-0.5 rounded-md uppercase tracking-wide shrink-0">
                      <Leaf size={10} /> Pure Veg
                    </span>
                  )}
                </div>

                {/* Cuisine & Location */}
                <p className="text-[10.5px] text-zinc-500 dark:text-zinc-400 font-medium line-clamp-1">
                  {restaurant.cuisineTags?.join(', ') || 'Multi-cuisine'} · 📍 {restaurant.address || restaurant.city || 'Ghatampur'}
                </p>

                {/* Offer Banner Badge */}
                <div className="pt-0.5">
                  <span className="inline-block text-[9.5px] font-black text-orange-600 dark:text-orange-400 bg-orange-500/10 px-2 py-0.5 rounded-md border border-orange-500/20 leading-tight line-clamp-1">
                    🔥 {offerText}
                  </span>
                </div>

              </div>

              {/* Bottom Row: Fresh Prep + Explore Menu Button */}
              <div className="flex items-center justify-between gap-1.5 pt-1.5 border-t border-zinc-100 dark:border-zinc-800/80 mt-1">
                <span className="text-[9.5px] font-bold text-zinc-500 dark:text-zinc-400 flex items-center gap-1 shrink-0">
                  ⚡ 30m Prep
                </span>

                <div className="inline-flex items-center gap-1 px-2.5 py-1 bg-orange-600 hover:bg-orange-700 text-white rounded-lg text-[10px] font-black uppercase tracking-wider transition-all shadow-2xs group-hover:scale-105 shrink-0 cursor-pointer">
                  <span>Explore</span>
                  <span>→</span>
                </div>
              </div>

            </div>

            {/* 3-dot Menu */}
            <button
              onClick={(e) => { e.preventDefault(); e.stopPropagation() }}
              className="absolute top-2 right-2 p-1 text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300 transition-colors"
            >
              <MoreVertical size={14} />
            </button>
          </div>
        </div>
      </Link>
    </motion.div>
  )
}
