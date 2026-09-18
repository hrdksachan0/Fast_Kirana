'use client'

import React from 'react'
import { ShoppingBag, IndianRupee, TrendingUp, Zap } from 'lucide-react'
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
  const cards = [
    {
      label: 'Gross',
      value: formatPrice(stats.todaySales || 0),
      sub: `₹${Math.round(stats.todayDeliveryFee || 0)} del · ₹${Math.round(stats.todayPackagingFee || 0)} pack`,
      icon: IndianRupee,
      color: 'text-emerald-600 dark:text-emerald-400',
      bg: 'bg-emerald-500/10 border-emerald-500/20',
      border: 'border-emerald-500/30',
    },
    {
      label: 'Net',
      value: formatPrice(stats.netSales || 0),
      sub: 'Delivered',
      icon: TrendingUp,
      color: 'text-teal-600 dark:text-teal-400',
      bg: 'bg-teal-500/10 border-teal-500/20',
      border: 'border-teal-500/30',
    },
    {
      label: 'Orders',
      value: String(stats.todayOrdersCount ?? stats.orderCount ?? 0),
      sub: `${stats.orderCount || 0} total`,
      icon: ShoppingBag,
      color: 'text-blue-600 dark:text-blue-400',
      bg: 'bg-blue-500/10 border-blue-500/20',
      border: 'border-blue-500/30',
    },
    {
      label: 'Live',
      value: String(stats.activeOrderCount || 0),
      sub: (stats.activeOrderCount || 0) > 0 ? '● Processing' : 'Queue clear',
      icon: Zap,
      color: 'text-orange-600 dark:text-orange-400',
      bg: 'bg-orange-500/10 border-orange-500/20',
      border: 'border-orange-500/30',
      pulse: (stats.activeOrderCount || 0) > 0,
    },
  ]

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-3.5 mb-5">
      {cards.map((card, idx) => {
        const Icon = card.icon
        return (
          <div
            key={idx}
            className={`relative rounded-2xl sm:rounded-3xl bg-card border ${card.border} p-3 sm:p-5 shadow-sm`}
          >
            {/* Top: icon + label */}
            <div className="flex items-center gap-1.5 mb-1.5">
              <div className={`h-7 w-7 sm:h-9 sm:w-9 shrink-0 rounded-xl sm:rounded-2xl border flex items-center justify-center ${card.bg}`}>
                <Icon className={`h-3.5 w-3.5 sm:h-4.5 sm:w-4.5 ${card.color}`} />
              </div>
              <span className="text-[10px] sm:text-[11px] font-black uppercase tracking-wider text-text-secondary">
                {card.label}
              </span>
            </div>

            {/* Value */}
            <h3 className="text-lg sm:text-2xl font-black text-text-primary tracking-tight">
              {card.value}
            </h3>

            {/* Subtitle */}
            <p className={`text-[9px] sm:text-[10px] font-bold mt-0.5 ${card.pulse ? 'text-orange-600 dark:text-orange-400' : 'text-text-secondary'}`}>
              {card.pulse && <span className="inline-block w-1.5 h-1.5 rounded-full bg-orange-500 animate-ping mr-1 align-middle" />}
              {card.sub}
            </p>
          </div>
        )
      })}
    </div>
  )
}
