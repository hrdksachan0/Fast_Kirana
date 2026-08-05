'use client'

import React from 'react'
import { ShoppingBag, DollarSign, Package, Users } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface DashboardStats {
  revenue?: number
  orderCount?: number
  lowStockCount?: number
  userCount?: number
}

export interface DashboardStatsCardsProps {
  stats: DashboardStats
}

export function DashboardStatsCards({ stats }: DashboardStatsCardsProps) {
  const cards = [
    {
      title: 'Total Orders',
      value: stats.orderCount || 0,
      icon: ShoppingBag,
      color: 'text-blue-600 bg-blue-500/10 border-blue-500/20',
    },
    {
      title: 'Low Stock Alerts',
      value: stats.lowStockCount || 0,
      icon: Package,
      color: 'text-amber-600 bg-amber-500/10 border-amber-500/20',
    },
    {
      title: 'Registered Users',
      value: stats.userCount || 0,
      icon: Users,
      color: 'text-purple-600 bg-purple-500/10 border-purple-500/20',
    },
  ]

  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
      {cards.map((card, idx) => {
        const Icon = card.icon
        return (
          <div
            key={idx}
            className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between"
          >
            <div>
              <p className="text-xs font-semibold text-text-secondary">{card.title}</p>
              <h3 className="text-xl font-black text-text-primary mt-1">{card.value}</h3>
            </div>
            <div className={`h-11 w-11 rounded-xl border flex items-center justify-center ${card.color}`}>
              <Icon className="h-5 w-5" />
            </div>
          </div>
        )
      })}
    </div>
  )
}
