'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'
import { supabase } from '@/lib/supabase-client'
import { toast } from 'sonner'
import { logger } from '@/lib/logger'
import { getAuthToken } from '@/lib/fastapi'

interface UseAdminRealtimeProps {
  selectedHubId: string
  initialOrders?: any[]
  activeTab?: string
  onNewOrder?: (order: any) => void
  onOrderUpdated?: (order: any) => void
}

let sharedAudioContext: AudioContext | null = null

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null
  const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext
  if (!AudioContextClass) return null
  if (!sharedAudioContext || sharedAudioContext.state === 'closed') {
    sharedAudioContext = new AudioContextClass()
  }
  if (sharedAudioContext.state === 'suspended') {
    sharedAudioContext.resume().catch(() => {})
  }
  return sharedAudioContext
}

export function useAdminRealtime({
  selectedHubId,
  initialOrders,
  activeTab,
  onNewOrder,
  onOrderUpdated,
}: UseAdminRealtimeProps) {
  const [liveOrders, setLiveOrders] = useState<any[]>(Array.isArray(initialOrders) ? initialOrders : [])
  const [orderRefreshKey, setOrderRefreshKey] = useState(0)
  const [isChimeMuted, setIsChimeMuted] = useState(false)

  // Live Active Carts States
  const [activeCarts, setActiveCarts] = useState<any[]>([])
  const [activeCartsCount, setActiveCartsCount] = useState<number>(0)
  const [isLoadingCarts, setIsLoadingCarts] = useState(false)
  const [cartsRefreshKey, setCartsRefreshKey] = useState(0)

  // Web Audio warning chime synthesizer
  const playWarningChime = useCallback(() => {
    try {
      const ctx = getAudioContext()
      if (!ctx) return
      const now = ctx.currentTime

      const osc1 = ctx.createOscillator()
      const gain1 = ctx.createGain()
      osc1.type = 'sine'
      osc1.frequency.setValueAtTime(550, now)
      gain1.gain.setValueAtTime(0, now)
      gain1.gain.linearRampToValueAtTime(0.08, now + 0.05)
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.35)

      osc1.connect(gain1)
      gain1.connect(ctx.destination)
      osc1.start(now)
      osc1.stop(now + 0.35)

      const osc2 = ctx.createOscillator()
      const gain2 = ctx.createGain()
      osc2.type = 'sine'
      osc2.frequency.setValueAtTime(660, now + 0.15)
      gain2.gain.setValueAtTime(0, now + 0.15)
      gain2.gain.linearRampToValueAtTime(0.08, now + 0.2)
      gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.5)

      osc2.connect(gain2)
      gain2.connect(ctx.destination)
      osc2.start(now + 0.15)
      osc2.stop(now + 0.5)
    } catch (err) {
      console.warn('AudioContext failed to play:', err)
    }
  }, [])

  // Web Audio new order chime synthesizer
  const playNewOrderChime = useCallback(() => {
    if (isChimeMuted) return
    try {
      const ctx = getAudioContext()
      if (!ctx) return
      const now = ctx.currentTime

      const osc1 = ctx.createOscillator()
      const gain1 = ctx.createGain()
      osc1.type = 'triangle'
      osc1.frequency.setValueAtTime(880, now)
      gain1.gain.setValueAtTime(0, now)
      gain1.gain.linearRampToValueAtTime(0.15, now + 0.05)
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.4)
      osc1.connect(gain1)
      gain1.connect(ctx.destination)
      osc1.start(now)
      osc1.stop(now + 0.4)

      const osc2 = ctx.createOscillator()
      const gain2 = ctx.createGain()
      osc2.type = 'triangle'
      osc2.frequency.setValueAtTime(659.25, now + 0.15)
      gain2.gain.setValueAtTime(0, now)
      gain2.gain.setValueAtTime(0.15, now + 0.15)
      gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.6)
      osc2.connect(gain2)
      gain2.connect(ctx.destination)
      osc2.start(now + 0.15)
      osc2.stop(now + 0.6)
    } catch (err) {
      console.warn('AudioContext failed to play new order chime:', err)
    }
  }, [isChimeMuted])

  const fetchLiveOrdersList = useCallback(async () => {
    try {
      const storeQuery =
        selectedHubId && selectedHubId !== 'all'
          ? `&storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(`/api/admin/orders?limit=100${storeQuery}`)
      if (res.ok) {
        const data = await res.json()
        const fetched = Array.isArray(data?.orders)
          ? data.orders
          : Array.isArray(data)
          ? data
          : []
        setLiveOrders(fetched)
      }
    } catch (err) {
      console.error('Failed to poll live orders:', err)
    }
  }, [selectedHubId])

  useEffect(() => {
    fetchLiveOrdersList()
  }, [fetchLiveOrdersList])

  // Tri-channel listener: Supabase, SSE, Railway WebSocket
  useEffect(() => {
    let updateTimeout: NodeJS.Timeout | null = null

    const debouncedRefresh = () => {
      if (updateTimeout) clearTimeout(updateTimeout)
      updateTimeout = setTimeout(() => {
        fetchLiveOrdersList()
        setOrderRefreshKey((prev) => prev + 1)
      }, 1000)
    }

    const channel = supabase
      .channel('admin-orders-live')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders' },
        (payload) => {
          const orderData = payload.new as any
          const orderStoreId = orderData?.storeId
          
          // Strict Hub Isolation: Ignore orders belonging to other store hubs
          if (selectedHubId && selectedHubId !== 'all' && orderStoreId && orderStoreId !== selectedHubId) {
            return
          }

          if (payload.eventType === 'INSERT') {
            toast.success(`🛎️ New Order Received: #${(orderData.readableId || orderData.id).slice(0, 8)}`)
            playNewOrderChime()
            onNewOrder?.(orderData)
            debouncedRefresh()
          } else if (payload.eventType === 'UPDATE') {
            onOrderUpdated?.(orderData)
            debouncedRefresh()
          }
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'carts' },
        () => setCartsRefreshKey((prev) => prev + 1)
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'cart_items' },
        () => setCartsRefreshKey((prev) => prev + 1)
      )
      .on('broadcast', { event: 'order-payment-updated' }, (payload) => {
        toast.success(`💳 Order #${payload.payload?.orderId?.slice(0, 8)} marked PAID!`)
        debouncedRefresh()
      })
      .subscribe()

    let isSubscribed = true
    let railwayWs: WebSocket | null = null
    let reconnectTimeout: NodeJS.Timeout | null = null

    const connectRailwayWs = () => {
      if (!isSubscribed) return
      try {
        const rawFastApiUrl = process.env.NEXT_PUBLIC_FASTAPI_URL || process.env.NEXT_PUBLIC_API_URL || 'https://fastkiran-backend-production.up.railway.app'
        const cleanUrl = rawFastApiUrl.replace(/\/+$/, '')
        const wsUrl = cleanUrl.replace(/^http:/, 'ws:').replace(/^https:/, 'wss:') + '/ws'
        railwayWs = new WebSocket(wsUrl)

        railwayWs.onmessage = (event) => {
          try {
            const payload = JSON.parse(event.data)
            const ev = payload.event || payload.type
            if (ev === 'NEW_ORDER' || ev === 'ORDER_CREATED' || ev === 'new-order') {
              toast.success(`🛎️ New Order Received!`)
              playNewOrderChime()
              debouncedRefresh()
            } else if (
              ev === 'CART_UPDATE' ||
              ev === 'CART_ITEM_ADDED' ||
              ev === 'cart-updated' ||
              ev === 'cart-update'
            ) {
              setCartsRefreshKey((prev) => prev + 1)
            } else if (
              ev === 'STATUS_UPDATE' ||
              ev === 'ORDER_UPDATED' ||
              ev === 'order-status-update'
            ) {
              debouncedRefresh()
            }
          } catch (e) {
            logger.warn('realtime', 'Failed to parse WebSocket payload', e)
          }
        }

        railwayWs.onclose = () => {
          if (isSubscribed) {
            reconnectTimeout = setTimeout(connectRailwayWs, 3000)
          }
        }

        railwayWs.onerror = () => {
          railwayWs?.close()
        }
      } catch (e) {
        if (isSubscribed) {
          reconnectTimeout = setTimeout(connectRailwayWs, 5000)
        }
      }
    }

    connectRailwayWs()

    return () => {
      isSubscribed = false
      supabase.removeChannel(channel)
      if (reconnectTimeout) clearTimeout(reconnectTimeout)
      if (railwayWs) railwayWs.close()
      if (updateTimeout) clearTimeout(updateTimeout)
    }
  }, [fetchLiveOrdersList, playNewOrderChime, onNewOrder, onOrderUpdated])

  // Active carts badge count fetch
  useEffect(() => {
    let active = true
    const fetchCartsCount = async () => {
      try {
        const storeQuery =
          selectedHubId && selectedHubId !== 'all'
            ? `&storeId=${encodeURIComponent(selectedHubId)}`
            : ''
        const token = await getAuthToken()
        const headers: Record<string, string> = {}
        if (token) headers['Authorization'] = `Bearer ${token}`

        const res = await fetch(`/api/admin/live-carts?t=${Date.now()}${storeQuery}`, { headers })
        if (res.ok && active) {
          const data = await res.json()
          setActiveCartsCount(data.count || 0)
        }
      } catch (err) {
        console.error('Failed to fetch carts count:', err)
      }
    }
    fetchCartsCount()
    const countInterval = setInterval(fetchCartsCount, 15000)
    return () => {
      active = false
      clearInterval(countInterval)
    }
  }, [selectedHubId, cartsRefreshKey])

  // Active carts detail polling when activeTab === 'liveops'
  useEffect(() => {
    let active = true
    let intervalId: any = null

    const fetchCartsDetail = async () => {
      if (activeTab !== 'liveops') return
      if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return
      setIsLoadingCarts(true)
      try {
        const storeQuery =
          selectedHubId && selectedHubId !== 'all'
            ? `&storeId=${encodeURIComponent(selectedHubId)}`
            : ''
        const token = await getAuthToken()
        const headers: Record<string, string> = {}
        if (token) headers['Authorization'] = `Bearer ${token}`

        const res = await fetch(`/api/admin/live-carts?t=${Date.now()}${storeQuery}`, { headers })
        if (res.ok && active) {
          const data = await res.json()
          setActiveCarts(data.carts || [])
          setActiveCartsCount(data.count || 0)
        }
      } catch (err) {
        console.error('Failed to fetch live carts detail:', err)
      } finally {
        if (active) setIsLoadingCarts(false)
      }
    }

    const handleVisibility = () => {
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
        fetchCartsDetail()
      }
    }

    if (activeTab === 'liveops') {
      fetchCartsDetail()
      intervalId = setInterval(fetchCartsDetail, 10000)
      if (typeof document !== 'undefined') {
        document.addEventListener('visibilitychange', handleVisibility)
      }
    }

    return () => {
      active = false
      if (intervalId) clearInterval(intervalId)
      if (typeof document !== 'undefined') {
        document.removeEventListener('visibilitychange', handleVisibility)
      }
    }
  }, [activeTab, cartsRefreshKey, selectedHubId])

  // Memoized live pending orders
  const livePendingOrders = useMemo(() => {
    return (Array.isArray(liveOrders) ? liveOrders : [])
      .filter((o: any) => o.status === 'PENDING')
      .sort((a: any, b: any) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
  }, [liveOrders])

  // Filter delayed orders
  const delayedOrders = useMemo(() => {
    return (Array.isArray(liveOrders) ? liveOrders : []).filter((order) => {
      const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
      if (order.status === 'PENDING') {
        const diffMs = new Date().getTime() - new Date(order.createdAt).getTime()
        return diffMs > (isRestaurant ? 30 : 10) * 60 * 1000
      }
      if (order.status === 'PACKED') {
        const baseTime = order.updatedAt || order.createdAt
        const diffMs = new Date().getTime() - new Date(baseTime).getTime()
        return diffMs > 10 * 60 * 1000
      }
      if (order.status === 'CONFIRMED') {
        const baseTime = order.updatedAt || order.createdAt
        const diffMs = new Date().getTime() - new Date(baseTime).getTime()
        if (isRestaurant) {
          return diffMs > 30 * 60 * 1000
        } else {
          return diffMs > 10 * 60 * 1000
        }
      }
      return false
    })
  }, [liveOrders])

  // Warning chime manager
  useEffect(() => {
    if (isChimeMuted) return
    if (delayedOrders.length === 0) return

    playWarningChime()
    const chimeInterval = setInterval(playWarningChime, 20000)
    return () => clearInterval(chimeInterval)
  }, [delayedOrders.length, isChimeMuted, playWarningChime])

  const pickerDelays = useMemo(
    () =>
      (Array.isArray(delayedOrders) ? delayedOrders : []).filter(
        (o) =>
          !o.restaurantId &&
          o.orderType !== 'RESTAURANT' &&
          (o.status === 'PENDING' || o.status === 'CONFIRMED')
      ),
    [delayedOrders]
  )

  const chefDelays = useMemo(
    () =>
      (Array.isArray(delayedOrders) ? delayedOrders : []).filter(
        (o) =>
          (!!o.restaurantId || o.orderType === 'RESTAURANT') &&
          (o.status === 'PENDING' || o.status === 'CONFIRMED')
      ),
    [delayedOrders]
  )

  const riderDelays = useMemo(
    () => (Array.isArray(delayedOrders) ? delayedOrders : []).filter((o) => o.status === 'PACKED'),
    [delayedOrders]
  )

  return {
    liveOrders,
    setLiveOrders,
    livePendingOrders,
    delayedOrders,
    pickerDelays,
    chefDelays,
    riderDelays,
    orderRefreshKey,
    setOrderRefreshKey,
    isChimeMuted,
    setIsChimeMuted,
    activeCarts,
    activeCartsCount,
    isLoadingCarts,
    cartsRefreshKey,
    setCartsRefreshKey,
    playWarningChime,
    playNewOrderChime,
    fetchLiveOrdersList,
  }
}
