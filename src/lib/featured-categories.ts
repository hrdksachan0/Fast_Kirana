import { z } from 'zod'
import { campaignImageSchema } from './campaign-config'

export const featuredCategoriesKey = 'featured_categories'
export const featuredBadges = ['', 'Featured', 'Seasonal', 'Everyday'] as const
export const featuredTints = ['auto', 'mint', 'cream', 'peach', 'sky', 'rose', 'lilac'] as const

export const featuredCategorySchema = z
  .object({
    categoryId: z.string().regex(/^[A-Za-z0-9_-]{1,128}$/),
    label: z.string().trim().max(60).default(''),
    image: z
      .string()
      .refine(
        (value) =>
          (value.startsWith('https://') || value.startsWith('/')) &&
          campaignImageSchema.safeParse(value).success,
        'Use an HTTPS URL or absolute image path'
      )
      .nullable()
      .default(null),
    imageFit: z.enum(['cover', 'contain']).default('cover'),
    badge: z.enum(featuredBadges).default(''),
    tint: z.enum(featuredTints).default('auto'),
    enabled: z.boolean().default(true),
  })
  .strict()

export const featuredCategoriesSchema = z
  .object({
    version: z.literal(1),
    enabled: z.boolean().default(true),
    title: z.string().trim().min(1).max(80).default('Featured categories'),
    items: z.array(featuredCategorySchema).max(6),
  })
  .strict()
  .superRefine((config, context) => {
    const ids = config.items.map((item) => item.categoryId)
    if (new Set(ids).size !== ids.length)
      context.addIssue({
        code: 'custom',
        path: ['items'],
        message: 'Each category can appear once',
      })
  })
export type FeaturedCategoriesConfig = z.infer<typeof featuredCategoriesSchema>
export type FeaturedCategoryItem = z.infer<typeof featuredCategorySchema>
export type CategorySource = {
  id: string
  name: string
  slug: string
  parentId?: string | null
  imageUrl?: string | null
  sortOrder?: number
  _count?: { products: number }
}

export function isGroceryCategory(category: CategorySource): boolean {
  const slug = category.slug.toLowerCase(),
    name = category.name.toLowerCase()
  return (
    !category.parentId &&
    !/restaurant|cafe|fastfood|fast-food-kitchen/.test(slug) &&
    !/restaurant|cafe|^fast food/.test(name)
  )
}
export function defaultFeaturedCategories(categories: CategorySource[]): FeaturedCategoriesConfig {
  return {
    version: 1,
    enabled: true,
    title: 'Featured categories',
    items: categories
      .filter((category) => isGroceryCategory(category) && category._count?.products !== 0)
      .slice()
      .sort(
        (a, b) =>
          (a.sortOrder ?? 0) - (b.sortOrder ?? 0) ||
          a.name.localeCompare(b.name) ||
          a.id.localeCompare(b.id)
      )
      .slice(0, 6)
      .map((category) => featuredCategorySchema.parse({ categoryId: category.id })),
  }
}
export function parseStoredFeaturedCategories(
  value?: string | null
): FeaturedCategoriesConfig | null {
  try {
    const parsed = featuredCategoriesSchema.safeParse(JSON.parse(value || 'null'))
    return parsed.success ? parsed.data : null
  } catch {
    return null
  }
}
