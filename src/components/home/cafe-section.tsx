'use client'

import Link from 'next/link'
import Image from 'next/image'
import { ChevronRight } from 'lucide-react'
import { cn } from '@/lib/utils'

export function CafeSection() {
  const categories = [
    { tag: 'all', title: 'All Menu', emoji: '🍽️', image: '/cafe_all_menu_category.png' },
    { tag: 'hot-beverage', title: 'Brews', emoji: '☕', image: '/cafe_brews_category.png' },
    { tag: 'hot-bite', title: 'Snacks', emoji: '🥟', image: '/cafe_snacks_category.png' },
    { tag: 'sandwiches', title: 'Sandwiches', emoji: '🥪', image: '/cafe_sandwiches_category.png' },
    { tag: 'frankie-rolls', title: 'Rolls', emoji: '🌯', image: '/cafe_rolls_category.png' },
    { tag: 'chinese', title: 'Chinese', emoji: '🥡', image: '/cafe_chinese_category.png' },
    { tag: 'italian-pasta', title: 'Pasta', emoji: '🍝', image: '/cafe_pasta_category.png' },
    { tag: 'bombay-bites', title: 'Bombay Bites', emoji: '🥪', image: '/cafe_bombay_bites_category.png' },
    { tag: 'rice-dishes', title: 'Rice', emoji: '🍚', image: '/cafe_rice_category.png' },
  ]

  return (
    <section className="space-y-4">
      {/* Café Banner Card */}
      <Link href="/cafe" className="block group">
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-amber-900 via-amber-800 to-rose-900 p-4 md:p-5 flex items-center justify-between shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.01]">
          <div className="flex items-center gap-3">
            <span className="text-3xl md:text-4xl select-none animate-float">☕</span>
            <div className="text-left">
              <h3 className="text-white font-extrabold text-sm md:text-base tracking-tight">FastKirana Café</h3>
              <p className="text-amber-200/80 text-[10px] md:text-xs font-medium">Fresh sandwiches, pasta, shakes & more — order now!</p>
            </div>
          </div>
          <div className="flex items-center gap-1.5 bg-white/15 backdrop-blur-sm px-3.5 py-1.5 rounded-xl border border-white/20 group-hover:bg-white/25 transition-all shrink-0">
            <span className="text-white text-xs font-bold hidden sm:inline">Explore Menu</span>
            <span className="text-white text-xs font-bold sm:hidden">Menu</span>
            <svg className="w-4 h-4 text-white group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" /></svg>
          </div>
          {/* Decorative circles */}
          <div className="absolute -top-6 -right-6 w-20 h-20 bg-white/5 rounded-full" />
          <div className="absolute -bottom-4 -left-4 w-16 h-16 bg-white/5 rounded-full" />
        </div>
      </Link>

      {/* Café Category Section Header */}
      <div className="flex items-center justify-between px-1">
        <h4 className="text-[11px] font-black uppercase tracking-wider text-text-muted">
          Trending Café Categories
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
                  <span className="text-3xl select-none leading-none">{cat.emoji}</span>
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
