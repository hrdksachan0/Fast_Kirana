'use client'

import React from 'react'
import { ProductsTab } from '@/components/admin/products-tab'
import { CategoriesTab } from '@/components/admin/categories-tab'
import { AlertsTab } from '@/components/admin/alerts-tab'
import { InwardTab } from '@/components/admin/inward-tab'
import { BulkUpdateTab } from '@/components/admin/bulk-update-tab'
import { CsvImportTab } from '@/components/admin/csv-import-tab'

export interface AdminInventoryHubTabProps {
  activeTab: 'products' | 'categories' | 'alerts' | 'inward' | 'bulk-update' | 'csv-import'
  selectedHubId: string
  // ProductsTab props
  productProps: any
  // CategoriesTab props
  categoryProps: any
  // Refresh callbacks
  onRefreshProducts: () => Promise<void>
}

export function AdminInventoryHubTab({
  activeTab,
  selectedHubId,
  productProps,
  categoryProps,
  onRefreshProducts,
}: AdminInventoryHubTabProps) {
  switch (activeTab) {
    case 'products':
      return <ProductsTab {...productProps} />
    case 'categories':
      return <CategoriesTab {...categoryProps} />
    case 'alerts':
      return <AlertsTab storeId={selectedHubId} onProductUpdated={onRefreshProducts} />
    case 'inward':
      return <InwardTab storeId={selectedHubId} onInventoryUpdated={onRefreshProducts} />
    case 'bulk-update':
      return (
        <BulkUpdateTab
          categories={categoryProps.categories}
          onUpdateCompleted={onRefreshProducts}
        />
      )
    case 'csv-import':
      return (
        <CsvImportTab
          categories={categoryProps.categories}
          onImportSuccess={onRefreshProducts}
        />
      )
    default:
      return null
  }
}
