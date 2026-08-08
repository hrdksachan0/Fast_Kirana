'use client'

import { AdminAnalytics } from '@/components/admin/admin-analytics'

interface AnalyticsTabProps {
  products: any[]
  orders: any[]
  categories: any[]
  stats: {
    revenue: number
    orderCount: number
    lowStockCount: number
  }
}

export function AnalyticsTab({ products, orders, categories, stats }: AnalyticsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminAnalytics products={products} orders={orders} categories={categories} stats={stats} />
    </div>
  )
}
