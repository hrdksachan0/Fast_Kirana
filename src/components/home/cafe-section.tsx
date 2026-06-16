'use client'

import Link from 'next/link'
import { Zap } from 'lucide-react'

export function CafeSection() {
  const categories = [
    { tag: 'hot-beverage', title: 'Brews', emoji: '☕' },
    { tag: 'hot-bite', title: 'Snacks', emoji: '🥟' },
    { tag: 'sandwiches', title: 'Sandwiches', emoji: '🥪' },
    { tag: 'frankie-rolls', title: 'Rolls', emoji: '🌯' },
    { tag: 'chinese', title: 'Chinese', emoji: '🥡' },
    { tag: 'italian-pasta', title: 'Pasta', emoji: '🍝' },
    { tag: 'bombay-bites', title: 'Bombay Bites', emoji: '🥪' },
    { tag: 'rice-dishes', title: 'Rice', emoji: '🍚' },
  ]

  return (
    <section className="space-y-3.5">
      {/* Café Banner Card */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-[#2a1711] via-[#1d0e0a] to-[#120805] dark:from-[#1b0d09] dark:via-[#0e0604] dark:to-black text-white p-4 md:p-8 flex items-center justify-between min-h-[130px] md:min-h-[165px] shadow-[0_8px_30px_rgba(35,21,16,0.15)] border border-[#3e241b] dark:border-[#20110c]">
        {/* Background Decorative Glow */}
        <div className="absolute -top-12 -right-12 w-48 h-48 rounded-full bg-amber-500/15 dark:bg-amber-500/10 blur-[50px] pointer-events-none animate-pulse-gentle" />
        
        {/* Left Content */}
        <div className="relative z-10 max-w-[62%] flex flex-col items-start text-left space-y-0.5 md:space-y-1">
          <div className="flex items-center gap-1.5">
            <h2 className="text-lg md:text-2xl font-black tracking-tight flex items-center gap-1.5">
              <span className="bg-gradient-to-r from-amber-200 via-orange-300 to-yellow-100 bg-clip-text text-transparent font-black">Café</span>
              <span className="text-base animate-float">☕</span>
            </h2>
          </div>
          <span className="inline-flex text-[8px] md:text-[10px] font-black bg-amber-500/10 border border-amber-500/20 text-amber-300 rounded-full px-2.5 py-0.5 tracking-wider uppercase mb-1">
            Freshly Prepared. Fast Delivered.
          </span>
          <p className="text-[10px] md:text-xs text-white/70 leading-snug font-semibold max-w-[210px] line-clamp-2">
            Coffee, Beverages, South Indian, Chinese & more from your favorite café.
          </p>
          
          <Link href="/cafe">
            <button className="bg-gradient-to-r from-white to-zinc-100 hover:from-zinc-100 hover:to-zinc-200 text-[#231510] text-[10px] md:text-xs font-black px-4 py-1.5 rounded-full mt-2.5 shadow-md hover:shadow-lg hover:shadow-amber-500/5 active:scale-95 transition-all cursor-pointer">
              Order Now →
            </button>
          </Link>
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

      {/* Café Menu Categories Horizontal Scrollbar */}
      <div className="flex gap-2.5 overflow-x-auto pb-1 scrollbar-none px-1 select-none snap-x snap-mandatory scroll-smooth">
        {categories.map((cat) => (
          <Link
            key={cat.tag}
            href={`/cafe?section=${cat.tag}`}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-black bg-[#faf6f0] dark:bg-[#1c120e] text-[#5d4037] dark:text-amber-200 border border-[#eddcd2]/50 dark:border-amber-950/20 hover:bg-[#eddcd2]/20 dark:hover:bg-[#2e1c15] transition-all shrink-0 whitespace-nowrap active:scale-95 shadow-sm snap-start"
          >
            <span>{cat.emoji}</span>
            <span>{cat.title}</span>
          </Link>
        ))}
      </div>
    </section>
  )
}
