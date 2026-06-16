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
        <div className="relative overflow-hidden rounded-2xl border border-amber-500/20 bg-gradient-to-r from-zinc-950 via-stone-900 to-zinc-900 p-5 flex items-center justify-between shadow-xl transition-all duration-500 hover:border-amber-500/40 hover:shadow-amber-500/5 hover:-translate-y-0.5">
          {/* Subtle animated light sweep */}
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out" />
          
          {/* Ambient glow in background */}
          <div className="absolute -right-10 -bottom-10 w-40 h-40 rounded-full bg-amber-500/10 blur-3xl group-hover:bg-amber-500/15 transition-all duration-500" />
          <div className="absolute -left-10 -top-10 w-32 h-32 rounded-full bg-rose-500/10 blur-2xl group-hover:bg-rose-500/15 transition-all duration-500" />

          <div className="flex items-center gap-4 relative z-10">
            {/* Elegant 3D Coffee Cup Container */}
            <div className="relative w-14 h-14 rounded-2xl bg-gradient-to-br from-amber-500/10 to-rose-500/10 border border-white/10 flex items-center justify-center shadow-inner group-hover:scale-105 transition-transform duration-300">
              <span className="text-3xl select-none filter drop-shadow-[0_4px_8px_rgba(251,191,36,0.35)] animate-float">☕</span>
              {/* Pulsing halo */}
              <div className="absolute inset-0 rounded-2xl bg-amber-500/5 animate-pulse pointer-events-none" />
            </div>
            
            <div className="text-left space-y-1">
              <div className="flex items-center gap-2">
                <h3 className="text-transparent bg-clip-text bg-gradient-to-r from-amber-100 via-amber-200 to-orange-100 font-extrabold text-base tracking-tight group-hover:from-white group-hover:to-amber-200 transition-all duration-300">
                  FastKirana Café
                </h3>
                <span className="inline-flex items-center gap-1 bg-amber-500/15 text-amber-300 border border-amber-500/20 px-2 py-0.5 rounded text-[8px] font-black uppercase tracking-wider">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
                  Live Kitchen
                </span>
              </div>
              <p className="text-stone-300 text-xs font-medium max-w-[280px] sm:max-w-md">
                Freshly prepared sandwiches, pasta, shakes & more — delivered hot!
              </p>
            </div>
          </div>

          <div className="relative z-10 flex items-center gap-2 bg-gradient-to-r from-amber-600 to-rose-600 text-white font-bold text-xs px-4 py-2 rounded-xl shadow-[0_4px_12px_rgba(217,119,6,0.2)] group-hover:shadow-[0_6px_20px_rgba(217,119,6,0.4)] group-hover:scale-105 transition-all duration-300 shrink-0 border border-amber-400/20">
            <span>Menu</span>
            <ChevronRight size={14} className="group-hover:translate-x-0.5 transition-transform" strokeWidth={3} />
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
