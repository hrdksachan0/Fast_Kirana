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
  storeId?: string | null
}

export function AnalyticsTab({ products, orders, categories, stats, storeId }: AnalyticsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminAnalytics products={products} orders={orders} categories={categories} stats={stats} storeId={storeId} />
    </div>
  )
}
