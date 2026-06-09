'use client'

import { useState, useCallback, useMemo, useRef } from 'react'
import Link from 'next/link'
import { Plus, Minus, Check, Zap } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { Button } from '@/components/ui/button'
import { Product } from '@/types'
import { useUIStore } from '@/stores/ui-store'
import { ProductImage } from '@/components/product/product-image'
import { motion, AnimatePresence } from 'framer-motion'

interface ProductCardProps {
  product: Product
}

import { isCafeProduct } from '@/lib/utils'

export function ProductCard({ product }: ProductCardProps) {

  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const quantity = getItemQuantity(product.id)
  const [showAdded, setShowAdded] = useState(false)
  const imageRef = useRef<HTMLDivElement>(null)

  const isCafe = isCafeProduct(product)
  const isStoreClosed = isCafe ? !cafeOpen : !groceryMartOpen

  // Map of category slug to emoji representation
  const emojiMap: Record<string, string> = {
    'fruits-vegetables': '🥬',
    'dairy-breakfast': '🥛',
    'snacks-munchies': '🍿',
    'beverages': '🥤',
    'personal-care': '🧴',
    'household': '🏠',
    'bakery-biscuits': '🍞',
    'atta-rice-dal': '🌾',
  }

  const categorySlug = product.category?.slug || ''
  const categoryEmoji = emojiMap[categorySlug] || '🛒'

  const cartProduct = useMemo(() => ({
    id: product.id,
    name: product.name,
    slug: product.slug,
    imageUrl: product.imageUrl,
    mrp: product.mrp,
    price: product.price,
    discount: product.discount,
    unit: product.unit,
    stock: product.stock,
    category: product.category,
  }), [product])

  const handleAdd = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    addItem(cartProduct)
    setShowAdded(true)
    setTimeout(() => setShowAdded(false), 600)

  }, [addItem, cartProduct])

  const handleIncrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    updateQuantity(product.id, product.name, quantity + 1)
  }

  const handleDecrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    updateQuantity(product.id, product.name, quantity - 1)
  }

  const savings = product.mrp - product.price

  return (
    <div className="group relative flex flex-col justify-between overflow-hidden rounded-xl border border-border/60 dark:border-zinc-800/60 bg-card p-1 min-[375px]:p-1.5 sm:p-3 shadow-card transition-all duration-400 md:hover:shadow-[0_8px_30px_rgba(226,10,34,0.12),0_2px_8px_rgba(0,0,0,0.06)] md:dark:hover:shadow-[0_8px_30px_rgba(226,10,34,0.2),0_2px_8px_rgba(0,0,0,0.3)] md:hover:border-primary/25 md:hover:-translate-y-1.5 md:hover:scale-[1.01] active:scale-[0.98] md:active:scale-[1.01]">
      {/* Cart Add Success Animation Overlay (with smooth enter and exit transitions) */}
      <AnimatePresence>
        {showAdded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="absolute inset-0 z-30 flex items-center justify-center bg-[#2e7d32]/10 rounded-xl pointer-events-none"
          >
            <motion.div
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ duration: 0.12, ease: 'easeOut' }}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-[#2e7d32] text-white shadow-lg"
            >
              <Check className="h-4 w-4" strokeWidth={3} />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <Link href={`/product/${product.slug}`} className="flex flex-col flex-grow">

        {/* Discount Badge — top left */}
        {product.discount > 0 && (
          <div className="absolute left-1 top-1 z-10 rounded-full bg-gradient-to-r from-[#ff5722] to-[#ff9800] dark:from-[#ff5722] dark:to-[#ff9800] px-1.5 py-0.5 text-[7px] min-[375px]:text-[8.5px] font-black text-white shadow-md whitespace-nowrap pointer-events-none select-none">
            {product.discount}% OFF
          </div>
        )}

        {/* Image Container */}
        <div ref={imageRef} className="relative aspect-square w-full overflow-hidden rounded-lg bg-muted/10 dark:bg-white/[0.02] flex items-center justify-center mb-0.5">
          <ProductImage
            src={product.imageUrl}
            alt={product.name}
            categorySlug={categorySlug}
            isBestseller={product.tags?.includes('popular')}
            className="h-full w-full object-contain p-1 transition-transform duration-300 md:group-hover:scale-105 group-active:scale-[0.97] md:group-active:scale-105"
          />

          {/* Bestseller Tag */}
          {product.tags?.includes('popular') && (
            <div className="absolute bottom-0.5 left-0.5 z-10 flex items-center gap-0.5 rounded bg-amber-500/90 px-1 py-0.5 text-[7px] min-[375px]:text-[8px] font-bold text-white shadow-sm">
              ⭐ Bestseller
            </div>
          )}
        </div>

        {/* Product Info */}
        <div className="flex flex-col flex-grow">
          {/* Name */}
          <h3 className="text-[10px] min-[375px]:text-[11px] sm:text-xs md:text-sm font-extrabold text-text-primary line-clamp-2 leading-tight md:group-hover:text-primary transition-colors min-h-[22px] min-[375px]:min-h-[26px] sm:min-h-[32px] mb-0.5">
            {product.name}
          </h3>
          {/* Unit */}
          <span className="text-[8px] min-[375px]:text-[9px] sm:text-xs font-bold text-text-muted mb-0.5">
            {product.unit}
          </span>
          {product.stock > 0 && product.stock < 15 && (
            <span className="text-[8px] min-[375px]:text-[9px] font-bold text-red-500 dark:text-red-400 mb-0.5">
              Only {product.stock} left!
            </span>
          )}
        </div>
      </Link>

      {/* Consolidated Bottom Row: Price, MRP, Savings and ADD Button */}
      <div className="flex items-end justify-between gap-1 mt-1 w-full min-w-0">
        {/* Left Side: Pricing & Savings */}
        <div className="flex flex-col min-w-0 flex-1">
          <div className="flex items-baseline gap-1 flex-wrap leading-none">
            <span className="text-[10px] min-[375px]:text-xs sm:text-base font-black text-text-primary">
              ₹{product.price}
            </span>
            {product.mrp > product.price && (
              <span className="text-[8px] min-[375px]:text-[9px] text-text-muted line-through font-bold">
                ₹{product.mrp}
              </span>
            )}
          </div>
          {savings > 0 && (
            <span 
              className="text-[7.5px] min-[375px]:text-[8px] font-black text-[#2e7d32] dark:text-emerald-400 mt-0.5 block truncate tracking-tight leading-none"
              title={`Save ₹${savings}`}
            >
              Save ₹{savings}
            </span>
          )}
        </div>

        {/* Right Side: Add to Cart Actions */}
        <div className="relative h-8 sm:h-9 w-[64px] min-[375px]:w-[72px] sm:w-20 shrink-0 flex-shrink-0">
          <AnimatePresence mode="wait">
            {quantity === 0 ? (
              <motion.div
                key="add-to-cart-button"
                initial={{ opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.15 }}
                className="w-full h-full"
              >
                <Button
                  onClick={handleAdd}
                  disabled={product.stock <= 0 || isStoreClosed}
                  className="w-full h-full border border-[#2e7d32] bg-gradient-to-b from-white to-green-50/50 dark:from-zinc-900 dark:to-zinc-800 text-[#2e7d32] dark:text-emerald-400 text-[10px] sm:text-xs font-black md:hover:bg-[#2e7d32] md:hover:text-white rounded-md md:hover:scale-[1.03] active:scale-95 transition-all duration-200 flex items-center justify-center gap-0.5 cursor-pointer shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {product.stock <= 0 ? (
                    'Out'
                  ) : isStoreClosed ? (
                    'Closed'
                  ) : (
                    <>
                      ADD
                      <Plus className="h-2.5 w-2.5 sm:h-3 sm:w-3 stroke-[3]" />
                    </>
                  )}
                </Button>
              </motion.div>
            ) : (
              <motion.div
                key="qty-counter-selector"
                initial={{ opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.15 }}
                className="flex h-full w-full items-center justify-between rounded-md bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold shadow-sm overflow-hidden transition-all duration-300"
              >
                <button
                  onClick={handleDecrement}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all cursor-pointer"
                  aria-label="Decrease quantity"
                >
                  <Minus className="h-2 w-2 sm:h-3 sm:w-3 stroke-[3]" />
                </button>
                <span className="w-4 min-[375px]:w-5 sm:w-7 shrink-0 flex items-center justify-center text-[9px] sm:text-xs font-black select-none h-full bg-[#2e7d32] border-x border-white/20">
                  {quantity}
                </span>
                <button
                  onClick={handleIncrement}
                  disabled={quantity >= product.stock || isStoreClosed}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all disabled:opacity-50 cursor-pointer"
                  aria-label="Increase quantity"
                >
                  <Plus className="h-2 w-2 sm:h-3 sm:w-3 stroke-[3]" />
                </button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  )
}
