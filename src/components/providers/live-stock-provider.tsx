'use client'

import { createContext, useContext, useEffect, useRef, useState, useCallback } from 'react'
import { useCartStore, CartProduct } from '@/stores/cart-store'

interface LiveProductState {
  price: number
  mrp: number
  stock: number
  isAvailable: boolean
}

interface LiveStockContextType {
  liveStock: Record<string, LiveProductState>
  registerProduct: (id: string) => void
  unregisterProduct: (id: string) => void
}

const LiveStockContext = createContext<LiveStockContextType | null>(null)

export function LiveStockProvider({ children }: { children: React.ReactNode }) {
  const [liveStock, setLiveStock] = useState<Record<string, LiveProductState>>({})
  const registryRef = useRef<Record<string, number>>({})
  const lastFetchedRef = useRef<Record<string, number>>({})
  const fetchTimeoutRef = useRef<NodeJS.Timeout | null>(null)

  const triggerBatchFetch = useCallback((force = false) => {
    if (fetchTimeoutRef.current) clearTimeout(fetchTimeoutRef.current)

    fetchTimeoutRef.current = setTimeout(async () => {
      const now = Date.now()
      const CACHE_TTL = 240000 // 240 seconds (4 minutes) client cache TTL — optimized for lower serverless traffic

      const onScreenIds = Object.entries(registryRef.current)
        .filter(([_, count]) => count > 0)
        .map(([id]) => id)

      // Get all product IDs currently in the cart
      const cartProductIds = useCartStore.getState().items.map((item) => item.product.id)

      // Combine registry IDs and cart IDs, and remove duplicates
      const activeIds = Array.from(new Set([...onScreenIds, ...cartProductIds]))

      if (activeIds.length === 0) return

      // Filter IDs that were not fetched within the last CACHE_TTL ms (unless forced)
      const idsToFetch = force
        ? activeIds
        : activeIds.filter((id) => {
            const lastTime = lastFetchedRef.current[id] || 0
            return now - lastTime > CACHE_TTL
          })

      if (idsToFetch.length === 0) return

      // Update timestamp cache for IDs being requested
      idsToFetch.forEach((id) => {
        lastFetchedRef.current[id] = now
      })

      try {
        const res = await fetch('/api/products/live-stock', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ids: idsToFetch }),
        })
        if (res.ok) {
          const data = await res.json()
          setLiveStock((prev) => ({ ...prev, ...data }))

          // Sync the updated live values back to the Cart Store
          const cartState = useCartStore.getState()
          Object.entries(data).forEach(([id, updates]: [string, any]) => {
            const cartItem = cartState.items.find((item) => item.product.id === id)
            if (cartItem) {
              const p = cartItem.product
              if (
                p.price !== updates.price ||
                p.mrp !== updates.mrp ||
                p.stock !== updates.stock ||
                p.isAvailable !== updates.isAvailable
              ) {
                cartState.updateCartProduct(id, updates)
              }
            }
          })
        }
      } catch (err) {
        console.error('Failed to fetch live stock:', err)
      }
    }, 400) // 400ms batch window to aggregate product mounts
  }, [])

  const registerProduct = useCallback((id: string) => {
    const currentCount = registryRef.current[id] || 0
    registryRef.current[id] = currentCount + 1
    if (currentCount === 0) {
      triggerBatchFetch()
    }
  }, [triggerBatchFetch])

  const unregisterProduct = useCallback((id: string) => {
    const currentCount = registryRef.current[id] || 0
    if (currentCount <= 1) {
      delete registryRef.current[id]
    } else {
      registryRef.current[id] = currentCount - 1
    }
  }, [])

  // Background polling effect (every 4 minutes / 240s for active items)
  useEffect(() => {
    let lastFocusFetchTime = Date.now()

    const interval = setInterval(() => {
      if (document.visibilityState === 'visible') {
        triggerBatchFetch(false)
      }
    }, 240000) // 4-minute interval matches client cache TTL

    // Only revalidate on focus if at least 3 minutes have elapsed since last check
    const handleFocus = () => {
      const now = Date.now()
      if (now - lastFocusFetchTime > 180000) {
        lastFocusFetchTime = now
        triggerBatchFetch(false)
      }
    }
    window.addEventListener('focus', handleFocus)

    return () => {
      clearInterval(interval)
      window.removeEventListener('focus', handleFocus)
      if (fetchTimeoutRef.current) clearTimeout(fetchTimeoutRef.current)
    }
  }, [triggerBatchFetch])

  return (
    <LiveStockContext.Provider value={{ liveStock, registerProduct, unregisterProduct }}>
      {children}
    </LiveStockContext.Provider>
  )
}

export function useLiveStock(productId: string) {
  const context = useContext(LiveStockContext)
  if (!context) {
    throw new Error('useLiveStock must be used within a LiveStockProvider')
  }

  const { liveStock, registerProduct, unregisterProduct } = context

  useEffect(() => {
    registerProduct(productId)
    return () => {
      unregisterProduct(productId)
    }
  }, [productId, registerProduct, unregisterProduct])

  return liveStock[productId] || null
}
