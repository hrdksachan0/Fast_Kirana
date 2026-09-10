'use client'

import { AdminForecast } from '@/components/admin/admin-forecast'

interface ForecastTabProps {
  categories: any[]
  onRestockCompleted: () => Promise<void>
  storeId?: string | null
}

export function ForecastTab({ categories, onRestockCompleted, storeId }: ForecastTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminForecast categories={categories} onRestockCompleted={onRestockCompleted} storeId={storeId} />
    </div>
  )
}
