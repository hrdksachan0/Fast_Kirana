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

  const discountParts = restaurant.discountOffer?.split(' UPTO ') || []
  const mainOffer = discountParts[0] || ''
  const uptoAmount = discountParts[1] || ''

  const operatingStatus = checkStoreOperatingStatus(restaurant)

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: index * 0.05, ease: 'easeOut' }}
    >
      <Link
        href={`/food/${restaurant.slug}`}
        className="block group"
      >
        <div className={cn(
          "relative bg-white dark:bg-zinc-900/80 rounded-2xl border border-zinc-100 dark:border-zinc-800/60",
          "shadow-[0_2px_12px_rgba(0,0,0,0.04)] dark:shadow-none",
          "hover:shadow-[0_4px_24px_rgba(0,0,0,0.08)] dark:hover:shadow-[0_4px_24px_rgba(0,0,0,0.3)]",
          "transition-all duration-300 overflow-hidden",
          !operatingStatus.isOpen && "opacity-60"
        )}>
          <div className="flex gap-3 p-3">
            {/* Left: Restaurant Image with Offer Overlay */}
            <div className="relative w-[130px] h-[145px] sm:w-[150px] sm:h-[160px] flex-shrink-0 rounded-xl overflow-hidden bg-zinc-100 dark:bg-zinc-800">
              {restaurant.bannerUrl || restaurant.logoUrl ? (
                <Image
                  src={restaurant.bannerUrl || restaurant.logoUrl || ''}
                  alt={restaurant.name}
                  fill
                  className="object-cover group-hover:scale-105 transition-transform duration-500"
                  sizes="150px"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-4xl bg-gradient-to-br from-orange-50 to-amber-100 dark:from-zinc-800 dark:to-zinc-700">
                  🍽️
                </div>
              )}

              {/* Favourite Heart */}
              <button
                onClick={handleFavourite}
                className="absolute top-2 right-2 z-10"
              >
                <Heart
                  size={22}
                  className={cn(
                    "drop-shadow-md transition-all duration-200",
                    isFavourite
                      ? "fill-red-500 text-red-500 scale-110"
                      : "fill-white/70 text-white stroke-[2]"
                  )}
                />
              </button>

              {/* Closed Badge with Schedule */}
              {!operatingStatus.isOpen && (
                <div className="absolute inset-0 bg-black/60 backdrop-blur-[2px] flex items-center justify-center p-2 text-center">
                  <span className="bg-rose-600 text-white text-[9px] font-black px-2.5 py-1 rounded-full uppercase tracking-wider shadow-md">
                    {operatingStatus.formattedScheduleStr || 'Closed'}
                  </span>
                </div>
              )}
            </div>

            {/* Right: Restaurant Info */}
            <div className="flex-1 min-w-0 py-0.5 flex flex-col justify-between">
              <div>
                {/* Pure Veg Badge */}
                {restaurant.isPureVeg && (
                  <div className="flex items-center gap-1 mb-1">
                    <Leaf size={12} className="text-green-600" />
                    <span className="text-[10px] font-bold text-green-700 dark:text-green-500 uppercase tracking-wide">
                      Pure Veg
                    </span>
                  </div>
                )}

                {/* Restaurant Name */}
                <h3 className="text-[15px] font-black text-zinc-900 dark:text-zinc-100 truncate leading-tight mb-0.5 group-hover:text-orange-600 dark:group-hover:text-orange-400 transition-colors">
                  {restaurant.name}
                </h3>


                {/* Cuisine Tags */}
                <p className="text-[11px] text-zinc-500 dark:text-zinc-500 font-medium truncate mb-0.5">
                  {restaurant.cuisineTags?.join(', ') || 'Multi-cuisine'}
                </p>

                {/* Address */}
                <p className="text-[11px] text-zinc-400 dark:text-zinc-600 font-medium truncate">
                  {restaurant.address || restaurant.city}
                </p>
              </div>
            </div>

            {/* 3-dot Menu */}
            <button
              onClick={(e) => { e.preventDefault(); e.stopPropagation() }}
              className="absolute top-3 right-3 p-1 text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300 transition-colors"
            >
              <MoreVertical size={16} />
            </button>
          </div>
        </div>
      </Link>
    </motion.div>
  )
}
