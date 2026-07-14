'use client'

import { useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { ChevronRight, Coffee, ChefHat } from 'lucide-react'
import { cn } from '@/lib/utils'
import { DEFAULT_CAFE_MENU_SECTIONS, DEFAULT_RESTAURANT_MENU_SECTIONS } from '@/lib/constants'
import { motion } from 'framer-motion'
import { useUIStore } from '@/stores/ui-store'
import { ProductCard } from '@/components/product/product-card'

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
    'north-indian': '/cafe_south_indian_category.png',
    'biryani-rice': '/cafe_rice_category.png',
  }
  return mapping[tag] || null
}

const getShortTitle = (tag: string, fullTitle: string) => {
  const customMapping: Record<string, string> = {
    'hot-beverage': 'Brews',
    'hot-bite': 'Quick Bites & Snacks',
    'sandwiches': 'Sandwiches',
    'frankie-rolls': 'Frankie & Rolls',
    'chinese': 'Chinese Cuisine',
    'italian-pasta': 'Pasta & Italian',
    'bombay-bites': 'Bombay',
    'rice-dishes': 'Rice',
    'shakes': 'Shakes',
    'mocktails': 'Mocktails',
    'cold-coffee': 'Coffee',
    'south-indian': 'South Indian Fastfood',
    'bakery': 'Bakery',
    'chilled': 'Cold Drinks',
    'pizza': 'Pizzas & Sides',
    'burgers': 'Gourmet Burgers',
    'garlic-bread': 'Garlic Bread',
    'desserts': 'Desserts & Sweets',
    'north-indian': 'North Indian',
    'biryani-rice': 'Biryani & Rice',
  }
  return customMapping[tag] || fullTitle
}

interface CafeSectionProps {
  showProducts?: boolean
}

