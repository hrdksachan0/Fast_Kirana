'use client'

import Link from 'next/link'
import { Category } from '@/types'
import { Salad, Milk, Cookie, CupSoda, Sparkles, Home, Croissant, Wheat, ShoppingBag } from 'lucide-react'

interface CategoryGridProps {
  categories: Category[]
}

const iconMap: Record<string, React.ComponentType<any>> = {
  'fruits-vegetables': Salad,
  'dairy-breakfast': Milk,
  'snacks-munchies': Cookie,
  'beverages': CupSoda,
  'personal-care': Sparkles,
  'household': Home,
  'bakery-biscuits': Croissant,
  'atta-rice-dal': Wheat,
}

// Generate a consistent item count (15-80) from a string
function getItemCount(name: string): number {
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = (hash << 5) - hash + name.charCodeAt(i)
    hash |= 0 // Convert to 32bit integer
  }
  return 15 + (Math.abs(hash) % 66) // Range: 15-80
}

export function CategoryGrid({ categories }: CategoryGridProps) {
  // Map of category slugs to visual themes with glowing rings
  const colorMap: Record<string, { bg: string; text: string; gradient: string; ring: string }> = {
    'fruits-vegetables': { 
      bg: 'bg-emerald-50 dark:bg-emerald-500/5', 
      text: 'text-emerald-500 dark:text-emerald-400', 
      gradient: 'from-emerald-100/30 to-emerald-50/10 dark:from-emerald-500/10 dark:to-transparent', 
      ring: 'group-hover:border-emerald-500/50 group-hover:shadow-[0_0_15px_rgba(16,185,129,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(16,185,129,0.5)]' 
    },
    'dairy-breakfast': { 
      bg: 'bg-blue-50 dark:bg-blue-500/5', 
      text: 'text-blue-500 dark:text-blue-400', 
      gradient: 'from-blue-100/30 to-blue-50/10 dark:from-blue-500/10 dark:to-transparent', 
      ring: 'group-hover:border-blue-500/50 group-hover:shadow-[0_0_15px_rgba(59,130,246,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(59,130,246,0.5)]' 
    },
    'snacks-munchies': { 
      bg: 'bg-amber-50 dark:bg-amber-500/5', 
      text: 'text-amber-500 dark:text-amber-400', 
      gradient: 'from-amber-100/30 to-amber-50/10 dark:from-amber-500/10 dark:to-transparent', 
      ring: 'group-hover:border-amber-500/50 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
    },
    'beverages': { 
      bg: 'bg-purple-50 dark:bg-purple-500/5', 
      text: 'text-purple-500 dark:text-purple-400', 
      gradient: 'from-purple-100/30 to-purple-50/10 dark:from-purple-500/10 dark:to-transparent', 
      ring: 'group-hover:border-purple-500/50 group-hover:shadow-[0_0_15px_rgba(139,92,246,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(139,92,246,0.5)]' 
    },
    'personal-care': { 
      bg: 'bg-pink-50 dark:bg-pink-500/5', 
      text: 'text-pink-500 dark:text-pink-400', 
      gradient: 'from-pink-100/30 to-pink-50/10 dark:from-pink-500/10 dark:to-transparent', 
      ring: 'group-hover:border-pink-500/50 group-hover:shadow-[0_0_15px_rgba(236,72,153,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(236,72,153,0.5)]' 
    },
    'household': { 
      bg: 'bg-indigo-50 dark:bg-indigo-500/5', 
      text: 'text-indigo-500 dark:text-indigo-400', 
      gradient: 'from-indigo-100/30 to-indigo-50/10 dark:from-indigo-500/10 dark:to-transparent', 
      ring: 'group-hover:border-indigo-500/50 group-hover:shadow-[0_0_15px_rgba(99,102,241,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(99,102,241,0.5)]' 
    },
    'bakery-biscuits': { 
      bg: 'bg-orange-50 dark:bg-orange-500/5', 
      text: 'text-orange-500 dark:text-orange-400', 
      gradient: 'from-orange-100/30 to-orange-50/10 dark:from-orange-500/10 dark:to-transparent', 
      ring: 'group-hover:border-orange-500/50 group-hover:shadow-[0_0_15px_rgba(249,115,22,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(249,115,22,0.5)]' 
    },
    'atta-rice-dal': { 
      bg: 'bg-yellow-50 dark:bg-yellow-500/5', 
      text: 'text-yellow-500 dark:text-yellow-400', 
      gradient: 'from-yellow-100/30 to-yellow-50/10 dark:from-yellow-500/10 dark:to-transparent', 
      ring: 'group-hover:border-yellow-500/50 group-hover:shadow-[0_0_15px_rgba(234,179,8,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(234,179,8,0.5)]' 
    },
  }

  return (
    <section className="py-6">
      <h2 className="text-lg md:text-2xl font-black text-text-primary tracking-tight mb-4 px-1 flex items-center gap-2">
        <span className="h-5 w-1.5 rounded-full bg-primary animate-pulse-gentle" />
        Shop by Category
      </h2>

      {/* Mobile: Horizontal scroll strip */}
      <div
        className="flex gap-3 overflow-x-auto pb-3 md:hidden scrollbar-hide scroll-smooth snap-x snap-mandatory"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
      >
        {/* Cafe card */}
        <Link
          href="/cafe"
          className="group relative flex flex-col items-center text-center flex-shrink-0 snap-start w-[80px]"
        >
          <span className="absolute -top-1.5 right-0.5 z-10 flex items-center gap-0.5 rounded-full bg-gradient-to-r from-red-600 to-orange-500 px-1.5 py-0.5 text-[7px] font-black text-white shadow-sm border border-orange-300/30 animate-pulse-gentle whitespace-nowrap">
            HOT
          </span>
          <div className="flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-pink-500 via-rose-500 to-orange-500 mb-2 shadow-md transition-all duration-300 group-hover:scale-110 ring-2 ring-orange-300/40 group-hover:shadow-[0_0_15px_rgba(244,63,94,0.5)] overflow-hidden">
            <span className="text-2xl select-none transition-transform duration-300 group-hover:scale-110 group-hover:rotate-12">☕</span>
          </div>
          <span className="text-[11px] font-black text-rose-600 dark:text-rose-400 leading-tight line-clamp-2">Cafe</span>
          <span className="text-[9px] text-orange-600 dark:text-orange-400 font-bold mt-0.5">Hot & Fresh</span>
        </Link>

        {categories
          .filter((category) => category.slug !== 'cafe')
          .map((category) => {
          const colors = colorMap[category.slug] || {
            bg: 'bg-zinc-50 dark:bg-white/5',
            text: 'text-zinc-500 dark:text-zinc-400',
            gradient: 'from-zinc-100/30 to-zinc-50/10',
            ring: 'group-hover:border-zinc-500/50',
          }
          const itemCount = getItemCount(category.name)
          const IconComponent = iconMap[category.slug] || ShoppingBag

          return (
            <Link
              key={category.id}
              href={`/category/${category.slug}`}
              className="group flex flex-col items-center text-center flex-shrink-0 snap-start w-[80px]"
            >
              <div
                className={`flex items-center justify-center w-16 h-16 rounded-2xl ${colors.bg} border border-white/20 dark:border-zinc-800/30 backdrop-blur-md mb-2 shadow-sm transition-all duration-300 group-hover:scale-110 group-hover:shadow-lg ${colors.ring} overflow-hidden`}
              >
                {category.imageUrl && (category.imageUrl.startsWith('data:image/') || category.imageUrl.startsWith('/') || category.imageUrl.startsWith('http')) ? (
                  <img src={category.imageUrl} alt={category.name} className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-110" />
                ) : category.imageUrl && category.imageUrl.length < 5 ? (
                  <span className="text-2xl transition-transform duration-300 group-hover:scale-110 group-hover:rotate-12 select-none">{category.imageUrl}</span>
                ) : (
                  <IconComponent className={`h-7 w-7 ${colors.text} transition-all duration-300 group-hover:scale-110 group-hover:rotate-12`} />
                )}
              </div>
              <span className="text-[11px] font-bold text-text-primary group-hover:text-primary transition-colors leading-tight line-clamp-2">
                {category.name}
              </span>
              <span className="text-[9px] text-text-muted mt-0.5">
                {itemCount} items
              </span>
            </Link>
          )
        })}
      </div>

      {/* Desktop: Grid layout (8 columns) */}
      <div className="hidden md:grid grid-cols-8 gap-4 stagger-children">
        {/* Cafe card */}
        <Link
          href="/cafe"
          className="group relative flex flex-col items-center text-center p-3 rounded-2xl transition-all duration-300 hover:shadow-card hover:-translate-y-1"
        >
          <span className="absolute -top-1.5 right-1.5 z-10 flex items-center gap-0.5 rounded-full bg-gradient-to-r from-red-600 to-orange-500 px-2 py-0.5 text-[8px] font-black text-white shadow-sm border border-orange-300/30 animate-pulse-gentle whitespace-nowrap">
            ☕ HOT
          </span>
          <div className="flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-pink-500 via-rose-500 to-orange-500 mb-2 shadow-md transition-all duration-300 group-hover:scale-110 ring-2 ring-orange-300/40 group-hover:ring-orange-400 group-hover:shadow-[0_0_18px_rgba(244,63,94,0.45)] overflow-hidden">
            <span className="text-3xl transition-transform duration-300 group-hover:scale-115 group-hover:rotate-12 select-none">☕</span>
          </div>
          <span className="text-xs font-black text-rose-600 dark:text-rose-400 group-hover:text-rose-700 transition-colors leading-tight line-clamp-2">Cafe</span>
          <span className="text-[10px] text-orange-600 dark:text-orange-400 font-bold mt-0.5">Hot & Fresh</span>
        </Link>

        {categories
          .filter((category) => category.slug !== 'cafe')
          .map((category) => {
          const colors = colorMap[category.slug] || {
            bg: 'bg-zinc-50 dark:bg-white/5',
            text: 'text-zinc-500 dark:text-zinc-400',
            gradient: 'from-zinc-100/30 to-zinc-50/10',
            ring: 'group-hover:border-zinc-500/50',
          }
          const itemCount = getItemCount(category.name)
          const IconComponent = iconMap[category.slug] || ShoppingBag

          return (
            <Link
              key={category.id}
              href={`/category/${category.slug}`}
              className="group flex flex-col items-center text-center p-3 rounded-2xl transition-all duration-300 hover:shadow-card hover:-translate-y-1"
            >
              <div
                className={`flex items-center justify-center w-16 h-16 rounded-2xl ${colors.bg} border border-white/20 dark:border-zinc-800/30 backdrop-blur-md mb-2 shadow-sm transition-all duration-300 group-hover:scale-110 group-hover:shadow-lg ${colors.ring} overflow-hidden`}
              >
                {category.imageUrl && (category.imageUrl.startsWith('data:image/') || category.imageUrl.startsWith('/') || category.imageUrl.startsWith('http')) ? (
                  <img src={category.imageUrl} alt={category.name} className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-110" />
                ) : category.imageUrl && category.imageUrl.length < 5 ? (
                  <span className="text-3xl transition-transform duration-300 group-hover:scale-110 group-hover:rotate-12 select-none">{category.imageUrl}</span>
                ) : (
                  <IconComponent className={`h-7 w-7 ${colors.text} transition-all duration-300 group-hover:scale-110 group-hover:rotate-12`} />
                )}
              </div>
              <span className="text-xs font-bold text-text-primary group-hover:text-primary transition-colors leading-tight line-clamp-2">
                {category.name}
              </span>
              <span className="text-[10px] text-text-muted mt-0.5">
                {itemCount} items
              </span>
            </Link>
          )
        })}
      </div>
    </section>
  )
}
