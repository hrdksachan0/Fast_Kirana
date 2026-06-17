import { notFound } from 'next/navigation'
import { prisma } from '@/lib/prisma'
import { CategoryPageClient } from '@/components/category/category-page-client'
import { Category, Product } from '@/types'
import { Suspense } from 'react'

interface CategoryPageProps {
  params: Promise<{ slug: string }>
}

export const revalidate = 300 // Cache for 5 minutes (saves DB active CPU), purged on-demand when products update

export default async function CategoryPage({ params }: CategoryPageProps) {
  const { slug } = await params

  // 1. Fetch categories, category products, and active product counts in parallel
  const [categoriesRaw, productsRaw, productCounts] = await Promise.all([
    prisma.category.findMany({
      where: {
        slug: { not: 'cafe' },
      },
      orderBy: { sortOrder: 'asc' },
    }).catch(() => []),
    prisma.product.findMany({
      where: {
        category: { slug },
        isAvailable: true,
      },
      orderBy: { createdAt: 'desc' }, // default sort by newest
      include: {
        category: true,
      },
    }).catch(() => []),
    prisma.product.groupBy({
      by: ['categoryId'],
      where: { isAvailable: true },
      _count: {
        id: true,
      },
    }).catch(() => []),
  ])

  // 2. Fetch the active category from the pre-loaded category pool
  const activeCategory = categoriesRaw.find((c) => c.slug === slug)

  if (!activeCategory) {
    notFound()
  }

  // 3. Map product counts list to a lookup map
  const countsMap: Record<string, number> = {}
  productCounts.forEach((group) => {
    countsMap[group.categoryId] = group._count.id
  })

  // 4. Map database categories and products to UI models
  const categories: Category[] = categoriesRaw.map((c) => ({
    id: c.id,
    name: c.name,
    slug: c.slug,
    imageUrl: c.imageUrl,
    parentId: c.parentId,
    sortOrder: c.sortOrder,
  }))

  const products: Product[] = productsRaw.map((p) => ({
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
      id: activeCategory.id,
      name: activeCategory.name,
      slug: activeCategory.slug,
      imageUrl: activeCategory.imageUrl,
      parentId: activeCategory.parentId,
      sortOrder: activeCategory.sortOrder,
    },
  }))

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
