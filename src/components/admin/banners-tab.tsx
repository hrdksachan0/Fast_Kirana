'use client'

import { AdminBanners } from '@/components/admin/admin-banners'

interface BannersTabProps {
  categories: any[]
  products: any[]
  storeId?: string
  stores?: any[]
}

export function BannersTab({ categories, products, storeId, stores }: BannersTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminBanners categories={categories} products={products} storeId={storeId} stores={stores} />
    </div>
  )
}
