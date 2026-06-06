'use client'

import { useCartStore, CartProduct } from '@/stores/cart-store'
import { toast } from 'sonner'
import { isCafeProduct } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'

export function useCart() {
  const store = useCartStore()

  const addItem = async (product: CartProduct) => {
    try {
      const res = await fetch('/api/settings')
      if (res.ok) {
        const data = await res.json()
        const isCafe = isCafeProduct(product)
        if (isCafe && data.cafe_open === 'false') {
          triggerHaptic('warning')
          toast.error(`FastKirana Cafe is temporarily closed. Cannot add ${product.name}.`)
          return
        }
        if (!isCafe && data.grocery_mart_open === 'false') {
          triggerHaptic('warning')
          toast.error(`Grocery Mart is temporarily closed. Cannot add ${product.name}.`)
          return
        }
      }
    } catch (err) {
      console.error(err)
    }

    store.addItem(product)
    triggerHaptic('light')
    toast.success(`${product.name} added to cart`, {
      id: `cart-add-${product.id}`,
    })
  }

  const updateQuantity = async (productId: string, name: string, quantity: number) => {
    const currentQty = store.getItemQuantity(productId)

    if (quantity > currentQty) {
      try {
        const res = await fetch('/api/settings')
        if (res.ok) {
          const data = await res.json()
          const item = store.items.find((i) => i.product.id === productId)
          if (item) {
            const isCafe = isCafeProduct(item.product)
            if (isCafe && data.cafe_open === 'false') {
              triggerHaptic('warning')
              toast.error(`FastKirana Cafe is temporarily closed. Cannot increase quantity.`)
              return
            }
            if (!isCafe && data.grocery_mart_open === 'false') {
              triggerHaptic('warning')
              toast.error(`Grocery Mart is temporarily closed. Cannot increase quantity.`)
              return
            }
          }
        }
      } catch (err) {
        console.error(err)
      }
    }

    store.updateQuantity(productId, quantity)
    triggerHaptic('light')

    if (quantity > currentQty) {
      toast.success(`Increased ${name} quantity`, {
        id: `cart-qty-${productId}`,
      })
    } else if (quantity < currentQty && quantity > 0) {
      toast.success(`Decreased ${name} quantity`, {
        id: `cart-qty-${productId}`,
      })
    } else if (quantity === 0) {
      toast.success(`${name} removed from cart`, {
        id: `cart-qty-${productId}`,
      })
    }
  }

  const removeItem = (productId: string, name: string) => {
    store.removeItem(productId)
    triggerHaptic('medium')
    toast.success(`${name} removed from cart`, {
      id: `cart-remove-${productId}`,
    })
  }

  return {
    items: store.items,
    addItem,
    removeItem,
    updateQuantity,
    clearCart: store.clearCart,
    getItemQuantity: store.getItemQuantity,
    getTotalItems: store.getTotalItems,
    getSubtotal: store.getSubtotal,
    getMrpTotal: store.getMrpTotal,
    getSavings: store.getSavings,
  }
}
