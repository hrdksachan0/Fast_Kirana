'use client'

import React from 'react'
import { ProductsTab } from '@/components/admin/products-tab'

export interface InventoryTableProps {
  products: any[]
  categories: any[]
  restaurantsList?: any[]
  settingsMap?: Record<string, any>
  filteredProducts: any[]
  searchQuery: string
  selectedTypeFilter: string
  selectedCategoryFilter: string
  showAddProduct: boolean
  showSortManager: boolean
  showCsvImport: boolean
  showExportModal: boolean
  isExporting: boolean
  isCreatingProduct: boolean
  newProduct: any
  newProductType: string
  editProductType: string
  newProductVariants: any[]
  editProductVariants: any[]
  hasVariantsNew: boolean
  hasVariantsEdit: boolean
  newCustomTag: string
  editCustomTag: string
  isUploading: boolean
  productPage: number
  productTotal: number
  editingProduct: any
  savingProductId: string | null
  setShowAddProduct: (show: boolean) => void
  setShowSortManager: (show: boolean) => void
  setShowCsvImport: (show: boolean) => void
  setShowExportModal: (show: boolean) => void
  setNewProduct: any
  setNewProductType: any
  setEditProductType: any
  setNewProductVariants: any
  setEditProductVariants: any
  setHasVariantsNew: any
  setHasVariantsEdit: any
  setNewCustomTag: any
  setEditingProduct: any
  setProductPage: (page: number) => void
  setMediaTarget: any
  setShowMediaLibrary: any
  setSearchQuery: (query: string) => void
  setSelectedTypeFilter: (filter: string) => void
  setSelectedCategoryFilter: (cat: string) => void
  setProducts: any
  setAllProducts: any
  handleNewProductTypeChange: any
  handleEditProductTypeChange: any
  applyProductTemplate: any
  toggleTag: any
  handleCreateCustomTag: any
  handleCreateProduct: any
  handleToggleProductAvailability: any
  handleDeleteProduct: any
  startEditingProduct: any
  handleDuplicateProduct: any
  handleCloudinaryUpload: any
  handleExportCsv: any
  handleReplenishCsv: any
  renderPagination: any
  allProducts: any[]
  resetNewProductForm: any
}

/**
 * InventoryTable
 * 
 * Modular subcomponent for the Admin Dashboard.
 * Handles product catalog filtering, stock management, price updates,
 * quick toggles (availability, flash deals), and bulk CSV actions.
 */
export function InventoryTable(props: InventoryTableProps) {
  return (
    <div className="w-full">
      <ProductsTab
        {...(props as any)}
        restaurantsList={props.restaurantsList || []}
        settingsMap={props.settingsMap || {}}
      />
    </div>
  )
}

export default InventoryTable
