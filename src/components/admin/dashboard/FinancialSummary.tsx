'use client'

import React from 'react'
import { AdminFinanceTab } from '@/components/admin/finance/admin-finance-tab'

export interface FinancialSummaryProps {
  storeId?: string | null
}

/**
 * FinancialSummary
 * 
 * Modular subcomponent for the Admin Dashboard.
 * Consolidates daily gross sales, cash vs online splits,
 * rider COD reconciliation, category margins, and ledger export.
 */
export function FinancialSummary({ storeId }: FinancialSummaryProps) {
  return (
    <div className="w-full">
      <AdminFinanceTab storeId={storeId} />
    </div>
  )
}

export default FinancialSummary
