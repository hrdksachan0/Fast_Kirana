import { prisma } from '@/lib/prisma'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'
import { logger } from '@/lib/logger'
import { Prisma } from '@prisma/client'

export interface CreateDishInput {
  name: string
  price: number
  mrp?: number
  unit?: string
  stock?: number
  description?: string | null
  imageUrl?: string | null
  tags?: string[]
  categoryId?: string | null
  restaurantId: string
  variants?: any
  availableStartTime?: string | null
  availableEndTime?: string | null
  foodType?: 'veg' | 'non-veg' | 'egg' | string
  prepTime?: number | string
  sectionId?: string
  menuSectionId?: string
}

import { extractCityFromStoreName } from '@/lib/store-resolver'

export class RestaurantCatalogService {
  /**
   * Fetches menu items and restaurant metadata for dashboard
   */
  async getDashboardCatalog(restaurantId: string | null, storeId?: string | null) {
    const where: Prisma.ProductWhereInput = {}
    
    if (restaurantId === 'ALL') {
      if (storeId && storeId !== 'all') {
        const store = await prisma.darkStore.findUnique({
          where: { id: storeId },
          select: { name: true }
        })
        const city = store ? extractCityFromStoreName(store.name) : ''
        const storeRestaurants = await prisma.restaurant.findMany({
          where: city ? { city: { contains: city, mode: 'insensitive' } } : {},
          select: { id: true }
        })
        const ids = storeRestaurants.map(r => r.id)
        if (ids.length === 0) {
          return { products: [], restaurant: null }
        }
        where.restaurantId = { in: ids }
      } else {
        where.restaurantId = { not: null }
      }
    } else if (restaurantId && restaurantId !== 'NONE') {
      where.restaurantId = restaurantId
    } else {
      return { products: [], restaurant: null }
    }

    const [products, restaurant] = await Promise.all([
      prisma.product.findMany({
        where,
        include: { category: true, images: true },
        orderBy: [{ sortOrder: 'desc' }, { createdAt: 'desc' }],
      }),
      restaurantId && restaurantId !== 'ALL' && restaurantId !== 'NONE'
        ? prisma.restaurant.findUnique({
            where: { id: restaurantId },
            select: { id: true, name: true, slug: true, menuSections: true, cuisineTags: true },
          })
        : null,
    ])

    return { products, restaurant }
  }

  /**
   * Creates a new menu dish with slug deduplication, automatic tags, and cache invalidation
   */
  async createDish(input: CreateDishInput) {
    const {
      name,
      description,
      imageUrl,
      price,
      mrp,
      unit,
      stock,
      tags,
      categoryId,
      restaurantId,
      variants,
      availableStartTime,
      availableEndTime,
      foodType,
      prepTime,
      sectionId,
      menuSectionId,
    } = input

    const targetCategoryId = null
    const finalUnit = (unit && typeof unit === 'string' && unit.trim()) ? unit.trim() : '1 Serving'
    const parsedPrice = typeof price === 'number' ? price : (parseFloat(price) || 0)
    const parsedMrp = mrp !== undefined ? (typeof mrp === 'number' ? mrp : parseFloat(mrp) || parsedPrice) : parsedPrice
    const parsedStock = stock !== undefined ? (typeof stock === 'number' ? stock : parseInt(stock) || 999) : 999

    const discountVal =
      parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0

    // Generate unique slug from name
    const baseSlug = name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '') || `item-${Date.now()}`
    const existingCount = await prisma.product.count({ where: { slug: { startsWith: baseSlug } } })
    const slug = existingCount > 0 ? `${baseSlug}-${existingCount + 1}-${Date.now().toString().slice(-4)}` : baseSlug

    const tagsList = Array.isArray(tags) ? [...tags] : []
    if (!tagsList.includes('restaurant')) {
      tagsList.push('restaurant')
    }

    // Add food type tag: 'veg', 'non-veg', 'egg'
    if (foodType) {
      const ft = String(foodType).toLowerCase().trim()
      if (['veg', 'non-veg', 'egg'].includes(ft) && !tagsList.includes(ft)) {
        tagsList.push(ft)
      }
    }

    // Add prep time tag if provided
    if (prepTime) {
      const pt = parseInt(String(prepTime), 10)
      if (pt > 0) {
        tagsList.push(`prep-${pt}m`)
      }
    }

    // Add unique section ID for relational indexing
    const secId = sectionId || menuSectionId
    if (secId && typeof secId === 'string' && secId.trim() && !tagsList.includes(secId.trim())) {
      tagsList.push(secId.trim())
    }

    const product = await prisma.product.create({
      data: {
        name: name.trim(),
        slug,
        description: description || null,
        imageUrl: imageUrl || null,
        price: parsedPrice,
        mrp: parsedMrp,
        discount: discountVal,
        unit: finalUnit,
        stock: parsedStock,
        tags: tagsList,
        categoryId: targetCategoryId,
        restaurantId,
        variants: variants || null,
        availableStartTime: availableStartTime || null,
        availableEndTime: availableEndTime || null,
        isAvailable: true,
      },
      include: { category: true },
    })

    try {
      revalidateStorefront(product.category?.slug)
      await invalidateProductCache()
    } catch (e) {
      logger.warn('cache', 'Cache revalidation failed after dish creation', e)
    }

    return product
  }
}

export const restaurantCatalogService = new RestaurantCatalogService()
