import { z } from 'zod'

const id = z
  .string()
  .trim()
  .min(1)
  .max(128)
  .regex(/^[a-zA-Z0-9_-]+$/)
const copy = z.string().max(200)
const keywords = z.array(z.string().trim().min(1).max(80)).max(40)
const colour = z.string().regex(/^#[0-9a-fA-F]{6}$/, 'Use a six-digit hex colour')
export const campaignImageSchema = z
  .string()
  .max(2048)
  .refine((value) => {
    if (/[\u0000-\u001f\\]/.test(value)) return false
    try {
      const decoded = decodeURIComponent(value)
      if (
        decoded.includes('\\') ||
        decoded.split('/').some((part) => part === '..' || part === '.')
      )
        return false
    } catch {
      return false
    }
    if (!value.startsWith('https://') && value.includes('..')) return false
    if (/^[\w.-]+\.(svg|png|jpe?g|webp|avif)$/i.test(value)) return true
    if (/^\/(?!\/)[\w/%.@-]+\.(svg|png|jpe?g|webp|avif)$/i.test(value)) return !value.includes('..')
    try {
      const url = new URL(value)
      return url.protocol === 'https:' && Boolean(url.hostname) && !url.username && !url.password
    } catch {
      return false
    }
  }, 'Choose a local image or an HTTPS image URL')

export const campaignLabels = {
  sectionLabel: 'Celebrate Navratri',
  specialsHeading: 'Navratri Specials',
  curvedTabLabel: 'Top Picks',
  loadingText: 'Loading this store’s festive picks…',
  emptyText:
    'No matching products in this collection yet. Try another tab or search the catalogue.',
  demoLabel: 'Demo prices',
  resultsDemoLabel: 'Demo collection · illustrative prices',
}
export const campaignAppearance = {
  background: '#FF831F',
  card: '#FFF8DF',
  text: '#985F39',
  smallText: '#5E2E16',
  headerText: '#FFF8DF',
  headerOutline: '#713D21',
  underline: '#832F27',
  tabSurface: '#FFF8DF',
}

const product = z
  .object({
    id,
    name: copy.min(1),
    image: campaignImageSchema,
    originalPrice: z.number().finite().nonnegative(),
    price: z.number().finite().nonnegative(),
    currency: z.literal('INR'),
    categoryId: id,
    destinationId: id,
    productId: id.optional(),
  })
  .strict()
  .refine((value) => value.price <= value.originalPrice, {
    message: 'Sale price cannot exceed the original price',
    path: ['price'],
  })

export const campaignMotionSchema = z
  .object({
    preset: z.enum(['none', 'fade', 'slide', 'float', 'zoom', 'sparkle']).default('fade'),
    speed: z.enum(['slow', 'normal', 'fast']).default('normal'),
  })
  .strict()

export const campaignBlockSchema = z
  .object({
    id,
    type: z.enum(['banner', 'categories', 'spotlight', 'collection', 'image', 'text']),
    enabled: z.boolean().default(true),
    title: copy.default(''),
    body: z.string().max(500).default(''),
    image: campaignImageSchema.nullable().default(null),
    destinationId: id.nullable().default(null),
    itemIds: z.array(id).max(12).default([]),
    tabId: id.nullable().default(null),
    presentation: z.enum(['wide', 'grid', 'row', 'offer', 'plain']).default('wide'),
    motion: campaignMotionSchema.default({ preset: 'fade', speed: 'normal' }),
  })
  .strict()

export const campaignSchema = z
  .object({
    version: z.literal(1),
    layout: z.enum(['classic', 'banner', 'split', 'grid', 'deals']).default('classic'),
    composition: z.enum(['template', 'blocks']).default('template'),
    blocks: z.array(campaignBlockSchema).max(16).default([]),
    demo: z.boolean(),
    enabled: z.boolean().default(true),
    autoplay: z.boolean().default(true),
    searchPrefix: copy.min(1).default('Search for'),
    decorationImage: campaignImageSchema.nullable().default('string-lights.svg'),
    labels: z
      .object({
        sectionLabel: copy.min(1),
        specialsHeading: copy.min(1),
        curvedTabLabel: copy.min(1),
        loadingText: copy.min(1),
        emptyText: z.string().min(1).max(500),
        demoLabel: copy.min(1),
        resultsDemoLabel: copy.min(1),
      })
      .strict()
      .default(campaignLabels),
    appearance: z
      .object({
        background: colour,
        card: colour,
        text: colour,
        smallText: colour,
        headerText: colour,
        headerOutline: colour,
        underline: colour,
        tabSurface: colour,
      })
      .strict()
      .default(campaignAppearance),
    timings: z
      .object({
        headerMs: z.number().int().min(1500).max(60000),
        productMs: z.number().int().min(1500).max(60000),
        searchMs: z.number().int().min(1500).max(60000),
        crossfadeMs: z.number().int().min(0).max(1200),
      })
      .strict(),
    searchSuggestions: z.array(copy.min(1)).min(1).max(12),
    navigation: z
      .array(z.object({ id, label: copy.min(1), destinationId: id.nullable() }).strict())
      .max(12)
      .default([]),
    headers: z
      .array(
        z
          .object({
            id,
            kind: z.enum(['illustration', 'title', 'brand']),
            eyebrow: copy,
            title: copy.min(1),
            subtitle: copy,
            image: campaignImageSchema.nullable(),
          })
          .strict()
      )
      .min(1)
      .max(8),
    products: z.array(product).min(1).max(12),
    categories: z
      .array(
        z
          .object({
            id,
            label: copy.min(1),
            image: campaignImageSchema,
            destinationId: id,
            keywords,
          })
          .strict()
      )
      .length(4),
    tabs: z
      .array(
        z
          .object({
            id,
            label: copy.min(1),
            image: campaignImageSchema,
            keywords,
            productIds: z.array(z.string().trim().min(1)).max(40).optional().default([]),
          })
          .strict()
      )
      .min(1)
      .max(8),
    destinations: z
      .array(z.object({ id, kind: z.literal('search'), query: copy }).strict())
      .min(1)
      .max(80),
  })
  .strict()
  .superRefine((campaign, context) => {
    for (const collection of [
      'headers',
      'products',
      'categories',
      'tabs',
      'destinations',
      'navigation',
    ] as const) {
      const ids = campaign[collection].map((value) => value.id)
      if (new Set(ids).size !== ids.length)
        context.addIssue({ code: 'custom', path: [collection], message: 'IDs must be unique' })
    }
    const destinations = new Set(campaign.destinations.map((value) => value.id))
    const blockIds = campaign.blocks.map((block) => block.id)
    if (new Set(blockIds).size !== blockIds.length)
      context.addIssue({ code: 'custom', path: ['blocks'], message: 'Block IDs must be unique' })
    if (campaign.composition === 'blocks' && !campaign.blocks.some((block) => block.enabled))
      context.addIssue({
        code: 'custom',
        path: ['blocks'],
        message: 'Add at least one visible block',
      })
    const presentations = {
      banner: ['wide'],
      categories: ['grid', 'row'],
      spotlight: ['wide', 'offer'],
      collection: ['grid', 'row'],
      image: ['wide'],
      text: ['plain'],
    }
    campaign.blocks.forEach((block, index) => {
      const issue = (field: string, message: string) =>
        context.addIssue({ code: 'custom', path: ['blocks', index, field], message })
      if (!presentations[block.type].includes(block.presentation))
        issue('presentation', 'Choose a presentation supported by this block')
      if (block.destinationId && !destinations.has(block.destinationId))
        issue('destinationId', 'Choose an existing destination')
      if (new Set(block.itemIds).size !== block.itemIds.length)
        issue('itemIds', 'Choose each item only once')
      const source =
        block.type === 'banner'
          ? campaign.headers
          : block.type === 'categories'
            ? campaign.categories
            : block.type === 'spotlight'
              ? campaign.products
              : []
      const available = new Set(source.map((item) => item.id))
      if (block.itemIds.some((item) => !available.has(item)))
        issue('itemIds', 'Choose existing items for this block')
      if (block.type === 'collection') {
        if (!campaign.tabs.some((tab) => tab.id === block.tabId))
          issue('tabId', 'Choose an existing collection')
      } else if (block.tabId) issue('tabId', 'Only collection blocks use a collection')
      if (block.type === 'image' && !block.image) issue('image', 'Image banners need artwork')
      if (block.type === 'text' && !block.title.trim() && !block.body.trim())
        issue('title', 'Text blocks need a heading or message')
      if (block.type === 'text' && !['none', 'fade', 'slide'].includes(block.motion.preset))
        issue('motion', 'Text blocks support no effect, soft fade, or slide in')
    })
    campaign.headers.forEach((slide, index) => {
      if (slide.kind !== 'title' && !slide.image)
        context.addIssue({
          code: 'custom',
          path: ['headers', index, 'image'],
          message:
            'Illustration and brand slides need an image; use the title style for text-only slides',
        })
    })
    const categories = new Set(campaign.categories.map((value) => value.id))
    for (const collection of ['products', 'categories', 'navigation'] as const) {
      campaign[collection].forEach((item, index) => {
        if (item.destinationId && !destinations.has(item.destinationId))
          context.addIssue({
            code: 'custom',
            path: [collection, index, 'destinationId'],
            message: 'Choose an existing destination',
          })
      })
    }
    campaign.products.forEach((item, index) => {
      if (!categories.has(item.categoryId))
        context.addIssue({
          code: 'custom',
          path: ['products', index, 'categoryId'],
          message: 'Choose an existing card category',
        })
      const displayed =
        campaign.composition === 'template' ||
        campaign.blocks.some(
          (block) =>
            block.enabled &&
            block.type === 'spotlight' &&
            (!block.itemIds.length || block.itemIds.includes(item.id))
        )
      if (!campaign.demo && displayed && !item.productId)
        context.addIssue({
          code: 'custom',
          path: ['products', index, 'productId'],
          message:
            'Live campaigns must link every displayed promotional card to a catalogue product',
        })
    })
  })

export type CampaignConfig = z.infer<typeof campaignSchema>
export type CampaignBlock = z.infer<typeof campaignBlockSchema>
export type CampaignMotion = z.infer<typeof campaignMotionSchema>
export const parseCampaignConfig = (value: unknown): CampaignConfig => campaignSchema.parse(value)
