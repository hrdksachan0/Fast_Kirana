'use client'

import { AdminReports } from '@/components/admin/admin-reports'

interface ReportsTabProps {}

export function ReportsTab({}: ReportsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminReports />
    </div>
  )
}
