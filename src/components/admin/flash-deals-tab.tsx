'use client'

import { AdminPromotions } from '@/components/admin/admin-promotions'

interface FlashDealsTabProps {
  storeId?: string
}

export function FlashDealsTab({ storeId }: FlashDealsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminPromotions storeId={storeId} />
    </div>
  )
}
