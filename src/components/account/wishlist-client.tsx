'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { Heart, ShoppingBag, Trash2, Loader2, Sparkles, ArrowRight } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { ProductCard } from '@/components/product/product-card'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'

interface WishlistItem {
  id: string
  productId: string
  createdAt: string
  product: any
}

export function WishlistClient({ initialItems }: { initialItems?: WishlistItem[] } = {}) {
  const [items, setItems] = useState<WishlistItem[]>(initialItems || [])
  const [loading, setLoading] = useState(false)
  const [removingId, setRemovingId] = useState<string | null>(null)
  const [clearing, setClearing] = useState(false)

  const fetchWishlist = async () => {
    if (initialItems && initialItems.length > 0) return
    setLoading(true)
    try {
      const res = await fetch('/api/wishlist')
      if (!res.ok) throw new Error('Failed to fetch')
      const data = await res.json()
      setItems(data.items || [])
    } catch {
      toast.error('Failed to load wishlist')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchWishlist()
  }, [])

  const removeItem = async (productId: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation()
    triggerHaptic('light')
    setRemovingId(productId)
    try {
      const res = await fetch('/api/wishlist', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ productId }),
      })
      if (res.ok) {
        setItems((prev) => prev.filter((item) => item.productId !== productId))
        toast.success('Item removed from wishlist')
      } else {
        throw new Error('Failed')
      }
    } catch {
      toast.error('Failed to remove from wishlist')
    } finally {
      setRemovingId(null)
    }
  }

  const clearAllWishlist = async () => {
    if (items.length === 0) return
    triggerHaptic('medium')
    setClearing(true)
    try {
      await Promise.all(
        items.map((item) =>
          fetch('/api/wishlist', {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ productId: item.productId }),
          })
        )
      )
      setItems([])
      toast.success('Wishlist cleared')
    } catch {
      toast.error('Failed to clear wishlist')
    } finally {
      setClearing(false)
    }
  }

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-3">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="text-xs font-semibold text-text-secondary">Loading your wishlist...</p>
      </div>
    )
  }

  if (items.length === 0) {
    return (
      <div className="text-center py-16 sm:py-20 border border-dashed border-border/80 bg-card/60 backdrop-blur-sm rounded-3xl p-6 sm:p-10 space-y-4">
        <div className="h-16 w-16 mx-auto rounded-3xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-500 shadow-sm">
          <Heart className="h-8 w-8 stroke-[1.8]" />
        </div>
        <div className="space-y-1.5 max-w-xs mx-auto">
          <h3 className="text-base sm:text-lg font-black text-text-primary">Your Wishlist is Empty</h3>
          <p className="text-xs text-text-secondary font-medium leading-relaxed">
            Save your favorite grocery items and restaurant dishes here to order them quickly anytime!
          </p>
        </div>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-2.5 pt-3">
          <Link href="/" className="w-full sm:w-auto">
            <Button className="w-full sm:w-auto bg-primary hover:bg-primary/90 text-white font-black text-xs rounded-xl shadow-sm h-10 px-5">
              <ShoppingBag className="h-4 w-4 mr-2" />
              Explore Grocery Mart
            </Button>
          </Link>
          <Link href="/restaurant" className="w-full sm:w-auto">
            <Button variant="outline" className="w-full sm:w-auto font-black text-xs rounded-xl border-border hover:bg-muted h-10 px-5">
              🍽️ Order Food
            </Button>
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-4 animate-fade-in">
      {/* Top Controls Bar */}
      <div className="flex items-center justify-between bg-muted/40 border border-border/60 px-4 py-2.5 rounded-2xl">
        <div className="flex items-center gap-2">
          <span className="flex h-2 w-2 rounded-full bg-rose-500" />
          <span className="text-xs font-black text-text-primary">
            {items.length} {items.length === 1 ? 'Product' : 'Products'} Saved
          </span>
        </div>

        <button
          onClick={clearAllWishlist}
          disabled={clearing}
          className="text-[11px] font-bold text-rose-600 dark:text-rose-400 hover:text-rose-700 bg-rose-500/10 hover:bg-rose-500/15 border border-rose-500/20 px-3 py-1 rounded-xl transition-all active:scale-95 disabled:opacity-50 cursor-pointer flex items-center gap-1"
        >
          {clearing ? (
            <Loader2 className="h-3 w-3 animate-spin" />
          ) : (
            <Trash2 className="h-3 w-3" />
          )}
          Clear All
        </button>
      </div>

      {/* Mobile-First 2-Column Product Grid */}
      <div className="grid grid-cols-2 min-[540px]:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2.5 sm:gap-4">
        {items.map((item) => {
          if (!item.product) return null
          const isRemoving = removingId === item.productId

          return (
            <div key={item.id || item.productId} className="relative group/wishcard">
              {/* Overlay Remove Button */}
              <button
                type="button"
                onClick={(e) => removeItem(item.productId, e)}
                disabled={isRemoving}
                title="Remove from wishlist"
                className="absolute top-2 right-2 z-20 h-7 w-7 rounded-full bg-white/95 dark:bg-zinc-900/95 border border-border/80 shadow-md flex items-center justify-center text-rose-500 hover:bg-rose-500 hover:text-white transition-all active:scale-90 cursor-pointer"
              >
                {isRemoving ? (
                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                ) : (
                  <Trash2 className="h-3.5 w-3.5" />
                )}
              </button>

              {/* Real Interactive ProductCard */}
              <ProductCard product={item.product} />
            </div>
          )
        })}
      </div>
    </div>
  )
}

