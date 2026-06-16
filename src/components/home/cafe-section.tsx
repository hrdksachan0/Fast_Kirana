'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { ChevronRight } from 'lucide-react'
import { cn } from '@/lib/utils'

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

  useEffect(() => {
    fetch('/api/settings')
      .then(res => res.json())
      .then(data => {
        const customSectionsStr = data.cafe_menu_sections || data.CAFE_MENU_SECTIONS
        if (customSectionsStr) {
          try {
            const parsed = JSON.parse(customSectionsStr)
            if (Array.isArray(parsed) && parsed.length > 0) {
              const mapped = parsed.map((sec: any) => ({
                tag: sec.tag,
                title: getShortTitle(sec.tag, sec.title),
                emoji: sec.emoji || '🍽️',
                image: getCafeSectionImage(sec.tag)
              }))
              setCategories([
                { tag: 'all', title: 'All Menu', emoji: '🍽️', image: '/cafe_all_menu_category.png' },
                ...mapped
              ])
            }
          } catch (e) {}
        }
      })
      .catch(() => {})
  }, [])

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
          <div className="absolute inset-0 flex items-center justify-between px-6 sm:px-8 z-20">
            <div className="text-left space-y-1 sm:space-y-1.5">
              <div className="flex items-center gap-2.5 flex-wrap">
                <h3 className="text-transparent bg-clip-text bg-gradient-to-r from-amber-100 via-amber-200 to-white font-black text-lg sm:text-2xl md:text-3xl tracking-tight group-hover:from-white group-hover:to-amber-200 transition-all duration-300 flex items-center gap-1">
                  Cafe
                  <ChevronRight className="h-5 w-5 sm:h-6 sm:w-6 text-amber-350 group-hover:translate-x-1.5 transition-transform duration-300 stroke-[3.5] self-center" />
                </h3>
                <span className="inline-flex items-center gap-1 bg-amber-500/20 text-amber-300 border border-amber-500/35 px-2 py-0.5 rounded-full text-[8px] sm:text-[9px] font-black uppercase tracking-wider shadow-inner">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
                  Live Kitchen
                </span>
              </div>
              <p className="text-zinc-100 text-[10px] sm:text-xs font-semibold leading-relaxed max-w-[200px] sm:max-w-md">
                Freshly prepared sandwiches, rolls, Chinese, Italian pasta & beverages — delivered hot!
              </p>
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
        {categories.map((cat) => {
          const href = cat.tag === 'all' ? '/cafe' : `/cafe?section=${cat.tag}`
          return (
            <Link
              key={cat.tag}
              href={href}
              className="group flex flex-col items-center text-center cursor-pointer active:scale-95 transition-all w-[70px] shrink-0 snap-start"
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
          )
        })}
      </div>
    </section>
  )
}
