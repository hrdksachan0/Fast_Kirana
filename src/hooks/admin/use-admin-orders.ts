'use client'

import { useState, useEffect, useMemo, useCallback, useRef } from 'react'
import { useSession } from 'next-auth/react'

interface UseAdminOrdersProps {
  initialOrders?: any[]
  initialOrderCounts?: Record<string, number>
  selectedHubId: string
  orderRefreshKey: number
  onNewOrderDetected?: (order: any) => void
}

export function useAdminOrders({
  initialOrders,
  initialOrderCounts,
  selectedHubId,
  orderRefreshKey,
  onNewOrderDetected,
}: UseAdminOrdersProps) {
  const { data: session } = useSession()
  const authHeaders = useMemo(() => ({
    'Content-Type': 'application/json',
    ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
    ...((session?.user as any)?.role ? { 'x-user-role': (session?.user as any).role } : { 'x-user-role': 'ADMIN' }),
    ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
    ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
  }), [session])

  const [orders, setOrders] = useState<any[]>(Array.isArray(initialOrders) ? initialOrders : [])
  const [orderCounts, setOrderCounts] = useState<Record<string, number>>(() => {
    if (initialOrderCounts) return initialOrderCounts
    const list = Array.isArray(initialOrders) ? initialOrders : []
    return {
      ALL: list.length,
      ADMIN_PENDING: list.filter((o: any) => o.status === 'ADMIN_PENDING').length,
      PENDING: list.filter((o: any) => o.status === 'PENDING' && (o.paymentMethod === 'COD' || o.paymentStatus === 'PAID')).length,
      PAYMENT_PENDING: list.filter((o: any) => o.status === 'PENDING' && o.paymentMethod !== 'COD' && o.paymentStatus !== 'PAID').length,
      CONFIRMED: list.filter((o: any) => o.status === 'CONFIRMED').length,
      PACKED: list.filter((o: any) => o.status === 'PACKED').length,
      SHIPPED: list.filter((o: any) => o.status === 'SHIPPED').length,
      DELIVERED: list.filter((o: any) => o.status === 'DELIVERED').length,
      CANCELLED: list.filter((o: any) => o.status === 'CANCELLED').length,
    }
  })

  const [orderPage, setOrderPage] = useState(1)
  const [orderTotal, setOrderTotal] = useState(Array.isArray(initialOrders) ? initialOrders.length : 0)
  const [isLoadingOrders, setIsLoadingOrders] = useState(false)
  const [orderStatusFilter, setOrderStatusFilter] = useState('ALL')
  const [orderSearchQuery, setOrderSearchQuery] = useState('')
  const [ordersSubTab, setOrdersSubTab] = useState<'active' | 'history'>('active')
  const [orderShopFilter, setOrderShopFilter] = useState<'ALL' | 'GROCERY' | 'CAFE' | 'RESTAURANT'>(
    'ALL'
  )
  const [orderMethodFilter, setOrderMethodFilter] = useState<'ALL' | 'DELIVERY' | 'SELF_PICKUP'>(
    'ALL'
  )
  const [selectedOrderForTracking, setSelectedOrderForTracking] = useState<any | null>(null)
  const [isLoadingOrderItems, setIsLoadingOrderItems] = useState(false)
  const [updatingOrderId, setUpdatingOrderId] = useState<string | null>(null)

  const [apiTodaySales, setApiTodaySales] = useState<number | null>(null)
  const [apiTodayNetSales, setApiTodayNetSales] = useState<number | null>(null)
  const [apiTodayOrdersCount, setApiTodayOrdersCount] = useState<number | null>(null)
  const [apiTodayDeliveryFee, setApiTodayDeliveryFee] = useState<number | null>(null)
  const [apiTodayPackagingFee, setApiTodayPackagingFee] = useState<number | null>(null)

  useEffect(() => {
    setOrderPage(1)
  }, [orderStatusFilter, orderSearchQuery, selectedHubId])

  const prevKnownOrderIds = useRef<Set<string>>(new Set())

  const fetchOrders = useCallback(async () => {
    try {
      const storeQueryParam =
        selectedHubId && selectedHubId !== 'all'
          ? `&storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(
        `/api/admin/orders?page=${orderPage}&limit=10&status=${orderStatusFilter}&search=${encodeURIComponent(
          orderSearchQuery
        )}${storeQueryParam}&t=${Date.now()}`,
        { headers: authHeaders }
      )
      if (res.ok) {
        const data = await res.json()
        const fetchedOrders = Array.isArray(data)
          ? data
          : Array.isArray(data?.orders)
          ? data.orders
          : []

        // If previously populated, detect newly received pending orders
        if (prevKnownOrderIds.current.size > 0) {
          const freshPending = fetchedOrders.filter(
            (o: any) =>
              !prevKnownOrderIds.current.has(o.id) &&
              (o.status === 'PENDING' || o.status === 'ADMIN_PENDING')
          )
          if (freshPending.length > 0) {
            onNewOrderDetected?.(freshPending[0])
          }
        }
        prevKnownOrderIds.current = new Set(fetchedOrders.map((o: any) => o.id))

        setOrders(fetchedOrders)
        setOrderTotal(typeof data?.total === 'number' ? data.total : fetchedOrders.length)
        if (typeof data.todaySales === 'number') setApiTodaySales(data.todaySales)
        if (typeof data.todayNetSales === 'number') setApiTodayNetSales(data.todayNetSales)
        if (typeof data.todayOrdersCount === 'number') setApiTodayOrdersCount(data.todayOrdersCount)
        if (typeof data.todayDeliveryFee === 'number') setApiTodayDeliveryFee(data.todayDeliveryFee)
        if (typeof data.todayPackagingFee === 'number')
          setApiTodayPackagingFee(data.todayPackagingFee)
        if (data.counts) {
          setOrderCounts(data.counts)
        }
      }
    } catch (err) {
      console.error('Failed to fetch orders:', err)
    } finally {
      setIsLoadingOrders(false)
    }
  }, [orderPage, orderStatusFilter, orderSearchQuery, selectedHubId, authHeaders, onNewOrderDetected])

  useEffect(() => {
    fetchOrders()

    // 6-second fast polling for active live action queue, 30s for history
    const pollInterval = ordersSubTab === 'active' ? 6000 : 30000
    const interval = setInterval(() => {
      if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return
      fetchOrders()
    }, pollInterval)

    const handleVisibility = () => {
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
        fetchOrders()
      }
    }

    if (typeof document !== 'undefined') {
      document.addEventListener('visibilitychange', handleVisibility)
    }

    return () => {
      clearInterval(interval)
      if (typeof document !== 'undefined') {
        document.removeEventListener('visibilitychange', handleVisibility)
      }
    }
  }, [fetchOrders, orderRefreshKey, ordersSubTab])

  const handleOpenOrderModal = useCallback(async (order: any) => {
    if (!order) return
    setSelectedOrderForTracking(order)
    setIsLoadingOrderItems(true)
    try {
      const res = await fetch(`/api/orders/${order.id}`, { headers: authHeaders })
      if (res.ok) {
        const fullData = await res.json()
        setSelectedOrderForTracking((prev: any) => ({ ...prev, ...fullData }))
      }
    } catch (err) {
      console.error('Failed to fetch full order details:', err)
    } finally {
      setIsLoadingOrderItems(false)
    }
  }, [])

  return {
    orders,
    setOrders,
    orderCounts,
    setOrderCounts,
    orderPage,
    setOrderPage,
    orderTotal,
    isLoadingOrders,
    orderStatusFilter,
    setOrderStatusFilter,
    orderSearchQuery,
    setOrderSearchQuery,
    ordersSubTab,
    setOrdersSubTab,
    orderShopFilter,
    setOrderShopFilter,
    orderMethodFilter,
    setOrderMethodFilter,
    selectedOrderForTracking,
    setSelectedOrderForTracking,
    isLoadingOrderItems,
    updatingOrderId,
    setUpdatingOrderId,
    apiTodaySales,
    apiTodayNetSales,
    apiTodayOrdersCount,
    apiTodayDeliveryFee,
    apiTodayPackagingFee,
    fetchOrders,
    handleOpenOrderModal,
  }
}
