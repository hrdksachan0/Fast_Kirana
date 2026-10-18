'use client'

import { useState, useEffect, useMemo, useRef } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Category } from '@/types'
import { useUIStore } from '@/stores/ui-store'
import { cn } from '@/lib/utils'
import { Salad, Milk, Cookie, CupSoda, Sparkles, Home, Croissant, Wheat, ShoppingBag, IceCream, ChevronLeft, ChevronRight } from 'lucide-react'
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
  'fruits-vegetables': '/fruits_vegetables_category.webp',
  'dairy-breakfast': '/dairy_breakfast_category.webp',
  'snacks-munchies': '/snacks_munchies_category.webp',
  'beverages': '/beverages_category.webp',
  'personal-care': '/personal_care_category.webp',
  'household': '/household_category.webp',
  'bakery-biscuits': '/bakery_biscuits_category.webp',
  'atta-rice-dal': '/atta_rice_dal_category.webp',
  'ice-cream': '/ice_cream_category.webp',
  'cafe': '/cafe_category.webp',
}

export function CategoryGrid({ categories }: CategoryGridProps) {
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}

  const allDisplayCategories = useMemo(() => {
    return (categories || []).filter((cat) => !cat.parentId)
  }, [categories])

  // Map of category slugs to visual themes with glowing rings
  const colorMap: Record<string, { bg: string; text: string; gradient: string; ring: string }> = {
    'fruits-vegetables': { 
      bg: 'bg-emerald-50 dark:bg-emerald-500/5', 
      text: 'text-emerald-500 dark:text-emerald-400', 
      gradient: 'from-emerald-100/30 to-emerald-50/10 dark:from-emerald-500/10 dark:to-transparent', 
      ring: 'group-hover:border-emerald-500/50 group-hover:shadow-[0_0_15px_rgba(16,185,129,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(16,185,129,0.5)]' 
    },
    'dairy-products': { 
      bg: 'bg-amber-50 dark:bg-amber-500/5', 
      text: 'text-amber-500 dark:text-amber-400', 
      gradient: 'from-amber-100/30 to-amber-50/10 dark:from-amber-500/10 dark:to-transparent', 
      ring: 'group-hover:border-amber-500/50 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
    },
    'dairy-breakfast': { 
      bg: 'bg-amber-50 dark:bg-amber-500/5', 
      text: 'text-amber-500 dark:text-amber-400', 
      gradient: 'from-amber-100/30 to-amber-50/10 dark:from-amber-500/10 dark:to-transparent', 
      ring: 'group-hover:border-amber-500/50 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
    },
    'cookies-namkeen': { 
      bg: 'bg-orange-50 dark:bg-orange-500/5', 
      text: 'text-orange-500 dark:text-orange-400', 
      gradient: 'from-orange-100/30 to-orange-50/10 dark:from-orange-500/10 dark:to-transparent', 
      ring: 'group-hover:border-orange-500/50 group-hover:shadow-[0_0_15px_rgba(249,115,22,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(249,115,22,0.5)]' 
    },
    'packaged-items': { 
      bg: 'bg-rose-50 dark:bg-rose-500/5', 
      text: 'text-rose-500 dark:text-rose-400', 
      gradient: 'from-rose-100/30 to-rose-50/10 dark:from-rose-500/10 dark:to-transparent', 
      ring: 'group-hover:border-rose-500/50 group-hover:shadow-[0_0_15px_rgba(244,63,94,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(244,63,94,0.5)]' 
    },
    'dry-fruits-super-foods': { 
      bg: 'bg-purple-50 dark:bg-purple-500/5', 
      text: 'text-purple-500 dark:text-purple-400', 
      gradient: 'from-purple-100/30 to-purple-50/10 dark:from-purple-500/10 dark:to-transparent', 
      ring: 'group-hover:border-purple-500/50 group-hover:shadow-[0_0_15px_rgba(168,85,247,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(168,85,247,0.5)]' 
    },
    'cakes-chocolates': { 
      bg: 'bg-violet-50 dark:bg-violet-500/5', 
      text: 'text-violet-500 dark:text-violet-400', 
      gradient: 'from-violet-100/30 to-violet-50/10 dark:from-violet-500/10 dark:to-transparent', 
      ring: 'group-hover:border-violet-500/50 group-hover:shadow-[0_0_15px_rgba(147,51,234,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(147,51,234,0.5)]' 
    },
    'household-essentials': { 
      bg: 'bg-teal-50 dark:bg-teal-500/5', 
      text: 'text-teal-600 dark:text-teal-400', 
      gradient: 'from-teal-100/30 to-teal-50/10 dark:from-teal-500/10 dark:to-transparent', 
      ring: 'group-hover:border-teal-500/50 group-hover:shadow-[0_0_15px_rgba(20,184,166,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(20,184,166,0.5)]' 
    },
    'snacks-munchies': { 
      bg: 'bg-amber-50 dark:bg-amber-500/5', 
      text: 'text-amber-500 dark:text-amber-400', 
      gradient: 'from-amber-100/30 to-amber-50/10 dark:from-amber-500/10 dark:to-transparent', 
      ring: 'group-hover:border-amber-500/50 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
    },
    'snacks-instant-food': { 
      bg: 'bg-amber-50 dark:bg-amber-500/5', 
      text: 'text-amber-500 dark:text-amber-400', 
      gradient: 'from-amber-100/30 to-amber-50/10 dark:from-amber-500/10 dark:to-transparent', 
      ring: 'group-hover:border-amber-500/50 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
    },
    'dry-fruits-spices': { 
      bg: 'bg-orange-50 dark:bg-orange-500/5', 
      text: 'text-orange-500 dark:text-orange-400', 
      gradient: 'from-orange-100/30 to-orange-50/10 dark:from-orange-500/10 dark:to-transparent', 
      ring: 'group-hover:border-orange-500/50 group-hover:shadow-[0_0_15px_rgba(249,115,22,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(249,115,22,0.5)]' 
    },
    'kitchen-ration': { 
      bg: 'bg-yellow-50 dark:bg-yellow-500/5', 
      text: 'text-yellow-500 dark:text-yellow-400', 
      gradient: 'from-yellow-100/30 to-yellow-50/10 dark:from-yellow-500/10 dark:to-transparent', 
      ring: 'group-hover:border-yellow-500/50 group-hover:shadow-[0_0_15px_rgba(234,179,8,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(234,179,8,0.5)]' 
    },
    'kitchen-needs': { 
      bg: 'bg-yellow-50 dark:bg-yellow-500/5', 
      text: 'text-yellow-500 dark:text-yellow-400', 
      gradient: 'from-yellow-100/30 to-yellow-50/10 dark:from-yellow-500/10 dark:to-transparent', 
      ring: 'group-hover:border-yellow-500/50 group-hover:shadow-[0_0_15px_rgba(234,179,8,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(234,179,8,0.5)]' 
    },
    'beverages': { 
      bg: 'bg-cyan-50 dark:bg-cyan-500/5', 
      text: 'text-cyan-600 dark:text-cyan-400', 
      gradient: 'from-cyan-100/30 to-cyan-50/10 dark:from-cyan-500/10 dark:to-transparent', 
      ring: 'group-hover:border-cyan-500/50 group-hover:shadow-[0_0_15px_rgba(6,182,212,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(6,182,212,0.5)]' 
    },
    'personal-care': { 
      bg: 'bg-pink-50 dark:bg-pink-500/5', 
      text: 'text-pink-500 dark:text-pink-400', 
      gradient: 'from-pink-100/30 to-pink-50/10 dark:from-pink-500/10 dark:to-transparent', 
      ring: 'group-hover:border-pink-500/50 group-hover:shadow-[0_0_15px_rgba(236,72,153,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(236,72,153,0.5)]' 
    },
    'household': { 
      bg: 'bg-teal-50 dark:bg-teal-500/5', 
      text: 'text-teal-600 dark:text-teal-400', 
      gradient: 'from-teal-100/30 to-teal-50/10 dark:from-teal-500/10 dark:to-transparent', 
      ring: 'group-hover:border-teal-500/50 group-hover:shadow-[0_0_15px_rgba(20,184,166,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(20,184,166,0.5)]' 
    },
    'home-needs-and-cleaning': { 
      bg: 'bg-sky-50 dark:bg-sky-500/5', 
      text: 'text-sky-600 dark:text-sky-400', 
      gradient: 'from-sky-100/30 to-sky-50/10 dark:from-sky-500/10 dark:to-transparent', 
      ring: 'group-hover:border-sky-500/50 group-hover:shadow-[0_0_15px_rgba(14,165,233,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(14,165,233,0.5)]' 
    },
    'bakery-biscuits': { 
      bg: 'bg-orange-50 dark:bg-orange-500/5', 
      text: 'text-orange-500 dark:text-orange-400', 
      gradient: 'from-orange-100/30 to-orange-50/10 dark:from-orange-500/10 dark:to-transparent', 
      ring: 'group-hover:border-orange-500/50 group-hover:shadow-[0_0_15px_rgba(249,115,22,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(249,115,22,0.5)]' 
    },
    'bakery': { 
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
      bg: 'bg-pink-50 dark:bg-pink-500/5', 
      text: 'text-pink-500 dark:text-pink-400', 
      gradient: 'from-pink-100/30 to-pink-50/10 dark:from-pink-500/10 dark:to-transparent', 
      ring: 'group-hover:border-pink-500/50 group-hover:shadow-[0_0_15px_rgba(244,63,94,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(244,63,94,0.5)]' 
    },
    'chocolates': { 
      bg: 'bg-rose-50 dark:bg-rose-500/5', 
      text: 'text-rose-500 dark:text-rose-400', 
      gradient: 'from-rose-100/30 to-rose-50/10 dark:from-rose-500/10 dark:to-transparent', 
      ring: 'group-hover:border-rose-500/50 group-hover:shadow-[0_0_15px_rgba(244,63,94,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(244,63,94,0.5)]' 
    },
    'packaged-foods': { 
      bg: 'bg-orange-50 dark:bg-orange-500/5', 
      text: 'text-orange-500 dark:text-orange-400', 
      gradient: 'from-orange-100/30 to-orange-50/10 dark:from-orange-500/10 dark:to-transparent', 
      ring: 'group-hover:border-orange-500/50 group-hover:shadow-[0_0_15px_rgba(249,115,22,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(249,115,22,0.5)]' 
    },
    'healthy-foods': { 
      bg: 'bg-emerald-50 dark:bg-emerald-500/5', 
      text: 'text-emerald-500 dark:text-emerald-400', 
      gradient: 'from-emerald-100/30 to-emerald-50/10 dark:from-emerald-500/10 dark:to-transparent', 
      ring: 'group-hover:border-emerald-500/50 group-hover:shadow-[0_0_15px_rgba(16,185,129,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(16,185,129,0.5)]' 
    },
    'groceries': { 
      bg: 'bg-blue-50 dark:bg-blue-500/5', 
      text: 'text-blue-500 dark:text-blue-400', 
      gradient: 'from-blue-100/30 to-blue-50/10 dark:from-blue-500/10 dark:to-transparent', 
      ring: 'group-hover:border-blue-500/50 group-hover:shadow-[0_0_15px_rgba(59,130,246,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(59,130,246,0.5)]' 
    },
    'cafe': { 
      bg: 'bg-amber-50 dark:bg-amber-500/5', 
      text: 'text-amber-500 dark:text-amber-400', 
      gradient: 'from-amber-100/30 to-amber-50/10 dark:from-amber-500/10 dark:to-transparent', 
      ring: 'group-hover:border-amber-500/50 group-hover:shadow-[0_0_15px_rgba(245,158,11,0.35)] dark:group-hover:shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
    },
  }

  const mobileColorMap: Record<string, { bg: string; text: string; label: string; emoji: string }> = {
    'fruits-vegetables': { bg: 'bg-[#ecf7ed] dark:bg-emerald-950/20', text: 'text-[#2e7d32]', label: 'Fruits & Veg', emoji: '🥦' },
    'dairy-products': { bg: 'bg-[#fffde7] dark:bg-amber-950/20', text: 'text-[#d97706]', label: 'Milk & Dairy', emoji: '🥛' },
    'dairy-breakfast': { bg: 'bg-[#fffde7] dark:bg-amber-950/20', text: 'text-[#d97706]', label: 'Milk & Dairy', emoji: '🥛' },
    'cookies-namkeen': { bg: 'bg-[#fff7ed] dark:bg-orange-950/20', text: 'text-[#ea580c]', label: 'Cookies & Namkeen', emoji: '🍪' },
    'packaged-items': { bg: 'bg-[#fff1f2] dark:bg-rose-950/20', text: 'text-[#e11d48]', label: 'Packaged Items', emoji: '🍜' },
    'dry-fruits-super-foods': { bg: 'bg-[#faf5ff] dark:bg-purple-950/20', text: 'text-[#7c3aed]', label: 'Dry Fruits', emoji: '🥜' },
    'cakes-chocolates': { bg: 'bg-[#faf5ff] dark:bg-violet-950/20', text: 'text-[#9333ea]', label: 'Cakes & Choco', emoji: '🍫' },
    'household-essentials': { bg: 'bg-[#f0fdfa] dark:bg-teal-950/20', text: 'text-[#0d9488]', label: 'Home Care', emoji: '🧼' },
    'snacks-munchies': { bg: 'bg-[#fff8e1] dark:bg-amber-950/20', text: 'text-[#f57f17]', label: 'Snacks', emoji: '🍿' },
    'snacks-instant-food': { bg: 'bg-[#fff8e1] dark:bg-amber-950/20', text: 'text-[#f57f17]', label: 'Snacks & Instant', emoji: '🍿' },
    'dry-fruits-spices': { bg: 'bg-[#fff3e0] dark:bg-orange-950/20', text: 'text-[#e65100]', label: 'Dry Fruits & Spices', emoji: '🥜' },
    'kitchen-ration': { bg: 'bg-[#fffde7] dark:bg-yellow-950/20', text: 'text-[#fbc02d]', label: 'Kitchen & Ration', emoji: '🌾' },
    'kitchen-needs': { bg: 'bg-[#fffde7] dark:bg-yellow-950/20', text: 'text-[#fbc02d]', label: 'Kitchen Needs', emoji: '🍳' },
    'beverages': { bg: 'bg-[#eef2f6] dark:bg-slate-900/40', text: 'text-[#37474f]', label: 'Beverages', emoji: '🥤' },
    'personal-care': { bg: 'bg-[#fce4ec] dark:bg-pink-950/20', text: 'text-[#c2185b]', label: 'Personal Care', emoji: '🧴' },
    'household': { bg: 'bg-[#e0f7fa] dark:bg-teal-950/20', text: 'text-[#00838f]', label: 'Home Care', emoji: '🧼' },
    'home-needs-and-cleaning': { bg: 'bg-[#e0f7fa] dark:bg-teal-950/20', text: 'text-[#00838f]', label: 'Home Needs', emoji: '🧼' },
    'bakery': { bg: 'bg-[#efebe9] dark:bg-amber-950/10', text: 'text-[#4e342e]', label: 'Bakery & Biscuits', emoji: '🥐' },
    'bakery-biscuits': { bg: 'bg-[#efebe9] dark:bg-amber-950/10', text: 'text-[#4e342e]', label: 'Bakery', emoji: '🥐' },
    'atta-rice-dal': { bg: 'bg-[#fffde7] dark:bg-yellow-950/20', text: 'text-[#fbc02d]', label: 'Staples', emoji: '🌾' },
    'ice-cream': { bg: 'bg-[#e0f2f1] dark:bg-teal-950/20', text: 'text-[#00796b]', label: 'Ice Cream', emoji: '🍦' },
    'chocolates': { bg: 'bg-[#f3e5f5] dark:bg-purple-950/20', text: 'text-[#7b1fa2]', label: 'Chocolates & Sweets', emoji: '🍫' },
    'packaged-foods': { bg: 'bg-[#ede7f6] dark:bg-indigo-950/20', text: 'text-[#512da8]', label: 'Packaged Foods', emoji: '🥫' },
    'healthy-foods': { bg: 'bg-[#e8f5e9] dark:bg-emerald-950/20', text: 'text-[#388e3c]', label: 'Healthy Foods', emoji: '🥗' },
    'groceries': { bg: 'bg-[#e3f2fd] dark:bg-blue-950/20', text: 'text-[#1976d2]', label: 'Groceries', emoji: '🛒' },
    'cafe': { bg: 'bg-[#fff8e1] dark:bg-amber-950/20', text: 'text-[#f57f17]', label: 'Cafe', emoji: '☕' },
  }

  const getCategoryPhoto = (cat: any): string | null => {
    if (cat.imageUrl && (cat.imageUrl.startsWith('data:image/') || cat.imageUrl.startsWith('/') || cat.imageUrl.startsWith('http'))) {
      return cat.imageUrl
    }
    const slug = (cat.slug || '').toLowerCase()
    if (categoryPhotos[slug]) return categoryPhotos[slug]
    const combined = `${slug} ${(cat.name || '').toLowerCase()}`
    if (/dairy|milk|paneer|curd|butter|cheese|chhachh|ghee|dahi/i.test(combined)) return '/dairy_breakfast_category.webp'
    if (/fruit|veg|sabzi/i.test(combined)) return '/fruits_vegetables_category.webp'
    if (/cookie|namkeen|snack|munch|chips|biscuit|kurkure/i.test(combined)) return '/snacks_munchies_category.webp'
    if (/beverage|drink|juice|soda|cola|water|cold/i.test(combined)) return '/beverages_category.webp'
    if (/personal|care|hygiene|soap|shampoo|oral|hair|cosmetic/i.test(combined)) return '/personal_care_category.webp'
    if (/clean|wash|house|home|laundry|dish|pest|pooja/i.test(combined)) return '/household_category.webp'
    if (/atta|rice|dal|oil|spice|masala|kitchen|ration|grain|flour/i.test(combined)) return '/atta_rice_dal_category.webp'
    if (/ice.?cream|dessert|kulfi|cassatta/i.test(combined)) return '/ice_cream_category.webp'
    if (/cake|choco|sweet|mithai|pastry|bakery/i.test(combined)) return '/bakery_biscuits_category.webp'
    if (/cafe|restaurant|burger|pizza/i.test(combined)) return '/cafe_category.webp'
    return null
  }

  const getCategoryColor = (cat: any) => {
    const slug = (cat.slug || '').toLowerCase()
    if (colorMap[slug]) return colorMap[slug]
    const combined = `${slug} ${(cat.name || '').toLowerCase()}`
    if (/dairy|milk|paneer|curd|butter|cheese/i.test(combined)) return colorMap['dairy-products'] || colorMap['dairy-breakfast']
    if (/fruit|veg/i.test(combined)) return colorMap['fruits-vegetables']
    if (/cookie|namkeen/i.test(combined)) return colorMap['cookies-namkeen']
    if (/package|instant|noodle|pasta/i.test(combined)) return colorMap['packaged-items']
    if (/dry.?fruit|nuts/i.test(combined)) return colorMap['dry-fruits-super-foods']
    if (/cake|choco|sweet/i.test(combined)) return colorMap['cakes-chocolates']
    if (/house|clean|home/i.test(combined)) return colorMap['household-essentials']
    if (/kitchen|ration|atta|rice|dal/i.test(combined)) return colorMap['kitchen-ration']
    if (/drink|beverage/i.test(combined)) return colorMap['beverages']
    if (/personal|hygiene|care/i.test(combined)) return colorMap['personal-care']
    if (/ice.?cream/i.test(combined)) return colorMap['ice-cream']
    return {
      bg: 'bg-rose-500/5 dark:bg-rose-950/10 hover:bg-rose-500/10',
      text: 'text-rose-500 dark:text-rose-450',
      gradient: 'from-rose-500/10 to-rose-50/5',
      ring: 'group-hover:ring-rose-500/20 hover:border-rose-500/30',
    }
  }

  const getCategoryMobileConfig = (cat: any) => {
    const slug = (cat.slug || '').toLowerCase()
    if (mobileColorMap[slug]) return mobileColorMap[slug]
    const combined = `${slug} ${(cat.name || '').toLowerCase()}`
    if (/dairy|milk|paneer|curd|butter|cheese/i.test(combined)) return mobileColorMap['dairy-products'] || mobileColorMap['dairy-breakfast']
    if (/fruit|veg/i.test(combined)) return mobileColorMap['fruits-vegetables']
    if (/cookie|namkeen/i.test(combined)) return mobileColorMap['cookies-namkeen']
    if (/package|instant|noodle|pasta/i.test(combined)) return mobileColorMap['packaged-items']
    if (/dry.?fruit|nuts/i.test(combined)) return mobileColorMap['dry-fruits-super-foods']
    if (/cake|choco|sweet/i.test(combined)) return mobileColorMap['cakes-chocolates']
    if (/house|clean|home/i.test(combined)) return mobileColorMap['household-essentials']
    if (/kitchen|ration|atta|rice|dal/i.test(combined)) return mobileColorMap['kitchen-ration']
    if (/drink|beverage/i.test(combined)) return mobileColorMap['beverages']
    if (/personal|hygiene|care/i.test(combined)) return mobileColorMap['personal-care']
    if (/ice.?cream/i.test(combined)) return mobileColorMap['ice-cream']
    return {
      bg: 'bg-rose-500/10 dark:bg-rose-950/20 hover:border-rose-500/30',
      text: 'text-rose-500 dark:text-rose-450',
      label: cat.name || slug,
      emoji: (cat as any).emoji || '📦'
    }
  }

  const scrollContainerRef = useRef<HTMLDivElement>(null)

  const handleScroll = (direction: 'left' | 'right') => {
    if (scrollContainerRef.current) {
      const scrollOffset = direction === 'left' ? -240 : 240
      scrollContainerRef.current.scrollBy({ left: scrollOffset, behavior: 'smooth' })
    }
  }

  return (
    <section className="py-0.5 md:py-2">
      {/* Mobile Header: Shop by Categories + Controls + See all */}
      <div className="flex items-center justify-between mb-2 md:hidden px-1">
        <h2 className="text-base font-black text-zinc-900 dark:text-zinc-100 tracking-tight">
          Trending Categories
        </h2>
        <div className="flex items-center gap-1.5">
          <button
            type="button"
            onClick={() => handleScroll('left')}
            aria-label="Scroll left"
            className="w-6 h-6 rounded-full border border-border/60 bg-card hover:bg-muted text-text-secondary flex items-center justify-center transition-all cursor-pointer active:scale-90 shadow-2xs"
          >
            <ChevronLeft className="w-3.5 h-3.5" />
          </button>
          <button
            type="button"
            onClick={() => handleScroll('right')}
            aria-label="Scroll right"
            className="w-6 h-6 rounded-full border border-border/60 bg-card hover:bg-muted text-text-secondary flex items-center justify-center transition-all cursor-pointer active:scale-90 shadow-2xs"
          >
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
          <Link 
            href="/category" 
            prefetch={false}
            className="text-[9px] sm:text-[10px] font-black uppercase tracking-wider px-2.5 py-1 rounded-full border border-primary/20 bg-primary/5 text-primary hover:bg-primary/15 transition-all duration-300 shadow-[0_1.5px_4px_rgba(0,0,0,0.015)] active:scale-95 whitespace-nowrap ml-0.5"
          >
            See all
          </Link>
        </div>
      </div>

      {/* Mobile: 2-Row Horizontal scrollable/sliding list with useRef controller */}
      <div 
        ref={scrollContainerRef}
        className="grid grid-rows-2 grid-flow-col auto-cols-[74px] sm:auto-cols-[80px] gap-x-2.5 gap-y-3 overflow-x-auto pb-2 pt-1 scrollbar-none md:hidden px-1 scroll-smooth"
      >
        {allDisplayCategories.map((category: any) => {
            const config = getCategoryMobileConfig(category)
            const photoSrc = getCategoryPhoto(category)

            const rawLabel = (config.label || category.name || '').replace(/^(FastKirana|FastMinute)\s+/i, '').trim()
            let formattedLabel = rawLabel
            if (category.slug === 'household' || category.slug?.includes('household') || category.name?.toLowerCase().includes('household')) {
              formattedLabel = 'Home Care'
            } else if (category.slug === 'restaurant' || category.slug?.includes('restaurant') || category.name?.toLowerCase().includes('restaurant')) {
              formattedLabel = 'Restaurant'
            } else if (category.slug === 'cafe' || category.slug?.includes('cafe') || category.name?.toLowerCase().includes('cafe')) {
              formattedLabel = 'Cafe'
            }

            const isCafe = category.slug === 'cafe' || category.isCafeSection
            const isCatOpen = categoryStatus[category.slug] !== false
            const isClosed = isCafe ? (!cafeOpen || !isCatOpen) : (!groceryMartOpen || !isCatOpen)

            return (
              <motion.div
                key={category.id}
                whileTap={{ scale: 0.93, rotate: -1.5 }}
                className="w-[76px] shrink-0"
              >
                <Link
                  href={category.slug === 'cafe' || category.isCafeSection ? '/food/as-cafe' : category.slug === 'restaurant' ? '/food' : `/category/${category.slug}`}
                  prefetch={false}
                  className="group flex flex-col items-center text-center cursor-pointer"
                >
                  {/* Pastel Squircle Card with Real Transparent Photo or 3D Glassmorphic Emoji */}
                  <div
                    className={`w-[70px] h-[70px] mx-auto rounded-[20px] ${config.bg} p-0.5 overflow-hidden shadow-[0_2px_8px_rgba(0,0,0,0.04)] transition-all duration-300 border border-black/5 dark:border-white/[0.04] relative flex items-center justify-center`}
                  >
                    {/* Fallback Emoji layer (always present beneath the image) */}
                    <span className="text-2xl select-none filter drop-shadow-[0_2px_4px_rgba(0,0,0,0.12)]">
                      {category.imageUrl && category.imageUrl.length < 5 ? category.imageUrl : config.emoji}
                    </span>

                    {/* Image overlay if real photo URL exists */}
                    {photoSrc ? (
                      <Image
                        src={photoSrc}
                        alt={formattedLabel}
                        fill
                        sizes="70px"
                        className="object-contain p-0.5 transition-transform duration-500 group-hover:scale-110 filter drop-shadow-[0_2px_4px_rgba(0,0,0,0.06)]"
                        onError={(e) => {
                          (e.currentTarget as HTMLElement).style.display = 'none'
                        }}
                      />
                    ) : null}
                  </div>
                  {/* Category Label */}
                  <div className="min-h-[26px] flex items-center justify-center mt-1 w-full px-0.5">
                    <span className="text-[10px] sm:text-[10.5px] font-black text-zinc-800 dark:text-zinc-200 leading-[1.15] tracking-tight line-clamp-2 text-center break-words max-w-full">
                      {formattedLabel}
                    </span>
                  </div>
                </Link>
              </motion.div>
            )
          })}
      </div>

      {/* Desktop Header */}
      <h2 className="hidden md:flex text-lg md:text-2xl font-black text-text-primary tracking-tight mb-4 px-1 items-center gap-2">
        <span className="h-5 w-1.5 rounded-full bg-primary" />
        Trending Categories
      </h2>

      {/* Desktop: Grid layout */}
      <div className="hidden md:grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-9 gap-4 stagger-children">
        {allDisplayCategories.map((category: any) => {
            const colors = getCategoryColor(category)
            const photoSrc = getCategoryPhoto(category)
            const itemCount = category._count?.products ?? 0
            const IconComponent = iconMap[category.slug] || ShoppingBag

            const isCafe = category.slug === 'cafe' || category.isCafeSection
            const isCatOpen = categoryStatus[category.slug] !== false
            const isClosed = isCafe ? (!cafeOpen || !isCatOpen) : (!groceryMartOpen || !isCatOpen)

            return (
              <div
                key={category.id}
                className="p-3 rounded-2xl border border-transparent hover:border-zinc-200/50 dark:hover:border-zinc-800/40 hover:bg-white/70 dark:hover:bg-zinc-900/30 shadow-2xs hover:shadow-sm transition-all duration-300 group"
              >
                <Link
                  href={category.slug === 'cafe' || category.isCafeSection ? '/food/as-cafe' : category.slug === 'restaurant' ? '/food' : `/category/${category.slug}`}
                  prefetch={false}
                  className="flex flex-col items-center text-center"
                >
                  <div
                    className={`flex items-center justify-center w-20 h-20 rounded-[22px] ${colors.bg} p-1 border border-white/20 dark:border-white/[0.05] backdrop-blur-md mb-2 shadow-xs transition-all duration-300 group-hover:shadow-md ${colors.ring} overflow-hidden relative`}
                  >
                    {photoSrc ? (
                      <Image
                        src={photoSrc}
                        alt={category.name}
                        fill
                        sizes="(max-width: 768px) 80px, 120px"
                        className="object-contain p-1 transition-transform duration-300 group-hover:scale-110 filter drop-shadow-[0_2px_4px_rgba(0,0,0,0.06)]"
                        onError={(e) => {
                          (e.currentTarget as HTMLElement).style.display = 'none'
                        }}
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
                    {category.isCafeSection ? 'Freshly Made' : (itemCount > 0 ? `${itemCount} items` : 'Explore')}
                  </span>
                </Link>
              </div>
            )
          })}
      </div>
    </section>
  )
}
