import { prisma } from '@/lib/prisma'
import { ProductCard } from '@/components/product/product-card'
import Link from 'next/link'
import { ChevronRight, Flame } from 'lucide-react'

// Revalidate page every 30 seconds to keep quantities synced
export const revalidate = 30

export default async function CafePage() {
  // 1. Self-healing seeding for Cafe category & hot food products
  let cafeCategory = await prisma.category.findUnique({
    where: { slug: 'cafe' }
  })

  if (!cafeCategory) {
    try {
      cafeCategory = await prisma.category.create({
        data: {
          name: 'FastKirana Cafe',
          slug: 'cafe',
          imageUrl: '☕',
          sortOrder: 0,
        }
      })
    } catch (e) {
      // Handle concurrent creation
      cafeCategory = await prisma.category.findUnique({
        where: { slug: 'cafe' }
      })
    }
  }

  // Define hot cafe items to seed if they do not exist
  const hotCafeProducts = [
    {
      name: 'Special Masala Chai',
      slug: 'special-masala-chai',
      description: 'Hot steaming milk tea brewed with fresh ginger, cardamom, and premium tea leaves.',
      imageUrl: '☕',
      mrp: 35,
      price: 30,
      discount: 14,
      unit: '1 cup (150 ml)',
      stock: 100,
      tags: ['cafe', 'hot-beverage', 'breakfast', 'tea', 'popular'],
    },
    {
      name: 'Hot Filter Coffee',
      slug: 'hot-filter-coffee',
      description: 'Traditional South Indian filter coffee brewed with fresh milk and premium chicory blend.',
      imageUrl: '☕',
      mrp: 45,
      price: 40,
      discount: 11,
      unit: '1 cup (150 ml)',
      stock: 100,
      tags: ['cafe', 'hot-beverage', 'breakfast', 'coffee', 'popular'],
    },
    {
      name: 'Fresh Samosa (2 pcs)',
      slug: 'fresh-samosa-2pcs',
      description: 'Crispy golden pastry stuffed with spiced potato and peas filling. Served hot with sweet tamarind and spicy green chutney.',
      imageUrl: '🥟',
      mrp: 35,
      price: 30,
      discount: 14,
      unit: '1 plate (2 pcs)',
      stock: 80,
      tags: ['cafe', 'hot-bite', 'snacks', 'samosa', 'popular'],
    },
    {
      name: 'Veg Grilled Sandwich',
      slug: 'veg-grilled-sandwich',
      description: 'Golden grilled bread stuffed with fresh cucumber, tomato, onion slices, and green chutney spreads.',
      imageUrl: '🥪',
      mrp: 99,
      price: 79,
      discount: 20,
      unit: '1 pc',
      stock: 60,
      tags: ['cafe', 'hot-bite', 'breakfast', 'snacks'],
    },
    {
      name: 'Veg Momos (6 pcs)',
      slug: 'veg-momos-6pcs',
      description: 'Steamed thin wrappers stuffed with minced cabbage, carrots, onion, and spices. Served with fire-hot red chilli garlic dip.',
      imageUrl: '🥟',
      mrp: 80,
      price: 69,
      discount: 13,
      unit: '1 plate (6 pcs)',
      stock: 60,
      tags: ['cafe', 'hot-bite', 'snacks', 'popular'],
    }
  ]

  for (const item of hotCafeProducts) {
    const existing = await prisma.product.findUnique({
      where: { slug: item.slug }
    })
    if (!existing && cafeCategory) {
      await prisma.product.create({
        data: {
          name: item.name,
          slug: item.slug,
          description: item.description,
          imageUrl: item.imageUrl,
          categoryId: cafeCategory.id,
          mrp: item.mrp,
          price: item.price,
          discount: item.discount,
          unit: item.unit,
          stock: item.stock,
          isAvailable: true,
          tags: item.tags,
        }
      }).catch(err => console.error('Failed to dynamically seed cafe product:', err))
    }
  }

  // 2. Fetch all products under Cafe category or tagged with 'cafe'
  const dbCafeProducts = await prisma.product.findMany({
    where: {
      OR: [
        { categoryId: cafeCategory?.id },
        { tags: { has: 'cafe' } },
        { slug: { in: ['croissant-butter', 'muffin-chocolate', 'nescafe-classic', 'tata-tea-gold', 'maggi-noodles', 'lays-classic-salted', 'coca-cola', 'sprite', 'red-bull-energy'] } }
      ],
      isAvailable: true,
    },
    include: { category: true }
  })

  // Group products into custom categories for layout
  const hotBrews = dbCafeProducts.filter(p => p.tags.includes('hot-beverage') || ['nescafe-classic', 'tata-tea-gold'].includes(p.slug))
  const hotBites = dbCafeProducts.filter(p => p.tags.includes('hot-bite') || ['maggi-noodles'].includes(p.slug))
  const bakery = dbCafeProducts.filter(p => ['croissant-butter', 'muffin-chocolate', 'lays-classic-salted'].includes(p.slug) || p.category?.slug === 'bakery-biscuits')
  const chilled = dbCafeProducts.filter(p => ['coca-cola', 'sprite', 'red-bull-energy'].includes(p.slug))

  // Safe mapping helper
  const mapProduct = (p: any) => ({
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
    category: p.category ? {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
      imageUrl: p.category.imageUrl,
      parentId: p.category.parentId,
      sortOrder: p.category.sortOrder,
    } : undefined
  })

  return (
    <div className="container mx-auto px-4 py-6 max-w-7xl space-y-8">
      {/* Breadcrumb */}
      <nav className="flex items-center gap-1.5 text-xs md:text-sm font-semibold">
        <Link href="/" className="text-text-muted hover:text-primary transition-colors">Home</Link>
        <ChevronRight size={14} className="text-text-muted" />
        <span className="font-bold text-rose-600">FastKirana Cafe ☕</span>
      </nav>

      {/* Hero Cafe Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-rose-500 via-pink-500 to-orange-500 p-6 md:p-10 text-white shadow-xl">
        <div className="relative z-10 max-w-lg space-y-3">
          <span className="inline-flex items-center gap-1 rounded-full bg-white/20 backdrop-blur-sm px-3 py-1 text-[10px] font-black tracking-wider uppercase">
            <Flame className="h-3 w-3 text-orange-200 fill-orange-200" />
            Freshly Prepared & Hot
          </span>
          <h1 className="text-2xl md:text-4xl font-black leading-tight tracking-tight">
            FastKirana Cafe
          </h1>
          <p className="text-xs md:text-sm text-white/95 leading-relaxed font-semibold">
            Steaming hot tea, fresh filter coffee, and delicious hot bites delivered alongside your groceries in just 10 minutes!
          </p>
          <div className="flex items-center gap-4 pt-2 text-[10px] md:text-xs font-bold text-white/90">
            <span className="flex items-center gap-1 bg-white/10 px-2.5 py-1 rounded-lg">⚡ 10 Min Delivery</span>
            <span className="flex items-center gap-1 bg-white/10 px-2.5 py-1 rounded-lg">🔥 Steaming Hot</span>
          </div>
        </div>
        
        {/* Floating emoji decorations */}
        <div className="absolute right-4 md:right-10 top-1/2 -translate-y-1/2 text-8xl md:text-9xl opacity-30 select-none pointer-events-none animate-bounce-gentle">
          ☕
        </div>
      </div>

      {/* Section 1: Hot Brews */}
      {hotBrews.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">☕</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Steaming Hot Brews</h2>
              <p className="text-xs text-text-secondary">Chai, coffee, and fresh brewing mixes</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {hotBrews.map(p => (
              <ProductCard key={p.id} product={mapProduct(p)} />
            ))}
          </div>
        </section>
      )}

      {/* Section 2: Hot Bites */}
      {hotBites.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥟</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Quick Bites & Snacks</h2>
              <p className="text-xs text-text-secondary">Samosas, Momos, and warm treats</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {hotBites.map(p => (
              <ProductCard key={p.id} product={mapProduct(p)} />
            ))}
          </div>
        </section>
      )}

      {/* Section 3: Bakery & Desserts */}
      {bakery.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥐</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Bakery & Sweet Cravings</h2>
              <p className="text-xs text-text-secondary">Freshly baked croissants, muffins, and sweet nibbles</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {bakery.map(p => (
              <ProductCard key={p.id} product={mapProduct(p)} />
            ))}
          </div>
        </section>
      )}

      {/* Section 4: Chilled Sodas */}
      {chilled.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥤</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Chilled Sips & Sodas</h2>
              <p className="text-xs text-text-secondary">Carbonated soft drinks and cold energy boosts</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {chilled.map(p => (
              <ProductCard key={p.id} product={mapProduct(p)} />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
