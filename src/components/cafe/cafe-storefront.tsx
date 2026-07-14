'use client'

import { useState, useMemo, useEffect, useCallback, useRef } from 'react'
import { ChevronRight, Menu as MenuIcon, X, Plus, Minus, Check, Clock, Award, Tag, ShoppingBag, Utensils, Coffee, ChefHat } from 'lucide-react'
import { Product } from '@/types'
import { ProductCard } from '@/components/product/product-card'
import Link from 'next/link'
import Image from 'next/image'
import { motion, AnimatePresence } from 'framer-motion'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { useLiveStock } from '@/components/providers/live-stock-provider'
import { ProductImage } from '@/components/product/product-image'
import { Button } from '@/components/ui/button'
import { useSearchParams } from 'next/navigation'
import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'

import { DEFAULT_CAFE_MENU_SECTIONS, CafeMenuSection } from '@/lib/constants'

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
    'bakery': '/bakery_biscuits_category.png',
    'pizza': '/cafe_pizza_category.png',
    'burgers': '/cafe_burgers_category.png',
    'garlic-bread': '/cafe_garlic_bread_category.png',
    'desserts': '/cafe_desserts_category.png',
  }
  return mapping[tag] || null
}

const containerVariants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: {
      staggerChildren: 0.04,
      delayChildren: 0.02
    }
  }
} as const

const itemVariants = {
  hidden: { opacity: 0, y: 15 },
  show: { 
    opacity: 1, 
    y: 0, 
    transition: { 
      type: 'spring', 
      stiffness: 220, 
      damping: 18 
    } 
  }
} as const

interface CafeProductRowProps {
  product: any
  cafeOpen: boolean
}

