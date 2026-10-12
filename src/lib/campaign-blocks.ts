import type { CampaignBlock, CampaignConfig, CampaignMotion } from './campaign-config'

export const campaignBlockTypes = [
  {
    id: 'banner',
    name: 'Rotating banner',
    description: 'Header slides with editable artwork and copy.',
  },
  {
    id: 'categories',
    name: 'Category tiles',
    description: 'Choose category cards and arrange them in a grid or row.',
  },
  {
    id: 'spotlight',
    name: 'Product spotlight',
    description: 'Rotate linked catalogue products or labelled demo examples.',
  },
  {
    id: 'collection',
    name: 'Collection shelf',
    description: 'Show products from one of your configured collections.',
  },
  {
    id: 'image',
    name: 'Image banner',
    description: 'Upload artwork and optionally link it to catalogue search.',
  },
  {
    id: 'text',
    name: 'Text message',
    description: 'Add a heading and a short message between shopping blocks.',
  },
] as const

export const campaignMotionPresets = [
  { id: 'none', name: 'No effect' },
  { id: 'fade', name: 'Soft fade' },
  { id: 'slide', name: 'Slide in' },
  { id: 'float', name: 'Floating artwork' },
  { id: 'zoom', name: 'Gentle zoom' },
  { id: 'sparkle', name: 'Sparkle' },
] as const

export const blockPresentations: Record<
  CampaignBlock['type'],
  { id: CampaignBlock['presentation']; name: string }[]
> = {
  banner: [{ id: 'wide', name: 'Wide banner' }],
  categories: [
    { id: 'grid', name: 'Tile grid' },
    { id: 'row', name: 'Scrolling row' },
  ],
  spotlight: [
    { id: 'wide', name: 'Product strip' },
    { id: 'offer', name: 'Large price spotlight' },
  ],
  collection: [
    { id: 'row', name: 'Product shelf' },
    { id: 'grid', name: 'Product grid' },
  ],
  image: [{ id: 'wide', name: 'Wide artwork' }],
  text: [{ id: 'plain', name: 'Heading and message' }],
}

export function createCampaignBlock(
  type: CampaignBlock['type'],
  data: CampaignConfig,
  id: string
): CampaignBlock {
  return {
    id,
    type,
    enabled: true,
    title: type === 'text' ? 'Your campaign message' : '',
    body: '',
    image:
      type === 'image'
        ? (data.headers.find((header) => header.image)?.image ?? data.categories[0].image)
        : null,
    destinationId: null,
    itemIds: [],
    tabId: type === 'collection' ? data.tabs[0].id : null,
    presentation: blockPresentations[type][0].id,
    motion: { preset: 'fade', speed: 'normal' },
  }
}

export function defaultCampaignBlocks(data: CampaignConfig): CampaignBlock[] {
  const banner = createCampaignBlock('banner', data, 'block-banner')
  const categories = createCampaignBlock('categories', data, 'block-categories')
  const spotlight = createCampaignBlock('spotlight', data, 'block-spotlight')
  const collection = createCampaignBlock('collection', data, 'block-collection')
  categories.presentation = ['banner', 'deals'].includes(data.layout) ? 'row' : 'grid'
  spotlight.presentation = data.layout === 'deals' ? 'offer' : 'wide'
  return [
    banner,
    ...(['split', 'grid'].includes(data.layout)
      ? [categories, spotlight]
      : [spotlight, categories]),
    collection,
  ]
}

export function campaignBlockItems<T extends { id: string }>(items: T[], selected: string[]): T[] {
  if (!selected.length) return items
  const byId = new Map(items.map((item) => [item.id, item]))
  return selected.flatMap((id) => {
    const item = byId.get(id)
    return item ? [item] : []
  })
}

export function campaignMotionInterval(milliseconds: number, motion: CampaignMotion): number {
  const factor = motion.speed === 'slow' ? 1.5 : motion.speed === 'fast' ? 0.65 : 1
  return Math.max(1500, Math.min(60000, Math.round(milliseconds * factor)))
}
