'use client'

import { AdminBanners } from '@/components/admin/admin-banners'

interface BannersTabProps {
  categories: any[]
  products: any[]
}

export function BannersTab({ categories, products }: BannersTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminBanners categories={categories} products={products} />
    </div>
  )
}
