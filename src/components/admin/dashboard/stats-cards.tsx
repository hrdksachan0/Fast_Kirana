'use client'

import React from 'react'
import { ShoppingBag, IndianRupee, TrendingUp, Zap, Sparkles, ArrowUpRight } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface DashboardStats {
  todaySales?: number
  todayOrdersCount?: number
  netSales?: number
  todayDeliveryFee?: number
  todayPackagingFee?: number
  revenue?: number
  groceryRevenue?: number
  restaurantRevenue?: number
  orderCount?: number
  activeOrderCount?: number
  lowStockCount?: number
  userCount?: number
}

export interface DashboardStatsCardsProps {
  stats: DashboardStats
}

export function DashboardStatsCards({ stats }: DashboardStatsCardsProps) {
  const hasFeeBreakdown = (stats.todayDeliveryFee || 0) > 0 || (stats.todayPackagingFee || 0) > 0

  const cards = [
    {
      title: "Today's Gross Sales",
      value: formatPrice(stats.todaySales || 0),
      subtitle: hasFeeBreakdown 
        ? `₹${Math.round(stats.todayDeliveryFee || 0)} delivery • ₹${Math.round(stats.todayPackagingFee || 0)} packing`
        : 'Total gross order value today',
      icon: IndianRupee,
      glow: 'from-emerald-500/20 via-emerald-500/5 to-transparent',
      borderColor: 'border-emerald-500/30 hover:border-emerald-500/60',
      iconBg: 'text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border-emerald-500/20',
      tag: 'Gross Sales',
    },
    {
      title: "Today's Net Realized",
      value: formatPrice(stats.netSales || 0),
      subtitle: 'Delivered net of returns/refunds',
      icon: TrendingUp,
      glow: 'from-teal-500/20 via-teal-500/5 to-transparent',
      borderColor: 'border-teal-500/30 hover:border-teal-500/60',
      iconBg: 'text-teal-600 dark:text-teal-400 bg-teal-500/10 border-teal-500/20',
      tag: 'Delivered',
    },
    {
      title: "Today's Orders",
      value: stats.todayOrdersCount ?? stats.orderCount ?? 0,
      subtitle: `${stats.orderCount || 0} lifetime orders logged`,
      icon: ShoppingBag,
      glow: 'from-blue-500/20 via-blue-500/5 to-transparent',
      borderColor: 'border-blue-500/30 hover:border-blue-500/60',
      iconBg: 'text-blue-600 dark:text-blue-400 bg-blue-500/10 border-blue-500/20',
      tag: 'Total Orders',
    },
    {
      title: 'Active Live Queue',
      value: stats.activeOrderCount || 0,
      subtitle: 'Kitchen + Pickers + Riders on way',
      icon: Zap,
      glow: 'from-orange-500/20 via-orange-500/5 to-transparent',
      borderColor: 'border-orange-500/30 hover:border-orange-500/60',
      iconBg: 'text-orange-600 dark:text-orange-400 bg-orange-500/10 border-orange-500/20',
      tag: (stats.activeOrderCount || 0) > 0 ? 'Live Processing' : 'Queue Clear',
      isPulse: (stats.activeOrderCount || 0) > 0,
    },
  ]

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5 mb-5">
      {cards.map((card, idx) => {
        const Icon = card.icon
        return (
          <div
            key={idx}
            className={`group relative overflow-hidden rounded-3xl bg-card border ${card.borderColor} p-4 sm:p-5 shadow-sm hover:shadow-md transition-all duration-300 flex flex-col justify-between`}
          >
            {/* Ambient background glow on hover */}
            <div className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${card.glow} opacity-40 group-hover:opacity-100 transition-opacity duration-500`} />

            {/* Top row: Label & Icon */}
            <div className="flex items-center justify-between relative z-10 mb-2">
              <span className="text-[11px] font-black uppercase tracking-wider text-text-secondary truncate">
                {card.title}
              </span>
              <div className={`h-9 w-9 shrink-0 rounded-2xl border flex items-center justify-center shadow-2xs ${card.iconBg}`}>
                <Icon className="h-4.5 w-4.5" />
              </div>
            </div>

            {/* Middle: Big Metric Value */}
            <div className="relative z-10 my-1">
              <h3 className="text-xl sm:text-2xl font-black text-text-primary tracking-tight truncate">
                {card.value}
              </h3>
            </div>

            {/* Bottom row: Subtitle & Tag */}
            <div className="flex items-center justify-between relative z-10 mt-1 pt-2 border-t border-border/40">
              <p className="text-[10px] font-bold text-text-secondary truncate mr-1">
                {card.subtitle}
              </p>
              {card.isPulse ? (
                <span className="inline-flex items-center gap-1 text-[9px] font-black uppercase tracking-wider text-orange-600 bg-orange-500/10 border border-orange-500/30 px-1.5 py-0.5 rounded-md shrink-0">
                  <span className="w-1.5 h-1.5 rounded-full bg-orange-500 animate-ping" />
                  {card.tag}
                </span>
              ) : (
                <span className="text-[9px] font-black uppercase tracking-wider text-text-secondary bg-muted/60 px-1.5 py-0.5 rounded-md shrink-0">
                  {card.tag}
                </span>
              )}
            </div>
          </div>
        )
      })}
    </div>
  )
}

