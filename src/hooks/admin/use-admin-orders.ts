'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'

interface UseAdminOrdersProps {
  initialOrders?: any[]
  initialOrderCounts?: Record<string, number>
  selectedHubId: string
  orderRefreshKey: number
}

export function useAdminOrders({
  initialOrders,
  initialOrderCounts,
  selectedHubId,
  orderRefreshKey,
}: UseAdminOrdersProps) {
  const [orders, setOrders] = useState(initialOrders || [])
  const [orderCounts, setOrderCounts] = useState<Record<string, number>>(() => {
    if (initialOrderCounts) return initialOrderCounts
    const list = initialOrders || []
    return {
      ALL: list.length,
      PENDING: list.filter((o: any) => o.status === 'PENDING').length,
      CONFIRMED: list.filter((o: any) => o.status === 'CONFIRMED').length,
      PACKED: list.filter((o: any) => o.status === 'PACKED').length,
      SHIPPED: list.filter((o: any) => o.status === 'SHIPPED').length,
      DELIVERED: list.filter((o: any) => o.status === 'DELIVERED').length,
      CANCELLED: list.filter((o: any) => o.status === 'CANCELLED').length,
    }
  })

  const [orderPage, setOrderPage] = useState(1)
  const [orderTotal, setOrderTotal] = useState((initialOrders || []).length)
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

  const fetchOrders = useCallback(async () => {
    try {
      const storeQueryParam =
        selectedHubId && selectedHubId !== 'all'
          ? `&storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(
        `/api/admin/orders?page=${orderPage}&limit=10&status=${orderStatusFilter}&search=${encodeURIComponent(
          orderSearchQuery
        )}${storeQueryParam}&t=${Date.now()}`
      )
      if (res.ok) {
        const data = await res.json()
        setOrders(data.orders)
        setOrderTotal(data.total)
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
  }, [orderPage, orderStatusFilter, orderSearchQuery, selectedHubId])

  useEffect(() => {
    fetchOrders()
    const interval = setInterval(fetchOrders, 10000)
    return () => clearInterval(interval)
  }, [fetchOrders, orderRefreshKey])

  const handleOpenOrderModal = useCallback(async (order: any) => {
    if (!order) return
    setSelectedOrderForTracking(order)
    setIsLoadingOrderItems(true)
    try {
      const res = await fetch(`/api/orders/${order.id}`)
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
