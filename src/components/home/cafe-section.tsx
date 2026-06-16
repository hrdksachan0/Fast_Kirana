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
        <div className="relative overflow-hidden rounded-2xl border border-amber-500/25 bg-gradient-to-br from-[#1c0d02] via-[#0f0701] to-[#050200] p-5 flex items-center justify-between shadow-[0_8px_30px_rgba(0,0,0,0.35)] transition-all duration-500 hover:border-amber-500/50 hover:shadow-[0_12px_40px_rgba(245,158,11,0.12)] hover:-translate-y-0.5">
          {/* Subtle animated light sweep */}
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out" />
          
          {/* Ambient glow in background */}
          <div className="absolute -right-12 -bottom-12 w-36 h-36 bg-amber-500/15 rounded-full blur-[40px] pointer-events-none group-hover:bg-amber-500/25 transition-all duration-700 animate-pulse-gentle" />
          <div className="absolute -left-12 -top-12 w-36 h-36 bg-rose-500/10 rounded-full blur-[40px] pointer-events-none group-hover:bg-rose-500/15 transition-all duration-700" />

          <div className="flex items-center gap-4.5 relative z-10">
            {/* Elegant 3D Coffee Cup Container */}
            <div className="relative w-15 h-15 rounded-2xl bg-gradient-to-br from-amber-500/20 to-orange-600/10 border border-amber-500/25 flex items-center justify-center shadow-[0_0_15px_rgba(245,158,11,0.2)] group-hover:scale-105 group-hover:shadow-[0_0_20px_rgba(245,158,11,0.35)] transition-all duration-500 select-none">
              <span className="text-4xl select-none filter drop-shadow-[0_4px_8px_rgba(245,158,11,0.4)] animate-float leading-none">☕</span>
              {/* Pulsing halo */}
              <div className="absolute inset-0 rounded-2xl bg-amber-500/5 animate-pulse pointer-events-none" />
            </div>
            
            <div className="text-left space-y-1">
              <div className="flex items-center gap-2 flex-wrap">
                <h3 className="text-transparent bg-clip-text bg-gradient-to-r from-amber-100 via-amber-200 to-orange-100 font-extrabold text-base md:text-lg tracking-tight group-hover:from-white group-hover:to-amber-250 transition-all duration-300 flex items-center gap-0.5">
                  FastKirana Café
                  <ChevronRight size={18} className="text-amber-350 group-hover:translate-x-1.5 transition-transform duration-300 stroke-[3.5] self-center ml-0.5" />
                </h3>
                <span className="inline-flex items-center gap-1 bg-amber-500/20 text-amber-300 border border-amber-500/30 px-2 py-0.5 rounded-full text-[8.5px] font-black uppercase tracking-wider shadow-inner">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
                  Live Kitchen
                </span>
              </div>
              <p className="text-zinc-400 text-xs font-semibold leading-relaxed max-w-[240px] sm:max-w-md">
                Freshly prepared sandwiches, pasta, shakes & more — delivered hot!
              </p>
            </div>
          </div>

          {/* Right Floating Food Emoji instead of Menu button */}
          <div className="relative z-10 text-4xl filter drop-shadow-[0_0_8px_rgba(244,63,94,0.45)] animate-float select-none opacity-80 group-hover:opacity-100 group-hover:scale-110 transition-all duration-500 pr-2">
            🥪
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
