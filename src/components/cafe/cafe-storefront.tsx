'use client'

import { useState, useMemo, useEffect, useCallback, useRef } from 'react'
import { ChevronRight, Menu as MenuIcon, X, Plus, Minus, Check } from 'lucide-react'
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

  const isScrollingRef = useRef(false)
  const scrollTimeoutRef = useRef<NodeJS.Timeout | null>(null)

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
      const predef = (customSections || DEFAULT_CAFE_MENU_SECTIONS).find(c => c.tag === sec.tag) as any
      list.push({
        tag: sec.tag,
        title: sec.title,
        emoji: sec.emoji,
        image: predef?.imageUrl || predef?.image || getCafeSectionImage(sec.tag),
        count: sec.products.length
      })
    })
    if (filteredCategorySections.moreItems.length > 0) {
      list.push({
        tag: 'more',
        title: 'More Specials',
        emoji: '🍽️',
        image: '/cafe_all_menu_category.png',
        count: filteredCategorySections.moreItems.length
      })
    }
    return list
  }, [filteredCategorySections, customSections])

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

  // Scroll tracker logic (scrollspy)
  useEffect(() => {
    const handleScroll = () => {
      // Determine if floating menu button should appear (after scrolling past hero banner)
      setShowFloatingMenuBtn(window.scrollY > 250)

      if (isScrollingRef.current) return

      const headerOffset = navbarHeight + 16
      const scrollPosition = window.scrollY + headerOffset

      let currentActive = ''
      const isMobile = window.innerWidth < 768
      const idPrefix = isMobile ? 'mobile-category-section-' : 'category-section-'

      // Dynamic tags sections
      filteredCategorySections.sections.forEach(sec => {
        const el = document.getElementById(`${idPrefix}${sec.tag}`)
        if (el && scrollPosition >= el.offsetTop) {
          currentActive = sec.tag
        }
      })

      // More specials section
      const moreEl = document.getElementById(`${idPrefix}more`)
      if (moreEl && scrollPosition >= moreEl.offsetTop) {
        currentActive = 'more'
      }

      // If we've scrolled to the very bottom of the page, highlight the last category
      const isAtBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 12
      if (isAtBottom && menuCategories.length > 0) {
        currentActive = menuCategories[menuCategories.length - 1].tag
      }

      if (currentActive) {
        setActiveCategory(currentActive)
      } else if (menuCategories.length > 0) {
        setActiveCategory(menuCategories[0].tag)
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
    <div className="container mx-auto px-4 py-6 max-w-7xl relative">
      {/* -------------------- DESKTOP LAYOUT -------------------- */}
      <div className="hidden md:flex flex-col gap-6">
        {/* Breadcrumb */}
        <nav className="flex items-center gap-1.5 text-[9px] font-black text-zinc-450 dark:text-zinc-500 uppercase tracking-widest select-none bg-zinc-50 dark:bg-zinc-900/30 px-3 py-1.5 rounded-full w-fit border border-zinc-150/40 dark:border-zinc-800/20 mb-3">
          <Link href="/" className="hover:text-primary transition-colors">Home</Link>
          <ChevronRight size={10} className="text-zinc-350 dark:text-zinc-700" />
          {currentActiveTag && currentActiveTag !== 'all' ? (
            <>
              <Link href="/cafe" onClick={() => setActiveCategory('')} className="hover:text-primary transition-colors">
                FastKirana Cafe ☕
              </Link>
              <ChevronRight size={10} className="text-zinc-350 dark:text-zinc-700" />
              <span className="text-[#FF2E55] font-extrabold">{activeSectionTitle}</span>
            </>
          ) : (
            <span className="text-[#FF2E55] font-extrabold">FastKirana Cafe ☕</span>
          )}
        </nav>

        {/* Hero Cafe Banner */}
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-[#2a1711] via-[#1d0e0a] to-[#120805] dark:from-[#1b0d09] dark:via-[#0e0604] dark:to-black text-white p-4 md:p-8 flex items-center justify-between min-h-[130px] md:min-h-[165px] shadow-[0_8px_30px_rgba(35,21,16,0.15)] border border-[#3e241b] dark:border-[#20110c]">
          <div className="absolute -top-12 -right-12 w-48 h-48 rounded-full bg-amber-500/15 dark:bg-amber-500/10 blur-[50px] pointer-events-none animate-pulse-gentle" />
          <div className="relative z-10 max-w-[62%] flex flex-col items-start text-left space-y-0.5 md:space-y-1">
            <div className="flex items-center gap-1.5">
              <h1 className="text-lg md:text-2xl font-black tracking-tight flex items-center gap-1.5">
                <span className="bg-gradient-to-r from-amber-200 via-orange-300 to-yellow-100 bg-clip-text text-transparent font-black">Café</span>
                <span className="text-base animate-float">☕</span>
              </h1>
            </div>
            <span className="inline-flex text-[8px] md:text-[10px] font-black bg-amber-500/10 border border-amber-500/20 text-amber-300 rounded-full px-2.5 py-0.5 tracking-wider uppercase mb-1">
              Freshly Prepared. Fast Delivered.
            </span>
            <p className="text-[10px] md:text-xs text-white/70 leading-snug font-semibold max-w-[320px]">
              Coffee, Beverages, South Indian, Chinese & more from your favorite café.
            </p>
          </div>
          <div className="absolute right-4 md:right-8 bottom-0 top-0 w-[35%] md:w-[40%] flex items-center justify-end select-none pointer-events-none">
            <div className="relative w-full h-[110px] md:h-[145px] lg:h-[165px]">
              <Image
                src="/cafe_banner.png"
                alt="South Indian and Chinese Cafe Specials"
                fill
                sizes="(max-width: 768px) 35vw, 300px"
                className="object-contain drop-shadow-[0_12px_24px_rgba(0,0,0,0.4)] animate-float"
                priority
              />
            </div>
          </div>
        </div>

        {/* Split layout: Sidebar categories for desktop */}
        <div className="flex gap-8 items-start">
          <aside 
            style={{ 
              top: `${navbarHeight + 16}px`, 
              maxHeight: `calc(100vh - ${navbarHeight + 40}px)` 
            }}
            className="w-64 shrink-0 sticky overflow-y-auto pr-2 border-r border-border/40 space-y-1 scrollbar-none py-1"
          >
            <div className="text-[10px] font-extrabold text-text-muted uppercase tracking-wider px-3 mb-2">
              Menu Categories
            </div>
            {menuCategories.map((cat) => {
              const isActive = activeCategory === cat.tag
              return (
                <button
                  key={cat.tag}
                  onClick={() => scrollToCategory(cat.tag)}
                  className={cn(
                    'w-full flex items-center justify-between px-3 py-2.5 rounded-xl transition-all duration-200 cursor-pointer text-left relative z-10',
                    isActive
                      ? 'text-rose-600 dark:text-rose-400 font-extrabold shadow-sm'
                      : 'text-text-secondary hover:bg-muted/40 hover:text-text-primary'
                  )}
                >
                  {/* Sliding active background */}
                  {isActive && (
                    <motion.div
                      layoutId="activeCafeCategoryDesktop"
                      className="absolute inset-0 rounded-xl bg-rose-50 dark:bg-rose-950/20 -z-10"
                      transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                    />
                  )}
                  <div className="flex items-center gap-2.5 min-w-0">
                    <div className="w-6 h-6 rounded-full overflow-hidden shrink-0 bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/40 relative">
                      {cat.image ? (
                        <Image
                          src={cat.image}
                          alt={cat.title}
                          fill
                          sizes="24px"
                          className="object-cover"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center bg-amber-500/10 text-xs select-none">
                          {cat.emoji}
                        </div>
                      )}
                    </div>
                    <span className="text-xs truncate">{cat.title}</span>
                  </div>
                  <span className={cn(
                    'text-[9px] font-black px-1.5 py-0.5 rounded-full shrink-0 relative z-20 transition-all duration-200',
                    isActive
                      ? 'bg-rose-500 text-white'
                      : 'bg-muted-foreground/10 text-text-secondary'
                  )}>
                    {cat.count}
                  </span>
                </button>
              )
            })}
          </aside>

          {/* Desktop Categories Content */}
          <div className="flex-1 space-y-8">
            {/* Desktop Filters & Search Bar */}
            <div className="flex justify-between items-center bg-card border border-border/50 rounded-2xl p-4 shadow-sm select-none mb-2">
              <div className="flex items-center gap-4">
                <span className="text-xs font-extrabold text-text-primary uppercase tracking-wider">Cafe Menu</span>
              </div>
              {/* Café Search Input */}
              <div className="relative flex-1 max-w-sm">
                <input
                  type="text"
                  placeholder="Search in Cafe Menu..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full h-9 pl-9 pr-8 text-xs font-semibold bg-muted/40 hover:bg-muted/60 focus:bg-background border border-border/80 focus:border-rose-500/30 rounded-xl focus:outline-none transition-all"
                />
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted text-xs select-none">🔍</span>
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery('')}
                    className="absolute right-3 top-1/2 -translate-y-1/2 h-5 w-5 rounded-full flex items-center justify-center bg-muted-foreground/15 hover:bg-muted-foreground/25 text-text-secondary text-[9px] font-black cursor-pointer"
                  >
                    ✕
                  </button>
                )}
              </div>
            </div>

            {filteredCategorySections.sections.map((section) => (
              <section key={section.tag} id={`category-section-${section.tag}`} className="space-y-4 pt-2 scroll-mt-24">
                <div className="flex items-center gap-2 px-1">
                  <span className="text-xl">{section.emoji}</span>
                  <div>
                    <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">{section.title}</h2>
                    <p className="text-xs text-text-secondary">{section.description}</p>
                  </div>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 md:gap-4">
                  {section.products.map((p: any) => (
                    <ProductCard key={p.id} product={p} />
                  ))}
                </div>
              </section>
            ))}

            {filteredCategorySections.moreItems.length > 0 && (
              <section id="category-section-more" className="space-y-4 pt-2 scroll-mt-24">
                <div className="flex items-center gap-2 px-1">
                  <span className="text-xl">🍽️</span>
                  <div>
                    <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">More Specials</h2>
                    <p className="text-xs text-text-secondary">Additional cafe items and specials</p>
                  </div>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 md:gap-4">
                  {filteredCategorySections.moreItems.map((p: any) => (
                    <ProductCard key={p.id} product={p} />
                  ))}
                </div>
              </section>
            )}

            {filteredCategorySections.sections.length === 0 && filteredCategorySections.moreItems.length === 0 && (
              <div className="flex flex-col items-center justify-center py-16 text-center select-none bg-muted/10 dark:bg-zinc-900/10 border border-dashed border-border rounded-3xl p-6">
                <span className="text-4xl animate-bounce-gentle">🥗</span>
                <h3 className="text-sm font-extrabold text-text-primary mt-3">No matching items found</h3>
                <p className="text-xs text-text-secondary max-w-[280px] mt-1">Try clearing your search query to see all items.</p>
                <button
                  onClick={() => { setSearchQuery('') }}
                  className="mt-4 px-4 py-2 bg-rose-500 hover:bg-rose-600 text-white font-extrabold text-xs rounded-xl shadow-md transition-all active:scale-95 cursor-pointer"
                >
                  Show All Items
                </button>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* -------------------- MOBILE LAYOUT (SPLIT SIDEBAR VIEW) -------------------- */}
      <div id="mobile-cafe-layout-root" className="md:hidden flex flex-col -mx-4 min-h-[calc(100vh-140px)]">
        {/* Mobile Breadcrumbs */}
        <div className="px-4 mb-2.5">
          <nav className="flex items-center gap-1.5 text-[9px] font-black text-zinc-450 dark:text-zinc-500 uppercase tracking-widest select-none bg-zinc-50 dark:bg-zinc-900/30 px-3 py-1.5 rounded-full w-fit border border-zinc-150/40 dark:border-zinc-800/20">
            <Link href="/" className="hover:text-primary transition-colors">Home</Link>
            <ChevronRight size={10} className="text-zinc-350 dark:text-zinc-700" />
            {currentActiveTag && currentActiveTag !== 'all' ? (
              <>
                <Link href="/cafe" onClick={() => setActiveCategory('')} className="hover:text-primary transition-colors">
                  Cafe ☕
                </Link>
                <ChevronRight size={10} className="text-zinc-350 dark:text-zinc-700" />
                <span className="text-[#FF2E55] font-extrabold truncate max-w-[100px]">
                  {menuCategories.find(c => c.tag === currentActiveTag)?.title || 'All'}
                </span>
              </>
            ) : (
              <span className="text-[#FF2E55] font-extrabold">Cafe ☕</span>
            )}
          </nav>
        </div>

        {/* Main Split Area */}
        <div className="flex flex-1 border-t border-zinc-100 dark:border-zinc-900">
          {/* Mobile Left Sidebar: Categories */}
          <aside 
            id="mobile-cafe-sidebar" 
            className="w-[84px] shrink-0 border-r border-zinc-100 dark:border-zinc-900/50 bg-white dark:bg-zinc-950/70 backdrop-blur-md py-2 space-y-1 overflow-y-auto max-h-[calc(100vh-160px)] scrollbar-none sticky top-[56px] self-start shadow-sm"
          >
            {menuCategories.map((cat) => {
              const isActive = currentActiveTag === cat.tag
              return (
                <motion.button
                  key={cat.tag}
                  id={`mobile-category-tab-${cat.tag}`}
                  whileTap={{ scale: 0.93 }}
                  onClick={() => scrollToCategory(cat.tag)}
                  className={cn(
                    'w-full flex flex-col items-center text-center gap-1.5 py-3.5 px-1 relative transition-all cursor-pointer select-none z-10',
                    isActive ? 'text-rose-600 dark:text-rose-400 font-extrabold' : 'text-text-secondary hover:text-text-primary'
                  )}
                >
                  {/* Sliding Left indicator bar */}
                  {isActive && (
                    <motion.div
                      layoutId="activeCafeCategoryMobileBar"
                      className="absolute left-0 top-1/4 bottom-1/4 w-[4px] bg-rose-500 dark:bg-rose-400 rounded-r-full shadow-[0_0_8px_rgba(244,63,94,0.6)]"
                      transition={{ type: 'spring', stiffness: 350, damping: 25 }}
                    />
                  )}

                  {/* Icon Card Container */}
                  <div
                    className={cn(
                      'w-[46px] h-[46px] rounded-full flex items-center justify-center transition-all duration-300 border shadow-[0_2px_6px_rgba(0,0,0,0.01)] relative z-10 overflow-hidden',
                      isActive
                        ? 'border-rose-400/80 dark:border-rose-500/50 scale-[1.05] shadow-[0_0_12px_rgba(244,63,94,0.25)]'
                        : 'bg-white dark:bg-zinc-900 border-zinc-100 dark:border-zinc-800'
                    )}
                  >
                    {/* Sliding active inner circle background */}
                    {isActive && (
                      <motion.div
                        layoutId="activeCafeCategoryMobileCircle"
                        className="absolute inset-0 rounded-full bg-rose-50/70 dark:bg-rose-950/20 -z-10"
                        transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                      />
                    )}
                    {cat.image ? (
                      <Image
                        src={cat.image}
                        alt={cat.title}
                        fill
                        sizes="46px"
                        className="object-cover relative z-20"
                      />
                    ) : (
                      <span className="text-2xl filter drop-shadow-sm select-none leading-none relative z-20">{cat.emoji}</span>
                    )}
                  </div>

                  {/* Category Name */}
                  <span className="text-[9.5px] leading-tight font-extrabold px-1 tracking-tight select-none mt-0.5 relative z-20">
                    {cat.title}
                  </span>
                </motion.button>
              )
            })}
          </aside>

          {/* Mobile Right Content Panel */}
          <div className="flex-1 min-w-0 bg-background px-3 py-3 space-y-4">
            {/* Cafe Banner inside Mobile Right Panel */}
            <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-[#1d0e0a] via-[#120805] to-black text-white p-3.5 flex items-center justify-between min-h-[96px] shadow-[0_0_20px_rgba(244,63,94,0.12)] border border-rose-950/40 select-none mb-2">
              <div className="absolute -top-10 -right-10 w-24 h-24 rounded-full bg-rose-500/15 blur-[25px] pointer-events-none animate-pulse-gentle" />
              <div className="absolute -bottom-10 -left-10 w-24 h-24 rounded-full bg-amber-500/10 blur-[25px] pointer-events-none" />
              <div className="relative z-10 max-w-[65%] text-left">
                <span className="text-[8.5px] font-black tracking-widest text-rose-400 dark:text-rose-300 block mb-0.5 uppercase">
                  ⚡ FASTKIRANA CAFÉ
                </span>
                <h2 className="text-xs font-black text-white tracking-tight leading-tight mb-1 select-none">
                  {activeSectionTitle || 'Fresh Specials'}
                </h2>
                <p className="text-[9px] font-bold text-zinc-400 leading-none">
                  Prepared Fresh & Delivered Fast
                </p>
              </div>
              <div className="relative z-10 shrink-0 text-3xl font-bold animate-float pr-2 filter drop-shadow-[0_0_10px_rgba(244,63,94,0.4)] leading-none">
                {activeSectionEmoji}
              </div>
            </div>

            {/* Mobile Filters & Search Bar */}
            <div className="space-y-2.5 pb-1 select-none">

              {/* Café Search Input */}
              <div className="relative w-full">
                <input
                  type="text"
                  placeholder="Search Cafe Menu..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full h-8.5 pl-8.5 pr-8 text-[11px] font-semibold bg-muted/30 border border-border/80 focus:border-rose-500/20 rounded-xl focus:outline-none transition-all"
                />
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted text-[11px] select-none">🔍</span>
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery('')}
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 h-4.5 w-4.5 rounded-full flex items-center justify-center bg-muted-foreground/15 text-text-secondary text-[8px] font-black cursor-pointer"
                  >
                    ✕
                  </button>
                )}
              </div>
            </div>

            {/* Render Category Sections Vertically */}
            {filteredCategorySections.sections.map((section) => (
              <section 
                key={section.tag} 
                id={`mobile-category-section-${section.tag}`} 
                className="space-y-3 pt-1 scroll-mt-24"
              >
                <div className="flex items-center gap-1.5 px-0.5 pt-2 pb-1.5 border-b border-zinc-100 dark:border-zinc-900/60">
                  <span className="text-base filter drop-shadow-sm select-none">{section.emoji}</span>
                  <div className="flex items-baseline justify-between w-full">
                    <h3 className="text-[11px] font-black text-text-primary uppercase tracking-wider">{section.title}</h3>
                    <span className="text-[9px] font-black text-rose-500 bg-rose-50 dark:bg-rose-950/30 px-1.5 py-0.5 rounded-full">{section.products.length} Items</span>
                  </div>
                </div>

                <motion.div 
                  variants={containerVariants}
                  initial="hidden"
                  whileInView="show"
                  viewport={{ once: true, margin: "-10% 0px" }}
                  className="grid grid-cols-2 gap-2.5"
                >
                  {section.products.map((p: any) => (
                    <motion.div key={p.id} variants={itemVariants} className="h-full">
                      <ProductCard product={p} />
                    </motion.div>
                  ))}
                </motion.div>
              </section>
            ))}

            {/* Render More Specials section if it exists */}
            {filteredCategorySections.moreItems.length > 0 && (
              <section 
                id="mobile-category-section-more" 
                className="space-y-3 pt-1 scroll-mt-24 pb-20"
              >
                <div className="flex items-center gap-1.5 px-0.5 pt-2 pb-1.5 border-b border-zinc-100 dark:border-zinc-900/60">
                  <span className="text-base filter drop-shadow-sm select-none">🍽️</span>
                  <div className="flex items-baseline justify-between w-full">
                    <h3 className="text-[11px] font-black text-text-primary uppercase tracking-wider">More Specials</h3>
                    <span className="text-[9px] font-black text-rose-500 bg-rose-50 dark:bg-rose-950/30 px-1.5 py-0.5 rounded-full">{filteredCategorySections.moreItems.length} Items</span>
                  </div>
                </div>

                <motion.div 
                  variants={containerVariants}
                  initial="hidden"
                  whileInView="show"
                  viewport={{ once: true, margin: "-10% 0px" }}
                  className="grid grid-cols-2 gap-2.5"
                >
                  {filteredCategorySections.moreItems.map((p: any) => (
                    <motion.div key={p.id} variants={itemVariants} className="h-full">
                      <ProductCard product={p} />
                    </motion.div>
                  ))}
                </motion.div>
              </section>
            )}

            {filteredCategorySections.sections.length === 0 && filteredCategorySections.moreItems.length === 0 && (
              <div className="flex flex-col items-center justify-center py-16 text-center select-none bg-muted/10 dark:bg-zinc-900/10 border border-dashed border-border rounded-3xl p-6">
                <span className="text-4xl animate-bounce-gentle">🥗</span>
                <h3 className="text-sm font-extrabold text-text-primary mt-3">No matching items found</h3>
                <p className="text-xs text-text-secondary max-w-[240px] mt-1">Try clearing your search query to see all items.</p>
                <button
                  onClick={() => { setSearchQuery('') }}
                  className="mt-4 px-4 py-2 bg-rose-500 hover:bg-rose-600 text-white font-extrabold text-xs rounded-xl shadow-md transition-all active:scale-95 cursor-pointer"
                >
                  Show All Items
                </button>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Floating Menu Drawer Backdrop/Popup */}
      <AnimatePresence>
        {isFloatingMenuOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs cursor-pointer"
              onClick={() => setIsFloatingMenuOpen(false)}
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 220 }}
              className="fixed bottom-0 left-0 right-0 z-50 max-h-[60vh] bg-background border-t border-border rounded-t-3xl shadow-2xl overflow-hidden flex flex-col mx-auto max-w-sm"
            >
              <div className="w-12 h-1.5 bg-muted/60 rounded-full mx-auto my-3 shrink-0" />
              <div className="px-5 pb-3 border-b border-border/50 flex justify-between items-center shrink-0">
                <span className="text-xs font-black uppercase text-text-muted tracking-wider">Jump to Section</span>
                <button
                  onClick={() => setIsFloatingMenuOpen(false)}
                  className="p-1 rounded-full bg-muted/60 text-text-secondary hover:text-text-primary hover:bg-muted"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
              <div className="flex-1 overflow-y-auto px-4 py-3 space-y-1">
                {menuCategories.map((cat) => {
                  const isActive = currentActiveTag === cat.tag
                  return (
                    <button
                      key={cat.tag}
                      onClick={() => {
                        setActiveCategory(cat.tag)
                        setIsFloatingMenuOpen(false)
                        scrollToCategory(cat.tag)
                      }}
                      className={`w-full flex items-center justify-between p-3 rounded-xl transition-all cursor-pointer ${
                        isActive
                          ? 'bg-rose-500/10 text-rose-500 font-extrabold border border-rose-500/20'
                          : 'hover:bg-muted/40 text-text-primary border border-transparent'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-6 h-6 rounded-full overflow-hidden shrink-0 bg-zinc-50 dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/40 relative">
                          {cat.image ? (
                            <Image
                              src={cat.image}
                              alt={cat.title}
                              fill
                              sizes="24px"
                              className="object-cover"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center bg-amber-500/10 text-xs select-none">
                              {cat.emoji}
                            </div>
                          )}
                        </div>
                        <span className="text-sm font-bold">{cat.title}</span>
                      </div>
                      <span className="text-xs text-text-muted font-bold bg-muted px-2 py-0.5 rounded-full">
                        {cat.count}
                      </span>
                    </button>
                  )
                })}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  )
}
