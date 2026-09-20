'use client'

import React from 'react'
import { RiderCashTab } from '@/components/admin/rider-cash-tab'

export interface AdminRidersFleetTabProps {
  storeId?: string | null
}

export function AdminRidersFleetTab({ storeId }: AdminRidersFleetTabProps) {
  return (
    <div className="w-full">
      <RiderCashTab storeId={storeId} />
    </div>
  )
}
