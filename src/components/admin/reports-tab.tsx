'use client'

import { AdminReports } from '@/components/admin/admin-reports'

interface ReportsTabProps {
  storeId?: string | null
}

export function ReportsTab({ storeId }: ReportsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminReports storeId={storeId} />
    </div>
  )
}
