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



export const revalidate = 86400 // Cache for 24 hours, purged on-demand when products update



export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {

  const { slug } = await params

  const category = await prisma.category.findFirst({

    where: { slug },

    select: { name: true },

  }).catch(() => null)



  const name = category?.name || slug.split(/[-_]/).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')



  return {

    title: `${name} - FastMinute | Online Grocery Delivery`,

    description: `Buy ${name} online at FastMinute. Fresh products, fast delivery in Ghatampur, Kanpur.`,

    keywords: [name, 'online grocery', 'fast delivery', 'Ghatampur', 'Kanpur'],

  }

}



export default async function CategoryPage({ params }: CategoryPageProps) {

  const { slug } = await params



  // 1. Fetch categories, all grocery products, and sort setting in parallel

  const [categoriesRaw, allGroceryProducts, sortSetting] = await Promise.all([

    prisma.category.findMany({

      where: {

        slug: { notIn: ['cafe', 'restaurant', 'fastkirana-cafe', 'fastkirana-restaurant', 'restaurant-food', 'fast-food-kitchen'] },

      },

      orderBy: { sortOrder: 'asc' },

    }).catch(() => []),

    prisma.product.findMany({

      where: {

        isAvailable: true,

        restaurantId: null,

        category: {

          slug: { notIn: ['cafe', 'restaurant', 'fastkirana-cafe', 'fastkirana-restaurant', 'restaurant-food', 'fast-food-kitchen'] }

        }

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



  // Category alias dictionary to handle renames, subcategories, and alternate slugs seamlessly
  const CATEGORY_ALIASES: Record<string, string[]> = {
    'dairy-products': ['dairy-sweets', 'milk-dairy', 'dairy', 'milk'],
    'dairy': ['dairy-sweets', 'milk-dairy', 'dairy-products'],
    'dairy-breakfast': ['dairy-sweets', 'milk-dairy', 'dairy-products'],
    'milk-dairy': ['dairy-sweets', 'dairy-products', 'dairy'],
    'dairy-sweets': ['dairy-products', 'milk-dairy', 'dairy'],
    'fruits-veg': ['fruits-vegetables', 'fresh-vegetables', 'fresh-fruits'],
    'vegetables': ['fruits-vegetables', 'fresh-vegetables'],
    'fruits': ['fruits-vegetables', 'fresh-fruits'],
    'cookies': ['cookies-namkeen'],
    'namkeen': ['cookies-namkeen'],
    'biscuits': ['cookies-namkeen', 'bakery-biscuits'],
    'snacks': ['snacks-munchies', 'packaged-items', 'noodles-pasta-snacks'],
    'packaged-food': ['packaged-items'],
    'packaged-foods': ['packaged-items'],
    'cold-drinks': ['beverages'],
    'drinks': ['beverages'],
    'ration': ['kitchen-ration'],
    'kitchen': ['kitchen-ration'],
    'grocery': ['kitchen-ration'],
    'groceries': ['kitchen-ration'],
    'dry-fruits': ['dry-fruits-super-foods', 'dry-fruits-nuts-seeds'],
    'super-foods': ['dry-fruits-super-foods'],
    'chocolates': ['cakes-chocolates', 'chocolates-sweets'],
    'cakes': ['cakes-chocolates'],
    'home-care': ['household-essentials'],
    'cleaning': ['household-essentials'],
    'personal-care': ['personal-care-hygiene'],
  }

  // 2. Fetch or construct active category with multi-strategy resolution
  let activeCategory: any = categoriesRaw.find(
    (c) => c.slug.toLowerCase() === slug.toLowerCase() ||
           c.id.toLowerCase() === slug.toLowerCase() ||
           c.slug.toLowerCase().replace(/[-_]/g, '') === slug.toLowerCase().replace(/[-_]/g, '')
  )

  // Alias lookup
  if (!activeCategory) {
    const aliases = CATEGORY_ALIASES[slug.toLowerCase()] || []
    if (aliases.length > 0) {
      activeCategory = categoriesRaw.find((c) =>
        aliases.includes(c.slug.toLowerCase()) || aliases.includes(c.id.toLowerCase())
      )
    }
  }

  // Token/keyword substring matching in category name or slug
  if (!activeCategory) {
    const slugWords = slug.toLowerCase().split(/[-_ ]+/).filter(w => w.length > 2 && !['and', 'the', 'for', 'item', 'items', 'products'].includes(w))
    activeCategory = categoriesRaw.find((c) => {
      const cName = c.name.toLowerCase()
      const cSlug = c.slug.toLowerCase()
      return slugWords.some(w => cName.includes(w) || cSlug.includes(w))
    })
  }

  // Subcategory matching fallback
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

  // 3. Build comprehensive product query: products attached to this category, its children, or matching aliases
  const normSlug = slug.toLowerCase().trim()
  const slugVariants = [
    normSlug,
    normSlug.replace(/-/g, '_'),
    normSlug.replace(/_/g, '-'),
    normSlug.replace(/-/g, ' '),
  ]

  // Add aliases to slug variants
  const aliasList = CATEGORY_ALIASES[normSlug] || []
  aliasList.forEach(a => slugVariants.push(a))

  // Recursively collect all descendant category IDs
  const matchingCatIds = new Set<string>()
  if (activeCategory && activeCategory.id && !activeCategory.id.startsWith('virtual-')) {
    matchingCatIds.add(activeCategory.id)

    // If it's a parent category, add all children and grandchildren
    const childCats = categoriesRaw.filter((c) => c.parentId === activeCategory.id)
    childCats.forEach((ch) => {
      matchingCatIds.add(ch.id)
      const grandChildren = categoriesRaw.filter((gc) => gc.parentId === ch.id)
      grandChildren.forEach((gc) => matchingCatIds.add(gc.id))
    })

    // If it's a child subcategory, also add its parent and siblings so relevant products display
    if (activeCategory.parentId) {
      matchingCatIds.add(activeCategory.parentId)
      const siblingCats = categoriesRaw.filter((c) => c.parentId === activeCategory.parentId)
      siblingCats.forEach((sc) => matchingCatIds.add(sc.id))
    }
  }

  // Also include any categories matching alias slugs
  aliasList.forEach(aliasSlug => {
    const matched = categoriesRaw.filter(c => c.slug.toLowerCase() === aliasSlug.toLowerCase())
    matched.forEach(m => {
      matchingCatIds.add(m.id)
      const children = categoriesRaw.filter(c => c.parentId === m.id)
      children.forEach(ch => matchingCatIds.add(ch.id))
    })
  })

  const conditions: any[] = [
    { category: { slug: { in: slugVariants } } },
    { category: { parent: { slug: { in: slugVariants } } } },
  ]

  if (matchingCatIds.size > 0) {
    const idList = Array.from(matchingCatIds)
    conditions.push({ categoryId: { in: idList } })
    conditions.push({ category: { id: { in: idList } } })
    conditions.push({ category: { parentId: { in: idList } } })
  } else {
    // If no direct category matched, perform keyword search on product tags & name so products never disappear
    const searchKeywords = normSlug.split(/[-_ ]+/).filter(w => w.length > 2 && !['and', 'the', 'for', 'item', 'items', 'products'].includes(w))
    if (searchKeywords.length > 0) {
      conditions.push({
        OR: searchKeywords.map(kw => ({
          name: { contains: kw, mode: 'insensitive' }
        }))
      })
      conditions.push({
        tags: { hasSome: searchKeywords }
      })
    }
  }



  const productsRaw = await prisma.product.findMany({

    where: {

      isAvailable: true,

      restaurantId: null,

      category: {

        slug: { notIn: ['cafe', 'restaurant', 'fastkirana-cafe', 'fastkirana-restaurant', 'restaurant-food', 'fast-food-kitchen'] }

      },

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



  // Filter products for category view: Exclude prepared restaurant items, shakes, coffee, and hot meals from grocery category pages

  let finalProductsRaw = productsRaw.filter((p: any) => {

    // Strictly dark-store grocery products only

    if (p.restaurantId) return false

    const catSlug = (p.category?.slug || '').toLowerCase()

    if (['restaurant-food', 'cafe', 'restaurant', 'fastkirana-cafe', 'fastkirana-restaurant', 'fast-food-kitchen'].includes(catSlug)) {

      return false

    }



    const pName = (p.name || '').toLowerCase()

    const tags = Array.isArray(p.tags) ? p.tags.map((t: string) => t.toLowerCase()) : []



    // Exclude prepared shakes and cold coffee specifically from grocery category view

    if (/shake|smoothie|frappe|classic cold coffee/i.test(pName)) return false



    // Exclude hot restaurant main courses, parathas, pizzas, burgers, biryanis from grocery catalog

    const isHotPreparedFood = /paratha|naan|roti|biryani|paneer 65|makhani|lababdaar|do pyaaza|kulcha|handi|chaap|pizza|burger|hakkah|manchurian|chilli paneer|tandoori|tikka|dosa|thali/i.test(pName)

    if (isHotPreparedFood) return false



    if (normSlug === 'ice-cream' || normSlug === 'ice_cream') {

      const isNonIceCream = /shampoo|soap|paste|lotion|cleaner|chips|namkeen|biscuit|cookie|atta|rice|dal|tea|coffee|coke|pepsi|sprite|soda|paratha|pizza|burger|oil|ghee|paneer|curd|milkshake|shake|smoothie/i.test(pName)

      if (isNonIceCream && !/ice.?cream|kulfi|chocobar|cornetto|cassatta|sundae|scoop/i.test(pName)) return false



      const isIceCream = /ice.?cream|kulfi|chocobar|cornetto|cassatta|sundae|scoop|matka|kwality|havmor|amul|vadilal|baskin|nic|falooda/i.test(pName) ||

        tags.some((t: string) => /ice.?cream|kulfi|chocobar|cornetto/i.test(t)) ||

        catSlug === 'ice-cream' || catSlug === 'ice_cream'



      return isIceCream

    }



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

      if (p.category && (p.category.id === cat.id || p.category.slug.toLowerCase() === cSlug)) return true

      // Also match if product belongs to any subcategory of this category

      if (p.category && (p.category as any).parentId === cat.id) return true

      const pCat = categoriesRaw.find(c => c.id === p.categoryId)

      if (pCat && pCat.parentId === cat.id) return true

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

      id: p.category?.id || p.categoryId || activeCategory.id,

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

