'use client'

import { useCartStore, CartProduct } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { toast } from 'sonner'
import { isCafeProduct } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { playCartPop } from '@/lib/audio'
import { FREE_DELIVERY_THRESHOLD } from '@/lib/constants'

export function useCart() {
  const store = useCartStore()

  const checkFreeDeliveryUnlock = (action: () => void) => {
    const prevItems = [...store.items]
    const getCategorySubtotal = (itemsList: typeof store.items, checkCafe: boolean) => 
      itemsList.filter((item) => isCafeProduct(item.product) === checkCafe)
               .reduce((sum, item) => sum + item.product.price * item.quantity, 0)

    const prevGrocerySub = getCategorySubtotal(prevItems, false)
    const prevCafeSub = getCategorySubtotal(prevItems, true)

    action()

    const newItems = useCartStore.getState().items
    const newGrocerySub = getCategorySubtotal(newItems, false)
    const newCafeSub = getCategorySubtotal(newItems, true)

    if (prevGrocerySub < FREE_DELIVERY_THRESHOLD && newGrocerySub >= FREE_DELIVERY_THRESHOLD) {
      setTimeout(() => {
        triggerHaptic('success')
        toast.success('🎉 FREE Grocery delivery unlocked!', {
          id: 'free-delivery-unlocked-grocery',
          duration: 2000,
        })
      }, 300)
    }

    if (prevCafeSub < 200 && newCafeSub >= 200) {
      setTimeout(() => {
        triggerHaptic('success')
        toast.success('🎉 FREE Cafe delivery unlocked!', {
          id: 'free-delivery-unlocked-cafe',
          duration: 2000,
        })
      }, 300)
    }
  }

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

    const limit = isCafeProduct(product) ? 10 : 5
    const currentQty = store.getItemQuantity(product.id)
    if (currentQty >= limit) {
      triggerHaptic('warning')
      toast.error(`Maximum limit of ${limit} units reached for ${product.name}`, {
        id: `cart-max-limit-${product.id}`,
      })
      return
    }

    checkFreeDeliveryUnlock(() => {
      store.addItem(product)
    })
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
        const limit = isCafeProduct(item.product) ? 10 : 5
        if (quantity > limit) {
          triggerHaptic('warning')
          toast.error(`Maximum limit of ${limit} units reached for ${name}`, {
            id: `cart-max-limit-${productId}`,
          })
          return
        }
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

    checkFreeDeliveryUnlock(() => {
      store.updateQuantity(productId, quantity)
    })
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
    checkFreeDeliveryUnlock(() => {
      store.removeItem(productId)
    })
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
    updateCartProduct: store.updateCartProduct,
  }
}
