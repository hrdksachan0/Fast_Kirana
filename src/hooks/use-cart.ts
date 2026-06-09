'use client'

import { useCartStore, CartProduct } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { toast } from 'sonner'
import { isCafeProduct } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { playCartPop } from '@/lib/audio'

export function useCart() {
  const store = useCartStore()

  const addItem = (product: CartProduct) => {
    const { groceryMartOpen, cafeOpen } = useUIStore.getState()
    const isCafe = isCafeProduct(product)
    
    if (isCafe && !cafeOpen) {
      triggerHaptic('warning')
      toast.error(`FastKirana Cafe is temporarily closed. Cannot add ${product.name}.`)
      return
    }
    if (!isCafe && !groceryMartOpen) {
      triggerHaptic('warning')
      toast.error(`Grocery Mart is temporarily closed. Cannot add ${product.name}.`)
      return
    }
    if (product.stock <= 0) {
      triggerHaptic('warning')
      toast.error(`Sorry, ${product.name} is out of stock!`)
      return
    }

    store.addItem(product)
    playCartPop()
    triggerHaptic('light')
    toast.success(`${product.name} added to cart`, {
      id: `cart-add-${product.id}`,
    })
  }

  const updateQuantity = (productId: string, name: string, quantity: number) => {
    const currentQty = store.getItemQuantity(productId)

    if (quantity > currentQty) {
      const { groceryMartOpen, cafeOpen } = useUIStore.getState()
      const item = store.items.find((i) => i.product.id === productId)
      if (item) {
        if (quantity > item.product.stock) {
          triggerHaptic('warning')
          toast.error(`Cannot add more. Only ${item.product.stock} units available in stock.`)
          return
        }
        const isCafe = isCafeProduct(item.product)
        if (isCafe && !cafeOpen) {
          triggerHaptic('warning')
          toast.error(`FastKirana Cafe is temporarily closed. Cannot increase quantity.`)
          return
        }
        if (!isCafe && !groceryMartOpen) {
          triggerHaptic('warning')
          toast.error(`Grocery Mart is temporarily closed. Cannot increase quantity.`)
          return
        }
      }
    }

    store.updateQuantity(productId, quantity)
    if (quantity > currentQty) {
      playCartPop()
    }
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
