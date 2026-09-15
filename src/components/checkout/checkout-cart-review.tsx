'use client'

import Link from 'next/link'
import { ShoppingBag } from 'lucide-react'
import type { CartItem } from '@/stores/cart-store'
import { formatPrice } from '@/lib/formatters'

interface CheckoutCartReviewProps {
  items: CartItem[]
  cookingInstruction: string
  setCookingInstruction: (val: string) => void
}

export function CheckoutCartReview({
  items,
  cookingInstruction,
  setCookingInstruction,
}: CheckoutCartReviewProps) {
  return (
    <div className="border-t border-border/40 pt-4 space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
          <ShoppingBag className="h-4 w-4 text-primary" />
          <span>Order Items ({items.length})</span>
        </h3>
        <Link href="/cart" className="text-xs font-bold text-primary hover:underline">
          Edit Cart
        </Link>
      </div>

      <div className="rounded-2xl border border-border/70 bg-muted/10 p-3 sm:p-4 space-y-3">
        <div className="divide-y divide-border/40">
          {items.map((item) => (
            <div
              key={item.product.id}
              className="flex justify-between items-center py-2.5 first:pt-0 last:pb-0 text-xs font-semibold"
            >
              <div className="flex items-center gap-2.5 min-w-0 pr-2">
                {item.product.imageUrl && (
                  <img
                    src={item.product.imageUrl}
                    alt={item.product.name}
                    className="w-10 h-10 object-cover rounded-xl border border-border/50 shrink-0 bg-white"
                  />
                )}
                <div className="truncate">
                  <h4 className="text-text-primary font-bold truncate text-xs">
                    {item.product.name}
                  </h4>
                  <p className="text-[10.5px] text-text-muted mt-0.5">
                    {item.product.unit || '1 unit'} ×{' '}
                    <span className="font-bold text-text-primary">{item.quantity}</span>
                  </p>
                </div>
              </div>
              <span className="text-text-primary font-black shrink-0 text-xs">
                {formatPrice(item.product.price * item.quantity)}
              </span>
            </div>
          ))}
        </div>

        {/* Single Delivery / Cooking Note Input */}
        <div className="pt-2 border-t border-border/30">
          <div className="flex items-center gap-2 p-2 rounded-xl border border-border/70 bg-background focus-within:border-primary">
            <span className="text-sm shrink-0">📝</span>
            <input
              type="text"
              placeholder="Add delivery instructions (e.g. Ring bell, leave at door)..."
              value={cookingInstruction}
              onChange={(e) => setCookingInstruction(e.target.value)}
              className="w-full text-xs font-semibold bg-transparent placeholder:text-text-muted/60 focus:outline-none"
            />
          </div>
        </div>
      </div>
    </div>
  )
}
