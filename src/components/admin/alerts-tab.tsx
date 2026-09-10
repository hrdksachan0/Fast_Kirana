'use client'

import { AdminAlerts } from '@/components/admin/admin-alerts'

interface AlertsTabProps {
  onProductUpdated: () => Promise<void>
  storeId?: string | null
}

export function AlertsTab({ onProductUpdated, storeId }: AlertsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminAlerts onProductUpdated={onProductUpdated} storeId={storeId} />
    </div>
  )
}
