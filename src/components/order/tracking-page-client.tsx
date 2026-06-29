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

  useEffect(() => {
    let isMounted = true

    async function fetchOrder() {
      try {
        const res = await fetch(`/api/orders/${orderId}`)
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
            name: i.name,
            price: i.price,
            quantity: i.quantity,
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
              setCompanionOrder(companion)
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
        
        {companionOrder && (
          <div className="bg-gradient-to-r from-rose-500 via-pink-500 to-orange-500 p-4 rounded-2xl text-white shadow-md flex flex-col md:flex-row justify-between items-start md:items-center gap-4 animate-slide-up">
            <div className="space-y-1">
              <span className="inline-flex items-center gap-1 rounded-full bg-white/20 px-2.5 py-0.5 text-[9px] font-black uppercase tracking-wider">
                {isCompanionCafe ? '☕ Cafe Order Split' : '📦 Grocery Order Split'}
              </span>
              <h3 className="text-sm font-black">Your Order Has Been Split!</h3>
              <p className="text-[10px] text-white/90 leading-relaxed font-semibold">
                {isCafeOrder
                  ? 'To ensure your beverages and hot bites are delivered piping hot, we created a separate order for your other grocery items. Track the Grocery order here.'
                  : 'To ensure your beverages and hot bites are delivered piping hot, we created a separate Cafe order for them. Track the Cafe order here.'}
              </p>
            </div>
            <Link
              href={`/order/${companionOrder.id}/track`}
              className="px-4 py-2 bg-white hover:bg-white/90 text-rose-600 font-extrabold rounded-xl text-xs transition-all shrink-0 shadow-sm active:scale-98"
            >
              {isCompanionCafe ? 'Track Cafe Order →' : 'Track Grocery Order →'}
            </Link>
          </div>
        )}
      </div>

      <OrderTracker initialOrder={order} />
    </div>
  )
}
