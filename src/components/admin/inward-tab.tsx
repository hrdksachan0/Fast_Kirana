'use client'

import { AdminInventoryCenter } from '@/components/admin/admin-inventory-center'

interface InwardTabProps {}

export function InwardTab({}: InwardTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminInventoryCenter />
    </div>
  )
}
