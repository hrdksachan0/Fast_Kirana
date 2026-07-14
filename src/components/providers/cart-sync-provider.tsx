'use client'

import { useEffect, useRef, useState } from 'react'
import { useCartStore, CartItem } from '@/stores/cart-store'
import { useSession } from 'next-auth/react'

export function CartSyncProvider({ children }: { children: React.ReactNode }) {
  const items = useCartStore((s) => s.items)
  const { data: session, status } = useSession()
  const isInitialMount = useRef(true)
  const [hasInitialSyncCompleted, setHasInitialSyncCompleted] = useState(false)
  const isFetchingServerCart = useRef(false)

  // Reset initial sync completed and clear cart if the user logs out
  useEffect(() => {
    if (status !== 'authenticated') {
      setHasInitialSyncCompleted(false)
      useCartStore.getState().clearCart()
    }
  }, [status])

  // 1. Fetch server cart on login and merge with local cart
  useEffect(() => {
    if (status !== 'authenticated' || !session?.user?.id || hasInitialSyncCompleted || isFetchingServerCart.current) {
      return
    }

    isFetchingServerCart.current = true

    const loadServerCart = async () => {
      try {
        const response = await fetch('/api/cart')
        if (response.ok) {
          const data = await response.json()
          if (data.success && Array.isArray(data.items)) {
            const serverItems: CartItem[] = data.items
            const localItems = useCartStore.getState().items

            const mergedMap = new Map<string, CartItem>()

            // First add server items
            for (const item of serverItems) {
              mergedMap.set(item.product.id, item)
            }

            // Then merge local items
            for (const item of localItems) {
              const existing = mergedMap.get(item.product.id)
              if (existing) {
                // Keep the maximum quantity, capped at stock
                const maxStock = item.product.stock || 99
                // Using limits defined in the web cart-store (10 for cafe, 5 for grocery)
                const limit = item.product.id.includes('_') ? 10 : 5
                const newQty = Math.min(Math.max(existing.quantity, item.quantity), maxStock, limit)
                
                mergedMap.set(item.product.id, {
                  ...existing,
                  quantity: newQty,
                  notes: item.notes || existing.notes
                })
              } else {
                mergedMap.set(item.product.id, item)
              }
            }

            const finalItems = Array.from(mergedMap.values())
            
            // Overwrite local Zustand store with the merged results
            useCartStore.setState({ items: finalItems })
            
            console.log('Successfully synced/merged cart from DB:', finalItems.length, 'items')
          }
        }
      } catch (err) {
        console.error('Failed to load server cart on mount:', err)
      } finally {
        setHasInitialSyncCompleted(true)
        isFetchingServerCart.current = false
      }
    }

    loadServerCart()
  }, [status, session, hasInitialSyncCompleted])

  // 2. Sync local cart changes back to DB (debounced)
  useEffect(() => {
    // DO NOT sync back to DB until the initial sync from DB has completed!
    // Otherwise, we might overwrite the DB cart with an empty/stale local cart.
    if (status !== 'authenticated' || !session?.user?.id || !hasInitialSyncCompleted) return

    const delay = isInitialMount.current ? 800 : 2000
    isInitialMount.current = false

    const timer = setTimeout(async () => {
      try {
        const mappedItems = items.map((item) => {
          const isVariant = item.product.id.includes('_')
          const [productId, variantName] = isVariant 
            ? item.product.id.split('_') 
            : [item.product.id, null]

          return {
            productId,
            quantity: item.quantity,
            selectedVariant: variantName,
            notes: item.notes || null
          }
        })

        await fetch('/api/cart', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ items: mappedItems }),
        })
      } catch (err) {
        console.error('Failed to sync cart to DB:', err)
      }
    }, delay)

    return () => clearTimeout(timer)
  }, [items, session, status, hasInitialSyncCompleted])

  return <>{children}</>
}
