'use client'

import { motion } from 'framer-motion'
import { Clock } from 'lucide-react'
import { formatPrice, formatAddress } from '@/lib/utils'
import { formatOrderTime } from '@/lib/date-helpers'

interface DeliveryHistoryViewProps {
  todayDeliveries: number
  deliveredOrders: any[]
}

export default function DeliveryHistoryView({
  todayDeliveries,
  deliveredOrders,
}: DeliveryHistoryViewProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-4 pt-1"
    >
      {/* Rider Achievements Milestone Widget */}
      <div className="bg-gradient-to-br from-slate-900 to-slate-950 text-white border border-slate-800 rounded-3xl p-4 shadow-lg relative overflow-hidden">
        <div className="flex justify-between items-center pb-3 border-b border-slate-800/80">
          <div>
            <span className="text-[9px] font-black uppercase tracking-wider text-slate-400">Daily Milestone Goal</span>
            <div className="flex items-baseline gap-1 mt-0.5">
              <span className="text-xl font-black text-emerald-400">{todayDeliveries}</span>
              <span className="text-[10px] text-slate-400 font-bold">completed today</span>
            </div>
          </div>
          <div className="text-right">
            <span className="text-[9px] font-black uppercase tracking-wider text-slate-400">Target Bonus</span>
            <p className="text-xs font-bold text-emerald-400 mt-0.5">
              {todayDeliveries}/5 Deliveries
            </p>
          </div>
        </div>

        <div className="pt-3 space-y-2">
          <div className="h-2 rounded-full bg-slate-800 overflow-hidden">
            <div
              className="h-full rounded-full bg-gradient-to-r from-emerald-500 to-teal-400 transition-all duration-500"
              style={{ width: `${Math.min((todayDeliveries / 5) * 100, 100)}%` }}
            />
          </div>
          <p className="text-[9px] font-bold text-slate-400">
            {todayDeliveries >= 5 ? (
              <span className="text-emerald-400 flex items-center gap-1">🎉 Milestone bonus target achieved today!</span>
            ) : (
              `Complete ${5 - todayDeliveries} more deliveries to reach your daily milestone bonus!`
            )}
          </p>
        </div>
      </div>

      <div className="flex items-center justify-between pb-2 border-b border-border/40">
        <div className="flex items-center gap-2">
          <div className="h-6 w-6 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
            <Clock className="h-3.5 w-3.5" />
          </div>
          <h2 className="text-xs font-black text-text-primary uppercase tracking-wider">
            Delivered Orders ({deliveredOrders.length})
          </h2>
        </div>
        <span className="text-[10px] font-bold text-text-muted">Today's History</span>
      </div>

      {deliveredOrders.length === 0 ? (
        <div className="bg-card/50 border border-dashed border-border/80 p-8 rounded-2xl text-center text-xs text-text-muted">
          No completed deliveries recorded today yet.
        </div>
      ) : (
        deliveredOrders.map((order) => (
          <div
            key={order.id}
            className="bg-card border border-border/70 p-4 rounded-2xl shadow-xs space-y-2.5"
          >
            <div className="flex justify-between items-center border-b border-border/30 pb-2">
              <div>
                <span className="text-xs font-mono font-black text-text-primary block">
                  #{order.readableId || order.id.slice(0, 8)}
                </span>
                <span className="text-[9px] text-text-muted font-semibold">
                  Delivered: {formatOrderTime(order.deliveredAt || order.updatedAt || order.createdAt)}
                </span>
              </div>
              <span className="px-2.5 py-1 rounded-lg text-[9px] font-black uppercase tracking-wider bg-emerald-500/10 text-emerald-600 border border-emerald-500/20">
                ✅ Delivered
              </span>
            </div>

            <div className="flex justify-between items-center text-xs">
              <div>
                <span className="text-text-primary font-bold block">{order.user?.name || 'Customer'}</span>
                <span className="text-[10px] text-text-secondary font-semibold">{formatAddress(order.address, false)}</span>
              </div>
              <div className="text-right shrink-0">
                <span className="text-sm font-black text-text-primary block">{formatPrice(order.total)}</span>
                <span className="text-[8px] font-bold text-text-muted uppercase">
                  {order.paymentMethod === 'COD' ? '💰 COD' : '💳 Online'}
                </span>
              </div>
            </div>
          </div>
        ))
      )}
    </motion.div>
  )
}
