'use client'

import { useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ShoppingBag, Utensils, Clock } from 'lucide-react'
import { toast } from 'sonner'
import { LiveCartsPanel } from '@/components/admin/dashboard/live-carts-panel'
import { parseDateInput } from '@/lib/date-helpers'

interface LiveOpsTabProps {
  liveOrders: any[]
  livePendingOrders: any[]
  delayedOrders: any[]
  activeCarts: any[]
  isLoadingCarts: boolean
  cartsRefreshKey: number
  setCartsRefreshKey: (fn: (prev: number) => number) => void
  sendCartNotification: (userId: string, userName: string) => Promise<void>
  openWhatsAppModal: (userName: string, phone: string) => void
}

export function LiveOpsTab({
  liveOrders,
  livePendingOrders,
  delayedOrders,
  activeCarts,
  isLoadingCarts,
  cartsRefreshKey,
  setCartsRefreshKey,
  sendCartNotification,
  openWhatsAppModal,
}: LiveOpsTabProps) {
  // Calculate average pick time for completed grocery pickings (in minutes)
  const avgPickTime = useMemo(() => {
    const validOrders = (liveOrders || []).filter((o) => {
      if (o.status === 'CANCELLED') return false
      if (o.restaurantId || o.orderType === 'RESTAURANT') return false
      const confirmed = parseDateInput(o.confirmedAt)?.getTime()
      const packed = parseDateInput(o.packedAt)?.getTime()
      return confirmed && packed && packed > confirmed
    })

    if (validOrders.length === 0) return 0
    const totalMinutes = validOrders.reduce((sum, o) => {
      const confirmed = parseDateInput(o.confirmedAt)!.getTime()
      const packed = parseDateInput(o.packedAt)!.getTime()
      return sum + (packed - confirmed) / 60000
    }, 0)
    return Math.max(0, Math.round(totalMinutes / validOrders.length))
  }, [liveOrders])

  // Calculate average prep time for completed cafe/restaurant prep (in minutes)
  const avgPrepTime = useMemo(() => {
    const validOrders = (liveOrders || []).filter((o) => {
      if (o.status === 'CANCELLED') return false
      if (!o.restaurantId && o.orderType !== 'RESTAURANT') return false
      const confirmed = parseDateInput(o.confirmedAt)?.getTime()
      const packed = parseDateInput(o.packedAt)?.getTime()
      return confirmed && packed && packed > confirmed
    })

    if (validOrders.length === 0) return 0
    const totalMinutes = validOrders.reduce((sum, o) => {
      const confirmed = parseDateInput(o.confirmedAt)!.getTime()
      const packed = parseDateInput(o.packedAt)!.getTime()
      return sum + (packed - confirmed) / 60000
    }, 0)
    return Math.max(0, Math.round(totalMinutes / validOrders.length))
  }, [liveOrders])

  // Calculate average delivery transit time (in minutes)
  const avgDeliveryTime = useMemo(() => {
    const validOrders = (liveOrders || []).filter((o) => {
      if (o.status === 'CANCELLED') return false
      const shipped = parseDateInput(o.shippedAt)?.getTime()
      const delivered = parseDateInput(o.deliveredAt)?.getTime()
      return shipped && delivered && delivered > shipped
    })

    if (validOrders.length === 0) return 0
    const totalMinutes = validOrders.reduce((sum, o) => {
      const shipped = parseDateInput(o.shippedAt)!.getTime()
      const delivered = parseDateInput(o.deliveredAt)!.getTime()
      return sum + (delivered - shipped) / 60000
    }, 0)
    return Math.max(0, Math.round(totalMinutes / validOrders.length))
  }, [liveOrders])

  // Consolidate multi-outlet sub-orders sharing combinedId so each combined checkout counts as 1 master order
  const consolidatedLiveOrders = useMemo(() => {
    const seen = new Set<string>()
    return (liveOrders || []).filter((o) => {
      const key = o.combinedId || o.id
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
  }, [liveOrders])

  const pendingCount = consolidatedLiveOrders.filter((o) => o.status === 'PENDING').length
  const confirmedCount = consolidatedLiveOrders.filter((o) => o.status === 'CONFIRMED').length
  const packedCount = consolidatedLiveOrders.filter((o) => o.status === 'PACKED').length
  const shippedCount = consolidatedLiveOrders.filter((o) => o.status === 'SHIPPED').length
  const deliveredCount = consolidatedLiveOrders.filter((o) => o.status === 'DELIVERED').length

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Status Counts */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        {[
          { label: 'Placed (New)', count: pendingCount, color: 'border-blue-500/30 text-blue-600 bg-blue-500/5' },
          { label: 'In Picking/Prep', count: confirmedCount, color: 'border-amber-500/30 text-amber-600 bg-amber-500/5' },
          { label: 'Packed & Ready', count: packedCount, color: 'border-emerald-500/30 text-emerald-600 bg-emerald-500/5' },
          { label: 'Out for Delivery', count: shippedCount, color: 'border-purple-500/30 text-purple-600 bg-purple-500/5' },
          { label: 'Delivered', count: deliveredCount, color: 'border-zinc-500/30 text-zinc-600 bg-zinc-500/5' },
        ].map((stat) => (
          <div
            key={stat.label}
            className={`border rounded-2xl p-4 shadow-sm text-center ${stat.color} bg-card`}
          >
            <span className="text-[10px] font-extrabold uppercase tracking-wider opacity-85 block">
              {stat.label}
            </span>
            <span className="text-xl md:text-2xl font-black mt-1 block">{stat.count}</span>
          </div>
        ))}
      </div>

      {/* Avg Times */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-card border border-border rounded-2xl p-5 shadow-sm space-y-3">
          <div className="flex justify-between items-center">
            <h4 className="font-extrabold text-sm text-text-primary">Avg Picking Speed</h4>
            <ShoppingBag className="h-4 w-4 text-blue-500" />
          </div>
          <div className="flex items-baseline gap-1.5">
            <span className="text-2xl font-black text-text-primary">{avgPickTime || '—'}</span>
            <span className="text-xs font-bold text-text-secondary">minutes</span>
          </div>
          <p className="text-[10px] text-text-secondary font-medium">
            Avg duration between picker confirming order & packing it
          </p>
        </div>

        <div className="bg-card border border-border rounded-2xl p-5 shadow-sm space-y-3">
          <div className="flex justify-between items-center">
            <h4 className="font-extrabold text-sm text-text-primary">Avg Cafe Prep Speed</h4>
            <Utensils className="h-4 w-4 text-orange-500" />
          </div>
          <div className="flex items-baseline gap-1.5">
            <span className="text-2xl font-black text-text-primary">{avgPrepTime || '—'}</span>
            <span className="text-xs font-bold text-text-secondary">minutes</span>
          </div>
          <p className="text-[10px] text-text-secondary font-medium">
            Avg preparation time for cafe food items
          </p>
        </div>

        <div className="bg-card border border-border rounded-2xl p-5 shadow-sm space-y-3">
          <div className="flex justify-between items-center">
            <h4 className="font-extrabold text-sm text-text-primary">Avg Rider Dispatch Time</h4>
            <Clock className="h-4 w-4 text-rose-500" />
          </div>
          <div className="flex items-baseline gap-1.5">
            <span className="text-2xl font-black text-text-primary">{avgDeliveryTime || '—'}</span>
            <span className="text-xs font-bold text-text-secondary">minutes</span>
          </div>
          <p className="text-[10px] text-text-secondary font-medium">
            Avg transit duration from store pickup to customer doorstep
          </p>
        </div>
      </div>

      {/* SLA Alert Stream */}
      <div className="bg-card border border-border rounded-2xl p-5 shadow-sm">
        <h4 className="font-extrabold text-sm text-text-primary mb-3">SLA Alert Stream</h4>
        {delayedOrders.length === 0 ? (
          <p className="text-xs text-text-secondary text-center py-6">
            All orders are running well within their SLA (10m Grocery / 30m Restaurant).
          </p>
        ) : (
          <div className="space-y-2.5 max-h-96 overflow-y-auto pr-1">
            {delayedOrders.map((order) => {
              const baseTime =
                order.status === 'PENDING' ? order.createdAt : order.updatedAt || order.createdAt
              const baseDate = parseDateInput(baseTime) || new Date()
              const delayMin = Math.max(
                0,
                Math.floor((new Date().getTime() - baseDate.getTime()) / 60000)
              )

              const pendingIdx = livePendingOrders.findIndex((po) => po.id === order.id)
              const fifoRank = pendingIdx !== -1 ? pendingIdx + 1 : null

              return (
                <div
                  key={order.id}
                  className="flex justify-between items-center p-3 rounded-xl border border-rose-500/10 bg-rose-500/5 text-xs"
                >
                  <div>
                    <p className="font-bold text-rose-600 flex items-center gap-1.5">
                      Order #{order.readableId || order.id.slice(0, 8)}
                      {fifoRank && (
                        <span
                          className={`text-[8px] font-black px-1.5 py-0.2 rounded-full ${
                            fifoRank === 1
                              ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-500/20'
                              : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800/40 dark:text-zinc-400 border border-border/40'
                          }`}
                        >
                          {fifoRank === 1 ? '👑 FIFO #1' : `FIFO #${fifoRank}`}
                        </span>
                      )}
                    </p>
                    <p className="text-[10px] text-text-secondary mt-0.5 font-medium">
                      Status: <span className="font-bold uppercase">{order.status}</span> • Customer:{' '}
                      {order.userName || order.userEmail}
                    </p>
                  </div>
                  <span className="rounded-full bg-rose-500/10 border border-rose-500/20 px-2.5 py-1 font-black text-rose-700 animate-pulse">
                    {delayMin}m delay
                  </span>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Live Carts Panel */}
      <LiveCartsPanel
        activeCarts={activeCarts}
        isLoadingCarts={isLoadingCarts}
        onRefresh={() => setCartsRefreshKey((prev) => prev + 1)}
        onSendCartNotification={sendCartNotification}
        onOpenWhatsAppModal={openWhatsAppModal}
      />
    </div>
  )
}
