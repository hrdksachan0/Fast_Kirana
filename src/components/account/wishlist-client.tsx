'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { Heart, ShoppingBag, Trash2, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'
import Image from 'next/image'

interface WishlistProduct {
  id: string
  name: string
  slug: string
  price: number
  mrp: number
  discount: number
  unit: string
  stock: number
  isAvailable: boolean
  imageUrl: string | null
  category?: {
    id: string
    name: string
    slug: string
    imageUrl: string | null
  }
}

interface WishlistItem {
  id: string
  productId: string
  createdAt: string
  product: WishlistProduct
}

export function WishlistClient({ initialItems }: { initialItems?: WishlistItem[] } = {}) {
  const [items, setItems] = useState<WishlistItem[]>(initialItems || [])
  const [loading, setLoading] = useState(false)
  const [removing, setRemoving] = useState<string | null>(null)

  const fetchWishlist = async () => {
    if (initialItems) return // Server already provided data
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

  const removeItem = async (productId: string) => {
    setRemoving(productId)
    try {
      await fetch('/api/wishlist', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ productId }),
      })
      setItems((prev) => prev.filter((item) => item.productId !== productId))
      toast.success('Removed from wishlist')
    } catch {
      toast.error('Failed to remove')
    } finally {
      setRemoving(null)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    )
  }

  if (items.length === 0) {
    return (
      <div className="text-center py-20 border border-dashed border-border bg-card rounded-2xl">
        <Heart className="h-12 w-12 mx-auto text-text-muted mb-4" />
        <h3 className="text-lg font-bold text-text-primary mb-2">Your wishlist is empty</h3>
        <p className="text-sm text-text-secondary mb-6">Save items you love for later</p>
        <Link href="/">
          <Button className="bg-primary text-white">Start Shopping</Button>
        </Link>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      {items.map((item) => (
        <div
          key={item.id}
          className="bg-card border border-border rounded-xl overflow-hidden group hover:shadow-md transition-all"
        >
          <Link href={`/product/${item.product.slug || item.product.id}`} className="block">
            <div className="relative aspect-square bg-muted/30">
              {item.product.imageUrl ? (
                <Image
                  src={item.product.imageUrl}
                  alt={item.product.name}
                  fill
                  className="object-cover"
                />
              ) : (
                <div className="flex items-center justify-center h-full">
                  <ShoppingBag className="h-12 w-12 text-text-muted" />
                </div>
              )}
              {!item.product.isAvailable && (
                <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                  <span className="text-white text-xs font-bold bg-black/70 px-3 py-1 rounded-full">
                    Out of Stock
                  </span>
                </div>
              )}
            </div>
          </Link>

          <div className="p-3 space-y-2">
            {item.product.category && (
              <span className="text-[10px] font-bold text-primary uppercase tracking-wider">
                {item.product.category.name}
              </span>
            )}
            <Link href={`/product/${item.product.slug || item.product.id}`}>
              <h3 className="text-sm font-semibold text-text-primary line-clamp-2 hover:text-primary transition-colors">
                {item.product.name}
              </h3>
            </Link>

            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-sm font-bold text-text-primary">
                {formatPrice(item.product.price)}
              </span>
              {item.product.mrp > item.product.price && (
                <>
                  <span className="text-xs text-text-secondary line-through">
                    {formatPrice(item.product.mrp)}
                  </span>
                  <span className="text-[10px] font-bold text-green-600 bg-green-50 px-1.5 py-0.5 rounded-full">
                    {item.product.discount}% OFF
                  </span>
                </>
              )}
            </div>

            <div className="flex items-center gap-2 pt-1">
              <Link href={`/product/${item.product.slug || item.product.id}`} className="flex-1">
                <Button
                  size="sm"
                  className="w-full text-[11px] font-bold bg-primary hover:bg-primary-dark text-white"
                  disabled={!item.product.isAvailable}
                >
                  <ShoppingBag className="h-3 w-3 mr-1" />
                  {item.product.isAvailable ? 'Add to Cart' : 'Unavailable'}
                </Button>
              </Link>
              <Button
                size="icon"
                variant="ghost"
                className="h-8 w-8 text-red-500 hover:text-red-600 hover:bg-red-50"
                onClick={() => removeItem(item.productId)}
                disabled={removing === item.productId}
              >
                {removing === item.productId ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Trash2 className="h-4 w-4" />
                )}
              </Button>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
