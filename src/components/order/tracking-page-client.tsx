'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { OrderTracker } from '@/components/order/order-tracker'
import { Loader2 } from 'lucide-react'
import { supabase } from '@/lib/supabase-client'

interface TrackingPageClientProps {
  orderId: string
  initialOrder?: any
}

export function TrackingPageClient({ orderId, initialOrder }: TrackingPageClientProps) {
  const [order, setOrder] = useState<any>(initialOrder || null)
  const [companionOrder, setCompanionOrder] = useState<any>(null)
  const [loading, setLoading] = useState(!initialOrder)
  const [error, setError] = useState<string | null>(null)
  const [isCafeOpen, setIsCafeOpen] = useState(true)

  const fetchOrder = useCallback(async (isBackground = false) => {
    try {
      if (!isBackground && !order) setLoading(true)

      const [res, settingsRes] = await Promise.all([
        fetch(`/api/orders/${orderId}?t=${Date.now()}`),
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
        if (!order) {
          throw new Error(`Failed to fetch order (${res.status})`)
        }
        return
      }

      const data = await res.json()

      // Map API response to tracker format
      const mapped = {
        id: data.id,
        status: data.status,
        subtotal: Number(data.subtotal || 0),
        discount: Number(data.discount || 0),
        deliveryFee: Number(data.deliveryFee || 0),
        taxes: Number(data.taxes || 0),
        miscFee: Number(data.miscFee ?? 0),
        total: Number(data.total || 0),
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
          price: Number(i.price || 0),
          quantity: i.quantity,
          selectedVariant: i.selectedVariant || null,
          imageUrl: i.imageUrl || i.product?.imageUrl || null,
          notes: i.notes || null,
          shopName: i.shopName || null
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
        readableId: data.readableId || data.baseReadableId || data.id?.slice(0, 8),
        baseReadableId: data.baseReadableId,
        isCombined: !!data.isCombined,
        groceryStatus: data.groceryStatus,
        groceryItems: data.groceryItems || [],
        restaurantStatus: data.restaurantStatus,
        restaurantName: data.restaurantName,
        restaurantItems: data.restaurantItems || [],
        subOrders: data.subOrders || [],
        deliveryUser: data.deliveryUser || null,
      }

      setOrder(mapped)
      setError(null)
    } catch (err: any) {
      console.error('Error fetching order for tracking:', err)
      if (!order) {
        setError(err.message || 'Failed to load order')
      }
    } finally {
      setLoading(false)
    }
  }, [orderId, order])

  useEffect(() => {
    fetchOrder(false)

    // Poll every 5s for active orders (payment updates, delivery status progression)
    const interval = setInterval(() => {
      fetchOrder(true)
    }, 5000)

    // Supabase realtime channel for instant push on payment or status changes
    const channel = supabase
      .channel(`order-track-${orderId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders', filter: `id=eq.${orderId}` },
        () => fetchOrder(true)
      )
      .on('broadcast', { event: 'order-payment-updated' }, (payload) => {
        if (payload?.payload?.orderId === orderId || payload?.payload?.readableId === orderId) {
          fetchOrder(true)
        }
      })
      .subscribe()

    return () => {
      clearInterval(interval)
      supabase.removeChannel(channel)
    }
  }, [orderId, fetchOrder])

  if (loading && !order) {
    return (
      <div className="container mx-auto px-2.5 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl">
        <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
          <p className="text-sm font-semibold text-text-secondary animate-pulse">Loading your order...</p>
        </div>
      </div>
    )
  }

  if (error && !order) {
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

  return (
    <div className="container mx-auto px-2.5 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl space-y-6">
      <div className="flex flex-col gap-4">
        <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Track Your Delivery</h1>
      </div>

      {order && <OrderTracker initialOrder={order} companionOrder={companionOrder} isCafeOpen={isCafeOpen} />}
    </div>
  )
}
