import { z } from 'zod'
import type { Product } from '@/types'
import { campaignImageSchema } from '@/lib/campaign-config'

const slugId = z
  .string()
  .trim()
  .min(1)
  .max(128)
  .regex(/^[a-zA-Z0-9_-]+$/)

const shortText = z.string().trim().max(160)

export const bentoSlotItemSchema = z
  .object({
    id: slugId,
    productId: z.string().trim().min(1).max(128).nullable().optional(),
    keywords: z.array(z.string().trim().min(1).max(80)).max(20).default([]),
    customTitle: shortText.nullable().optional(),
    badge: z.string().trim().max(40).nullable().optional(),
    perUnitLabel: z.string().trim().max(40).nullable().optional(),
    checkedByDefault: z.boolean().optional(),
    fallbackName: shortText.min(1),
    fallbackUnit: z.string().trim().min(1).max(40),
    fallbackPrice: z.number().finite().nonnegative(),
    fallbackMrp: z.number().finite().nonnegative().optional(),
    fallbackImage: campaignImageSchema.default('/navratri/daily-vegetables.svg'),
  })
  .strict()

export const freshMarketTabSchema = z
  .object({
    id: slugId,
    label: shortText.min(1),
    icon: z.string().trim().max(16).default('🥬'),
    items: z.array(bentoSlotItemSchema).min(1).max(6),
  })
  .strict()

export const giftingOccasionSchema = z
  .object({
    id: slugId,
    label: shortText.min(1),
    icon: z.string().trim().max(16).default('🎁'),
  })
  .strict()

export const bentoTimeSlotEnum = z.enum([
  'ALL_DAY',
  'MORNING',
  'AFTERNOON',
  'EVENING',
  'NIGHT',
])
export type BentoTimeSlot = z.infer<typeof bentoTimeSlotEnum>

const cardVisibilityFields = {
  enabled: z.boolean().default(true),
  sortOrder: z.number().int().default(0),
  minInStockItems: z.number().int().min(0).max(20).default(1),
  scheduleEnabled: z.boolean().default(false),
  startDate: z.string().nullable().optional(),
  endDate: z.string().nullable().optional(),
  timeSlot: bentoTimeSlotEnum.default('ALL_DAY'),
  targetHubs: z.array(z.string().trim()).default(['all']),
  badge: z.string().trim().optional().default(''),
  backgroundColor: z.string().trim().optional().default(''),
  borderColor: z.string().trim().optional().default(''),
  accentColor: z.string().trim().optional().default(''),
  textColor: z.string().trim().optional().default(''),
}

export const campaignBentoConfigSchema = z
  .object({
    version: z.literal(1).default(1),
    enabled: z.boolean().default(false),
    freshMarket: z
      .object({
        ...cardVisibilityFields,
        title: shortText.min(1).default('Fresh Market'),
        subtitle: shortText.default('Farm-fresh essentials, ready to add'),
        headerImage: campaignImageSchema.default('/navratri/daily-vegetables.svg'),
        tabs: z.array(freshMarketTabSchema).min(1).max(5),
      })
      .strict(),
    dailyRestock: z
      .object({
        ...cardVisibilityFields,
        title: shortText.min(1).default('Daily Restock'),
        subtitle: shortText.default('Everyday groceries at your fingertips'),
        headerImage: campaignImageSchema.default('/navratri/daily-grocery-basket.svg'),
        items: z.array(bentoSlotItemSchema).min(1).max(6),
      })
      .strict(),
    valuePicks: z
      .object({
        ...cardVisibilityFields,
        title: shortText.min(1).default('Value Picks'),
        subtitle: shortText.default('Save more on your daily essentials'),
        items: z.array(bentoSlotItemSchema).min(1).max(4),
      })
      .strict(),
    giftingBoutique: z
      .object({
        ...cardVisibilityFields,
        title: shortText.min(1).default('Gifting Boutique'),
        subtitle: shortText.default('Thoughtful gifts for special occasions'),
        heroItem: bentoSlotItemSchema,
        miniItem: bentoSlotItemSchema,
        occasions: z.array(giftingOccasionSchema).min(1).max(6),
      })
      .strict(),
    movieNight: z
      .object({
        ...cardVisibilityFields,
        title: shortText.min(1).default('Movie Night'),
        subtitle: shortText.default('Snacks for the perfect watch time'),
        heroImage: campaignImageSchema.default('/navratri/ref-movie-cinema-scene.png'),
        items: z.array(bentoSlotItemSchema).min(1).max(6),
      })
      .strict(),
    breakfastClub: z
      .object({
        ...cardVisibilityFields,
        title: shortText.min(1).default('Breakfast Club'),
        subtitle: shortText.default('Your quick breakfast list'),
        heroImage: campaignImageSchema.default('/navratri/ref-breakfast-toast.png'),
        items: z.array(bentoSlotItemSchema).min(1).max(6),
      })
      .strict(),
  })
  .strict()

