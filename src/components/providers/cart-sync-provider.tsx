'use client'

import { useEffect, useRef } from 'react'
import { useCartStore } from '@/stores/cart-store'
import { useSession } from 'next-auth/react'

export function CartSyncProvider({ children }: { children: React.ReactNode }) {
  const items = useCartStore((s) => s.items)
  const { data: session, status } = useSession()
  const isInitialMount = useRef(true)

  useEffect(() => {
    if (status !== 'authenticated' || !session?.user?.id) return

    // If it's the first mount, wait a little bit to sync, otherwise debounce 2 seconds to avoid spamming the DB
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
  }, [items, session, status])

  return <>{children}</>
}
