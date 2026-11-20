'use client';
import { apiUrl } from '@/lib/api-url';

import { useState, useEffect, useMemo, useCallback, useRef } from 'react'
import { supabase } from '@/lib/supabase-client'
import { toast } from 'sonner'
import { logger } from '@/lib/logger'
import { getAuthToken } from '@/lib/fastapi'
import { parseDateInput } from '@/lib/date-helpers'
import {
  playSwiggyOrderBuzzer,
  speakOrderAlert,
  tryUnlockAudioContext,
  isAudioContextSuspended,
} from '@/lib/audio'

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

function showDesktopNotification(title: string, body: string, onClick?: () => void) {
  if (typeof window === 'undefined' || !('Notification' in window)) return
  if (Notification.permission === 'granted') {
    try {
      const notif = new Notification(title, {
        body,
        icon: '/icons/icon-192x192.png',
        tag: 'fastminute-new-order',
      })
      if (onClick) {
        notif.onclick = () => {
          window.focus()
          onClick()
        }
      }
    } catch {}
  }
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

  const [isAudioBlocked, setIsAudioBlocked] = useState(false)

  // Auto-detect browser autoplay policy and attach global user gesture unlockers
  useEffect(() => {
    if (typeof window === 'undefined') return
    if (isAudioContextSuspended()) {
      setIsAudioBlocked(true)
    }

    const unlock = () => {
      tryUnlockAudioContext().then((unlocked) => {
        if (unlocked) setIsAudioBlocked(false)
      })
    }

    window.addEventListener('click', unlock, { once: true })
    window.addEventListener('touchstart', unlock, { once: true })
    window.addEventListener('keydown', unlock, { once: true })

    return () => {
      window.removeEventListener('click', unlock)
      window.removeEventListener('touchstart', unlock)
      window.removeEventListener('keydown', unlock)
    }
  }, [])

  const handleUnblockAudio = useCallback(async () => {
    const unlocked = await tryUnlockAudioContext()
    if (unlocked) {
      setIsAudioBlocked(false)
      playSwiggyOrderBuzzer()
      toast.success('🔔 Live Order Buzzer activated!')
    }
  }, [])

  // Web Audio new order buzzer & alert announcer
  const playNewOrderChime = useCallback(
    (readableId?: string, itemCount = 1) => {
      if (isChimeMuted) return
      try {
        playSwiggyOrderBuzzer()
        if (readableId) {
          speakOrderAlert(readableId, itemCount)
        }
      } catch (err) {
        console.warn('Failed to play new order chime/buzzer:', err)
      }
    },
    [isChimeMuted]
  )

  const knownLiveOrderIds = useRef<Set<string>>(new Set())

  const fetchLiveOrdersList = useCallback(async () => {
    try {
      const storeQuery =
        selectedHubId && selectedHubId !== 'all'
          ? `&storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(`${apiUrl()}/api/admin/orders?limit=30&skipStats=true${storeQuery}&t=${Date.now()}`)
      if (res.ok) {
        const data = await res.json()
        const fetched = Array.isArray(data?.orders)
          ? data.orders
          : Array.isArray(data)
          ? data
          : []

        // If previously populated, detect any incoming new pending/confirmed orders
        if (knownLiveOrderIds.current.size > 0) {
          const twentyFourHoursAgo = Date.now() - 24 * 60 * 60 * 1000
          const newlyArrived = fetched.filter((o: any) => {
            if (knownLiveOrderIds.current.has(o.id)) return false
            if (o.status === 'PENDING' || o.status === 'ADMIN_PENDING') return true
            if (o.status === 'CONFIRMED') {
              const t = parseDateInput(o.createdAt)?.getTime() || 0
              return t >= twentyFourHoursAgo
            }
            return false
          })
          if (newlyArrived.length > 0) {
            const first = newlyArrived[0]
            const readableId = (first.readableId || first.id).slice(0, 8)
            const amt = first.total ? ` (₹${Math.round(first.total)})` : ''
            const isPaid = first.paymentStatus === 'PAID' || first.status === 'CONFIRMED'
            const msg = isPaid
              ? `💳 Online Paid Order #${readableId}${amt}`
              : `🛎️ New Order Received: #${readableId}${amt}`
            toast.success(msg, { duration: 9000 })
            playNewOrderChime(readableId, first.items?.length || 1)
            showDesktopNotification('FastMinute New Order!', msg)
            setOrderRefreshKey((prev) => prev + 1)
          }
        }

        knownLiveOrderIds.current = new Set(fetched.map((o: any) => o.id))
        setLiveOrders(fetched)
      }
    } catch (err) {
      console.error('Failed to poll live orders:', err)
    }
  }, [selectedHubId, playNewOrderChime])

  const isFirstMountRef = useRef(true)
  const lastKnownLatestOrderId = useRef<string | null>(null)
  const isPollingPulseRef = useRef(false)

  // Lightweight 80-byte pulse check for zero-load instant order detection (<3ms query)
  const checkOrderPulse = useCallback(async () => {
    if (isPollingPulseRef.current) return
    isPollingPulseRef.current = true
    try {
      const storeQuery =
        selectedHubId && selectedHubId !== 'all'
          ? `?storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(`${apiUrl()}/api/admin/orders/pulse${storeQuery}&t=${Date.now()}`)
      if (res.ok) {
        const data = await res.json()
        const latest = data?.latestOrder
        if (latest && latest.id) {
          if (lastKnownLatestOrderId.current && lastKnownLatestOrderId.current !== latest.id) {
            const readableId = (latest.readableId || latest.id).slice(0, 8)
            const amt = latest.total ? ` (₹${Math.round(latest.total)})` : ''
            const isPaid = latest.paymentStatus === 'PAID' || latest.status === 'CONFIRMED'
            const msg = isPaid
              ? `💳 Online Paid Order #${readableId}${amt}`
              : `🛎️ New Order #${readableId}${amt}`

            toast.success(msg, { duration: 9000 })
            playNewOrderChime(readableId, 1)
            showDesktopNotification('FastMinute New Order!', msg)

            fetchLiveOrdersList()
            setOrderRefreshKey((prev) => prev + 1)
          }
          lastKnownLatestOrderId.current = latest.id
        } else if (!latest) {
          lastKnownLatestOrderId.current = null
        }
      }
    } catch {
      // Graceful silence on network glitches
    } finally {
      isPollingPulseRef.current = false
    }
  }, [selectedHubId, playNewOrderChime, fetchLiveOrdersList])

  // Request browser desktop notification permission on mount
  useEffect(() => {
    if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission().catch(() => {})
    }
  }, [])

  // Active zero-load order pulse: 3.5s when active, 5.0s in background (never stops!)
  useEffect(() => {
    if (isFirstMountRef.current) {
      isFirstMountRef.current = false
      if (initialOrders && initialOrders.length > 0) {
        knownLiveOrderIds.current = new Set(initialOrders.map((o: any) => o.id))
        const first = initialOrders[0]
        if (
          first &&
          (first.status === 'PENDING' ||
            first.status === 'ADMIN_PENDING' ||
            first.status === 'CONFIRMED')
        ) {
          lastKnownLatestOrderId.current = first.id
        }
      } else {
        fetchLiveOrdersList()
      }
      checkOrderPulse()
    }

    let pulseTimer: NodeJS.Timeout | null = null

    const schedulePulse = () => {
      if (pulseTimer) clearInterval(pulseTimer)
      const isVisible = typeof document !== 'undefined' && document.visibilityState === 'visible'
      const intervalMs = isVisible ? 3500 : 5000
      pulseTimer = setInterval(() => {
        checkOrderPulse()
      }, intervalMs)
    }

    schedulePulse()

    // Background full list sync every 25 seconds
    const fullSyncInterval = setInterval(() => {
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
        fetchLiveOrdersList()
      }
    }, 25000)

    const handleVisibility = () => {
      schedulePulse()
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
        checkOrderPulse()
        fetchLiveOrdersList()
        setOrderRefreshKey((prev) => prev + 1)
      }
    }

    if (typeof document !== 'undefined') {
      document.addEventListener('visibilitychange', handleVisibility)
    }

    return () => {
      if (pulseTimer) clearInterval(pulseTimer)
      clearInterval(fullSyncInterval)
      if (typeof document !== 'undefined') {
        document.removeEventListener('visibilitychange', handleVisibility)
      }
    }
  }, [checkOrderPulse, fetchLiveOrdersList, initialOrders])

  // Tri-channel listener: Supabase, SSE, Railway WebSocket
  useEffect(() => {
    let updateTimeout: NodeJS.Timeout | null = null

    const debouncedRefresh = () => {
      if (updateTimeout) clearTimeout(updateTimeout)
      updateTimeout = setTimeout(() => {
        fetchLiveOrdersList()
        setOrderRefreshKey((prev) => prev + 1)
      }, 800)
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
            const isPaid = orderData?.paymentStatus === 'PAID' || orderData?.status === 'CONFIRMED'
            const rId = (orderData?.readableId || orderData?.id || '').slice(0, 8)
            const amt = orderData?.total ? ` (₹${Math.round(orderData.total)})` : ''
            const msg = isPaid
              ? `💳 Online Paid Order: #${rId}${amt}`
              : `🛎️ New Order Received: #${rId}${amt}`
            toast.success(msg, { duration: 9000 })
            playNewOrderChime(rId, 1)
            showDesktopNotification('FastMinute New Order!', msg)
            onNewOrder?.(orderData)
            debouncedRefresh()
          } else if (payload.eventType === 'UPDATE') {
            const oldOrder = payload.old as any
            const isNowPaid =
              (orderData?.paymentStatus === 'PAID' && oldOrder?.paymentStatus !== 'PAID') ||
              (orderData?.status === 'CONFIRMED' && oldOrder?.status !== 'CONFIRMED')
            if (isNowPaid) {
              const rId = (orderData?.readableId || orderData?.id || '').slice(0, 8)
              const amt = orderData?.total ? ` (₹${Math.round(orderData.total)})` : ''
              const msg = `💳 Online Paid Order: #${rId}${amt}`
              toast.success(msg, { duration: 9000 })
              playNewOrderChime(rId, 1)
              showDesktopNotification('FastMinute New Order!', msg)
            }
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
      .on('broadcast', { event: 'new-order' }, (payload) => {
        const orderData = payload?.payload?.orders?.[0] || payload?.payload?.order || payload?.payload
        const orderStoreId = orderData?.storeId
        if (selectedHubId && selectedHubId !== 'all' && orderStoreId && orderStoreId !== selectedHubId) {
          return
        }
        const isPaid = orderData?.paymentStatus === 'PAID' || orderData?.status === 'CONFIRMED'
        const rId = (orderData?.readableId || orderData?.id || '').slice(0, 8)
        const amt = orderData?.total ? ` (₹${Math.round(orderData.total)})` : ''
        const msg = isPaid ? `💳 Online Paid Order: #${rId}${amt}` : `🛎️ New Order Received: #${rId}${amt}`
        toast.success(msg, { duration: 9000 })
        playNewOrderChime(rId, 1)
        showDesktopNotification('FastMinute New Order!', msg)
        debouncedRefresh()
      })
      .on('broadcast', { event: 'order-status-update' }, () => {
        debouncedRefresh()
      })
      .on('broadcast', { event: 'order-payment-updated' }, (payload) => {
        const rId = (payload.payload?.readableId || payload.payload?.orderId || '').slice(0, 8)
        toast.success(`💳 Order #${rId} marked PAID!`)
        playNewOrderChime(rId, 1)
        debouncedRefresh()
      })
      .subscribe()

    let isSubscribed = true
    let railwayWs: WebSocket | null = null
    let reconnectTimeout: NodeJS.Timeout | null = null
    let pingInterval: NodeJS.Timeout | null = null

    const connectRailwayWs = () => {
      if (!isSubscribed) return
      try {
        const rawFastApiUrl = process.env.NEXT_PUBLIC_FASTAPI_URL || process.env.NEXT_PUBLIC_API_URL || 'https://api.fastkirana.in'
        const cleanUrl = rawFastApiUrl.replace(/\/+$/, '')
        const token = typeof window !== 'undefined'
          ? (localStorage.getItem('fastapi_token') || localStorage.getItem('fastkirana_token'))
          : null
        const wsUrl = cleanUrl.replace(/^http:/, 'ws:').replace(/^https:/, 'wss:') + '/ws' + (token ? `?token=${encodeURIComponent(token)}` : '')
        railwayWs = new WebSocket(wsUrl)

        railwayWs.onopen = () => {
          if (pingInterval) clearInterval(pingInterval)
          pingInterval = setInterval(() => {
            if (railwayWs && railwayWs.readyState === WebSocket.OPEN) {
              try {
                railwayWs.send('ping')
              } catch (_) {}
            }
          }, 20000)
        }

        railwayWs.onmessage = (event) => {
          try {
            if (event.data === 'ping' || event.data === 'pong' || event.data === 'PONG') return
            const payload = JSON.parse(event.data)
            if (payload?.event === 'PONG') return

            const ev = payload.event || payload.type
            if (ev === 'NEW_ORDER' || ev === 'ORDER_CREATED' || ev === 'new-order') {
              const orderStoreId = payload.storeId || payload.order?.storeId
              if (selectedHubId && selectedHubId !== 'all' && orderStoreId && orderStoreId !== selectedHubId) {
                return
              }
              const displayId = (payload.readableId || payload.orderId || payload.order?.readableId || '').slice(0, 8)
              const isPaid = payload.paymentStatus === 'PAID' || payload.isPaid || payload.status === 'CONFIRMED'
              const amt = payload.total || payload.order?.total ? ` (₹${Math.round(payload.total || payload.order?.total)})` : ''
              const msg = isPaid ? `💳 Online Paid Order! #${displayId}${amt}` : `🛎️ New Order Received! #${displayId}${amt}`
              toast.success(msg, { duration: 9000 })
              playNewOrderChime(displayId, 1)
              showDesktopNotification('FastMinute New Order!', msg)
              debouncedRefresh()
            } else if (
              ev === 'PAYMENT_CONFIRMED' ||
              ev === 'PAYMENT_SUCCESS' ||
              ev === 'order-payment-updated' ||
              (payload.paymentStatus === 'PAID' && (ev === 'UPDATE' || ev === 'STATUS_UPDATE'))
            ) {
              const orderStoreId = payload.storeId || payload.order?.storeId
              if (selectedHubId && selectedHubId !== 'all' && orderStoreId && orderStoreId !== selectedHubId) {
                return
              }
              const displayId = (payload.readableId || payload.orderId || payload.order?.readableId || '').slice(0, 8)
              const msg = `💳 Online Payment Confirmed! #${displayId}`
              toast.success(msg)
              playNewOrderChime(displayId, 1)
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
          if (pingInterval) clearInterval(pingInterval)
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
      if (pingInterval) clearInterval(pingInterval)
      if (reconnectTimeout) clearTimeout(reconnectTimeout)
      if (railwayWs) railwayWs.close()
      if (updateTimeout) clearTimeout(updateTimeout)
    }
  }, [fetchLiveOrdersList, playNewOrderChime, onNewOrder, onOrderUpdated, selectedHubId])

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

        const res = await fetch(`${apiUrl()}/api/admin/live-carts?t=${Date.now()}${storeQuery}`, { headers })
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

        const res = await fetch(`${apiUrl()}/api/admin/live-carts?t=${Date.now()}${storeQuery}`, { headers })
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

  // Memoized live pending/actionable orders (PENDING, ADMIN_PENDING, or recent CONFIRMED awaiting action)
  const livePendingOrders = useMemo(() => {
    const twentyFourHoursAgo = Date.now() - 24 * 60 * 60 * 1000
    return (Array.isArray(liveOrders) ? liveOrders : [])
      .filter((o: any) => {
        if (o.status === 'PENDING' || o.status === 'ADMIN_PENDING') return true
        if (o.status === 'CONFIRMED') {
          const t = parseDateInput(o.createdAt)?.getTime() || 0
          return t >= twentyFourHoursAgo
        }
        return false
      })
      .sort((a: any, b: any) => {
        const timeA = parseDateInput(a.createdAt)?.getTime() || 0
        const timeB = parseDateInput(b.createdAt)?.getTime() || 0
        return timeA - timeB
      })
  }, [liveOrders])

  // Continuous Swiggy / Zomato order alarm buzzer: rings every 3.5s while unhandled orders exist
  useEffect(() => {
    if (isChimeMuted) return
    if (!livePendingOrders || livePendingOrders.length === 0) return

    playSwiggyOrderBuzzer()
    const buzzerInterval = setInterval(() => {
      playSwiggyOrderBuzzer()
    }, 3500)

    return () => clearInterval(buzzerInterval)
  }, [livePendingOrders.length, isChimeMuted])

  // Filter delayed orders
  const delayedOrders = useMemo(() => {
    const now = Date.now()
    return (Array.isArray(liveOrders) ? liveOrders : []).filter((order) => {
      const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
      if (order.status === 'PENDING') {
        const d = parseDateInput(order.createdAt)
        if (!d) return false
        const diffMs = now - d.getTime()
        return diffMs > (isRestaurant ? 30 : 10) * 60 * 1000
      }
      if (order.status === 'PACKED') {
        const baseTime = order.updatedAt || order.createdAt
        const d = parseDateInput(baseTime)
        if (!d) return false
        const diffMs = now - d.getTime()
        return diffMs > 10 * 60 * 1000
      }
      if (order.status === 'CONFIRMED') {
        const baseTime = order.updatedAt || order.createdAt
        const d = parseDateInput(baseTime)
        if (!d) return false
        const diffMs = now - d.getTime()
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
    isAudioBlocked,
    handleUnblockAudio,
    fetchLiveOrdersList,
  }
}
