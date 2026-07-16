'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { OrderTracker } from '@/components/order/order-tracker'
import { Loader2 } from 'lucide-react'

interface TrackingPageClientProps {
  orderId: string
}

export function TrackingPageClient({ orderId }: TrackingPageClientProps) {
  const [order, setOrder] = useState<any>(null)
  const [companionOrder, setCompanionOrder] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isCafeOpen, setIsCafeOpen] = useState(true)


  useEffect(() => {
    let isMounted = true

    async function fetchOrder() {
      try {
        const [res, settingsRes] = await Promise.all([
          fetch(`/api/orders/${orderId}`),
          fetch('/api/settings', { cache: 'no-store' }).catch(() => null)
        ])

        if (settingsRes && settingsRes.ok) {
          const settingsData = await settingsRes.json()
          if (settingsData && settingsData.cafe_open !== undefined) {
            setIsCafeOpen(settingsData.cafe_open === 'true')
          }
        }

        if (!res.ok) {
          if (res.status === 401) {
            window.location.href = '/login'
            return
          }
          throw new Error(`Failed to fetch order (${res.status})`)
        }

        const data = await res.json()

        if (!isMounted) return

        // Map API response to tracker format
        const mapped = {
          id: data.id,
          status: data.status,
          subtotal: data.subtotal,
          discount: data.discount,
          deliveryFee: data.deliveryFee,
          taxes: data.taxes,
          total: data.total,
          paymentMethod: data.paymentMethod,
          paymentStatus: data.paymentStatus,
          estimatedDelivery: data.estimatedDelivery ? new Date(data.estimatedDelivery).toISOString() : null,
          deliveryPhoto: data.deliveryPhoto || null,
          deliveryLat: data.deliveryLat || null,
          deliveryLng: data.deliveryLng || null,
          deliveryMethod: data.deliveryMethod,
          isB2B: data.isB2B,
          shopName: data.shopName,
          shopPhone: data.shopPhone,
          createdAt: data.createdAt ? new Date(data.createdAt).toISOString() : new Date().toISOString(),
          items: (data.items || []).map((i: any) => ({
            id: i.id,
            productId: i.productId,
            name: i.name,
            price: i.price,
            quantity: i.quantity,
            selectedVariant: i.selectedVariant || null
          })),
          address: {
            label: data.address?.label || 'Pickup Location',
            houseNo: data.address?.houseNo || '',
            street: data.address?.street || '',
            area: data.address?.area || 'Hub Store',
            city: data.address?.city || 'Kanpur',
            pincode: data.address?.pincode || '209206',
            lat: data.address?.lat || 26.1534185,
            lng: data.address?.lng || 80.1714024,
          },
          deliveryUser: data.deliveryUser || null,
        }

        setOrder(mapped)
        setError(null)

        // Fetch companion orders (placed within 5s of this order)
        try {
          const ordersRes = await fetch('/api/orders')
          if (ordersRes.ok) {
            const allOrders = await ordersRes.json()
            const orderCreatedAt = new Date(data.createdAt).getTime()
            const companion = allOrders.find((o: any) =>
              o.id !== data.id &&
              Math.abs(new Date(o.createdAt).getTime() - orderCreatedAt) <= 5000
            )
            if (companion && isMounted) {
              const compRes = await fetch(`/api/orders/${companion.id}`)
              if (compRes.ok) {
                const compData = await compRes.json()
                const mappedComp = {
                  id: compData.id,
                  status: compData.status,
                  subtotal: compData.subtotal,
                  discount: compData.discount,
                  deliveryFee: compData.deliveryFee,
                  taxes: compData.taxes,
                  total: compData.total,
                  paymentMethod: compData.paymentMethod,
                  paymentStatus: compData.paymentStatus,
                  estimatedDelivery: compData.estimatedDelivery ? new Date(compData.estimatedDelivery).toISOString() : null,
                  deliveryPhoto: compData.deliveryPhoto || null,
                  deliveryLat: compData.deliveryLat || null,
                  deliveryLng: compData.deliveryLng || null,
                  deliveryMethod: compData.deliveryMethod,
                  isB2B: compData.isB2B,
                  shopName: compData.shopName,
                  shopPhone: compData.shopPhone,
                  createdAt: compData.createdAt ? new Date(compData.createdAt).toISOString() : new Date().toISOString(),
                  items: (compData.items || []).map((i: any) => ({
                    id: i.id,
                    productId: i.productId,
                    name: i.name,
                    price: i.price,
                    quantity: i.quantity,
                    selectedVariant: i.selectedVariant || null
                  })),
                  address: {
                    label: compData.address?.label || 'Pickup Location',
                    houseNo: compData.address?.houseNo || '',
                    street: compData.address?.street || '',
                    area: compData.address?.area || 'Hub Store',
                    city: compData.address?.city || 'Kanpur',
                    pincode: compData.address?.pincode || '209206',
                    lat: compData.address?.lat || 26.1534185,
                    lng: compData.address?.lng || 80.1714024,
                  },
                  deliveryUser: compData.deliveryUser || null
                }
                setCompanionOrder(mappedComp)
              }
            }
          }
        } catch {
          // Companion order is non-critical, ignore errors
        }
      } catch (err: any) {
        console.error('Error fetching order for tracking:', err)
        if (isMounted) {
          setError(err.message || 'Failed to load order')
        }
      } finally {
        if (isMounted) {
          setLoading(false)
        }
      }
    }

    fetchOrder()

    return () => {
      isMounted = false
    }
  }, [orderId])

  if (loading) {
    return (
      <div className="container mx-auto px-2.5 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl">
        <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
          <p className="text-sm font-semibold text-text-secondary animate-pulse">Loading your order...</p>
        </div>
      </div>
    )
  }

  if (error || !order) {
    return (
      <div className="container mx-auto px-2.5 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl">
        <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4 text-center">
          <div className="h-16 w-16 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
            <span className="text-2xl">⚠️</span>
          </div>
          <h2 className="text-lg font-black text-text-primary">Unable to Load Order</h2>
          <p className="text-sm text-text-secondary max-w-xs">{error || 'Order not found. Please try again.'}</p>
          <button
            onClick={() => { setLoading(true); setError(null); window.location.reload() }}
            className="px-6 py-2.5 bg-primary text-white font-bold rounded-xl text-sm hover:bg-primary/90 transition-colors"
          >
            Try Again
          </button>
          <Link href="/" className="text-xs font-semibold text-primary hover:underline">
            ← Go to Home
          </Link>
        </div>
      </div>
    )
  }

  const isCafeOrder = order.shopName === 'FastKirana Cafe Kitchen'
  const isCompanionCafe = companionOrder?.shopName === 'FastKirana Cafe Kitchen'

  return (
    <div className="container mx-auto px-2.5 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl space-y-6">
      <div className="flex flex-col gap-4">
        <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Track Your Delivery</h1>
      </div>

      <OrderTracker initialOrder={order} companionOrder={companionOrder} isCafeOpen={isCafeOpen} />
    </div>
  )
}
