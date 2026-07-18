'use client'

import { useCallback } from 'react'
import { useCartStore, CartProduct } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { toast } from 'sonner'
import { isCafeProduct, getProductLimit, getProductType, isProductStoreClosed } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { playCartPop } from '@/lib/audio'
import { FREE_DELIVERY_THRESHOLD } from '@/lib/constants'

export function useCart() {
  const items = useCartStore((s) => s.items)

  const checkFreeDeliveryUnlock = useCallback((action: () => void) => {
    const storeState = useCartStore.getState()
    const prevItems = [...storeState.items]
    const getCategorySubtotal = (itemsList: typeof storeState.items, checkCafe: boolean) => 
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
  }, [])

  const addItem = useCallback((product: CartProduct) => {
    const { groceryMartOpen, cafeOpen, restaurantOpen, categoryStatus } = useUIStore.getState()
    const categorySlug = product.category?.slug || ''
    const isCategoryOpen = (categoryStatus as any)?.[categorySlug] !== false
    
    if (!isCategoryOpen) {
      triggerHaptic('warning')
      toast.error(`Category is closed. Cannot add ${product.name}.`)
      return
    }

    const isClosed = isProductStoreClosed(product, { groceryMartOpen, cafeOpen, restaurantOpen })
    if (isClosed) {
      triggerHaptic('warning')
      const type = getProductType(product)
      const storeName = type === 'RESTAURANT' ? 'Restaurant Kitchen' : type === 'CAFE' ? 'Cafe' : 'Grocery Mart'
      toast.error(`${storeName} is closed. Cannot add ${product.name}.`)
      return
    }
    if (product.stock <= 0) {
      triggerHaptic('warning')
      toast.error(`Sorry, ${product.name} is out of stock!`)
      return
    }

    const storeState = useCartStore.getState()

    const areTypesCompatible = (t1: string, t2: string): boolean => {
      if (t1 === t2) return true
      if (t1 === 'BYPASS' && (t2 === 'CAFE' || t2 === 'GROCERY')) return true
      if (t2 === 'BYPASS' && (t1 === 'CAFE' || t1 === 'GROCERY')) return true
      return false
    }

    const newType = getProductType(product)
    const incompatibleItem = storeState.items.find((item) => {
      const existType = getProductType(item.product)
      return !areTypesCompatible(newType, existType)
    })

    if (incompatibleItem) {
      useUIStore.setState({ pendingConflictProduct: product })
      return
    }

    const limit = getProductLimit(product)
    const currentQty = storeState.getItemQuantity(product.id)
    if (currentQty >= limit) {
      triggerHaptic('warning')
      toast.error(`Maximum limit of ${limit} units reached for ${product.name}`, {
        id: `cart-max-limit-${product.id}`,
      })
      return
    }

    checkFreeDeliveryUnlock(() => {
      useCartStore.getState().addItem(product)
    })
    playCartPop()
    triggerHaptic('light')
    toast.success(`${product.name} added to cart`, {
      id: `cart-add-${product.id}`,
    })
  }, [checkFreeDeliveryUnlock])

  const updateQuantity = useCallback((productId: string, name: string, quantity: number) => {
    const storeState = useCartStore.getState()
    const currentQty = storeState.getItemQuantity(productId)

    if (quantity > currentQty) {
      const { groceryMartOpen, cafeOpen, restaurantOpen, categoryStatus } = useUIStore.getState()
      const item = storeState.items.find((i) => i.product.id === productId)
      if (item) {
        const limit = getProductLimit(item.product)
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
        const categorySlug = item.product.category?.slug || ''
        const isCategoryOpen = (categoryStatus as any)?.[categorySlug] !== false

        if (!isCategoryOpen) {
          triggerHaptic('warning')
          toast.error(`Category is closed. Cannot increase quantity.`)
          return
        }

        const isClosed = isProductStoreClosed(item.product, { groceryMartOpen, cafeOpen, restaurantOpen })
        if (isClosed) {
          triggerHaptic('warning')
          const type = getProductType(item.product)
          const storeName = type === 'RESTAURANT' ? 'Restaurant Kitchen' : type === 'CAFE' ? 'Cafe' : 'Grocery Mart'
          toast.error(`${storeName} is closed. Cannot increase quantity.`)
          return
        }
      }
    }

    checkFreeDeliveryUnlock(() => {
      useCartStore.getState().updateQuantity(productId, quantity)
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
  }, [checkFreeDeliveryUnlock])

  const removeItem = useCallback((productId: string, name: string) => {
    checkFreeDeliveryUnlock(() => {
      useCartStore.getState().removeItem(productId)
    })
    triggerHaptic('medium')
    toast.success(`${name} removed from cart`, {
      id: `cart-remove-${productId}`,
    })
  }, [checkFreeDeliveryUnlock])

  const storeState = useCartStore.getState()

  return {
    items,
    addItem,
    removeItem,
    updateQuantity,
    clearCart: useCartStore((s) => s.clearCart),
    getItemQuantity: useCartStore((s) => s.getItemQuantity),
    getTotalItems: useCartStore((s) => s.getTotalItems),
    getSubtotal: useCartStore((s) => s.getSubtotal),
    getMrpTotal: useCartStore((s) => s.getMrpTotal),
    getSavings: useCartStore((s) => s.getSavings),
    updateCartProduct: useCartStore((s) => s.updateCartProduct),
    updateItemNotes: useCartStore((s) => s.updateItemNotes),
  }
}
