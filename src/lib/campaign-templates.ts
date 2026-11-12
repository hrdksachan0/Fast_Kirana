import premium0 from '../../public/navratri/templates/fresh-market.json'
import premium1 from '../../public/navratri/templates/daily-restock.json'
import premium2 from '../../public/navratri/templates/pack-value.json'
import premium3 from '../../public/navratri/templates/gifting-boutique.json'
import premium4 from '../../public/navratri/templates/movie-night.json'
import premium5 from '../../public/navratri/templates/breakfast-club.json'
import navratri from '../../public/navratri/navratri.json'
import metadata from '../../public/navratri/templates/index.json'
import diwali from '../../public/navratri/templates/diwali.json'
import holi from '../../public/navratri/templates/holi.json'
import ramadan from '../../public/navratri/templates/ramadan.json'
import dailyEssentials from '../../public/navratri/templates/daily-essentials.json'
import valuePicks from '../../public/navratri/templates/value-picks.json'
import summer from '../../public/navratri/templates/summer.json'
import monsoon from '../../public/navratri/templates/monsoon.json'
import { parseCampaignConfig, type CampaignConfig } from './campaign-config'

export const campaignTemplateGroups = ['Festival', 'Everyday', 'Value', 'Seasonal'] as const
export type CampaignTemplateType = (typeof campaignTemplateGroups)[number]
export interface CampaignTemplate {
  id: string
  name: string
  type: CampaignTemplateType
  description: string
  thumbnail: string
  config: CampaignConfig
}

const configs: Record<string, unknown> = {
  'fresh-market': premium0,
  'daily-restock': premium1,
  'pack-value': premium2,
  'gifting-boutique': premium3,
  'movie-night': premium4,
  'breakfast-club': premium5,
  navratri,
  diwali,
  holi,
  ramadan,
  'daily-essentials': dailyEssentials,
  'value-picks': valuePicks,
  summer,
  monsoon,
}

export const campaignLayouts = [
  {
    id: 'classic',
    name: 'Festive mosaic',
    description: 'A tall rotating product beside four category cards.',
  },
  {
    id: 'banner',
    name: 'Wide banner',
    description:
      'A large illustrated header, horizontal product spotlight and scrolling categories.',
  },
  {
    id: 'split',
    name: 'Split spotlight',
    description: 'Two large category spotlights, two compact cards and a product strip.',
  },
  {
    id: 'grid',
    name: 'Category grid',
    description: 'Four equally sized shopping categories with a product strip below.',
  },
  {
    id: 'deals',
    name: 'Offer shelf',
    description: 'A prominent rotating product and price, followed by compact shopping categories.',
  },
] as const satisfies ReadonlyArray<{
  id: CampaignConfig['layout']
  name: string
  description: string
}>

export const campaignTemplates: CampaignTemplate[] = metadata.map((entry) => {
  if (!campaignTemplateGroups.some((group) => group === entry.type)) {
    throw new Error(`Unknown campaign template type: ${entry.type}`)
  }
  return {
    id: entry.id,
    name: entry.name,
    type: entry.type as CampaignTemplateType,
    description: entry.description,
    thumbnail: entry.thumbnail,
    config: parseCampaignConfig(configs[entry.id]),
  }
})

/** Each load gets its own editable copy; changing it cannot alter another draft. */
export function createCampaignFromTemplate(id: string): CampaignConfig {
  const template = campaignTemplates.find((entry) => entry.id === id)
  if (!template) throw new RangeError(`Unknown campaign template: ${id}`)
  return structuredClone(template.config)
}