export type BentoSlotItem = z.infer<typeof bentoSlotItemSchema>
export type FreshMarketTab = z.infer<typeof freshMarketTabSchema>
export type GiftingOccasion = z.infer<typeof giftingOccasionSchema>
export type CampaignBentoConfig = z.infer<typeof campaignBentoConfigSchema>
export type BentoCardKey =
  | 'freshMarket'
  | 'dailyRestock'
  | 'valuePicks'
  | 'giftingBoutique'
  | 'movieNight'
  | 'breakfastClub'

export const defaultCampaignBentoConfig: CampaignBentoConfig = {
  version: 1,
  enabled: false,
  freshMarket: {
    enabled: true,
    sortOrder: 1,
    badge: '01',
    backgroundColor: '#E2EFFF',
    borderColor: '#CFE4FD',
    accentColor: '#15803D',
    textColor: '#0F172A',
    minInStockItems: 1,
    scheduleEnabled: false,
    startDate: null,
    endDate: null,
    timeSlot: 'ALL_DAY',
    targetHubs: ['all'],
    title: 'Fresh Market',
    subtitle: 'Farm-fresh essentials, ready to add',
    headerImage: '/navratri/daily-vegetables.svg',
    tabs: [
      {
        id: 'sabzi',
        label: 'Sabzi',
        icon: '🍅',
        items: [
          {
            id: 'tomato',
            productId: null,
            keywords: ['tomato', 'tamatar'],
            fallbackName: 'Tomato',
            fallbackUnit: '500 g',
            fallbackPrice: 25,
            fallbackMrp: 30,
            fallbackImage: '/navratri/ref-fresh-tomato.png',
          },
          {
            id: 'cucumber',
            productId: null,
            keywords: ['cucumber', 'kheera'],
            fallbackName: 'Cucumber',
            fallbackUnit: '500 g',
            fallbackPrice: 30,
            fallbackMrp: 35,
            fallbackImage: '/navratri/ref-fresh-cucumber.png',
          },
        ],
      },
      {
        id: 'fruits',
        label: 'Fruits',
        icon: '🥭',
        items: [
          {
            id: 'mango',
            productId: null,
            keywords: ['mango', 'safeda', 'aam', 'apple', 'banana'],
            fallbackName: 'Safeda Mango',
            fallbackUnit: '1 kg',
            fallbackPrice: 160,
            fallbackMrp: 200,
            fallbackImage: '/navratri/summer-mango.svg',
          },
          {
            id: 'lemon',
            productId: null,
            keywords: ['lemon', 'nimbu', 'orange', 'mosambi'],
            fallbackName: 'Fresh Lemon',
            fallbackUnit: '250 g',
            fallbackPrice: 40,
            fallbackMrp: 55,
            fallbackImage: '/navratri/summer-lemon.svg',
          },
        ],
      },
      {
        id: 'herbs',
        label: 'Herbs',
        icon: '🌿',
        items: [
          {
            id: 'coriander',
            productId: null,
            keywords: ['coriander', 'dhaniya'],
            fallbackName: 'Fresh Coriander',
            fallbackUnit: '100 g',
            fallbackPrice: 15,
            fallbackMrp: 20,
            fallbackImage: '/navratri/fresh-coriander.svg',
          },
          {
            id: 'mint',
            productId: null,
            keywords: ['mint', 'pudina', 'curry leaves', 'palak', 'spinach'],
            fallbackName: 'Fresh Mint',
            fallbackUnit: '100 g',
            fallbackPrice: 15,
            fallbackMrp: 20,
            fallbackImage: '/navratri/fresh-mint.svg',
          },
        ],
      },
    ],
  },
  dailyRestock: {
    enabled: true,
    sortOrder: 2,
    badge: '02',
    backgroundColor: '#F4F9FD',
    borderColor: '#E0F2FE',
    accentColor: '#0284C7',
    textColor: '#0F172A',
    minInStockItems: 1,
    scheduleEnabled: false,
    startDate: null,
    endDate: null,
    timeSlot: 'ALL_DAY',
    targetHubs: ['all'],
    title: 'Daily Restock',
    subtitle: 'Everyday groceries at your fingertips',
    headerImage: '/navratri/daily-grocery-basket.svg',
    items: [
      {
        id: 'milk-daily',
        productId: null,
        keywords: ['milk', 'taaza', 'gold milk', 'amul', 'doodh'],
        fallbackName: 'Milk',
        fallbackUnit: '500 ml',
        fallbackPrice: 30,
        fallbackMrp: 32,
        fallbackImage: '/navratri/daily-milk.svg',
      },
      {
        id: 'bread-daily',
        productId: null,
        keywords: ['bread', 'brown bread', 'sandwich bread', 'pav'],
        fallbackName: 'Bread',
        fallbackUnit: '400 g',
        fallbackPrice: 45,
        fallbackMrp: 50,
        fallbackImage: '/navratri/daily-bread.svg',
      },
      {
        id: 'atta-daily',
        productId: null,
        keywords: ['atta', 'aashirvaad', 'wheat flour', 'chakki'],
        fallbackName: 'Atta',
        fallbackUnit: '1 kg',
        fallbackPrice: 55,
        fallbackMrp: 65,
        fallbackImage: '/navratri/ref-atta-1kg.png',
      },
    ],
  },
  valuePicks: {
    enabled: true,
    sortOrder: 3,
    badge: '03',
    backgroundColor: '#FEFCE8',
    borderColor: '#FEF08A',
    accentColor: '#15803D',
    textColor: '#78350F',
    minInStockItems: 1,
    scheduleEnabled: false,
    startDate: null,
    endDate: null,
    timeSlot: 'ALL_DAY',
    targetHubs: ['all'],
    title: 'Value Picks',
    subtitle: 'Save more on your daily essentials',
    items: [
      {
        id: 'atta-value-1kg',
        productId: null,
        keywords: ['atta 1kg', '1 kg atta', 'atta'],
        perUnitLabel: '₹60/kg',
        fallbackName: 'Atta',
        fallbackUnit: '1 kg',
        fallbackPrice: 60,
        fallbackMrp: 68,
        fallbackImage: '/navratri/ref-atta-1kg.png',
      },
      {
        id: 'atta-value-5kg',
        productId: null,
        keywords: ['atta 5kg', '5 kg atta', '5kg', 'aashirvaad 5'],
        badge: 'Better value',
        perUnitLabel: '₹50/kg',
        fallbackName: 'Atta 5kg',
        fallbackUnit: '5 kg',
        fallbackPrice: 250,
        fallbackMrp: 295,
        fallbackImage: '/navratri/ref-atta-5kg.png',
      },
    ],
  },
  giftingBoutique: {
    enabled: true,
    sortOrder: 4,
    badge: '04',
    backgroundColor: '#FDF2F4',
    borderColor: '#FCE7F3',
    accentColor: '#15803D',
    textColor: '#831843',
    minInStockItems: 1,
    scheduleEnabled: false,
    startDate: null,
    endDate: null,
    timeSlot: 'ALL_DAY',
    targetHubs: ['all'],
    title: 'Gifting Boutique',
    subtitle: 'Thoughtful gifts for special occasions',
    heroItem: {
      id: 'rose-bouquet',
      productId: null,
      keywords: ['rose', 'bouquet', 'flower', 'gift box', 'ferrero', 'celebrations'],
      fallbackName: 'Rose bouquet',
      fallbackUnit: '8 stems',
      fallbackPrice: 399,
      fallbackMrp: 499,
      fallbackImage: '/navratri/ref-rose-bouquet.png',
    },
    miniItem: {
      id: 'choco-cake',
      productId: null,
      keywords: ['chocolate cake', 'cake', 'dairy milk', 'silk', 'chocolate'],
      fallbackName: 'Chocolate cake',
      fallbackUnit: '500 g',
      fallbackPrice: 499,
      fallbackMrp: 599,
      fallbackImage: '/navratri/ref-chocolate-cake.png',
    },
    occasions: [
      { id: 'birthday', label: 'Birthday', icon: '🎂' },
      { id: 'anniversary', label: 'Anniversary', icon: '🤍' },
    ],
  },
  movieNight: {
    enabled: false,
    sortOrder: 5,
    badge: '05',
    backgroundColor: '#251640',
    borderColor: '#382458',
    accentColor: '#15803D',
    textColor: '#FFFFFF',
    minInStockItems: 1,
    scheduleEnabled: false,
    startDate: null,
    endDate: null,
    timeSlot: 'EVENING',
    targetHubs: ['all'],
    title: 'Movie Night',
    subtitle: 'Snacks for the perfect watch time',
    heroImage: '/navratri/ref-movie-cinema-scene.png',
    items: [
      {
        id: 'popcorn-movie',
        productId: null,
        keywords: ['popcorn', 'act ii', 'corn'],
        fallbackName: 'Popcorn',
        fallbackUnit: '60 g',
        fallbackPrice: 40,
        fallbackMrp: 45,
        fallbackImage: '/navratri/movie-popcorn.svg',
      },
      {
        id: 'chips-movie',
        productId: null,
        keywords: ['chips', 'lays', 'kurkure', 'bingo', 'uncle chipps'],
        fallbackName: 'Chips',
        fallbackUnit: '52 g',
        fallbackPrice: 20,
        fallbackMrp: 20,
        fallbackImage: '/navratri/vrat-chips.svg',
      },
      {
        id: 'cola-movie',
        productId: null,
        keywords: ['cola', 'coca', 'pepsi', 'thums up', 'sprite', 'coke'],
        fallbackName: 'Cola',
        fallbackUnit: '750 ml',
        fallbackPrice: 35,
        fallbackMrp: 45,
        fallbackImage: '/navratri/chilled-cola.svg',
      },
    ],
  },
  breakfastClub: {
    enabled: false,
    sortOrder: 6,
    badge: '06',
    backgroundColor: '#FFF8F0',
    borderColor: '#FEE6D1',
    accentColor: '#15803D',
    textColor: '#9A3412',
    minInStockItems: 1,
    scheduleEnabled: false,
    startDate: null,
    endDate: null,
    timeSlot: 'MORNING',
    targetHubs: ['all'],
    title: 'Breakfast Club',
    subtitle: 'Your quick breakfast list',
    heroImage: '/navratri/ref-breakfast-toast.png',
    items: [
      {
        id: 'bread',
        productId: null,
        keywords: ['bread', 'brown bread', 'sandwich'],
        checkedByDefault: true,
        fallbackName: 'Bread',
        fallbackUnit: '400 g',
        fallbackPrice: 45,
        fallbackMrp: 50,
        fallbackImage: '/navratri/daily-bread.svg',
      },
      {
        id: 'butter',
        productId: null,
        keywords: ['butter', 'amul butter', 'cheese'],
        checkedByDefault: false,
        fallbackName: 'Butter',
        fallbackUnit: '100 g',
        fallbackPrice: 60,
        fallbackMrp: 65,
        fallbackImage: '/navratri/table-butter.svg',
      },
      {
        id: 'milk',
        productId: null,
        keywords: ['milk', 'taaza', 'doodh', 'amul'],
        checkedByDefault: true,
        fallbackName: 'Milk',
        fallbackUnit: '500 ml',
        fallbackPrice: 30,
        fallbackMrp: 32,
        fallbackImage: '/navratri/daily-milk.svg',
      },
    ],
  },
}

