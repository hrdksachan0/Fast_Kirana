import { z } from 'zod'

export const giftingOccasionSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  title: z.string().min(1),
  imageUrl: z.string().default(''),
  emoji: z.string().default('🎁'),
  tags: z.array(z.string()).default([]),
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
})

export type GiftingStoreConfig = z.infer<typeof giftingStoreConfigSchema>

export const DEFAULT_GIFTING_CONFIG: GiftingStoreConfig = {
  enabled: true,
  bannerTitle: 'Gifting Store',
  bannerSubtitle: 'Curated by FastMinute',
  bannerImageUrl: '', // Empty by default so admin can upload their own
  gradientStart: '#E89E90',
  gradientEnd: '#CD7564',
  occasions: [
    {
      id: 'occ_birthday',
      label: 'Birthday',
      title: 'Birthday Specials',
      imageUrl: '', // Empty by default so admin can upload custom photography
      emoji: '🎈',
      tags: ['birthday', 'gift', 'cake', 'chocolate'],
      isActive: true,
      sortOrder: 1,
    },
    {
      id: 'occ_anniversary',
      label: 'Anniversary',
      title: 'Anniversary Hampers',
      imageUrl: '',
      emoji: '🧸',
      tags: ['anniversary', 'gift', 'romantic', 'cake'],
      isActive: true,
      sortOrder: 2,
    },
    {
      id: 'occ_cakes',
      label: 'Cakes',
      title: 'Cakes & Bakery',
      imageUrl: '',
      emoji: '🎂',
      tags: ['cake', 'bakery', 'pastry'],
      isActive: true,
      sortOrder: 3,
    },
    {
      id: 'occ_chocolates',
      label: 'Chocolates',
      title: 'Luxury Chocolates',
      imageUrl: '',
      emoji: '🍫',
      tags: ['chocolate', 'gift', 'sweet'],
      isActive: true,
      sortOrder: 4,
    },
    {
      id: 'occ_mithai',
      label: 'Mithai',
      title: 'Royal Mithai',
      imageUrl: '',
      emoji: '🍯',
      tags: ['mithai', 'sweets', 'traditional'],
      isActive: true,
      sortOrder: 5,
    },
    {
      id: 'occ_dry_fruits',
      label: 'Dry Fruits',
      title: 'Festive Hampers',
      imageUrl: '',
      emoji: '🎁',
      tags: ['dry-fruit', 'nut', 'hamper', 'festive'],
      isActive: true,
      sortOrder: 6,
    },
  ],
}
