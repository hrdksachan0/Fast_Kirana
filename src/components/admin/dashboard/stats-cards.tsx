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
  const hasFeeBreakdown = (stats.todayDeliveryFee || 0) > 0 || (stats.todayPackagingFee || 0) > 0

  const cards = [
    {
      title: "Today's Sales",
      value: formatPrice(stats.todaySales || 0),
      subtitle: hasFeeBreakdown 
        ? `Incl. ₹${Math.round(stats.todayDeliveryFee || 0)} del + ₹${Math.round(stats.todayPackagingFee || 0)} pack`
        : 'Gross order value placed today',
      icon: IndianRupee,
      color: 'text-emerald-600 bg-emerald-500/10 border-emerald-500/20',
    },
    {
      title: "Today's Net Sales",
      value: formatPrice(stats.netSales || 0),
      subtitle: 'Delivered net of refunds',
      icon: TrendingUp,
      color: 'text-teal-600 bg-teal-500/10 border-teal-500/20',
    },
    {
      title: "Today's Orders",
      value: stats.todayOrdersCount ?? stats.orderCount ?? 0,
      subtitle: 'Placed orders today',
      icon: ShoppingBag,
      color: 'text-blue-600 bg-blue-500/10 border-blue-500/20',
    },
    {
      title: 'Active Orders',
      value: stats.activeOrderCount || 0,
      subtitle: 'Live kitchen & delivery queue',
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
            <div className="min-w-0 flex-1 mr-2">
              <p className="text-[11px] font-bold text-text-secondary truncate">{card.title}</p>
              <h3 className="text-lg sm:text-xl font-black text-text-primary mt-0.5 truncate">{card.value}</h3>
              {card.subtitle && (
                <p className="text-[9.5px] font-semibold text-text-muted mt-0.5 truncate">
                  {card.subtitle}
                </p>
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
