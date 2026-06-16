'use client'

import { useState, useMemo, useEffect } from 'react'
import Link from 'next/link'
import { ProductCard } from '@/components/product/product-card'
import { Category, Product } from '@/types'
import { cn } from '@/lib/utils'
import { ShoppingBag, Search, X, ChevronRight } from 'lucide-react'
import { useSearchParams } from 'next/navigation'
import { motion } from 'framer-motion'

interface Subcategory {
  id: string
  name: string
  emoji: string
  filterFn: (p: Product) => boolean
}

const getSubcategories = (categorySlug: string, products: Product[]): Subcategory[] => {
  const list: Subcategory[] = [{ id: 'all', name: 'All', emoji: '🥬', filterFn: () => true }]

  if (categorySlug === 'fruits-vegetables') {
    list.push(
      {
        id: 'vegetables',
        name: 'Fresh Vegetables',
        emoji: '🥦',
        filterFn: (p) => {
          const name = p.name.toLowerCase()
          const tags = p.tags?.map(t => t.toLowerCase()) || []
          return tags.includes('cooking') || tags.includes('essential') || tags.includes('salad') || tags.includes('spicy') ||
            /potato|onion|tomato|chilli|coriander|garlic|ginger|lemon|cucumber|cabbage|carrot|cauliflower|bhindi|okra|gourd|spinach|palak/.test(name)
        }
      },
      {
        id: 'fruits',
        name: 'Fresh Fruits',
        emoji: '🍎',
        filterFn: (p) => {
          const name = p.name.toLowerCase()
          const tags = p.tags?.map(t => t.toLowerCase()) || []
          return (tags.includes('fresh') && !/potato|onion|tomato|chilli|coriander|garlic|ginger|lemon|cucumber|cabbage|carrot|cauliflower|bhindi|okra|gourd|spinach|palak/.test(name)) || tags.includes('premium') ||
            /banana|apple|mango|litchi|orange|grapes|pomegranate|watermelon|papaya|kiwi|pineapple/.test(name)
        }
      },
      {
        id: 'herbs-seasoning',
        name: 'Leafy & Herbs',
        emoji: '🌿',
        filterFn: (p) => {
          const name = p.name.toLowerCase()
          return /coriander|mint|pudina|ginger|garlic|lemon|curry|leaf|chilli/.test(name)
        }
      },
      {
        id: 'premium',
        name: 'Exotics & Premium',
        emoji: '👑',
        filterFn: (p) => p.tags?.map(t => t.toLowerCase()).includes('premium') || false
      }
    )
  } else if (categorySlug === 'dairy-breakfast') {
    list.push(
      {
        id: 'milk',
        name: 'Milk & Curd',
        emoji: '🥛',
        filterFn: (p) => /milk|curd|taaza/i.test(p.name)
      },
      {
        id: 'cheese-butter',
        name: 'Cheese & Butter',
        emoji: '🧀',
        filterFn: (p) => /cheese|butter|paneer/i.test(p.name)
      },
      {
        id: 'breakfast',
        name: 'Breakfast',
        emoji: '🥣',
        filterFn: (p) => {
          const tags = p.tags?.map(t => t.toLowerCase()) || []
          return tags.includes('breakfast') || tags.includes('cereal') || /bread|egg|flakes/i.test(p.name)
        }
      }
    )
  } else if (categorySlug === 'snacks-munchies') {
    list.push(
      {
        id: 'chips',
        name: 'Chips & Crisps',
        emoji: '🍟',
        filterFn: (p) => /chips|pringles|lays|kurkure|puff/i.test(p.name)
      },
      {
        id: 'biscuits',
        name: 'Biscuits',
        emoji: '🍪',
        filterFn: (p) => /biscuit|cookie|oreo|fantasy/i.test(p.name)
      },
      {
        id: 'chocolates',
        name: 'Chocolates',
        emoji: '🍫',
        filterFn: (p) => /chocolate|dairy milk|5 star|kitkat/i.test(p.name)
      },
      {
        id: 'namkeen',
        name: 'Namkeen',
        emoji: '🥨',
        filterFn: (p) => /bhujia|namkeen|mixture/i.test(p.name)
      }
    )
  } else if (categorySlug === 'beverages') {
    list.push(
      {
        id: 'cold-drinks',
        name: 'Soft Drinks',
        emoji: '🥤',
        filterFn: (p) => /coca-cola|sprite|thumbs up|coke|soda|fanta|limca/i.test(p.name)
      },
      {
        id: 'juices',
        name: 'Juices & Drinks',
        emoji: '🧃',
        filterFn: (p) => /juice|frooti|paper boat|real/i.test(p.name)
      },
      {
        id: 'tea-coffee',
        name: 'Tea & Coffee',
        emoji: '☕',
        filterFn: (p) => /tea|coffee|nescafe|tata/i.test(p.name)
      }
    )
  } else if (categorySlug === 'personal-care') {
    list.push(
      {
        id: 'bath',
        name: 'Bath & Soap',
        emoji: '🧼',
        filterFn: (p) => /soap|dove|dettol|handwash|shower/i.test(p.name)
      },
      {
        id: 'hair',
        name: 'Hair Care',
        emoji: '💇',
        filterFn: (p) => /shampoo|oil|hair|parachute/i.test(p.name)
      },
      {
        id: 'skin',
        name: 'Skin Care',
        emoji: '🧴',
        filterFn: (p) => /lotion|face wash|cream|nivea|vaseline|himalaya/i.test(p.name)
      }
    )
  } else {
    const uniqueTags = Array.from(
      new Set(products.flatMap((p) => p.tags || []))
    ).filter((t) => !['cafe', 'popular', 'essential', 'daily'].includes(t.toLowerCase()))

    uniqueTags.slice(0, 4).forEach((tag) => {
      const name = tag.charAt(0).toUpperCase() + tag.slice(1)
      list.push({
        id: tag.toLowerCase(),
        name,
        emoji: '📦',
        filterFn: (p) => p.tags?.map(t => t.toLowerCase()).includes(tag.toLowerCase()) || false
      })
    })
  }

  return list
}

