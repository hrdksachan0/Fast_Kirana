'use client'

import { useState, useMemo, useEffect, useCallback } from 'react'
import { ChevronRight, Menu as MenuIcon, X, Plus, Minus, Check } from 'lucide-react'
import { Product } from '@/types'
import { ProductCard } from '@/components/product/product-card'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { useLiveStock } from '@/components/providers/live-stock-provider'
import { ProductImage } from '@/components/product/product-image'
import { Button } from '@/components/ui/button'

import { DEFAULT_CAFE_MENU_SECTIONS, CafeMenuSection } from '@/lib/constants'

interface CafeProductRowProps {
  product: any
  cafeOpen: boolean
}

export function CafeProductRow({ product, cafeOpen }: CafeProductRowProps) {
  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const quantity = getItemQuantity(product.id)
  const [showAdded, setShowAdded] = useState(false)

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
    addItem(cartProduct)
    setShowAdded(true)
    setTimeout(() => setShowAdded(false), 600)
  }, [addItem, cartProduct])

  const handleIncrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    updateQuantity(product.id, product.name, quantity + 1)
  }

  const handleDecrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
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
            {quantity === 0 ? (
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
                  className="w-full h-full border border-green-600 bg-white dark:bg-zinc-900 text-[#2e7d32] dark:text-emerald-400 text-[10px] sm:text-xs font-black hover:bg-green-50 dark:hover:bg-zinc-800 rounded shadow-md hover:scale-[1.03] active:scale-95 transition-all duration-200 flex items-center justify-center gap-0.5 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
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
                <button
                  onClick={handleDecrement}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all cursor-pointer"
                  aria-label="Decrease quantity"
                >
                  <Minus className="h-2.5 w-2.5 stroke-[3]" />
                </button>
                <span className="w-5 sm:w-6 shrink-0 flex items-center justify-center text-[10px] sm:text-xs font-black select-none h-full bg-[#2e7d32] border-x border-white/20">
                  {quantity}
                </span>
                <button
                  onClick={handleIncrement}
                  disabled={quantity >= resolvedStock || quantity >= 10 || !cafeOpen}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all disabled:opacity-50 cursor-pointer"
                  aria-label="Increase quantity"
                >
                  <Plus className="h-2.5 w-2.5 stroke-[3]" />
                </button>
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
  const [activeCategory, setActiveCategory] = useState<string>('')
  const [showFloatingMenuBtn, setShowFloatingMenuBtn] = useState<boolean>(false)
  const [isFloatingMenuOpen, setIsFloatingMenuOpen] = useState<boolean>(false)
  const [navbarHeight, setNavbarHeight] = useState<number>(96)

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

  // Swiggy categories catalog list (combining grouped and dynamic ones)
  const menuCategories = useMemo(() => {
    const list = []
    categorySections.sections.forEach(sec => {
      list.push({
        tag: sec.tag,
        title: sec.title,
        emoji: sec.emoji,
        count: sec.products.length
      })
    })
    if (categorySections.moreItems.length > 0) {
      list.push({
        tag: 'more',
        title: 'More Specials',
        emoji: '🍽️',
        count: categorySections.moreItems.length
      })
    }
    return list
  }, [categorySections])

  // Scroll tracker logic
  useEffect(() => {
    const handleScroll = () => {
      const navbarEl = document.querySelector('nav')
      const currentNavbarHeight = navbarEl ? navbarEl.getBoundingClientRect().height : 96
      
      setNavbarHeight(prev => {
        if (Math.abs(prev - currentNavbarHeight) > 1) {
          return currentNavbarHeight
        }
        return prev
      })

      // Get sticky categories bar height if on mobile
      const stickyBarEl = document.getElementById('mobile-category-sticky-bar')
      const stickyBarHeight = stickyBarEl ? stickyBarEl.getBoundingClientRect().height : 44

      const headerOffset = currentNavbarHeight + (window.innerWidth < 768 ? stickyBarHeight : 0) + 16
      const scrollPosition = window.scrollY + headerOffset
      
      // Determine if floating menu button should appear (after scrolling past hero banner)
      setShowFloatingMenuBtn(window.scrollY > 250)

      let currentActive = ''

      // Dynamic tags sections
      categorySections.sections.forEach(sec => {
        const el = document.getElementById(`category-section-${sec.tag}`)
        if (el && scrollPosition >= el.offsetTop) {
          currentActive = sec.tag
        }
      })

      // More specials section
      const moreEl = document.getElementById('category-section-more')
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
  }, [categorySections, menuCategories])

  // Auto-scroll horizontal category bar to center active tag button (debounced by 150ms to prevent jittering when scrolling fast)
  useEffect(() => {
    if (!activeCategory) return

    const timeoutId = setTimeout(() => {
      const activeTabEl = document.getElementById(`category-tab-${activeCategory}`)
      const containerEl = document.getElementById('mobile-category-sticky-bar')
      if (activeTabEl && containerEl) {
        const containerWidth = containerEl.clientWidth
        const tabOffsetLeft = activeTabEl.offsetLeft
        const tabWidth = activeTabEl.clientWidth
        const targetScrollLeft = tabOffsetLeft - (containerWidth / 2) + (tabWidth / 2)
        
        containerEl.scrollTo({
          left: targetScrollLeft,
          behavior: 'smooth'
        })
      }
    }, 150)

    return () => clearTimeout(timeoutId)
  }, [activeCategory])

  // Smooth scroll handler
  const scrollToCategory = (tag: string) => {
    const el = document.getElementById(`category-section-${tag}`)
    if (el) {
      const navbarEl = document.querySelector('nav')
      const currentNavbarHeight = navbarEl ? navbarEl.getBoundingClientRect().height : 96
      
      const isMobile = window.innerWidth < 768
      let stickyBarHeight = 0
      if (isMobile) {
        const stickyBarEl = document.getElementById('mobile-category-sticky-bar')
        stickyBarHeight = stickyBarEl ? stickyBarEl.getBoundingClientRect().height : 44
      }

      const headerOffset = currentNavbarHeight + stickyBarHeight + 8
      const elementPosition = el.offsetTop
      const offsetPosition = elementPosition - headerOffset

      window.scrollTo({
        top: offsetPosition >= 0 ? offsetPosition : 0,
        behavior: 'smooth'
      })
      
      setActiveCategory(tag)
      setIsFloatingMenuOpen(false)
    }
  }

  return (
    <div className="container mx-auto px-4 py-6 max-w-7xl space-y-6 md:space-y-8 relative">
      {/* Breadcrumb */}
      <nav className="flex items-center gap-1.5 text-xs md:text-sm font-semibold">
        <Link href="/" className="text-text-muted hover:text-primary transition-colors">Home</Link>
        <ChevronRight size={14} className="text-text-muted" />
        <span className="font-bold text-rose-600">FastKirana Cafe ☕</span>
      </nav>

      {/* Hero Cafe Banner (Consistent with landing page design) */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-[#2a1711] via-[#1d0e0a] to-[#120805] dark:from-[#1b0d09] dark:via-[#0e0604] dark:to-black text-white p-4 md:p-8 flex items-center justify-between min-h-[130px] md:min-h-[165px] shadow-[0_8px_30px_rgba(35,21,16,0.15)] border border-[#3e241b] dark:border-[#20110c]">
        {/* Background Decorative Glow */}
        <div className="absolute -top-12 -right-12 w-48 h-48 rounded-full bg-amber-500/15 dark:bg-amber-500/10 blur-[50px] pointer-events-none animate-pulse-gentle" />
        
        {/* Left Content */}
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

        {/* Right Content: Food Image */}
        <div className="absolute right-4 md:right-8 bottom-0 top-0 w-[35%] md:w-[40%] flex items-center justify-end select-none pointer-events-none">
          <img
            src="/cafe_banner.png"
            alt="South Indian and Chinese Cafe Specials"
            className="object-contain max-h-[110px] md:max-h-[145px] lg:max-h-[165px] w-auto h-auto drop-shadow-[0_12px_24px_rgba(0,0,0,0.4)] animate-float"
          />
        </div>
      </div>

      {/* -------------------- STICKY CATEGORY NAVIGATION TAB BAR (Mobile Only) -------------------- */}
      <div 
        id="mobile-category-sticky-bar"
        style={{ top: `${navbarHeight}px` }}
        className="sticky md:hidden z-30 bg-background/95 backdrop-blur-md border-b border-border/80 py-2.5 -mx-4 px-4 flex gap-2.5 overflow-x-auto scrollbar-none shadow-sm select-none transition-all duration-300"
      >
        {menuCategories.map((cat) => {
          const isActive = activeCategory === cat.tag
          return (
            <button
              key={cat.tag}
              id={`category-tab-${cat.tag}`}
              onClick={() => scrollToCategory(cat.tag)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-black shrink-0 whitespace-nowrap transition-all duration-200 cursor-pointer flex items-center gap-1.5 ${
                isActive
                  ? 'bg-rose-600 text-white shadow-md shadow-rose-500/10 border border-rose-500'
                  : 'bg-muted/30 text-text-secondary border border-border/60 hover:bg-muted/60'
              }`}
            >
              <span>{cat.emoji}</span>
              <span>{cat.title}</span>
              <span className={`text-[9px] px-1 py-0.5 rounded-full ${
                isActive ? 'bg-white/20 text-white' : 'bg-muted-foreground/10 text-text-secondary'
              }`}>
                {cat.count}
              </span>
            </button>
          )
        })}
      </div>

      {/* Split layout: Sidebar categories for desktop, main content on right */}
      <div className="flex gap-8 items-start">
        {/* Desktop Vertical Sidebar (Swiggy Style) */}
        <aside 
          style={{ 
            top: `${navbarHeight + 16}px`, 
            maxHeight: `calc(100vh - ${navbarHeight + 40}px)` 
          }}
          className="hidden md:block w-64 shrink-0 sticky overflow-y-auto pr-2 border-r border-border/40 space-y-1 scrollbar-none py-1"
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
                className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl transition-all duration-200 cursor-pointer text-left ${
                  isActive
                    ? 'bg-rose-50 dark:bg-rose-950/20 text-rose-600 dark:text-rose-400 font-extrabold shadow-sm'
                    : 'text-text-secondary hover:bg-muted/40 hover:text-text-primary'
                }`}
              >
                <div className="flex items-center gap-2.5 min-w-0">
                  <span className="text-base shrink-0">{cat.emoji}</span>
                  <span className="text-xs truncate">{cat.title}</span>
                </div>
                <span className={`text-[9px] font-black px-1.5 py-0.5 rounded-full shrink-0 ${
                  isActive
                    ? 'bg-rose-500 text-white'
                    : 'bg-muted-foreground/10 text-text-secondary'
                }`}>
                  {cat.count}
                </span>
              </button>
            )
          })}
        </aside>

        {/* Categories Main Content Area */}
        <div className="flex-1 space-y-10 md:space-y-12">
          {categorySections.sections.map((section) => (
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

          {/* Catch-all More from Cafe */}
          {categorySections.moreItems.length > 0 && (
            <section id="category-section-more" className="space-y-4 pt-2 scroll-mt-24">
              <div className="flex items-center gap-2 px-1">
                <span className="text-xl">🍽️</span>
                <div>
                  <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">More Specials</h2>
                  <p className="text-xs text-text-secondary">Additional cafe items and specials</p>
                </div>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 md:gap-4">
                {categorySections.moreItems.map((p: any) => (
                  <ProductCard key={p.id} product={p} />
                ))}
              </div>
            </section>
          )}
        </div>
      </div>

      {/* -------------------- FLOATING MENU BUTTON (Swiggy Style) -------------------- */}
      <AnimatePresence>
        {showFloatingMenuBtn && (
          <motion.div
            initial={{ opacity: 0, scale: 0.8, y: 30 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.8, y: 30 }}
            transition={{ duration: 0.2 }}
            className={`fixed left-1/2 -translate-x-1/2 z-40 md:hidden ${
              hasCartItems ? 'bottom-[124px]' : 'bottom-20'
            }`}
          >
            <button
              onClick={() => setIsFloatingMenuOpen(true)}
              className="bg-zinc-900 dark:bg-zinc-800 border border-white/10 text-white font-extrabold text-xs px-4 py-3 rounded-full shadow-2xl flex items-center gap-2 hover:scale-105 active:scale-95 transition-all select-none cursor-pointer"
            >
              <MenuIcon className="h-4 w-4" />
              <span>MENU</span>
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* FLOATING QUICK MENU DRAWER */}
      <AnimatePresence>
        {isFloatingMenuOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs cursor-pointer"
              onClick={() => setIsFloatingMenuOpen(false)}
            />

            {/* Menu Popup */}
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 220 }}
              className="fixed bottom-0 left-0 right-0 z-50 max-h-[60vh] bg-background border-t border-border rounded-t-3xl shadow-2xl overflow-hidden flex flex-col mx-auto max-w-sm"
            >
              {/* Drawer indicator */}
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

              {/* List of categories */}
              <div className="flex-1 overflow-y-auto px-4 py-3 space-y-1">
                {menuCategories.map((cat) => {
                  const isActive = activeCategory === cat.tag
                  return (
                    <button
                      key={cat.tag}
                      onClick={() => scrollToCategory(cat.tag)}
                      className={`w-full flex items-center justify-between p-3 rounded-xl transition-all cursor-pointer ${
                        isActive
                          ? 'bg-rose-500/10 text-rose-500 font-extrabold border border-rose-500/20'
                          : 'hover:bg-muted/40 text-text-primary border border-transparent'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-lg">{cat.emoji}</span>
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
