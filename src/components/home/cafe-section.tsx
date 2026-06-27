'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { ChevronRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import { DEFAULT_CAFE_MENU_SECTIONS } from '@/lib/constants'
import { motion } from 'framer-motion'
import { useUIStore } from '@/stores/ui-store'

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

const getShortTitle = (tag: string, fullTitle: string) => {
  const customMapping: Record<string, string> = {
    'hot-beverage': 'Brews',
    'hot-bite': 'Snacks',
    'sandwiches': 'Sandwiches',
    'frankie-rolls': 'Rolls',
    'chinese': 'Chinese',
    'italian-pasta': 'Pasta',
    'bombay-bites': 'Bombay',
    'rice-dishes': 'Rice',
    'shakes': 'Shakes',
    'mocktails': 'Mocktails',
    'cold-coffee': 'Coffee',
    'south-indian': 'South Indian',
    'bakery': 'Bakery',
    'chilled': 'Cold Drinks',
    'pizza': 'Pizza',
    'burgers': 'Burgers',
    'garlic-bread': 'Garlic Bread',
    'desserts': 'Desserts',
  }
  return customMapping[tag] || fullTitle
}

export function CafeSection() {
  const settings = useUIStore((s) => s.settings) || {}
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const isCafeActive = cafeOpen && (categoryStatus['cafe'] !== false)

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
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    setIsLoading(true)
    fetch('/api/products?category=cafe&limit=250')
      .then(res => res.json())
      .then(productsRes => {
        const dbProducts = productsRes?.products || productsRes || []
        const customSectionsStr = settings.cafe_menu_sections || settings.CAFE_MENU_SECTIONS
        
        let parsedSections = null
        if (customSectionsStr) {
          try {
            const parsed = JSON.parse(customSectionsStr)
            if (Array.isArray(parsed) && parsed.length > 0) {
              parsedSections = parsed
            }
          } catch (e) {}
        }

        const PREDEFINED_CATEGORIES = parsedSections || DEFAULT_CAFE_MENU_SECTIONS

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
            finalCategories.push({
              tag: sec.tag,
              title: sec.title,
              emoji: sec.emoji,
              image: sec.image
            })
          }
        })

        dynamicSections.forEach(sec => {
          finalCategories.push({
            tag: sec.tag,
            title: sec.title,
            emoji: sec.emoji,
            image: sec.image
          })
        })

        const allGroupedIds = new Set<string>()
        PREDEFINED_CATEGORIES.forEach(cat => {
          const sec = sectionsMap.get(cat.tag)
          if (sec) {
            sec.matchedIds.forEach((id: string) => allGroupedIds.add(id))
          }
        })
        const moreCount = dbProducts.filter((p: any) => !allGroupedIds.has(p.id)).length
        if (moreCount > 0) {
          finalCategories.push({
            tag: 'more',
            title: 'More Specials',
            emoji: '🍽️',
            image: '/cafe_all_menu_category.png'
          })
        }

        // Only show categories that have products in the database
        setCategories([
          { tag: 'all', title: 'All Menu', emoji: '🍽️', image: '/cafe_all_menu_category.png' },
          ...finalCategories
        ])
      })
      .catch(() => {})
      .finally(() => {
        setIsLoading(false)
      })
  }, [settings])

  return (
    <section className="space-y-4">
      {/* Café Banner Card */}
      <Link href="/cafe" className="block group">
        <div className="relative overflow-hidden rounded-3xl h-[120px] sm:h-[140px] md:h-[160px] border border-amber-500/20 shadow-[0_8px_30px_rgba(0,0,0,0.15)] transition-all duration-500 hover:border-amber-500/40 hover:shadow-[0_12px_40px_rgba(245,158,11,0.15)] hover:-translate-y-0.5">
          {/* Cafe Banner Image */}
          <Image
            src="/cafe_banner.png"
            alt="Cafe Banner"
            fill
            className="object-cover transition-transform duration-700 group-hover:scale-103"
          />

          {/* Premium dark gradient overlay for text readability */}
          <div className="absolute inset-0 bg-gradient-to-r from-black/85 via-black/55 to-transparent z-10" />

          {/* Subtle light sweep reflection */}
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out z-10" />

          {/* Banner content */}
          <div className="absolute inset-0 flex items-center justify-between px-4 sm:px-8 z-20">
            <div className="text-left space-y-1 sm:space-y-1.5 max-w-[62%] sm:max-w-[70%]">
              <div className="flex items-center gap-1.5 flex-wrap">
                {isCafeActive ? (
                  <span className="inline-flex items-center gap-1 bg-[#00b140] text-white px-2 py-0.5 sm:px-2.5 sm:py-0.5 rounded-full text-[8px] sm:text-[9px] font-black uppercase tracking-wider shadow-sm">
                    ● Live Kitchen
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 bg-zinc-600 text-zinc-350 px-2 py-0.5 sm:px-2.5 sm:py-0.5 rounded-full text-[8px] sm:text-[9px] font-black uppercase tracking-wider shadow-sm">
                    ● Kitchen Closed
                  </span>
                )}
                <span className="text-[10px] sm:text-xs animate-pulse-gentle">🔥</span>
              </div>
              <div className="flex items-center gap-1 sm:gap-1.5">
                <h3 className="text-white font-black text-sm min-[375px]:text-base sm:text-2xl md:text-3xl tracking-tight leading-tight">
                  FastKirana Café
                </h3>
                <span className="text-xs sm:text-base animate-float">☕</span>
              </div>
              <p className="text-zinc-200 text-[8.5px] min-[375px]:text-[9.5px] sm:text-xs font-semibold leading-normal min-[375px]:leading-relaxed line-clamp-2">
                Freshly prepared sandwiches, rolls, Chinese, Italian pasta & beverages — delivered hot!
              </p>
            </div>

            <div className="shrink-0 pl-2 self-end mb-2.5 sm:mb-3.5">
              <span className="inline-flex items-center gap-1 bg-[#e20a22] hover:bg-[#c8081c] text-white font-extrabold px-2.5 py-1.5 sm:px-4 sm:py-2 rounded-full text-[8.5px] sm:text-xs shadow-md transition-all duration-300 group-hover:scale-105 active:scale-95 cursor-pointer uppercase tracking-wider">
                <span>Open Menu</span>
                <ChevronRight className="h-3 w-3 sm:h-3.5 sm:w-3.5 group-hover:translate-x-0.5 transition-transform duration-300" />
              </span>
            </div>
          </div>
        </div>
      </Link>

      {/* Café Category Section Header */}
      <div className="flex items-center justify-between px-1">
        <h4 className="text-[11px] font-black uppercase tracking-wider text-text-muted">
          Cafe Categories
        </h4>
        <Link href="/cafe" className="text-[11px] font-black text-rose-600 dark:text-rose-400 hover:opacity-85 flex items-center gap-0.5 select-none">
          <span>See Menu</span>
          <ChevronRight size={10} strokeWidth={3} />
        </Link>
      </div>

      {/* Café Menu Categories Horizontal Scrollbar */}
      <div className="flex gap-4.5 overflow-x-auto pb-3.5 pt-1.5 scrollbar-none px-2 snap-x snap-mandatory scroll-smooth select-none">
        {isLoading ? (
          Array.from({ length: 8 }).map((_, idx) => (
            <div
              key={`skeleton-${idx}`}
              className="flex flex-col items-center text-center w-[70px] shrink-0 snap-start animate-pulse"
            >
              {/* Circular skeleton */}
              <div className="w-[64px] h-[64px] mx-auto rounded-full bg-zinc-200 dark:bg-zinc-800/40 relative overflow-hidden before:absolute before:inset-0 before:-translate-x-full before:animate-[shimmer_2s_infinite] before:bg-gradient-to-r before:from-transparent before:via-white/10 dark:before:via-white/5 before:to-transparent" />
              {/* Text skeleton */}
              <div className="h-3 w-12 bg-zinc-200 dark:bg-zinc-800/40 rounded-md mt-2.5 relative overflow-hidden before:absolute before:inset-0 before:-translate-x-full before:animate-[shimmer_2s_infinite] before:bg-gradient-to-r before:from-transparent before:via-white/10 dark:before:via-white/5 before:to-transparent" />
            </div>
          ))
        ) : (
          categories.map((cat) => {
            const href = cat.tag === 'all' ? '/cafe' : `/cafe?section=${cat.tag}`
            return (
              <motion.div
                key={cat.tag}
                whileHover={{ y: -4, scale: 1.03, transition: { type: 'spring', stiffness: 300, damping: 15 } }}
                whileTap={{ scale: 0.95 }}
                className="w-[70px] shrink-0 snap-start"
              >
                <Link
                  href={href}
                  className="group flex flex-col items-center text-center cursor-pointer"
                >
                  {/* Circular image container */}
                  <div
                    className={cn(
                      "w-[64px] h-[64px] mx-auto rounded-full overflow-hidden shadow-[0_3px_10px_rgba(0,0,0,0.03)] border border-transparent dark:border-white/[0.02] relative group-hover:scale-105 transition-all duration-300 bg-zinc-50 dark:bg-zinc-900/40"
                    )}
                  >
                    {cat.image ? (
                      <Image
                        src={cat.image}
                        alt={cat.title}
                        fill
                        sizes="80px"
                        className="object-cover transition-transform duration-500 group-hover:scale-110"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-amber-500/10 dark:bg-amber-500/5 backdrop-blur-md rounded-full shadow-[inset_0_1.5px_3px_rgba(255,255,255,0.45)] border border-amber-500/15">
                        <span className="text-3xl select-none leading-none filter drop-shadow-[0_4px_6px_rgba(0,0,0,0.15)] transition-transform duration-300 group-hover:scale-110 group-hover:rotate-6">{cat.emoji}</span>
                      </div>
                    )}
                  </div>
                  <span className="text-[10px] font-black text-text-primary mt-2 truncate w-full group-hover:text-primary transition-colors">
                    {cat.title}
                  </span>
                </Link>
              </motion.div>
            )
          })
        )}
      </div>
    </section>
  )
}

