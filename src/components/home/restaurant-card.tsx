'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Star, Heart, Clock, MapPin, Bike, Sparkles, ShieldCheck } from 'lucide-react'
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
  const offerText = restaurant.discountOffer || restaurant.discountBadge || '50% OFF UPTO ₹100'
  const ratingVal = restaurant.rating > 0 ? restaurant.rating : 4.3

  // Resolve cuisines
  const cuisinesList = restaurant.cuisineTags && restaurant.cuisineTags.length > 0
    ? restaurant.cuisineTags.slice(0, 3).join(', ')
    : 'North Indian, Fast Food, Biryani'

  // Image resolution
  const effectiveImage = restaurant.bannerUrl || 
    (restaurant.slug?.includes('as-') || restaurant.name?.toLowerCase().includes('a.s') 
      ? '/as_restaurant_banner.webp' 
      : restaurant.slug?.includes('wedson') 
        ? '/wedson_restaurant_banner.webp' 
        : restaurant.logoUrl || 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80')

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.28, delay: index * 0.04, ease: 'easeOut' }}
    >
      <Link
        href={`/food/${restaurant.slug}`}
        prefetch={false}
        className="block group"
      >
        <div className={cn(
          "relative bg-white dark:bg-zinc-900 rounded-2xl border border-zinc-200/80 dark:border-zinc-800/80",
          "shadow-xs hover:shadow-xl hover:border-zinc-300 dark:hover:border-zinc-700",
          "transition-all duration-300 overflow-hidden flex flex-col -translate-y-0 hover:-translate-y-1",
          !operatingStatus.isOpen && "opacity-75"
        )}>
          {/* 1. TOP HERO IMAGE BANNER (Full Width, 16:9 ~ 200px) */}
          <div className="relative w-full h-48 sm:h-52 overflow-hidden bg-zinc-100 dark:bg-zinc-800">
            <Image
              src={effectiveImage}
              alt={restaurant.name}
              fill
              className="object-cover group-hover:scale-105 transition-transform duration-500 ease-out"
              sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
            />

            {/* Gradient Overlays for Readability */}
            <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-black/85 via-black/40 to-transparent pointer-events-none" />
            <div className="absolute inset-x-0 top-0 h-14 bg-gradient-to-b from-black/40 to-transparent pointer-events-none" />

            {/* Top-Left Badges: Pure Veg / Top Rated */}
            <div className="absolute top-2.5 left-2.5 z-10 flex items-center gap-1.5 flex-wrap">
              {restaurant.isPureVeg && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-white/95 dark:bg-zinc-900/95 backdrop-blur-xs text-[10px] font-extrabold text-emerald-700 dark:text-emerald-400 border border-emerald-500/30 shadow-xs">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-600 animate-pulse" />
                  Pure Veg
                </span>
              )}
              {ratingVal >= 4.5 && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-amber-500 text-white text-[9px] font-black uppercase tracking-wider shadow-xs">
                  🏆 Top Rated
                </span>
              )}
            </div>

            {/* Top-Right: Favorite Heart Button */}
            <button
              onClick={handleFavourite}
              aria-label="Add to favorites"
              className="absolute top-2.5 right-2.5 z-10 w-8 h-8 rounded-full bg-black/35 hover:bg-black/55 backdrop-blur-md flex items-center justify-center transition-all cursor-pointer shadow-sm"
            >
              <Heart
                size={17}
                className={cn(
                  "drop-shadow transition-all duration-200",
                  isFavourite
                    ? "fill-red-500 text-red-500 scale-110"
                    : "fill-black/30 text-white stroke-[2]"
                )}
              />
            </button>



            {/* Closed Overlay */}
            {!operatingStatus.isOpen && (
              <div className="absolute inset-0 bg-black/70 backdrop-blur-[2px] flex flex-col items-center justify-center p-3 text-center z-20">
                <span className="bg-rose-600 text-white text-xs font-black px-3 py-1 rounded-full uppercase tracking-wider shadow-lg">
                  Closed Now
                </span>
                <span className="text-[11px] text-zinc-200 mt-1 font-semibold">
                  Opens {operatingStatus.formattedScheduleStr || 'Tomorrow'}
                </span>
              </div>
            )}
          </div>

          {/* 2. CARD CONTENT DETAILS (Zomato Hierarchy) */}
          <div className="p-3.5 sm:p-4 flex flex-col flex-1 justify-between gap-1.5">
            <div>
              {/* Row 1: Restaurant Name + Signature Green Rating Pill */}
              <div className="flex items-center justify-between gap-2">
                <h3 className="text-base sm:text-[17px] font-black text-zinc-900 dark:text-zinc-100 group-hover:text-red-600 dark:group-hover:text-red-400 transition-colors truncate tracking-tight">
                  {restaurant.name}
                </h3>
                
                {/* Zomato Green Rating Badge */}
                <div className="flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-[#24963F] text-white font-black text-xs shadow-xs shrink-0 tracking-wide">
                  <span>{ratingVal.toFixed(1)}</span>
                  <Star size={10} className="fill-white stroke-none" />
                </div>
              </div>

              {/* Row 2: Cuisines */}
              <div className="text-xs sm:text-[13px] text-zinc-500 dark:text-zinc-400 font-medium mt-1 truncate">
                {cuisinesList}
              </div>

              {/* Row 3: Location / Area */}
              <div className="flex items-center gap-1 text-[11px] sm:text-xs text-zinc-400 dark:text-zinc-500 font-medium truncate mt-1">
                <MapPin size={12} className="text-zinc-400 shrink-0" />
                <span className="truncate">{restaurant.address || restaurant.city || 'Ghatampur Market'}</span>
              </div>
            </div>

            {/* Dashed Separator */}
            <div className="border-t border-dashed border-zinc-200 dark:border-zinc-800 my-1" />

            {/* Row 4: Zomato Footer Strip (Safety / Free Delivery & Menu CTA) */}
            <div className="flex items-center justify-between text-[11px] text-zinc-500 dark:text-zinc-400 font-medium">
              <div className="flex items-center gap-1.5 truncate">
                <Bike size={13} className="text-emerald-600 dark:text-emerald-400 shrink-0" />
                <span className="truncate font-semibold text-zinc-700 dark:text-zinc-300">
                  Free Delivery above ₹149
                </span>
              </div>

              <span className="font-bold text-red-600 dark:text-red-400 group-hover:translate-x-0.5 transition-transform flex items-center gap-0.5 shrink-0 pl-2">
                Menu →
              </span>
            </div>
          </div>
        </div>
      </Link>
    </motion.div>
  )
}

