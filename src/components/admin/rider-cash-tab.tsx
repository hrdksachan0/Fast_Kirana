'use client'

import { AdminRiderCash } from '@/components/admin/admin-rider-cash'

interface RiderCashTabProps {
  storeId?: string | null
}

export function RiderCashTab({ storeId }: RiderCashTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminRiderCash storeId={storeId} />
    </div>
  )
}
