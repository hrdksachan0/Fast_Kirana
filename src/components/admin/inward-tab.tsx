'use client'

import { AdminInventoryCenter } from '@/components/admin/admin-inventory-center'

interface InwardTabProps {
  onInventoryUpdated?: () => void
}

export function InwardTab({ onInventoryUpdated }: InwardTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminInventoryCenter onInventoryUpdated={onInventoryUpdated} />
    </div>
  )
}
