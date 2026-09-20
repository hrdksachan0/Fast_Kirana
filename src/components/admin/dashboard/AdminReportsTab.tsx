'use client'

import React from 'react'
import { ReportsTab } from '@/components/admin/reports-tab'
import { RestaurantReportTab } from '@/components/admin/restaurant-report-tab'
import { AnalyticsTab } from '@/components/admin/analytics-tab'
import { ForecastTab } from '@/components/admin/forecast-tab'

export interface AdminReportsTabProps {
  activeTab: 'reports' | 'restaurant-report' | 'analytics' | 'forecast'
  storeId?: string | null
  products: any[]
  orders: any[]
  categories: any[]
  stats: {
    revenue: number
    orderCount: number
    lowStockCount: number
  }
  onRestockCompleted?: () => Promise<void>
}

export function AdminReportsTab({
  activeTab,
  storeId,
  products,
  orders,
  categories,
  stats,
  onRestockCompleted,
}: AdminReportsTabProps) {
  switch (activeTab) {
    case 'reports':
      return <ReportsTab storeId={storeId} />
    case 'restaurant-report':
      return <RestaurantReportTab storeId={storeId} />
    case 'analytics':
      return (
        <AnalyticsTab
          storeId={storeId}
          products={products}
          orders={orders}
          categories={categories}
          stats={stats}
        />
      )
    case 'forecast':
      return (
        <ForecastTab
          storeId={storeId}
          categories={categories}
          onRestockCompleted={onRestockCompleted || (async () => {})}
        />
      )
    default:
      return null
  }
}
