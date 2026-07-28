'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import { RestaurantCard } from '@/components/home/restaurant-card'
import { Restaurant } from '@/types'
import { cn } from '@/lib/utils'
import { motion, AnimatePresence } from 'framer-motion'
import { SlidersHorizontal, ChevronDown, Leaf, Tag, Star, Search, X, Loader2 } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'

// Cuisine category pills with icons
const CUISINE_CATEGORIES = [
  { id: 'all', label: 'All', emoji: '🍽️' },
  { id: 'specials', label: 'Specials', emoji: '🔥' },
  { id: 'rolls', label: 'Rolls', emoji: '🌯' },
  { id: 'biryani', label: 'Biryani', emoji: '🍚' },
  { id: 'cakes', label: 'Cakes', emoji: '🎂' },
  { id: 'naan', label: 'Naan', emoji: '🫓' },
  { id: 'burgers', label: 'Burgers', emoji: '🍔' },
  { id: 'chinese', label: 'Chinese', emoji: '🥡' },
  { id: 'pizza', label: 'Pizza', emoji: '🍕' },
  { id: 'south-indian', label: 'South Indian', emoji: '🍛' },
  { id: 'beverages', label: 'Beverages', emoji: '☕' },
  { id: 'desserts', label: 'Desserts', emoji: '🍨' },
  { id: 'fast-food', label: 'Fast Food', emoji: '🍟' },
  { id: 'indian', label: 'Indian', emoji: '🥘' },
]

type SortOption = 'relevance' | 'rating' | 'delivery_time' | 'distance'

interface RestaurantListingProps {
  initialRestaurants?: Restaurant[]
}

export function RestaurantListing({ initialRestaurants }: RestaurantListingProps) {
  const [restaurants, setRestaurants] = useState<Restaurant[]>(initialRestaurants || [])
  const [isLoading, setIsLoading] = useState(!initialRestaurants)
  const [activeCuisine, setActiveCuisine] = useState('all')
  const [sortBy, setSortBy] = useState<SortOption>('relevance')
  const [showSortDropdown, setShowSortDropdown] = useState(false)
  const [pureVegOnly, setPureVegOnly] = useState(false)
  const [offersOnly, setOffersOnly] = useState(false)
  const [ratingFilter, setRatingFilter] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [showSearch, setShowSearch] = useState(false)
  const cuisineScrollRef = useRef<HTMLDivElement>(null)
  const sortRef = useRef<HTMLDivElement>(null)

  // Fetch restaurants from API
  useEffect(() => {
    if (initialRestaurants) return
    setIsLoading(true)
    fetch('/api/restaurants')
      .then(res => res.json())
      .then(data => {
        setRestaurants(Array.isArray(data) ? data : data.restaurants || [])
      })
      .catch(err => console.error('Failed to load restaurants:', err))
      .finally(() => setIsLoading(false))
  }, [initialRestaurants])

  // Close sort dropdown on outside click
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (sortRef.current && !sortRef.current.contains(e.target as Node)) {
        setShowSortDropdown(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  // Filter & sort restaurants
  const filteredRestaurants = useMemo(() => {
    let filtered = [...restaurants]

    // Cuisine filter
    if (activeCuisine !== 'all') {
      filtered = filtered.filter(r =>
        r.cuisineTags?.some(tag =>
          tag.toLowerCase().includes(activeCuisine.toLowerCase())
        )
      )
    }

    // Pure veg filter
    if (pureVegOnly) {
      filtered = filtered.filter(r => r.isPureVeg || r.isVeg)
    }

    // Offers filter
    if (offersOnly) {
      filtered = filtered.filter(r => r.discountOffer || r.discountBadge)
    }

    // Rating filter (4.0+)
    if (ratingFilter) {
      filtered = filtered.filter(r => r.rating >= 4.0)
    }

    // Search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(r =>
        r.name.toLowerCase().includes(query) ||
        r.cuisineTags?.some(t => t.toLowerCase().includes(query)) ||
        r.address?.toLowerCase().includes(query) ||
        r.city?.toLowerCase().includes(query)
      )
    }

    // Sort
    switch (sortBy) {
      case 'rating':
        filtered.sort((a, b) => b.rating - a.rating)
        break
      case 'delivery_time':
        filtered.sort((a, b) => {
          const getMinTime = (t: string) => parseInt(t.match(/\d+/)?.[0] || '999')
          return getMinTime(a.deliveryTime) - getMinTime(b.deliveryTime)
        })
        break
      case 'distance':
        filtered.sort((a, b) => {
          const getDist = (d: string | null) => parseFloat(d?.match(/[\d.]+/)?.[0] || '999')
          return getDist(a.distance) - getDist(b.distance)
        })
        break
      default:
        // Relevance — open first, then by sortOrder
        filtered.sort((a, b) => {
          if (a.isOpen !== b.isOpen) return a.isOpen ? -1 : 1
          return (b.sortOrder || 0) - (a.sortOrder || 0)
        })
    }

    return filtered
  }, [restaurants, activeCuisine, pureVegOnly, offersOnly, ratingFilter, searchQuery, sortBy])

  const activeFilterCount = [pureVegOnly, offersOnly, ratingFilter].filter(Boolean).length

  return (
    <div className="w-full">
      {/* Search Bar (collapsible) */}
      <AnimatePresence>
        {showSearch && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden mb-3"
          >
            <div className="relative">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400" />
              <input
                type="text"
                placeholder="Search restaurants, cuisines..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-9 py-2.5 rounded-xl bg-zinc-100 dark:bg-zinc-800/80 border border-zinc-200 dark:border-zinc-700 text-sm font-medium text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 focus:outline-none focus:ring-2 focus:ring-orange-500/40"
                autoFocus
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-400 hover:text-zinc-600"
                >
                  <X size={16} />
                </button>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Restaurant Count */}
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-black text-zinc-800 dark:text-zinc-200 tracking-tight">
          {filteredRestaurants.length} restaurant{filteredRestaurants.length !== 1 ? 's' : ''} near you
        </h2>
        {(activeCuisine !== 'all' || pureVegOnly || offersOnly || ratingFilter || searchQuery) && (
          <button
            onClick={() => {
              setActiveCuisine('all')
              setPureVegOnly(false)
              setOffersOnly(false)
              setRatingFilter(false)
              setSearchQuery('')
            }}
            className="text-[11px] font-bold text-orange-500 hover:text-orange-600 transition-colors"
          >
            Clear all
          </button>
        )}
      </div>

      {/* Restaurant List */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <Loader2 size={28} className="text-orange-500 animate-spin" />
          <p className="text-[12px] font-bold text-zinc-400">Finding restaurants near you...</p>
        </div>
      ) : filteredRestaurants.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <span className="text-4xl">🍽️</span>
          <p className="text-sm font-bold text-zinc-500 dark:text-zinc-400">No restaurants found</p>
          <p className="text-[11px] text-zinc-400">Try adjusting your filters</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {filteredRestaurants.map((restaurant, idx) => (
            <RestaurantCard
              key={restaurant.id}
              restaurant={restaurant}
              index={idx}
            />
          ))}
        </div>
      )}
    </div>
  )
}
