'use client'

import React, { useState, useEffect, useRef, useMemo } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import { Star, Clock, MapPin, Search, Leaf, ArrowLeft, ShoppingBag, X, ChevronRight, RefreshCw, Moon } from 'lucide-react'
import { ProductCard } from '@/components/product/product-card'
import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { useCart } from '@/hooks/use-cart'
import { DEFAULT_CAFE_MENU_SECTIONS, DEFAULT_RESTAURANT_MENU_SECTIONS } from '@/lib/constants'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { formatDate } from '@/lib/date-helpers'
import { FloatingEmojis } from '@/components/shared/floating-emojis'

const getCafeSectionImage = (tag: string) => {
  const mapping: Record<string, string> = {
    'hot-beverage': '/cafe_brews_category.png',
    'hot-bite': '/cafe_snacks_category.png',
    'sandwiches': '/cafe_sandwiches_category.png',
    'frankie-rolls': '/cafe_rolls_category.png',
    'chinese': '/cafe_chinese_category.png',
    'italian-pasta': '/cafe_pasta_category.png',
    'bombay-bites': '/cafe_bombay_bites_category.png',
    'rice-dishes': '/cafe_rice_category.png',
    'shakes': '/cafe_shakes_category.png',
    'mocktails': '/cafe_mocktails_category.png',
    'cold-coffee': '/cafe_coffee_category.png',
    'south-indian': '/cafe_south_indian_category.png',
    'chilled': '/cafe_cold_drinks_category.png',
    'beverages': '/cafe_cold_drinks_category.png',
    'drinks': '/cafe_cold_drinks_category.png',
    'bakery': '/bakery_biscuits_category.png',
    'pizza': '/cafe_pizza_category.png',
    'burgers': '/cafe_burgers_category.png',
    'garlic-bread': '/cafe_garlic_bread_category.png',
    'desserts': '/ice_cream_category.png',
    'north-indian': '/cafe_south_indian_category.png',
    'biryani-rice': '/cafe_rice_category.png',
  }
  return mapping[tag] || null
}

interface RestaurantStorefrontProps {
  restaurant: any
  products: any[]
}

