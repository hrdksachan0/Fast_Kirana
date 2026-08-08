'use client'

import { AdminAlerts } from '@/components/admin/admin-alerts'

interface AlertsTabProps {
  onProductUpdated: () => Promise<void>
}

export function AlertsTab({ onProductUpdated }: AlertsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminAlerts onProductUpdated={onProductUpdated} />
    </div>
  )
}
