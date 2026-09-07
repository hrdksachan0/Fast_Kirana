'use client'

import { motion } from 'framer-motion'
import { AlertCircle, Volume2, VolumeX, ShoppingBag, Utensils, Clock, Eye } from 'lucide-react'

interface DelayedOrder {
  id: string
  readableId?: string
  status: string
  restaurantId?: string | null
  orderType?: string
  createdAt: string | Date
  updatedAt?: string | Date
  userName?: string
  userEmail?: string
}

interface BottleneckBannerProps {
  delayedOrders: DelayedOrder[]
  pickerDelays: DelayedOrder[]
  chefDelays: DelayedOrder[]
  riderDelays: DelayedOrder[]
  livePendingOrders: any[]
  isChimeMuted: boolean
  onToggleChime: () => void
  onInspectOrder: (orderId: string) => void
}

export function BottleneckBanner({
  delayedOrders,
  pickerDelays,
  chefDelays,
  riderDelays,
  livePendingOrders,
  isChimeMuted,
  onToggleChime,
  onInspectOrder,
}: BottleneckBannerProps) {
  if (delayedOrders.length === 0) return null

  return (
    <motion.div
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      className="relative overflow-hidden rounded-2xl border border-rose-500/20 bg-gradient-to-r from-rose-500/10 via-amber-500/5 to-rose-500/10 p-5 shadow-lg backdrop-blur-md animate-glow-pulse"
    >
      <div className="absolute right-0 top-0 -mr-6 -mt-6 h-24 w-24 rounded-full bg-rose-500/10 blur-xl animate-pulse" />

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-start gap-3.5">
          <div className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-rose-500/10 text-rose-500">
            <AlertCircle className="h-5 w-5 animate-bounce-subtle" />
            <span className="absolute -right-0.5 -top-0.5 flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-rose-500"></span>
            </span>
          </div>
          <div>
            <h3 className="text-sm font-black text-rose-500 flex items-center gap-2">
              Operational Bottlenecks Detected
              <span className="rounded-full bg-rose-500/10 px-2.5 py-0.5 text-xs font-bold text-rose-600">
                {delayedOrders.length} {delayedOrders.length === 1 ? 'order' : 'orders'} delayed
              </span>
            </h3>
            <p className="text-xs text-text-secondary mt-0.5 max-w-2xl font-medium">
              The following orders have exceeded the queue limit. Please coordinate with staff immediately to prevent service level degradation.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-end md:self-center">
          <button
            onClick={onToggleChime}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-bold transition-all ${
              isChimeMuted
                ? 'bg-muted/80 border-border/80 text-text-secondary hover:text-text-primary hover:bg-muted'
                : 'bg-rose-500/10 border-rose-500/30 text-rose-600 hover:bg-rose-500/20'
            }`}
          >
            {isChimeMuted ? (
              <>
                <VolumeX className="h-3.5 w-3.5" />
                <span>Muted</span>
              </>
            ) : (
              <>
                <Volume2 className="h-3.5 w-3.5 animate-pulse" />
                <span>Alert Active</span>
              </>
            )}
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2 mt-4">
        {pickerDelays.length > 0 && (
          <div className="flex items-center gap-1.5 rounded-lg bg-amber-500/10 border border-amber-500/20 px-2.5 py-1 text-xs font-semibold text-amber-600">
            <ShoppingBag className="h-3.5 w-3.5" />
            <span>Grocery Picker Delay: {pickerDelays.length}</span>
          </div>
        )}
        {chefDelays.length > 0 && (
          <div className="flex items-center gap-1.5 rounded-lg bg-orange-500/10 border border-orange-500/20 px-2.5 py-1 text-xs font-semibold text-orange-600">
            <Utensils className="h-3.5 w-3.5" />
            <span>Cafe Chef Delay: {chefDelays.length}</span>
          </div>
        )}
        {riderDelays.length > 0 && (
          <div className="flex items-center gap-1.5 rounded-lg bg-rose-500/10 border border-rose-500/20 px-2.5 py-1 text-xs font-semibold text-rose-600">
            <Clock className="h-3.5 w-3.5" />
            <span>Rider Dispatch Delay: {riderDelays.length}</span>
          </div>
        )}
      </div>

      <div className="mt-4 border-t border-rose-500/10 pt-3">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2 max-h-48 overflow-y-auto pr-1 scrollbar-none">
          {delayedOrders.map((order) => {
            const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
            const isPacked = order.status === 'PACKED'
            const baseTime = order.status === 'PENDING' ? order.createdAt : (order.updatedAt || order.createdAt)
            const delayMin = Math.floor((new Date().getTime() - new Date(baseTime).getTime()) / 60000)

            let delayType = 'Grocery Picker'
            let delayColor = 'border-amber-500/20 bg-amber-500/5 text-amber-700 dark:text-amber-400'
            if (isPacked) {
              delayType = 'Rider Delivery'
              delayColor = 'border-rose-500/20 bg-rose-500/5 text-rose-700 dark:text-rose-400'
            } else if (isRestaurant) {
              delayType = 'Kitchen Chef'
              delayColor = 'border-orange-500/20 bg-orange-500/5 text-orange-700 dark:text-orange-400'
            }

            const pendingIdx = livePendingOrders.findIndex((po) => po.id === order.id)
            const fifoRank = pendingIdx !== -1 ? pendingIdx + 1 : null

            return (
              <div
                key={order.id}
                className={`flex items-center justify-between rounded-xl border p-2.5 text-xs font-medium ${delayColor}`}
              >
                <div className="flex flex-col gap-0.5">
                  <span className="font-bold flex items-center gap-1.5">
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
                  </span>
                  <span className="text-[10px] opacity-80">
                    {delayType} • {order.userName || order.userEmail || 'Guest'}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="rounded bg-black/5 px-1.5 py-0.5 text-[10px] font-black">
                    {delayMin}m delay
                  </span>
                  <button
                    onClick={() => onInspectOrder(order.id)}
                    className="rounded-lg bg-card p-1 text-text-primary shadow-sm hover:bg-muted transition-colors border border-border/40"
                    title="View order"
                  >
                    <Eye className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </motion.div>
  )
}
