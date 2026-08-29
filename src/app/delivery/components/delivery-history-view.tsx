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
  const target = 5
  const progress = Math.min((todayDeliveries / target) * 100, 100)
  const radius = 34
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (progress / 100) * circumference

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-5 pt-1 pb-6"
    >
      {/* Rider Achievements Milestone Widget */}
      <div className="bg-slate-950 text-white rounded-3xl p-5 relative overflow-hidden shadow-xl border border-slate-900">
        <div className="absolute -top-10 -right-10 w-40 h-40 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />
        
        <div className="relative flex items-center gap-5">
          {/* Ring Progress */}
          <div className="relative w-20 h-20 shrink-0">
            <svg className="w-full h-full transform -rotate-90">
              <circle
                cx="40"
                cy="40"
                r="34"
                fill="transparent"
                stroke="currentColor"
                className="text-white/[0.06]"
                strokeWidth="6"
              />
              <circle
                cx="40"
                cy="40"
                r="34"
                fill="transparent"
                stroke="url(#emerald-gradient)"
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={circumference}
                strokeDashoffset={strokeDashoffset}
                className="transition-all duration-1000 ease-out"
              />
              <defs>
                <linearGradient id="emerald-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#10b981" />
                  <stop offset="100%" stopColor="#34d399" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex items-center justify-center flex-col">
              <span className="text-2xl font-black text-white leading-none">{todayDeliveries}</span>
            </div>
          </div>

          {/* Text content */}
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-[10px] font-black uppercase tracking-wider text-slate-400">Daily Goal</span>
              {todayDeliveries >= 3 && todayDeliveries < target && (
                <span className="bg-orange-500/20 text-orange-400 border border-orange-500/30 text-[9px] font-bold px-2 py-0.5 rounded-full">
                  🔥 Streak!
                </span>
              )}
            </div>
            
            {todayDeliveries >= target ? (
              <div className="space-y-1">
                <p className="text-sm font-bold text-emerald-400">Target Achieved!</p>
                <div className="text-xl">🎉 🎊 🏆</div>
              </div>
            ) : (
              <div className="space-y-1">
                <p className="text-xs font-bold text-white/90">
                  {target - todayDeliveries} more to reach bonus
                </p>
                <p className="text-[10px] text-slate-400 font-semibold">Keep pushing, you're doing great!</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Section header */}
      <div className="flex items-center justify-between px-1">
        <h2 className="text-sm font-black text-text-primary flex items-center gap-2">
          Today's Deliveries
          <span className="bg-emerald-500/10 text-emerald-600 px-2 py-0.5 rounded-full text-[10px] font-bold border border-emerald-500/20">
            {deliveredOrders.length}
          </span>
        </h2>
      </div>

      {/* Order Timeline List */}
      {deliveredOrders.length === 0 ? (
        <div className="bg-card/50 border border-border border-dashed p-8 rounded-3xl text-center flex flex-col items-center justify-center gap-3 mt-4">
          <div className="text-4xl">📦</div>
          <div>
            <p className="text-sm font-bold text-text-primary">No deliveries yet today</p>
            <p className="text-xs text-text-muted mt-1 font-medium">Your next order will appear here.</p>
          </div>
        </div>
      ) : (
        <div className="relative pl-7 mt-4 pb-4">
          {/* Vertical timeline line */}
          <div className="absolute left-[11px] top-6 bottom-4 w-[2px] bg-gradient-to-b from-emerald-500 to-emerald-500/10 rounded-full" />
          
          <div className="space-y-5">
            {deliveredOrders.map((order, i) => (
              <motion.div
                key={order.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ 
                  delay: i * 0.08,
                  type: "spring",
                  stiffness: 300,
                  damping: 24
                }}
                className="relative"
              >
                {/* Timeline dot */}
                <div className="absolute -left-[30px] top-6 -translate-y-1/2 h-[10px] w-[10px] rounded-full bg-emerald-500 ring-4 ring-emerald-500/20 z-10" />
                
                {/* Connecting line */}
                <div className="absolute -left-[27px] top-6 -translate-y-1/2 h-[2px] w-[27px] bg-emerald-500/20" />
                
                <div className="bg-card border border-border p-4 rounded-3xl shadow-sm hover:shadow-md transition-shadow">
                  <div className="flex justify-between items-start mb-3">
                    <div className="flex flex-col gap-1">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-black text-text-primary">
                          #{order.readableId || order.id.slice(0, 8)}
                        </span>
                        {/* Delivered badge as small green dot */}
                        <div className="h-2 w-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]" />
                      </div>
                      <span className="text-[10px] text-text-muted font-bold flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {formatOrderTime(order.deliveredAt || order.updatedAt || order.createdAt)}
                      </span>
                    </div>

                    <div className="text-right flex flex-col items-end gap-1.5">
                      <span className="text-sm font-black text-text-primary">
                        {formatPrice(order.total)}
                      </span>
                      <span className="text-[9px] font-bold text-text-primary uppercase bg-secondary px-2 py-0.5 rounded-md">
                        {order.paymentMethod === 'COD' ? '💰 COD' : '💳 Online'}
                      </span>
                    </div>
                  </div>

                  <div className="pt-2 border-t border-border/50">
                    <span className="text-xs text-text-primary font-bold block">
                      {order.user?.name || 'Customer'}
                    </span>
                    <span className="text-[10px] text-text-secondary font-medium block truncate mt-0.5">
                      {formatAddress(order.address, false)}
                    </span>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      )}
    </motion.div>
  )
}
