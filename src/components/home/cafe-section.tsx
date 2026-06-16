'use client'

import Link from 'next/link'
import { Zap } from 'lucide-react'

export function CafeSection() {
  const categories = [
    { tag: 'all', title: 'All Menu', emoji: '🍽️' },
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
    <section className="space-y-3">
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

      {/* Café Menu Categories Horizontal Scrollbar */}
      <div className="flex gap-2.5 overflow-x-auto pb-1 scrollbar-none px-1 select-none snap-x snap-mandatory scroll-smooth">
        {categories.map((cat) => {
          const href = cat.tag === 'all' ? '/cafe' : `/cafe?section=${cat.tag}`
          return (
            <Link
              key={cat.tag}
              href={href}
              className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-black bg-[#faf6f0] dark:bg-[#1c120e] text-[#5d4037] dark:text-amber-200 border border-[#eddcd2]/50 dark:border-amber-950/20 hover:bg-[#eddcd2]/20 dark:hover:bg-[#2e1c15] transition-all shrink-0 whitespace-nowrap active:scale-95 shadow-sm snap-start"
            >
              <span>{cat.emoji}</span>
              <span>{cat.title}</span>
            </Link>
          )
        })}
      </div>
    </section>
  )
}
