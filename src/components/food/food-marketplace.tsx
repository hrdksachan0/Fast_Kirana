'use client'

import { useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { motion } from 'framer-motion'
import { ArrowLeft, Search, SlidersHorizontal, Leaf, Clock, Star, Flame } from 'lucide-react'
import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { Restaurant } from '@/types'
import { RestaurantCard } from '@/components/home/restaurant-card'
import { FloatingEmojis } from '@/components/shared/floating-emojis'

const CUISINES = [
  { id: 'all', label: 'All 🍽️' },
  { id: 'pizza', label: 'Pizza 🍕' },
  { id: 'biryani', label: 'Biryani 🍚' },
  { id: 'chinese', label: 'Chinese 🥡' },
  { id: 'rolls', label: 'Rolls 🌯' },
  { id: 'burgers', label: 'Burgers 🍔' },
  { id: 'south-indian', label: 'South Indian 🍛' },
  { id: 'desserts', label: 'Desserts 🍨' },
  { id: 'cafe', label: 'Cafe ☕' },
  { id: 'north-indian', label: 'North Indian 🥘' }
]

type SortOption = 'relevance' | 'rating' | 'deliveryTime'

interface FoodMarketplaceProps {
  initialRestaurants: Restaurant[]
}

export function FoodMarketplace({ initialRestaurants }: FoodMarketplaceProps) {
  const router = useRouter()
  const [searchQuery, setSearchQuery] = useState('')
  const [activeCuisine, setActiveCuisine] = useState('all')
  const [isPureVeg, setIsPureVeg] = useState(false)
  const [hasOffers, setHasOffers] = useState(false)
  const [sortBy, setSortBy] = useState<SortOption>('relevance')

  // Filtering & Sorting Logic
  const filteredRestaurants = useMemo(() => {
    let result = [...initialRestaurants]

    // Search Filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      result = result.filter(
        r => r.name.toLowerCase().includes(q) || 
             r.cuisineTags?.some(tag => tag.toLowerCase().includes(q)) ||
             r.city?.toLowerCase().includes(q)
      )
    }

    // Cuisine Filter
    if (activeCuisine !== 'all') {
      const cuisineLabel = CUISINES.find(c => c.id === activeCuisine)?.label.split(' ')[0]
      if (cuisineLabel) {
        result = result.filter(r => 
          r.cuisineTags?.some(tag => tag.toLowerCase().includes(cuisineLabel.toLowerCase()))
        )
      }
    }

    // Pure Veg Filter
    if (isPureVeg) {
      result = result.filter(r => r.isPureVeg)
    }

    // Offers Filter
    if (hasOffers) {
      result = result.filter(r => !!r.discountOffer || !!r.discountBadge)
    }

    // Sorting
    switch (sortBy) {
      case 'rating':
        result.sort((a, b) => b.rating - a.rating)
        break
      case 'deliveryTime':
        result.sort((a, b) => {
          const timeA = parseInt(a.deliveryTime) || 999
          const timeB = parseInt(b.deliveryTime) || 999
          return timeA - timeB
        })
        break
      case 'relevance':
      default:
        result.sort((a, b) => {
          if (a.isOpen === b.isOpen) return (a.sortOrder || 0) - (b.sortOrder || 0)
          return a.isOpen ? -1 : 1
        })
    }

    return result
  }, [initialRestaurants, searchQuery, activeCuisine, isPureVeg, hasOffers, sortBy])

  return (
    <div className="w-full flex flex-col relative min-h-screen">
      <FloatingEmojis type="food" />
      {/* Sticky Header Banner */}
      <div className="sticky top-0 z-50 bg-white/80 dark:bg-zinc-950/80 backdrop-blur-md border-b border-zinc-200 dark:border-zinc-800 pt-safe-top">
        <div className="container mx-auto max-w-7xl px-4 py-3">
          <div className="flex items-center gap-3">
            <button 
              onClick={() => {
                triggerHaptic('light')
                router.back()
              }}
              className="p-2 -ml-2 rounded-full hover:bg-zinc-100 dark:hover:bg-zinc-900 transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-zinc-900 dark:text-zinc-100" />
            </button>
            <div className="flex-1">
              <h1 className="text-[22px] font-black text-zinc-900 dark:text-zinc-100 leading-none">Food Delivery</h1>
              <p className="text-[12px] font-bold text-zinc-500 dark:text-zinc-400 mt-1">Discover best restaurants</p>
            </div>
          </div>
          
          {/* Search Bar */}
          <div className="mt-4 relative">
            <div className="absolute inset-y-0 left-3 flex items-center pointer-events-none">
              <Search className="w-4 h-4 text-zinc-400" />
            </div>
            <input
              type="text"
              placeholder="Search for restaurants, cuisines..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-3 bg-zinc-100 dark:bg-zinc-900 border-none rounded-xl text-[14px] font-medium text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-500 focus:ring-2 focus:ring-orange-500 transition-all outline-none"
            />
          </div>
        </div>
      </div>

      <div className="container mx-auto max-w-7xl px-4 py-4 space-y-6">
        {/* Cuisine Filter Pills */}
        <div className="flex overflow-x-auto hide-scrollbar gap-2.5 pb-2 -mx-4 px-4 snap-x">
          {CUISINES.map((cuisine) => (
            <button
              key={cuisine.id}
              onClick={() => {
                triggerHaptic('light')
                setActiveCuisine(cuisine.id)
              }}
              className={cn(
                "whitespace-nowrap px-4 py-2 rounded-full text-[13px] font-black transition-all snap-start shadow-sm border",
                activeCuisine === cuisine.id
                  ? "bg-orange-100 dark:bg-orange-500/20 text-orange-600 dark:text-orange-400 border-orange-200 dark:border-orange-500/30"
                  : "bg-white dark:bg-zinc-900 text-zinc-700 dark:text-zinc-300 border-zinc-200 dark:border-zinc-800 hover:border-zinc-300 dark:hover:border-zinc-700"
              )}
            >
              {cuisine.label}
            </button>
          ))}
        </div>

        {/* Quick Filters */}
        <div className="flex items-center gap-2 overflow-x-auto hide-scrollbar pb-2">
          <button className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 text-[12px] font-black text-zinc-700 dark:text-zinc-300 shrink-0">
            <SlidersHorizontal className="w-3.5 h-3.5" />
            Sort
          </button>
          
          <button 
            onClick={() => {
              triggerHaptic('light')
              setIsPureVeg(!isPureVeg)
            }}
            className={cn(
              "flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-[12px] font-black shrink-0 transition-colors",
              isPureVeg 
                ? "border-green-500 bg-green-50 dark:bg-green-500/10 text-green-700 dark:text-green-500" 
                : "border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 text-zinc-700 dark:text-zinc-300"
            )}
          >
            <Leaf className={cn("w-3.5 h-3.5", isPureVeg ? "text-green-600 dark:text-green-500" : "")} />
            Pure Veg
          </button>

          <button 
            onClick={() => {
              triggerHaptic('light')
              setHasOffers(!hasOffers)
            }}
            className={cn(
              "flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-[12px] font-black shrink-0 transition-colors",
              hasOffers 
                ? "border-blue-500 bg-blue-50 dark:bg-blue-500/10 text-blue-700 dark:text-blue-500" 
                : "border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 text-zinc-700 dark:text-zinc-300"
            )}
          >
            <Flame className={cn("w-3.5 h-3.5", hasOffers ? "text-blue-600 dark:text-blue-500" : "")} />
            Offers
          </button>
        </div>

        {/* Sorting Options */}
        <div className="flex items-center gap-5 border-b border-zinc-200 dark:border-zinc-800 pb-3">
          <button 
            onClick={() => { triggerHaptic('light'); setSortBy('relevance') }}
            className={cn("text-[12px] font-black transition-colors relative", sortBy === 'relevance' ? "text-orange-600 dark:text-orange-500" : "text-zinc-500 hover:text-zinc-800 dark:hover:text-zinc-300")}
          >
            Relevance
            {sortBy === 'relevance' && (
              <motion.div layoutId="sort-indicator" className="absolute -bottom-3 left-0 right-0 h-0.5 bg-orange-600 dark:bg-orange-500 rounded-full" />
            )}
          </button>
          <button 
            onClick={() => { triggerHaptic('light'); setSortBy('rating') }}
            className={cn("text-[12px] font-black flex items-center gap-1 transition-colors relative", sortBy === 'rating' ? "text-orange-600 dark:text-orange-500" : "text-zinc-500 hover:text-zinc-800 dark:hover:text-zinc-300")}
          >
            Rating <Star className="w-3 h-3" />
            {sortBy === 'rating' && (
              <motion.div layoutId="sort-indicator" className="absolute -bottom-3 left-0 right-0 h-0.5 bg-orange-600 dark:bg-orange-500 rounded-full" />
            )}
          </button>
          <button 
            onClick={() => { triggerHaptic('light'); setSortBy('deliveryTime') }}
            className={cn("text-[12px] font-black flex items-center gap-1 transition-colors relative", sortBy === 'deliveryTime' ? "text-orange-600 dark:text-orange-500" : "text-zinc-500 hover:text-zinc-800 dark:hover:text-zinc-300")}
          >
            Delivery Time <Clock className="w-3 h-3" />
            {sortBy === 'deliveryTime' && (
              <motion.div layoutId="sort-indicator" className="absolute -bottom-3 left-0 right-0 h-0.5 bg-orange-600 dark:bg-orange-500 rounded-full" />
            )}
          </button>
        </div>

        {/* Restaurant Grid */}
        <div className="mt-4 pb-8">
          <h2 className="text-[16px] font-black text-zinc-900 dark:text-zinc-100 mb-4 tracking-tight">
            {filteredRestaurants.length} restaurants to explore
          </h2>
          
          {filteredRestaurants.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {filteredRestaurants.map((restaurant, idx) => (
                <RestaurantCard 
                  key={restaurant.id} 
                  restaurant={restaurant} 
                  index={idx}
                />
              ))}
            </div>
          ) : (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="flex flex-col items-center justify-center py-20 text-center"
            >
              <div className="w-24 h-24 bg-zinc-100 dark:bg-zinc-900 rounded-full flex items-center justify-center text-5xl mb-5 shadow-inner">
                🍽️
              </div>
              <h3 className="text-xl font-black text-zinc-900 dark:text-zinc-100 tracking-tight">No restaurants found</h3>
              <p className="text-[13px] font-bold text-zinc-500 max-w-[250px] mt-2">
                Try changing your filters or searching for something else.
              </p>
              <button 
                onClick={() => {
                  triggerHaptic('medium')
                  setSearchQuery('')
                  setActiveCuisine('all')
                  setIsPureVeg(false)
                  setHasOffers(false)
                }}
                className="mt-8 px-6 py-3 bg-orange-600 text-white text-[13px] font-black rounded-xl hover:bg-orange-700 transition-colors shadow-md shadow-orange-600/20 active:scale-95"
              >
                Clear Filters
              </button>
            </motion.div>
          )}
        </div>
      </div>
    </div>
  )
}
