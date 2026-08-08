'use client'

import { AdminRestaurantReport } from '@/components/admin/admin-restaurant-report'

interface RestaurantReportTabProps {}

export function RestaurantReportTab({}: RestaurantReportTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminRestaurantReport />
    </div>
  )
}
