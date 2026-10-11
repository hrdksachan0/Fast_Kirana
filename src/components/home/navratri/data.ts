import content from '../../../../public/navratri/navratri.json'
import type { Product } from '@/types'
import { campaignImageSchema, parseCampaignConfig, type CampaignConfig } from '@/lib/campaign-config'

export interface NavratriDestination {
  id: string
  kind: 'search'
  query: string
}
export interface NavratriHeader {
  id: string
  kind: 'illustration' | 'title' | 'brand'
  eyebrow: string
  title: string
  subtitle: string
  image: string | null
}
export interface NavratriProduct {
  id: string
  name: string
  image: string
  originalPrice: number
  price: number
  currency: 'INR'
  categoryId: string
  destinationId: string
  productId?: string
}
export interface NavratriCategory {
  id: string
  label: string
  image: string
  destinationId: string
  keywords: string[]
}
export interface NavratriTab {
  id: string
  label: string
  image: string
  keywords: string[]
}
export type NavratriData = CampaignConfig

export const navratriData = parseCampaignConfig(content)
export const navratriAsset = (image: string) =>
  image.startsWith('/') || image.startsWith('https://') ? image : `/navratri/${image}`
export const navratriPrice = (price: number) => `₹${price.toLocaleString('en-IN')}`

/** Match word starts: flower finds flowers, while diya never finds dandiya. */
export function matchesNavratriKeywords(text: string, keywords: string[]): boolean {
  const words = text
    .toLocaleLowerCase()
    .split(/[\s\-_/.,&()]+/)
    .filter(Boolean)
  return keywords.some((keyword) => {
    const parts = keyword
      .toLocaleLowerCase()
      .split(/[\s\-_/.,&()]+/)
      .filter(Boolean)
    return (
      parts.length > 0 &&
      words.some((_, start) =>
        parts.every((part, offset) => words[start + offset]?.startsWith(part))
      )
    )
  })
}

export function destinationHref(id: string | null, data = navratriData): string {
  const destination = data.destinations.find((item) => item.id === id)
  return destination ? `/search?q=${encodeURIComponent(destination.query)}` : '/'
}

export function filterNavratriProducts(
  products: Product[],
  keywords: string[],
  data = navratriData
): Product[] {
  const matches = keywords.length
    ? keywords
    : [
        ...data.categories.flatMap((category) => category.keywords),
        ...data.tabs.flatMap((tab) => tab.keywords),
      ]
  return products.filter((product) => {
    if (product.restaurantId) return false
    const text = [
      product.name,
      product.slug,
      product.description,
      product.category?.name,
      product.category?.slug,
      ...(product.tags ?? []),
    ]
      .filter(Boolean)
      .join(' ')
      .toLocaleLowerCase()
    return matchesNavratriKeywords(text, matches)
  })
}

export function filterDemoProducts(tab: NavratriTab, data = navratriData): NavratriProduct[] {
  if (!tab.keywords.length) return data.products
  return data.products.filter((product) => {
    const category = data.categories.find((item) => item.id === product.categoryId)
    const text =
      `${product.name} ${category?.label ?? ''} ${category?.keywords.join(' ') ?? ''}`.toLocaleLowerCase()
    return matchesNavratriKeywords(text, tab.keywords)
  })
}

export function resolveCampaignPromotions(
  data: CampaignConfig,
  catalogue: Product[]
): CampaignConfig {
  return {
    ...data,
    products: data.products.flatMap((slot) => {
      if (!slot.productId) return data.demo ? [slot] : []
      const product = catalogue.find(
        (item) =>
          item.id === slot.productId && item.isAvailable && item.stock > 0 && !item.restaurantId
      )
      if (!product) return []
      return [
        {
          ...slot,
          name: product.name,
          image: product.imageUrl && campaignImageSchema.safeParse(product.imageUrl).success ? product.imageUrl : slot.image,
          price: product.price,
          originalPrice: Math.max(product.mrp, product.price),
        },
      ]
    }),
  }
}