export function parseCampaignBentoConfig(input: unknown): CampaignBentoConfig {
  const parsed = campaignBentoConfigSchema.safeParse(input)
  if (parsed.success) return parsed.data
  return structuredClone(defaultCampaignBentoConfig)
}

export interface BentoCardVisibilityCheck {
  enabled: boolean
  sortOrder?: number
  minInStockItems?: number
  scheduleEnabled?: boolean
  startDate?: string | null
  endDate?: string | null
  timeSlot?: BentoTimeSlot
  targetHubs?: string[]
}

export function isBentoCardVisible(
  card: BentoCardVisibilityCheck,
  context: {
    inStockCount: number
    currentStoreId?: string | null
    referenceDate?: Date
  }
): { isVisible: boolean; reason?: string } {
  if (!card.enabled) {
    return { isVisible: false, reason: 'Card manually disabled by admin' }
  }

  // Hub target check
  if (card.targetHubs && card.targetHubs.length > 0 && !card.targetHubs.includes('all')) {
    if (context.currentStoreId && !card.targetHubs.includes(context.currentStoreId)) {
      return { isVisible: false, reason: `Not targeted to hub ${context.currentStoreId}` }
    }
  }

  // Minimum in-stock items threshold
  const minRequired = card.minInStockItems ?? 1
  if (minRequired > 0 && context.inStockCount < minRequired) {
    return {
      isVisible: false,
      reason: `In-stock items (${context.inStockCount}) below required minimum (${minRequired})`,
    }
  }

  // Schedule check (IST timezone)
  if (card.scheduleEnabled) {
    const now = context.referenceDate ?? new Date()
    // Convert to IST offset (+5:30)
    const istOffset = 5.5 * 60 * 60 * 1000
    const istDate = new Date(now.getTime() + istOffset + now.getTimezoneOffset() * 60000)

    if (card.startDate) {
      const start = new Date(card.startDate)
      if (now < start) {
        return { isVisible: false, reason: 'Campaign schedule has not started yet' }
      }
    }

    if (card.endDate) {
      const end = new Date(card.endDate)
      if (now > end) {
        return { isVisible: false, reason: 'Campaign schedule has ended' }
      }
    }

    if (card.timeSlot && card.timeSlot !== 'ALL_DAY') {
      const hours = istDate.getHours()
      const minutes = istDate.getMinutes()
      const timeInHours = hours + minutes / 60

      switch (card.timeSlot) {
        case 'MORNING': // 06:00 to 11:30
          if (timeInHours < 6 || timeInHours >= 11.5) {
            return { isVisible: false, reason: 'Active only in morning (06:00 - 11:30 AM)' }
          }
          break
        case 'AFTERNOON': // 11:30 to 17:00
          if (timeInHours < 11.5 || timeInHours >= 17) {
            return { isVisible: false, reason: 'Active only in afternoon (11:30 AM - 05:00 PM)' }
          }
          break
        case 'EVENING': // 17:00 to 22:00
          if (timeInHours < 17 || timeInHours >= 22) {
            return { isVisible: false, reason: 'Active only in evening (05:00 PM - 10:00 PM)' }
          }
          break
        case 'NIGHT': // 22:00 to 06:00
          if (timeInHours >= 6 && timeInHours < 22) {
            return { isVisible: false, reason: 'Active only in night (10:00 PM - 06:00 AM)' }
          }
          break
      }
    }
  }

  return { isVisible: true }
}

