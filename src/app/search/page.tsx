import Link from 'next/link'
import { prisma } from '@/lib/prisma'
import { ProductCard } from '@/components/product/product-card'
import { Product } from '@/types'
import { Search, Frown } from 'lucide-react'
import { sortProductsByStock } from '@/lib/utils'

interface SearchPageProps {
  searchParams: Promise<{ q?: string }>
}

export const revalidate = 0 // Search is dynamic

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const { q } = await searchParams
  const query = q?.trim() || ''

  let products: Product[] = []

  if (query) {
    const words = query.split(/\s+/).filter(Boolean)

    const productsRaw = await prisma.product.findMany({
      where: {
        isAvailable: true,
        AND: words.map((word) => ({
          OR: [
            { name: { contains: word, mode: 'insensitive' } },
            { description: { contains: word, mode: 'insensitive' } },
            { tags: { hasSome: [word.toLowerCase()] } },
            { category: { name: { contains: word, mode: 'insensitive' } } },
          ],
        })),
      },
      include: {
        category: true,
      },
    }).catch(() => [])

    products = sortProductsByStock(productsRaw.map((p) => ({
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
      category: p.category ? {
        id: p.category.id,
        name: p.category.name,
        slug: p.category.slug,
        imageUrl: p.category.imageUrl,
        parentId: p.category.parentId,
        sortOrder: p.category.sortOrder,
      } : undefined,
    })))
  }

  // Get dynamic suggestions (trending/popular items in DB)
  let dynamicSuggestions: { label: string; query: string }[] = []
  try {
    // 1. Group by order items to find top ordered products
    const trendingOrderItems = await (prisma.orderItem.groupBy as any)({
      by: ['productId'],
      _sum: {
        quantity: true,
      },
      orderBy: {
        _sum: {
          quantity: 'desc',
        },
      },
      take: 12,
    }).catch(() => [])

    const trendingProductIds = trendingOrderItems
      .map((item: any) => item.productId)
      .filter((id: any): id is string => id !== null)

    const whereClause = {
      isAvailable: true,
      NOT: [
        { tags: { has: 'cafe' } },
        { category: { slug: 'cafe' } }
      ]
    }

    const featuredProducts = await prisma.product.findMany({
      where: {
        ...whereClause,
        OR: [
          { isTopPick: true },
          { isBestSeller: true },
          { id: { in: trendingProductIds } }
        ]
      },
      select: {
        name: true,
      },
      take: 10
    })

    let finalSuggestions = [...featuredProducts]

    if (finalSuggestions.length < 10) {
      const existingNames = finalSuggestions.map(p => p.name)
      const popularProducts = await prisma.product.findMany({
        where: {
          ...whereClause,
          tags: { has: 'popular' },
          name: { notIn: existingNames }
        },
        select: {
          name: true,
        },
        take: 10 - finalSuggestions.length
      })
      finalSuggestions = [...finalSuggestions, ...popularProducts]
    }

    if (finalSuggestions.length < 10) {
      const existingNames = finalSuggestions.map(p => p.name)
      const anyProducts = await prisma.product.findMany({
        where: {
          ...whereClause,
          name: { notIn: existingNames }
        },
        select: {
          name: true,
        },
        take: 10 - finalSuggestions.length
      })
      finalSuggestions = [...finalSuggestions, ...anyProducts]
    }

    const emojiMap: Record<string, string> = {
      milk: '🥛',
      bread: '🍞',
      onion: '🧅',
      potato: '🥔',
      tomato: '🍅',
      chips: '🍿',
      tea: '☕',
      chai: '☕',
      atta: '🌾',
      maggi: '🍜',
      soap: '🧼',
      butter: '🧈',
      egg: '🥚',
      eggs: '🥚',
      rice: '🌾',
      paneer: '🧀',
      coke: '🥤',
      cola: '🥤',
      biscuit: '🍪',
      biscuits: '🍪',
      chocolate: '🍫',
      oil: '🛢️',
      ghee: '🥛',
      curd: '🥛',
      cheese: '🧀',
      salt: '🧂',
      sugar: '🍬',
      coffee: '☕',
      water: '💧',
      juice: '🧃',
      soda: '🥤',
    }

    dynamicSuggestions = finalSuggestions.map(p => {
      const nameLower = p.name.toLowerCase()
      let emoji = ''
      for (const [key, value] of Object.entries(emojiMap)) {
        if (nameLower.includes(key)) {
          emoji = ` ${value}`
          break
        }
      }
      return {
        label: `${p.name}${emoji}`,
        query: p.name.trim()
      }
    })
  } catch (err) {
    console.warn('Failed to load dynamic suggestions on search page:', err)
  }

  const suggestions = dynamicSuggestions.length > 0 ? dynamicSuggestions : [
    { label: 'Milk 🥛', query: 'milk' },
    { label: 'Bread 🍞', query: 'bread' },
    { label: 'Onion 🧅', query: 'onion' },
    { label: 'Potato 🥔', query: 'potato' },
    { label: 'Tomato 🍅', query: 'tomato' },
    { label: 'Chips 🍿', query: 'chips' },
    { label: 'Chai ☕', query: 'tea' },
    { label: 'Atta 🌾', query: 'atta' },
    { label: 'Maggi 🍜', query: 'maggi' },
    { label: 'Soap 🧼', query: 'soap' },
  ]

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl space-y-6">
      
      {/* Search Header */}
      <div className="border-b border-border/60 pb-4">
        <h1 className="text-lg md:text-2xl font-extrabold text-text-primary tracking-tight flex items-center gap-2">
          <Search className="h-5 w-5 md:h-6 md:w-6 text-text-secondary" />
          {query ? (
            <>
              Search Results for <span className="text-primary">"{query}"</span>
            </>
          ) : (
            'Search Products'
          )}
        </h1>
        {query && (
          <p className="text-xs text-text-secondary mt-1">
            Found {products.length} matching products
          </p>
        )}
      </div>

      {/* Search results listing */}
      {!query ? (
        // Initial state before search
        <div className="max-w-md mx-auto text-center py-16 space-y-6">
          <div className="w-16 h-16 bg-muted/40 rounded-full flex items-center justify-center mx-auto text-muted-foreground">
            <Search className="h-8 w-8 animate-pulse-gentle" />
          </div>
          <div>
            <h2 className="text-base font-bold text-text-primary">What are you looking for?</h2>
            <p className="text-xs text-text-secondary mt-1">
              Type the name of any grocery or household essential in the search bar above.
            </p>
          </div>
          
          {/* Quick suggestions list */}
          <div className="space-y-2.5 pt-4">
            <h3 className="text-xs font-bold text-text-secondary uppercase tracking-wide">Popular Searches</h3>
            <div className="flex flex-wrap justify-center gap-2">
              {suggestions.map((item) => (
                <Link
                  key={item.label}
                  href={`/search?q=${item.query}`}
                  className="px-3.5 py-1.5 text-xs font-bold bg-card border border-border hover:border-primary/40 hover:bg-muted/30 rounded-full transition-colors text-text-primary"
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </div>
        </div>
      ) : products.length === 0 ? (
        // No results empty state
        <div className="max-w-md mx-auto text-center py-16 space-y-6">
          <div className="w-16 h-16 bg-muted/40 rounded-full flex items-center justify-center mx-auto text-muted-foreground">
            <Frown className="h-8 w-8 animate-bounce-subtle" />
          </div>
          <div>
            <h2 className="text-base font-bold text-text-primary">No matching products found</h2>
            <p className="text-xs text-text-secondary mt-1">
              We couldn't find anything matching "{query}". Try checking your spelling or search something else.
            </p>
          </div>
          
          {/* Quick suggestions list as fallback */}
          <div className="space-y-2.5 pt-4">
            <h3 className="text-xs font-bold text-text-secondary uppercase tracking-wide">Try searching instead</h3>
            <div className="flex flex-wrap justify-center gap-2">
              {suggestions.map((item) => (
                <Link
                  key={item.label}
                  href={`/search?q=${item.query}`}
                  className="px-3.5 py-1.5 text-xs font-bold bg-card border border-border hover:border-primary/40 hover:bg-muted/30 rounded-full transition-colors text-text-primary"
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </div>
        </div>
      ) : (
        // Results catalog grid
        <div className="grid grid-cols-2 min-[375px]:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 animate-fade-in px-1">
          {products.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      )}

    </div>
  )
}