interface CategoryPageClientProps {
  categories: Category[]
  initialProducts: Product[]
  activeCategory: Category
  countsMap: Record<string, number>
}

export function CategoryPageClient({
  categories,
  initialProducts,
  activeCategory,
  countsMap,
}: CategoryPageClientProps) {
  const searchParams = useSearchParams()
  const subcatParam = searchParams.get('subcat')
  const [searchQuery, setSearchQuery] = useState('')
  const [sort, setSort] = useState<string>('popularity')
  const [vegFilter, setVegFilter] = useState<'all' | 'veg' | 'nonveg'>('all')
  const [showPriceFilter, setShowPriceFilter] = useState(false)
  const [activeSubcategoryId, setActiveSubcategoryId] = useState('all')

  const maxPriceOfCategory = useMemo(() => {
    if (initialProducts.length === 0) return 1000
    return Math.max(...initialProducts.map((p) => p.price))
  }, [initialProducts])

  const [maxPrice, setMaxPrice] = useState<number>(1000)

  // Reset maxPrice & subcategory when switching categories
  useEffect(() => {
    setMaxPrice(maxPriceOfCategory)
    if (subcatParam) {
      setActiveSubcategoryId(subcatParam)
    } else {
      setActiveSubcategoryId('all')
    }
  }, [maxPriceOfCategory, activeCategory.slug, subcatParam])

  // Center active category tab on mobile horizontal scroll bar on mount
  useEffect(() => {
    const activeTabEl = document.getElementById(`category-tab-${activeCategory.slug}`)
    const containerEl = document.getElementById('mobile-category-scrollbar')
    if (activeTabEl && containerEl) {
      const timer = setTimeout(() => {
        const containerWidth = containerEl.clientWidth
        const tabOffsetLeft = activeTabEl.offsetLeft
        const tabWidth = activeTabEl.clientWidth
        const targetScrollLeft = tabOffsetLeft - (containerWidth / 2) + (tabWidth / 2)
        
        containerEl.scrollTo({
          left: targetScrollLeft,
          behavior: 'auto'
        })
      }, 50)
      return () => clearTimeout(timer)
    }
  }, [activeCategory.slug])

  const sortOptions = [
    { label: 'Popularity', value: 'popularity' },
    { label: 'Price: Low to High', value: 'price-asc' },
    { label: 'Price: High to Low', value: 'price-desc' },
    { label: 'Big Discounts', value: 'discount-desc' },
  ]

  const subcategories = useMemo(() => {
    return getSubcategories(activeCategory.slug, initialProducts)
  }, [activeCategory.slug, initialProducts])

  // Filter and sort products in memory
  const processedProducts = useMemo(() => {
    let result = [...initialProducts]

    // 0. Filter by subcategory
    const activeSub = subcategories.find((s) => s.id === activeSubcategoryId)
    if (activeSub) {
      result = result.filter(activeSub.filterFn)
    }

    // 1. Filter by search query
    if (searchQuery.trim()) {
      const words = searchQuery.toLowerCase().trim().split(/\s+/).filter(Boolean)
      result = result.filter((p) =>
        words.every((word) =>
          p.name.toLowerCase().includes(word) ||
          (p.description && p.description.toLowerCase().includes(word)) ||
          p.tags.some((t) => t.toLowerCase().includes(word))
        )
      )
    }

    // 2. Filter by Veg/Non-Veg
    if (vegFilter === 'veg') {
      result = result.filter((p) => {
        const tags = p.tags?.map((t) => t.toLowerCase()) || []
        const isNonVeg = tags.includes('nonveg') || tags.includes('non-veg') || tags.includes('chicken') || tags.includes('egg') || tags.includes('mutton') || tags.includes('meat')
        return !isNonVeg
      })
    } else if (vegFilter === 'nonveg') {
      result = result.filter((p) => {
        const tags = p.tags?.map((t) => t.toLowerCase()) || []
        return tags.includes('nonveg') || tags.includes('non-veg') || tags.includes('chicken') || tags.includes('egg') || tags.includes('mutton') || tags.includes('meat')
      })
    }

    // 3. Filter by Price Limit
    result = result.filter((p) => p.price <= maxPrice)

    // 4. Sort results
    if (sort === 'price-asc') {
      result.sort((a, b) => a.price - b.price)
    } else if (sort === 'price-desc') {
      result.sort((a, b) => b.price - a.price)
    } else if (sort === 'discount-desc') {
      result.sort((a, b) => b.discount - a.discount)
    }

    return result
  }, [initialProducts, searchQuery, vegFilter, maxPrice, sort, activeSubcategoryId, subcategories])

  const categoryBanners: Record<string, { gradient: string; title: string; subtitle: string; emoji: string }> = {
    'fruits-vegetables': {
      gradient: 'from-[#EAFDF4] via-white to-[#F0FDF4] dark:from-emerald-950/15 dark:to-zinc-950 border-emerald-100/10 dark:border-emerald-950/10',
      title: 'FARM DIRECT',
      subtitle: '100% Farm-Fresh Organic',
      emoji: '🥬',
    },
    'dairy-breakfast': {
      gradient: 'from-[#EEF2FF] via-white to-[#EFF6FF] dark:from-blue-950/15 dark:to-zinc-950 border-blue-100/10 dark:border-blue-950/10',
      title: 'FRESH DAILY',
      subtitle: 'Chilled Dairy & Bread Essentials',
      emoji: '🥛',
    },
    'snacks-munchies': {
      gradient: 'from-[#FFF7ED] via-white to-[#FFFBEB] dark:from-orange-950/15 dark:to-zinc-950 border-orange-100/10 dark:border-orange-950/10',
      title: 'SNACK TIME',
      subtitle: 'Crunchy & Sweet Treats',
      emoji: '🍿',
    },
    'beverages': {
      gradient: 'from-[#FAF5FF] via-white to-[#FDF2F8] dark:from-purple-950/15 dark:to-zinc-950 border-purple-100/10 dark:border-purple-950/10',
      title: 'STAY HYDRATED',
      subtitle: 'Cool Drinks & Juices',
      emoji: '🥤',
    },
  }

  const activeBanner = categoryBanners[activeCategory.slug] || {
    gradient: 'from-[#fafafa] via-white to-[#f4f4f5] dark:from-zinc-900 dark:via-zinc-900/80 dark:to-zinc-950 border-border/20 dark:border-zinc-800/10',
    title: activeCategory.name.toUpperCase(),
    subtitle: 'Fresh Deals in Ghatampur',
    emoji: '🛒',
  }

  const activeSubcategory = subcategories.find((s) => s.id === activeSubcategoryId) || subcategories[0]

  return (
    <div className="container mx-auto px-2 min-h-[calc(100vh-140px)] py-4 max-w-7xl">
      {/* -------------------- DESKTOP LAYOUT -------------------- */}
      <div className="hidden md:flex flex-col gap-6">
        {/* Desktop Breadcrumbs */}
        <div className="flex items-center gap-1.5 text-xs font-semibold text-text-muted">
          <Link href="/" className="hover:text-primary transition-colors">Home</Link>
          <ChevronRight size={12} className="text-text-muted" />
          <span className="font-extrabold text-primary">{activeCategory.name}</span>
        </div>

        <div className="flex gap-6">
          {/* Desktop Left Sidebar: Categories Navigation */}
          <aside className="w-64 flex-shrink-0 border border-border bg-card p-4 rounded-2xl h-fit sticky top-[96px] shadow-sm">
            <h3 className="font-bold text-text-primary text-base mb-4 px-2">Categories</h3>
            <div className="space-y-1.5">
              {categories.map((cat) => {
                const isActive = cat.slug === activeCategory.slug
                return (
                  <Link
                    key={cat.id}
                    href={`/category/${cat.slug}`}
                    className={cn(
                      'flex items-center gap-3 w-full px-3 py-2 text-sm font-semibold rounded-xl transition-all duration-200 group',
                      isActive
                        ? 'bg-primary text-primary-foreground shadow-sm scale-[1.02]'
                        : 'text-text-secondary hover:bg-muted hover:text-text-primary'
                    )}
                  >
                    <span className="h-5 w-5 flex items-center justify-center shrink-0 overflow-hidden" role="img" aria-label={cat.name}>
                      {cat.imageUrl && (cat.imageUrl.startsWith('data:image/') || cat.imageUrl.startsWith('/') || cat.imageUrl.startsWith('http')) ? (
                        <img src={cat.imageUrl} alt={cat.name} className="h-full w-full object-cover rounded" />
                      ) : (
                        <span className="text-base leading-none">{cat.imageUrl || '🛒'}</span>
                      )}
                    </span>
                    <span className="truncate">{cat.name}</span>
                    <span
                      className={cn(
                        'ml-auto text-[10px] font-extrabold px-1.5 py-0.5 rounded-full border transition-colors shrink-0',
                        isActive
                          ? 'bg-primary-foreground/20 text-primary-foreground border-primary-foreground/10'
                          : 'bg-muted text-text-secondary border-border group-hover:bg-background group-hover:text-text-primary'
                      )}
                    >
                      {countsMap[cat.id] || 0}
                    </span>
                  </Link>
                )
              })}
            </div>
          </aside>

          {/* Desktop Right Section: Header and Product Grid */}
          <main className="flex-grow space-y-6">
            {/* Category Header */}
            <div className="flex items-center justify-between border-b border-border/60 pb-4">
              <div className="flex items-center gap-3">
                <span className="h-10 w-10 flex items-center justify-center shrink-0 overflow-hidden" role="img" aria-label={activeCategory.name}>
                  {activeCategory.imageUrl && (activeCategory.imageUrl.startsWith('data:image/') || activeCategory.imageUrl.startsWith('/') || activeCategory.imageUrl.startsWith('http')) ? (
                    <img src={activeCategory.imageUrl} alt={activeCategory.name} className="h-full w-full object-cover rounded-lg" />
                  ) : (
                    <span className="text-3xl leading-none">{activeCategory.imageUrl || '🛒'}</span>
                  )}
                </span>
                <div>
                  <h1 className="text-lg md:text-2xl font-extrabold text-text-primary tracking-tight">
                    {activeCategory.name}
                  </h1>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Showing {processedProducts.length} of {initialProducts.length} products
                  </p>
                </div>
              </div>

              {/* Sorting Actions */}
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-text-secondary">Sort By:</span>
                <div className="flex gap-1 bg-muted p-1 rounded-xl">
                  {sortOptions.map((opt) => {
                    const isActive = sort === opt.value
                    return (
                      <button
                        key={opt.label}
                        type="button"
                        onClick={() => setSort(opt.value)}
                        className={cn(
                          'transparent px-3 py-1.5 text-xs font-bold rounded-lg transition-colors whitespace-nowrap cursor-pointer border-0 outline-none',
                          isActive
                            ? 'bg-card text-text-primary shadow-sm'
                            : 'text-text-secondary hover:text-text-primary'
                        )}
                      >
                        {opt.label}
                      </button>
                    )
                  })}
                </div>
              </div>
            </div>

            {/* Search Bar and Dynamic Filters */}
            <div className="flex gap-3 items-center">
              <div className="relative flex-1 max-w-md bg-card rounded-xl border border-border shadow-sm overflow-hidden group">
                <Search className="absolute left-3.5 top-3.5 h-4 w-4 text-text-muted" />
                <input
                  type="text"
                  placeholder={`Search in ${activeCategory.name}...`}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-transparent border-0 pl-10 pr-10 py-3 text-xs focus:outline-none focus:ring-0 font-semibold text-text-primary"
                />
                {searchQuery && (
                  <button
                    type="button"
                    onClick={() => setSearchQuery('')}
                    className="absolute right-3 top-3 p-0.5 hover:bg-muted text-text-secondary rounded-full"
                  >
                    <X className="h-3.5 w-3.5" />
                  </button>
                )}
              </div>

              <button
                type="button"
                onClick={() => setShowPriceFilter(!showPriceFilter)}
                className={cn(
                  'px-3.5 py-2 rounded-full border text-xs font-black flex items-center gap-1.5 transition-all select-none cursor-pointer',
                  maxPrice < maxPriceOfCategory
                    ? 'bg-primary/10 border-primary/30 text-primary font-extrabold'
                    : 'bg-card border-border hover:bg-muted text-text-secondary'
                )}
              >
                <span>Under ₹{maxPrice}</span>
                <span className={cn('text-[9px] transition-transform duration-200', showPriceFilter ? 'rotate-180' : '')}>▼</span>
              </button>
            </div>

            {showPriceFilter && (
              <div className="bg-card border border-border/60 p-4 rounded-2xl shadow-sm space-y-3 max-w-xs text-left animate-slide-down">
                <div className="flex justify-between text-[10px] font-black text-text-muted uppercase tracking-wider">
                  <span>Min: ₹0</span>
                  <span>Max: ₹{maxPriceOfCategory}</span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={maxPriceOfCategory}
                  value={maxPrice}
                  onChange={(e) => setMaxPrice(Number(e.target.value))}
                  className="w-full accent-primary h-1 bg-muted rounded-lg appearance-none cursor-pointer"
                />
              </div>
            )}

            {processedProducts.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-20 border border-dashed border-border bg-card rounded-2xl text-center p-6 shadow-sm">
                <ShoppingBag className="h-8 w-8 text-muted-foreground mb-4 animate-pulse-gentle" />
                <h2 className="text-base font-bold text-text-primary">No products found</h2>
              </div>
            ) : (
              <div className="grid grid-cols-3 lg:grid-cols-4 gap-4">
                {processedProducts.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            )}
          </main>
        </div>
      </div>

      {/* -------------------- MOBILE LAYOUT (SPLIT SIDEBAR VIEW) -------------------- */}
      <div className="md:hidden flex flex-col -mx-2 min-[375px]:-mx-4 -mt-[96px] pt-[28px] min-h-[calc(100vh-64px)] bg-white dark:bg-zinc-950">
        {/* Mobile top category scrollbar (circular icons, like Zepto) */}
        <div 
          id="mobile-category-scrollbar"
          className="flex gap-4 overflow-x-auto pb-3 pt-3 scrollbar-none px-4 select-none w-full justify-start scroll-smooth snap-x snap-mandatory border-b border-zinc-100 dark:border-zinc-900 bg-white dark:bg-zinc-950"
        >
          {categories.map((cat) => {
            const isActive = cat.slug === activeCategory.slug
            return (
              <Link
                key={cat.id}
                id={`category-tab-${cat.slug}`}
                href={`/category/${cat.slug}`}
                className="group flex flex-col items-center gap-1 cursor-pointer shrink-0 snap-start outline-none select-none active:scale-95 transition-transform duration-300"
              >
                {/* Circular image container */}
                <div
                  className={cn(
                    "w-12 h-12 rounded-full overflow-hidden flex items-center justify-center transition-all duration-300 border relative z-10",
                    isActive
                      ? "border-rose-600 dark:border-rose-500 bg-rose-50/30 dark:bg-rose-950/10 scale-105 shadow-xs"
                      : "border-zinc-200/60 dark:border-zinc-800/50 bg-zinc-50/30 dark:bg-zinc-900/20"
                  )}
                >
                  {cat.imageUrl && (cat.imageUrl.startsWith('/') || cat.imageUrl.startsWith('http') || cat.imageUrl.startsWith('data:image/')) ? (
                    <img src={cat.imageUrl} alt={cat.name} className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105" />
                  ) : (
                    <span className="text-xl leading-none">{cat.imageUrl || '🛒'}</span>
                  )}
                </div>
                <span className={cn(
                  "text-[10px] tracking-tight text-center leading-tight line-clamp-2 w-[76px] transition-colors",
                  isActive ? "text-rose-600 dark:text-rose-400 font-bold" : "text-zinc-500 dark:text-zinc-400 font-medium"
                )}>
                  {cat.name}
                </span>
              </Link>
            )
          })}
        </div>

        {/* Mobile Breadcrumbs */}
        <div className="flex items-center gap-1.5 text-[9px] font-black text-text-muted uppercase tracking-widest mt-2 mb-1.5 px-4 select-none">
          <Link href="/" className="hover:text-primary transition-colors">Home</Link>
          <ChevronRight size={10} className="text-text-muted" />
          <Link href={`/category/${activeCategory.slug}`} className="hover:text-primary transition-colors truncate max-w-[80px]">{activeCategory.name}</Link>
          <ChevronRight size={10} className="text-text-muted" />
          <span className="font-extrabold text-primary truncate max-w-[80px]">{activeSubcategory.name}</span>
        </div>

        {/* Main Split Area */}
        <div className="flex flex-1 border-t border-zinc-100 dark:border-zinc-900">
          {/* Mobile Left Sidebar: Redesigned into Sleek Rectangular Vertical Tabs */}
          <aside className="w-[92px] shrink-0 border-r border-zinc-150 dark:border-zinc-900 bg-zinc-50/70 dark:bg-zinc-950/40 py-2 space-y-1.5 overflow-y-auto max-h-[calc(100vh-140px)] scrollbar-none sticky top-[64px] self-start backdrop-blur-md">
            {subcategories.map((subcat) => {
              const isActive = subcat.id === activeSubcategoryId
              // Format subcategory name to Title Case (e.g. JUICES & DRINKS -> Juices & Drinks)
              const formattedName = subcat.name
                .toLowerCase()
                .split(' ')
                .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
                .join(' ')

              return (
                <button
                  key={subcat.id}
                  onClick={() => setActiveSubcategoryId(subcat.id)}
                  className={cn(
                    'w-full flex flex-col items-center text-center gap-1 py-3 px-1.5 relative transition-all cursor-pointer select-none z-10 outline-none border-0 bg-transparent',
                    isActive ? 'text-rose-600 dark:text-rose-400' : 'text-zinc-500 dark:text-zinc-400'
                  )}
                >
                  {/* Sliding Left indicator bar */}
                  {isActive && (
                    <motion.div
                      layoutId="activeSubcategoryMobileBar"
                      className="absolute left-0 top-2 bottom-2 w-[3.5px] bg-[#FF2E55] rounded-r-full"
                      transition={{ type: 'spring', stiffness: 350, damping: 25 }}
                    />
                  )}

                  {/* Rectangular Card Container */}
                  <div
                    className={cn(
                      'w-14 h-14 rounded-2xl flex items-center justify-center transition-all duration-300 border relative z-10 shadow-[0_2px_8px_rgba(0,0,0,0.01)]',
                      isActive
                        ? 'border-zinc-200 dark:border-zinc-800 scale-[1.05] bg-white dark:bg-zinc-900 shadow-sm'
                        : 'bg-white/80 dark:bg-zinc-900/60 border-zinc-100 dark:border-zinc-900/60'
                    )}
                  >
                    {/* Sliding active inner background */}
                    {isActive && (
                      <motion.div
                        layoutId="activeSubcategoryMobileCircle"
                        className="absolute inset-0 rounded-2xl bg-rose-50/10 dark:bg-rose-950/5 -z-10"
                        transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                      />
                    )}
                    <span className="text-2xl filter drop-shadow-sm select-none leading-none relative z-20">{subcat.emoji}</span>
                  </div>

                  {/* Subcategory Name */}
                  <span className={cn(
                    "text-[9.5px] leading-tight px-0.5 tracking-tight select-none mt-1.5 relative z-20 text-center line-clamp-2 max-w-[80px]",
                    isActive ? "font-extrabold text-rose-600 dark:text-rose-450" : "font-semibold text-zinc-500 dark:text-zinc-400"
                  )}>
                    {formattedName}
                  </span>
                </button>
              )
            })}
          </aside>

          {/* Mobile Right Content Panel */}
          <div className="flex-grow min-w-0 bg-background overflow-y-auto max-h-[calc(100vh-140px)] px-2 py-2 space-y-2.5">
            {/* Promo Subcategory Banner (Visual Highlight) */}
            <div className={cn(
              'relative overflow-hidden rounded-xl p-3 flex items-center justify-between border shadow-[0_2px_10px_rgba(0,0,0,0.01)] min-h-[72px] select-none',
              activeBanner.gradient
            )}>
              {/* Decorative Circle Grid */}
              <div className="absolute -top-6 -right-6 w-20 h-20 bg-white/10 dark:bg-white/5 rounded-full blur-xs pointer-events-none" />
              <div className="absolute -bottom-6 -left-6 w-16 h-16 bg-white/10 dark:bg-white/5 rounded-full blur-xs pointer-events-none" />
              
              <div className="relative z-10 max-w-[65%] text-left">
                <span className="inline-block bg-amber-500/10 text-amber-700 dark:bg-amber-500/20 dark:text-amber-400 text-[8px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider mb-0.5">
                  {activeBanner.title}
                </span>
                <h2 className="text-sm font-black text-zinc-900 dark:text-zinc-100 tracking-tight leading-tight mb-0.5 select-none uppercase">
                  {activeSubcategory.name}
                </h2>
                <p className="text-[9.5px] font-extrabold text-zinc-500 dark:text-zinc-400 leading-none">
                  {activeBanner.subtitle}
                </p>
              </div>

              <div className="relative z-10 shrink-0 text-3xl font-bold animate-float pr-1.5 filter drop-shadow-[0_2px_5px_rgba(0,0,0,0.1)] leading-none">
                {activeBanner.emoji}
              </div>
            </div>

            {/* Sorting & Filter Header in Right Panel */}
            <div className="flex flex-col gap-1.5 border-b border-zinc-100 dark:border-zinc-900/50 pb-2.5">
              {/* Small Info Label */}
              <div className="flex justify-between items-center text-[9px] font-black text-text-muted uppercase tracking-widest px-0.5">
                <span>{activeSubcategory.name}</span>
                <span>{processedProducts.length} Products</span>
              </div>

              {/* Search Bar inside Right Panel */}
              <div className="relative bg-zinc-50 dark:bg-zinc-900/40 rounded-xl border border-zinc-200/50 dark:border-zinc-800/40 shadow-xs overflow-hidden group">
                <Search className="absolute left-3 top-2 h-3 w-3 text-text-muted" />
                <input
                  type="text"
                  placeholder={`Search in ${activeSubcategory.name}...`}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-transparent border-0 pl-8.5 pr-8 py-1.5 text-[10.5px] focus:outline-none focus:ring-0 font-bold text-text-primary placeholder:text-text-muted"
                />
                {searchQuery && (
                  <button
                    type="button"
                    onClick={() => setSearchQuery('')}
                    className="absolute right-2.5 top-2 p-0.5 hover:bg-muted text-text-secondary rounded-full"
                  >
                    <X className="h-3 w-3" />
                  </button>
                )}
              </div>

              {/* Quick Sort / Filter row */}
              <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none select-none pt-0.5">
                <button
                  type="button"
                  onClick={() => setShowPriceFilter(!showPriceFilter)}
                  className={cn(
                    'px-3 py-1.5 rounded-full border text-[10px] font-bold flex items-center gap-1 transition-all select-none cursor-pointer shrink-0 uppercase tracking-tight shadow-xs',
                    maxPrice < maxPriceOfCategory
                      ? 'bg-[#FF2E55] border-[#FF2E55] text-white font-extrabold shadow-sm'
                      : 'bg-white dark:bg-zinc-900 border-zinc-200/60 dark:border-zinc-800/40 hover:bg-muted text-zinc-500 dark:text-zinc-400'
                  )}
                >
                  <span>Under ₹{maxPrice}</span>
                  <span className={cn('text-[7.5px] transition-transform duration-200', showPriceFilter ? 'rotate-180' : '')}>▼</span>
                </button>

                {sortOptions.slice(0, 3).map((opt) => {
                  const isActive = sort === opt.value
                  return (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => setSort(opt.value)}
                      className={cn(
                        'px-3 py-1.5 rounded-full border text-[10px] font-bold transition-all select-none cursor-pointer shrink-0 uppercase tracking-tight shadow-xs border-0 outline-none',
                        isActive
                          ? 'bg-[#FF2E55] border-[#FF2E55] text-white font-extrabold shadow-sm'
                          : 'bg-white dark:bg-zinc-900 border-zinc-200/60 dark:border-zinc-800/40 hover:bg-muted text-zinc-500 dark:text-zinc-400'
                      )}
                    >
                      {opt.label.replace('Price: ', '')}
                    </button>
                  )
                })}
              </div>

              {/* Price range inside mobile right panel */}
              {showPriceFilter && (
                <div className="bg-white dark:bg-zinc-900 border border-zinc-150 dark:border-zinc-800/60 p-3.5 rounded-2xl shadow-xs space-y-2 text-left animate-slide-down">
                  <div className="flex justify-between text-[8px] font-black text-text-muted uppercase tracking-wider">
                    <span>Min: ₹0</span>
                    <span>Max: ₹{maxPriceOfCategory}</span>
                  </div>
                  <input
                    type="range"
                    min={0}
                    max={maxPriceOfCategory}
                    value={maxPrice}
                    onChange={(e) => setMaxPrice(Number(e.target.value))}
                    className="w-full accent-rose-600 h-1 bg-muted rounded-lg appearance-none cursor-pointer"
                  />
                  <div className="flex justify-between items-center text-[10px] font-black pt-1 border-t border-zinc-100 dark:border-zinc-800/40">
                    <span className="text-text-muted uppercase tracking-wider text-[8px]">Showing up to:</span>
                    <span className="text-rose-600 dark:text-rose-400">₹{maxPrice}</span>
                  </div>
                </div>
              )}
            </div>

            {/* Mobile Product Grid */}
            {processedProducts.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 border border-dashed border-zinc-200 dark:border-zinc-800 bg-zinc-50/20 dark:bg-zinc-900/5 rounded-2xl text-center p-4 shadow-sm select-none">
                <ShoppingBag className="h-6 w-6 text-muted-foreground/60 mb-2 animate-pulse-gentle" />
                <h2 className="text-xs font-bold text-text-primary uppercase tracking-tight">No products found</h2>
                <p className="text-[10px] text-text-secondary mt-0.5">Check back later or change filters</p>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-2 pb-20">
                {processedProducts.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