export function collectBentoSlotItems(config: CampaignBentoConfig): BentoSlotItem[] {
  return [
    ...config.freshMarket.tabs.flatMap((tab) => tab.items),
    ...config.dailyRestock.items,
    ...config.valuePicks.items,
    config.giftingBoutique.heroItem,
    config.giftingBoutique.miniItem,
    ...config.movieNight.items,
    ...config.breakfastClub.items,
  ]
}

export function collectBentoProductIds(config: CampaignBentoConfig): string[] {
  return [
    ...new Set(
      collectBentoSlotItems(config)
        .map((slot) => slot.productId)
        .filter((pid): pid is string => typeof pid === 'string' && pid.trim().length > 0)
    ),
  ]
}

export function computePerUnitLabel(price: number, unit: string): string | null {
  if (!Number.isFinite(price) || price <= 0 || !unit) return null
  const normalized = unit.trim().toLowerCase()
  const kgMatch = normalized.match(/^(\d+(?:\.\d+)?)\s*kg$/)
  if (kgMatch) {
    const qty = Number(kgMatch[1])
    if (qty > 0) return `₹${Math.round(price / qty)}/kg`
  }
  const gMatch = normalized.match(/^(\d+(?:\.\d+)?)\s*(?:g|gm|gms)$/)
  if (gMatch) {
    const grams = Number(gMatch[1])
    if (grams >= 100) return `₹${Math.round((price * 1000) / grams)}/kg`
  }
  const lMatch = normalized.match(/^(\d+(?:\.\d+)?)\s*(?:l|ltr)$/)
  if (lMatch) {
    const litres = Number(lMatch[1])
    if (litres > 0) return `₹${Math.round(price / litres)}/L`
  }
  const mlMatch = normalized.match(/^(\d+(?:\.\d+)?)\s*ml$/)
  if (mlMatch) {
    const ml = Number(mlMatch[1])
    if (ml >= 200) return `₹${Math.round((price * 1000) / ml)}/L`
  }
  return null
}

