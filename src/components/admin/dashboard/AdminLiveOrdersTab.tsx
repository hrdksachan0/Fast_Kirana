'use client'

import React from 'react'
import { OrdersTab } from '@/components/admin/dashboard/orders-tab'
import { LiveOpsTab } from '@/components/admin/live-ops-tab'

export interface AdminLiveOrdersTabProps {
  activeTab: 'orders' | 'liveops'
  // OrdersTab props
  orders: any[]
  orderCounts: Record<string, number> | null
  orderStatusFilter: string
  setOrderStatusFilter: (status: any) => void
  orderSearchQuery: string
  setOrderSearchQuery: (query: string) => void
  orderShopFilter: any
  setOrderShopFilter: (shop: any) => void
  orderMethodFilter: any
  setOrderMethodFilter: (method: any) => void
  ordersSubTab: 'active' | 'history'
  setOrdersSubTab: (subTab: 'active' | 'history') => void
  updatingOrderId: string | null
  onUpdateOrderStatus: (orderId: string, newStatus: string) => void
  onOpenOrderModal: (order: any) => void
  onOpenCreateOrderModal: () => void
  onNavigateToUsersTab: () => void
  livePendingOrders: any[]

  // LiveOpsTab props
  liveOrders: any[]
  delayedOrders: any[]
  activeCarts: any[]
  isLoadingCarts: boolean
  cartsRefreshKey: number
  setCartsRefreshKey: any
  sendCartNotification: (userId: string, userName: string) => Promise<void>
  openWhatsAppModal: (userName: string, phone: string) => void
}

export function AdminLiveOrdersTab({
  activeTab,
  orders,
  orderCounts,
  orderStatusFilter,
  setOrderStatusFilter,
  orderSearchQuery,
  setOrderSearchQuery,
  orderShopFilter,
  setOrderShopFilter,
  orderMethodFilter,
  setOrderMethodFilter,
  ordersSubTab,
  setOrdersSubTab,
  updatingOrderId,
  onUpdateOrderStatus,
  onOpenOrderModal,
  onOpenCreateOrderModal,
  onNavigateToUsersTab,
  livePendingOrders,
  liveOrders,
  delayedOrders,
  activeCarts,
  isLoadingCarts,
  cartsRefreshKey,
  setCartsRefreshKey,
  sendCartNotification,
  openWhatsAppModal,
}: AdminLiveOrdersTabProps) {
  if (activeTab === 'liveops') {
    return (
      <LiveOpsTab
        liveOrders={liveOrders}
        livePendingOrders={livePendingOrders}
        delayedOrders={delayedOrders}
        activeCarts={activeCarts}
        isLoadingCarts={isLoadingCarts}
        cartsRefreshKey={cartsRefreshKey}
        setCartsRefreshKey={setCartsRefreshKey}
        sendCartNotification={sendCartNotification}
        openWhatsAppModal={openWhatsAppModal}
      />
    )
  }

  return (
    <OrdersTab
      orders={orders}
      orderCounts={orderCounts || {}}
      orderStatusFilter={orderStatusFilter}
      setOrderStatusFilter={setOrderStatusFilter}
      orderSearchQuery={orderSearchQuery}
      setOrderSearchQuery={setOrderSearchQuery}
      orderShopFilter={orderShopFilter}
      setOrderShopFilter={setOrderShopFilter}
      orderMethodFilter={orderMethodFilter}
      setOrderMethodFilter={setOrderMethodFilter}
      ordersSubTab={ordersSubTab}
      setOrdersSubTab={setOrdersSubTab}
      updatingOrderId={updatingOrderId}
      onUpdateOrderStatus={onUpdateOrderStatus}
      onOpenOrderModal={onOpenOrderModal}
      onOpenCreateOrderModal={onOpenCreateOrderModal}
      onNavigateToUsersTab={onNavigateToUsersTab}
      livePendingOrders={livePendingOrders}
    />
  )
}
