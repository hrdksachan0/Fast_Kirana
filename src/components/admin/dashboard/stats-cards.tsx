'use client'

import React from 'react'
import { ShoppingBag, DollarSign, TrendingUp, Zap } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface DashboardStats {
  todaySales?: number
  netSales?: number
  revenue?: number
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
      title: "Today's Sales",
      value: formatPrice(stats.todaySales || 0),
      icon: DollarSign,
      color: 'text-emerald-600 bg-emerald-500/10 border-emerald-500/20',
    },
    {
      title: 'Net Sales',
      value: formatPrice(stats.netSales ?? stats.revenue ?? 0),
      icon: TrendingUp,
      color: 'text-teal-600 bg-teal-500/10 border-teal-500/20',
    },
    {
      title: 'Total Orders',
      value: stats.orderCount || 0,
      icon: ShoppingBag,
      color: 'text-blue-600 bg-blue-500/10 border-blue-500/20',
    },
    {
      title: 'Active Orders',
      value: stats.activeOrderCount || 0,
      icon: Zap,
      color: 'text-orange-600 bg-orange-500/10 border-orange-500/20',
    },
  ]

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5 mb-5">
      {cards.map((card, idx) => {
        const Icon = card.icon
        return (
          <div
            key={idx}
            className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between"
          >
            <div>
              <p className="text-[11px] font-bold text-text-secondary">{card.title}</p>
              <h3 className="text-lg sm:text-xl font-black text-text-primary mt-1">{card.value}</h3>
            </div>
            <div className={`h-10 w-10 shrink-0 rounded-xl border flex items-center justify-center ${card.color}`}>
              <Icon className="h-5 w-5" />
            </div>
          </div>
        )
      })}
    </div>
  )
}