export function CafeSection({ showProducts = false }: CafeSectionProps) {
  const settings = useUIStore((s) => s.settings) || {}
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const isCafeActive = cafeOpen && (categoryStatus['cafe'] !== false)

  const [activeCategoryTag, setActiveCategoryTag] = useState<string>('all')
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set())

  const toggleCategoryExpand = (tag: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev)
      if (next.has(tag)) {
        next.delete(tag)
      } else {
        next.add(tag)
      }
      return next
    })
  }
  const [experienceMode, setExperienceMode] = useState<'cafe' | 'restaurant'>('cafe')
  const [categories, setCategories] = useState<any[]>([
    { tag: 'all', title: 'All Menu', emoji: '🍽️', image: '/cafe_all_menu_category.png' },
    { tag: 'hot-beverage', title: 'Brews', emoji: '☕', image: '/cafe_brews_category.png' },
    { tag: 'hot-bite', title: 'Snacks', emoji: '🥟', image: '/cafe_snacks_category.png' },
    { tag: 'sandwiches', title: 'Sandwiches', emoji: '🥪', image: '/cafe_sandwiches_category.png' },
    { tag: 'frankie-rolls', title: 'Rolls', emoji: '🌯', image: '/cafe_rolls_category.png' },
    { tag: 'chinese', title: 'Chinese', emoji: '🥡', image: '/cafe_chinese_category.png' },
    { tag: 'italian-pasta', title: 'Pasta', emoji: '🍝', image: '/cafe_pasta_category.png' },
    { tag: 'bombay-bites', title: 'Bombay Bites', emoji: '🥪', image: '/cafe_bombay_bites_category.png' },
    { tag: 'rice-dishes', title: 'Rice', emoji: '🍚', image: '/cafe_rice_category.png' },
  ])

  const filteredCategories = useMemo(() => {
    return categories
  }, [categories])
  const [cafeProducts, setCafeProducts] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    setIsLoading(true)
    const categoryQuery = (experienceMode as string) === 'restaurant' ? 'restaurant' : 'cafe'
    fetch(`/api/products?category=${categoryQuery}&limit=250`)
      .then(res => res.json())
      .then(productsRes => {
        const dbProducts = productsRes?.products || productsRes || []
        setCafeProducts(dbProducts)
        const customSectionsStr = (experienceMode as string) === 'restaurant'
          ? (settings.restaurant_menu_sections || settings.RESTAURANT_MENU_SECTIONS)
          : (settings.cafe_menu_sections || settings.CAFE_MENU_SECTIONS)
        
        let parsedSections = null
        if (customSectionsStr) {
          try {
            const parsed = JSON.parse(customSectionsStr)
            if (Array.isArray(parsed) && parsed.length > 0) {
              parsedSections = parsed
            }
          } catch (e) {}
        }

        const PREDEFINED_CATEGORIES = parsedSections || ((experienceMode as string) === 'restaurant' ? DEFAULT_RESTAURANT_MENU_SECTIONS : DEFAULT_CAFE_MENU_SECTIONS)

        const sectionsMap = new Map<string, any>()
        PREDEFINED_CATEGORIES.forEach(cat => {
          sectionsMap.set(cat.tag, {
            tag: cat.tag,
            title: getShortTitle(cat.tag, cat.title),
            emoji: cat.emoji || '🍽️',
            image: cat.imageUrl || cat.image || getCafeSectionImage(cat.tag),
            matchTags: cat.matchTags || [],
            productsCount: 0,
            matchedIds: new Set<string>()
          })
        })

        const assignedProductIds = new Set<string>()

        dbProducts.forEach((product: any) => {
          for (const cat of PREDEFINED_CATEGORIES) {
            const hasMatch = product.tags?.some((t: string) => 
              cat.matchTags?.map((mt: string) => mt.toLowerCase()).includes(t.toLowerCase())
            ) || (cat.tag === 'bakery' && ['croissant-butter', 'muffin-chocolate'].includes(product.slug))

            if (hasMatch) {
              const sec = sectionsMap.get(cat.tag)
              if (sec && !sec.matchedIds.has(product.id)) {
                sec.productsCount++
                sec.matchedIds.add(product.id)
                assignedProductIds.add(product.id)
              }
            }
          }
        })

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

        const dynamicTagsMap = new Map<string, number>()
        dbProducts.forEach((product: any) => {
          if (assignedProductIds.has(product.id)) return

          product.tags?.forEach((t: string) => {
            const lowerTag = t.toLowerCase()
            if (excludeTags.has(lowerTag)) return

            dynamicTagsMap.set(lowerTag, (dynamicTagsMap.get(lowerTag) || 0) + 1)
          })
        })

        const dynamicSections: any[] = []
        dynamicTagsMap.forEach((count, tag) => {
          if (count > 0) {
            const title = tag
              .split(/[-_ ]+/)
              .map(word => word.charAt(0).toUpperCase() + word.slice(1))
              .join(' ')

            dynamicSections.push({
              tag,
              title: getShortTitle(tag, title),
              emoji: '✨',
              image: getCafeSectionImage(tag),
              productsCount: count
            })
          }
        })

        const finalCategories: any[] = []
        PREDEFINED_CATEGORIES.forEach(cat => {
          const sec = sectionsMap.get(cat.tag)
          if (sec && sec.productsCount > 0) {
            const matchedProducts = dbProducts.filter((p: any) => sec.matchedIds.has(p.id))
            finalCategories.push({
              tag: sec.tag,
              title: sec.title,
              emoji: sec.emoji,
              image: sec.image,
              products: matchedProducts
            })
          }
        })

        // Only show configured/predefined categories that have products in the database
        setCategories([
          { tag: 'all', title: 'All Menu', emoji: '🍽️', image: '/cafe_all_menu_category.png', products: dbProducts },
          ...finalCategories
        ])
      })
      .catch(() => {})
      .finally(() => {
        setIsLoading(false)
      })
  }, [settings, experienceMode])

  return (
    <section className="space-y-0">
      {/* ✨ Gen-Z Food Banner */}
      <div 
        onClick={() => {
          const target = document.getElementById('cafe-menu-categories-anchor')
          if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' })
        }}
        className="group relative overflow-hidden rounded-2xl md:rounded-3xl cursor-pointer transition-shadow duration-300 w-full h-[130px] min-[375px]:h-[135px] sm:h-[185px] md:h-[260px] shadow-md hover:shadow-lg"
      >
        <Image
          src="/food_genz_banner.png"
          alt="Delicious Food in minutes - FastKirana"
          fill
          sizes="100vw"
          className="object-cover object-center transition-transform duration-700 group-hover:scale-[1.01]"
          priority
        />
      </div>


      {/* Experience Switcher */}
      <div className="relative flex w-full h-[52px] sm:h-14 p-1 bg-zinc-150/60 dark:bg-zinc-900/40 rounded-full border border-zinc-200/50 dark:border-zinc-800/60 overflow-hidden mt-4 mb-3.5 select-none shadow-[0_4px_16px_rgba(0,0,0,0.01)]">
        <button
          onClick={() => setExperienceMode('cafe')}
          className={cn(
            "relative flex-1 h-full z-15 flex items-center justify-center gap-2 sm:gap-2.5 cursor-pointer rounded-full select-none outline-none transition-all duration-300",
            experienceMode === 'cafe'
              ? "text-orange-500 dark:text-orange-400 font-black scale-102"
              : "text-zinc-650 dark:text-zinc-450 hover:text-zinc-800 dark:hover:text-zinc-200 font-extrabold"
          )}
        >
          <Coffee className="h-4.5 w-4.5 sm:h-5 sm:w-5 shrink-0" strokeWidth={2.5} />
          <div className="flex flex-col text-left">
            <span className="text-[12px] sm:text-[14px] font-black leading-none">Cafe</span>
            <span className="text-[9px] sm:text-[10px] font-bold opacity-85 leading-tight mt-0.5">Coffee, Snacks &amp; More</span>
          </div>
        </button>
        
        <button
          onClick={() => setExperienceMode('restaurant')}
          className={cn(
            "relative flex-1 h-full z-15 flex items-center justify-center gap-2 sm:gap-2.5 cursor-pointer rounded-full select-none outline-none transition-all duration-300",
            (experienceMode as string) === 'restaurant'
              ? "text-orange-500 dark:text-orange-400 font-black scale-102"
              : "text-zinc-650 dark:text-zinc-450 hover:text-zinc-800 dark:hover:text-zinc-200 font-extrabold"
          )}
        >
          <ChefHat className="h-4.5 w-4.5 sm:h-5 sm:w-5 shrink-0" strokeWidth={2.5} />
          <div className="flex flex-col text-left">
            <span className="text-[12px] sm:text-[14px] font-black leading-none">Restaurant</span>
            <span className="text-[9px] sm:text-[10px] font-bold opacity-85 leading-tight mt-0.5">Meals, Combos &amp; More</span>
          </div>
        </button>

        {/* Sliding Liquid Pill Indicator */}
        <motion.div
          animate={{
            x: experienceMode === 'cafe' ? 0 : '100%',
          }}
          transition={{
            type: 'spring',
            stiffness: 380,
            damping: 22,
            mass: 0.65
          }}
          className="absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-full bg-white dark:bg-zinc-955 shadow-[0_4px_12px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)] z-10"
          style={{
            left: '4px',
          }}
        />
      </div>

        <>
          {/* Café Category Section Header */}
          <div id="cafe-menu-categories-anchor" className="flex items-center justify-between px-1 scroll-mt-24">
            <h4 className="text-[11px] font-black uppercase tracking-wider text-text-muted">
              {((experienceMode as string) === 'restaurant') ? 'Restaurant Categories' : 'Cafe Categories'}
            </h4>
            <button
              onClick={() => {
                const target = document.getElementById('cafe-menu-categories-anchor')
                if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' })
              }}
              className="text-[11px] font-bold text-rose-600 dark:text-rose-455 hover:opacity-85 flex items-center gap-0.5 select-none cursor-pointer"
            >
              <span>See Menu</span>
              <ChevronRight size={10} strokeWidth={3} />
            </button>
          </div>

          {/* Café Menu Categories Horizontal Scrollbar: Circular Item Style */}
          <div className="flex gap-5 sm:gap-7 overflow-x-auto pb-4 pt-2.5 scrollbar-none px-1 snap-x snap-mandatory scroll-smooth select-none w-full justify-start">
            {isLoading ? (
              Array.from({ length: 5 }).map((_, idx) => (
                <div key={`skeleton-${idx}`} className="flex flex-col items-center gap-2 shrink-0 snap-start">
                  <div className="h-18 w-18 sm:h-20 sm:w-20 rounded-full bg-zinc-200 dark:bg-zinc-800/40 animate-pulse" />
                  <div className="h-3 w-12 rounded bg-zinc-200 dark:bg-zinc-800/40 animate-pulse" />
                </div>
              ))
            ) : (
              filteredCategories.map((cat) => {
                const href = cat.tag === 'all' ? '/?mode=cafe' : `/?mode=cafe&section=${cat.tag}`
                const isActive = showProducts && activeCategoryTag === cat.tag
                return (
                  <Link
                    key={cat.tag}
                    href={href}
                    onClick={(e) => {
                      if (showProducts) {
                        e.preventDefault()
                        setActiveCategoryTag(cat.tag)
                        const targetId = cat.tag === 'all' ? 'cafe-menu-categories-anchor' : `cafe-home-section-${cat.tag}`
                        const target = document.getElementById(targetId)
                        if (target) {
                          target.scrollIntoView({ behavior: 'smooth', block: 'start' })
                        }
                        if (typeof window !== 'undefined' && 'vibrate' in navigator) {
                          navigator.vibrate(8)
                        }
                      }
                    }}
                    className="flex flex-col items-center gap-2 shrink-0 snap-start select-none cursor-pointer group outline-none"
                  >
                    {/* Circle Image Wrapper */}
                    <div 
                      className={cn(
                        "relative w-18 h-18 sm:w-20 sm:h-20 rounded-full overflow-hidden flex items-center justify-center p-1 transition-all duration-300 shadow-xs border-2 bg-white dark:bg-zinc-950",
                        isActive 
                          ? "border-orange-500 scale-105 shadow-[0_4px_14px_rgba(249,115,22,0.22)]" 
                          : "border-zinc-200/70 dark:border-zinc-800/60 group-hover:border-zinc-300 dark:group-hover:border-zinc-700 group-hover:scale-102"
                      )}
                    >
                      <div className="relative w-full h-full rounded-full overflow-hidden bg-zinc-50 dark:bg-zinc-900/50 flex items-center justify-center">
                        {cat.image ? (
                          <Image
                            src={cat.image}
                            alt={cat.title}
                            fill
                            sizes="(max-width: 640px) 72px, 80px"
                            className="object-cover transition-transform duration-500 group-hover:scale-108"
                          />
                        ) : (
                          <span className="text-2xl select-none">{cat.emoji}</span>
                        )}
                      </div>
                    </div>
                    {/* Centered label below */}
                    <span 
                      className={cn(
                        "text-[11px] sm:text-xs font-black text-center tracking-tight transition-colors duration-300",
                        isActive 
                          ? "text-orange-500" 
                          : "text-zinc-850 dark:text-zinc-250 group-hover:text-zinc-900 dark:group-hover:text-white"
                      )}
                    >
                      {cat.title}
                    </span>
                  </Link>
                )
              })
            )}
          </div>

          {/* Category-wise Cafe Products Slider List (stacked vertically) */}
          {showProducts && filteredCategories.filter(cat => cat.tag !== 'all' && cat.products?.length > 0).map((cat) => {
            const displayProducts = cat.products.slice(0, 5)
            const hasMore = cat.products.length > 5
            const isExpanded = expandedCategories.has(cat.tag)

            return (
              <div 
                key={cat.tag} 
                id={`cafe-home-section-${cat.tag}`}
                className="space-y-3 pt-6 border-t border-zinc-200/50 dark:border-zinc-800/40 first:border-t-0 scroll-mt-24"
              >
                <div className="flex items-center justify-between px-1">
                  <div className="flex items-center gap-1.5">
                    <div className="w-6 h-6 rounded-full overflow-hidden relative bg-zinc-100 dark:bg-zinc-800 border border-zinc-200/50 dark:border-zinc-700/50 shrink-0">
                      {cat.image ? (
                        <Image
                          src={cat.image}
                          alt={cat.title}
                          fill
                          sizes="24px"
                          className="object-cover"
                        />
                      ) : (
                        <span className="text-xs">{cat.emoji}</span>
                      )}
                    </div>
                    <h4 className="text-xs sm:text-sm font-bold uppercase tracking-wider text-text-primary">
                      {cat.title} Specials
                    </h4>
                  </div>
                  <button
                    onClick={() => {
                      toggleCategoryExpand(cat.tag)
                      if (!isExpanded) {
                        const target = document.getElementById(`cafe-home-section-${cat.tag}`)
                        if (target) {
                          setTimeout(() => {
                            target.scrollIntoView({ behavior: 'smooth', block: 'start' })
                          }, 100)
                        }
                      }
                    }}
                    className="text-[11px] font-bold text-rose-600 dark:text-rose-455 hover:opacity-85 flex items-center gap-0.5 select-none cursor-pointer"
                  >
                    <span>{isExpanded ? 'See Less' : `See All (${cat.products.length})`}</span>
                    <ChevronRight size={10} strokeWidth={3} className={cn("transition-transform duration-300", isExpanded && "rotate-90")} />
                  </button>
                </div>
                
                {isExpanded ? (
                  <div className="grid grid-cols-2 min-[375px]:grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3.5 pt-1.5 px-1">
                    {cat.products.map((p: any) => (
                      <div key={p.id} className="w-full">
                        <ProductCard product={p} />
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex gap-3.5 md:gap-4 overflow-x-auto pb-4 pt-1.5 scrollbar-hide snap-x snap-mandatory scroll-smooth px-1">
                    {displayProducts.map((p: any) => (
                      <div key={p.id} className="w-[140px] min-[375px]:w-[160px] sm:w-[180px] md:w-[220px] shrink-0 snap-start">
                        <ProductCard product={p} />
                      </div>
                    ))}
                    
                    {hasMore && (
                      <div className="w-[140px] min-[375px]:w-[160px] sm:w-[180px] md:w-[220px] shrink-0 snap-start">
                        <button
                          onClick={() => {
                            toggleCategoryExpand(cat.tag)
                            const target = document.getElementById(`cafe-home-section-${cat.tag}`)
                            if (target) {
                              setTimeout(() => {
                                target.scrollIntoView({ behavior: 'smooth', block: 'start' })
                              }, 100)
                            }
                          }}
                          className="group relative flex flex-col items-center justify-center overflow-hidden rounded-2xl border border-dashed border-zinc-200 dark:border-zinc-800 bg-card p-3 shadow-xs transition-all duration-300 hover:border-rose-500/40 hover:bg-rose-500/5 cursor-pointer h-[210px] min-[375px]:h-[230px] sm:h-[250px] md:h-[290px] w-full"
                        >
                          <div className="w-10 h-10 rounded-full bg-rose-500/10 dark:bg-rose-500/5 flex items-center justify-center text-rose-600 dark:text-rose-455 group-hover:scale-110 transition-transform duration-300">
                            <ChevronRight size={20} strokeWidth={2.5} />
                          </div>
                          <span className="text-xs font-bold text-text-primary mt-3 text-center">
                            See More
                          </span>
                          <span className="text-[10px] font-medium text-text-secondary mt-1 text-center">
                            +{cat.products.length - 5} items
                          </span>
                        </button>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )
          })}
        </>
    </section>
  )
}

