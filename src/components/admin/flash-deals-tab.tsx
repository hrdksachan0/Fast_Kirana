'use client'

import { AdminPromotions } from '@/components/admin/admin-promotions'

interface FlashDealsTabProps {}

export function FlashDealsTab({}: FlashDealsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminPromotions />
    </div>
  )
}
