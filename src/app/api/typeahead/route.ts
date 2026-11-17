import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getCache, setCache } from '@/lib/search-cache'

/**
 * Lightweight Typeahead API — Blinkit-style instant search suggestions.
 * Returns a compact index of product names, brands, and categories
 * for client-side prefix matching (zero-latency after first load).
 * 
 * GET /api/typeahead
 *   ?storeId=hub-209206  (optional, for store-scoped results)
 * 
 * Response is ~30-80KB, cached for 5 minutes server-side.
 */
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const storeId = searchParams.get('storeId') || 'hub-209206'
    
    const cacheKey = `typeahead:${storeId}`
    const cached = await getCache<any>(cacheKey)
    if (cached) {
      return NextResponse.json(cached, {
        headers: {
          'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
          'X-Cache': 'HIT',
        }
      })
    }

    // Fetch all available product names, categories, images, and prices
    // Using raw SQL for maximum speed — single query, no joins overhead
    const products: any[] = await prisma.$queryRawUnsafe(`
      SELECT 
        p.id, p.name, p.slug, p."imageUrl", p.price, p.mrp, p.discount, p.unit, p.stock,
        p."isAvailable", p.tags, p."restaurantId", p.variants,
        c.name as "categoryName", c.slug as "categorySlug"
      FROM products p
      LEFT JOIN categories c ON p."categoryId" = c.id
      WHERE p."isAvailable" = TRUE
      ORDER BY p."sortOrder" DESC, p."isBestSeller" DESC, p.name ASC
    `)

    // Build typeahead index
    // 1. Extract unique search terms (product names for autocomplete)
    const termSet = new Map<string, { term: string; categoryName: string; categorySlug: string; count: number }>()
    
    // 2. Extract brand names from product names (first word pattern)
    const brandCounts = new Map<string, { name: string; imageUrl: string | null; count: number }>()
    
    // Known brand patterns to extract
    const KNOWN_BRANDS = new Set([
      'maggi', 'amul', 'parle', 'britannia', 'haldiram', 'lays', 'kurkure', 'bingo',
      'cadbury', 'nestle', 'tata', 'dabur', 'patanjali', 'fortune', 'aashirvaad',
      'surf', 'vim', 'dettol', 'lifebuoy', 'colgate', 'closeup', 'head',
      'dove', 'lux', 'pears', 'clinic', 'sunsilk', 'pantene', 'garnier',
      'maaza', 'frooti', 'real', 'tropicana', 'paper boat', 'sting', 'red bull',
      'coca cola', 'pepsi', 'sprite', 'thums up', 'limca', 'fanta', '7up',
      'mtr', 'everest', 'mdh', 'catch', 'saffola', 'sundrop', 'dhara',
      'good day', 'hide & seek', 'oreo', 'bourbon', 'krackjack', 'monaco',
      'nescafe', 'bru', 'lipton', 'taj mahal', 'red label', 'wagh bakri',
      'bikano', 'balaji', 'act ii', 'too yumm', 'cornitos',
      'kissan', 'maggi', 'knorr', 'ching', 'smith & jones', 'tops',
      'harpic', 'lizol', 'domex', 'odonil', 'godrej', 'goodknight',
      'sunfeast', 'yippee', 'top ramen', 'knorr', 'wai wai',
      'mother dairy', 'verka', 'nandini', 'milma',
    ])

    for (const p of products) {
      const name = (p.name || '').trim()
      if (!name) continue
      
      const nameLower = name.toLowerCase()
      const categoryName = p.categoryName || ''
      const categorySlug = p.categorySlug || ''
      
      // Add full product name as a term
      if (!termSet.has(nameLower)) {
        termSet.set(nameLower, { term: name, categoryName, categorySlug, count: 1 })
      } else {
        termSet.get(nameLower)!.count++
      }
      
      // Extract brand (first word or known brand match)
      const words = nameLower.split(/\s+/)
      const firstWord = words[0]
      
      // Check if product name starts with a known brand
      let matchedBrand: string | null = null
      for (const brand of KNOWN_BRANDS) {
        if (nameLower.startsWith(brand)) {
          matchedBrand = brand
          break
        }
      }
      
      if (matchedBrand) {
        const brandKey = matchedBrand
        if (!brandCounts.has(brandKey)) {
          // Capitalize brand name properly
          const brandName = matchedBrand.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')
          brandCounts.set(brandKey, { name: brandName, imageUrl: p.imageUrl, count: 1 })
        } else {
          brandCounts.get(brandKey)!.count++
        }
      }
    }

    // 3. Build categories list
    const categories = await prisma.category.findMany({
      select: { name: true, slug: true, imageUrl: true },
      orderBy: { sortOrder: 'asc' }
    })

    // 4. Build compact product list for inline display (id, name, image, price, unit, category, slug)
    const compactProducts = products.map(p => ({
      id: p.id,
      name: (p.name || '').trim(),
      slug: p.slug,
      imageUrl: p.imageUrl,
      price: p.price,
      mrp: p.mrp,
      discount: p.discount,
      unit: p.unit,
      stock: p.stock,
      isAvailable: p.isAvailable,
      tags: p.tags || [],
      restaurantId: p.restaurantId,
      variants: p.variants,
      categoryName: p.categoryName || '',
      categorySlug: p.categorySlug || '',
    }))

    // 5. Build sorted terms (most products first)
    const terms = Array.from(termSet.values())
      .sort((a, b) => b.count - a.count)
      .map(t => ({ term: t.term, category: t.categoryName, categorySlug: t.categorySlug }))

    // 6. Build brands (most products first)
    const brands = Array.from(brandCounts.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, 50)

    const result = {
      terms,       // Product name autocomplete terms
      brands,      // Brand suggestions with icons
      categories,  // Category suggestions
      products: compactProducts, // Full compact product list for inline results
      totalProducts: compactProducts.length,
      generatedAt: new Date().toISOString(),
    }

    // Cache for 5 minutes
    await setCache(cacheKey, result, 300)

    return NextResponse.json(result, {
      headers: {
        'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
        'X-Cache': 'MISS',
      }
    })
  } catch (error) {
    console.error('[Typeahead API] Error:', error)
    return NextResponse.json({ terms: [], brands: [], categories: [], products: [] }, { status: 500 })
  }
}
