'use client'

import React from 'react'
import { Search, Plus, Loader2, MessageSquare, Share2 } from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice, formatAddress } from '@/lib/utils'
import { printKOTReceipt, printCustomerInvoice } from '@/lib/kot-print'

export interface OrdersTabProps {
  orders: any[]
  orderCounts: Record<string, number>
  orderStatusFilter: string
  setOrderStatusFilter: (filter: string) => void
  orderSearchQuery: string
  setOrderSearchQuery: (query: string) => void
  orderShopFilter: string
  setOrderShopFilter: (shop: any) => void
  orderMethodFilter: string
  setOrderMethodFilter: (method: any) => void
  ordersSubTab: 'active' | 'history'
  setOrdersSubTab: (tab: 'active' | 'history') => void
  updatingOrderId: string | null
  onUpdateOrderStatus: (id: string, status: string) => void
  onDeleteOrder?: (id: string) => void
  onOpenOrderModal: (order: any) => void
  onOpenCreateOrderModal: () => void
  onNavigateToUsersTab?: () => void
  livePendingOrders?: any[]
}

export function OrdersTab({
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
  livePendingOrders = [],
}: OrdersTabProps) {
  // Split orders into Active Processing Queue vs Past History
  const activeStatuses = ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED']
  const historyStatuses = ['DELIVERED', 'CANCELLED']

  const rawActiveList = orders.filter((o) => activeStatuses.includes(o.status))
  const rawHistoryList = orders.filter((o) => historyStatuses.includes(o.status))

  const isOrderPickup = (o: any) => {
    const method = (o.deliveryMethod || '').toUpperCase()
    return method === 'SELF_PICKUP' || method === 'PICKUP' || o.isSelfPickup === true
  }

  const shareKitchenOrder = (o: any) => {
    const isPickup = isOrderPickup(o)
    const orderId = o.readableId || o.id?.slice(0, 8) || 'Order'
    const orderTime = o.createdAt ? new Date(o.createdAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : ''
    
    let text = `🍽️ *FASTKIRANA KITCHEN ORDER*\n`
    text += `━━━━━━━━━━━━━━━━━━━━━\n`
    text += `🆔 *Order Token:* #${orderId}\n`
    text += `⏰ *Order Time:* ${orderTime}\n`
    text += `📦 *Type:* ${isPickup ? '🛍️ Self Pickup (Customer Takeaway)' : '🛵 Doorstep Delivery (Rider Pickup)'}\n`
    if (o.shopName) {
      text += `🏪 *Outlet:* ${o.shopName}\n`
    }
    text += `━━━━━━━━━━━━━━━━━━━━━\n`
    const hasPremium = (o.notes?.includes('Premium') || o.miscFee === 15)
    if (hasPremium) {
      text += `✨ *PREMIUM THERMAL PACKAGING REQUESTED*\n\n`
    }
    text += `📋 *ITEMS TO PREPARE:*\n\n`
    
    if (o.items && Array.isArray(o.items) && o.items.length > 0) {
      o.items.forEach((item: any, index: number) => {
        let displayName = item.name || ''
        if (item.selectedVariant) {
          const varClean = item.selectedVariant.replace(/[()]/g, '').trim().toLowerCase()
          const nameClean = displayName.toLowerCase()
          if (!nameClean.includes(varClean)) {
            displayName += ` (${item.selectedVariant.replace(/[()]/g, '').trim()})`
          }
        }
        text += `${index + 1}. *${displayName}*  ➜  *Qty: ${item.quantity}*\n`
        if (item.notes && item.notes.trim()) {
          text += `   ↳ _Item Note: ${item.notes.trim()}_\n`
        }
      })
      const totalQty = o.items.reduce((sum: number, item: any) => sum + (item.quantity || 1), 0)
      text += `\n🔢 *Total Items to Pack:* ${totalQty} items\n`
    } else {
      text += `(Click Quick View in Admin to view loaded products)\n`
    }

    text += `━━━━━━━━━━━━━━━━━━━━━\n`
    
    // Customer Notes / Cooking Instructions
    const customerNote = o.notes || o.deliveryInstructions
    if (customerNote && customerNote.trim()) {
      text += `📝 *Customer Cooking/Delivery Note:*\n"${customerNote.trim()}"\n`
      text += `━━━━━━━━━━━━━━━━━━━━━\n`
    }

    text += `👨‍🍳 *Chef Note:* Kripya fresh prepare karein aur safely pack karein.`
    const url = `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`
    window.open(url, '_blank')
  }

  const getOrderStoreType = (o: any) => {
    if (o.restaurantId || (o.shopName && o.shopName !== 'FastKirana Grocery' && o.shopName !== 'Grocery Mart')) {
      const name = ((o.restaurantName || o.shopName) || '').toLowerCase()
      if (name.includes('cafe') || name.includes('a.s') || name.includes('as-')) return 'CAFE'
      return 'RESTAURANT'
    }
    return 'GROCERY'
  }

  // Filter Active Table by status, store, method & search query
  const filteredActiveOrders = rawActiveList.filter((o) => {
    const matchesFilter = orderStatusFilter === 'ALL' || !activeStatuses.includes(orderStatusFilter) || o.status === orderStatusFilter
    const matchesShop = orderShopFilter === 'ALL' || getOrderStoreType(o) === orderShopFilter
    const matchesMethod = orderMethodFilter === 'ALL' || (orderMethodFilter === 'SELF_PICKUP' ? isOrderPickup(o) : !isOrderPickup(o))
    const matchesSearch = 
      orderSearchQuery.trim() === '' || 
      o.id.toLowerCase().includes(orderSearchQuery.toLowerCase()) || 
      (o.userName && o.userName.toLowerCase().includes(orderSearchQuery.toLowerCase())) || 
      (o.userEmail && o.userEmail.toLowerCase().includes(orderSearchQuery.toLowerCase())) ||
      (o.userPhone && o.userPhone.includes(orderSearchQuery)) ||
      (o.address?.phone && o.address.phone.includes(orderSearchQuery))
    return matchesFilter && matchesShop && matchesMethod && matchesSearch
  })

  // Filter History Table by status, store, method & search query
  const filteredHistoryOrders = rawHistoryList.filter((o) => {
    const matchesFilter = orderStatusFilter === 'ALL' || activeStatuses.includes(orderStatusFilter) || o.status === orderStatusFilter
    const matchesShop = orderShopFilter === 'ALL' || getOrderStoreType(o) === orderShopFilter
    const matchesMethod = orderMethodFilter === 'ALL' || (orderMethodFilter === 'SELF_PICKUP' ? isOrderPickup(o) : !isOrderPickup(o))
    const matchesSearch = 
      orderSearchQuery.trim() === '' || 
      o.id.toLowerCase().includes(orderSearchQuery.toLowerCase()) || 
      (o.userName && o.userName.toLowerCase().includes(orderSearchQuery.toLowerCase())) || 
      (o.userEmail && o.userEmail.toLowerCase().includes(orderSearchQuery.toLowerCase())) ||
      (o.userPhone && o.userPhone.includes(orderSearchQuery)) ||
      (o.address?.phone && o.address.phone.includes(orderSearchQuery))
    return matchesFilter && matchesShop && matchesMethod && matchesSearch
  })

  const activeOrdersCount = rawActiveList.length

  return (
    <div className="space-y-4 animate-fade-in">
      {/* ORDERS SUB-TABS SWITCHER */}
      <div className="flex flex-wrap items-center justify-between gap-3 bg-card border border-border rounded-2xl p-2.5 shadow-2xs">
        <div className="flex items-center gap-2 w-full sm:w-auto">
          <button
            type="button"
            onClick={() => { setOrdersSubTab('active'); setOrderStatusFilter('ALL'); }}
            className={`flex-1 sm:flex-initial px-4 py-2 text-xs font-black rounded-xl transition-all cursor-pointer flex items-center justify-center gap-2 border ${
              ordersSubTab === 'active'
                ? 'bg-amber-500 text-white border-amber-500 shadow-xs scale-102'
                : 'bg-muted/20 border-border hover:bg-muted text-text-secondary'
            }`}
          >
            <span className="h-2 w-2 rounded-full bg-emerald-400 animate-ping inline-block" />
            <span>🔥 Live Action Queue ({rawActiveList.length})</span>
          </button>

          <button
            type="button"
            onClick={() => { setOrdersSubTab('history'); setOrderStatusFilter('ALL'); }}
            className={`flex-1 sm:flex-initial px-4 py-2 text-xs font-black rounded-xl transition-all cursor-pointer flex items-center justify-center gap-2 border ${
              ordersSubTab === 'history'
                ? 'bg-primary text-white border-primary shadow-xs scale-102'
                : 'bg-muted/20 border-border hover:bg-muted text-text-secondary'
            }`}
          >
            <span>📜 Completed &amp; Past Orders ({rawHistoryList.length})</span>
          </button>
        </div>

        <button
          onClick={onOpenCreateOrderModal}
          className="bg-primary hover:bg-primary/95 text-white font-extrabold text-[10px] px-3.5 py-1.5 rounded-xl flex items-center gap-1 cursor-pointer transition-all active:scale-95 shadow-xs border border-white/10 ml-auto"
        >
          <Plus className="h-3.5 w-3.5 stroke-[3]" />
          <span>Create Order</span>
        </button>
      </div>

      {/* SUB-TAB 1: LIVE ACTION QUEUE */}
      {ordersSubTab === 'active' && (
        <div className="bg-card border-2 border-amber-500/30 dark:border-amber-500/20 rounded-3xl p-4 sm:p-6 shadow-md overflow-hidden bg-gradient-to-b from-amber-500/[0.02] to-transparent">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
            <div className="flex items-center gap-2.5">
              <div className="h-3 w-3 rounded-full bg-amber-500 animate-ping" />
              <h3 className="font-black text-text-primary text-base sm:text-lg flex items-center gap-2">
                🔥 Live Action Queue
                <span className="text-xs bg-amber-500/15 text-amber-700 dark:text-amber-400 px-2.5 py-0.5 rounded-full font-black border border-amber-500/20">
                  {rawActiveList.length} Active
                </span>
              </h3>
            </div>
          </div>

          {/* Direct Load Alert Banner inside Active Queue */}
          {activeOrdersCount >= 8 && (
            <div className="mb-4 p-3.5 rounded-2xl border border-rose-500/25 bg-gradient-to-r from-rose-500/10 via-amber-500/5 to-rose-500/10 text-xs animate-glow-pulse">
              <div className="flex items-start gap-2.5">
                <span className="text-base">🔥</span>
                <div>
                  <h4 className="font-black text-rose-600 dark:text-rose-400">High Action Load: {activeOrdersCount} Live Processing Orders</h4>
                  <p className="text-[10px] text-text-secondary mt-0.5 font-bold">
                    Ensure fast picking &amp; cooking to meet the SLA! 
                    {onNavigateToUsersTab && (
                      <> Go to <button onClick={onNavigateToUsersTab} className="text-primary hover:underline font-black cursor-pointer">Customers tab</button> to assign staff to **Picker** or **Chef** roles.</>
                    )}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Active Queue Process-Wise Tabs & Search */}
          <div className="flex flex-col md:flex-row gap-3 items-center justify-between mb-3 border-b border-border/40 pb-3">
            <div className="flex flex-wrap gap-1.5 w-full md:w-auto">
              {[
                { key: 'ALL', label: '🔥 All Active', color: 'bg-amber-500/10 text-amber-700 border-amber-500/20' },
                { key: 'PENDING', label: '⏳ Placed (New)', color: 'bg-amber-500/10 text-amber-600 border border-amber-500/20' },
                { key: 'CONFIRMED', label: '✓ Confirmed', color: 'bg-blue-500/10 text-blue-600 border border-blue-500/20' },
                { key: 'PACKED', label: '📦 Packed', color: 'bg-[#00b140]/10 text-[#00b140] border border-[#00b140]/20' },
                { key: 'SHIPPED', label: '🛵 On the Way', color: 'bg-purple-500/10 text-purple-600 border border-purple-500/20' },
              ].map((pill) => {
                const count = pill.key === 'ALL' 
                  ? rawActiveList.length 
                  : (orderCounts[pill.key] ?? 0)
                const isActive = orderStatusFilter === pill.key || (orderStatusFilter === 'ALL' && pill.key === 'ALL')
                return (
                  <button
                    key={pill.key}
                    type="button"
                    onClick={() => setOrderStatusFilter(pill.key)}
                    className={`px-2.5 py-1 text-[10px] font-black rounded-xl transition-all cursor-pointer border ${
                      isActive 
                        ? 'bg-amber-500 text-white border-amber-500 shadow-xs scale-102' 
                        : 'bg-card border-border hover:bg-muted text-text-secondary'
                    }`}
                  >
                    {pill.label} ({count})
                  </button>
                )
              })}
            </div>
            <div className="relative w-full md:w-56">
              <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
              <input
                type="text"
                placeholder="Search active orders..."
                value={orderSearchQuery}
                onChange={(e) => setOrderSearchQuery(e.target.value)}
                className="pl-9 pr-4 py-1.5 w-full text-[10px] rounded-xl border border-border bg-muted/20 focus:outline-none focus:border-amber-500 font-semibold"
              />
            </div>
          </div>

          {/* Store Type & Fulfillment Method Filter Pills */}
          <div className="flex flex-wrap items-center justify-between gap-2.5 mb-4 p-2 bg-muted/20 border border-border/40 rounded-2xl">
            {/* Store Category Pills */}
            <div className="flex items-center gap-1 flex-wrap">
              <span className="text-[10px] font-black uppercase text-text-muted px-1">Category:</span>
              {[
                { key: 'ALL', label: '🏪 All Stores' },
                { key: 'GROCERY', label: '🛒 Grocery' },
                { key: 'CAFE', label: '☕ Cafe' },
                { key: 'RESTAURANT', label: '🍽️ Restaurant' },
              ].map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => setOrderShopFilter(s.key as any)}
                  className={`px-2.5 py-1 text-[9.5px] font-black rounded-lg transition-all cursor-pointer border ${
                    orderShopFilter === s.key
                      ? 'bg-amber-500 text-white border-amber-500 shadow-2xs'
                      : 'bg-card border-border hover:bg-muted text-text-secondary'
                  }`}
                >
                  {s.label}
                </button>
              ))}
            </div>

            {/* Fulfillment Method Pills */}
            <div className="flex items-center gap-1 flex-wrap">
              <span className="text-[10px] font-black uppercase text-text-muted px-1">Type:</span>
              {[
                { key: 'ALL', label: '📦 All Types' },
                { key: 'DELIVERY', label: '🛵 Delivery' },
                { key: 'SELF_PICKUP', label: '🛍️ Self Pickup' },
              ].map((m) => (
                <button
                  key={m.key}
                  type="button"
                  onClick={() => setOrderMethodFilter(m.key as any)}
                  className={`px-2.5 py-1 text-[9.5px] font-black rounded-lg transition-all cursor-pointer border ${
                    orderMethodFilter === m.key
                      ? 'bg-purple-600 text-white border-purple-600 shadow-2xs'
                      : 'bg-card border-border hover:bg-muted text-text-secondary'
                  }`}
                >
                  {m.label}
                </button>
              ))}
            </div>
          </div>

          {/* Active Orders Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-extrabold text-[10px]">
                  <th className="py-2.5 px-3">Order ID &amp; Store</th>
                  <th className="py-2.5 px-3">Type</th>
                  <th className="py-2.5 px-3">Customer</th>
                  <th className="py-2.5 px-3">Address</th>
                  <th className="py-2.5 px-3">Total</th>
                  <th className="py-2.5 px-3 text-center">Status</th>
                  <th className="py-2.5 px-3 text-center">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/40 font-semibold">
                {filteredActiveOrders.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="text-center py-8 text-text-secondary text-[11px] font-bold">
                      🎉 No active orders in this queue right now. All caught up!
                    </td>
                  </tr>
                ) : (
                  filteredActiveOrders.map((o) => {
                    const pendingIdx = livePendingOrders.findIndex((po) => po.id === o.id)
                    const fifoRank = pendingIdx !== -1 ? pendingIdx + 1 : null
                    const isPickup = isOrderPickup(o)
                    const storeType = getOrderStoreType(o)

                    return (
                      <tr key={o.id} className="hover:bg-amber-500/5 transition-colors">
                        <td 
                          className="py-3 px-3 cursor-pointer group/cell"
                          onClick={() => onOpenOrderModal(o)}
                          title="Click to view full order items & details"
                        >
                          <div className="flex items-center gap-1.5 flex-wrap">
                            <span className="font-mono font-black text-[11px] text-text-primary group-hover/cell:text-amber-600 transition-colors underline decoration-dotted">
                              #{o.readableId || o.id.slice(0, 8)}
                            </span>
                            {fifoRank && (
                              <span className={`text-[9px] font-black px-1.5 py-0.5 rounded-full flex items-center gap-0.5 shrink-0 ${
                                fifoRank === 1 
                                  ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-500/20' 
                                  : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800/40 dark:text-zinc-400 border border-border/40'
                              }`}>
                                {fifoRank === 1 ? '👑 FIFO #1' : `FIFO #${fifoRank}`}
                              </span>
                            )}
                          </div>
                          <div className="mt-1 flex items-center gap-1">
                            {(() => {
                              const displayName = ((o as any).restaurantName || o.shopName || '').trim()
                              const isGenericGrocery = !displayName || displayName === 'FastKirana Grocery' || displayName === 'Grocery Mart'

                              if (storeType === 'CAFE') {
                                return (
                                  <span className="px-1.5 py-0.5 rounded-md bg-amber-500/15 text-amber-700 dark:text-amber-300 font-black text-[9px] border border-amber-500/30 truncate max-w-[140px]" title={displayName || 'Cafe'}>
                                    ☕ {isGenericGrocery ? 'CAFE' : displayName.toUpperCase()}
                                  </span>
                                )
                              }
                              if (storeType === 'RESTAURANT') {
                                return (
                                  <span className="px-1.5 py-0.5 rounded-md bg-rose-500/15 text-rose-700 dark:text-rose-300 font-black text-[9px] border border-rose-500/30 truncate max-w-[140px]" title={displayName || 'Restaurant'}>
                                    🥘 {isGenericGrocery ? 'RESTAURANT' : displayName.toUpperCase()}
                                  </span>
                                )
                              }
                              return (
                                <span className="px-1.5 py-0.5 rounded-md bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 font-black text-[9px] border border-emerald-500/30">
                                  🛒 GROCERY
                                </span>
                              )
                            })()}
                          </div>
                          <div className="text-[9px] text-text-muted font-mono mt-0.5" title={o.id}>
                            ID: {o.id.slice(0, 10)}...
                          </div>
                        </td>

                        <td className="py-3 px-3 whitespace-nowrap">
                          {isPickup ? (
                            <span className="px-2 py-0.5 rounded-full bg-purple-600 text-white font-black text-[9.5px] shadow-xs animate-pulse inline-flex items-center gap-1">
                              🛍️ SELF PICKUP
                            </span>
                          ) : (
                            <span className="px-2 py-0.5 rounded-md bg-sky-500/15 text-sky-700 dark:text-sky-300 border border-sky-500/30 font-extrabold text-[9px] inline-flex items-center gap-1">
                              🛵 DELIVERY
                            </span>
                          )}
                        </td>

                        <td 
                          className="py-3 px-3 cursor-pointer group/cell"
                          onClick={() => onOpenOrderModal(o)}
                          title="Click to view full order items & details"
                        >
                          <div className="font-bold group-hover/cell:text-amber-600 transition-colors">{o.userName || 'No Name'}</div>
                          <div className="text-[10px] text-text-muted font-normal">{o.userEmail}</div>
                          {(o.userPhone || o.address?.phone) && (
                            <div className="text-[10px] text-text-secondary font-bold font-mono mt-0.5">
                              📞 {o.userPhone || o.address?.phone}
                            </div>
                          )}
                        </td>
                        <td className="py-3 px-3 text-[11px]">
                          {isPickup ? (
                            <div>
                              <div className="font-black text-[10px] text-purple-600 dark:text-purple-400 flex items-center gap-1">
                                🛍️ Customer Pickup at Counter
                              </div>
                              <div className="text-[9px] text-text-muted font-medium">Store pickup (No rider needed)</div>
                            </div>
                          ) : (
                            <>
                              <div className="line-clamp-2">{formatAddress(o.address)}</div>
                              <div className="mt-1 flex items-center gap-1.5">
                                <span className="font-mono text-[9px] text-text-muted">
                                  [{o.deliveryLat?.toFixed(4)}, {o.deliveryLng?.toFixed(4)}]
                                </span>
                                {o.deliveryLat && o.deliveryLng && (
                                  <a
                                    href={`https://www.google.com/maps?q=${o.deliveryLat},${o.deliveryLng}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="inline-flex items-center justify-center p-1 rounded hover:bg-primary/10 text-primary transition-colors shrink-0 text-sm"
                                    title="Open exact GPS coordinates on Google Maps"
                                  >
                                    📍
                                  </a>
                                )}
                              </div>
                            </>
                          )}
                        </td>
                        <td className="py-3 px-3 font-black text-text-primary whitespace-nowrap">{formatPrice(o.total)}</td>
                        <td className="py-3 px-3 text-center">
                          <div className="flex flex-col items-center justify-center gap-1.5 min-w-[105px]">
                            <select
                              value={o.status}
                              onChange={(e) => onUpdateOrderStatus(o.id, e.target.value)}
                              disabled={updatingOrderId === o.id}
                              className="bg-zinc-100 dark:bg-zinc-800 px-2 py-1 rounded-lg border border-border text-[11px] font-extrabold text-text-primary focus:outline-none cursor-pointer w-full text-center shadow-2xs"
                            >
                              <option value="PENDING">Placed</option>
                              <option value="CONFIRMED">Confirmed</option>
                              <option value="PACKED">Packed</option>
                              <option value="SHIPPED">On the Way</option>
                              <option value="DELIVERED">Delivered</option>
                              <option value="CANCELLED">Cancelled</option>
                            </select>
                            
                            {o.status === 'PENDING' && (
                              <button
                                onClick={() => onUpdateOrderStatus(o.id, 'CONFIRMED')}
                                disabled={updatingOrderId === o.id}
                                className="w-full py-1 bg-emerald-600 hover:bg-emerald-700 text-white text-[10px] font-black rounded-lg transition-all active:scale-95 shadow-xs cursor-pointer"
                                title="Accept & Confirm Order"
                              >
                                ✓ Accept
                              </button>
                            )}
                            {o.status === 'CONFIRMED' && (
                              <button
                                onClick={() => onUpdateOrderStatus(o.id, 'PACKED')}
                                disabled={updatingOrderId === o.id}
                                className="w-full py-1 bg-amber-500 hover:bg-amber-600 text-white text-[10px] font-black rounded-lg transition-all active:scale-95 shadow-xs cursor-pointer"
                                title="Mark Order Packed"
                              >
                                ✓ Pack
                              </button>
                            )}
                            {o.status === 'PACKED' && (
                              <button
                                onClick={() => onUpdateOrderStatus(o.id, 'SHIPPED')}
                                disabled={updatingOrderId === o.id}
                                className="w-full py-1 bg-indigo-600 hover:bg-indigo-700 text-white text-[10px] font-black rounded-lg transition-all active:scale-95 shadow-xs cursor-pointer"
                                title="Dispatch / Ship Order"
                              >
                                ✓ Ship
                              </button>
                            )}
                            {o.status === 'SHIPPED' && (
                              <button
                                onClick={() => onUpdateOrderStatus(o.id, 'DELIVERED')}
                                disabled={updatingOrderId === o.id}
                                className="w-full py-1 bg-emerald-600 hover:bg-emerald-700 text-white text-[10px] font-black rounded-lg transition-all active:scale-95 shadow-xs cursor-pointer"
                                title="Complete & Deliver Order"
                              >
                                ✓ Deliver
                              </button>
                            )}
                          </div>
                        </td>
                        <td className="py-3 px-3 text-center">
                          {updatingOrderId === o.id ? (
                            <Loader2 className="h-4 w-4 animate-spin text-primary mx-auto" />
                          ) : (
                            <div className="flex flex-col items-center justify-center gap-1.5 min-w-[120px]">
                              <button
                                type="button"
                                onClick={() => onOpenOrderModal(o)}
                                className="inline-flex items-center justify-center w-full py-1 px-2 rounded-md bg-rose-500/10 dark:bg-rose-500/20 text-[#e20a22] dark:text-red-400 border border-red-500/20 hover:bg-rose-500/20 text-[10px] font-black tracking-wide transition-all shadow-2xs cursor-pointer whitespace-nowrap active:scale-95"
                                title="View full ordered items & details"
                              >
                                👁️ Quick View
                              </button>
                              <div className="flex items-center justify-center gap-1 w-full">
                                <button
                                  type="button"
                                  onClick={() => {
                                    const isRest = !!o.restaurantId || o.orderType === 'RESTAURANT'
                                    printKOTReceipt(o, isRest ? 'RESTAURANT' : 'STORE')
                                  }}
                                  className="flex-1 py-1 px-1 bg-orange-500/10 hover:bg-orange-500/20 text-orange-600 dark:text-orange-400 border border-orange-500/25 text-[9px] font-black rounded-md transition-all cursor-pointer shadow-2xs active:scale-95 shrink-0 whitespace-nowrap text-center"
                                  title="Print Thermal Kitchen Order Ticket (KOT)"
                                >
                                  🖨️ KOT
                                </button>
                                <button
                                  type="button"
                                  onClick={() => shareKitchenOrder(o)}
                                  className="flex-1 py-1 px-1 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-500/25 text-[9px] font-black rounded-md transition-all cursor-pointer shadow-2xs active:scale-95 shrink-0 whitespace-nowrap text-center"
                                  title="Share products-only WhatsApp slip with Kitchen"
                                >
                                  📱 Share
                                </button>
                                <button
                                  type="button"
                                  onClick={() => printCustomerInvoice(o)}
                                  className="flex-1 py-1 px-1 bg-blue-500/10 hover:bg-blue-500/20 text-blue-600 dark:text-blue-400 border border-blue-500/25 text-[9px] font-black rounded-md transition-all cursor-pointer shadow-2xs active:scale-95 shrink-0 whitespace-nowrap text-center"
                                  title="Print Customer Tax Invoice"
                                >
                                  📄 Invoice
                                </button>
                              </div>
                            </div>
                          )}
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* SUB-TAB 2: COMPLETED & PAST ORDERS HISTORY */}
      {ordersSubTab === 'history' && (
        <div className="bg-card border border-border rounded-3xl p-4 sm:p-6 shadow-sm overflow-hidden">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
            <h3 className="font-extrabold text-text-primary text-base sm:text-lg flex items-center gap-2">
              📜 Completed &amp; Past Orders History
              <span className="text-xs bg-muted text-text-secondary px-2.5 py-0.5 rounded-full font-bold border border-border">
                {rawHistoryList.length} Archived
              </span>
            </h3>
          </div>

          {/* History Process-Wise Tabs & Search */}
          <div className="flex flex-col md:flex-row gap-3 items-center justify-between mb-3 border-b border-border/40 pb-3">
            <div className="flex flex-wrap gap-1.5 w-full md:w-auto">
              {[
                { key: 'ALL_HISTORY', label: '📋 All History', status: 'ALL' },
                { key: 'DELIVERED', label: '✅ Delivered', status: 'DELIVERED' },
                { key: 'CANCELLED', label: '❌ Cancelled', status: 'CANCELLED' },
              ].map((pill) => {
                const count = pill.key === 'ALL_HISTORY' 
                  ? rawHistoryList.length 
                  : (orderCounts[pill.status] ?? 0)
                const isActive = orderStatusFilter === pill.status || (orderStatusFilter === 'ALL' && pill.key === 'ALL_HISTORY')
                return (
                  <button
                    key={pill.key}
                    type="button"
                    onClick={() => setOrderStatusFilter(pill.status)}
                    className={`px-2.5 py-1 text-[10px] font-black rounded-xl transition-all cursor-pointer border ${
                      isActive 
                        ? 'bg-primary text-white border-primary shadow-xs' 
                        : 'bg-card border-border hover:bg-muted text-text-secondary'
                    }`}
                  >
                    {pill.label} ({count})
                  </button>
                )
              })}
            </div>
            <div className="relative w-full md:w-56">
              <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
              <input
                type="text"
                placeholder="Search history orders..."
                value={orderSearchQuery}
                onChange={(e) => setOrderSearchQuery(e.target.value)}
                className="pl-9 pr-4 py-1.5 w-full text-[10px] rounded-xl border border-border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
          </div>

          {/* Store Type & Fulfillment Method Filter Pills */}
          <div className="flex flex-wrap items-center justify-between gap-2.5 mb-4 p-2 bg-muted/20 border border-border/40 rounded-2xl">
            {/* Store Category Pills */}
            <div className="flex items-center gap-1 flex-wrap">
              <span className="text-[10px] font-black uppercase text-text-muted px-1">Category:</span>
              {[
                { key: 'ALL', label: '🏪 All Stores' },
                { key: 'GROCERY', label: '🛒 Grocery' },
                { key: 'CAFE', label: '☕ Cafe' },
                { key: 'RESTAURANT', label: '🍽️ Restaurant' },
              ].map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => setOrderShopFilter(s.key as any)}
                  className={`px-2.5 py-1 text-[9.5px] font-black rounded-lg transition-all cursor-pointer border ${
                    orderShopFilter === s.key
                      ? 'bg-primary text-white border-primary shadow-2xs'
                      : 'bg-card border-border hover:bg-muted text-text-secondary'
                  }`}
                >
                  {s.label}
                </button>
              ))}
            </div>

            {/* Fulfillment Method Pills */}
            <div className="flex items-center gap-1 flex-wrap">
              <span className="text-[10px] font-black uppercase text-text-muted px-1">Type:</span>
              {[
                { key: 'ALL', label: '📦 All Types' },
                { key: 'DELIVERY', label: '🛵 Delivery' },
                { key: 'SELF_PICKUP', label: '🛍️ Self Pickup' },
              ].map((m) => (
                <button
                  key={m.key}
                  type="button"
                  onClick={() => setOrderMethodFilter(m.key as any)}
                  className={`px-2.5 py-1 text-[9.5px] font-black rounded-lg transition-all cursor-pointer border ${
                    orderMethodFilter === m.key
                      ? 'bg-purple-600 text-white border-purple-600 shadow-2xs'
                      : 'bg-card border-border hover:bg-muted text-text-secondary'
                  }`}
                >
                  {m.label}
                </button>
              ))}
            </div>
          </div>

          {/* History Orders Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-extrabold text-[10px]">
                  <th className="py-2.5 px-3">Order ID &amp; Store</th>
                  <th className="py-2.5 px-3">Type</th>
                  <th className="py-2.5 px-3">Customer</th>
                  <th className="py-2.5 px-3">Address</th>
                  <th className="py-2.5 px-3">Total</th>
                  <th className="py-2.5 px-3 text-center">Status</th>
                  <th className="py-2.5 px-3 text-center">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/40 font-semibold text-xs opacity-90">
                {filteredHistoryOrders.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="text-center py-6 text-text-secondary text-[11px] font-bold">
                      No history orders in this status.
                    </td>
                  </tr>
                ) : (
                  filteredHistoryOrders.map((o) => {
                    const isPickup = isOrderPickup(o)
                    const storeType = getOrderStoreType(o)

                    return (
                      <tr key={o.id} className="hover:bg-muted/30 transition-colors">
                        <td 
                          className="py-3 px-3 cursor-pointer group/cell"
                          onClick={() => onOpenOrderModal(o)}
                          title="Click to view full order items & details"
                        >
                          <span className="font-mono font-bold text-[10px] text-text-primary group-hover/cell:text-primary transition-colors underline decoration-dotted">
                            #{o.readableId || o.id.slice(0, 8)}
                          </span>
                          <div className="mt-1 flex items-center gap-1">
                            {(() => {
                              const displayName = ((o as any).restaurantName || o.shopName || '').trim()
                              const isGenericGrocery = !displayName || displayName === 'FastKirana Grocery' || displayName === 'Grocery Mart'

                              if (storeType === 'CAFE') {
                                return (
                                  <span className="px-1.5 py-0.5 rounded-md bg-amber-500/15 text-amber-700 dark:text-amber-300 font-black text-[9px] border border-amber-500/30 truncate max-w-[140px]" title={displayName || 'Cafe'}>
                                    ☕ {isGenericGrocery ? 'CAFE' : displayName.toUpperCase()}
                                  </span>
                                )
                              }
                              if (storeType === 'RESTAURANT') {
                                return (
                                  <span className="px-1.5 py-0.5 rounded-md bg-rose-500/15 text-rose-700 dark:text-rose-300 font-black text-[9px] border border-rose-500/30 truncate max-w-[140px]" title={displayName || 'Restaurant'}>
                                    🥘 {isGenericGrocery ? 'RESTAURANT' : displayName.toUpperCase()}
                                  </span>
                                )
                              }
                              return (
                                <span className="px-1.5 py-0.5 rounded-md bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 font-black text-[9px] border border-emerald-500/30">
                                  🛒 GROCERY
                                </span>
                              )
                            })()}
                          </div>
                          <div className="text-[9px] text-text-muted font-mono mt-0.5" title={o.id}>
                            ID: {o.id.slice(0, 10)}...
                          </div>
                        </td>

                        <td className="py-3 px-3 whitespace-nowrap">
                          {isPickup ? (
                            <span className="px-2 py-0.5 rounded-full bg-purple-600 text-white font-black text-[9.5px] shadow-xs">
                              🛍️ SELF PICKUP
                            </span>
                          ) : (
                            <span className="px-2 py-0.5 rounded-md bg-sky-500/15 text-sky-700 dark:text-sky-300 border border-sky-500/30 font-extrabold text-[9px]">
                              🛵 DELIVERY
                            </span>
                          )}
                        </td>

                        <td 
                          className="py-3 px-3 cursor-pointer group/cell"
                          onClick={() => onOpenOrderModal(o)}
                          title="Click to view full order items & details"
                        >
                          <div className="font-bold group-hover/cell:text-primary transition-colors">{o.userName || 'No Name'}</div>
                          <div className="text-[10px] text-text-muted font-normal">{o.userEmail}</div>
                        </td>
                        <td className="py-3 px-3 text-[11px]">
                          {isPickup ? (
                            <div>
                              <div className="font-bold text-[10px] text-purple-600 dark:text-purple-400">
                                🛍️ Customer Store Pickup
                              </div>
                            </div>
                          ) : (
                            <div className="line-clamp-2">{formatAddress(o.address)}</div>
                          )}
                        </td>
                        <td className="py-3 px-3 font-bold text-text-primary whitespace-nowrap">{formatPrice(o.total)}</td>
                        <td className="py-3 px-3 text-center">
                          <span className={`text-[10px] font-black px-2.5 py-1 rounded-full border ${
                            o.status === 'DELIVERED' ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20' : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
                          }`}>
                            {o.status}
                          </span>
                        </td>
                        <td className="py-3 px-3 text-center">
                          <div className="flex items-center justify-center gap-1.5">
                            <button
                              type="button"
                              onClick={() => onOpenOrderModal(o)}
                              className="px-2 py-1 bg-muted hover:bg-muted/80 text-text-primary border border-border text-[9.5px] font-black rounded-lg transition-all cursor-pointer shadow-2xs"
                            >
                              👁️ Details
                            </button>
                            <button
                              type="button"
                              onClick={() => shareKitchenOrder(o)}
                              className="px-2 py-1 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 text-[9.5px] font-black rounded-lg transition-all cursor-pointer shadow-2xs"
                              title="Share products-only WhatsApp slip with Kitchen"
                            >
                              📱 Share
                            </button>
                            <button
                              type="button"
                              onClick={() => printCustomerInvoice(o)}
                              className="px-2 py-1 bg-blue-500/10 hover:bg-blue-500/20 text-blue-600 dark:text-blue-400 border border-blue-500/20 text-[9.5px] font-black rounded-lg transition-all cursor-pointer shadow-2xs"
                            >
                              📄 Invoice
                            </button>
                          </div>
                        </td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
