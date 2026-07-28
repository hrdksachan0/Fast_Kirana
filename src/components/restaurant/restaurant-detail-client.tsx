'use client'

import React, { useState, useEffect, useRef, useMemo } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import { Star, Clock, MapPin, Search, Leaf, ChevronRight, Info, Check, ArrowLeft, Heart, Share2, ShoppingBag, X } from 'lucide-react'
import { ProductCard } from '@/components/product/product-card'
import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { useCart } from '@/hooks/use-cart'
import { DEFAULT_RESTAURANT_MENU_SECTIONS } from '@/lib/constants'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'

interface RestaurantDetailClientProps {
  restaurant: any;
  products: any[];
}

export function RestaurantDetailClient({ restaurant, products }: RestaurantDetailClientProps) {
  const router = useRouter()
  const [searchQuery, setSearchQuery] = useState('')
  const [isVegOnly, setIsVegOnly] = useState(restaurant.isPureVeg || false)
  const [activeCategoryTag, setActiveCategoryTag] = useState<string>('all')
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set())
  const isClickingTabRef = useRef(false)
  const { items } = useCart()

  // Generate categories from products and menu sections
  const categories = useMemo(() => {
    let sections = restaurant.menuSections ? (typeof restaurant.menuSections === 'string' ? JSON.parse(restaurant.menuSections) : restaurant.menuSections) : DEFAULT_RESTAURANT_MENU_SECTIONS
    
    // Filter products
    let filteredProducts = products
    if (isVegOnly) {
      filteredProducts = filteredProducts.filter(p => p.isVeg || p.tags?.includes('veg') || p.tags?.includes('pure-veg'))
    }
    if (searchQuery) {
      const q = searchQuery.toLowerCase()
      filteredProducts = filteredProducts.filter(p => p.name.toLowerCase().includes(q) || p.description?.toLowerCase().includes(q))
    }

    const catsWithProducts = sections.map((sec: any) => {
      const secProducts = filteredProducts.filter((p: any) => {
        // match by category slug or tags
        const pTags = p.tags || []
        const pCat = p.category?.slug || ''
        return sec.matchTags?.some((tag: string) => pTags.includes(tag) || pCat.includes(tag)) || false
      })
      return {
        ...sec,
        products: secProducts
      }
    }).filter((c: any) => c.products.length > 0)

    // Add 'All' category if missing
    return [{ tag: 'all', title: 'All', emoji: '🍽️', products: filteredProducts }, ...catsWithProducts]
  }, [products, isVegOnly, searchQuery, restaurant.menuSections])

  const toggleCategoryExpand = (tag: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev)
      if (next.has(tag)) next.delete(tag)
      else next.add(tag)
      return next
    })
  }

  // ScrollSpy
  useEffect(() => {
    if (categories.length === 0) return

    let rafId: number
    const handleScroll = () => {
      cancelAnimationFrame(rafId)
      rafId = requestAnimationFrame(() => {
        if (isClickingTabRef.current) return

        const categorySections = categories
          .filter((c: any) => c.tag !== 'all')
          .map((c: any) => ({
            tag: c.tag,
            el: document.getElementById(`restaurant-section-${c.tag}`)
          }))
          .filter((c: any): c is { tag: string; el: HTMLElement } => c.el !== null)

        if (categorySections.length === 0) return

        const offsetTop = 200
        let currentActiveTag = 'all'

        for (let i = 0; i < categorySections.length; i++) {
          const rect = categorySections[i].el.getBoundingClientRect()
          if (rect.top <= offsetTop && rect.bottom > offsetTop) {
            currentActiveTag = categorySections[i].tag
            break
          } else if (rect.top < offsetTop) {
            currentActiveTag = categorySections[i].tag
          }
        }

        const firstSecTop = categorySections[0]?.el.getBoundingClientRect().top
        if (firstSecTop !== undefined && firstSecTop > offsetTop + 60) {
          currentActiveTag = 'all'
        }

        setActiveCategoryTag(prev => {
          if (prev !== currentActiveTag) {
            const categoryTabEl = document.getElementById(`restaurant-category-tab-${currentActiveTag}`)
            if (categoryTabEl) {
              categoryTabEl.scrollIntoView({
                behavior: 'smooth',
                block: 'nearest',
                inline: 'center'
              })
            }
            return currentActiveTag
          }
          return prev
        })
      })
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => {
      window.removeEventListener('scroll', handleScroll)
      cancelAnimationFrame(rafId)
    }
  }, [categories])

  // Cart total matching restaurant items
  const restaurantProductIds = new Set(products.map(p => p.id))
  const cartItemsFromRestaurant = items.filter(item => restaurantProductIds.has(item.product.id) || restaurantProductIds.has(item.product.id.split('_')[0]))
  
  const cartItemCount = cartItemsFromRestaurant.reduce((acc, item) => acc + item.quantity, 0)
  const cartTotal = cartItemsFromRestaurant.reduce((acc, item) => acc + (item.product.price * item.quantity), 0)

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 pb-24">
      {/* Header / Hero Section */}
      <div className="relative w-full h-[220px] md:h-[280px]">
        {/* Banner Image */}
        {restaurant.bannerUrl ? (
          <Image
            src={restaurant.bannerUrl}
            alt={restaurant.name}
            fill
            className="object-cover"
            priority
          />
        ) : (
          <div className="absolute inset-0 bg-gradient-to-r from-red-600 to-orange-500" />
        )}
        {/* Gradient Overlay for Text Readability */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent" />
        
        {/* Top Nav (Back, Share, Like) */}
        <div className="absolute top-0 left-0 right-0 p-4 flex items-center justify-between z-10">
          <button 
            onClick={() => {
              triggerHaptic('light')
              router.back()
            }} 
            className="w-10 h-10 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white active:scale-95 transition-transform"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="flex gap-2">
            <button 
              onClick={() => {
                triggerHaptic('light')
                toast.success('Restaurant link copied!')
              }}
              className="w-10 h-10 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white active:scale-95 transition-transform"
            >
              <Share2 className="w-5 h-5" />
            </button>
            <button 
              onClick={() => {
                triggerHaptic('medium')
                toast.success('Added to favorites!')
              }}
              className="w-10 h-10 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white active:scale-95 transition-transform"
            >
              <Heart className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Restaurant Info (Bottom of Hero) */}
        <div className="absolute bottom-0 left-0 right-0 p-4 md:px-8 z-10 text-white">
          <div className="flex items-end gap-4">
            {/* Logo */}
            {restaurant.logoUrl && (
              <div className="w-16 h-16 md:w-20 md:h-20 rounded-2xl bg-white p-1 shrink-0 overflow-hidden shadow-lg border border-white/20">
                <Image src={restaurant.logoUrl} alt={restaurant.name} width={80} height={80} className="w-full h-full object-cover rounded-xl" />
              </div>
            )}
            <div className="flex-1 pb-1">
              <h1 className="text-2xl md:text-4xl font-black tracking-tight">{restaurant.name}</h1>
              <p className="text-sm md:text-base font-medium text-zinc-200 mt-1 line-clamp-1">
                {restaurant.cuisineTags?.join(', ') || restaurant.description}
              </p>
              
              <div className="flex items-center gap-3 mt-2 text-xs md:text-sm font-semibold">
                <div className="flex items-center gap-1 bg-black/40 backdrop-blur-sm px-2 py-0.5 rounded-md">
                  <MapPin className="w-3.5 h-3.5 text-zinc-300" />
                  <span>{restaurant.distance ? `${restaurant.distance} km` : 'Near you'}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="max-w-7xl mx-auto px-4 md:px-8 mt-4 md:mt-8">
        
        {/* Filters & Search */}
        <div className="flex flex-col sm:flex-row gap-3 mb-6 sticky top-[60px] z-20 bg-zinc-50/90 dark:bg-zinc-950/90 backdrop-blur-md py-2 border-b border-zinc-200/50 dark:border-zinc-800/50">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
            <input 
              type="text" 
              placeholder="Search in menu..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 rounded-xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 focus:outline-none focus:ring-2 focus:ring-red-500/50 text-sm font-medium"
            />
            {searchQuery && (
              <button onClick={() => setSearchQuery('')} className="absolute right-3 top-1/2 -translate-y-1/2">
                <X className="w-4 h-4 text-zinc-400" />
              </button>
            )}
          </div>
          
          <div className="flex gap-2 shrink-0">
            <button
              onClick={() => {
                triggerHaptic('light')
                setIsVegOnly(!isVegOnly)
              }}
              className={cn(
                "flex items-center gap-1.5 px-3 py-2 rounded-xl border text-sm font-bold transition-all",
                isVegOnly 
                  ? "bg-green-50 dark:bg-green-900/20 border-green-500 text-green-700 dark:text-green-400" 
                  : "bg-white dark:bg-zinc-900 border-zinc-200 dark:border-zinc-800 text-zinc-600 dark:text-zinc-400"
              )}
            >
              <span className={cn("w-3 h-3 border rounded-sm flex items-center justify-center", isVegOnly ? "border-green-600" : "border-zinc-400")}>
                <span className={cn("w-1.5 h-1.5 rounded-full", isVegOnly ? "bg-green-600" : "bg-transparent")} />
              </span>
              Veg Only
            </button>
          </div>
        </div>

        {/* Menu Layout: Sidebar + Grid */}
        <div className="flex flex-row items-start w-full gap-3 sm:gap-6">
          
          {/* Left Vertical Category Sidebar */}
          <aside 
            id="restaurant-menu-categories-anchor" 
            className="sticky top-[130px] md:top-[120px] z-30 w-[85px] sm:w-[120px] md:w-[220px] shrink-0 max-h-[calc(100vh-140px)] overflow-y-auto scrollbar-none py-1 space-y-1.5 select-none border-r border-zinc-200/60 dark:border-zinc-800/60 pr-1.5 sm:pr-2"
          >
            <div className="pb-2 px-1 hidden md:block">
              <h4 className="text-xs font-black uppercase tracking-wider text-zinc-400">
                Menu
              </h4>
            </div>

            {categories.map((cat: any) => {
              const isActive = activeCategoryTag === cat.tag
              
              return (
                <button
                  key={cat.tag}
                  id={`restaurant-category-tab-${cat.tag}`}
                  onClick={(e) => {
                    e.preventDefault()
                    isClickingTabRef.current = true
                    setActiveCategoryTag(cat.tag)

                    const categoryTabEl = document.getElementById(`restaurant-category-tab-${cat.tag}`)
                    if (categoryTabEl) {
                      categoryTabEl.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' })
                    }

                    const targetId = cat.tag === 'all' ? 'restaurant-menu-categories-anchor' : `restaurant-section-${cat.tag}`
                    const target = document.getElementById(targetId)
                    if (target) {
                      target.scrollIntoView({ behavior: 'smooth', block: 'start' })
                    }
                    triggerHaptic('light')

                    setTimeout(() => {
                      isClickingTabRef.current = false
                    }, 800)
                  }}
                  className={cn(
                    "w-full flex flex-col md:flex-row items-center gap-1.5 md:gap-3 p-2 md:px-3 md:py-2.5 rounded-2xl transition-all duration-200 text-center md:text-left outline-none group cursor-pointer border-l-4",
                    isActive 
                      ? "bg-red-500/10 dark:bg-red-500/15 border-[#e20a22] text-[#e20a22] dark:text-red-400 font-black shadow-sm" 
                      : "border-transparent text-zinc-600 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-900"
                  )}
                >
                  <div 
                    className={cn(
                      "relative w-10 h-10 md:w-9 md:h-9 rounded-full overflow-hidden shrink-0 border transition-all duration-300 bg-white dark:bg-zinc-900 flex items-center justify-center p-0.5",
                      isActive 
                        ? "border-[#e20a22] scale-105" 
                        : "border-zinc-200 dark:border-zinc-800"
                    )}
                  >
                    <div className="relative w-full h-full rounded-full overflow-hidden bg-zinc-50 dark:bg-zinc-800 flex items-center justify-center">
                      {cat.image || cat.imageUrl ? (
                        <Image
                          src={cat.image || cat.imageUrl || ''}
                          alt={cat.title}
                          fill
                          sizes="40px"
                          className="object-cover"
                        />
                      ) : (
                        <span className="text-lg">{cat.emoji}</span>
                      )}
                    </div>
                  </div>
                  <span className="text-[10px] sm:text-xs font-bold leading-tight md:text-sm line-clamp-2">
                    {cat.title}
                  </span>
                </button>
              )
            })}
          </aside>

          {/* Right Main Content (Products) */}
          <main className="flex-1 min-w-0 pb-10">
            {categories.filter((c: any) => c.tag !== 'all').length === 0 && (
              <div className="text-center py-20 text-zinc-500 font-medium">
                No items found matching your filters.
              </div>
            )}
            
            {categories.filter((c: any) => c.tag !== 'all').map((cat: any) => {
              const displayProducts = cat.products.slice(0, 50) // Adjust as needed
              const isExpanded = expandedCategories.has(cat.tag) || searchQuery !== ''

              return (
                <div 
                  key={cat.tag} 
                  id={`restaurant-section-${cat.tag}`}
                  className="space-y-4 pt-6 border-t border-zinc-200/50 dark:border-zinc-800/40 first:border-t-0 scroll-mt-32"
                >
                  <div className="flex items-center justify-between px-1">
                    <div className="flex flex-col">
                      <h2 className="text-lg md:text-xl font-black text-zinc-900 dark:text-zinc-100">
                        {cat.title}
                      </h2>
                      {cat.description && (
                        <p className="text-xs font-medium text-zinc-500 mt-0.5">{cat.description}</p>
                      )}
                    </div>
                    
                    {!searchQuery && cat.products.length > 4 && (
                      <button
                        onClick={() => toggleCategoryExpand(cat.tag)}
                        className="text-xs font-bold px-3 py-1.5 rounded-full bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 hover:bg-zinc-200 dark:hover:bg-zinc-700 transition-colors shrink-0 flex items-center gap-1"
                      >
                        {isExpanded ? 'View Less' : `View All (${cat.products.length})`}
                        <ChevronRight className={cn("w-3.5 h-3.5 transition-transform", isExpanded && "rotate-90")} />
                      </button>
                    )}
                  </div>
                  
                  {isExpanded ? (
                    <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4 px-1">
                      {cat.products.map((p: any) => (
                        <ProductCard key={p.id} product={p} />
                      ))}
                    </div>
                  ) : (
                    <div className="flex gap-3 sm:gap-4 overflow-x-auto pb-4 pt-1 px-1 scrollbar-hide snap-x snap-mandatory">
                      {displayProducts.map((p: any) => (
                        <div key={p.id} className="w-[160px] sm:w-[190px] md:w-[220px] shrink-0 snap-start">
                          <ProductCard product={p} />
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )
            })}
          </main>
        </div>
      </div>

      {/* Sticky Cart Footer */}
      <AnimatePresence>
        {cartItemCount > 0 && (
          <motion.div
            initial={{ y: 100, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 100, opacity: 0 }}
            className="fixed bottom-4 left-4 right-4 md:left-auto md:right-8 md:w-[350px] z-50 bg-[#e20a22] text-white rounded-2xl shadow-2xl p-4 flex items-center justify-between cursor-pointer active:scale-[0.98] transition-transform"
            onClick={() => router.push('/cart')}
          >
            <div className="flex flex-col">
              <span className="text-xs font-bold text-white/80 uppercase tracking-wider">{cartItemCount} item{cartItemCount > 1 ? 's' : ''} added</span>
              <span className="text-lg font-black mt-0.5">₹{cartTotal.toFixed(2)}</span>
            </div>
            
            <div className="flex items-center gap-2 font-black text-sm uppercase tracking-wide bg-white text-[#e20a22] px-4 py-2 rounded-xl">
              View Cart
              <ShoppingBag className="w-4 h-4" />
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
