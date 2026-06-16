'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Category } from '@/types'
import { Search, ChevronRight, ShoppingBag, Sparkles } from 'lucide-react'
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
      borderColor: 'border-emerald-100 dark:border-emerald-900/30',
      labelColor: 'text-emerald-800 dark:text-emerald-300 font-black',
      cardBg: 'bg-gradient-to-br from-emerald-500/[0.03] via-card to-emerald-500/[0.01] dark:from-emerald-950/[0.08] dark:via-zinc-950 dark:to-emerald-950/[0.02]',
      tagline: '100% Farm-Fresh Organics',
      tagBg: 'bg-emerald-500/[0.03] dark:bg-emerald-950/20 border-emerald-500/10 dark:border-emerald-900/20 text-emerald-850 dark:text-emerald-300',
      tagHover: 'hover:border-emerald-450 dark:hover:border-emerald-700 hover:text-emerald-650 dark:hover:text-emerald-200 hover:bg-emerald-500/[0.08]',
      badgeText: 'Farm Direct',
      badgeBg: 'bg-emerald-500/10 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-350 border border-emerald-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(16,185,129,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(16,185,129,0.04)] hover:border-emerald-500/30',
      btnBg: 'bg-emerald-600 hover:bg-emerald-750 dark:bg-emerald-500 dark:hover:bg-emerald-600 text-white shadow-emerald-500/10',
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
      borderColor: 'border-blue-100 dark:border-blue-900/30',
      labelColor: 'text-blue-800 dark:text-blue-300 font-black',
      cardBg: 'bg-gradient-to-br from-blue-500/[0.03] via-card to-blue-500/[0.01] dark:from-blue-950/[0.08] dark:via-zinc-950 dark:to-blue-950/[0.02]',
      tagline: 'Chilled Dairy & Bread Eggs',
      tagBg: 'bg-blue-500/[0.03] dark:bg-blue-950/20 border-blue-500/10 dark:border-blue-900/20 text-blue-850 dark:text-blue-300',
      tagHover: 'hover:border-blue-450 dark:hover:border-blue-700 hover:text-blue-650 dark:hover:text-blue-200 hover:bg-blue-500/[0.08]',
      badgeText: 'Fresh Daily',
      badgeBg: 'bg-blue-500/10 text-blue-700 dark:bg-blue-500/20 dark:text-blue-350 border border-blue-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(59,130,246,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(59,130,246,0.04)] hover:border-blue-500/30',
      btnBg: 'bg-blue-600 hover:bg-blue-750 dark:bg-blue-500 dark:hover:bg-blue-600 text-white shadow-blue-500/10',
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
      borderColor: 'border-amber-100 dark:border-amber-900/30',
      labelColor: 'text-amber-800 dark:text-amber-300 font-black',
      cardBg: 'bg-gradient-to-br from-amber-500/[0.03] via-card to-amber-500/[0.01] dark:from-amber-950/[0.08] dark:via-zinc-950 dark:to-amber-950/[0.02]',
      tagline: 'Chips, Biscuits & Sweets',
      tagBg: 'bg-amber-500/[0.03] dark:bg-amber-950/20 border-amber-500/10 dark:border-amber-900/20 text-amber-850 dark:text-amber-300',
      tagHover: 'hover:border-amber-450 dark:hover:border-amber-700 hover:text-amber-650 dark:hover:text-amber-200 hover:bg-amber-500/[0.08]',
      badgeText: 'Party Specials',
      badgeBg: 'bg-amber-500/10 text-amber-700 dark:bg-amber-500/20 dark:text-amber-355 border border-amber-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(245,158,11,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(245,158,11,0.04)] hover:border-amber-500/30',
      btnBg: 'bg-amber-600 hover:bg-amber-750 dark:bg-amber-500 dark:hover:bg-amber-600 text-white shadow-amber-500/10',
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
      borderColor: 'border-purple-100 dark:border-purple-900/30',
      labelColor: 'text-purple-800 dark:text-purple-300 font-black',
      cardBg: 'bg-gradient-to-br from-purple-500/[0.03] via-card to-purple-500/[0.01] dark:from-purple-950/[0.08] dark:via-zinc-950 dark:to-purple-950/[0.02]',
      tagline: 'Soft Drinks & Coolers',
      tagBg: 'bg-purple-500/[0.03] dark:bg-purple-950/20 border-purple-500/10 dark:border-purple-900/20 text-purple-850 dark:text-purple-300',
      tagHover: 'hover:border-purple-450 dark:hover:border-purple-700 hover:text-purple-650 dark:hover:text-purple-200 hover:bg-purple-500/[0.08]',
      badgeText: 'Chilled Drinks',
      badgeBg: 'bg-purple-500/10 text-purple-755 dark:bg-purple-500/20 dark:text-purple-355 border border-purple-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(139,92,246,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(139,92,246,0.04)] hover:border-purple-500/30',
      btnBg: 'bg-purple-600 hover:bg-purple-755 dark:bg-purple-500 dark:hover:bg-purple-600 text-white shadow-purple-500/10',
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
      borderColor: 'border-pink-100 dark:border-pink-900/30',
      labelColor: 'text-pink-800 dark:text-pink-300 font-black',
      cardBg: 'bg-gradient-to-br from-pink-500/[0.03] via-card to-pink-500/[0.01] dark:from-pink-950/[0.08] dark:via-zinc-950 dark:to-pink-950/[0.02]',
      tagline: 'Bath, Soaps & Hair Care',
      tagBg: 'bg-pink-500/[0.03] dark:bg-pink-950/20 border-pink-500/10 dark:border-pink-900/20 text-pink-850 dark:text-pink-300',
      tagHover: 'hover:border-pink-450 dark:hover:border-pink-700 hover:text-pink-650 dark:hover:text-pink-200 hover:bg-pink-500/[0.08]',
      badgeText: 'Premium Care',
      badgeBg: 'bg-pink-500/10 text-pink-755 dark:bg-pink-500/20 dark:text-pink-350 border border-pink-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(236,72,153,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(236,72,153,0.04)] hover:border-pink-500/30',
      btnBg: 'bg-pink-600 hover:bg-pink-755 dark:bg-pink-500 dark:hover:bg-pink-600 text-white shadow-pink-500/10',
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
      borderColor: 'border-teal-100 dark:border-teal-900/30',
      labelColor: 'text-teal-800 dark:text-teal-300 font-black',
      cardBg: 'bg-gradient-to-br from-teal-500/[0.03] via-card to-teal-500/[0.01] dark:from-teal-950/[0.08] dark:via-zinc-950 dark:to-teal-950/[0.02]',
      tagline: 'Cleaning & Detergents',
      tagBg: 'bg-teal-500/[0.03] dark:bg-teal-950/20 border-teal-500/10 dark:border-teal-900/20 text-teal-855 dark:text-teal-300',
      tagHover: 'hover:border-teal-450 dark:hover:border-teal-700 hover:text-teal-650 dark:hover:text-teal-200 hover:bg-teal-500/[0.08]',
      badgeText: 'Home Essentials',
      badgeBg: 'bg-teal-500/10 text-teal-755 dark:bg-teal-500/20 dark:text-teal-350 border border-teal-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(20,184,166,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(20,184,166,0.04)] hover:border-teal-500/30',
      btnBg: 'bg-teal-600 hover:bg-teal-755 dark:bg-teal-500 dark:hover:bg-teal-600 text-white shadow-teal-500/10',
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
      borderColor: 'border-orange-100 dark:border-orange-900/30',
      labelColor: 'text-orange-800 dark:text-orange-300 font-black',
      cardBg: 'bg-gradient-to-br from-orange-500/[0.03] via-card to-orange-500/[0.01] dark:from-orange-950/[0.08] dark:via-zinc-950 dark:to-orange-950/[0.02]',
      tagline: 'Fresh Bread, Cakes & Rusks',
      tagBg: 'bg-orange-500/[0.03] dark:bg-orange-950/20 border-orange-500/10 dark:border-orange-900/20 text-orange-855 dark:text-orange-305',
      tagHover: 'hover:border-orange-455 dark:hover:border-orange-700 hover:text-orange-655 dark:hover:text-orange-200 hover:bg-orange-500/[0.08]',
      badgeText: 'Oven Fresh',
      badgeBg: 'bg-orange-500/10 text-rose-700 dark:bg-orange-500/20 dark:text-orange-355 border border-orange-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(249,115,22,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(249,115,22,0.04)] hover:border-orange-500/30',
      btnBg: 'bg-orange-600 hover:bg-orange-750 dark:bg-orange-500 dark:hover:bg-orange-600 text-white shadow-orange-500/10',
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
      borderColor: 'border-yellow-100 dark:border-yellow-900/30',
      labelColor: 'text-yellow-800 dark:text-yellow-450 font-black',
      cardBg: 'bg-gradient-to-br from-yellow-500/[0.03] via-card to-yellow-500/[0.01] dark:from-yellow-950/[0.08] dark:via-zinc-950 dark:to-yellow-950/[0.02]',
      tagline: 'Premium Dals & Atta Grains',
      tagBg: 'bg-yellow-500/[0.03] dark:bg-yellow-950/20 border-yellow-500/10 dark:border-yellow-900/20 text-yellow-850 dark:text-yellow-300',
      tagHover: 'hover:border-yellow-450 dark:hover:border-yellow-700 hover:text-yellow-650 dark:hover:text-yellow-200 hover:bg-yellow-500/[0.08]',
      badgeText: 'Pantry Staples',
      badgeBg: 'bg-yellow-500/10 text-yellow-755 dark:bg-yellow-500/20 dark:text-yellow-355 border border-yellow-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(234,179,8,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(234,179,8,0.04)] hover:border-yellow-500/30',
      btnBg: 'bg-yellow-600 hover:bg-yellow-755 dark:bg-yellow-500 dark:hover:bg-yellow-600 text-white shadow-yellow-500/10',
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
      gradient: 'from-teal-500/20 to-cyan-500/10 dark:from-teal-950/40 dark:to-cyan-950/20',
      borderColor: 'border-teal-100 dark:border-teal-900/30',
      labelColor: 'text-teal-805 dark:text-teal-300 font-black',
      cardBg: 'bg-gradient-to-br from-teal-500/[0.03] via-card to-teal-500/[0.01] dark:from-teal-950/[0.08] dark:via-zinc-950 dark:to-teal-950/[0.02]',
      tagline: 'Sweet Frozen Treats & Cups',
      tagBg: 'bg-teal-500/[0.03] dark:bg-teal-950/20 border-teal-500/10 dark:border-teal-900/20 text-teal-855 dark:text-teal-305',
      tagHover: 'hover:border-teal-400 dark:hover:border-teal-700 hover:text-teal-655 dark:hover:text-teal-200 hover:bg-teal-500/[0.08]',
      badgeText: 'Frozen Delights',
      badgeBg: 'bg-teal-500/10 text-teal-755 dark:bg-teal-500/20 dark:text-teal-350 border border-teal-500/10',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(20,184,166,0.08)] dark:hover:shadow-[0_15px_30px_-5px_rgba(20,184,166,0.04)] hover:border-teal-500/30',
      btnBg: 'bg-teal-600 hover:bg-teal-755 dark:bg-teal-500 dark:hover:bg-teal-600 text-white shadow-teal-500/10',
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
      gradient: 'from-amber-900/20 to-rose-900/10 dark:from-amber-950/40 dark:to-rose-950/20',
      borderColor: 'border-amber-900/20 dark:border-amber-900/30',
      labelColor: 'text-[#5d4037] dark:text-amber-250 font-black',
      cardBg: 'bg-gradient-to-br from-amber-500/[0.04] via-card to-rose-500/[0.02] dark:from-amber-950/[0.08] dark:via-zinc-950 dark:to-rose-950/[0.02]',
      tagline: 'Freshly Prepared Hot Meals',
      tagBg: 'bg-amber-500/[0.03] dark:bg-amber-950/20 border-amber-500/10 dark:border-amber-900/20 text-amber-850 dark:text-amber-300',
      tagHover: 'hover:border-amber-400 dark:hover:border-amber-700 hover:text-amber-600 dark:hover:text-amber-200 hover:bg-amber-500/[0.08]',
      badgeText: 'Hot Kitchen',
      badgeBg: 'bg-amber-500/10 text-amber-755 dark:bg-amber-500/20 dark:text-amber-305 border border-amber-500/20',
      glowColor: 'hover:shadow-[0_15px_30px_-5px_rgba(120,53,4,0.1)] dark:hover:shadow-[0_15px_30px_-5px_rgba(120,53,4,0.04)] hover:border-amber-500/30',
      btnBg: 'bg-amber-700 hover:bg-amber-750 dark:bg-amber-600 dark:hover:bg-amber-700 text-white shadow-amber-700/10',
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
      <nav className="flex items-center gap-1.5 text-[10px] font-black text-zinc-400 dark:text-zinc-500 uppercase tracking-widest select-none bg-zinc-50 dark:bg-zinc-900/30 px-3 py-1.5 rounded-full w-fit border border-zinc-150/40 dark:border-zinc-800/20">
        <Link href="/" className="hover:text-primary transition-colors">
          Home
        </Link>
        <ChevronRight size={10} className="text-zinc-300 dark:text-zinc-700" />
        <span className="text-primary font-extrabold">Categories Directory</span>
      </nav>

      {/* Header and Search Bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="text-left">
          <h1 className="text-2xl md:text-3xl font-black text-zinc-900 dark:text-zinc-100 tracking-tight flex items-center gap-2">
            <span className="h-6 w-1.5 rounded-full bg-primary animate-pulse-gentle" />
            Shop by Category
          </h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 font-bold mt-1.5 pl-3.5">
            Explore our curated catalog of groceries and hot café treats
          </p>
        </div>

        {/* Search Bar Input */}
        <div className="relative w-full md:max-w-xs bg-white dark:bg-zinc-900/50 backdrop-blur-md rounded-xl border border-zinc-200/80 dark:border-zinc-800/40 shadow-sm focus-within:ring-2 focus-within:ring-rose-500/20 focus-within:border-rose-500/50 transition-all duration-300 overflow-hidden group">
          <Search className="absolute left-3.5 top-3.5 h-4 w-4 text-text-muted transition-colors group-focus-within:text-rose-500" />
          <input
            type="text"
            placeholder="Search categories..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-transparent border-0 pl-10 pr-4 py-3.5 text-xs font-bold text-text-primary focus:outline-none focus:ring-0"
          />
        </div>
      </div>

      {/* Promos Banner Strip */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-rose-600 via-rose-500 to-amber-500 p-5 text-white flex items-center justify-between shadow-[0_8px_30px_rgba(225,29,72,0.15)] border border-rose-500/15 select-none">
        {/* Animated Shimmer Circle Overlays for Premium look */}
        <div className="absolute -top-12 -left-12 w-32 h-32 bg-white/10 rounded-full blur-2xl pointer-events-none" />
        <div className="absolute -bottom-16 -right-16 w-40 h-40 bg-white/15 rounded-full blur-3xl pointer-events-none" />
        
        <div className="flex items-center gap-4 relative z-10">
          <div className="p-2.5 bg-white/15 rounded-xl backdrop-blur-md border border-white/20 shadow-inner">
            <Sparkles className="h-5 w-5 text-amber-200 fill-amber-200 animate-pulse-gentle" />
          </div>
          <div className="text-left">
            <span className="inline-block bg-white/25 text-white font-extrabold text-[9px] px-2 py-0.5 rounded-full uppercase tracking-wider mb-1.5 border border-white/10 shadow-sm">
              Limited Time Offer
            </span>
            <h3 className="text-sm md:text-base font-black uppercase tracking-tight text-white leading-tight">
              Super Deals inside categories
            </h3>
            <p className="text-xs text-white/95 font-semibold mt-0.5">
              Get flat <span className="font-extrabold text-amber-200 underline decoration-wavy decoration-amber-200/60 underline-offset-2">10% cashback</span> on snacks, dairy, and warm beverages
            </p>
          </div>
        </div>
        <div className="hidden md:flex items-center gap-1.5 bg-white text-rose-600 px-4 py-2.5 rounded-xl border border-white/10 text-xs font-black shrink-0 shadow-md hover:scale-105 active:scale-95 transition-all cursor-pointer select-none relative z-10">
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
        <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3.5 sm:gap-5 px-1 pb-20">
          {filteredCategories.map((c) => {
            const config = categoryConfigs[c.slug] || {
              title: c.name,
              emoji: '🛒',
              image: c.imageUrl || '/fruits_vegetables_category.png',
              gradient: 'from-zinc-500/10 to-zinc-500/5 dark:from-zinc-950/20 dark:to-transparent',
              borderColor: 'border-zinc-150 dark:border-zinc-900/30',
              labelColor: 'text-zinc-700 dark:text-zinc-355 font-black',
              cardBg: 'bg-card',
              tagline: 'Essential Products',
              tagBg: 'bg-zinc-50 dark:bg-zinc-900 border-zinc-200/60 text-text-secondary',
              tagHover: 'hover:border-zinc-300 dark:hover:border-zinc-800 hover:text-zinc-650 dark:hover:text-zinc-400 hover:bg-zinc-50/20',
              badgeText: 'Curated',
              badgeBg: 'bg-zinc-100 text-zinc-755 dark:bg-zinc-850 dark:text-zinc-300 border border-zinc-200/30',
              glowColor: 'hover:shadow-md hover:border-zinc-300 dark:hover:border-zinc-750',
              btnBg: 'bg-primary hover:bg-primary/95 text-white',
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
                className={cn(
                  'group relative flex flex-col justify-between overflow-hidden rounded-2xl border p-3.5 sm:p-4 shadow-sm hover:shadow-xl transition-all duration-300 backdrop-blur-md bg-white/75 dark:bg-zinc-950/45 border-white/30 dark:border-white/[0.03]',
                  config.borderColor,
                  config.glowColor
                )}
              >
                {/* Large floating decorative emoji in background */}
                <div className="absolute -right-4 -bottom-6 text-7xl select-none opacity-[0.06] dark:opacity-[0.03] rotate-12 transition-transform duration-700 group-hover:scale-130 group-hover:-rotate-12 pointer-events-none font-sans filter blur-[0.5px]">
                  {config.bgEmoji || '🛒'}
                </div>

                <div className="flex flex-col space-y-3.5 relative z-10 w-full">
                  {/* Big Image Section */}
                  <Link
                    href={destinationHref}
                    className={cn(
                      'relative w-full aspect-[4/3] rounded-xl overflow-hidden block border border-black/5 dark:border-white/5 shadow-sm bg-gradient-to-br',
                      config.gradient
                    )}
                  >
                    {/* Floating Badge in Top Left */}
                    <div className="absolute top-1.5 left-1.5 z-20">
                      {itemCount > 0 ? (
                        <span className="inline-flex items-center gap-1 bg-white/95 dark:bg-zinc-950/95 text-rose-500 font-extrabold text-[8px] sm:text-[9.5px] px-2 py-0.5 rounded-full uppercase tracking-wider shadow-sm border border-black/5">
                          <ShoppingBag size={8.5} strokeWidth={3} />
                          {itemCount} Items
                        </span>
                      ) : (
                        <span className={cn("inline-flex items-center gap-1 font-extrabold text-[8px] sm:text-[9.5px] px-2 py-0.5 rounded-full uppercase tracking-wider shadow-sm border border-black/5", config.badgeBg)}>
                          <Sparkles size={8.5} strokeWidth={3} />
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
                        className="object-cover transition-transform duration-700 ease-out group-hover:scale-108"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center bg-white/40 dark:bg-black/35 backdrop-blur-md shadow-[inset_0_1.5px_3px_rgba(255,255,255,0.45)] border border-white/20 dark:border-white/[0.06] rounded-xl">
                        <span className="text-5xl select-none filter drop-shadow-[0_6px_10px_rgba(0,0,0,0.18)] transition-transform duration-500 group-hover:scale-110 group-hover:rotate-6">
                          {config.emoji}
                        </span>
                      </div>
                    )}
                  </Link>

                  {/* Title & Tagline info */}
                  <div className="flex flex-col text-left min-w-0 px-0.5">
                    <h2 className={cn('text-sm sm:text-base font-black tracking-tight leading-tight truncate', config.labelColor)}>
                      {c.name}
                    </h2>
                    <span className="text-[10px] sm:text-[11px] text-zinc-500 dark:text-zinc-400 font-bold truncate leading-none mt-1 shadow-sm/5">
                      {config.tagline}
                    </span>
                  </div>

                  {/* Shop Now Action */}
                  <div className="w-full">
                    <Link
                      href={destinationHref}
                      className={cn(
                        'inline-flex items-center gap-1.5 text-[8.5px] sm:text-[9.5px] font-black px-3.5 py-2.5 rounded-xl shadow-md transition-all duration-300 tracking-wider uppercase w-full justify-center text-white cursor-pointer active:scale-95 select-none border border-white/10',
                        config.btnBg
                      )}
                    >
                      <span>Shop Now</span>
                      <ChevronRight size={10} strokeWidth={3} className="transition-transform duration-300 group-hover:translate-x-0.5" />
                    </Link>
                  </div>
                </div>

                {/* Bottom Section: Subcategories Quick Tags (Horizontal Scrollable) */}
                {config.subcats.length > 0 && (
                  <div className="relative z-10 flex flex-col pt-3.5 mt-3.5 border-t border-dashed border-zinc-200 dark:border-zinc-800/60 w-full">
                    <span className="text-[8.5px] font-black uppercase tracking-wider text-text-muted mb-2 select-none text-left">
                      Popular Categories
                    </span>
                    <div className="flex gap-1.5 overflow-x-auto pb-1 scrollbar-none -mx-1 px-1 snap-x select-none w-full">
                      {/* All / View All option */}
                      <Link
                        href={destinationHref}
                        className={cn(
                          'flex items-center gap-1 px-3 py-1.5 rounded-full border text-[9px] font-black transition-all duration-200 active:scale-95 shadow-sm shrink-0 snap-start',
                          config.tagBg,
                          config.tagHover
                        )}
                      >
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
                              'flex items-center gap-1 px-3 py-1.5 rounded-full border text-[9px] font-black transition-all duration-200 active:scale-95 shadow-sm shrink-0 snap-start',
                              config.tagBg,
                              config.tagHover
                            )}
                          >
                            <span>{sub.name}</span>
                          </Link>
                        )
                      })}
                    </div>
                  </div>
                )}
              </motion.div>
            )
          })}
        </div>
      )}
    </div>
  )
}
