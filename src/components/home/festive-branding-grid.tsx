'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Sparkles, ArrowRight, Flame, Gift, Clock, Tag } from 'lucide-react'
import { motion } from 'framer-motion'

interface FestiveCard {
  id: string
  title: string
  subtitle: string
  badgeText?: string
  gradient: string
  imageUrl?: string | null
  linkUrl: string
  categorySlug?: string
  icon?: string
}

// Default Blinkit & Zepto inspired high-converting festival & deal cards
const DEFAULT_FESTIVE_CARDS: FestiveCard[] = [
  {
    id: 'f1',
    title: 'Festival Sweets & Dry Fruits 🪔',
    subtitle: 'Kaju Katli, Gulab Jamun & Almond Gift Boxes',
    badgeText: 'FLAT ₹150 OFF',
    gradient: 'from-amber-600 via-orange-500 to-yellow-500',
    linkUrl: '/search?q=sweets',
    icon: '🪔',
  },
  {
    id: 'f2',
    title: 'Cold Drinks & Ice Creams 🍦',
    subtitle: 'Amul, Kwality Walls, Coke, Pepsi & Juices',
    badgeText: 'UP TO 40% OFF',
    gradient: 'from-cyan-600 via-blue-600 to-indigo-600',
    linkUrl: '/category/beverages',
    icon: '🥤',
  },
  {
    id: 'f3',
    title: 'Midnight Munchies 🌙',
    subtitle: 'Chips, Instant Noodles, Chocolates & Biscuits',
    badgeText: 'UNDER ₹49 DEALS',
    gradient: 'from-purple-700 via-indigo-700 to-slate-900',
    linkUrl: '/category/snacks-munchies',
    icon: '🍿',
  },
  {
    id: 'f4',
    title: 'Fresh Farm Produce 🥬',
    subtitle: '100% Organic Vegetables & Handpicked Fruits',
    badgeText: 'DAILY FRESH BAZAAR',
    gradient: 'from-emerald-600 via-teal-600 to-green-500',
    linkUrl: '/category/fruits-vegetables',
    icon: '🍇',
  },
]

export function FestiveBrandingGrid() {
  const [cards, setCards] = useState<FestiveCard[]>(DEFAULT_FESTIVE_CARDS)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    async function loadBanners() {
      try {
        const res = await fetch('/api/banners?type=festive')
        if (res.ok) {
          const data = await res.json()
          if (Array.isArray(data) && data.length > 0) {
            const mapped: FestiveCard[] = data.map((b: any) => ({
              id: b.id,
              title: b.title,
              subtitle: b.description || 'Special Festival Deals',
              badgeText: b.code ? `CODE: ${b.code}` : 'SPECIAL OFFER',
              gradient: b.gradient || 'from-primary via-rose-500 to-orange-400',
              imageUrl: b.imageUrl,
              linkUrl: b.linkUrl || '/search?q=deals',
            }))
            setCards(mapped)
          }
        }
      } catch (err) {
        console.error('Failed to load festive banners:', err)
      }
    }

    loadBanners()
  }, [])

  return (
    <div className="w-full space-y-3.5 my-4">
      {/* Header */}
      <div className="flex items-center justify-between px-1">
        <div className="flex items-center gap-2">
          <div className="h-7 w-7 rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400 flex items-center justify-center font-black text-xs border border-rose-500/20">
            <Sparkles className="h-3.5 w-3.5 fill-rose-500" />
          </div>
          <div>
            <h2 className="text-sm min-[375px]:text-base font-black text-text-primary tracking-tight flex items-center gap-1.5">
              <span>Festival Specials & Quick Deals</span>
              <span className="text-[10px] font-black uppercase tracking-wider bg-rose-500 text-white px-2 py-0.5 rounded-full shadow-xs">
                HOT 🔥
              </span>
            </h2>
          </div>
        </div>
      </div>

      {/* Zepto/Blinkit Style Festive Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
        {cards.map((card, idx) => (
          <motion.div
            key={card.id || idx}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.25, delay: idx * 0.05 }}
          >
            <Link
              href={card.linkUrl}
              className="group relative block rounded-3xl overflow-hidden p-4 sm:p-5 text-white shadow-md hover:shadow-xl transition-all duration-300 active:scale-[0.98] border border-white/10"
            >
              {/* Background Gradient */}
              <div
                className={`absolute inset-0 bg-gradient-to-br ${card.gradient} transition-transform duration-500 group-hover:scale-105`}
              />

              {/* Ambient Glow Mesh overlay */}
              <div className="absolute -top-12 -right-12 w-32 h-32 bg-white/20 rounded-full blur-2xl pointer-events-none" />

              {/* Content Layout */}
              <div className="relative z-10 flex flex-col justify-between h-full min-h-[120px] space-y-3">
                <div className="space-y-1.5">
                  {/* Badge */}
                  {card.badgeText && (
                    <span className="inline-flex items-center gap-1 bg-black/30 backdrop-blur-md text-white text-[9px] font-black uppercase tracking-wider px-2.5 py-0.5 rounded-full border border-white/20 shadow-xs">
                      <Tag className="h-2.5 w-2.5 text-yellow-300" />
                      {card.badgeText}
                    </span>
                  )}

                  <h3 className="text-base min-[375px]:text-lg font-black tracking-tight leading-snug drop-shadow-sm group-hover:translate-x-0.5 transition-transform">
                    {card.title}
                  </h3>
                  
                  <p className="text-xs font-semibold text-white/90 line-clamp-2 leading-relaxed">
                    {card.subtitle}
                  </p>
                </div>

                {/* Bottom CTA Bar */}
                <div className="flex items-center justify-between pt-2 border-t border-white/20">
                  <span className="text-xs font-black tracking-wide text-white group-hover:underline flex items-center gap-1">
                    Explore Deals
                  </span>
                  <div className="h-7 w-7 rounded-full bg-white text-black flex items-center justify-center shadow-md group-hover:scale-110 transition-transform">
                    <ArrowRight className="h-3.5 w-3.5" />
                  </div>
                </div>
              </div>

              {/* Custom Graphic Banner Image if present */}
              {card.imageUrl && (
                <div className="absolute right-2 bottom-2 w-24 h-24 pointer-events-none opacity-85 group-hover:opacity-100 group-hover:scale-110 transition-all">
                  <img src={card.imageUrl} alt="" className="w-full h-full object-contain" />
                </div>
              )}
            </Link>
          </motion.div>
        ))}
      </div>
    </div>
  )
}
