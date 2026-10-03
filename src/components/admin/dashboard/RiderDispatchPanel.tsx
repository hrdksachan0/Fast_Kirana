'use client'

import React from 'react'
import { RiderCashTab } from '@/components/admin/rider-cash-tab'

export interface RiderDispatchPanelProps {
  storeId?: string | null
}

/**
 * RiderDispatchPanel
 * 
 * Modular subcomponent for the Admin Dashboard.
 * Consolidates rider fleet monitoring, cash-in-hand tracking,
 * COD collection reconciliations, and direct delivery dispatch.
 */
export function RiderDispatchPanel({ storeId }: RiderDispatchPanelProps) {
  return (
    <div className="w-full">
      <RiderCashTab storeId={storeId} />
    </div>
  )
}

export default RiderDispatchPanel
