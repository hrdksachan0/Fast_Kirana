'use client'

import { AdminForecast } from '@/components/admin/admin-forecast'

interface ForecastTabProps {
  categories: any[]
  onRestockCompleted: () => Promise<void>
}

export function ForecastTab({ categories, onRestockCompleted }: ForecastTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminForecast categories={categories} onRestockCompleted={onRestockCompleted} />
    </div>
  )
}
