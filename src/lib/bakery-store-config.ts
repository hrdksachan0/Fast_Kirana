import { z } from 'zod'

export const bakeryTabSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  title: z.string().min(1),
  subtitle: z.string().default(''),
  emoji: z.string().default('🥐'),
  iconUrl: z.string().default(''),
  filterTags: z.array(z.string()).default([]),
  categorySlug: z.string().default('bakery'),
  isActive: z.boolean().default(true),
  sortOrder: z.number().default(0),
})

export type BakeryTab = z.infer<typeof bakeryTabSchema>

export const bakeryStoreConfigSchema = z.object({
  enabled: z.boolean().default(true),
  bannerBadge: z.string().default('⚡ FRESH BATCH 5:00 AM'),
  bannerTitle: z.string().default('Baked fresh every morning'),
  bannerSubtitle: z.string().default('Warm crusts, soft pav & tea-time rusks'),
  bannerImageUrl: z.string().default('https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80'),
  backgroundColor: z.string().default('#FAF8F3'),
  tabs: z.array(bakeryTabSchema).default([]),
})

export type BakeryStoreConfig = z.infer<typeof bakeryStoreConfigSchema>

export const DEFAULT_BAKERY_CONFIG: BakeryStoreConfig = {
  enabled: true,
  bannerBadge: '⚡ FRESH BATCH 5:00 AM',
  bannerTitle: 'Baked fresh every morning',
  bannerSubtitle: 'Warm crusts, soft pav & tea-time rusks',
  bannerImageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80',
  backgroundColor: '#FAF8F3',
  tabs: [
    {
      id: 'tab_pav',
      label: 'Pav, Buns\n& Bases',
      title: 'Pav, Buns & Pizza Bases',
      subtitle: 'Fresh batch from dark store • Baked 5:00 AM',
      emoji: '🍔',
      iconUrl: '',
      filterTags: ['pav', 'bun', 'burger bun', 'pizza base', 'kulcha', 'ladi pav'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 1,
    },
    {
      id: 'tab_breads',
      label: 'Daily\nBreads',
      title: 'Daily Fresh Breads',
      subtitle: '100% Whole Wheat, Multigrain & Milk Loaves',
      emoji: '🍞',
      iconUrl: '',
      filterTags: ['bread', 'atta bread', 'brown bread', 'multigrain', 'milk bread', 'white bread'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 2,
    },
    {
      id: 'tab_rusks',
      label: 'Toast &\nRusks',
      title: 'Crispy Rusks & Tea-Time Toasts',
      subtitle: 'Suji, Saunf & Milk Toasts for your morning chai',
      emoji: '🍪',
      iconUrl: '',
      filterTags: ['rusk', 'toast', 'suji rusk', 'tea toast', 'biscuit'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 3,
    },
    {
      id: 'tab_puffs',
      label: 'Puffs &\nPatties',
      title: 'Flaky Puffs & Savory Patties',
      subtitle: 'Baked crispy golden • Hot snack ready',
      emoji: '🥐',
      iconUrl: '',
      filterTags: ['puff', 'patties', 'patis', 'roll', 'croissant', 'savory'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 4,
    },
    {
      id: 'tab_khari',
      label: 'Khari &\nCookies',
      title: 'Butter Khari & Fresh Cookies',
      subtitle: 'Melt-in-mouth bakery biscuits and flaky khari',
      emoji: '🥨',
      iconUrl: '',
      filterTags: ['khari', 'cookie', 'nankhatai', 'jeera biscuit', 'butter biscuit'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: 5,
    },
  ],
}
