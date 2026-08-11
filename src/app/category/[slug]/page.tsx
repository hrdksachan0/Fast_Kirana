import { notFound } from 'next/navigation'
import { prisma } from '@/lib/prisma'
import { CategoryPageClient } from '@/components/category/category-page-client'
import { Category, Product } from '@/types'
import { Metadata } from 'next'
import { Suspense } from 'react'
import { sortProductsByStock } from '@/lib/utils'

interface CategoryPageProps {
  params: Promise<{ slug: string }>
}

export const revalidate = 300 // Cache for 5 minutes (saves DB active CPU), purged on-demand when products update

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params
  const category = await prisma.category.findFirst({
    where: { slug },
    select: { name: true },
  }).catch(() => null)

  const name = category?.name || slug.split(/[-_]/).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')

  return {
    title: `${name} - FastKirana | Online Grocery Delivery`,
    description: `Buy ${name} online at FastKirana. Fresh products, fast delivery in Ghatampur, Kanpur.`,
    keywords: [name, 'online grocery', 'fast delivery', 'Ghatampur', 'Kanpur'],
  }
}

export default async function CategoryPage({ params }: CategoryPageProps) {
  const { slug } = await params

  // 1. Fetch categories, all grocery products, and sort setting in parallel
  const [categoriesRaw, allGroceryProducts, sortSetting] = await Promise.all([
    prisma.category.findMany({
      where: {
        slug: { notIn: ['cafe', 'restaurant', 'fastkirana-cafe', 'fastkirana-restaurant'] },
      },
      orderBy: { sortOrder: 'asc' },
    }).catch(() => []),
    prisma.product.findMany({
      where: {
        isAvailable: true,
        OR: [
          { restaurantId: null },
          { category: { slug: { in: ['beverages', 'ice-cream'] } } },
          { tags: { hasSome: ['beverages', 'ice-cream'] } }
        ],
        NOT: [
          { category: { slug: { in: ['restaurant', 'fastkirana-restaurant', 'cafe', 'fastkirana-cafe'] } } }
        ]
      },
      select: {
        id: true,
        name: true,
        categoryId: true,
        tags: true,
        category: {
          select: {
            id: true,
            slug: true,
            name: true,
          }
        }
      }
    }).catch(() => []),
    prisma.storeSetting.findUnique({
      where: { key: `category_sort_${slug}` }
    }).catch(() => null),
  ])

  const rule = sortSetting?.value || 'manual'

  let orderBy: any = [
    { sortOrder: 'desc' },
    { createdAt: 'desc' }
  ]

  if (rule === 'best-seller') {
    orderBy = [
      { isBestSeller: 'desc' },
      { sortOrder: 'desc' },
      { createdAt: 'desc' }
    ]
  } else if (rule === 'stock-desc') {
    orderBy = [
      { stock: 'desc' },
      { sortOrder: 'desc' },
      { createdAt: 'desc' }
    ]
  } else if (rule === 'price-asc') {
    orderBy = [
      { price: 'asc' },
      { sortOrder: 'desc' }
    ]
  } else if (rule === 'price-desc') {
    orderBy = [
      { price: 'desc' },
      { sortOrder: 'desc' }
    ]
  } else if (rule === 'newest') {
    orderBy = [
      { createdAt: 'desc' }
    ]
  }

  // 2. Fetch or construct active category to prevent 404s
  let activeCategory: any = categoriesRaw.find(
    (c) => c.slug.toLowerCase() === slug.toLowerCase() ||
           c.slug.toLowerCase().replace(/[-_]/g, '') === slug.toLowerCase().replace(/[-_]/g, '')
  )

  if (!activeCategory) {
    activeCategory = categoriesRaw.find(
      (c) => c.name.toLowerCase().includes(slug.toLowerCase()) || c.slug.toLowerCase().includes(slug.toLowerCase())
    )
  }

  if (!activeCategory) {
    const formattedTitle = slug.split(/[-_]/).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')
    activeCategory = {
      id: `virtual-${slug}`,
      name: formattedTitle,
      slug: slug,
      imageUrl: null,
      parentId: null,
      sortOrder: 99,
    } as any
  }

  // 3. Build broad product search query to include both direct category items and tagged products
  const normSlug = slug.toLowerCase().trim()
  const slugVariants = [
    normSlug,
    normSlug.replace(/-/g, '_'),
    normSlug.replace(/_/g, '-'),
    normSlug.replace(/-/g, ' '),
  ]

  const relatedTagsMap: Record<string, string[]> = {
    'beverages': ['beverages', 'beverage', 'drinks', 'drink', 'cold-drinks', 'cold-beverages', 'hot-beverages', 'shake', 'shakes', 'chilled', 'juices', 'juice', 'soda', 'tea', 'coffee', 'campa', 'energy'],
    'ice-cream': ['ice-cream', 'ice cream', 'ice_cream', 'desserts', 'dessert', 'kulfi', 'cones', 'tubs', 'sweet', 'sweets'],
    'dairy-breakfast': ['dairy', 'breakfast', 'milk', 'curd', 'paneer', 'butter', 'nashta', 'bread', 'eggs', 'dahi'],
    'snacks-munchies': ['snack', 'snacks', 'namkeen', 'chips', 'biscuits', 'munchies', 'bhujia', 'biscuit'],
    'fruits-vegetables': ['fruit', 'fruits', 'vegetable', 'vegetables', 'sabzi', 'pyaz', 'tamatar', 'aalu'],
    'bakery-biscuits': ['bakery', 'biscuit', 'biscuits', 'bread', 'cake', 'cookies', 'toast', 'rusk'],
    'atta-rice-dal': ['atta', 'rice', 'dal', 'pulse', 'pulses', 'flour', 'chawal', 'aata'],
    'personal-care': ['personal', 'care', 'soap', 'shampoo', 'paste', 'brush', 'lotion'],
    'household': ['household', 'cleaner', 'detergent', 'dishwash', 'clean'],
  }

  const related = relatedTagsMap[normSlug] || slugVariants
  const conditions: any[] = [
    { category: { slug: { in: slugVariants } } },
    { tags: { hasSome: related } },
  ]

  if (activeCategory && activeCategory.id && !activeCategory.id.startsWith('virtual-')) {
    conditions.push({ categoryId: activeCategory.id })
  }

  const productsRaw = await prisma.product.findMany({
    where: {
      isAvailable: true,
      OR: conditions,
    },
    orderBy,
    include: {
      category: true,
    },
  }).catch((err) => {
    console.error('Error querying category products:', err)
    return []
  })

  // Filter products for category view: Exclude Classic Cold Coffee and hot main course meals from grocery category pages
  let finalProductsRaw = productsRaw.filter((p: any) => {
    const pName = (p.name || '').toLowerCase()
    const tags = Array.isArray(p.tags) ? p.tags.map((t: string) => t.toLowerCase()) : []
    const catSlug = (p.category?.slug || '').toLowerCase()

    // Exclude Classic Cold Coffee specifically from grocery category view
    if (pName.includes('classic cold coffee')) return false

    // Exclude hot restaurant main courses, parathas, pizzas, burgers, biryanis from grocery catalog
    const isHotPreparedFood = /paratha|naan|roti|biryani|paneer 65|makhani|lababdaar|do pyaaza|kulcha|handi|chaap|pizza|burger|hakkah|manchurian|chilli paneer|tandoori|tikka|dosa|thali/i.test(pName)
    if (isHotPreparedFood) return false

    if (normSlug === 'beverages' || normSlug === 'cold-drinks-juices' || normSlug === 'drinks' || normSlug === 'beverage') {
      if (['personal-care', 'personal_care', 'skincare', 'household', 'beauty', 'atta-rice-dal'].includes(catSlug)) {
        return false
      }

      const isNonBeverage = /chocolate|cadbury|kitkat|cake|pastry|brownie|biscuit|cookie|bread|muffin|noodle|pasta|maggi|namkeen|chips|atta|rice|dal|soap|shampoo|face|facewash|skincare|mamaearth|lotion|cream|moisturizer|wash|oil|conditioner|serum/i.test(pName)
      if (isNonBeverage) return false

      const isAllowedBeverage = /thums|pepsi|hell|\bdew\b|mountain.?dew|coke|sprite|7up|limca|fanta|mirinda|soda|cold|drink|soft|campa|cola|juice|real|tropicana|frooti|maaza|slice|appy|paper|water|bisleri|kinley|aquafina|sting|red.?bull|monster|charged|coconut/i.test(pName) ||
        tags.some((t: string) => /drink|soda|beverage|juice|water/i.test(t)) ||
        catSlug === 'beverages'

      return isAllowedBeverage
    }

    return true
  })

  // 4. Compute dynamic sidebar counts map for all categories
  const countsMap: Record<string, number> = {}
  categoriesRaw.forEach((cat) => {
    const cSlug = cat.slug.toLowerCase()
    const matchCount = allGroceryProducts.filter((p) => {
      const pName = (p.name || '').toLowerCase()
      const pTags = Array.isArray(p.tags) ? p.tags.map(t => t.toLowerCase()) : []
      const pCatSlug = (p.category?.slug || '').toLowerCase()

      if (cSlug === 'beverages') {
        if (['personal-care', 'personal_care', 'skincare', 'household', 'beauty', 'atta-rice-dal'].includes(pCatSlug)) {
          return false
        }

        const isNonBeverage = /chocolate|cadbury|kitkat|cake|pastry|brownie|biscuit|cookie|bread|muffin|noodle|pasta|maggi|namkeen|chips|atta|rice|dal|soap|shampoo|face|facewash|skincare|mamaearth|lotion|cream|moisturizer|wash|oil|conditioner|serum/i.test(pName)
        if (isNonBeverage) return false

        return /coke|pepsi|thums.?up|sprite|7up|limca|fanta|mirinda|soda|cold.?drink|soft.?drink|campa|cola|juice|real|tropicana|frooti|maaza|slice|appy|paper.?boat|water|bisleri|kinley|aquafina|sting|red.?bull|monster|hell|charged|\bdew\b|mountain.?dew/i.test(pName) ||
          pTags.some(t => /drink|soda|beverage|juice|water/i.test(t)) ||
          pCatSlug === 'beverages'
      }

      if (p.categoryId === cat.id) return true
      if (p.category && p.category.slug.toLowerCase() === cSlug) return true
      if (pTags.includes(cSlug)) return true
      return false
    }).length

    countsMap[cat.id] = matchCount
  })

  // 5. Map database categories and products to UI models
  const categories: Category[] = categoriesRaw.map((c) => ({
    id: c.id,
    name: c.name,
    slug: c.slug,
    imageUrl: c.imageUrl,
    parentId: c.parentId,
    sortOrder: c.sortOrder,
  }))

  const products: Product[] = sortProductsByStock(finalProductsRaw.map((p) => ({
    id: p.id,
    name: p.name,
    slug: p.slug,
    description: p.description,
    imageUrl: p.imageUrl,
    categoryId: p.categoryId,
    mrp: p.mrp,
    price: p.price,
    discount: p.discount,
    unit: p.unit,
    stock: p.stock,
    isAvailable: p.isAvailable,
    tags: p.tags,
    minStock: p.minStock,
    variants: p.variants as any,
    category: {
      id: p.category?.id || activeCategory.id,
      name: p.category?.name || activeCategory.name,
      slug: p.category?.slug || activeCategory.slug,
      imageUrl: p.category?.imageUrl || activeCategory.imageUrl,
      parentId: p.category?.parentId || activeCategory.parentId,
      sortOrder: p.category?.sortOrder || activeCategory.sortOrder,
    },
  })))

  return (
    <Suspense fallback={<div className="text-center py-20 text-xs font-black text-text-secondary">Loading Category...</div>}>
      <CategoryPageClient
        categories={categories}
        initialProducts={products}
        activeCategory={{
          id: activeCategory.id,
          name: activeCategory.name,
          slug: activeCategory.slug,
          imageUrl: activeCategory.imageUrl,
          parentId: activeCategory.parentId,
          sortOrder: activeCategory.sortOrder,
        }}
        countsMap={countsMap}
      />
    </Suspense>
  )
}
