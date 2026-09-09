'use client'

import { AdminInventoryCenter } from '@/components/admin/admin-inventory-center'

interface InwardTabProps {
  onInventoryUpdated?: () => void
  storeId?: string | null
}

export function InwardTab({ onInventoryUpdated, storeId }: InwardTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminInventoryCenter onInventoryUpdated={onInventoryUpdated} storeId={storeId} />
    </div>
  )
}
