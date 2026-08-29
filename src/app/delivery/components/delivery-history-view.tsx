'use client'

import { motion } from 'framer-motion'
import { Clock, Trophy, Flame } from 'lucide-react'
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
  const target = 5
  const progress = Math.min((todayDeliveries / target) * 100, 100)
  const radius = 32
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (progress / 100) * circumference

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-4 pt-1 pb-6"
    >
      {/* Rider Achievements Milestone Widget */}
      <div className="bg-card text-text-primary rounded-3xl p-4 sm:p-5 relative overflow-hidden shadow-md border border-border">
        {/* Subtle decorative glow */}
        <div className="absolute -top-10 -right-10 w-36 h-36 bg-emerald-500/10 rounded-full blur-2xl pointer-events-none" />
        
        <div className="relative flex items-center gap-4">
          {/* Ring Progress */}
          <div className="relative w-18 h-18 shrink-0 flex items-center justify-center">
            <svg className="w-full h-full transform -rotate-90">
              <circle
                cx="36"
                cy="36"
                r="30"
                fill="transparent"
                stroke="currentColor"
                className="text-muted"
                strokeWidth="6"
              />
              <circle
                cx="36"
                cy="36"
                r="30"
                fill="transparent"
                stroke="#10b981"
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={2 * Math.PI * 30}
                strokeDashoffset={2 * Math.PI * 30 - (progress / 100) * (2 * Math.PI * 30)}
                className="transition-all duration-1000 ease-out"
              />
            </svg>
            <div className="absolute inset-0 flex items-center justify-center flex-col">
              <span className="text-xl font-black text-text-primary leading-none">{todayDeliveries}</span>
              <span className="text-[8px] font-bold text-text-muted">/ {target}</span>
            </div>
          </div>

          {/* Text content */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-[10px] font-black uppercase tracking-wider text-text-muted">
                Daily Goal
              </span>
              {todayDeliveries >= 3 && todayDeliveries < target && (
                <span className="bg-orange-500/15 text-orange-600 dark:text-orange-400 border border-orange-500/30 text-[9px] font-black px-2 py-0.5 rounded-full flex items-center gap-1">
                  <Flame className="h-2.5 w-2.5" />
                  <span>Streak!</span>
                </span>
              )}
            </div>
            
            {todayDeliveries >= target ? (
              <div className="space-y-0.5">
                <p className="text-xs font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                  <Trophy className="h-3.5 w-3.5" />
                  <span>Milestone Bonus Achieved!</span>
                </p>
                <p className="text-[11px] text-text-secondary font-medium">Great hustle today! 🎉</p>
              </div>
            ) : (
              <div className="space-y-0.5">
                <p className="text-xs font-black text-text-primary">
                  {target - todayDeliveries} more to reach daily bonus
                </p>
                <p className="text-[10px] text-text-secondary font-medium">Keep delivering, you're almost there!</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Section header */}
      <div className="flex items-center justify-between px-1">
        <h2 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-2">
          Today's Completed Deliveries
          <span className="bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 px-2 py-0.5 rounded-full text-[10px] font-black border border-emerald-500/25">
            {deliveredOrders.length}
          </span>
        </h2>
      </div>

      {/* Order Timeline List */}
      {deliveredOrders.length === 0 ? (
        <div className="bg-card/50 border border-border border-dashed p-8 rounded-3xl text-center flex flex-col items-center justify-center gap-2 mt-2">
          <div className="text-3xl">📦</div>
          <p className="text-xs font-bold text-text-primary">No deliveries yet today</p>
          <p className="text-[11px] text-text-muted">Completed orders will appear here on your timeline.</p>
        </div>
      ) : (
        <div className="relative pl-6 mt-3 space-y-3">
          {/* Vertical timeline line */}
          <div className="absolute left-[9px] top-4 bottom-4 w-[2px] bg-gradient-to-b from-emerald-500 via-emerald-400 to-teal-500/20 rounded-full" />
          
          {deliveredOrders.map((order, i) => (
            <motion.div
              key={order.id}
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ 
                delay: i * 0.05,
                type: "spring",
                stiffness: 280,
                damping: 24
              }}
              className="relative"
            >
              {/* Timeline dot */}
              <div className="absolute -left-[20px] top-5 -translate-y-1/2 h-2.5 w-2.5 rounded-full bg-emerald-500 ring-4 ring-emerald-500/20 z-10" />
              
              <div className="bg-card border border-border p-3.5 rounded-2xl shadow-xs space-y-2">
                <div className="flex justify-between items-start">
                  <div className="space-y-0.5">
                    <span className="text-xs font-mono font-black text-text-primary block">
                      #{order.readableId || order.id.slice(0, 8)}
                    </span>
                    <span className="text-[10px] text-text-muted font-bold flex items-center gap-1">
                      <Clock className="w-3 h-3 text-emerald-500" />
                      {formatOrderTime(order.deliveredAt || order.updatedAt || order.createdAt)}
                    </span>
                  </div>

                  <div className="text-right">
                    <span className="text-xs font-black text-text-primary block">
                      {formatPrice(order.total)}
                    </span>
                    <span className="text-[9px] font-black uppercase text-emerald-700 dark:text-emerald-300 bg-emerald-500/10 px-1.5 py-0.2 rounded border border-emerald-500/20">
                      {order.paymentMethod === 'COD' ? '💵 COD' : '✅ Online'}
                    </span>
                  </div>
                </div>

                <div className="pt-2 border-t border-border/40 flex justify-between items-center text-xs">
                  <div className="truncate pr-2">
                    <span className="font-bold text-text-primary block truncate">
                      {order.user?.name || 'Customer'}
                    </span>
                    <span className="text-[10px] text-text-secondary truncate block">
                      {formatAddress(order.address, false)}
                    </span>
                  </div>
                  <span className="text-[10px] font-black text-emerald-600 bg-emerald-500/10 px-2 py-0.5 rounded-lg shrink-0">
                    Delivered ✅
                  </span>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      )}
    </motion.div>
  )
}
