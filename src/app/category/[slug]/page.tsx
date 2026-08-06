import { notFound } from 'next/navigation'
import { prisma } from '@/lib/prisma'
import { CategoryPageClient } from '@/components/category/category-page-client'
import { Category, Product } from '@/types'
import { Suspense } from 'react'
import { sortProductsByStock } from '@/lib/utils'

interface CategoryPageProps {
  params: Promise<{ slug: string }>
}

export const revalidate = 300 // Cache for 5 minutes (saves DB active CPU), purged on-demand when products update

export default async function CategoryPage({ params }: CategoryPageProps) {
  const { slug } = await params

  // 1. Fetch categories, sort setting, and active product counts in parallel
  const [categoriesRaw, productCounts, sortSetting] = await Promise.all([
    prisma.category.findMany({
      where: {
        slug: { not: 'cafe' },
      },
      orderBy: { sortOrder: 'asc' },
    }).catch(() => []),
    prisma.product.groupBy({
      by: ['categoryId'],
      where: {
        isAvailable: true,
        restaurantId: null,
        NOT: {
          tags: {
            has: 'restaurant'
          }
        }
      },
      _count: {
        id: true,
      },
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
    'beverages': ['beverages', 'beverage', 'drinks', 'drink', 'cold-drinks', 'cold-beverages', 'hot-beverages', 'shake', 'shakes', 'chilled', 'juices', 'juice', 'soda', 'tea', 'coffee'],
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

  // Filter products for category view: Grocery Beverages vs Restaurant Cafe segregation
  let finalProductsRaw = productsRaw
  if (normSlug === 'beverages' || normSlug === 'cold-drinks-juices') {
    finalProductsRaw = productsRaw.filter((p) => {
      const pName = (p.name || '').toLowerCase()
      const tags = Array.isArray(p.tags) ? p.tags.map((t: string) => t.toLowerCase()) : []

      // Prepared restaurant shakes & coffees belong to Restaurant/Cafe -> exclude from Grocery Beverages
      const isPreparedRestaurantDrink = /shake|smoothie|coffee|frappe|mocktail|latte|cappuccino/i.test(pName) || tags.includes('wedson') || tags.includes('as-restaurant')
      const isFoodMainCourse = /dosa|naan|roti|biryani|paneer|thali|curry|gravy|manchurian|dal|burger|pizza/i.test(pName)

      return !isPreparedRestaurantDrink && !isFoodMainCourse
    })
  } else if (normSlug === 'ice-cream' || normSlug === 'ice_cream') {
    finalProductsRaw = productsRaw.filter((p) => {
      const isFoodMainCourse = /dosa|naan|roti|biryani|paneer|thali|curry|gravy|manchurian|dal|burger|pizza/i.test(p.name)
      return !isFoodMainCourse
    })
  }

  // 4. Map product counts list to a lookup map
  const countsMap: Record<string, number> = {}
  productCounts.forEach((group) => {
    countsMap[group.categoryId] = group._count.id
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
