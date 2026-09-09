'use client'

import { AdminRestaurantReport } from '@/components/admin/admin-restaurant-report'

interface RestaurantReportTabProps {
  storeId?: string | null
}

export function RestaurantReportTab({ storeId }: RestaurantReportTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminRestaurantReport storeId={storeId} />
    </div>
  )
}
