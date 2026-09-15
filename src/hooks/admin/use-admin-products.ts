'use client'

import { useState, useEffect, useCallback } from 'react'
import { ProductEditForm } from '@/components/admin/product-edit-modal'
import { PRODUCT_TEMPLATES } from '@/lib/constants'
import { toast } from 'sonner'

interface UseAdminProductsProps {
  initialProducts?: any[]
  initialAllProducts?: any[]
  categories: any[]
  selectedHubId: string
  sessionUserId?: string
  sessionUserRole?: string
}

export function useAdminProducts({
  initialProducts,
  initialAllProducts,
  categories,
  selectedHubId,
  sessionUserId,
  sessionUserRole,
}: UseAdminProductsProps) {
  const [products, setProducts] = useState(initialProducts || [])
  const [allProducts, setAllProducts] = useState(initialAllProducts || [])
  const [productPage, setProductPage] = useState(1)
  const [productTotal, setProductTotal] = useState((initialProducts || []).length)
  const [isLoadingProducts, setIsLoadingProducts] = useState(false)

  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState('')
  const [selectedTypeFilter, setSelectedTypeFilter] = useState<string>('all')

  const [editingProduct, setEditingProduct] = useState<any | null>(null)
  const [savingProductId, setSavingProductId] = useState<string | null>(null)

  const [productEditForm, setProductEditForm] = useState<ProductEditForm>({
    name: '',
    description: '',
    imageUrl: '',
    categoryId: '',
    restaurantId: '',
    mrp: '',
    price: '',
    unit: '',
    stock: '',
    isAvailable: true,
    tags: '',
    minStock: '10',
    expiryDate: '',
    costPrice: '0',
    location: '',
    isFlashDeal: false,
    isTopPick: false,
    isBestSeller: false,
    sortOrder: '0',
    barcode: '',
    vendor: '',
    vendorId: '',
  })

  const [showAddProduct, setShowAddProduct] = useState(false)
  const [showSortManager, setShowSortManager] = useState(false)
  const [showCsvImport, setShowCsvImport] = useState(false)
  const [showExportModal, setShowExportModal] = useState(false)
  const [isExporting, setIsExporting] = useState(false)
  const [isCreatingProduct, setIsCreatingProduct] = useState(false)

  const [newProduct, setNewProduct] = useState({
    name: '',
    description: '',
    imageUrl: '',
    categoryId: categories?.[0]?.id || '',
    restaurantId: '',
    mrp: '',
    price: '',
    unit: '',
    stock: '',
    isAvailable: true,
    tags: '',
    minStock: '10',
    expiryDate: '',
    costPrice: '0',
    location: '',
    isFlashDeal: false,
    isTopPick: false,
    isBestSeller: false,
    sortOrder: '0',
    barcode: '',
    vendor: '',
    vendorId: '',
  })

  const [newProductType, setNewProductType] = useState<'grocery' | 'cafe' | 'restaurant'>('grocery')
  const [editProductType, setEditProductType] = useState<'grocery' | 'cafe' | 'restaurant'>('grocery')
  const [newCustomTag, setNewCustomTag] = useState('')
  const [editCustomTag, setEditCustomTag] = useState('')
  const [newProductVariants, setNewProductVariants] = useState<any[]>([])
  const [editProductVariants, setEditProductVariants] = useState<any[]>([])
  const [hasVariantsNew, setHasVariantsNew] = useState(false)
  const [hasVariantsEdit, setHasVariantsEdit] = useState(false)

  const isNewProductCafe = newProductType === 'cafe'
  const isEditProductCafe = editProductType === 'cafe'
  const isNewProductRestaurant = newProductType === 'restaurant'
  const isEditProductRestaurant = editProductType === 'restaurant'

  useEffect(() => {
    setProductPage(1)
  }, [selectedCategoryFilter, searchQuery, selectedTypeFilter, selectedHubId])

  const fetchProducts = useCallback(async () => {
    setIsLoadingProducts(true)
    try {
      const storeQuery =
        selectedHubId && selectedHubId !== 'all'
          ? `&storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(
        `/api/admin/products?page=${productPage}&limit=10&categoryId=${selectedCategoryFilter}&search=${encodeURIComponent(
          searchQuery
        )}&type=${selectedTypeFilter}${storeQuery}&t=${Date.now()}`
      )
      if (res.ok) {
        const data = await res.json()
        setProducts(data.products)
        setProductTotal(data.total)
      }
    } catch (err) {
      console.error('Failed to fetch products:', err)
    } finally {
      setIsLoadingProducts(false)
    }
  }, [productPage, selectedCategoryFilter, searchQuery, selectedTypeFilter, selectedHubId])

  useEffect(() => {
    fetchProducts()
  }, [fetchProducts])

  useEffect(() => {
    let active = true
    const loadAllProducts = async () => {
      try {
        const storeQuery =
          selectedHubId && selectedHubId !== 'all'
            ? `&storeId=${encodeURIComponent(selectedHubId)}`
            : ''
        const res = await fetch(`/api/products?limit=1000${storeQuery}&t=${Date.now()}`)
        if (res.ok && active) {
          const data = await res.json()
          if (data.products) {
            setAllProducts(data.products)
          }
        }
      } catch (err) {
        console.error('Failed to load full products list:', err)
      }
    }
    loadAllProducts()
    return () => {
      active = false
    }
  }, [selectedHubId])

  const handleNewProductTypeChange = (type: 'grocery' | 'cafe' | 'restaurant') => {
    setNewProductType(type)
    if (type === 'restaurant' || type === 'cafe') {
      setNewProduct((prev) => ({ ...prev, expiryDate: '' }))
    } else {
      const firstCatId = categories[0]?.id || ''
      setNewProduct((prev) => ({ ...prev, categoryId: firstCatId }))
    }
  }

  const handleEditProductTypeChange = (type: 'grocery' | 'cafe' | 'restaurant') => {
    setEditProductType(type)
    if (type === 'restaurant' || type === 'cafe') {
      setProductEditForm((prev) => ({ ...prev, expiryDate: '' }))
    } else {
      const firstCatId = categories[0]?.id || ''
      setProductEditForm((prev) => ({ ...prev, categoryId: firstCatId }))
    }
  }

  const applyProductTemplate = (templateId: string) => {
    const template = PRODUCT_TEMPLATES.find((t) => t.id === templateId)
    if (!template) return

    let categoryId = ''
    if (template.categoryName === 'FastKirana Cafe') {
      const cafeCat = categories.find((c) => c.slug === 'cafe')
      categoryId = cafeCat?.id || ''
      handleNewProductTypeChange('cafe')
    } else {
      const matchedCat = categories.find(
        (c) => c.name.toLowerCase().trim() === template.categoryName.toLowerCase().trim()
      )
      categoryId = matchedCat?.id || categories.find((c) => c.slug !== 'cafe')?.id || ''
      handleNewProductTypeChange('grocery')
    }

    setNewProduct((prev) => ({
      ...prev,
      categoryId,
      unit: template.unit,
      minStock: template.minStock.toString(),
      tags: template.tags,
    }))
    toast.success(`Applied ${template.label} template!`)
  }

  const toggleTag = (form: 'new' | 'edit', tag: string, checked: boolean) => {
    const currentForm = form === 'new' ? newProduct : productEditForm
    const setForm: any = form === 'new' ? setNewProduct : setProductEditForm

    const tagsList = currentForm.tags
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0 && t.toLowerCase() !== tag.toLowerCase())

    if (checked) {
      tagsList.push(tag)
    }

    setForm((prev: any) => ({
      ...prev,
      tags: tagsList.join(', '),
    }))
  }

  const handleCreateCustomTag = (form: 'new' | 'edit', tagText: string) => {
    const cleanTag = tagText.trim().toLowerCase().replace(/\s+/g, '-')
    if (!cleanTag) return

    const currentForm = form === 'new' ? newProduct : productEditForm
    const setForm: any = form === 'new' ? setNewProduct : setProductEditForm

    const tagsList = currentForm.tags
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)

    if (!tagsList.map((t) => t.toLowerCase()).includes(cleanTag)) {
      tagsList.push(cleanTag)
    }

    setForm((prev: any) => ({
      ...prev,
      tags: tagsList.join(', '),
    }))

    if (form === 'new') {
      setNewCustomTag('')
    } else {
      setEditCustomTag('')
    }
  }

  const handleDuplicateProduct = (p: any) => {
    const isCafe =
      (p.tags || []).map((t: string) => t.trim().toLowerCase()).includes('cafe') ||
      categories.find((c) => c.id === p.categoryId)?.slug === 'cafe'
    setNewProductType(isCafe ? 'cafe' : 'grocery')

    const hasVariants = p.variants && Array.isArray(p.variants) && p.variants.length > 0
    setHasVariantsNew(hasVariants)
    setNewProductVariants(
      hasVariants
        ? (p.variants as any[]).map((v) => ({
            name: v.name,
            price: String(v.price),
            mrp: String(v.mrp),
            costPrice: String(v.costPrice ?? 0),
            stock: String(v.stock),
          }))
        : []
    )

    setNewProduct({
      name: `${p.name} (Copy)`,
      description: p.description || '',
      imageUrl: p.imageUrl || '',
      categoryId: p.categoryId || '',
      restaurantId: p.restaurantId || '',
      mrp: String(p.mrp || ''),
      price: String(p.price || ''),
      unit: p.unit || '',
      stock: String(p.stock || ''),
      isAvailable: p.isAvailable !== false,
      tags: p.tags ? p.tags.join(', ') : '',
      minStock: String(p.minStock ?? 10),
      expiryDate: p.expiryDate ? String(p.expiryDate) : '',
      costPrice: String(p.costPrice ?? 0),
      location: p.location || '',
      isFlashDeal: p.isFlashDeal || false,
      isTopPick: p.isTopPick || false,
      isBestSeller: p.isBestSeller || false,
      sortOrder: String(p.sortOrder ?? 0),
      barcode: p.barcode || '',
      vendor: p.vendor || '',
      vendorId: (p as any).vendorId || '',
    })

    setShowAddProduct(true)
    setShowCsvImport(false)

    setTimeout(() => {
      const formElement = document.getElementById('add-product-form-container')
      if (formElement) {
        formElement.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    }, 50)
  }

  const handleExportCsv = async (type: 'all' | 'grocery' | 'cafe') => {
    setIsExporting(true)
    try {
      const url = `/api/admin/products?limit=5000${type !== 'all' ? `&type=${type}` : ''}`
      const res = await fetch(url)
      const data = await res.json()

      if (!res.ok) {
        throw new Error(data.error || 'Failed to fetch products for export')
      }

      const exportProducts = data.products || []

      if (exportProducts.length === 0) {
        toast.warning('No products found to export.')
        setIsExporting(false)
        return
      }

      const headers = [
        'ID',
        'Name',
        'Category',
        'Vendor',
        'Unit',
        'MRP',
        'Price',
        'Stock',
        'Tags',
        'Description',
        'Image URL',
        'Cost Price',
        'Min Stock',
        'Location',
        'Barcode',
        'Display Order',
        'Variants',
      ]

      const csvRows = [headers.join(',')]

      exportProducts.forEach((p: any) => {
        const row = [
          p.id || '',
          p.name || '',
          p.category?.name || '',
          p.vendor || '',
          p.unit || '',
          p.mrp?.toString() || '0',
          p.price?.toString() || '0',
          p.stock?.toString() || '0',
          Array.isArray(p.tags) ? p.tags.join(', ') : p.tags || '',
          p.description || '',
          p.imageUrl || '',
          p.costPrice?.toString() || '0',
          p.minStock?.toString() || '10',
          p.location || '',
          p.barcode || '',
          p.sortOrder?.toString() || '0',
          p.variants
            ? Array.isArray(p.variants)
              ? (p.variants as any[])
                  .map((v) => {
                    const parts = [
                      v.name || '',
                      v.price?.toString() || '0',
                      v.mrp?.toString() || '0',
                      v.stock?.toString() || '0',
                    ]
                    if (v.costPrice !== undefined) {
                      parts.push(v.costPrice.toString())
                    }
                    return parts.join(':')
                  })
                  .join(' | ')
              : typeof p.variants === 'string'
              ? p.variants
              : ''
            : '',
        ]

        const escapedRow = row.map((cell) => {
          const cleanCell = cell.replace(/"/g, '""')
          if (cleanCell.includes(',') || cleanCell.includes('\n') || cleanCell.includes('"')) {
            return `"${cleanCell}"`
          }
          return cleanCell
        })

        csvRows.push(escapedRow.join(','))
      })

      const csvContent = csvRows.join('\n')
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const urlBlob = URL.createObjectURL(blob)

      const link = document.createElement('a')
      link.href = urlBlob

      const filename = `fastkirana_products_${type}_${
        new Date().toISOString().split('T')[0]
      }.csv`
      link.setAttribute('download', filename)
      link.click()
      URL.revokeObjectURL(urlBlob)

      toast.success(`Successfully exported ${exportProducts.length} items!`)
      setShowExportModal(false)
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Failed to export products')
    } finally {
      setIsExporting(false)
    }
  }

  const handleReplenishCsv = async () => {
    setIsExporting(true)
    try {
      const url = '/api/admin/products?limit=5000'
      const res = await fetch(url)
      const data = await res.json()

      if (!res.ok) {
        throw new Error(data.error || 'Failed to fetch products for replenish PO')
      }

      const replenishProducts = (data.products || []).filter(
        (p: any) => p.stock <= (p.minStock ?? 10)
      )

      if (replenishProducts.length === 0) {
        toast.success('Excellent! No products are currently below min stock levels.')
        setIsExporting(false)
        return
      }

      const headers = [
        'Name',
        'Category',
        'Unit',
        'MRP',
        'Price',
        'Stock',
        'Tags',
        'Description',
        'Image URL',
        'Cost Price',
        'Min Stock',
        'Location',
      ]

      const csvRows = [headers.join(',')]

      replenishProducts.forEach((p: any) => {
        const row = [
          p.name || '',
          p.category?.name || '',
          p.unit || '',
          p.mrp?.toString() || '0',
          p.price?.toString() || '0',
          p.stock?.toString() || '0',
          Array.isArray(p.tags) ? p.tags.join(', ') : p.tags || '',
          p.description || '',
          p.imageUrl || '',
          p.costPrice?.toString() || '0',
          p.minStock?.toString() || '10',
          p.location || '',
        ]

        const escapedRow = row.map((cell) => {
          const cleanCell = cell.replace(/"/g, '""')
          if (cleanCell.includes(',') || cleanCell.includes('\n') || cleanCell.includes('"')) {
            return `"${cleanCell}"`
          }
          return cleanCell
        })

        csvRows.push(escapedRow.join(','))
      })

      const csvContent = csvRows.join('\n')
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const urlBlob = URL.createObjectURL(blob)

      const link = document.createElement('a')
      link.href = urlBlob

      const filename = `fastkirana_replenish_po_${new Date().toISOString().split('T')[0]}.csv`
      link.setAttribute('download', filename)
      link.click()
      URL.revokeObjectURL(urlBlob)

      toast.success(`Generated replenishment PO with ${replenishProducts.length} items!`)
    } catch (err: any) {
      toast.error(err.message || 'Error generating replenishment PO')
    } finally {
      setIsExporting(false)
    }
  }

  const startEditingProduct = (p: any) => {
    setEditingProduct(p)
    const isCafe =
      (p.tags || []).map((t: string) => t.trim().toLowerCase()).includes('cafe') ||
      categories.find((c) => c.id === p.categoryId)?.slug === 'cafe'
    const isRestaurant =
      (p.tags || []).map((t: string) => t.trim().toLowerCase()).includes('restaurant') ||
      categories.find((c) => c.id === p.categoryId)?.slug === 'restaurant'
    setEditProductType(isRestaurant ? 'restaurant' : isCafe ? 'cafe' : 'grocery')

    const hasVariants = p.variants && Array.isArray(p.variants) && p.variants.length > 0
    setHasVariantsEdit(hasVariants)
    setEditProductVariants(
      hasVariants
        ? (p.variants as any[]).map((v) => ({
            name: v.name,
            price: String(v.price),
            mrp: String(v.mrp),
            costPrice: String(v.costPrice ?? 0),
            stock: String(v.stock),
          }))
        : []
    )

    setProductEditForm({
      name: p.name || '',
      description: p.description || '',
      imageUrl: p.imageUrl || '',
      categoryId: p.categoryId || '',
      restaurantId: p.restaurantId || '',
      mrp: String(p.mrp || ''),
      price: String(p.price || ''),
      unit: p.unit || '',
      stock: String(p.stock || ''),
      isAvailable: p.isAvailable !== false,
      tags: p.tags ? p.tags.join(', ') : '',
      minStock: String(p.minStock ?? 10),
      expiryDate: p.expiryDate ? String(p.expiryDate) : '',
      costPrice: String(p.costPrice ?? 0),
      location: p.location || '',
      isFlashDeal: p.isFlashDeal || false,
      isTopPick: p.isTopPick || false,
      isBestSeller: p.isBestSeller || false,
      sortOrder: String(p.sortOrder ?? 0),
      barcode: p.barcode || '',
      vendor: p.vendor || '',
      vendorId: (p as any).vendorId || '',
    })
  }

  const saveProductChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    const requiresBasePrice = !hasVariantsEdit
    const isRestaurant = isEditProductRestaurant || !!productEditForm.restaurantId
    const isSpecialProduct = isEditProductCafe || isRestaurant
    const hasCategory = productEditForm.categoryId || isSpecialProduct

    if (isRestaurant && !productEditForm.restaurantId) {
      toast.error('Please select a Restaurant Outlet for this dish *')
      return
    }

    if (
      !productEditForm.name ||
      !hasCategory ||
      (requiresBasePrice && (!productEditForm.price || !productEditForm.mrp))
    ) {
      toast.error('Please fill in all required fields')
      return
    }
    if (hasVariantsEdit && editProductVariants.length === 0) {
      toast.error('Please add at least one variant option')
      return
    }

    setSavingProductId(editingProduct.id)
    try {
      const tagsArray = productEditForm.tags
        ? productEditForm.tags
            .split(',')
            .map((t) => t.trim())
            .filter((t) => t.length > 0)
        : []

      let parsedExpiryISO: string | null = null
      if (productEditForm.expiryDate) {
        const d = new Date(productEditForm.expiryDate)
        if (!isNaN(d.getTime())) {
          parsedExpiryISO = d.toISOString()
        }
      }

      const sortedEditVariants =
        hasVariantsEdit && editProductVariants.length > 0
          ? [...editProductVariants].sort(
              (a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0)
            )
          : []
      const lowestEditVariant = sortedEditVariants[0]
      const lowestEditPrice = lowestEditVariant
        ? parseFloat(lowestEditVariant.price) || 0
        : parseFloat(productEditForm.price)
      const lowestEditMrp = lowestEditVariant
        ? parseFloat(lowestEditVariant.mrp) || lowestEditPrice
        : parseFloat(productEditForm.mrp)
      const resolvedEditUnit =
        lowestEditVariant &&
        (!productEditForm.unit ||
          productEditForm.unit === '1 pc' ||
          productEditForm.unit === '1 unit')
          ? lowestEditVariant.name
          : productEditForm.unit

      const res = await fetch(`/api/products/${editingProduct.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          ...(sessionUserId
            ? { 'x-user-id': sessionUserId, 'x-user-role': sessionUserRole }
            : {}),
        },
        body: JSON.stringify({
          name: productEditForm.name,
          description: productEditForm.description,
          imageUrl: productEditForm.imageUrl,
          categoryId: productEditForm.categoryId,
          restaurantId: productEditForm.restaurantId || null,
          mrp: lowestEditMrp,
          price: lowestEditPrice,
          unit: resolvedEditUnit,
          stock:
            isEditProductCafe || isEditProductRestaurant || productEditForm.restaurantId
              ? 99999
              : sortedEditVariants.length > 0
              ? sortedEditVariants.reduce((sum, v) => sum + (parseInt(v.stock) || 0), 0)
              : parseInt(productEditForm.stock) || 0,
          minStock:
            isEditProductCafe || isEditProductRestaurant || productEditForm.restaurantId
              ? 0
              : parseInt(productEditForm.minStock) || 10,
          isAvailable: productEditForm.isAvailable,
          tags: tagsArray,
          expiryDate: parsedExpiryISO,
          costPrice: parseFloat(productEditForm.costPrice) || 0,
          location: productEditForm.location || null,
          isFlashDeal: productEditForm.isFlashDeal,
          isTopPick: productEditForm.isTopPick,
          isBestSeller: productEditForm.isBestSeller,
          sortOrder: parseInt(productEditForm.sortOrder) || 0,
          barcode: productEditForm.barcode || null,
          vendor: productEditForm.vendor?.trim() || null,
          vendorId: productEditForm.vendorId || null,
          storeId: selectedHubId && selectedHubId !== 'all' ? selectedHubId : undefined,
          variants:
            sortedEditVariants.length > 0
              ? sortedEditVariants.map((v) => ({
                  name: v.name,
                  price: parseFloat(v.price) || 0,
                  mrp: parseFloat(v.mrp) || 0,
                  costPrice: parseFloat(v.costPrice) || 0,
                  stock: parseInt(v.stock) || 0,
                }))
              : null,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setProducts(products.map((p) => (p.id === editingProduct.id ? updated : p)))
        setAllProducts(
          allProducts.map((p) => (p.id === editingProduct.id ? { ...p, ...updated } : p))
        )
        toast.success('Product updated successfully!')
        setEditingProduct(null)
      } else {
        const errorData = await res.json().catch(() => ({}))
        toast.error(errorData.error || 'Failed to update product details')
      }
    } catch (err: any) {
      console.error('Error saving product changes:', err)
      toast.error(err?.message || 'Error saving product changes')
    } finally {
      setSavingProductId(null)
    }
  }

  const handleToggleProductAvailability = async (
    productId: string,
    currentAvailable: boolean
  ) => {
    try {
      const res = await fetch(`/api/products/${productId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          isAvailable: !currentAvailable,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setProducts(products.map((p) => (p.id === productId ? updated : p)))
        setAllProducts(
          allProducts.map((p) => (p.id === productId ? { ...p, ...updated } : p))
        )
        toast.success(
          `Product "${updated.name}" ${!currentAvailable ? 'enabled' : 'disabled'} successfully!`
        )
      } else {
        toast.error('Failed to update product availability')
      }
    } catch (err) {
      toast.error('Error updating product status')
    }
  }

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault()
    const requiresBasePrice = !hasVariantsNew
    const isRestaurant = isNewProductRestaurant || !!newProduct.restaurantId
    const isSpecialProduct = isNewProductCafe || isRestaurant
    const hasCategory = newProduct.categoryId || isSpecialProduct

    if (isRestaurant && !newProduct.restaurantId) {
      toast.error('Please select a Restaurant Outlet for this dish *')
      return
    }

    if (
      !newProduct.name ||
      !hasCategory ||
      (requiresBasePrice && (!newProduct.price || !newProduct.mrp))
    ) {
      toast.error('Please fill in all required fields')
      return
    }
    if (hasVariantsNew && newProductVariants.length === 0) {
      toast.error('Please add at least one variant option')
      return
    }

    setIsCreatingProduct(true)
    try {
      const tagsArray = newProduct.tags
        ? newProduct.tags
            .split(',')
            .map((t) => t.trim())
            .filter((t) => t.length > 0)
        : []

      let resolvedCategoryId = newProduct.categoryId
      if (newProduct.restaurantId) {
        resolvedCategoryId = newProduct.categoryId || categories[0]?.id || ''
      }

      const sortedNewVariants =
        hasVariantsNew && newProductVariants.length > 0
          ? [...newProductVariants].sort(
              (a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0)
            )
          : []
      const lowestNewVariant = sortedNewVariants[0]
      const lowestNewPrice = lowestNewVariant
        ? parseFloat(lowestNewVariant.price) || 0
        : parseFloat(newProduct.price)
      const lowestNewMrp = lowestNewVariant
        ? parseFloat(lowestNewVariant.mrp) || lowestNewPrice
        : parseFloat(newProduct.mrp)
      const resolvedNewUnit =
        lowestNewVariant &&
        (!newProduct.unit || newProduct.unit === '1 pc' || newProduct.unit === '1 unit')
          ? lowestNewVariant.name
          : newProduct.unit

      const res = await fetch('/api/products', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(sessionUserId
            ? { 'x-user-id': sessionUserId, 'x-user-role': sessionUserRole }
            : {}),
        },
        body: JSON.stringify({
          ...newProduct,
          vendor: newProduct.vendor?.trim() || null,
          vendorId: newProduct.vendorId || null,
          restaurantId: newProduct.restaurantId || null,
          barcode: newProduct.barcode || null,
          location: newProduct.location || null,
          storeId: selectedHubId && selectedHubId !== 'all' ? selectedHubId : undefined,
          categoryId: resolvedCategoryId || newProduct.categoryId,
          mrp: lowestNewMrp,
          price: lowestNewPrice,
          unit: resolvedNewUnit,
          stock:
            isNewProductCafe || isNewProductRestaurant || newProduct.restaurantId
              ? 99999
              : sortedNewVariants.length > 0
              ? sortedNewVariants.reduce((sum, v) => sum + (parseInt(v.stock) || 0), 0)
              : parseInt(newProduct.stock) || 0,
          minStock:
            isNewProductCafe || isNewProductRestaurant || newProduct.restaurantId
              ? 0
              : parseInt(newProduct.minStock) || 10,
          expiryDate: newProduct.expiryDate
            ? new Date(newProduct.expiryDate).toISOString()
            : null,
          costPrice: parseFloat(newProduct.costPrice) || 0,
          tags: tagsArray,
          variants:
            sortedNewVariants.length > 0
              ? sortedNewVariants.map((v) => ({
                  name: v.name,
                  price: parseFloat(v.price) || 0,
                  mrp: parseFloat(v.mrp) || 0,
                  costPrice: parseFloat(v.costPrice) || 0,
                  stock: parseInt(v.stock) || 0,
                }))
              : null,
        }),
      })

      if (res.ok) {
        const created = await res.json()
        setProducts([created, ...products])
        setAllProducts([created, ...allProducts])
        toast.success(`Product "${created.name}" created successfully!`)
        setShowAddProduct(false)
        setNewProductVariants([])
        setHasVariantsNew(false)
        setNewProduct({
          name: '',
          description: '',
          imageUrl: '',
          categoryId: categories?.[0]?.id || '',
          restaurantId: '',
          mrp: '',
          price: '',
          unit: '',
          stock: '',
          isAvailable: true,
          tags: '',
          minStock: '10',
          expiryDate: '',
          costPrice: '0',
          location: '',
          isFlashDeal: false,
          isTopPick: false,
          isBestSeller: false,
          sortOrder: '0',
          barcode: '',
          vendor: '',
          vendorId: '',
        })
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.error || 'Failed to create product')
      }
    } catch (err: any) {
      console.error('Error creating product:', err)
      toast.error(err?.message || 'Error creating product')
    } finally {
      setIsCreatingProduct(false)
    }
  }

  const handleDeleteProduct = async (productId: string) => {
    if (
      !confirm(
        '⚠️ Are you sure you want to PERMANENTLY delete this product? This action cannot be undone.'
      )
    ) {
      return
    }

    try {
      const res = await fetch(`/api/products/${productId}`, {
        method: 'DELETE',
      })

      if (res.ok) {
        setProducts(products.filter((p) => p.id !== productId))
        setAllProducts(allProducts.filter((p) => p.id !== productId))
        toast.success('Product permanently deleted.')
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to delete product')
      }
    } catch (err) {
      toast.error('Error deleting product')
    }
  }

  return {
    products,
    setProducts,
    allProducts,
    setAllProducts,
    productPage,
    setProductPage,
    productTotal,
    isLoadingProducts,
    searchQuery,
    setSearchQuery,
    selectedCategoryFilter,
    setSelectedCategoryFilter,
    selectedTypeFilter,
    setSelectedTypeFilter,
    editingProduct,
    setEditingProduct,
    savingProductId,
    setSavingProductId,
    productEditForm,
    setProductEditForm,
    showAddProduct,
    setShowAddProduct,
    showSortManager,
    setShowSortManager,
    showCsvImport,
    setShowCsvImport,
    showExportModal,
    setShowExportModal,
    isExporting,
    setIsExporting,
    isCreatingProduct,
    newProduct,
    setNewProduct,
    newProductType,
    setNewProductType,
    editProductType,
    setEditProductType,
    newCustomTag,
    setNewCustomTag,
    editCustomTag,
    setEditCustomTag,
    newProductVariants,
    setNewProductVariants,
    editProductVariants,
    setEditProductVariants,
    hasVariantsNew,
    setHasVariantsNew,
    hasVariantsEdit,
    setHasVariantsEdit,
    isNewProductCafe,
    isEditProductCafe,
    isNewProductRestaurant,
    isEditProductRestaurant,
    fetchProducts,
    handleNewProductTypeChange,
    handleEditProductTypeChange,
    applyProductTemplate,
    toggleTag,
    handleCreateCustomTag,
    handleDuplicateProduct,
    handleExportCsv,
    handleReplenishCsv,
    startEditingProduct,
    saveProductChanges,
    handleToggleProductAvailability,
    handleCreateProduct,
    handleDeleteProduct,
  }
}
