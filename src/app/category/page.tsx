import { prisma } from '@/lib/prisma'
import { CategoriesDirectoryClient } from '@/components/category/categories-directory-client'
import { Category } from '@/types'
import { Suspense } from 'react'

// Revalidate this page every 24 hours
export const revalidate = 86400

async function CategoriesLoader() {
  // Fetch all categories from database
  const categoriesRaw = await prisma.category.findMany({
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