export function RestaurantStorefront({ restaurant, products }: RestaurantStorefrontProps) {
  const router = useRouter()
  const [searchQuery, setSearchQuery] = useState('')
  const [showSearch, setShowSearch] = useState(false)
  const [isVegOnly, setIsVegOnly] = useState(restaurant.isPureVeg || false)
  const [activeCategoryTag, setActiveCategoryTag] = useState<string>('all')
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set())
  const isClickingTabRef = useRef(false)
  const categoryTabsRef = useRef<HTMLDivElement>(null)
  const { items, getTotalItems, getSubtotal } = useCart()

  // Reviews states
  const [activeSubTab, setActiveSubTab] = useState<'menu' | 'reviews'>('menu')
  const [reviews, setReviews] = useState<any[]>([])
  const [reviewsLoading, setReviewsLoading] = useState(true)
  const [newRating, setNewRating] = useState(5)
  const [newComment, setNewComment] = useState('')
  const [isSubmittingReview, setIsSubmittingReview] = useState(false)

  const fetchReviews = async () => {
    try {
      const res = await fetch(`/api/restaurants/${restaurant.id}/reviews`)
      if (res.ok) {
        const data = await res.json()
        setReviews(data.reviews || [])
      }
    } catch (err) {
      console.error(err)
    } finally {
      setReviewsLoading(false)
    }
  }

  useEffect(() => {
    fetchReviews()
  }, [restaurant.id])

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault()
    if (newRating < 1 || newRating > 5) return
    setIsSubmittingReview(true)
    try {
      const res = await fetch(`/api/restaurants/${restaurant.id}/reviews`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rating: newRating, comment: newComment }),
      })
      const data = await res.json()
      if (res.ok) {
        toast.success('Review submitted successfully!')
        setNewComment('')
        setNewRating(5)
        fetchReviews()
      } else {
        toast.error(data.error || 'Failed to submit review')
      }
    } catch (err) {
      toast.error('Failed to submit review')
    } finally {
      setIsSubmittingReview(false)
    }
  }

  const isCafe = useMemo(() => {
    const slug = (restaurant.slug || '').toLowerCase()
    const name = (restaurant.name || '').toLowerCase()
    let tags: string[] = []
    if (Array.isArray(restaurant.cuisineTags)) {
      tags = restaurant.cuisineTags.map((t: string) => t.toLowerCase())
    } else if (typeof restaurant.cuisineTags === 'string') {
      try {
        tags = (JSON.parse(restaurant.cuisineTags) as string[]).map(t => t.toLowerCase())
      } catch {
        tags = [restaurant.cuisineTags.toLowerCase()]
      }
    }

    return slug.includes('cafe') || slug.includes('as-') || name.includes('cafe') || name.includes('a.s') || tags.some(t => t.includes('cafe'))
  }, [restaurant.slug, restaurant.name, restaurant.cuisineTags])

  const hasNonVegItems = useMemo(() => {
    if (restaurant.isPureVeg) return false
    return products.some((p: any) => p.tags?.some((t: string) => t.toLowerCase() === 'non-veg' || t.toLowerCase() === 'nonveg'))
  }, [restaurant.isPureVeg, products])

  // Determine menu sections based on restaurant type
  const getDefaultSections = () => {
    return isCafe ? DEFAULT_CAFE_MENU_SECTIONS : DEFAULT_RESTAURANT_MENU_SECTIONS
  }

  // Generate categories from products and menu sections
  const categories = useMemo(() => {
    let sections = restaurant.menuSections
      ? (typeof restaurant.menuSections === 'string' ? JSON.parse(restaurant.menuSections) : restaurant.menuSections)
      : getDefaultSections()

    // Filter out disabled sections (owner can toggle sections off)
    sections = sections.filter((s: any) => !s.disabled)

    // Filter products
    let filteredProducts = products.map((p: any) => ({
      ...p,
      restaurantId: p.restaurantId || restaurant.id,
      restaurant: p.restaurant || { id: restaurant.id, name: restaurant.name, slug: restaurant.slug, address: restaurant.address, ownerPhone: restaurant.ownerPhone, isOpen: restaurant.isOpen }
    }))
    if (isVegOnly) {
      filteredProducts = filteredProducts.filter(p =>
        restaurant.isPureVeg || p.tags?.some((t: string) => ['veg', 'pure-veg', 'vegetarian'].includes(t.toLowerCase()))
      )
    }
    if (searchQuery) {
      const q = searchQuery.toLowerCase()
      filteredProducts = filteredProducts.filter(p =>
        p.name.toLowerCase().includes(q) ||
        p.description?.toLowerCase().includes(q) ||
        p.tags?.some((t: string) => t.toLowerCase().includes(q))
      )
    }

    const assignedIds = new Set<string>()

    const catsWithProducts = sections.map((sec: any) => {
      const secTagLower = (sec.tag || '').toLowerCase()
      const secTitleLower = (sec.title || '').toLowerCase()

      const secProducts = filteredProducts.filter((p: any) => {
        const pTags = (p.tags || []).map((t: string) => t.toLowerCase())
        const pCatSlug = (p.category?.slug || '').toLowerCase()
        const pCatName = (p.category?.name || '').toLowerCase()
        const pMenuSec = (p.menuSection || '').toLowerCase()

        const matched = 
          (sec.matchTags || []).some((tag: string) => {
            const t = tag.toLowerCase()
            return pTags.includes(t) || pCatSlug.includes(t) || pCatName.includes(t) || pMenuSec === t
          }) || 
          pTags.includes(secTagLower) || 
          pCatSlug === secTagLower || 
          pCatName === secTitleLower || 
          (pMenuSec && pMenuSec === secTagLower)

        if (matched) assignedIds.add(p.id)
        return matched
      })
      return { ...sec, products: secProducts }
    }).filter((c: any) => c.products.length > 0)

    // Unassigned products smartly auto-grouped by category name
    const unassigned = filteredProducts.filter(p => !assignedIds.has(p.id))
    if (unassigned.length > 0) {
      const categoryGroups: Record<string, { title: string; products: any[] }> = {}

      unassigned.forEach((p: any) => {
        let groupTitle = p.category?.name || 'Chef Specials'
        if (groupTitle.toLowerCase().includes('fastkirana') || groupTitle.toLowerCase().includes('restaurant') || groupTitle.toLowerCase().includes('cafe')) {
          groupTitle = 'Chef Specials'
        }
        if (!categoryGroups[groupTitle]) {
          categoryGroups[groupTitle] = { title: groupTitle, products: [] }
        }
        categoryGroups[groupTitle].products.push(p)
      })

      Object.entries(categoryGroups).forEach(([title, grp]) => {
        const tag = title.toLowerCase().replace(/[^a-z0-9]+/g, '-')
        catsWithProducts.push({
          tag: `custom-${tag}`,
          title: grp.title,
          emoji: '🍳',
          description: `Delicious ${grp.title} from our kitchen`,
          products: grp.products,
        })
      })
    }

    return [
      { tag: 'all', title: 'All Items', emoji: '🍽️', products: filteredProducts },
      ...catsWithProducts,
    ]
  }, [products, isVegOnly, searchQuery, restaurant.menuSections])

  const toggleCategoryExpand = (tag: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev)
      if (next.has(tag)) next.delete(tag)
      else next.add(tag)
      return next
    })
  }

  const [isScrolledPastHero, setIsScrolledPastHero] = useState(false)

  // ScrollSpy for active category
  useEffect(() => {
    if (categories.length === 0) return

    let rafId: number
    const handleScroll = () => {
      cancelAnimationFrame(rafId)
      rafId = requestAnimationFrame(() => {
        setIsScrolledPastHero(window.scrollY > 150)
        if (isClickingTabRef.current) return

        const sectionEls = categories
          .filter(c => c.tag !== 'all')
          .map(c => ({
            tag: c.tag,
            el: document.getElementById(`section-${c.tag}`),
          }))
          .filter(s => s.el)

        const scrollTop = window.scrollY + 180
        let activeTag = 'all'

        for (const section of sectionEls) {
          if (section.el && section.el.offsetTop <= scrollTop) {
            activeTag = section.tag
          }
        }

        setActiveCategoryTag(activeTag)
      })
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => {
      window.removeEventListener('scroll', handleScroll)
      cancelAnimationFrame(rafId)
    }
  }, [categories])

  const scrollToSection = (tag: string) => {
    triggerHaptic('light')
    setActiveCategoryTag(tag)
    isClickingTabRef.current = true

    if (tag === 'all') {
      window.scrollTo({ top: 0, behavior: 'smooth' })
    } else {
      const el = document.getElementById(`section-${tag}`)
      if (el) {
        const offset = el.offsetTop - 75
        window.scrollTo({ top: offset, behavior: 'smooth' })
      }
    }

    setTimeout(() => { isClickingTabRef.current = false }, 800)
  }

  // Scroll active tab into view (horizontal tabs for standard restaurants)
  useEffect(() => {
    if (!categoryTabsRef.current) return
    const activeBtn = categoryTabsRef.current.querySelector(`[data-tag="${activeCategoryTag}"]`) as HTMLElement
    if (activeBtn && categoryTabsRef.current) {
      const container = categoryTabsRef.current
      const containerRect = container.getBoundingClientRect()
      const tabRect = activeBtn.getBoundingClientRect()
      const scrollLeft = container.scrollLeft + (tabRect.left - containerRect.left) - (containerRect.width / 2) + (tabRect.width / 2)
      container.scrollTo({ left: Math.max(0, scrollLeft), behavior: 'smooth' })
    }
  }, [activeCategoryTag])

  // Auto-scroll vertical sidebar to center active tag button
  useEffect(() => {
    if (!activeCategoryTag) return
    const activeBtn = document.getElementById(`cafe-category-tab-${activeCategoryTag}`)
    const sidebar = document.getElementById(`cafe-sidebar`)
    if (activeBtn && sidebar) {
      const containerHeight = sidebar.clientHeight
      const btnOffsetTop = activeBtn.offsetTop
      const btnHeight = activeBtn.clientHeight
      const targetScrollTop = btnOffsetTop - (containerHeight / 2) + (btnHeight / 2)
      sidebar.scrollTo({
        top: Math.max(0, targetScrollTop),
        behavior: 'smooth'
      })
    }
  }, [activeCategoryTag])

  const totalItems = getTotalItems()
  const subtotal = getSubtotal()

  const activeProducts = activeCategoryTag === 'all'
    ? categories.find(c => c.tag === 'all')?.products || []
    : null

  return (
    <div className="min-h-screen bg-[#fafafa] dark:bg-[#09090b] pb-32 relative">
      <FloatingEmojis type={isCafe ? 'cafe' : 'food'} />
      {/* Sticky Header */}
      <div className="sticky top-0 z-50 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-xl border-b border-zinc-200/60 dark:border-zinc-800/60">
        <div className={cn("mx-auto px-4 h-12 sm:h-14 flex items-center justify-between", isCafe ? "max-w-4xl" : "max-w-3xl")}>
          <button
            onClick={() => router.back()}
            className="flex items-center gap-1.5 text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors"
          >
            <ArrowLeft className="h-5 w-5" />
            <span className="text-xs font-bold hidden sm:inline">Back</span>
          </button>

          <h1 className={cn(
            "text-sm font-black text-zinc-900 dark:text-zinc-100 truncate max-w-[200px] transition-opacity duration-300",
            isScrolledPastHero ? "opacity-100" : "opacity-0"
          )}>
            {restaurant.name}
          </h1>

          <button
            onClick={() => { setShowSearch(!showSearch); triggerHaptic('light') }}
            className="p-2 rounded-xl hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors"
          >
            {showSearch ? <X className="h-5 w-5 text-zinc-500" /> : <Search className="h-5 w-5 text-zinc-500" />}
          </button>
        </div>

        {/* Search Bar */}
        <AnimatePresence>
          {showSearch && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="overflow-hidden border-t border-zinc-100 dark:border-zinc-800"
            >
              <div className={cn("mx-auto px-4 py-2", isCafe ? "max-w-4xl" : "max-w-3xl")}>
                <div className="relative">
                  <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-400" />
                  <input
                    type="text"
                    placeholder={`Search in ${restaurant.name}...`}
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    className="w-full pl-9 pr-9 py-2 rounded-xl bg-zinc-100 dark:bg-zinc-800/80 border border-zinc-200 dark:border-zinc-700 text-xs font-medium text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 focus:outline-none focus:ring-2 focus:ring-orange-500/40"
                    autoFocus
                  />
                  {searchQuery && (
                    <button onClick={() => setSearchQuery('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-400">
                      <X size={16} />
                    </button>
                  )}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Restaurant Hero Banner */}
      <div className="relative w-full h-[180px] sm:h-[220px] overflow-hidden">
        {restaurant.bannerUrl ? (
          <Image
            src={restaurant.bannerUrl}
            alt={restaurant.name}
            fill
            className="object-cover"
            sizes="100vw"
            priority
          />
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-orange-500 via-red-500 to-pink-500" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/30 to-transparent" />

        {/* Restaurant Info Overlay */}
        <div className="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
          <div className={cn("mx-auto flex items-end gap-3", isCafe ? "max-w-4xl" : "max-w-3xl")}>
            {/* Logo */}
            {restaurant.logoUrl && (
              <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-xl border-2 border-white/30 overflow-hidden flex-shrink-0 bg-white shadow-lg">
                <Image src={restaurant.logoUrl} alt={restaurant.name} width={64} height={64} className="object-cover w-full h-full" />
              </div>
            )}
            <div className="flex-1 min-w-0">
              <h2 className="text-lg sm:text-2xl font-black text-white drop-shadow-lg leading-tight">
                {restaurant.name}
              </h2>
              <p className="text-xs sm:text-sm font-bold text-white/95 drop-shadow-md line-clamp-2 mt-0.5 leading-snug">
                {restaurant.description || (restaurant.cuisineTags && restaurant.cuisineTags.length > 0 ? `${restaurant.cuisineTags.join(' • ')} Specials` : 'Delicious North Indian Curries, Gravies & Fast Food Specials')}
              </p>
              <div className="flex flex-wrap items-center gap-1.5 mt-1.5">
                {restaurant.cuisineTags?.slice(0, 4).map((tag: string) => (
                  <span key={tag} className="text-[9px] font-extrabold uppercase tracking-wider text-white bg-black/40 backdrop-blur-xs border border-white/20 px-2 py-0.5 rounded-full shadow-2xs">
                    {tag}
                  </span>
                ))}
                {restaurant.isPureVeg && (
                  <span className="flex items-center gap-0.5 text-[9.5px] font-black text-emerald-400 bg-emerald-950/70 backdrop-blur-xs border border-emerald-500/40 px-2 py-0.5 rounded-full shadow-2xs">
                    <Leaf size={10} /> Pure Veg
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Discount Badge */}
        {restaurant.discountOffer && (
          <div className="absolute top-3 right-3 bg-blue-600 text-white px-2.5 py-1 rounded-lg shadow-lg">
            <span className="text-[10px] font-black">{restaurant.discountOffer}</span>
          </div>
        )}
      </div>

      {/* Closed Kitchen Operating Hours Banner */}
      {(() => {
        const operatingStatus = checkStoreOperatingStatus(restaurant)
        if (!operatingStatus.isOpen) {
          return (
            <div className="bg-rose-500/10 border-b border-rose-500/20 px-4 py-2.5 text-center text-xs font-bold text-rose-600 dark:text-rose-400 flex items-center justify-center gap-2">
              <Moon className="h-4 w-4 shrink-0" />
              <span>🌙 Kitchen Currently Closed — {operatingStatus.formattedScheduleStr || 'Not accepting orders right now.'}</span>
            </div>
          )
        }
        return null
      })()}

      {/* Menu / Reviews Sub-tabs */}
      <div className={cn("mx-auto px-4 pt-4 flex gap-4 border-b border-zinc-200 dark:border-zinc-800", isCafe ? "max-w-4xl" : "max-w-3xl")}>
        <button
          onClick={() => { setActiveSubTab('menu'); triggerHaptic('light') }}
          className={cn(
            "pb-2 text-xs font-black uppercase tracking-wider transition-all border-b-2",
            activeSubTab === 'menu'
              ? "border-orange-500 text-orange-500"
              : "border-transparent text-zinc-500 hover:text-zinc-850 dark:hover:text-zinc-250"
          )}
        >
          Menu
        </button>
        <button
          onClick={() => { setActiveSubTab('reviews'); triggerHaptic('light') }}
          className={cn(
            "pb-2 text-xs font-black uppercase tracking-wider transition-all border-b-2",
            activeSubTab === 'reviews'
              ? "border-orange-500 text-orange-500"
              : "border-transparent text-zinc-500 hover:text-zinc-850 dark:hover:text-zinc-250"
          )}
        >
          Reviews ({reviews.length})
        </button>
      </div>

      {/* Category Tabs (Sticky) */}
      {activeSubTab === 'menu' && !isCafe && (
        <div className="sticky top-12 sm:top-14 z-40 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-md border-b border-zinc-200/60 dark:border-zinc-800/60 py-2 shadow-2xs">
          <div
            ref={categoryTabsRef}
            className="flex gap-1.5 px-4 overflow-x-auto scrollbar-hide max-w-3xl mx-auto"
            style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
          >
            {categories.map(cat => (
              <button
                key={cat.tag}
                data-tag={cat.tag}
                onClick={() => scrollToSection(cat.tag)}
                className={cn(
                  "flex-shrink-0 px-3 py-1.5 rounded-full text-[11px] font-bold transition-all duration-200 whitespace-nowrap",
                  activeCategoryTag === cat.tag
                    ? "bg-orange-500 text-white shadow-md shadow-orange-500/25"
                    : "bg-zinc-100 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-400 hover:bg-zinc-200 dark:hover:bg-zinc-700"
                )}
              >
                {cat.emoji} {cat.title} ({cat.products.length})
              </button>
            ))}
          </div>
        </div>
      )}

      {activeSubTab === 'menu' ? (
        <>
          {/* Veg Toggle + Info Bar */}
          <div className={cn("mx-auto px-4 py-2 flex items-center justify-between bg-zinc-100/60 dark:bg-zinc-900/60 rounded-2xl border border-zinc-200/50 dark:border-zinc-800/50 my-2", isCafe ? "max-w-4xl" : "max-w-3xl")}>
            <div className="flex items-center gap-2 min-w-0">
              <span className="px-2.5 py-1 bg-orange-500/10 text-orange-600 dark:text-orange-400 rounded-lg text-[10px] font-black uppercase tracking-wider shrink-0">
                {products.length} ITEMS
              </span>
              <span className="text-[11px] font-bold text-zinc-600 dark:text-zinc-400 hidden sm:inline">
                Fresh & Fast Delivery
              </span>
            </div>
            {hasNonVegItems ? (
              <button
                onClick={() => { setIsVegOnly(!isVegOnly); triggerHaptic('light') }}
                className={cn(
                  "flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-black transition-all shrink-0 cursor-pointer shadow-2xs active:scale-95",
                  isVegOnly
                    ? "bg-emerald-600 text-white shadow-emerald-500/20"
                    : "bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 text-zinc-700 dark:text-zinc-300"
                )}
              >
                <Leaf size={12} className={isVegOnly ? "text-white" : "text-emerald-600"} />
                <span>Veg Only</span>
              </button>
            ) : (
              <span className="flex items-center gap-1 text-[10px] font-black text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2.5 py-1 rounded-full border border-emerald-500/20 shrink-0">
                <Leaf size={12} className="text-emerald-500" /> 100% Pure Veg Kitchen
              </span>
            )}
          </div>

          {/* Menu Content */}
          <div className={cn("mx-auto px-4", isCafe ? "max-w-4xl" : "max-w-3xl")}>
            {products.length === 0 ? (
              /* Empty state */
              <div className="flex flex-col items-center justify-center py-20 gap-3">
                <span className="text-5xl">🍽️</span>
                <p className="text-sm font-bold text-zinc-500">Menu not available yet</p>
                <p className="text-[11px] text-zinc-400">Check back soon!</p>
              </div>
            ) : searchQuery && categories[0]?.products?.length === 0 ? (
              /* Empty search state */
              <div className="flex flex-col items-center justify-center py-16 gap-3">
                <span className="text-4xl">🔍</span>
                <p className="text-sm font-bold text-zinc-500">No items found for &quot;{searchQuery}&quot;</p>
                <button
                  onClick={() => setSearchQuery('')}
                  className="text-[11px] font-bold text-orange-500"
                >
                  Clear search
                </button>
              </div>
            ) : (
              /* Split Sidebar Layout (for all outlets) */
              <div className="flex flex-row items-start w-full gap-3 sm:gap-6 mt-2">
                {/* Left Vertical Category Sidebar */}
                <aside 
                  id="cafe-sidebar" 
                  className="sticky top-[66px] sm:top-[74px] z-30 w-[80px] min-[375px]:w-[85px] sm:w-[110px] shrink-0 max-h-[calc(100vh-145px)] overflow-y-auto scrollbar-none py-1 pb-28 space-y-1.5 select-none border-r border-zinc-200/60 dark:border-zinc-800/60 pr-1.5 sm:pr-2 self-start transition-all duration-200"
                >
                  {categories.map((cat: any) => {
                    const isActive = activeCategoryTag === cat.tag
                    const image = cat.tag === 'all' ? null : (cat.image || getCafeSectionImage(cat.tag))

                    return (
                      <button
                        key={cat.tag}
                        id={`cafe-category-tab-${cat.tag}`}
                        onClick={(e) => {
                          e.preventDefault()
                          scrollToSection(cat.tag)
                        }}
                        className={cn(
                          "w-full flex flex-col items-center gap-1.5 p-1.5 rounded-2xl transition-all duration-200 text-center outline-none group cursor-pointer border-l-2",
                          isActive 
                            ? "bg-orange-500/10 dark:bg-orange-500/15 border-orange-500 text-orange-600 dark:text-orange-400 font-black shadow-2xs" 
                            : "border-transparent text-zinc-600 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-800/80"
                        )}
                      >
                        <div 
                          className={cn(
                            "relative w-9 h-9 min-[375px]:w-10 min-[375px]:h-10 rounded-full overflow-hidden shrink-0 border transition-all duration-300 bg-white dark:bg-zinc-900 flex items-center justify-center p-0.5",
                            isActive 
                              ? "border-orange-500 scale-105 shadow-2xs" 
                              : "border-zinc-200 dark:border-zinc-800"
                          )}
                        >
                          <div className="relative w-full h-full rounded-full overflow-hidden bg-zinc-50 dark:bg-zinc-850 flex items-center justify-center">
                            {image ? (
                              <Image
                                src={image}
                                alt={cat.title}
                                fill
                                sizes="40px"
                                className="object-cover"
                              />
                            ) : (
                              <span className="text-base select-none">{cat.emoji || '🍽️'}</span>
                            )}
                          </div>
                        </div>
                        <span className="text-[9px] min-[375px]:text-[9.5px] font-bold leading-[1.2] line-clamp-2 max-w-full">
                          {cat.title}
                        </span>
                      </button>
                    )
                  })}
                </aside>

                {/* Right Side Products Container */}
                <main className="flex-grow min-w-0 space-y-6 pb-32">
                  {categories.filter(c => c.tag !== 'all').map(cat => {
                    const isCollapsed = expandedCategories.has(cat.tag)
                    const isExpanded = !isCollapsed || searchQuery !== ''
                    
                    return (
                      <div 
                        key={cat.tag} 
                        id={`section-${cat.tag}`}
                        className="space-y-3 pt-4 border-t border-zinc-200/50 dark:border-zinc-800/40 first:border-t-0 scroll-mt-24"
                      >
                        <div className="flex items-center justify-between px-1">
                          <div className="flex items-center gap-1.5">
                            <h4 className="text-xs sm:text-sm font-black uppercase tracking-wider text-text-primary">
                              {cat.title} Specials
                            </h4>
                          </div>
                          <button
                            onClick={() => {
                              triggerHaptic('light')
                              toggleCategoryExpand(cat.tag)
                            }}
                            className="text-[11px] font-black text-orange-600 hover:opacity-85 flex items-center gap-0.5 select-none"
                          >
                            <span>{isExpanded ? 'Collapse' : `See All (${cat.products.length})`}</span>
                            <ChevronRight size={10} strokeWidth={3} className={cn("transition-transform duration-200", isExpanded && "rotate-90")} />
                          </button>
                        </div>

                        {isExpanded ? (
                          /* Expanded: Grid Layout */
                          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 animate-fade-in">
                            {cat.products.map((product: any, idx: number) => (
                              <motion.div
                                key={product.id}
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                transition={{ duration: 0.25, delay: idx * 0.03 }}
                              >
                                <ProductCard product={product} />
                              </motion.div>
                            ))}
                          </div>
                        ) : (
                          /* Collapsed: Horizontal Slider Layout */
                          <div className="flex gap-3.5 md:gap-4 overflow-x-auto pb-3 pt-1.5 scrollbar-hide snap-x snap-mandatory scroll-smooth px-1">
                            {cat.products.map((product: any) => (
                              <div key={product.id} className="w-[140px] min-[375px]:w-[160px] sm:w-[180px] md:w-[200px] shrink-0 snap-start">
                                <ProductCard product={product} />
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    )
                  })}
                </main>
              </div>
            )}

            {/* Empty state */}
            {products.length === 0 && (
              <div className="flex flex-col items-center justify-center py-20 gap-3">
                <span className="text-5xl">🍽️</span>
                <p className="text-sm font-bold text-zinc-500">Menu not available yet</p>
                <p className="text-[11px] text-zinc-400">Check back soon!</p>
              </div>
            )}

            {searchQuery && categories[0]?.products?.length === 0 && (
              <div className="flex flex-col items-center justify-center py-16 gap-3">
                <span className="text-4xl">🔍</span>
                <p className="text-sm font-bold text-zinc-500">No items found for &quot;{searchQuery}&quot;</p>
                <button
                  onClick={() => setSearchQuery('')}
                  className="text-[11px] font-bold text-orange-500"
                >
                  Clear search
                </button>
              </div>
            )}
          </div>
        </>
      ) : (
        /* Reviews Panel */
        <div className={cn("mx-auto px-4 py-6 space-y-6 animate-fade-in", isCafe ? "max-w-4xl" : "max-w-3xl")}>
          {/* Average Rating Stats Card */}
          <div className="bg-white dark:bg-zinc-900 border border-zinc-200/60 dark:border-zinc-800/60 rounded-3xl p-6 flex flex-col sm:flex-row items-center gap-6 shadow-sm">
            <div className="text-center sm:border-r border-zinc-200 dark:border-zinc-850 sm:pr-8 flex-shrink-0">
              <h4 className="text-4xl font-black text-zinc-900 dark:text-zinc-50">{restaurant.rating?.toFixed(1) || '4.0'}</h4>
              <div className="flex items-center justify-center gap-0.5 my-1.5 text-yellow-400">
                {[1, 2, 3, 4, 5].map((s) => (
                  <Star key={s} size={16} className={cn("fill-current", s <= Math.round(restaurant.rating || 4) ? "text-yellow-400" : "text-zinc-200 dark:text-zinc-700")} />
                ))}
              </div>
              <p className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider">{reviews.length} ratings</p>
            </div>
            
            {/* Add Review Form */}
            <form onSubmit={handleSubmitReview} className="flex-1 w-full space-y-3">
              <h5 className="text-xs font-black uppercase tracking-tight text-zinc-800 dark:text-zinc-200">Write a Review</h5>
              
              <div className="flex items-center gap-1.5">
                {[1, 2, 3, 4, 5].map((s) => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => { setNewRating(s); triggerHaptic('light') }}
                    className="text-yellow-400 p-0.5"
                  >
                    <Star size={20} className={cn("transition-colors", s <= newRating ? "fill-yellow-400 text-yellow-400" : "text-zinc-350 dark:text-zinc-750")} />
                  </button>
                ))}
              </div>

              <div className="relative">
                <textarea
                  placeholder="Tell us about your experience (food quality, packaging, delivery)..."
                  value={newComment}
                  onChange={(e) => setNewComment(e.target.value)}
                  className="w-full px-3.5 py-2.5 text-xs font-medium text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 bg-zinc-100 dark:bg-zinc-800/80 border border-zinc-200 dark:border-zinc-750 rounded-2xl focus:outline-none focus:ring-2 focus:ring-orange-500/40 min-h-[70px] resize-none"
                />
              </div>

              <button
                type="submit"
                disabled={isSubmittingReview}
                className="w-full sm:w-auto px-4 py-2 bg-orange-500 text-white rounded-xl text-xs font-black shadow-md shadow-orange-500/25 active:scale-95 transition-all flex items-center justify-center gap-1 disabled:opacity-50"
              >
                {isSubmittingReview ? 'Submitting...' : 'Submit Review'}
              </button>
            </form>
          </div>

          {/* Reviews List */}
          <div className="space-y-4">
            <h4 className="text-[13px] font-black uppercase tracking-wider text-zinc-900 dark:text-zinc-100">Customer Feedback</h4>
            {reviewsLoading ? (
              <div className="flex justify-center items-center py-10">
                <RefreshCw className="h-6 w-6 text-orange-500 animate-spin" />
              </div>
            ) : reviews.length === 0 ? (
              <div className="text-center py-12 border border-dashed border-zinc-200 dark:border-zinc-800 rounded-3xl">
                <span className="text-3xl">💬</span>
                <p className="text-xs font-bold text-zinc-400 mt-2">No reviews yet for this restaurant.</p>
                <p className="text-[10px] text-zinc-400/80 mt-0.5">Be the first to review after your order is delivered!</p>
              </div>
            ) : (
              <div className="space-y-3">
                {reviews.map((rev) => (
                  <div key={rev.id} className="bg-white dark:bg-zinc-900 border border-zinc-200/50 dark:border-zinc-800/50 rounded-2xl p-4 space-y-2.5 shadow-xs">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        {rev.user.image ? (
                          <div className="w-8 h-8 rounded-full overflow-hidden relative">
                            <Image src={rev.user.image} alt={rev.user.name || 'User'} fill className="object-cover" />
                          </div>
                        ) : (
                          <div className="w-8 h-8 rounded-full bg-zinc-100 dark:bg-zinc-800 text-zinc-500 flex items-center justify-center text-xs font-black">
                            {(rev.user.name || 'U').slice(0, 1).toUpperCase()}
                          </div>
                        )}
                        <div>
                          <p className="text-xs font-black text-zinc-900 dark:text-zinc-100">{rev.user.name || 'Anonymous'}</p>
                          <p className="text-[9px] font-bold text-zinc-400">{formatDate(rev.createdAt, 'dd MMM yyyy')}</p>
                        </div>
                      </div>

                      <div className="flex items-center gap-0.5 text-yellow-400 bg-yellow-400/5 dark:bg-yellow-400/10 px-2 py-0.5 rounded-full border border-yellow-400/10">
                        <Star size={11} className="fill-current" />
                        <span className="text-[10px] font-black">{rev.rating}</span>
                      </div>
                    </div>

                    {rev.comment && (
                      <p className="text-xs font-bold text-zinc-700 dark:text-zinc-300 leading-relaxed pl-1">
                        {rev.comment}
                      </p>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
