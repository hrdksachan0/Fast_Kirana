'use client'

import { useEffect, useRef, useState } from 'react'
import { useCartStore, CartItem } from '@/stores/cart-store'
import { useSession } from 'next-auth/react'
import { getProductLimit } from '@/lib/utils'

export function CartSyncProvider({ children }: { children: React.ReactNode }) {
  const items = useCartStore((s) => s.items)
  const { data: session, status } = useSession()
  const isInitialMount = useRef(true)
  const [hasInitialSyncCompleted, setHasInitialSyncCompleted] = useState(false)
  const isFetchingServerCart = useRef(false)
  const [guestId, setGuestId] = useState<string>('')

  // Initialize guest ID token for unauthenticated cart sync tracking
  useEffect(() => {
    if (typeof window !== 'undefined') {
      let gid = localStorage.getItem('fastkirana-guest-id')
      if (!gid) {
        gid = 'g_' + Math.random().toString(36).substring(2, 11) + Date.now().toString(36)
        localStorage.setItem('fastkirana-guest-id', gid)
      }
      setGuestId(gid)
    }
  }, [])

  // 1. Fetch server cart on login and merge with local cart
  useEffect(() => {
    if (status !== 'authenticated' || !session?.user?.id || hasInitialSyncCompleted || isFetchingServerCart.current) {
      if (status !== 'authenticated') {
        setHasInitialSyncCompleted(true)
      }
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
                const maxStock = item.product.stock || 99
                const limit = getProductLimit(item.product)
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
            useCartStore.setState({ items: finalItems })
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

  // 2. Sync local cart changes back to DB (debounced for both authenticated & guest users)
  useEffect(() => {
    // Wait until initial sync check has completed
    if (status === 'authenticated' && !hasInitialSyncCompleted) return

    const delay = isInitialMount.current ? 800 : 1500
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

        const headers: Record<string, string> = {
          'Content-Type': 'application/json',
        }
        if (guestId && status !== 'authenticated') {
          headers['x-guest-id'] = guestId
        }

        await fetch('/api/cart', {
          method: 'POST',
          headers,
          body: JSON.stringify({ items: mappedItems }),
        })
      } catch (err) {
        console.error('Failed to sync cart to DB:', err)
      }
    }, delay)

    return () => clearTimeout(timer)
  }, [items, session, status, hasInitialSyncCompleted, guestId])

  return <>{children}</>
}
