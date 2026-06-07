import { notFound } from 'next/navigation'
import Link from 'next/link'
import { prisma } from '@/lib/prisma'
import { ProductCard } from '@/components/product/product-card'
import { Category, Product } from '@/types'
import { Prisma } from '@prisma/client'
import { cn } from '@/lib/utils'
import { ShoppingBag } from 'lucide-react'

interface CategoryPageProps {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ sort?: string }>
}

export const revalidate = 60

export default async function CategoryPage({ params, searchParams }: CategoryPageProps) {
  const { slug } = await params
  const { sort } = await searchParams

  // 1. Fetch all categories for the sidebar/navigation
  const categoriesRaw = await prisma.category.findMany({
    where: {
      slug: { not: 'cafe' },
    },
    orderBy: { sortOrder: 'asc' },
  }).catch(() => [])

  // 2. Fetch the active category
  const activeCategory = categoriesRaw.find((c) => c.slug === slug)

  if (!activeCategory) {
    notFound()
  }

  // 3. Fetch products in the active category
  let orderBy: Prisma.ProductOrderByWithRelationInput = { createdAt: 'desc' }

  if (sort === 'price-asc') {
    orderBy = { price: 'asc' }
  } else if (sort === 'price-desc') {
    orderBy = { price: 'desc' }
  } else if (sort === 'discount-desc') {
    orderBy = { discount: 'desc' }
  }

  const productsRaw = await prisma.product.findMany({
    where: {
      categoryId: activeCategory.id,
      isAvailable: true,
    },
    orderBy,
    include: {
      category: true,
    },
  }).catch(() => [])

  // Map database categories and products to UI models
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
    category: {
      id: activeCategory.id,
      name: activeCategory.name,
      slug: activeCategory.slug,
      imageUrl: activeCategory.imageUrl,
      parentId: activeCategory.parentId,
      sortOrder: activeCategory.sortOrder,
    },
  }))

  const sortOptions = [
    { label: 'Popularity', value: undefined },
    { label: 'Price: Low to High', value: 'price-asc' },
    { label: 'Price: High to Low', value: 'price-desc' },
    { label: 'Big Discounts', value: 'discount-desc' },
  ]

  return (
    <div className="container mx-auto px-4 py-6 max-w-7xl">
      <div className="flex flex-col md:flex-row gap-6">
        
        {/* Desktop Left Sidebar: Categories Navigation */}
        <aside className="hidden md:block w-64 flex-shrink-0 border border-border bg-card p-4 rounded-2xl h-fit sticky top-[96px] shadow-sm">
          <h3 className="font-bold text-text-primary text-base mb-4 px-2">Categories</h3>
          <div className="space-y-1.5">
            {categories.map((cat) => {
              const isActive = cat.slug === slug
              return (
                <Link
                  key={cat.id}
                  href={`/category/${cat.slug}${sort ? `?sort=${sort}` : ''}`}
                  className={cn(
                    "flex items-center gap-3 w-full px-3 py-2 text-sm font-semibold rounded-xl transition-all duration-200",
                    isActive
                      ? "bg-primary text-primary-foreground shadow-sm scale-[1.02]"
                      : "text-text-secondary hover:bg-muted hover:text-text-primary"
                  )}
                >
                  <span className="text-xl" role="img" aria-label={cat.name}>
                    {cat.imageUrl || '🛒'}
                  </span>
                  <span>{cat.name}</span>
                </Link>
              )
            })}
          </div>
        </aside>

        {/* Right Section: Header and Product Grid */}
        <main className="flex-grow space-y-6">
          {/* Mobile Category Horizontal Scrollbar */}
          <div className="md:hidden overflow-x-auto flex gap-2 pb-2 scrollbar-hide">
            {categories.map((cat) => {
              const isActive = cat.slug === slug
              return (
                <Link
                  key={cat.id}
                  href={`/category/${cat.slug}${sort ? `?sort=${sort}` : ''}`}
                  className={cn(
                    "flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-full border whitespace-nowrap flex-shrink-0 transition-colors",
                    isActive
                      ? "bg-primary text-primary-foreground border-primary"
                      : "bg-card text-text-secondary border-border hover:bg-muted"
                  )}
                >
                  <span>{cat.imageUrl || '🛒'}</span>
                  <span>{cat.name}</span>
                </Link>
              )
            })}
          </div>

          {/* Category Header */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-border/60 pb-4">
            <div>
              <div className="flex items-center gap-3">
                <span className="text-3xl" role="img" aria-label={activeCategory.name}>
                  {activeCategory.imageUrl || '🛒'}
                </span>
                <h1 className="text-xl md:text-2xl font-extrabold text-text-primary tracking-tight">
                  {activeCategory.name}
                </h1>
              </div>
              <p className="text-xs text-text-secondary mt-1">
                Showing {products.length} products
              </p>
            </div>

            {/* Sorting Actions */}
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-bold text-text-secondary">Sort By:</span>
              <div className="flex flex-wrap gap-1 bg-muted p-1 rounded-xl">
                {sortOptions.map((opt) => {
                  const isActive = sort === opt.value
                  return (
                    <Link
                      key={opt.label}
                      href={`/category/${slug}${opt.value ? `?sort=${opt.value}` : ''}`}
                      className={cn(
                        "px-3 py-1 text-xs font-bold rounded-lg transition-colors whitespace-nowrap",
                        isActive
                          ? "bg-card text-text-primary shadow-sm"
                          : "text-text-secondary hover:text-text-primary"
                      )}
                    >
                      {opt.label}
                    </Link>
                  )
                })}
              </div>
            </div>
          </div>

          {/* Products Catalog Grid */}
          {products.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 border border-dashed border-border bg-card rounded-2xl text-center p-6 shadow-sm">
              <div className="w-16 h-16 bg-muted/40 rounded-full flex items-center justify-center mx-auto text-muted-foreground mb-4">
                <ShoppingBag className="h-8 w-8 animate-pulse-gentle" />
              </div>
              <h2 className="text-base font-bold text-text-primary">No products available</h2>
              <p className="text-xs text-text-secondary mt-1">
                We are currently restocking this category. Please check back in a few minutes!
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
              {products.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          )}
        </main>

      </div>
    </div>
  )
}
