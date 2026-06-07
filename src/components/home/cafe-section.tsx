'use client'

import Link from 'next/link'
import { Zap } from 'lucide-react'

export function CafeSection() {
  const cafeShortcuts = [
    { label: 'Coffee', emoji: '☕', href: '/search?q=coffee' },
    { label: 'Cold Drinks', emoji: '🥤', href: '/search?q=drinks' },
    { label: 'South Indian', emoji: '🥞', href: '/search?q=south+indian' },
    { label: 'Chinese', emoji: '🥢', href: '/search?q=chinese' },
  ]

  return (
    <section className="space-y-3">
      {/* Café Banner Card */}
      <div className="relative overflow-hidden rounded-[20px] bg-[#231510] text-white p-4 md:p-8 flex items-center justify-between min-h-[125px] md:min-h-[160px] shadow-lg border border-[#362119]">
        {/* Background Decorative Glow */}
        <div className="absolute top-0 right-0 w-48 h-48 rounded-full bg-amber-500/10 blur-[60px] pointer-events-none" />
        
        {/* Left Content */}
        <div className="relative z-10 max-w-[62%] flex flex-col items-start text-left space-y-0.5 md:space-y-1">
          <div className="flex items-center gap-1">
            <h2 className="text-lg md:text-2xl font-black tracking-tight flex items-center gap-1">
              Café <span className="text-base animate-float">☕</span>
            </h2>
          </div>
          <p className="text-[10px] md:text-xs font-black text-amber-300 uppercase tracking-wider">
            Freshly brewed. Fast delivered.
          </p>
          <p className="text-[9px] md:text-[11px] text-white/60 leading-tight font-medium max-w-[200px] line-clamp-2">
            Coffee, Beverages, South Indian, Chinese & more from your favorite café.
          </p>
          
          <Link href="/cafe">
            <button className="bg-white hover:bg-zinc-100 text-[#231510] text-[9px] md:text-xs font-black px-3.5 py-1.5 rounded-full mt-2 md:mt-3 shadow-md active:scale-95 transition-all cursor-pointer">
              Order Now →
            </button>
          </Link>
        </div>

        {/* Right Content: Food Image */}
        <div className="absolute right-0 bottom-0 top-0 w-[45%] flex items-center justify-end select-none pointer-events-none">
          <div className="relative w-full h-full flex items-center justify-center">
            {/* The circular 10-min badge */}
            <div className="absolute top-2 left-0 z-20 bg-amber-500 text-white rounded-full h-8 w-8 md:h-10 md:w-10 flex flex-col items-center justify-center shadow-md border border-amber-400">
              <span className="text-[10px] md:text-xs font-black leading-none">10</span>
              <span className="text-[5px] md:text-[6px] font-bold uppercase leading-none mt-0.5">min</span>
            </div>
            
            {/* Cafe Food Image */}
            <img
              src="/cafe_banner.png"
              alt="South Indian and Chinese Cafe Specials"
              className="object-contain max-h-[110px] max-w-[110px] md:max-h-[135px] md:max-w-[135px] w-auto h-auto drop-shadow-2xl translate-x-1.5 translate-y-1.5 md:translate-x-3 md:translate-y-3"
            />
          </div>
        </div>
      </div>

      {/* Subcategory Pills below Cafe Banner */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1.5 scrollbar-hide" style={{ scrollbarWidth: 'none' }}>
        {cafeShortcuts.map((item, idx) => (
          <Link
            key={idx}
            href={item.href}
            className="flex items-center gap-1.5 bg-[#311d16] hover:bg-[#432920] border border-[#482b21] px-3.5 py-2 rounded-xl text-white text-[11px] font-black tracking-wide shrink-0 transition-colors shadow-sm active:scale-95"
          >
            <span>{item.emoji}</span>
            <span>{item.label}</span>
          </Link>
        ))}
      </div>
    </section>
  )
}
