'use client'

import { useRef } from 'react'
import { ChevronLeft, ChevronRight, Plus, Salad, Milk, Cookie, CupSoda, Sparkles, Home, Croissant, Wheat, ShoppingBag, History } from 'lucide-react'
import { useCartStore } from '@/stores/cart-store'
import { formatPrice } from '@/lib/utils'
import { toast } from 'sonner'

const iconMap: Record<string, React.ComponentType<any>> = {
  'fruits-vegetables': Salad,
  'dairy-breakfast': Milk,
  'snacks-munchies': Cookie,
  'beverages': CupSoda,
  'personal-care': Sparkles,
  'household': Home,
  'bakery-biscuits': Croissant,
  'atta-rice-dal': Wheat,
}

interface BuyAgainItem {
  id: string
  name: string
  slug: string
  emoji: string
  price: number
  mrp: number
  unit: string
  lastOrderedDays: number
  categorySlug: string
}

const MOCK_BUY_AGAIN_ITEMS: BuyAgainItem[] = [
  {
    id: 'cmpxxtm2h000su8idf678npyj',
    name: 'Amul Taaza Milk',
    slug: 'amul-taaza-milk',
    emoji: '🥛',
    price: 27,
    mrp: 27,
    unit: '500 ml',
    lastOrderedDays: 3,
    categorySlug: 'dairy-breakfast',
  },
  {
    id: 'cmpxxtm3f0012u8id0qcaxr17',
    name: 'Maggi Noodles',
    slug: 'maggi-noodles',
    emoji: '🍜',
    price: 52,
    mrp: 56,
    unit: '280 g (4-pack)',
    lastOrderedDays: 5,
    categorySlug: 'snacks-munchies',
  },
  {
    id: 'cmpxxtm75002au8idnznyrntl',
    name: 'Aashirvaad Atta',
    slug: 'aashirvaad-atta',
    emoji: '🌾',
    price: 265,
    mrp: 295,
    unit: '5 kg',
    lastOrderedDays: 12,
    categorySlug: 'atta-rice-dal',
  },
  {
    id: 'cmpxxtm2k000tu8idhemvnlj4',
    name: 'Bread - White',
    slug: 'bread-white',
    emoji: '🍞',
    price: 35,
    mrp: 40,
    unit: '400 g',
    lastOrderedDays: 2,
    categorySlug: 'bakery-biscuits',
  },
  {
    id: 'cmpxxtm2z0017u8id4jp136oc',
    name: 'Tata Tea Gold',
    slug: 'tata-tea-gold',
    emoji: '🍵',
    price: 249,
    mrp: 270,
    unit: '500 g',
    lastOrderedDays: 15,
    categorySlug: 'beverages',
  },
  {
    id: 'cmpxxtm6g0020u8idhnc9sgkp',
    name: 'Parle-G Biscuits',
    slug: 'parle-g-biscuits',
    emoji: '🍪',
    price: 72,
    mrp: 80,
    unit: '800 g',
    lastOrderedDays: 7,
    categorySlug: 'bakery-biscuits',
  },
]

export function BuyAgainSection() {
  const scrollRef = useRef<HTMLDivElement>(null)
  const addItem = useCartStore((s) => s.addItem)

  const scroll = (direction: 'left' | 'right') => {
    if (scrollRef.current) {
      const { scrollLeft, clientWidth } = scrollRef.current
      const scrollTo =
        direction === 'left'
          ? scrollLeft - clientWidth * 0.6
          : scrollLeft + clientWidth * 0.6
      scrollRef.current.scrollTo({ left: scrollTo, behavior: 'smooth' })
    }
  }

  const handleAddToCart = (item: BuyAgainItem) => {
    addItem({
      id: item.id,
      name: item.name,
      slug: item.slug,
      imageUrl: null,
      mrp: item.mrp,
      price: item.price,
      discount: item.mrp > item.price ? Math.round(((item.mrp - item.price) / item.mrp) * 100) : 0,
      unit: item.unit,
      stock: 50,
    })
    toast.success(`${item.name} added to cart`, {
      id: `buyagain-${item.id}`,
    })
  }

  return (
    <section className="py-4">
      <div className="rounded-2xl bg-primary/5 border border-primary/10 p-4 md:p-5">
        {/* Section header */}
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-base md:text-2xl font-black text-text-primary tracking-tight flex items-center gap-2">
              <span className="flex-shrink-0 flex items-center justify-center p-1.5 rounded-lg bg-primary/10 border border-primary/20 text-primary">
                <History className="h-4 w-4" />
              </span>
              <span>Buy It Again</span>
            </h2>
            <p className="text-[11px] sm:text-xs text-text-secondary mt-0.5">
              Your favorites, one tap away
            </p>
          </div>
          <div className="hidden sm:flex items-center gap-1.5">
            <button
              onClick={() => scroll('left')}
              className="flex h-7 w-7 items-center justify-center rounded-full border border-border bg-card text-text-primary hover:bg-muted transition-colors shadow-sm"
              aria-label="Scroll left"
            >
              <ChevronLeft className="h-3.5 w-3.5" />
            </button>
            <button
              onClick={() => scroll('right')}
              className="flex h-7 w-7 items-center justify-center rounded-full border border-border bg-card text-text-primary hover:bg-muted transition-colors shadow-sm"
              aria-label="Scroll right"
            >
              <ChevronRight className="h-3.5 w-3.5" />
            </button>
          </div>
        </div>

        {/* Horizontal scroll of compact items */}
        <div
          ref={scrollRef}
          className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide scroll-smooth snap-x snap-mandatory"
          style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
        >
          {MOCK_BUY_AGAIN_ITEMS.map((item) => (
            <div
              key={item.id}
              className="w-[120px] flex-shrink-0 snap-start group"
            >
              <div className="flex flex-col items-center bg-card rounded-xl border border-border/60 p-3 h-full shadow-sm hover:shadow-card-hover hover:border-primary/20 transition-all duration-300">
                {/* Icon circle */}
                <div className="flex items-center justify-center w-12 h-12 rounded-full bg-primary/5 text-primary mb-2 group-hover:scale-110 transition-transform duration-300">
                  {(() => {
                    const IconComponent = iconMap[item.categorySlug] || ShoppingBag
                    return <IconComponent className="h-5 w-5 text-primary" />
                  })()}
                </div>

                {/* Product name */}
                <h3 className="text-xs font-semibold text-text-primary text-center line-clamp-2 leading-tight mb-1 min-h-[2rem]">
                  {item.name}
                </h3>

                {/* Last ordered */}
                <p className="text-[10px] text-text-muted mb-2">
                  {item.lastOrderedDays === 1
                    ? 'Yesterday'
                    : `${item.lastOrderedDays} days ago`}
                </p>

                {/* Price */}
                <div className="flex items-center gap-1 mb-2">
                  <span className="text-sm font-bold text-text-primary">
                    {formatPrice(item.price)}
                  </span>
                  {item.mrp > item.price && (
                    <span className="text-[10px] text-text-muted line-through">
                      {formatPrice(item.mrp)}
                    </span>
                  )}
                </div>

                {/* Quick ADD button */}
                <button
                  onClick={() => handleAddToCart(item)}
                  className="w-full flex items-center justify-center gap-0.5 py-1.5 px-2 rounded-lg border border-accent bg-accent/5 text-accent text-xs font-bold hover:bg-accent hover:text-white active:scale-95 transition-all duration-200"
                >
                  ADD
                  <Plus className="h-3 w-3" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