export function CafeProductRow({ product, cafeOpen }: CafeProductRowProps) {
  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const quantity = getItemQuantity(product.id)
  const [showAdded, setShowAdded] = useState(false)

  const [mounted, setMounted] = useState(false)
  useEffect(() => {
    setMounted(true)
  }, [])

  const resolvedQuantity = mounted ? quantity : 0

  const liveState = useLiveStock(product.id)
  const resolvedStock = liveState !== null ? liveState.stock : product.stock
  const resolvedPrice = liveState !== null ? liveState.price : product.price
  const resolvedMrp = liveState !== null ? liveState.mrp : product.mrp
  const resolvedIsAvailable = liveState !== null ? liveState.isAvailable : product.isAvailable

  const resolvedDiscount = useMemo(() => {
    if (liveState === null) return product.discount
    if (resolvedMrp <= resolvedPrice) return 0
    return Math.max(0, Math.round(((resolvedMrp - resolvedPrice) / resolvedMrp) * 100))
  }, [liveState, resolvedMrp, resolvedPrice, product.discount])

  const cartProduct = useMemo(() => ({
    id: product.id,
    name: product.name,
    slug: product.slug,
    imageUrl: product.imageUrl,
    mrp: resolvedMrp,
    price: resolvedPrice,
    discount: resolvedDiscount,
    unit: product.unit,
    stock: resolvedStock,
    isAvailable: resolvedIsAvailable,
    category: product.category,
  }), [product, resolvedMrp, resolvedPrice, resolvedDiscount, resolvedStock, resolvedIsAvailable])

  const handleAdd = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')
    addItem(cartProduct)
    setShowAdded(true)
    setTimeout(() => setShowAdded(false), 600)
  }, [addItem, cartProduct])

  const handleIncrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')
    updateQuantity(product.id, product.name, quantity + 1)
  }

  const handleDecrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('medium')
    updateQuantity(product.id, product.name, quantity - 1)
  }

  const savings = resolvedMrp - resolvedPrice
  const tagsLower = product.tags?.map((t: string) => t.toLowerCase()) || []
  const isNonVeg = tagsLower.includes('nonveg') || tagsLower.includes('non-veg') || tagsLower.includes('chicken') || tagsLower.includes('egg')
  const isBestseller = tagsLower.includes('popular')

  return (
    <div className="group relative flex items-start justify-between py-6 gap-4 border-b border-border/60 last:border-b-0">
      <AnimatePresence>
        {showAdded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="absolute inset-0 z-30 flex items-center justify-center bg-[#2e7d32]/5 rounded-xl pointer-events-none"
          >
            <motion.div
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ duration: 0.12, ease: 'easeOut' }}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-[#2e7d32] text-white shadow-lg"
            >
              <Check className="h-4 w-4" strokeWidth={3} />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="flex-1 space-y-1.5 min-w-0 pr-2">
        <div className="flex items-center gap-2 flex-wrap">
          {isNonVeg ? (
            <span className="flex items-center justify-center h-4 w-4 border border-[#8B4513] p-0.5 rounded-xs shrink-0" title="Non-Veg">
              <span className="h-2 w-2 bg-[#8B4513] rotate-45 shrink-0" />
            </span>
          ) : (
            <span className="flex items-center justify-center h-4 w-4 border border-[#2e7d32] p-0.5 rounded-xs shrink-0" title="Veg">
              <span className="h-2 w-2 rounded-full bg-[#2e7d32] shrink-0" />
            </span>
          )}

          {isBestseller && (
            <span className="inline-flex items-center gap-0.5 bg-gradient-to-r from-amber-500 to-orange-500 text-white font-extrabold text-[8px] uppercase tracking-wider px-1.5 py-0.5 rounded shadow-xs">
              ★ Bestseller
            </span>
          )}
        </div>

        <h3 className="text-sm sm:text-base font-extrabold text-text-primary leading-tight">
          {product.name}
        </h3>

        <div className="flex items-baseline gap-1.5 flex-wrap">
          <span className="text-sm sm:text-base font-black text-text-primary">
            ₹{resolvedPrice}
          </span>
          {resolvedMrp > resolvedPrice && (
            <span className="text-xs text-text-muted line-through font-bold">
              ₹{resolvedMrp}
            </span>
          )}
          {resolvedDiscount > 0 && (
            <span className="text-[10px] font-black text-[#2e7d32] dark:text-emerald-400">
              {resolvedDiscount}% OFF
            </span>
          )}
        </div>

        <div className="text-[10px] font-bold text-text-muted">
          {product.unit}
        </div>

        {product.description && (
          <p className="text-xs text-text-secondary leading-relaxed font-semibold max-w-xl">
            {product.description}
          </p>
        )}
      </div>

      <div className="relative flex flex-col items-center shrink-0 select-none">
        <div className="relative h-24 w-24 sm:h-28 sm:w-28 overflow-hidden rounded-xl bg-muted/10 dark:bg-white/[0.02] border border-border/40">
          <ProductImage
            src={product.imageUrl}
            alt={product.name}
            categorySlug={product.category?.slug || ''}
            className="h-full w-full object-contain p-1"
          />
        </div>

        <div className="absolute -bottom-2 h-7.5 w-[76px] sm:w-[84px] z-10 shrink-0">
          <AnimatePresence mode="wait">
            {resolvedQuantity === 0 ? (
              <motion.div
                key="add-btn"
                initial={{ opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.15 }}
                className="w-full h-full"
              >
                <Button
                  onClick={handleAdd}
                  disabled={resolvedStock <= 0 || !resolvedIsAvailable || !cafeOpen}
                  className={cn(
                    "w-full h-full border text-[10px] sm:text-xs font-black rounded shadow-md hover:scale-[1.03] active:scale-95 transition-all duration-200 flex items-center justify-center gap-0.5 cursor-pointer",
                    resolvedStock <= 0 || !resolvedIsAvailable || !cafeOpen
                      ? "border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-zinc-400 dark:text-zinc-500 cursor-not-allowed"
                      : "border-green-600 bg-white dark:bg-zinc-900 text-[#2e7d32] dark:text-emerald-400 hover:bg-green-50 dark:hover:bg-zinc-800"
                  )}
                >
                  {resolvedStock <= 0 || !resolvedIsAvailable ? (
                    'Out'
                  ) : !cafeOpen ? (
                    'Closed'
                  ) : (
                    <>
                      ADD
                      <Plus className="h-2.5 w-2.5 sm:h-3 sm:w-3 stroke-[3]" />
                    </>
                  )}
                </Button>
              </motion.div>
            ) : (
              <motion.div
                key="qty-counter"
                initial={{ opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.15 }}
                className="flex h-full w-full items-center justify-between rounded bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold shadow-md overflow-hidden transition-all duration-300"
              >
                <motion.button
                  whileTap={{ scale: 0.82 }}
                  onClick={handleDecrement}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all cursor-pointer"
                  aria-label="Decrease quantity"
                >
                  <Minus className="h-2.5 w-2.5 stroke-[3]" />
                </motion.button>
                <span className="w-5 sm:w-6 shrink-0 flex items-center justify-center text-[10px] sm:text-xs font-black select-none h-full bg-[#2e7d32] border-x border-white/20">
                  {quantity}
                </span>
                <motion.button
                  whileTap={{ scale: 0.82 }}
                  onClick={handleIncrement}
                  disabled={quantity >= resolvedStock || quantity >= 10 || !cafeOpen}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all disabled:opacity-50 cursor-pointer"
                  aria-label="Increase quantity"
                >
                  <Plus className="h-2.5 w-2.5 stroke-[3]" />
                </motion.button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  )
}

interface CafeStorefrontProps {
  initialProducts: any[]
  customSections?: CafeMenuSection[]
}

export function CafeStorefront({ initialProducts, customSections }: CafeStorefrontProps) {
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const { items } = useCart()
  const hasCartItems = items.length > 0
  // Swiggy dynamic navigation states
  const searchParams = useSearchParams()
  const sectionParam = searchParams.get('section')
  
  const [activeCategory, setActiveCategory] = useState<string>('')
  const [showFloatingMenuBtn, setShowFloatingMenuBtn] = useState<boolean>(false)
  const [isFloatingMenuOpen, setIsFloatingMenuOpen] = useState<boolean>(false)
  const [navbarHeight, setNavbarHeight] = useState<number>(96)
  const [searchQuery, setSearchQuery] = useState('')
  const [isSticky, setIsSticky] = useState<boolean>(false)
  const [experienceMode, setExperienceMode] = useState<'cafe' | 'restaurant'>('cafe')

  const isScrollingRef = useRef(false)
  const scrollTimeoutRef = useRef<NodeJS.Timeout | null>(null)
  const categoriesBarRef = useRef<HTMLDivElement>(null)

  // Measure and update navbar height only on mount and window resize (prevents layout thrashing on scroll)
  useEffect(() => {
    const updateNavbarHeight = () => {
      const navbarEl = document.querySelector('nav')
      if (navbarEl) {
        setNavbarHeight(navbarEl.getBoundingClientRect().height)
      }
    }
    updateNavbarHeight()
    window.addEventListener('resize', updateNavbarHeight)
    return () => window.removeEventListener('resize', updateNavbarHeight)
  }, [])

  // Parse section query parameter on mount and scroll to it
  useEffect(() => {
    if (sectionParam) {
      setActiveCategory(sectionParam)
      const timer = setTimeout(() => {
        scrollToCategory(sectionParam)
      }, 400)
      return () => clearTimeout(timer)
    }
  }, [sectionParam])

  // Map products to categories
  const mappedProducts = useMemo(() => {
    return initialProducts.map(p => ({
      id: p.id,
      name: p.name,
      slug: p.slug,
      description: p.description,
      imageUrl: p.imageUrl,
      categoryId: p.categoryId,
      mrp: p.mrp,
      price: p.price,
      discount: p.discount,
      unit: p.unit,
      stock: p.stock,
      isAvailable: p.isAvailable,
      tags: p.tags || [],
      minStock: p.minStock,
      variants: p.variants || null,
      category: p.category ? {
        id: p.category.id,
        name: p.category.name,
        slug: p.category.slug,
        imageUrl: p.category.imageUrl,
        parentId: p.category.parentId,
        sortOrder: p.category.sortOrder,
      } : undefined
    }))
  }, [initialProducts])

  // Dynamic grouping logic to discover categories from product tags
  const categorySections = useMemo(() => {
    const excludeTags = new Set([
      'cafe', 'popular', 'veg', 'paneer', 'cheese', 'spicy', 'protein', 
      'breakfast', 'essential', 'cooking', 'staple', 'premium', 'garnish', 'salad', 
      'seasonal', 'daily', 'snack', 'cereal', 'traditional', 'chips', 'namkeen', 
      'chocolate', 'instant', 'biscuit', 'juice', 'desi', 'summer', 'water', 'energy', 
      'soap', 'toothpaste', 'shampoo', 'hygiene', 'skincare', 'deo', 'personal', 
      'shaving', 'men', 'herbal', 'hair', 'oil', 'cleaning', 'detergent', 'toilet', 
      'floor', 'mosquito', 'freshener', 'glass', 'wrapping', 'cookies', 'light', 
      'rusk', 'tea-time', 'bread', 'atta', 'rice', 'dal', 'spice', 'healthy', 'salt'
    ])

    const PREDEFINED_CATEGORIES = customSections || DEFAULT_CAFE_MENU_SECTIONS

    const sectionsMap = new Map<string, any>()
    PREDEFINED_CATEGORIES.forEach(cat => {
      sectionsMap.set(cat.tag, {
        tag: cat.tag,
        title: cat.title,
        emoji: cat.emoji,
        description: cat.description,
        products: [],
        matchedIds: new Set<string>()
      })
    })

    const assignedProductIds = new Set<string>()

    mappedProducts.forEach(product => {
      for (const cat of PREDEFINED_CATEGORIES) {
        const hasMatch = product.tags?.some((t: string) => 
          cat.matchTags.includes(t.toLowerCase())
        ) || (cat.tag === 'bakery' && ['croissant-butter', 'muffin-chocolate'].includes(product.slug))

        if (hasMatch) {
          const sec = sectionsMap.get(cat.tag)
          if (sec && !sec.matchedIds.has(product.id)) {
            sec.products.push(product)
            sec.matchedIds.add(product.id)
            assignedProductIds.add(product.id)
          }
        }
      }
    })

    const dynamicTagsMap = new Map<string, any[]>()
    mappedProducts.forEach(product => {
      if (assignedProductIds.has(product.id)) return

      product.tags?.forEach((t: string) => {
        const lowerTag = t.toLowerCase()
        if (excludeTags.has(lowerTag)) return

        if (!dynamicTagsMap.has(lowerTag)) {
          dynamicTagsMap.set(lowerTag, [])
        }
        dynamicTagsMap.get(lowerTag)?.push(product)
      })
    })

    const dynamicSections: any[] = []
    dynamicTagsMap.forEach((products, tag) => {
      const title = tag
        .split(/[-_ ]+/)
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ')

      dynamicSections.push({
        tag,
        title,
        emoji: '✨',
        description: `Fresh items tagged under ${title}`,
        products
      })
    })

    const finalSections: any[] = []
    PREDEFINED_CATEGORIES.forEach(cat => {
      const sec = sectionsMap.get(cat.tag)
      if (sec && sec.products.length > 0) {
        finalSections.push({
          tag: sec.tag,
          title: sec.title,
          emoji: sec.emoji,
          description: sec.description,
          products: sec.products
        })
      }
    })

    finalSections.push(...dynamicSections)

    const allGroupedIds = new Set<string>()
    finalSections.forEach(sec => sec.products.forEach((p: any) => allGroupedIds.add(p.id)))
    const moreItems = mappedProducts.filter(p => !allGroupedIds.has(p.id))

    return {
      sections: finalSections,
      moreItems
    }
  }, [mappedProducts])

  // Filtered categories and products based on user search query
  const filteredCategorySections = useMemo(() => {
    const filterFn = (p: any) => {
      // Search query filter
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase().trim()
        const matchesName = p.name.toLowerCase().includes(query)
        const matchesDesc = p.description?.toLowerCase().includes(query) || false
        const matchesTags = p.tags?.some((t: string) => t.toLowerCase().includes(query)) || false
        return matchesName || matchesDesc || matchesTags
      }

      return true
    }

    const filteredSections = categorySections.sections
      .map(sec => ({
        ...sec,
        products: sec.products.filter(filterFn)
      }))
      .filter(sec => sec.products.length > 0)

    const filteredMoreItems = categorySections.moreItems.filter(filterFn)

    return {
      sections: filteredSections,
      moreItems: filteredMoreItems
    }
  }, [categorySections, searchQuery])

  // Swiggy categories catalog list (combining grouped and dynamic ones)
  const menuCategories = useMemo(() => {
    const list = []
    filteredCategorySections.sections.forEach(sec => {
      if (experienceMode === 'restaurant') return

      const predef = (customSections || DEFAULT_CAFE_MENU_SECTIONS).find(c => c.tag === sec.tag) as any
      list.push({
        tag: sec.tag,
        title: sec.title,
        emoji: sec.emoji,
        image: predef?.imageUrl || predef?.image || getCafeSectionImage(sec.tag),
        count: sec.products.length,
        products: sec.products
      })
    })
    if (filteredCategorySections.moreItems.length > 0 && experienceMode === 'cafe') {
      list.push({
        tag: 'more',
        title: 'More Specials',
        emoji: '🍽️',
        image: '/cafe_all_menu_category.png',
        count: filteredCategorySections.moreItems.length,
        products: filteredCategorySections.moreItems
      })
    }
    return list
  }, [filteredCategorySections, customSections, experienceMode])

  // Scroll spy scrollend event listener to unlock scrollspy tracking when smooth scroll completes
  useEffect(() => {
    const handleScrollEnd = () => {
      isScrollingRef.current = false
      if (scrollTimeoutRef.current) {
        clearTimeout(scrollTimeoutRef.current)
        scrollTimeoutRef.current = null
      }
    }
    window.addEventListener('scrollend', handleScrollEnd)
    return () => {
      window.removeEventListener('scrollend', handleScrollEnd)
      if (scrollTimeoutRef.current) clearTimeout(scrollTimeoutRef.current)
    }
  }, [])

  // Scroll tracker logic (scrollspy + sticky bar)
  useEffect(() => {
    const handleScroll = () => {
      // Determine if floating menu button should appear (after scrolling past hero banner)
      setShowFloatingMenuBtn(window.scrollY > 300)

      // Determine if categories bar should be sticky
      if (categoriesBarRef.current) {
        const barTop = categoriesBarRef.current.offsetTop
        const threshold = barTop - navbarHeight
        setIsSticky(window.scrollY > threshold)
      }

      if (isScrollingRef.current) return

      const headerOffset = navbarHeight + 85
      const scrollPosition = window.scrollY + headerOffset

      let currentActive = ''
      
      // Check active category row
      menuCategories.filter(c => c.tag !== 'all').forEach(cat => {
        const el = document.getElementById(`cafe-section-${cat.tag}`)
        if (el && scrollPosition >= el.offsetTop) {
          currentActive = cat.tag
        }
      })

      // If we've scrolled to the very bottom of the page, highlight the last category
      const isAtBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 12
      if (isAtBottom && menuCategories.length > 0) {
        const visibleCats = menuCategories.filter(c => c.tag !== 'all')
        if (visibleCats.length > 0) {
          currentActive = visibleCats[visibleCats.length - 1].tag
        }
      }

      if (currentActive) {
        setActiveCategory(currentActive)
      }
    }

    window.addEventListener('scroll', handleScroll)
    // Initialize active state on mount
    handleScroll()
    return () => window.removeEventListener('scroll', handleScroll)
  }, [filteredCategorySections, menuCategories, navbarHeight])

  // Auto-reset active category if it gets filtered out of the visible list
  useEffect(() => {
    if (menuCategories.length > 0) {
      const isStillVisible = menuCategories.some(c => c.tag === activeCategory)
      if (!isStillVisible) {
        setActiveCategory(menuCategories[0].tag)
      }
    } else {
      setActiveCategory('')
    }
  }, [menuCategories, activeCategory])

  // Auto-scroll vertical sidebar (on mobile) to center active tag button (debounced by 150ms to prevent jittering when scrolling fast)
  useEffect(() => {
    if (!activeCategory) return

    const timeoutId = setTimeout(() => {
      const isMobile = window.innerWidth < 768
      if (isMobile) {
        const activeTabEl = document.getElementById(`mobile-category-tab-${activeCategory}`)
        const containerEl = document.getElementById('mobile-cafe-sidebar')
        if (activeTabEl && containerEl) {
          const containerHeight = containerEl.clientHeight
          const tabOffsetTop = activeTabEl.offsetTop
          const tabHeight = activeTabEl.clientHeight
          const targetScrollTop = tabOffsetTop - (containerHeight / 2) + (tabHeight / 2)
          
          containerEl.scrollTo({
            top: targetScrollTop,
            behavior: 'smooth'
          })
        }
      }
    }, 150)

    return () => clearTimeout(timeoutId)
  }, [activeCategory])

  // Smooth scroll handler
  const scrollToCategory = (tag: string) => {
    const isMobile = window.innerWidth < 768
    const idPrefix = isMobile ? 'mobile-category-section-' : 'category-section-'
    const el = document.getElementById(`${idPrefix}${tag}`)
    
    if (el) {
      const headerOffset = navbarHeight + 8
      const elementPosition = el.offsetTop
      const offsetPosition = elementPosition - headerOffset

      // Lock scrollspy updates during programmatic smooth scroll
      isScrollingRef.current = true
      setActiveCategory(tag)
      setIsFloatingMenuOpen(false)

      window.scrollTo({
        top: offsetPosition >= 0 ? offsetPosition : 0,
        behavior: 'smooth'
      })
      
      // Fallback timeout to re-enable scrollspy if scrollend is not supported or does not fire
      if (scrollTimeoutRef.current) clearTimeout(scrollTimeoutRef.current)
      scrollTimeoutRef.current = setTimeout(() => {
        isScrollingRef.current = false
      }, 1000)
    }
  }

  const currentActiveTag = activeCategory || menuCategories[0]?.tag || ''
  const activeSection = filteredCategorySections.sections.find(s => s.tag === currentActiveTag)
  const activeSectionProducts = activeSection ? activeSection.products : (currentActiveTag === 'more' ? filteredCategorySections.moreItems : [])
  const activeSectionTitle = activeSection ? activeSection.title : (currentActiveTag === 'more' ? 'More Specials' : 'Fresh Specials')
  const activeSectionEmoji = activeSection ? activeSection.emoji : (currentActiveTag === 'more' ? '🍽️' : '☕')
  const activeSectionDescription = activeSection ? activeSection.description : (currentActiveTag === 'more' ? 'Additional cafe items and specials' : 'Prepared Fresh & Delivered Fast')

  return (
    <div className="container mx-auto px-4 py-6 max-w-4xl relative select-none">
      {/* Premium ambient glow background effects */}
      <div className="absolute -top-12 left-1/2 -translate-x-1/2 w-64 h-32 rounded-full blur-3xl pointer-events-none opacity-40 dark:opacity-20"
           style={{ background: 'radial-gradient(circle, rgba(249,115,22,0.3) 0%, transparent 70%)' }} />

      {/* 1. Full-width Segment Controller Switcher */}
      <div className="w-full select-none mb-5">
        <div className="relative flex w-full h-12 p-1 bg-zinc-150/50 dark:bg-zinc-900/40 backdrop-blur-xl rounded-2xl shadow-[0_8px_32px_rgba(0,0,0,0.04)] dark:shadow-[0_8px_32px_rgba(0,0,0,0.2)] border border-white/50 dark:border-white/[0.04] overflow-hidden items-center">
          <Link
            href="/?mode=grocery"
            className="relative flex-1 h-full text-xs sm:text-sm font-black tracking-wider uppercase transition-all duration-300 z-10 flex items-center justify-center gap-2 cursor-pointer text-zinc-600 dark:text-zinc-350 hover:text-zinc-900 dark:hover:text-white"
          >
            <ShoppingBag className="h-4 w-4 sm:h-5 sm:w-5" strokeWidth={2.5} />
            <span>Grocery</span>
          </Link>
          <button
            disabled
            className="relative flex-1 h-full text-xs sm:text-sm font-black tracking-wider uppercase transition-all duration-300 z-10 flex items-center justify-center gap-2 text-white scale-102"
          >
            <Utensils className="h-4 w-4 sm:h-5 sm:w-5" strokeWidth={2.5} />
            <span>Food</span>
          </button>
          
          {/* Sliding indicator positioned on Food (right tab) */}
          <div
            className="absolute top-1 bottom-1 rounded-xl -z-0 bg-gradient-to-r from-orange-600 to-amber-500 shadow-[0_4px_16px_rgba(249,115,22,0.35)]"
            style={{
              width: 'calc(50% - 4px)',
              left: 'calc(50% + 2px)',
            }}
          />
        </div>
      </div>

      <div className="flex flex-col gap-6.5">
        {/* 2. Full-bleed Cafe Cute Promo Banner */}
        <div className="relative w-full aspect-[21/9] sm:aspect-[16/6] md:aspect-[16/5] rounded-3xl overflow-hidden shadow-lg border border-zinc-150/20 dark:border-zinc-800/35">
          <Image
            src="/cafe_banner.png"
            alt="Café & Restaurant Promo Banner"
            fill
            sizes="100vw"
            className="object-cover"
            priority
          />
        </div>


        {/* 4. Experience Switcher */}
        <div className="space-y-3 select-none">
          <div className="relative flex w-full p-1 bg-[#e4e2de]/60 dark:bg-zinc-900/50 rounded-full border border-zinc-200/20 dark:border-zinc-800/40 overflow-hidden">
            <button
              onClick={() => {
                setExperienceMode('cafe')
                setActiveCategory('hot-beverage')
                const target = document.getElementById('cafe-categories-start')
                if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' })
              }}
              className={cn(
                "relative flex-1 py-3.5 text-sm font-semibold transition-all duration-300 z-15 flex items-center justify-center gap-2 cursor-pointer rounded-full",
                experienceMode === 'cafe'
                  ? "text-zinc-900 dark:text-white"
                  : "text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-300"
              )}
            >
              <Coffee className="h-4 w-4 sm:h-5 sm:w-5" strokeWidth={2.5} />
              <span>Cafe</span>
            </button>
            
            <button
              onClick={() => {
                setExperienceMode('restaurant')
                setActiveCategory('chinese')
                const target = document.getElementById('cafe-categories-start')
                if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' })
              }}
              className={cn(
                "relative flex-1 py-3.5 text-sm font-semibold transition-all duration-300 z-15 flex items-center justify-center gap-2 cursor-pointer rounded-full",
                experienceMode === 'restaurant'
                  ? "text-zinc-900 dark:text-white"
                  : "text-zinc-500 dark:text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-300"
              )}
            >
              <ChefHat className="h-4 w-4 sm:h-5 sm:w-5" strokeWidth={2.5} />
              <span>Restaurant</span>
            </button>

            {/* Sliding Pill Indicator */}
            <div
              className="absolute top-1 bottom-1 rounded-full bg-white dark:bg-zinc-800 shadow-[0_4px_12px_rgba(0,0,0,0.06)] dark:shadow-[0_4px_12px_rgba(0,0,0,0.25)] border border-white/50 dark:border-zinc-700/35 transition-all duration-300 z-10"
              style={{
                width: 'calc(50% - 4px)',
                left: experienceMode === 'cafe' ? '4px' : 'calc(50%)',
              }}
            />
          </div>
        </div>

        {experienceMode === 'restaurant' ? (
          <div className="flex flex-col items-center justify-center py-16 text-center select-none bg-muted/10 dark:bg-zinc-900/10 border border-dashed border-border rounded-3xl p-8 mt-4">
            <span className="text-5xl animate-bounce-gentle">🛎️</span>
            <h3 className="text-base font-extrabold text-text-primary mt-4">Restaurant Dine is coming soon!</h3>
            <p className="text-xs text-text-secondary max-w-[280px] mt-1.5 leading-relaxed">
              We are partnering with your favorite local restaurants to bring delicious full meals to your doorstep shortly. Stay tuned!
            </p>
          </div>
        ) : (
          <>
            {/* 5. Offers for you */}
        <div className="space-y-3 select-none">
          <div className="flex items-center justify-between">
            <h3 className="text-xs sm:text-sm font-black text-text-primary tracking-tight uppercase">
              Offers for you
            </h3>
            <span className="text-[11px] font-black text-orange-600 hover:underline cursor-pointer">See all</span>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {/* Left wide card */}
            <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-rose-50 to-rose-100/70 dark:from-rose-950/15 dark:to-rose-900/10 p-4 border border-rose-200/40 dark:border-rose-800/20 flex flex-col justify-between min-h-[155px]">
              <div className="text-left">
                <span className="text-[8px] font-black uppercase tracking-wider text-rose-500 block mb-0.5">Special Cafe Coupon</span>
                <h4 className="text-sm font-black text-zinc-950 dark:text-white leading-tight">Flat 20% OFF</h4>
                <p className="text-[9.5px] font-bold text-zinc-550 mt-0.5">On all cafe orders</p>
              </div>
              <div className="absolute right-1 bottom-1 w-14 h-14 pointer-events-none">
                <Image src="/cafe_brews_category.png" alt="Coffee Cup" fill sizes="56px" className="object-contain" />
              </div>
              <div className="mt-3 flex flex-col gap-1.5 self-start">
                <span className="px-2 py-0.5 bg-white dark:bg-zinc-800 border border-dashed border-rose-300 dark:border-rose-800 text-[9.5px] font-black text-rose-600 dark:text-rose-455 rounded-lg">
                  CAFE20
                </span>
                <span className="text-[7.5px] font-bold text-zinc-450 dark:text-zinc-500">T&C Apply</span>
              </div>
            </div>

            {/* Right stacked cards */}
            <div className="flex flex-col gap-3">
              <div className="relative overflow-hidden rounded-2.5xl bg-zinc-50 dark:bg-zinc-900/30 p-3 border border-zinc-150/40 dark:border-zinc-800/30 flex items-center justify-between min-h-[72px] sm:min-h-[76px]">
                <div className="text-left max-w-[65%] min-w-0">
                  <h4 className="text-xs font-black text-text-primary leading-tight truncate">Up to 30% OFF</h4>
                  <p className="text-[8.5px] font-bold text-text-secondary mt-0.5 truncate">On restaurant orders</p>
                </div>
                <div className="w-10 h-10 relative shrink-0">
                  <Image src="/cafe_burgers_category.png" alt="Burger Offer" fill sizes="40px" className="object-contain" />
                </div>
              </div>
              
              <div className="relative overflow-hidden rounded-2.5xl bg-zinc-50 dark:bg-zinc-900/30 p-3 border border-zinc-150/40 dark:border-zinc-800/30 flex items-center justify-between min-h-[72px] sm:min-h-[76px]">
                <div className="text-left max-w-[65%] min-w-0">
                  <h4 className="text-xs font-black text-text-primary leading-tight truncate">Free Delivery</h4>
                  <p className="text-[8.5px] font-bold text-text-secondary mt-0.5 truncate">On orders above ₹199</p>
                </div>
                <div className="w-10 h-10 relative shrink-0">
                  <Image src="/delivered_package_proof.png" alt="Free Delivery" fill sizes="40px" className="object-contain" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* 6. Popular near you */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-xs sm:text-sm font-black text-text-primary tracking-tight uppercase">
              Popular near you
            </h3>
            <span className="text-[11px] font-black text-orange-600 hover:underline cursor-pointer">See all</span>
          </div>
          
          <div className="flex gap-3.5 md:gap-4 overflow-x-auto pb-4 pt-1.5 scrollbar-hide snap-x snap-mandatory scroll-smooth px-1">
            {mappedProducts
              .filter(p => p.tags?.includes('popular') || p.tags?.includes('bestseller') || p.tags?.includes('top-pick') || p.price < 150)
              .slice(0, 10)
              .map((p: any) => (
                <div key={p.id} className="w-[140px] min-[375px]:w-[160px] sm:w-[180px] md:w-[220px] shrink-0 snap-start">
                  <ProductCard product={p} />
                </div>
              ))}
          </div>
        </div>

        {/* Sticky Glassmorphic Category Quick-Bar (ScrollSpy) */}
        <div ref={categoriesBarRef} className="h-14 w-full scroll-mt-24 select-none">
          <div className={cn(
            "w-full transition-all duration-300 z-30",
            isSticky 
              ? "fixed left-0 right-0 bg-white/80 dark:bg-zinc-950/80 backdrop-blur-xl border-b border-zinc-150/40 dark:border-zinc-900/40 shadow-[0_4px_25px_rgba(0,0,0,0.03)] px-4 py-2.5" 
              : "py-1"
          )}
          style={isSticky ? { top: `${navbarHeight}px` } : {}}
          >
            <div className="max-w-4xl mx-auto flex gap-3 overflow-x-auto scrollbar-premium py-1 px-1">
              {menuCategories.filter(c => c.tag !== 'all').map((cat) => {
                const isActive = activeCategory === cat.tag
                return (
                  <button
                    key={cat.tag}
                    onClick={() => {
                      setActiveCategory(cat.tag)
                      const target = document.getElementById(`cafe-section-${cat.tag}`)
                      if (target) {
                        const offset = isSticky ? (navbarHeight + 64) : (navbarHeight + 110)
                        const targetPosition = target.offsetTop - offset
                        window.scrollTo({ top: targetPosition, behavior: 'smooth' })
                      }
                    }}
                    className={cn(
                      "px-4 py-2.5 rounded-full text-xs font-semibold shrink-0 transition-all duration-200 cursor-pointer flex items-center gap-1.5 border border-transparent shadow-[0_2px_8px_rgba(0,0,0,0.015)]",
                      isActive
                        ? "bg-gradient-to-r from-orange-500 to-amber-500 text-white shadow-[0_4px_12px_rgba(249,115,22,0.25)] scale-[1.03]"
                        : "bg-[#f4f2ee] dark:bg-zinc-900/60 text-zinc-650 dark:text-zinc-400 hover:bg-zinc-200/50 dark:hover:bg-zinc-800/80"
                    )}
                  >
                    <div className="w-4 h-4 rounded-full overflow-hidden relative shrink-0">
                      {cat.image ? (
                        <Image src={cat.image} alt={cat.title} fill sizes="16px" className="object-cover" />
                      ) : (
                        <span className="text-[10px]">{cat.emoji}</span>
                      )}
                    </div>
                    <span>{cat.title}</span>
                  </button>
                )
              })}
            </div>
          </div>
        </div>

        {/* Categories Start Anchor */}
        <div id="cafe-categories-start" className="w-full scroll-mt-36" />

        {/* 7. Category-wise Product Sliders (vertically stacked) */}
        {menuCategories.filter(cat => cat.tag !== 'all' && cat.products?.length > 0).map((cat) => {
          const displayProducts = cat.products.slice(0, 5)
          const hasMore = cat.products.length > 5
          const sectionHref = `/cafe?section=${cat.tag}`

          return (
            <div 
              key={cat.tag} 
              id={`cafe-section-${cat.tag}`}
              className="space-y-3 pt-6 border-t border-zinc-200/50 dark:border-zinc-800/40 first:border-t-0 scroll-mt-24"
            >
              <div className="flex items-center justify-between px-1">
                <div className="flex items-center gap-1.5">
                  <div className="w-6 h-6 rounded-full overflow-hidden relative bg-zinc-150/50 dark:bg-zinc-800 border border-zinc-200/30 dark:border-zinc-700/30 shrink-0">
                    {cat.image ? (
                      <Image src={cat.image} alt={cat.title} fill sizes="24px" className="object-cover" />
                    ) : (
                      <span className="text-xs">{cat.emoji}</span>
                    )}
                  </div>
                  <h4 className="text-xs sm:text-sm font-black uppercase tracking-wider text-text-primary">
                    {cat.title} Specials
                  </h4>
                </div>
                <Link href={sectionHref} className="text-[11px] font-black text-rose-600 dark:text-rose-455 hover:opacity-85 flex items-center gap-0.5 select-none">
                  <span>See All ({cat.products.length})</span>
                  <ChevronRight size={10} strokeWidth={3} />
                </Link>
              </div>
              
              <div className="flex gap-3.5 md:gap-4 overflow-x-auto pb-4 pt-1.5 scrollbar-hide snap-x snap-mandatory scroll-smooth px-1">
                {displayProducts.map((p: any) => (
                  <div key={p.id} className="w-[140px] min-[375px]:w-[160px] sm:w-[180px] md:w-[220px] shrink-0 snap-start">
                    <ProductCard product={p} />
                  </div>
                ))}
                
                {hasMore && (
                  <div className="w-[140px] min-[375px]:w-[160px] sm:w-[180px] md:w-[220px] shrink-0 snap-start">
                    <Link href={sectionHref} className="group relative flex flex-col items-center justify-center overflow-hidden rounded-2xl border border-dashed border-zinc-200 dark:border-zinc-800 bg-card p-3 shadow-xs transition-all duration-300 hover:border-orange-500/40 hover:bg-orange-500/5 cursor-pointer h-[210px] min-[375px]:h-[230px] sm:h-[250px] md:h-[290px] w-full">
                      <div className="w-10 h-10 rounded-full bg-orange-500/10 dark:bg-orange-500/5 flex items-center justify-center text-orange-600 dark:text-orange-450 group-hover:scale-110 transition-transform duration-300">
                        <ChevronRight size={20} strokeWidth={2.5} />
                      </div>
                      <span className="text-xs font-black text-text-primary mt-3 text-center">
                        See More
                      </span>
                      <span className="text-[10px] font-bold text-text-secondary mt-1 text-center">
                        +{cat.products.length - 5} items
                      </span>
                    </Link>
                  </div>
                )}
              </div>
            </div>
          )
        })}
          </>
        )}
      </div>
    </div>
  )
}
