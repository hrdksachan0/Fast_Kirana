'use client'

import Link from 'next/link'
import Image from 'next/image'
import { Category } from '@/types'
import { Salad, Milk, Cookie, CupSoda, Sparkles, Home, Croissant, Wheat, ShoppingBag, IceCream } from 'lucide-react'
import { motion } from 'framer-motion'

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
  'ice-cream': IceCream,
}

const categoryPhotos: Record<string, string> = {
  'fruits-vegetables': '/fruits_vegetables_category.png',
  'dairy-breakfast': '/dairy_breakfast_category.png',
  'snacks-munchies': '/snacks_munchies_category.png',
  'beverages': '/beverages_category.png',
  'personal-care': '/personal_care_category.png',
  'household': '/household_category.png',
  'bakery-biscuits': '/bakery_biscuits_category.png',
  'atta-rice-dal': '/atta_rice_dal_category.png',
  'ice-cream': '/ice_cream_category.png',
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
    'ice-cream': { 
      bg: 'bg-teal-50 dark:bg-teal-500/5', 
      text: 'text-teal-500 dark:text-teal-400', 
      gradient: 'from-teal-100/30 to-teal-50/10 dark:from-teal-500/10 dark:to-transparent', 
      ring: 'group-hover:border-teal-500/50 group-hover:shadow-[0_0_15px_rgba(20,184,166,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(20,184,166,0.5)]' 
    },
  }

  const mobileColorMap: Record<string, { bg: string; text: string; label: string; emoji: string }> = {
    'fruits-vegetables': { bg: 'bg-[#ecf7ed] dark:bg-emerald-950/20', text: 'text-[#2e7d32]', label: 'Fruits & Veg', emoji: '🥦' },
    'dairy-breakfast': { bg: 'bg-[#e8f4fd] dark:bg-blue-950/20', text: 'text-[#1976d2]', label: 'Milk & Dairy', emoji: '🥛' },
    'snacks-munchies': { bg: 'bg-[#fff8e1] dark:bg-amber-950/20', text: 'text-[#f57f17]', label: 'Snacks', emoji: '🍿' },
    'beverages': { bg: 'bg-[#eef2f6] dark:bg-slate-900/40', text: 'text-[#37474f]', label: 'Beverages', emoji: '🥤' },
    'personal-care': { bg: 'bg-[#fce4ec] dark:bg-pink-950/20', text: 'text-[#c2185b]', label: 'Personal Care', emoji: '🧴' },
    'household': { bg: 'bg-[#e0f7fa] dark:bg-teal-950/20', text: 'text-[#00838f]', label: 'Home Care', emoji: '🧼' },
    'bakery-biscuits': { bg: 'bg-[#efebe9] dark:bg-amber-950/10', text: 'text-[#4e342e]', label: 'Bakery', emoji: '🥐' },
    'atta-rice-dal': { bg: 'bg-[#fffde7] dark:bg-yellow-950/20', text: 'text-[#fbc02d]', label: 'Staples', emoji: '🌾' },
    'ice-cream': { bg: 'bg-[#e0f2f1] dark:bg-teal-950/20', text: 'text-[#00796b]', label: 'Ice Cream', emoji: '🍦' },
  }

  return (
    <section className="py-2 md:py-6">
      {/* Mobile Header: Shop by Categories + See all */}
      <div className="flex items-center justify-between mb-2.5 md:hidden px-1">
        <h2 className="text-base font-black text-zinc-900 dark:text-zinc-100 tracking-tight">
          Trending Categories
        </h2>
        <Link href="/category/fruits-vegetables" className="text-xs font-black text-primary hover:opacity-85">
          See all
        </Link>
      </div>

      {/* Mobile: Horizontal scrollable/sliding list */}
      <div className="flex gap-4.5 overflow-x-auto pb-3.5 pt-1.5 scrollbar-none md:hidden px-2 snap-x snap-mandatory scroll-smooth">
        {categories
          .filter((c) => c.slug !== 'cafe')
          .map((category) => {
            const config = mobileColorMap[category.slug] || {
              bg: 'bg-zinc-50 dark:bg-white/5',
              text: 'text-zinc-700 dark:text-zinc-300',
              label: category.name,
              emoji: '🛒'
            }

            return (
              <motion.div
                key={category.id}
                whileTap={{ scale: 0.93, rotate: -1.5 }}
                className="w-[70px] shrink-0 snap-start"
              >
                <Link
                  href={`/category/${category.slug}`}
                  className="group flex flex-col items-center text-center cursor-pointer"
                >
                  {/* Pastel Rounded Card with Real Photo or 3D Glassmorphic Emoji */}
                  <div
                    className={`w-[66px] h-[66px] mx-auto rounded-full ${config.bg} overflow-hidden shadow-[0_3px_10px_rgba(0,0,0,0.03)] transition-all duration-300 border border-transparent dark:border-white/[0.02] relative`}
                  >
                    {category.imageUrl && (category.imageUrl.startsWith('data:image/') || category.imageUrl.startsWith('/') || category.imageUrl.startsWith('http')) ? (
                      <Image
                        src={category.imageUrl}
                        alt={config.label}
                        fill
                        sizes="100px"
                        className="object-cover transition-transform duration-500 group-hover:scale-110"
                      />
                    ) : categoryPhotos[category.slug] ? (
                      <Image
                        src={categoryPhotos[category.slug]}
                        alt={config.label}
                        fill
                        sizes="100px"
                        className="object-cover transition-transform duration-500 group-hover:scale-110"
                      />
                    ) : category.imageUrl && category.imageUrl.length < 5 ? (
                      <div className="w-full h-full flex items-center justify-center bg-white/40 dark:bg-black/35 backdrop-blur-md shadow-[inset_0_1.5px_3px_rgba(255,255,255,0.45)] border border-white/20 dark:border-white/[0.06] rounded-full">
                        <span className="text-3xl select-none filter drop-shadow-[0_4px_6px_rgba(0,0,0,0.15)] transition-transform duration-300 group-hover:scale-110 group-hover:rotate-6">
                          {category.imageUrl}
                        </span>
                      </div>
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-white/40 dark:bg-black/35 backdrop-blur-md shadow-[inset_0_1.5px_3px_rgba(255,255,255,0.45)] border border-white/20 dark:border-white/[0.06] rounded-full">
                        <span className="text-3xl select-none filter drop-shadow-[0_4px_6px_rgba(0,0,0,0.15)] transition-transform duration-300 group-hover:scale-110 group-hover:rotate-6">
                          {config.emoji}
                        </span>
                      </div>
                    )}
                  </div>
                  {/* Category Label */}
                  <span className="text-[10px] font-black text-zinc-800 dark:text-zinc-200 mt-2 leading-tight tracking-tight line-clamp-1">
                    {config.label}
                  </span>
                </Link>
              </motion.div>
            )
          })}
      </div>

      {/* Desktop Header */}
      <h2 className="hidden md:flex text-lg md:text-2xl font-black text-text-primary tracking-tight mb-4 px-1 items-center gap-2">
        <span className="h-5 w-1.5 rounded-full bg-primary animate-pulse-gentle" />
        Trending Categories
      </h2>

      {/* Desktop: Grid layout (8 columns) */}
      <div className="hidden md:grid grid-cols-8 gap-4 stagger-children">
        {categories
          .filter((category) => category.slug !== 'cafe')
          .map((category) => {
            const colors = colorMap[category.slug] || {
              bg: 'bg-zinc-50 dark:bg-white/5',
              text: 'text-zinc-500 dark:text-zinc-400',
              gradient: 'from-zinc-100/30 to-zinc-50/10',
              ring: 'group-hover:border-zinc-500/50',
            }
            const itemCount = category._count?.products ?? 0
            const IconComponent = iconMap[category.slug] || ShoppingBag

            return (
              <motion.div
                key={category.id}
                whileHover={{ 
                  scale: 1.05, 
                  rotate: 1.5,
                  transition: { type: 'spring', stiffness: 300, damping: 15 } 
                }}
                whileTap={{ scale: 0.95 }}
                className="p-3 rounded-2xl transition-all duration-300 hover:shadow-card hover:-translate-y-1 group"
              >
                <Link
                  href={`/category/${category.slug}`}
                  className="flex flex-col items-center text-center"
                >
                  <div
                    className={`flex items-center justify-center w-16 h-16 rounded-2xl ${colors.bg} border border-white/20 dark:border-white/[0.05] backdrop-blur-md mb-2 shadow-sm transition-all duration-300 group-hover:shadow-lg ${colors.ring} overflow-hidden relative`}
                  >
                    {category.imageUrl && (category.imageUrl.startsWith('data:image/') || category.imageUrl.startsWith('/') || category.imageUrl.startsWith('http')) ? (
                      <Image
                        src={category.imageUrl}
                        alt={category.name}
                        fill
                        sizes="80px"
                        className="object-cover transition-transform duration-300 group-hover:scale-110"
                      />
                    ) : categoryPhotos[category.slug] ? (
                      <Image
                        src={categoryPhotos[category.slug]}
                        alt={category.name}
                        fill
                        sizes="80px"
                        className="object-cover transition-transform duration-300 group-hover:scale-110"
                      />
                    ) : category.imageUrl && category.imageUrl.length < 5 ? (
                      <div className="w-full h-full flex items-center justify-center bg-white/40 dark:bg-black/35 backdrop-blur-md shadow-[inset_0_1.5px_3px_rgba(255,255,255,0.45)] border border-white/20 dark:border-white/[0.06] rounded-2xl">
                        <span className="text-3xl transition-transform duration-300 group-hover:scale-110 group-hover:rotate-12 select-none filter drop-shadow-[0_4px_6px_rgba(0,0,0,0.15)]">{category.imageUrl}</span>
                      </div>
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-white/40 dark:bg-black/35 backdrop-blur-md shadow-[inset_0_1.5px_3px_rgba(255,255,255,0.45)] border border-white/20 dark:border-white/[0.06] rounded-2xl">
                        <IconComponent className={`h-7 w-7 ${colors.text} transition-all duration-300 group-hover:scale-110 group-hover:rotate-12`} />
                      </div>
                    )}
                  </div>
                  <span className="text-xs font-bold text-text-primary group-hover:text-primary transition-colors leading-tight line-clamp-2">
                    {category.name}
                  </span>
                  <span className="text-[10px] text-text-muted mt-0.5">
                    {itemCount} items
                  </span>
                </Link>
              </motion.div>
            )
          })}
      </div>
    </section>
  )
}
