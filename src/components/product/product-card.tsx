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
  const isB2BMode = useUIStore((s) => s.isB2BMode)
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

    // Trigger Cart Fly Animation
    if (imageRef.current) {
      const rect = imageRef.current.getBoundingClientRect()
      window.dispatchEvent(
        new CustomEvent('cart-item-fly', {
          detail: {
            startX: rect.left + rect.width / 2,
            startY: rect.top + rect.height / 2,
            imageUrl: product.imageUrl,
          },
        })
      )
    }
  }, [addItem, cartProduct, product.imageUrl])

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
    <div className="group relative flex flex-col justify-between overflow-hidden rounded-3xl border border-border/60 dark:border-zinc-800/60 bg-card dark:bg-zinc-900/80 p-2.5 sm:p-3 shadow-card transition-all duration-400 hover:shadow-[0_8px_30px_rgba(226,10,34,0.12),0_2px_8px_rgba(0,0,0,0.06)] dark:hover:shadow-[0_8px_30px_rgba(226,10,34,0.2),0_2px_8px_rgba(0,0,0,0.3)] hover:border-primary/25 hover:-translate-y-1.5 hover:scale-[1.01]">
      {/* Cart Add Success Animation Overlay (with smooth enter and exit transitions) */}
      <AnimatePresence>
        {showAdded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="absolute inset-0 z-30 flex items-center justify-center bg-[#2e7d32]/10 rounded-3xl pointer-events-none"
          >
            <motion.div
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ type: 'spring', damping: 15, stiffness: 220 }}
              className="flex h-12 w-12 items-center justify-center rounded-full bg-[#2e7d32] text-white shadow-lg"
            >
              <Check className="h-6 w-6" strokeWidth={3} />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <Link href={`/product/${product.slug}`} className="flex flex-col flex-grow">

        {/* Discount Badge — top left */}
        {product.discount > 0 && (
          <div className="absolute left-2 top-2 z-10 rounded-full bg-gradient-to-r from-[#ff5722] to-[#ff9800] dark:from-[#ff5722] dark:to-[#ff9800] px-2 py-0.5 text-[9px] md:text-[10px] font-black text-white shadow-md whitespace-nowrap pointer-events-none select-none animate-badge-bounce">
            {product.discount}% OFF
          </div>
        )}



        {/* Image Container */}
        <div ref={imageRef} className="relative aspect-square w-full overflow-hidden rounded-2xl bg-transparent flex items-center justify-center mb-3">
          <ProductImage
            src={product.imageUrl}
            alt={product.name}
            categorySlug={categorySlug}
            isBestseller={product.tags?.includes('popular')}
            className="h-full w-full object-contain p-2 transition-transform duration-300 group-hover:scale-105"
          />

          {/* Bestseller Tag */}
          {product.tags?.includes('popular') && (
            <div className="absolute bottom-1 left-1 z-10 flex items-center gap-0.5 rounded-md bg-amber-500/90 px-1.5 py-0.5 text-[10px] font-bold text-white shadow-sm">
              ⭐ Bestseller
            </div>
          )}
        </div>

        {/* Product Info */}
        <div className="flex flex-col flex-grow">
          {/* Name */}
          <h3 className="text-sm md:text-base font-extrabold text-text-primary line-clamp-2 leading-tight group-hover:text-primary transition-colors min-h-[2.5rem] mb-1">
            {product.name}
          </h3>
          {/* Unit */}
          <span className="text-xs font-bold text-text-muted mb-2">
            {product.unit}
          </span>
          {product.stock > 0 && product.stock <= 5 && (
            <span className="text-[10px] font-bold text-red-500 dark:text-red-400">
              Only {product.stock} left!
            </span>
          )}
          
          {/* Pricing Row */}
          <div className="mt-1">
            {isB2BMode ? (
              <div className="flex flex-col">
                <span className="text-base font-black text-text-primary">
                  ₹{(product.price * 0.9).toFixed(0)}
                </span>
                <span className="text-[9px] text-primary font-black uppercase tracking-wider -mt-0.5">
                  Wholesale Price
                </span>
              </div>
            ) : (
              <div className="flex items-baseline gap-1.5 flex-wrap">
                <span className="text-base sm:text-lg md:text-xl font-black text-text-primary">
                  ₹{product.price}
                </span>
                {product.mrp > product.price && (
                  <span className="text-[10px] sm:text-xs md:text-sm text-text-muted line-through font-bold">
                    ₹{product.mrp}
                  </span>
                )}
              </div>
            )}
          </div>
        </div>
      </Link>

      {/* Bottom Row: Savings and Add Button */}
      <div className="flex items-center justify-between gap-1.5 sm:gap-2 mt-3 pt-2.5 border-t border-border/40 dark:border-zinc-700/40 w-full min-w-0">
        {/* Savings on the left (never wraps, truncates if space is extremely tight, never overlaps) */}
        <div className="min-w-0 flex-1">
          {savings > 0 && !isB2BMode && (
            <span 
              className="text-[9px] min-[375px]:text-[10px] sm:text-xs font-black text-[#2e7d32] dark:text-emerald-400 block truncate tracking-tight"
              title={`Save ₹${savings}`}
            >
              Save ₹{savings}
            </span>
          )}
        </div>

        {/* Add to Cart Actions on the right (shrink-0 ensures button is always fully visible) */}
        <div className="relative h-9 w-[72px] sm:w-24 shrink-0 flex-shrink-0">
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
                  className="w-full h-full border-2 border-[#2e7d32] bg-gradient-to-b from-white to-green-50/50 dark:from-zinc-900 dark:to-zinc-800 text-[#2e7d32] dark:text-emerald-400 text-xs sm:text-sm font-black hover:bg-gradient-to-b hover:from-[#2e7d32] hover:to-[#1b5e20] hover:text-white hover:border-[#1b5e20] rounded-xl hover:scale-[1.03] active:scale-95 transition-all duration-250 flex items-center justify-center gap-0.5 sm:gap-1 cursor-pointer shadow-sm hover:shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {product.stock <= 0 ? (
                    'Out'
                  ) : isStoreClosed ? (
                    'Closed'
                  ) : (
                    <>
                      ADD
                      <Plus className="h-3 w-3 sm:h-3.5 sm:w-3.5 stroke-[3]" />
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
                className="flex h-full w-full items-center justify-between rounded-xl bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold shadow-md overflow-hidden transition-all duration-300"
              >
                <button
                  onClick={handleDecrement}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all cursor-pointer"
                  aria-label="Decrease quantity"
                >
                  <Minus className="h-3.5 w-3.5 sm:h-4 sm:w-4 stroke-[3]" />
                </button>
                <span className="w-6 sm:w-8 shrink-0 flex items-center justify-center text-xs sm:text-sm font-black select-none h-full bg-[#2e7d32] border-x border-white/20">
                  {quantity}
                </span>
                <button
                  onClick={handleIncrement}
                  disabled={quantity >= product.stock || isStoreClosed}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all disabled:opacity-50 cursor-pointer"
                  aria-label="Increase quantity"
                >
                  <Plus className="h-3.5 w-3.5 sm:h-4 sm:w-4 stroke-[3]" />
                </button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  )
}
