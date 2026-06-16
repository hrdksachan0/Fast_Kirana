'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Category } from '@/types'
import { Search, ChevronRight, ShoppingBag, Sparkles } from 'lucide-react'
import { cn } from '@/lib/utils'

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
  glowColor: string
  btnBg: string
  bgEmoji: string
  subcats: { id: string; name: string; emoji: string }[]
}

export function CategoriesDirectoryClient({ categories }: CategoriesDirectoryClientProps) {
  const [searchQuery, setSearchQuery] = useState('')

  // Configurations for category details (gradients, subcategories, images)
  const categoryConfigs: Record<string, CategoryConfig> = {
    'fruits-vegetables': {
      title: 'Fruits & Vegetables',
      emoji: '🥦',
      image: '/fruits_vegetables_category.png',
      gradient: 'from-emerald-500/20 to-teal-500/10 dark:from-emerald-950/40 dark:to-teal-950/20',
      borderColor: 'border-emerald-100/80 dark:border-emerald-900/30',
      labelColor: 'text-emerald-800 dark:text-emerald-300 font-black',
      cardBg: 'bg-gradient-to-br from-emerald-500/[0.03] via-card to-emerald-500/[0.01] dark:from-emerald-950/[0.08] dark:via-zinc-950 dark:to-emerald-950/[0.02]',
      tagline: '100% Farm-Fresh Organics',
      tagBg: 'bg-emerald-500/[0.03] dark:bg-emerald-950/20 border-emerald-500/10 dark:border-emerald-900/20 text-emerald-800 dark:text-emerald-300',
      tagHover: 'hover:border-emerald-400 dark:hover:border-emerald-700 hover:text-emerald-600 dark:hover:text-emerald-200 hover:bg-emerald-500/[0.08]',
      badgeText: 'Farm Direct',
      badgeBg: 'bg-emerald-500/10 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-350 border border-emerald-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(16,185,129,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(16,185,129,0.04)] hover:border-emerald-500/30',
      btnBg: 'bg-emerald-600 hover:bg-emerald-700 dark:bg-emerald-500 dark:hover:bg-emerald-600 text-white shadow-emerald-500/10',
      bgEmoji: '🥦',
      subcats: [
        { id: 'vegetables', name: 'Vegetables', emoji: '🥦' },
        { id: 'fruits', name: 'Fresh Fruits', emoji: '🍎' },
        { id: 'herbs-seasoning', name: 'Leafy Herbs', emoji: '🌿' },
      ],
    },
    'dairy-breakfast': {
      title: 'Dairy, Bread & Eggs',
      emoji: '🥛',
      image: '/dairy_breakfast_category.png',
      gradient: 'from-blue-500/20 to-sky-500/10 dark:from-blue-950/40 dark:to-sky-950/20',
      borderColor: 'border-blue-100/80 dark:border-blue-900/30',
      labelColor: 'text-blue-800 dark:text-blue-300 font-black',
      cardBg: 'bg-gradient-to-br from-blue-500/[0.03] via-card to-blue-500/[0.01] dark:from-blue-950/[0.08] dark:via-zinc-950 dark:to-blue-950/[0.02]',
      tagline: 'Chilled Dairy & Bread Eggs',
      tagBg: 'bg-blue-500/[0.03] dark:bg-blue-950/20 border-blue-500/10 dark:border-blue-900/20 text-blue-800 dark:text-blue-300',
      tagHover: 'hover:border-blue-400 dark:hover:border-blue-700 hover:text-blue-600 dark:hover:text-blue-200 hover:bg-blue-500/[0.08]',
      badgeText: 'Fresh Daily',
      badgeBg: 'bg-blue-500/10 text-blue-700 dark:bg-blue-500/20 dark:text-blue-350 border border-blue-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(59,130,246,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(59,130,246,0.04)] hover:border-blue-500/30',
      btnBg: 'bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 text-white shadow-blue-500/10',
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
      gradient: 'from-amber-500/20 to-orange-500/10 dark:from-amber-950/40 dark:to-orange-950/20',
      borderColor: 'border-amber-100/80 dark:border-amber-900/30',
      labelColor: 'text-amber-800 dark:text-amber-300 font-black',
      cardBg: 'bg-gradient-to-br from-amber-500/[0.03] via-card to-amber-500/[0.01] dark:from-amber-950/[0.08] dark:via-zinc-950 dark:to-amber-950/[0.02]',
      tagline: 'Chips, Biscuits & Sweets',
      tagBg: 'bg-amber-500/[0.03] dark:bg-amber-950/20 border-amber-500/10 dark:border-amber-900/20 text-amber-800 dark:text-amber-300',
      tagHover: 'hover:border-amber-400 dark:hover:border-amber-700 hover:text-amber-600 dark:hover:text-amber-200 hover:bg-amber-500/[0.08]',
      badgeText: 'Party Specials',
      badgeBg: 'bg-amber-500/10 text-amber-700 dark:bg-amber-500/20 dark:text-amber-350 border border-amber-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(245,158,11,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(245,158,11,0.04)] hover:border-amber-500/30',
      btnBg: 'bg-amber-600 hover:bg-amber-700 dark:bg-amber-500 dark:hover:bg-amber-600 text-white shadow-amber-500/10',
      bgEmoji: '🍿',
      subcats: [
        { id: 'chips', name: 'Chips & Crisps', emoji: '🍟' },
        { id: 'biscuits', name: 'Biscuits', emoji: '🍪' },
        { id: 'chocolates', name: 'Chocolates', emoji: '🍫' },
        { id: 'namkeen', name: 'Namkeen', emoji: '🥨' },
      ],
    },
    'beverages': {
      title: 'Cold Drinks & Juices',
      emoji: '🥤',
      image: '/beverages_category.png',
      gradient: 'from-purple-500/20 to-indigo-500/10 dark:from-purple-950/40 dark:to-indigo-950/20',
      borderColor: 'border-purple-100/80 dark:border-purple-900/30',
      labelColor: 'text-purple-800 dark:text-purple-300 font-black',
      cardBg: 'bg-gradient-to-br from-purple-500/[0.03] via-card to-purple-500/[0.01] dark:from-purple-950/[0.08] dark:via-zinc-950 dark:to-purple-950/[0.02]',
      tagline: 'Soft Drinks & Coolers',
      tagBg: 'bg-purple-500/[0.03] dark:bg-purple-950/20 border-purple-500/10 dark:border-purple-900/20 text-purple-800 dark:text-purple-300',
      tagHover: 'hover:border-purple-400 dark:hover:border-purple-700 hover:text-purple-600 dark:hover:text-purple-200 hover:bg-purple-500/[0.08]',
      badgeText: 'Chilled Drinks',
      badgeBg: 'bg-purple-500/10 text-purple-700 dark:bg-purple-500/20 dark:text-purple-355 border border-purple-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(139,92,246,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(139,92,246,0.04)] hover:border-purple-500/30',
      btnBg: 'bg-purple-600 hover:bg-purple-700 dark:bg-purple-500 dark:hover:bg-purple-600 text-white shadow-purple-500/10',
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
      gradient: 'from-pink-500/20 to-rose-500/10 dark:from-pink-950/40 dark:to-rose-950/20',
      borderColor: 'border-pink-100/80 dark:border-pink-900/30',
      labelColor: 'text-pink-800 dark:text-pink-300 font-black',
      cardBg: 'bg-gradient-to-br from-pink-500/[0.03] via-card to-pink-500/[0.01] dark:from-pink-950/[0.08] dark:via-zinc-950 dark:to-pink-950/[0.02]',
      tagline: 'Bath, Soaps & Hair Care',
      tagBg: 'bg-pink-500/[0.03] dark:bg-pink-950/20 border-pink-500/10 dark:border-pink-900/20 text-pink-800 dark:text-pink-300',
      tagHover: 'hover:border-pink-400 dark:hover:border-pink-700 hover:text-pink-600 dark:hover:text-pink-200 hover:bg-pink-500/[0.08]',
      badgeText: 'Premium Care',
      badgeBg: 'bg-pink-500/10 text-pink-700 dark:bg-pink-500/20 dark:text-pink-350 border border-pink-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(236,72,153,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(236,72,153,0.04)] hover:border-pink-500/30',
      btnBg: 'bg-pink-600 hover:bg-pink-700 dark:bg-pink-500 dark:hover:bg-pink-600 text-white shadow-pink-500/10',
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
      gradient: 'from-teal-500/20 to-cyan-500/10 dark:from-teal-950/40 dark:to-cyan-950/20',
      borderColor: 'border-teal-100/80 dark:border-teal-900/30',
      labelColor: 'text-teal-800 dark:text-teal-300 font-black',
      cardBg: 'bg-gradient-to-br from-teal-500/[0.03] via-card to-teal-500/[0.01] dark:from-teal-950/[0.08] dark:via-zinc-950 dark:to-teal-950/[0.02]',
      tagline: 'Cleaning & Detergents',
      tagBg: 'bg-teal-500/[0.03] dark:bg-teal-950/20 border-teal-500/10 dark:border-teal-900/20 text-teal-800 dark:text-teal-300',
      tagHover: 'hover:border-teal-400 dark:hover:border-teal-700 hover:text-teal-600 dark:hover:text-teal-200 hover:bg-teal-500/[0.08]',
      badgeText: 'Home Essentials',
      badgeBg: 'bg-teal-500/10 text-teal-700 dark:bg-teal-500/20 dark:text-teal-350 border border-teal-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(20,184,166,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(20,184,166,0.04)] hover:border-teal-500/30',
      btnBg: 'bg-teal-600 hover:bg-teal-700 dark:bg-teal-500 dark:hover:bg-teal-600 text-white shadow-teal-500/10',
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
      gradient: 'from-orange-500/20 to-yellow-500/10 dark:from-orange-950/40 dark:to-yellow-950/20',
      borderColor: 'border-orange-100/80 dark:border-orange-900/30',
      labelColor: 'text-orange-800 dark:text-orange-300 font-black',
      cardBg: 'bg-gradient-to-br from-orange-500/[0.03] via-card to-orange-500/[0.01] dark:from-orange-950/[0.08] dark:via-zinc-950 dark:to-orange-950/[0.02]',
      tagline: 'Fresh Bread, Cakes & Rusks',
      tagBg: 'bg-orange-500/[0.03] dark:bg-orange-950/20 border-orange-500/10 dark:border-orange-900/20 text-orange-800 dark:text-orange-300',
      tagHover: 'hover:border-orange-400 dark:hover:border-orange-700 hover:text-orange-600 dark:hover:text-orange-200 hover:bg-orange-500/[0.08]',
      badgeText: 'Oven Fresh',
      badgeBg: 'bg-orange-500/10 text-orange-700 dark:bg-orange-500/20 dark:text-orange-355 border border-orange-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(249,115,22,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(249,115,22,0.04)] hover:border-orange-500/30',
      btnBg: 'bg-orange-600 hover:bg-orange-700 dark:bg-orange-500 dark:hover:bg-orange-600 text-white shadow-orange-500/10',
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
      gradient: 'from-yellow-500/20 to-amber-500/10 dark:from-yellow-950/40 dark:to-amber-950/20',
      borderColor: 'border-yellow-100/80 dark:border-yellow-900/30',
      labelColor: 'text-yellow-800 dark:text-yellow-400 font-black',
      cardBg: 'bg-gradient-to-br from-yellow-500/[0.03] via-card to-yellow-500/[0.01] dark:from-yellow-950/[0.08] dark:via-zinc-950 dark:to-yellow-950/[0.02]',
      tagline: 'Premium Dals & Atta Grains',
      tagBg: 'bg-yellow-500/[0.03] dark:bg-yellow-950/20 border-yellow-500/10 dark:border-yellow-900/20 text-yellow-800 dark:text-yellow-300',
      tagHover: 'hover:border-yellow-450 dark:hover:border-yellow-700 hover:text-yellow-750 dark:hover:text-yellow-200 hover:bg-yellow-500/[0.08]',
      badgeText: 'Pantry Staples',
      badgeBg: 'bg-yellow-500/10 text-yellow-750 dark:bg-yellow-500/20 dark:text-yellow-355 border border-yellow-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(234,179,8,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(234,179,8,0.04)] hover:border-yellow-500/30',
      btnBg: 'bg-yellow-600 hover:bg-yellow-700 dark:bg-yellow-500 dark:hover:bg-yellow-600 text-white shadow-yellow-500/10',
      bgEmoji: '🌾',
      subcats: [
        { id: 'atta-flours', name: 'Atta Flours', emoji: '🌾' },
        { id: 'rice-grains', name: 'Rice Grains', emoji: '🍚' },
        { id: 'pulses-dals', name: 'Dals & Pulses', emoji: '🍛' },
      ],
    },
    'cafe': {
      title: 'FastKirana Café',
      emoji: '☕',
      image: '/cafe_category.png',
      gradient: 'from-amber-900/20 to-rose-900/10 dark:from-amber-950/40 dark:to-rose-950/20',
      borderColor: 'border-amber-900/20 dark:border-amber-900/30',
      labelColor: 'text-[#5d4037] dark:text-amber-200 font-black',
      cardBg: 'bg-gradient-to-br from-amber-500/[0.04] via-card to-rose-500/[0.02] dark:from-amber-950/[0.08] dark:via-zinc-950 dark:to-rose-950/[0.02]',
      tagline: 'Freshly Prepared Hot Meals',
      tagBg: 'bg-amber-500/[0.03] dark:bg-amber-950/20 border-amber-500/10 dark:border-amber-900/20 text-amber-800 dark:text-amber-300',
      tagHover: 'hover:border-amber-400 dark:hover:border-amber-700 hover:text-amber-600 dark:hover:text-amber-200 hover:bg-amber-500/[0.08]',
      badgeText: 'Hot Kitchen',
      badgeBg: 'bg-amber-500/10 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300 border border-amber-500/20',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(120,53,4,0.1)] dark:hover:shadow-[0_15px_30px_-5px_rgba(120,53,4,0.04)] hover:border-amber-500/30',
      btnBg: 'bg-amber-700 hover:bg-amber-800 dark:bg-amber-600 dark:hover:bg-amber-700 text-white shadow-amber-700/10',
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
  }, [categories, searchQuery])

  return (
    <div className="space-y-6">
      {/* Breadcrumbs */}
      <nav className="flex items-center gap-1.5 text-xs font-semibold text-text-muted uppercase tracking-wider select-none">
        <Link href="/" className="hover:text-primary transition-colors">
          Home
        </Link>
        <ChevronRight size={10} />
        <span className="text-primary font-extrabold">Categories Directory</span>
      </nav>

      {/* Header and Search Bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight flex items-center gap-1.5">
            Shop by Category
          </h1>
          <p className="text-xs text-text-secondary font-medium mt-0.5">
            Explore our curated catalog of groceries and hot café treats
          </p>
        </div>

        {/* Search Bar Input */}
        <div className="relative w-full md:max-w-xs bg-card rounded-xl border border-border/80 shadow-sm overflow-hidden group">
          <Search className="absolute left-3.5 top-3.5 h-4 w-4 text-text-muted" />
          <input
            type="text"
            placeholder="Search categories..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-transparent border-0 pl-10 pr-4 py-3 text-xs font-bold text-text-primary focus:outline-none focus:ring-0"
          />
        </div>
      </div>

      {/* Promos Banner Strip */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-red-600 via-rose-500 to-amber-500 p-5 text-white flex items-center justify-between shadow-lg select-none">
        {/* Animated Shimmer Circle Overlays for Premium look */}
        <div className="absolute -top-12 -left-12 w-32 h-32 bg-white/10 rounded-full blur-xl pointer-events-none" />
        <div className="absolute -bottom-16 -right-16 w-40 h-40 bg-white/15 rounded-full blur-2xl pointer-events-none" />
        
        <div className="flex items-center gap-4 relative z-10">
          <div className="p-2 bg-white/15 rounded-xl backdrop-blur-md border border-white/10 animate-bounce-gentle">
            <Sparkles className="h-5 w-5 text-amber-200 fill-amber-200" />
          </div>
          <div className="text-left">
            <span className="inline-block bg-white/20 text-white font-black text-[9px] px-2 py-0.5 rounded-full uppercase tracking-wider mb-1">
              Limited Time Offer
            </span>
            <h3 className="text-sm md:text-base font-black uppercase tracking-tight text-white leading-tight">
              Super Deals inside categories
            </h3>
            <p className="text-xs text-white/90 font-medium mt-0.5">
              Get flat <span className="font-extrabold text-amber-200">10% cashback</span> on snacks, dairy, and warm beverages
            </p>
          </div>
        </div>
        <div className="hidden md:flex items-center gap-1.5 bg-white text-rose-600 px-4 py-2 rounded-xl border border-white/10 text-xs font-black shrink-0 shadow-md hover:scale-105 transition-transform cursor-pointer select-none relative z-10">
          <span>Apply Coupon</span>
          <ChevronRight className="h-3 w-3 stroke-[3]" />
        </div>
      </div>

      {/* Categories Grid */}
      {filteredCategories.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 border border-dashed border-border bg-card rounded-2xl text-center p-6 shadow-sm select-none">
          <ShoppingBag className="h-8 w-8 text-muted-foreground/60 mb-3 animate-pulse-gentle" />
          <h3 className="text-sm font-bold text-text-primary">No categories found</h3>
          <p className="text-xs text-text-secondary mt-0.5">
            Try searching for other words like "snacks" or "milk"!
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5 px-1 pb-20">
          {filteredCategories.map((c) => {
            const config = categoryConfigs[c.slug] || {
              title: c.name,
              emoji: '🛒',
              image: c.imageUrl || '/fruits_vegetables_category.png',
              gradient: 'from-zinc-500/10 to-zinc-500/5 dark:from-zinc-950/20 dark:to-transparent',
              borderColor: 'border-zinc-100 dark:border-zinc-900/30',
              labelColor: 'text-zinc-700 dark:text-zinc-300 font-bold',
              cardBg: 'bg-card',
              tagline: 'Essential Products',
              tagBg: 'bg-zinc-50 dark:bg-zinc-900 border-zinc-200/60 text-text-secondary',
              tagHover: 'hover:border-zinc-300 dark:hover:border-zinc-800 hover:text-zinc-650 dark:hover:text-zinc-400 hover:bg-zinc-50/20',
              badgeText: 'Curated',
              badgeBg: 'bg-zinc-100 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300 border border-zinc-200/30',
              glowColor: 'hover:shadow-md hover:border-zinc-300 dark:hover:border-zinc-750',
              btnBg: 'bg-primary hover:bg-primary/95 text-white',
              bgEmoji: '🛒',
              subcats: [],
            }
            const itemCount = c._count?.products ?? 0
            const isCafe = c.slug === 'cafe'
            const destinationHref = isCafe ? '/cafe' : `/category/${c.slug}`

            return (
              <div
                key={c.id}
                className={cn(
                  'group relative flex flex-col justify-between overflow-hidden rounded-2xl border p-5 shadow-sm hover:-translate-y-1.5 transition-all duration-500',
                  config.borderColor,
                  config.cardBg,
                  config.glowColor
                )}
              >
                {/* Large floating decorative emoji in background */}
                <div className="absolute -right-4 -bottom-6 text-7xl select-none opacity-[0.06] dark:opacity-[0.03] rotate-12 transition-transform duration-700 group-hover:scale-125 group-hover:-rotate-12 pointer-events-none font-sans">
                  {config.bgEmoji || '🛒'}
                </div>

                {/* Top Section: Title & Visual Image */}
                <div className="flex items-start justify-between gap-3 relative z-10">
                  <div className="flex flex-col text-left space-y-1 min-w-0 flex-1">
                    {/* Badge */}
                    <div className="flex flex-wrap items-center gap-1.5 mb-1 select-none">
                      {itemCount > 0 ? (
                        <span className="inline-flex items-center gap-1 bg-primary/10 text-primary font-black text-[9px] px-2 py-0.5 rounded-full uppercase tracking-wider">
                          <ShoppingBag size={8} strokeWidth={3} />
                          {itemCount} Items
                        </span>
                      ) : (
                        <span className={cn("inline-flex items-center gap-1 font-black text-[9px] px-2 py-0.5 rounded-full uppercase tracking-wider", config.badgeBg)}>
                          <Sparkles size={8} strokeWidth={3} />
                          {config.badgeText}
                        </span>
                      )}
                    </div>

                    <h2 className={cn('text-base font-black tracking-tight leading-tight truncate', config.labelColor)}>
                      {c.name}
                    </h2>
                    <span className="text-[11px] text-text-secondary font-bold truncate leading-none">
                      {config.tagline}
                    </span>

                    {/* Shop Now Action */}
                    <div className="pt-2.5">
                      <Link
                        href={destinationHref}
                        className={cn(
                          'inline-flex items-center gap-1 text-[9.5px] font-black px-3.5 py-1.5 rounded-full shadow-sm hover:scale-[1.03] transition-all duration-300 tracking-wider uppercase',
                          config.btnBg
                        )}
                      >
                        <span>Shop Now</span>
                        <ChevronRight size={10} strokeWidth={3} className="transition-transform duration-300 group-hover:translate-x-0.5" />
                      </Link>
                    </div>
                  </div>

                  {/* Circular/Rounded Category Thumbnail Image Container */}
                  <Link
                    href={destinationHref}
                    className={cn(
                      'relative w-16 h-16 rounded-2xl overflow-hidden shadow-inner flex items-center justify-center shrink-0 border border-white/60 dark:border-zinc-800 bg-gradient-to-br transition-all duration-500 group-hover:scale-105 group-hover:shadow-md',
                      config.gradient
                    )}
                  >
                    {config.image ? (
                      <Image
                        src={config.image}
                        alt={c.name}
                        fill
                        sizes="80px"
                        className="object-cover p-1 transition-transform duration-500 group-hover:rotate-3"
                      />
                    ) : (
                      <span className="text-3xl select-none leading-none">{config.emoji}</span>
                    )}
                  </Link>
                </div>

                {/* Bottom Section: Subcategories Quick Tags */}
                {config.subcats.length > 0 && (
                  <div className="relative z-10 flex flex-col pt-4 mt-4 border-t border-dashed border-border/80">
                    <span className="text-[9px] font-black uppercase tracking-wider text-text-muted mb-2 select-none">
                      Popular Categories
                    </span>
                    <div className="flex flex-wrap gap-1.5">
                      {/* All / View All option */}
                      <Link
                        href={destinationHref}
                        className={cn(
                          'flex items-center gap-1 px-2.5 py-1.5 rounded-lg border text-[10px] font-black transition-all duration-200 active:scale-95 shadow-sm',
                          config.tagBg,
                          config.tagHover
                        )}
                      >
                        <span>🛍️</span>
                        <span>All</span>
                      </Link>
                      {config.subcats.map((sub) => {
                        const subcatHref = isCafe
                          ? `/cafe?section=${sub.id}`
                          : `/category/${c.slug}?subcat=${sub.id}`

                        return (
                          <Link
                            key={sub.id}
                            href={subcatHref}
                            className={cn(
                              'flex items-center gap-1 px-2.5 py-1.5 rounded-lg border text-[10px] font-black transition-all duration-200 active:scale-95 shadow-sm',
                              config.tagBg,
                              config.tagHover
                            )}
                          >
                            <span>{sub.emoji}</span>
                            <span>{sub.name}</span>
                          </Link>
                        )
                      })}
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
