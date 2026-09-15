'use client'

import Link from 'next/link'
import { toast } from 'sonner'
import type { CartItem } from '@/stores/cart-store'
import { isCafeProduct, isProductStoreClosed } from '@/lib/utils'

export function EmptyCartScreen() {
  return (
    <div className="container mx-auto px-4 py-16 text-center max-w-md space-y-6">
      <span className="text-6xl block">🛒</span>
      <h1 className="text-xl font-bold">Your cart is empty</h1>
      <Link href="/" className="inline-block bg-primary text-white px-6 py-3 rounded-xl font-bold">
        Explore Products
      </Link>
    </div>
  )
}

interface InventoryIssueScreenProps {
  items: CartItem[]
  removeItem: (id: string, name: string) => void
  updateQuantity: (id: string, name: string, quantity: number) => void
}

export function InventoryIssueScreen({
  items,
  removeItem,
  updateQuantity,
}: InventoryIssueScreenProps) {
  const handleRemoveOutOfStock = () => {
    let count = 0
    items.forEach((item) => {
      if (item.product.stock <= 0 || item.product.isAvailable === false) {
        removeItem(item.product.id, item.product.name)
        count++
      } else if (item.quantity > item.product.stock) {
        updateQuantity(item.product.id, item.product.name, item.product.stock)
        count++
      }
    })
    if (count > 0) {
      toast.success(`Adjusted out-of-stock items in your cart!`)
    }
  }

  const conflictingItems = items.filter(
    (item) =>
      item.product.stock <= 0 ||
      item.product.isAvailable === false ||
      item.quantity > item.product.stock
  )

  return (
    <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
      <div className="h-20 w-20 bg-rose-50 dark:bg-rose-950/20 text-rose-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner border border-rose-200/60 dark:border-rose-900/40">
        ⚠️
      </div>
      <h1 className="text-2xl font-black text-text-primary">Item(s) Out of Stock</h1>
      <p className="text-sm text-text-secondary leading-relaxed">
        Some items in your cart just went out of stock or have limited quantity. Please adjust them
        to proceed with your order.
      </p>
      <div className="space-y-2 max-h-48 overflow-y-auto p-2 bg-muted/20 rounded-xl border border-border/50">
        {conflictingItems.map((item) => (
          <div
            key={item.product.id}
            className="flex items-center justify-between text-xs py-1.5 px-2 font-bold text-left"
          >
            <span className="truncate flex-1">{item.product.name}</span>
            <span className="text-rose-500 font-black text-[10px] uppercase ml-2">
              {item.product.stock <= 0 || item.product.isAvailable === false
                ? 'Out of Stock'
                : `Only ${item.product.stock} available`}
            </span>
          </div>
        ))}
      </div>
      <div className="pt-2 flex flex-col gap-3">
        <button
          onClick={handleRemoveOutOfStock}
          className="w-full px-6 py-3 bg-rose-600 text-white font-black text-xs rounded-full hover:bg-rose-700 transition-all shadow-md active:scale-98 cursor-pointer"
        >
          Remove Out-of-Stock Items & Proceed
        </button>
        <Link
          href="/cart"
          className="w-full px-6 py-3 bg-muted text-text-primary font-black text-xs rounded-full hover:bg-muted/80 transition-all text-center"
        >
          Go Back to Cart
        </Link>
      </div>
    </div>
  )
}

interface StoreClosedScreenProps {
  closedItems: CartItem[]
  removeItem: (id: string, name: string) => void
}

export function StoreClosedScreen({ closedItems, removeItem }: StoreClosedScreenProps) {
  const handleRemoveClosedItems = () => {
    let count = 0
    closedItems.forEach((item) => {
      removeItem(item.product.id, item.product.name)
      count++
    })
    if (count > 0) {
      toast.success(`Removed closed outlet item(s) from your cart!`)
    }
  }

  const closedOutletNames = Array.from(
    new Set(
      closedItems
        .map(
          (i) =>
            (i.product as any).restaurant?.name ||
            (i.product as any).shopName ||
            (isCafeProduct(i.product) ? 'Cafe' : 'Grocery Mart')
        )
        .filter(Boolean)
    )
  )

  return (
    <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
      <div className="h-20 w-20 bg-amber-50 dark:bg-amber-950/20 text-amber-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner animate-pulse-gentle border border-amber-200/60 dark:border-amber-900/40">
        🏪
      </div>
      <h1 className="text-2xl font-black text-text-primary">Outlet Closed Temporarily</h1>
      <p className="text-sm text-text-secondary leading-relaxed">
        {closedOutletNames.length > 0 ? closedOutletNames.join(' & ') : 'This store'} is
        temporarily closed right now. You can proceed with your order by removing items from this
        closed outlet.
      </p>
      <div className="space-y-2 max-h-48 overflow-y-auto p-2 bg-muted/20 rounded-xl border border-border/50">
        {closedItems.map((item) => (
          <div
            key={item.product.id}
            className="flex items-center justify-between text-xs py-1.5 px-2 font-bold text-left"
          >
            <span className="truncate flex-1">{item.product.name}</span>
            <span className="text-amber-600 dark:text-amber-400 font-black text-[10px] uppercase ml-2 bg-amber-500/10 px-1.5 py-0.5 rounded">
              Closed Outlet
            </span>
          </div>
        ))}
      </div>
      <div className="pt-4 flex flex-col gap-3">
        <button
          onClick={handleRemoveClosedItems}
          className="w-full px-6 py-3 bg-primary text-white font-black text-xs rounded-full hover:bg-primary-dark transition-all shadow-md active:scale-98 cursor-pointer"
        >
          Remove Closed Items & Proceed
        </button>
        <Link
          href="/cart"
          className="px-6 py-3 bg-primary text-white font-black text-xs rounded-full hover:bg-primary/95 transition-all shadow-md active:scale-98 text-center"
        >
          Go Back to Cart
        </Link>
        <Link
          href="/"
          className="px-6 py-3 border-2 border-border text-text-secondary font-black text-xs rounded-full hover:bg-muted/30 transition-all active:scale-98 text-center"
        >
          Continue Browsing
        </Link>
      </div>
    </div>
  )
}
