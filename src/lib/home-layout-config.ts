import { z } from 'zod'

export const homeSectionIdSchema = z.enum([
  'diwali_campaign',
  'hero_banners',
  'top_categories',
  'bento_gifting',
  'bento_fresh_market',
  'bento_seasonal',
  'bento_daily_restock',
  'bento_value_picks',
  'campaign_bento',
  'product_sections',
])

export type HomeSectionId = z.infer<typeof homeSectionIdSchema>

export const homeSectionConfigSchema = z.object({
  id: homeSectionIdSchema,
  label: z.string(),
  description: z.string().default(''),
  enabled: z.boolean().default(true),
  sortOrder: z.number().default(0),
})

export type HomeSectionConfig = z.infer<typeof homeSectionConfigSchema>

export const homeLayoutConfigSchema = z.object({
  sections: z.array(homeSectionConfigSchema),
})

export type HomeLayoutConfig = z.infer<typeof homeLayoutConfigSchema>

export const DEFAULT_HOME_LAYOUT: HomeLayoutConfig = {
  sections: [
    {
      id: 'diwali_campaign',
      label: '🪔 Diwali / Festive Campaign Section',
      description: 'Diwali Mahotsav specials, clay diyas, Lakshmi pooja kits & festive sweets.',
      enabled: true,
      sortOrder: 1,
    },
    {
      id: 'hero_banners',
      label: '🖼️ Hero Promo Banners Carousel',
      description: 'Rotating discount billboards, bank offers & darkstore promos.',
      enabled: true,
      sortOrder: 2,
    },
    {
      id: 'top_categories',
      label: '📦 Top Category Icons Grid',
      description: 'Fast circular & squircle category tiles (Dairy, Veggies, Snacks, Atta).',
      enabled: true,
      sortOrder: 3,
    },
    {
      id: 'bento_gifting',
      label: '🎁 Bento: Gifting Boutique & Hampers',
      description: 'Curated gift hampers, celebratory boxes & luxury gifting card.',
      enabled: true,
      sortOrder: 4,
    },
    {
      id: 'bento_fresh_market',
      label: '🥬 Bento: Fresh Market (Bloom)',
      description: 'Farm-fresh hydroponics, daily vegetables, fruits & herbs.',
      enabled: true,
      sortOrder: 5,
    },
    {
      id: 'bento_seasonal',
      label: '🧴 Bento: Seasonal Switch-Up',
      description: 'Winter skin care, cold creams, body lotions & wellness picks.',
      enabled: true,
      sortOrder: 6,
    },
    {
      id: 'bento_daily_restock',
      label: '🛒 Bento: Daily Restock',
      description: 'Morning essentials, bread, milk, eggs & kitchen pantry restock.',
      enabled: true,
      sortOrder: 7,
    },
    {
      id: 'bento_value_picks',
      label: '🏷️ Bento: Value Picks',
      description: 'Budget-friendly combos, mega savings & clearance steals.',
      enabled: true,
      sortOrder: 8,
    },
    {
      id: 'product_sections',
      label: '🥛 Product Feed (Dairy, Snacks & Daily Staples)',
      description: 'Horizontal product carousels & vertical infinite grocery feed.',
      enabled: true,
      sortOrder: 9,
    },
  ],
}
