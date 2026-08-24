import { prisma } from '@/lib/prisma'
import { CategoriesDirectoryClient } from '@/components/category/categories-directory-client'
import { Category } from '@/types'
import { Metadata } from 'next'
import { Suspense } from 'react'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: 'All Categories - FastKirana | Grocery, Cafe & Restaurant',
    description: 'Browse all categories at FastKirana. Fresh groceries, dairy, snacks, beverages, ice cream, bakery, and more delivered fast in Ghatampur, Kanpur.',
    keywords: ['grocery categories', 'online grocery', 'fast delivery', 'Ghatampur', 'Kanpur', 'snacks', 'dairy', 'beverages'],
  }
}

async function CategoriesLoader() {
  try {
    // Fetch all grocery categories from database (exclude restaurant food)
    const categoriesRaw = await prisma.category.findMany({
      where: {
        slug: { notIn: ['cafe', 'restaurant', 'fastkirana-cafe', 'fastkirana-restaurant', 'restaurant-food', 'fast-food-kitchen'] },
      },
      orderBy: { sortOrder: 'asc' },
      include: {
        _count: {
          select: { products: true },
        },
      },
    })

    // Map to standard Category schema
    const categories: Category[] = categoriesRaw.map((c) => ({
      id: c.id,
      name: c.name,
      slug: c.slug,
      imageUrl: c.imageUrl,
      parentId: c.parentId,
      sortOrder: c.sortOrder,
      _count: c._count,
    }))

    return <CategoriesDirectoryClient categories={categories} />
  } catch (error) {
    console.error('Failed to load categories in CategoriesLoader:', error)
    return <CategoriesDirectoryClient categories={[]} />
  }
}

export default function CategoriesPage() {
  return (
    <div className="container mx-auto px-4 py-4 max-w-7xl">
      <Suspense
        fallback={
          <div className="flex flex-col items-center justify-center py-20 space-y-4">
            <div className="h-10 w-10 border-4 border-primary border-t-transparent rounded-full animate-spin" />
            <p className="text-xs font-black text-text-secondary">Loading Categories Directory...</p>
          </div>
        }
      >
        <CategoriesLoader />
      </Suspense>
    </div>
  )
}
