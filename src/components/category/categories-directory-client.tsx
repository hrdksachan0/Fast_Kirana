'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Category } from '@/types'
import { 
  Search, 
  ChevronRight, 
  ShoppingBag, 
  Sparkles, 
  Leaf, 
  Zap, 
  Flame, 
  Coffee, 
  Home 
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { motion } from 'framer-motion'

interface CategoriesDirectoryClientProps {
  categories: Category[]
}

interface CategoryConfig {
  title: string
  emoji: string
  image: string
  gradient: string
  borderColor: string
  labelColor: string
  cardBg: string
  tagline: string
  tagBg: string
  tagHover: string
  badgeText: string
  badgeBg: string
  badgeIcon: any
  glowColor: string
  btnBg: string
  btnArrowColor: string
  bgEmoji: string
  subcats: { id: string; name: string; emoji: string }[]
}

export function CategoriesDirectoryClient({ categories }: CategoriesDirectoryClientProps) {
  const [searchQuery, setSearchQuery] = useState('')

  // Configurations for category details (matching mockup tags, colors, and buttons)
  const categoryConfigs: Record<string, CategoryConfig> = {
    'fruits-vegetables': {
      title: 'Fruits & Vegetables',
      emoji: '🥦',
      image: '/fruits_vegetables_category.png',
      gradient: 'from-emerald-500/10 to-emerald-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#029664] dark:text-emerald-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: '100% Farm-Fresh Organic',
      tagBg: 'bg-emerald-500/[0.03] dark:bg-emerald-950/20 text-emerald-850 dark:text-emerald-300',
      tagHover: 'hover:border-emerald-450 dark:hover:border-emerald-700 hover:bg-emerald-500/[0.08]',
      badgeText: 'Farm Direct',
      badgeBg: 'bg-[#E8F8F0] text-[#029664] dark:bg-emerald-950/40 dark:text-emerald-350',
      badgeIcon: Leaf,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(2,150,100,0.04)]',
      btnBg: 'bg-[#029664] hover:bg-[#028054]',
      btnArrowColor: 'text-[#029664]',
      bgEmoji: '🥦',
      subcats: [
        { id: 'vegetables', name: 'Vegetables', emoji: '🥦' },
        { id: 'fruits', name: 'Fresh Fruits', emoji: '🍎' },
        { id: 'herbs-seasoning', name: 'Leafy Herbs', emoji: '🌿' },
      ],
    },
    'dairy-breakfast': {
      title: 'Dairy & Breakfast',
      emoji: '🥛',
      image: '/dairy_breakfast_category.png',
      gradient: 'from-blue-500/10 to-blue-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#2563EB] dark:text-blue-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Chilled Dairy & Bread Essentials',
      tagBg: 'bg-blue-500/[0.03] dark:bg-blue-950/20 text-blue-850 dark:text-blue-300',
      tagHover: 'hover:border-blue-450 dark:hover:border-blue-700 hover:bg-blue-500/[0.08]',
      badgeText: 'Fresh Daily',
      badgeBg: 'bg-[#EEF2FF] text-[#2563EB] dark:bg-blue-950/40 dark:text-blue-355',
      badgeIcon: Sparkles,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(37,99,235,0.04)]',
      btnBg: 'bg-[#2563EB] hover:bg-[#1D4ED8]',
      btnArrowColor: 'text-[#2563EB]',
      bgEmoji: '🥛',
      subcats: [
        { id: 'milk', name: 'Milk & Curd', emoji: '🥛' },
        { id: 'cheese-butter', name: 'Cheese & Paneer', emoji: '🧀' },
        { id: 'breakfast', name: 'Breakfast', emoji: '🥣' },
      ],
    },
    'snacks-munchies': {
      title: 'Snacks & Munchies',
      emoji: '🍿',
      image: '/snacks_munchies_category.png',
      gradient: 'from-amber-500/10 to-amber-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#EA580C] dark:text-orange-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Crunchy & Sweet Treats',
      tagBg: 'bg-amber-500/[0.03] dark:bg-amber-950/20 text-amber-850 dark:text-amber-300',
      tagHover: 'hover:border-amber-450 dark:hover:border-amber-700 hover:bg-amber-500/[0.08]',
      badgeText: 'Snack Time',
      badgeBg: 'bg-[#FFF7ED] text-[#EA580C] dark:bg-amber-950/40 dark:text-amber-355',
      badgeIcon: Zap,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(234,88,12,0.04)]',
      btnBg: 'bg-[#EA580C] hover:bg-[#D97706]',
      btnArrowColor: 'text-[#EA580C]',
      bgEmoji: '🍿',
      subcats: [
        { id: 'chips', name: 'Chips & Crisps', emoji: '🍟' },
        { id: 'biscuits', name: 'Biscuits', emoji: '🍪' },
        { id: 'chocolates', name: 'Chocolates', emoji: '🍫' },
        { id: 'namkeen', name: 'Namkeen', emoji: '🥨' },
      ],
    },
    'beverages': {
      title: 'Beverages',
      emoji: '🥤',
      image: '/beverages_category.png',
      gradient: 'from-purple-500/10 to-purple-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#7C3AED] dark:text-purple-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Soft Drinks & Coolers',
      tagBg: 'bg-purple-500/[0.03] dark:bg-purple-950/20 text-purple-850 dark:text-purple-300',
      tagHover: 'hover:border-purple-450 dark:hover:border-purple-700 hover:bg-purple-500/[0.08]',
      badgeText: 'Beverages',
      badgeBg: 'bg-[#FAF5FF] text-[#7C3AED] dark:bg-purple-950/40 dark:text-purple-355',
      badgeIcon: Coffee,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(124,58,237,0.04)]',
      btnBg: 'bg-[#7C3AED] hover:bg-[#6D28D9]',
      btnArrowColor: 'text-[#7C3AED]',
      bgEmoji: '🥤',
      subcats: [
        { id: 'cold-drinks', name: 'Soft Drinks', emoji: '🥤' },
        { id: 'juices', name: 'Juices & Soda', emoji: '🧃' },
        { id: 'tea-coffee', name: 'Tea & Coffee', emoji: '☕' },
      ],
    },
    'personal-care': {
      title: 'Personal Care',
      emoji: '🧴',
      image: '/personal_care_category.png',
      gradient: 'from-pink-500/10 to-pink-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#DB2777] dark:text-pink-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Bath, Soaps & Hair Care',
      tagBg: 'bg-pink-500/[0.03] dark:bg-pink-950/20 text-pink-855 dark:text-pink-300',
      tagHover: 'hover:border-pink-450 dark:hover:border-pink-700 hover:bg-pink-500/[0.08]',
      badgeText: 'Care & Beauty',
      badgeBg: 'bg-[#FDF2F8] text-[#DB2777] dark:bg-pink-950/40 dark:text-pink-350',
      badgeIcon: Sparkles,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(219,39,119,0.04)]',
      btnBg: 'bg-[#DB2777] hover:bg-[#BE185D]',
      btnArrowColor: 'text-[#DB2777]',
      bgEmoji: '🧴',
      subcats: [
        { id: 'bath', name: 'Bath & Soap', emoji: '🧼' },
        { id: 'hair', name: 'Hair Care', emoji: '💇' },
        { id: 'skin', name: 'Skin Care', emoji: '🧴' },
      ],
    },
    'household': {
      title: 'Household Needs',
      emoji: '🧼',
      image: '/household_category.png',
      gradient: 'from-teal-500/10 to-teal-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#0D9488] dark:text-teal-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Cleaning & Detergents',
      tagBg: 'bg-teal-500/[0.03] dark:bg-teal-950/20 text-teal-855 dark:text-teal-300',
      tagHover: 'hover:border-teal-450 dark:hover:border-teal-700 hover:bg-teal-500/[0.08]',
      badgeText: 'Household',
      badgeBg: 'bg-[#F0FDFA] text-[#0D9488] dark:bg-teal-950/40 dark:text-teal-350',
      badgeIcon: Home,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(13,148,136,0.04)]',
      btnBg: 'bg-[#0D9488] hover:bg-[#0F766E]',
      btnArrowColor: 'text-[#0D9488]',
      bgEmoji: '🧼',
      subcats: [
        { id: 'cleaners', name: 'Cleaners', emoji: '🧹' },
        { id: 'repellents', name: 'Repellents', emoji: '🦟' },
        { id: 'detergents', name: 'Detergents', emoji: '🧼' },
      ],
    },
    'bakery-biscuits': {
      title: 'Bakery & Bread',
      emoji: '🥐',
      image: '/bakery_biscuits_category.png',
      gradient: 'from-orange-500/10 to-orange-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#EA580C] dark:text-orange-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Fresh Bread, Cakes & Rusks',
      tagBg: 'bg-orange-500/[0.03] dark:bg-orange-950/20 text-orange-855 dark:text-orange-305',
      tagHover: 'hover:border-orange-455 dark:hover:border-orange-700 hover:bg-orange-500/[0.08]',
      badgeText: 'Oven Fresh',
      badgeBg: 'bg-[#FFF7ED] text-[#EA580C] dark:bg-orange-950/40 dark:text-orange-355',
      badgeIcon: Flame,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(234,88,12,0.04)]',
      btnBg: 'bg-[#EA580C] hover:bg-[#C2410C]',
      btnArrowColor: 'text-[#EA580C]',
      bgEmoji: '🥐',
      subcats: [
        { id: 'bread', name: 'Fresh Bread', emoji: '🍞' },
        { id: 'cookies', name: 'Cookies', emoji: '🍪' },
      ],
    },
    'atta-rice-dal': {
      title: 'Atta, Rice & Dal',
      emoji: '🌾',
      image: '/atta_rice_dal_category.png',
      gradient: 'from-yellow-500/10 to-yellow-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#B45309] dark:text-yellow-450',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Premium Dals & Atta Grains',
      tagBg: 'bg-yellow-500/[0.03] dark:bg-yellow-950/20 text-yellow-850 dark:text-yellow-300',
      tagHover: 'hover:border-yellow-450 dark:hover:border-yellow-700 hover:bg-yellow-500/[0.08]',
      badgeText: 'Pantry Staples',
      badgeBg: 'bg-[#FEF9C3] text-[#B45309] dark:bg-yellow-950/40 dark:text-yellow-355',
      badgeIcon: ShoppingBag,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(180,83,9,0.04)]',
      btnBg: 'bg-[#B45309] hover:bg-[#9A3412]',
      btnArrowColor: 'text-[#B45309]',
      bgEmoji: '🌾',
      subcats: [
        { id: 'atta-flours', name: 'Atta Flours', emoji: '🌾' },
        { id: 'rice-grains', name: 'Rice Grains', emoji: '🍚' },
        { id: 'pulses-dals', name: 'Dals & Pulses', emoji: '🍛' },
      ],
    },
    'ice-cream': {
      title: 'Ice Cream & Desserts',
      emoji: '🍦',
      image: '/ice_cream_category.png',
      gradient: 'from-sky-500/10 to-sky-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#0284C7] dark:text-sky-400',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Sweet Frozen Treats & Cups',
      tagBg: 'bg-sky-500/[0.03] dark:bg-sky-950/20 text-sky-855 dark:text-sky-305',
      tagHover: 'hover:border-sky-400 dark:hover:border-sky-700 hover:bg-sky-500/[0.08]',
      badgeText: 'Frozen Delights',
      badgeBg: 'bg-[#F0F9FF] text-[#0284C7] dark:bg-sky-950/40 dark:text-sky-350',
      badgeIcon: Sparkles,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(2,132,199,0.04)]',
      btnBg: 'bg-[#0284C7] hover:bg-[#0369A1]',
      btnArrowColor: 'text-[#0284C7]',
      bgEmoji: '🍦',
      subcats: [
        { id: 'cones', name: 'Cones & Bars', emoji: '🍦' },
        { id: 'tubs', name: 'Family Tubs', emoji: '🍨' },
      ],
    },
    'cafe': {
      title: 'FastKirana Café',
      emoji: '☕',
      image: '/cafe_category.png',
      gradient: 'from-amber-500/10 to-amber-500/5',
      borderColor: 'border-zinc-150 dark:border-zinc-800/40',
      labelColor: 'text-[#D97706] dark:text-amber-250',
      cardBg: 'bg-white dark:bg-zinc-950',
      tagline: 'Freshly Prepared Hot Meals',
      tagBg: 'bg-amber-500/[0.03] dark:bg-amber-950/20 text-amber-850 dark:text-amber-300',
      tagHover: 'hover:border-amber-400 dark:hover:border-amber-700 hover:bg-amber-500/[0.08]',
      badgeText: 'Hot Cafe',
      badgeBg: 'bg-[#FFFBEB] text-[#D97706] dark:bg-amber-950/40 dark:text-amber-305',
      badgeIcon: Coffee,
      glowColor: 'hover:shadow-[0_12px_24px_rgba(217,119,6,0.04)]',
      btnBg: 'bg-[#D97706] hover:bg-[#B45309]',
      btnArrowColor: 'text-[#D97706]',
      bgEmoji: '☕',
      subcats: [
        { id: 'hot-beverage', name: 'Brews', emoji: '☕' },
        { id: 'hot-bite', name: 'Snacks', emoji: '🥟' },
        { id: 'sandwiches', name: 'Sandwiches', emoji: '🥪' },
      ],
    },
  }

  // Filter categories matching search input
  const filteredCategories = useMemo(() => {
    if (!searchQuery) return categories

    const lowerQuery = searchQuery.toLowerCase()
    return categories.filter((c) => {
      const config = categoryConfigs[c.slug]
      const nameMatch = c.name.toLowerCase().includes(lowerQuery)
      const subcatsMatch = config?.subcats.some((sub) =>
        sub.name.toLowerCase().includes(lowerQuery)
      )
      return nameMatch || subcatsMatch
    })
  }, [categories, searchQuery, categoryConfigs])

  return (
    <div className="space-y-6">
      {/* Header and Search Bar (matching screenshot layout) */}
      <div className="flex items-center justify-between gap-4 py-2 px-1">
        <div className="text-left">
          {/* Breadcrumbs */}
          <nav className="flex items-center gap-1.5 text-[9px] font-black text-zinc-400 dark:text-zinc-500 uppercase tracking-widest select-none bg-zinc-50 dark:bg-zinc-900/30 px-3 py-1.5 rounded-full w-fit border border-zinc-150/40 dark:border-zinc-800/20 mb-4">
            <Link href="/" className="hover:text-primary transition-colors">
              Home
            </Link>
            <ChevronRight size={10} className="text-zinc-300 dark:text-zinc-700" />
            <span className="text-[#FF2E55] font-extrabold">Categories Directory</span>
          </nav>

          <h1 className="text-3xl md:text-4xl font-extrabold text-zinc-900 dark:text-zinc-100 tracking-tight flex items-center">
            <span className="h-7 w-1.5 rounded-full bg-[#FF2E55] mr-3 inline-block shrink-0" />
            Shop by Category
          </h1>
          <p className="text-xs sm:text-sm text-zinc-500 dark:text-zinc-400 font-semibold mt-2 pl-4 max-w-md">
            Explore our curated catalog of groceries and hot café treats
          </p>
        </div>
        
        {/* Shopping Bag Image Banner */}
        <div className="relative w-28 h-28 sm:w-32 sm:h-32 shrink-0 select-none pointer-events-none hidden min-[375px]:block">
          <Image
            src="/grocery_bag_banner.png"
            alt="Grocery Bag"
            fill
            className="object-contain"
            priority
          />
        </div>
      </div>

      {/* Full-width Search Bar Input */}
      <div className="relative w-full bg-white dark:bg-zinc-900/50 backdrop-blur-md rounded-2xl border border-zinc-250/80 dark:border-zinc-850/40 shadow-sm focus-within:ring-2 focus-within:ring-rose-500/10 focus-within:border-rose-500/30 transition-all duration-300 overflow-hidden group mb-6">
        <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-zinc-400 transition-colors group-focus-within:text-[#FF2E55]" />
        <input
          type="text"
          placeholder="Search categories..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full bg-transparent border-0 pl-12 pr-4 py-4 text-xs sm:text-sm font-semibold text-zinc-800 dark:text-zinc-200 focus:outline-none focus:ring-0"
        />
      </div>

      {/* Categories Grid (without Promo Banner to match screenshot) */}
      {filteredCategories.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 border border-dashed border-border bg-card rounded-2xl text-center p-6 shadow-sm select-none">
          <ShoppingBag className="h-8 w-8 text-muted-foreground/60 mb-3 animate-pulse-gentle" />
          <h3 className="text-sm font-bold text-text-primary">No categories found</h3>
          <p className="text-xs text-text-secondary mt-0.5">
            Try searching for other words like "snacks" or "milk"!
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6 px-1 pb-20">
          {filteredCategories.map((c) => {
            const config = categoryConfigs[c.slug] || {
              title: c.name,
              emoji: '🛒',
              image: c.imageUrl || '/fruits_vegetables_category.png',
              gradient: 'from-zinc-500/10 to-zinc-500/5',
              borderColor: 'border-zinc-200/60 dark:border-zinc-900/20',
              labelColor: 'text-zinc-700 dark:text-zinc-355 font-extrabold',
              cardBg: 'bg-white dark:bg-zinc-950',
              tagline: 'Essential Products',
              tagBg: 'bg-zinc-50 dark:bg-zinc-900 text-text-secondary',
              tagHover: 'hover:border-zinc-300 dark:hover:border-zinc-800 hover:bg-zinc-50/20',
              badgeText: 'Curated',
              badgeBg: 'bg-zinc-100 text-zinc-755 dark:bg-zinc-850 dark:text-zinc-350 border border-zinc-200/30',
              badgeIcon: Sparkles,
              glowColor: 'hover:shadow-md hover:border-zinc-350',
              btnBg: 'bg-primary hover:bg-primary/95 text-white',
              btnArrowColor: 'text-primary',
              bgEmoji: '🛒',
              subcats: [],
            }
            const itemCount = c._count?.products ?? 0
            const isCafe = c.slug === 'cafe'
            const destinationHref = isCafe ? '/cafe' : `/category/${c.slug}`

            return (
              <motion.div
                key={c.id}
                whileHover={{ 
                  y: -6, 
                  scale: 1.015,
                  transition: { type: 'spring', stiffness: 300, damping: 20 }
                }}
                whileTap={{ scale: 0.985 }}
                className="group relative flex flex-col justify-between overflow-hidden rounded-[32px] border p-4 sm:p-5 transition-all duration-300 bg-white dark:bg-zinc-950 border-zinc-150 dark:border-zinc-800/80 shadow-sm shadow-zinc-100/40 dark:shadow-none"
              >
                {/* Large floating decorative emoji in background */}
                <div className="absolute -right-4 -bottom-6 text-7xl select-none opacity-[0.06] dark:opacity-[0.03] rotate-12 transition-transform duration-700 group-hover:scale-130 group-hover:-rotate-12 pointer-events-none font-sans filter blur-[0.5px]">
                  {config.bgEmoji || '🛒'}
                </div>

                <div className="flex flex-col space-y-4 relative z-10 w-full">
                  {/* Image Section inside Light Container */}
                  <Link
                    href={destinationHref}
                    className="relative w-full aspect-square sm:aspect-[4/3] rounded-2xl overflow-hidden block border border-zinc-100 dark:border-zinc-900 bg-[#F8FAFC] dark:bg-zinc-900/40"
                  >
                    {/* Floating Badge in Top Left */}
                    <div className="absolute top-2.5 left-2.5 z-20">
                      {itemCount > 0 ? (
                        <span className="inline-flex items-center gap-1 bg-white/95 dark:bg-zinc-950/95 text-[#FF2E55] font-extrabold text-[8.5px] sm:text-[9.5px] px-2.5 py-1 rounded-full uppercase tracking-wider shadow-sm border border-black/5">
                          <ShoppingBag size={9} strokeWidth={3} />
                          {itemCount} Items
                        </span>
                      ) : (
                        <span className={cn(
                          "inline-flex items-center gap-1.5 font-bold text-[8.5px] sm:text-[9.5px] px-3 py-1 rounded-full uppercase tracking-wide", 
                          config.badgeBg
                        )}>
                          {config.badgeIcon && <config.badgeIcon className="h-3 w-3 shrink-0" />}
                          {config.badgeText}
                        </span>
                      )}
                    </div>

                    {config.image ? (
                      <Image
                        src={config.image}
                        alt={c.name}
                        fill
                        sizes="(max-width: 640px) 150px, 250px"
                        className="object-cover transition-transform duration-700 ease-out group-hover:scale-105"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <span className="text-5xl select-none filter drop-shadow-[0_6px_10px_rgba(0,0,0,0.18)] transition-transform duration-500 group-hover:scale-110 group-hover:rotate-6">
                          {config.emoji}
                        </span>
                      </div>
                    )}
                  </Link>

                  {/* Title & Tagline info */}
                  <div className="flex flex-col text-left min-w-0 px-1">
                    <h2 className={cn('text-lg sm:text-xl font-bold tracking-tight leading-tight truncate', config.labelColor)}>
                      {c.name}
                    </h2>
                    <span className="text-xs sm:text-sm text-zinc-500 dark:text-zinc-400 font-medium truncate leading-none mt-1.5">
                      {config.tagline}
                    </span>
                  </div>

                  {/* Custom Shop Now Button */}
                  <div className="w-full">
                    <Link
                      href={destinationHref}
                      className={cn(
                        'flex items-center justify-between text-[11px] sm:text-xs font-bold px-4 py-3 rounded-2xl transition-all duration-300 uppercase w-full text-white cursor-pointer active:scale-95 select-none border border-white/5',
                        config.btnBg
                      )}
                    >
                      <span className="flex-grow text-center pl-7 tracking-wider font-extrabold">SHOP NOW</span>
                      <span className="w-7 h-7 rounded-full bg-white flex items-center justify-center shrink-0 shadow-sm">
                        <ChevronRight size={14} className={cn("stroke-[3.5]", config.btnArrowColor)} />
                      </span>
                    </Link>
                  </div>
                </div>
              </motion.div>
            )
          })}
        </div>
      )}
    </div>
  )
}
