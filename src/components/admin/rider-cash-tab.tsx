'use client'

import { AdminRiderCash } from '@/components/admin/admin-rider-cash'

interface RiderCashTabProps {}

export function RiderCashTab({}: RiderCashTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminRiderCash />
    </div>
  )
}