function normalizeTokens(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
}

function scoreProductForSlot(slot: BentoSlotItem, product: Product): number {
  if (product.restaurantId) return -1
  const keywords = [
    ...(slot.keywords ?? []),
    slot.fallbackName,
  ]
    .map((k) => k.trim().toLowerCase())
    .filter(Boolean)
  if (keywords.length === 0) return -1

  const nameLower = (product.name ?? '').toLowerCase()
  const unitLower = (product.unit ?? '').toLowerCase().replace(/\s+/g, '')
  const fallbackUnitCompact = slot.fallbackUnit.toLowerCase().replace(/\s+/g, '')
  const haystack = [
    product.name,
    product.slug,
    product.unit,
    product.category?.name,
    ...(product.tags ?? []),
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
  const tokens = normalizeTokens(haystack)
  const nameTokens = normalizeTokens(nameLower)

  let bestKeywordScore = 0
  for (let i = 0; i < keywords.length; i++) {
    const kw = keywords[i]
    const kwTokens = normalizeTokens(kw)
    if (kwTokens.length === 0) continue

    const exactPhraseInName = nameLower.includes(kw)
    const allTokensInName = kwTokens.every((part) =>
      nameTokens.some((tok) => tok === part || tok.startsWith(part))
    )
    const allTokensInHaystack = kwTokens.every((part) =>
      tokens.some((tok) => tok === part || tok.startsWith(part))
    )

    if (!exactPhraseInName && !allTokensInName && !allTokensInHaystack) continue

    // Earlier keywords carry slightly higher priority
    const priorityBoost = Math.max(0, 12 - i * 2)
    let score = 20 + priorityBoost
    if (exactPhraseInName) score += 25
    else if (allTokensInName) score += 15
    if (nameLower === kw) score += 20
    bestKeywordScore = Math.max(bestKeywordScore, score)
  }

  if (bestKeywordScore === 0) return -1

  // Prefer matching unit hint (e.g. 5 kg vs 1 kg atta)
  if (fallbackUnitCompact && unitLower && unitLower === fallbackUnitCompact) {
    bestKeywordScore += 18
  } else if (fallbackUnitCompact && unitLower.includes(fallbackUnitCompact)) {
    bestKeywordScore += 10
  }

  // Prefer in-stock and available products strongly
  if (product.isAvailable && product.stock > 0) {
    bestKeywordScore += 30
  } else if (!product.isAvailable) {
    bestKeywordScore -= 25
  }

  return bestKeywordScore
}

/** Deterministically find the best matching real grocery product for a bento slot */
export function autoMatchBentoProduct(slot: BentoSlotItem, products: Product[]): Product | null {
  let best: Product | null = null
  let bestScore = 0
  for (const product of products) {
    const score = scoreProductForSlot(slot, product)
    if (score > bestScore) {
      bestScore = score
      best = product
    }
  }
  return best
}

/** Populate `productId` on slots in config where a clear catalogue match exists */
export function autoLinkBentoConfigProducts(
  config: CampaignBentoConfig,
  products: Product[],
  options: { overwriteExisting?: boolean } = {}
): { config: CampaignBentoConfig; matchedCount: number; totalSlots: number } {
  let matchedCount = 0
  let totalSlots = 0

  const linkSlot = (slot: BentoSlotItem): BentoSlotItem => {
    totalSlots += 1
    if (slot.productId && !options.overwriteExisting) {
      const stillExists = products.some((p) => p.id === slot.productId && !p.restaurantId)
      if (stillExists) {
        matchedCount += 1
        return slot
      }
    }
    const matched = autoMatchBentoProduct(slot, products)
    if (matched) {
      matchedCount += 1
      return { ...slot, productId: matched.id }
    }
    return slot
  }

  const next: CampaignBentoConfig = {
    ...config,
    freshMarket: {
      ...config.freshMarket,
      tabs: config.freshMarket.tabs.map((tab) => ({
        ...tab,
        items: tab.items.map(linkSlot),
      })),
    },
    dailyRestock: {
      ...config.dailyRestock,
      items: config.dailyRestock.items.map(linkSlot),
    },
    valuePicks: {
      ...config.valuePicks,
      items: config.valuePicks.items.map(linkSlot),
    },
    giftingBoutique: {
      ...config.giftingBoutique,
      heroItem: linkSlot(config.giftingBoutique.heroItem),
      miniItem: linkSlot(config.giftingBoutique.miniItem),
    },
    movieNight: {
      ...config.movieNight,
      items: config.movieNight.items.map(linkSlot),
    },
    breakfastClub: {
      ...config.breakfastClub,
      items: config.breakfastClub.items.map(linkSlot),
    },
  }

  return { config: next, matchedCount, totalSlots }
}

export interface ResolvedBentoSlot {
  slotId: string
  product: Product | null
  isLinked: boolean
  isExplicitLink: boolean
  inStock: boolean
  name: string
  unit: string
  price: number
  mrp: number
  imageUrl: string
  badge: string | null
  perUnitLabel: string | null
}

export function resolveBentoSlotProduct(
  slot: BentoSlotItem,
  products: Product[],
  options: { allowAutoMatch?: boolean } = {}
): ResolvedBentoSlot {
  const allowAutoMatch = options.allowAutoMatch ?? true
  const explicitProduct = slot.productId
    ? products.find((p) => p.id === slot.productId && !p.restaurantId) ?? null
    : null
  const matchedProduct =
    explicitProduct ?? (allowAutoMatch ? autoMatchBentoProduct(slot, products) : null)

  const product = matchedProduct
  const price = product ? product.price : slot.fallbackPrice
  const mrp = product
    ? Math.max(product.mrp ?? product.price, product.price)
    : Math.max(slot.fallbackMrp ?? Math.round(slot.fallbackPrice * 1.2), slot.fallbackPrice)
  const unit = product?.unit || slot.fallbackUnit
  const name = slot.customTitle?.trim() || product?.name || slot.fallbackName
  const imageUrl =
    product?.imageUrl && product.imageUrl.trim().length > 0
      ? product.imageUrl
      : slot.fallbackImage
  const inStock = product ? product.isAvailable !== false && product.stock > 0 : true
  const autoPerUnit = product ? computePerUnitLabel(price, unit) : null

  return {
    slotId: slot.id,
    product,
    isLinked: Boolean(product),
    isExplicitLink: Boolean(explicitProduct),
    inStock,
    name,
    unit,
    price,
    mrp,
    imageUrl,
    badge: slot.badge ?? null,
    perUnitLabel: slot.perUnitLabel?.trim() || autoPerUnit,
  }
}
