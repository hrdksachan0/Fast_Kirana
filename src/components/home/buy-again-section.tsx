'use client'

import { useState, useEffect, useRef } from 'react'
import { ChevronLeft, ChevronRight, Plus, Minus, History } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { formatPrice, isCafeProduct, cn } from '@/lib/utils'
import { ProductImage } from '@/components/product/product-image'
import { motion, AnimatePresence } from 'framer-motion'
import { triggerHaptic } from '@/lib/haptic'

interface BuyAgainItem {
  id: string
  name: string
  slug: string
  imageUrl: string | null
  price: number
  mrp: number
  unit: string
  lastOrderedDays: number
  categorySlug: string
  stock?: number
  isAvailable?: boolean
  category?: any
}

export function BuyAgainSection() {
  const scrollRef = useRef<HTMLDivElement>(null)
  
  // Select store closure settings
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}

  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const [items, setItems] = useState<BuyAgainItem[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchItems() {
      try {
        const res = await fetch('/api/products/buy-again')
        if (res.ok) {
          const data = await res.json()
          setItems(data)
        }
      } catch (err) {
        console.error('Error fetching buy-again items:', err)
      } finally {
        setLoading(false)
      }
    }
    fetchItems()
  }, [])

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

  const handleAddToCart = (e: React.MouseEvent, item: BuyAgainItem) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')

    addItem({
      id: item.id,
      name: item.name,
      slug: item.slug,
      imageUrl: item.imageUrl,
      mrp: item.mrp,
      price: item.price,
      discount: item.mrp > item.price ? Math.round(((item.mrp - item.price) / item.mrp) * 100) : 0,
      unit: item.unit,
      stock: item.stock ?? 50,
      isAvailable: item.isAvailable ?? true,
      category: item.category,
    })
  }

  const handleIncrement = (e: React.MouseEvent, item: BuyAgainItem, quantity: number) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')
    updateQuantity(item.id, item.name, quantity + 1)
  }

  const handleDecrement = (e: React.MouseEvent, item: BuyAgainItem, quantity: number) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('medium')
    updateQuantity(item.id, item.name, quantity - 1)
  }

  if (loading) {
    return (
      <section className="py-4">
        <div className="rounded-2xl bg-primary/5 border border-primary/10 p-4 md:p-5">
          <div className="h-6 w-36 bg-muted/65 rounded mb-4 animate-pulse" />
          <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-none">
            {Array.from({ length: 6 }).map((_, idx) => (
              <div key={idx} className="w-[120px] flex-shrink-0 bg-card rounded-xl border border-border/60 p-3 h-[190px] shadow-sm animate-pulse flex flex-col items-center">
                <div className="w-12 h-12 rounded-xl bg-muted/50 mb-3 shrink-0" />
                <div className="h-3 w-5/6 bg-muted/55 rounded mb-2" />
                <div className="h-2.5 w-1/2 bg-muted/40 rounded mb-3" />
                <div className="h-3 w-1/3 bg-muted/50 rounded mb-4" />
                <div className="h-7 w-full bg-muted/45 rounded-lg" />
              </div>
            ))}
          </div>
        </div>
      </section>
    )
  }

  if (items.length === 0) return null

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
              className="flex h-7 w-7 items-center justify-center rounded-full border border-border bg-card text-text-primary hover:bg-muted transition-colors shadow-sm cursor-pointer"
              aria-label="Scroll left"
            >
              <ChevronLeft className="h-3.5 w-3.5" />
            </button>
            <button
              onClick={() => scroll('right')}
              className="flex h-7 w-7 items-center justify-center rounded-full border border-border bg-card text-text-primary hover:bg-muted transition-colors shadow-sm cursor-pointer"
              aria-label="Scroll right"
            >
              <ChevronRight className="h-3.5 w-3.5" />
            </button>
          </div>
        </div>

        {/* Horizontal scroll of compact items */}
        <div
          ref={scrollRef}
          className="flex gap-3 overflow-x-auto pb-2 scrollbar-none scroll-smooth snap-x snap-mandatory"
          style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
        >
          {items.map((item) => {
            const quantity = getItemQuantity(item.id)
            const isCafe = item.categorySlug === 'cafe'
            const isCatOpen = categoryStatus[item.categorySlug] !== false
            const isStoreClosed = isCafe 
              ? (!cafeOpen || !isCatOpen) 
              : (!groceryMartOpen || !isCatOpen)
              
            const stock = item.stock ?? 50
            const isLowStock = !isCafe && stock > 0 && stock <= 10

            return (
              <div
                key={item.id}
                className="w-[120px] flex-shrink-0 snap-start group"
              >
                <div className="flex flex-col items-center bg-card rounded-xl border border-border/60 p-3 h-full shadow-[0_2px_8px_rgba(0,0,0,0.03)] md:hover:-translate-y-1 md:hover:shadow-[0_8px_24px_rgba(0,0,0,0.06)] md:hover:border-primary/20 transition-all duration-300">
                  {/* Product Image */}
                  <div className="relative w-12 h-12 overflow-hidden rounded-xl bg-white dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-850 flex items-center justify-center mb-2 shrink-0 md:group-hover:scale-105 transition-transform duration-300">
                    <ProductImage
                      src={item.imageUrl}
                      alt={item.name}
                      categorySlug={item.categorySlug}
                      className="h-full w-full object-contain p-0.5"
                    />
                    
                    {/* Low stock mini warning */}
                    {isLowStock && (
                      <span className="absolute inset-x-0 bottom-0 bg-red-500/95 text-[7px] font-bold text-white text-center py-0.5 leading-none select-none">
                        Low Stock
                      </span>
                    )}
                  </div>

                  {/* Product name */}
                  <h3 className="text-xs font-semibold text-text-primary text-center line-clamp-2 leading-tight mb-1 min-h-[2rem]">
                    {item.name}
                  </h3>

                  {/* Last ordered days */}
                  <p className="text-[9.5px] text-text-muted mb-2 font-medium">
                    {item.lastOrderedDays === 1
                      ? 'Yesterday'
                      : `${item.lastOrderedDays} days ago`}
                  </p>

                  {/* Price */}
                  <div className="flex items-center gap-1 mb-2.5 leading-none">
                    <span className="text-xs font-bold text-text-primary">
                      {formatPrice(item.price)}
                    </span>
                    {item.mrp > item.price && (
                      <span className="text-[9.5px] text-text-muted line-through font-medium">
                        {formatPrice(item.mrp)}
                      </span>
                    )}
                  </div>

                  {/* Dynamic Action Button: Counter or ADD */}
                  <div className="w-full h-7">
                    <AnimatePresence mode="wait">
                      {quantity === 0 ? (
                        <motion.div
                          key="add"
                          initial={{ opacity: 0, scale: 0.95 }}
                          animate={{ opacity: 1, scale: 1 }}
                          exit={{ opacity: 0, scale: 0.95 }}
                          transition={{ duration: 0.12 }}
                          className="w-full h-full"
                        >
                          <button
                            onClick={(e) => handleAddToCart(e, item)}
                            disabled={isStoreClosed}
                            className={cn(
                              "w-full h-full flex items-center justify-center gap-0.5 rounded-lg border text-[10px] font-black transition-all duration-200 cursor-pointer shadow-sm",
                              isStoreClosed
                                ? "border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900/40 text-zinc-400 dark:text-zinc-500 cursor-not-allowed"
                                : "border-accent bg-accent/5 text-accent md:hover:bg-accent md:hover:text-white"
                            )}
                          >
                            {isStoreClosed ? (
                              'Closed'
                            ) : (
                              <>
                                ADD
                                <Plus className="h-2.5 w-2.5 stroke-[3.5]" />
                              </>
                            )}
                          </button>
                        </motion.div>
                      ) : (
                        <motion.div
                          key="counter"
                          initial={{ opacity: 0, scale: 0.95 }}
                          animate={{ opacity: 1, scale: 1 }}
                          exit={{ opacity: 0, scale: 0.95 }}
                          transition={{ duration: 0.12 }}
                          className="flex h-full w-full items-center justify-between rounded-lg bg-gradient-to-r from-accent to-rose-600 text-white font-bold shadow-sm overflow-hidden"
                        >
                          <motion.button
                            whileTap={{ scale: 0.82 }}
                            onClick={(e) => handleDecrement(e, item, quantity)}
                            className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all cursor-pointer"
                            aria-label="Decrease quantity"
                          >
                            <Minus className="h-2.5 w-2.5 stroke-[3]" />
                          </motion.button>
                          <span className="w-5 shrink-0 flex items-center justify-center text-[10px] font-black select-none h-full bg-accent border-x border-white/20">
                            {quantity}
                          </span>
                          <motion.button
                            whileTap={{ scale: 0.82 }}
                            onClick={(e) => handleIncrement(e, item, quantity)}
                            disabled={quantity >= stock || quantity >= (isCafe ? 10 : 5) || isStoreClosed}
                            className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all disabled:opacity-50 cursor-pointer"
                            aria-label="Increase quantity"
                          >
                            <Plus className="h-2.5 w-2.5 stroke-[3]" />
                          </motion.button>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
