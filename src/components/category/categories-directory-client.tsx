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
      gradient: 'from-emerald-500/10 to-teal-500/5 dark:from-emerald-950/20 dark:to-transparent',
      borderColor: 'border-emerald-100/60 dark:border-emerald-900/25',
      labelColor: 'text-emerald-700 dark:text-emerald-400',
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
      gradient: 'from-blue-500/10 to-sky-500/5 dark:from-blue-950/20 dark:to-transparent',
      borderColor: 'border-blue-100/60 dark:border-blue-900/25',
      labelColor: 'text-blue-700 dark:text-blue-400',
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
      gradient: 'from-amber-500/10 to-orange-500/5 dark:from-amber-950/20 dark:to-transparent',
      borderColor: 'border-amber-100/60 dark:border-amber-900/25',
      labelColor: 'text-amber-700 dark:text-amber-400',
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
      gradient: 'from-purple-500/10 to-indigo-500/5 dark:from-purple-950/20 dark:to-transparent',
      borderColor: 'border-purple-100/60 dark:border-purple-900/25',
      labelColor: 'text-purple-700 dark:text-purple-400',
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
      gradient: 'from-pink-500/10 to-rose-500/5 dark:from-pink-950/20 dark:to-transparent',
      borderColor: 'border-pink-100/60 dark:border-pink-900/25',
      labelColor: 'text-pink-700 dark:text-pink-400',
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
      gradient: 'from-teal-500/10 to-cyan-500/5 dark:from-teal-950/20 dark:to-transparent',
      borderColor: 'border-teal-100/60 dark:border-teal-900/25',
      labelColor: 'text-teal-700 dark:text-teal-400',
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
      gradient: 'from-orange-500/10 to-yellow-500/5 dark:from-orange-950/20 dark:to-transparent',
      borderColor: 'border-orange-100/60 dark:border-orange-900/25',
      labelColor: 'text-orange-700 dark:text-orange-400',
      subcats: [
        { id: 'bread', name: 'Fresh Bread', emoji: '🍞' },
        { id: 'cookies', name: 'Cookies', emoji: '🍪' },
      ],
    },
    'atta-rice-dal': {
      title: 'Atta, Rice & Dal',
      emoji: '🌾',
      image: '/atta_rice_dal_category.png',
      gradient: 'from-yellow-500/10 to-amber-500/5 dark:from-yellow-950/20 dark:to-transparent',
      borderColor: 'border-yellow-100/60 dark:border-yellow-900/25',
      labelColor: 'text-yellow-700 dark:text-yellow-400',
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
      gradient: 'from-amber-900/10 to-rose-900/5 dark:from-amber-950/20 dark:to-transparent',
      borderColor: 'border-amber-900/15 dark:border-amber-900/25',
      labelColor: 'text-[#5d4037] dark:text-amber-200',
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
    <div className="space-y-5">
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
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-red-600 via-rose-500 to-amber-500 p-4 text-white flex items-center justify-between shadow-md select-none">
        <div className="flex items-center gap-3">
          <span className="text-2xl animate-float">🎉</span>
          <div className="text-left">
            <h3 className="text-xs md:text-sm font-extrabold uppercase tracking-widest text-white/95">
              Super Deals inside categories
            </h3>
            <p className="text-[10px] md:text-xs text-white/80 font-bold mt-0.5">
              Get flat 10% cashbacks on snacks, dairy, and warm beverages
            </p>
          </div>
        </div>
        <div className="hidden sm:flex items-center gap-1 bg-white/20 px-3 py-1 rounded-lg border border-white/10 text-xs font-black shrink-0">
          <span>Apply Coupon</span>
          <Sparkles className="h-3 w-3" />
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
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 px-1 pb-20">
          {filteredCategories.map((c) => {
            const config = categoryConfigs[c.slug] || {
              title: c.name,
              emoji: '🛒',
              image: c.imageUrl || '/fruits_vegetables_category.png',
              gradient: 'from-zinc-500/10 to-zinc-500/5 dark:from-zinc-950/20 dark:to-transparent',
              borderColor: 'border-zinc-100 dark:border-zinc-900/30',
              labelColor: 'text-zinc-700 dark:text-zinc-400',
              subcats: [],
            }
            const itemCount = c._count?.products ?? 0
            const isCafe = c.slug === 'cafe'
            const destinationHref = isCafe ? '/cafe' : `/category/${c.slug}`

            return (
              <div
                key={c.id}
                className={cn(
                  'group flex flex-col justify-between overflow-hidden rounded-2xl border bg-card p-4 shadow-sm hover:shadow-md transition-all duration-300 hover:-translate-y-1',
                  config.borderColor
                )}
              >
                {/* Top Section: Title & Visual Image */}
                <div className="flex items-start justify-between gap-3">
                  <div className="flex flex-col text-left space-y-1">
                    <h2 className={cn('text-sm font-black tracking-tight leading-tight', config.labelColor)}>
                      {c.name}
                    </h2>
                    <span className="text-[10px] text-text-muted font-bold">
                      {itemCount} active products
                    </span>
                    <Link
                      href={destinationHref}
                      className={cn(
                        'inline-flex items-center gap-0.5 text-[10px] font-black mt-2 tracking-wide hover:opacity-80 transition-opacity uppercase',
                        isCafe ? 'text-rose-600 dark:text-rose-400' : 'text-primary'
                      )}
                    >
                      Shop Now
                      <ChevronRight size={10} strokeWidth={2.5} />
                    </Link>
                  </div>

                  {/* Circular/Rounded Category Thumbnail Image Container */}
                  <Link
                    href={destinationHref}
                    className={cn(
                      'relative w-16 h-16 rounded-2xl overflow-hidden shadow-inner flex items-center justify-center shrink-0 border border-white/40 dark:border-white/5 bg-gradient-to-br transition-all duration-500 group-hover:scale-110 group-hover:shadow-md',
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
                  <div className="flex flex-wrap gap-1.5 pt-3 mt-3 border-t border-dashed border-border/80">
                    {/* All / View All option */}
                    <Link
                      href={destinationHref}
                      className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-zinc-50 hover:bg-muted text-[10px] font-black text-text-secondary border border-border/40 hover:text-text-primary transition-all active:scale-95"
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
                          className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-zinc-50 hover:bg-muted text-[10px] font-black text-text-secondary border border-border/40 hover:text-text-primary transition-all active:scale-95"
                        >
                          <span>{sub.emoji}</span>
                          <span>{sub.name}</span>
                        </Link>
                      )
                    })}
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
