import { z } from 'zod'

export const giftingHamperSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  tagline: z.string().default(''),
  price: z.number().min(0),
  mrp: z.number().min(0),
  badge: z.string().default('✨ CURATED DUO'),
  imageUrl: z.string().default(''),
  bundledProductIds: z.array(z.string()).default([]),
  isActive: z.boolean().default(true),
  sortOrder: z.number().default(0),
})

export type GiftingHamper = z.infer<typeof giftingHamperSchema>

export const giftingOccasionSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  title: z.string().min(1),
  imageUrl: z.string().default(''),
  emoji: z.string().default('🎁'),
  tags: z.array(z.string()).default([]),
  productIds: z.array(z.string()).default([]),
  isActive: z.boolean().default(true),
  sortOrder: z.number().default(0),
})

export type GiftingOccasion = z.infer<typeof giftingOccasionSchema>

export const giftingStoreConfigSchema = z.object({
  enabled: z.boolean().default(true),
  bannerTitle: z.string().default('Gifting Store'),
  bannerSubtitle: z.string().default('Curated by FastMinute'),
  bannerImageUrl: z.string().default(''),
  gradientStart: z.string().default('#E89E90'),
  gradientEnd: z.string().default('#CD7564'),
  occasions: z.array(giftingOccasionSchema).default([]),
  hampers: z.array(giftingHamperSchema).default([]),
})

export type GiftingStoreConfig = z.infer<typeof giftingStoreConfigSchema>

export const DEFAULT_GIFTING_CONFIG: GiftingStoreConfig = {
  enabled: true,
  bannerTitle: 'Gifting Store',
  bannerSubtitle: 'Curated by FastMinute',
  bannerImageUrl: '',
  gradientStart: '#E89E90',
  gradientEnd: '#CD7564',
  occasions: [
    {
      id: 'occ_flowers',
      label: 'Flowers',
      title: 'Fresh Flowers & Bouquets',
      imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/gifting/cutout_flowers.png',
      emoji: '🌸',
      tags: ['flower', 'flowers', 'bouquet', 'rose', 'roses', 'bloom', 'floral', 'rose bouquet', 'gifting'],
      productIds: [],
      isActive: true,
      sortOrder: 1,
    },
    {
      id: 'occ_cakes',
      label: 'Cakes',
      title: 'Cakes & Bakery',
      imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/gifting/cutout_cake.png',
      emoji: '🎂',
      tags: ['cake', 'cakes', 'bakery', 'pastry', 'donut cake', 'celebration cake', 'swiss roll'],
      productIds: [],
      isActive: true,
      sortOrder: 2,
    },
    {
      id: 'occ_chocolates',
      label: 'Chocolates',
      title: 'Luxury Chocolates',
      imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/gifting/cutout_chocolates.png',
      emoji: '🍫',
      tags: ['chocolate', 'chocolates', 'silk', 'bournville', 'temptation', 'celebration', 'ferrero', 'gift pack', 'dairy milk'],
      productIds: [],
      isActive: true,
      sortOrder: 3,
    },
    {
      id: 'occ_sweets',
      label: 'Sweets',
      title: 'Royal Sweets & Mithai',
      imageUrl: 'https://bberzasmxwioxjynbuaf.supabase.co/storage/v1/object/public/fastkirana-images/gifting/cutout_sweets.png',
      emoji: '🍬',
      tags: ['mithai', 'sweets', 'sweet', 'kaju katli', 'soan papdi', 'milk cake', 'gulab jamun', 'rasgulla', 'laddu', 'barfi', 'peda'],
      productIds: [],
      isActive: true,
      sortOrder: 4,
    },
  ],
  hampers: [],
}
