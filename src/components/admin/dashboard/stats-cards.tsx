'use client'

import React from 'react'
import { ShoppingBag, IndianRupee, TrendingUp, Zap, Store, UtensilsCrossed } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface DashboardStats {
  todaySales?: number
  todayOrdersCount?: number
  netSales?: number
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
      title: "Today's Net Sales",
      value: formatPrice(stats.netSales || stats.todaySales || 0),
      icon: TrendingUp,
      color: 'text-emerald-600 bg-emerald-500/10 border-emerald-500/20',
    },
    {
      title: 'Main Shop Revenue',
      subtitle: 'Kirana Store Sales',
      value: formatPrice(stats.groceryRevenue || 0),
      icon: Store,
      color: 'text-blue-600 bg-blue-500/10 border-blue-500/20',
    },
    {
      title: 'Restaurant Revenue',
      subtitle: 'Food Outlets Sales',
      value: formatPrice(stats.restaurantRevenue || 0),
      icon: UtensilsCrossed,
      color: 'text-purple-600 bg-purple-500/10 border-purple-500/20',
    },
    {
      title: "Today's Orders",
      value: stats.todayOrdersCount ?? stats.orderCount ?? 0,
      icon: ShoppingBag,
      color: 'text-amber-600 bg-amber-500/10 border-amber-500/20',
    },
    {
      title: 'Active Orders',
      value: stats.activeOrderCount || 0,
      icon: Zap,
      color: 'text-orange-600 bg-orange-500/10 border-orange-500/20',
    },
  ]

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3.5 mb-5">
      {cards.map((card, idx) => {
        const Icon = card.icon
        return (
          <div
            key={idx}
            className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between transition-all hover:border-border"
          >
            <div>
              <p className="text-[11px] font-bold text-text-secondary">{card.title}</p>
              <h3 className="text-base sm:text-lg lg:text-xl font-black text-text-primary mt-1">{card.value}</h3>
              {card.subtitle && (
                <p className="text-[10px] text-text-secondary/80 font-medium">{card.subtitle}</p>
              )}
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
