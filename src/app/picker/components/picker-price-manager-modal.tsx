'use client'

import { useState, useEffect, useTransition } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  X,
  Search,
  Tag,
  Package,
  Barcode,
  Edit2,
  RefreshCw,
  Plus,
  Loader2,
  AlertCircle,
  IndianRupee,
} from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { EditProductPriceModal, EditableGroceryProduct } from './edit-product-price-modal'

interface PickerPriceManagerModalProps {
  isOpen: boolean
  onClose: () => void
}

export function PickerPriceManagerModal({
  isOpen,
  onClose,
}: PickerPriceManagerModalProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [products, setProducts] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [editingProduct, setEditingProduct] = useState<EditableGroceryProduct | null>(null)
  const [isEditModalOpen, setIsEditModalOpen] = useState(false)

  const fetchProducts = async (q?: string) => {
    setIsLoading(true)
    try {
      const url = new URL('/api/picker/products', window.location.origin)
      if (q && q.trim()) {
        url.searchParams.set('search', q.trim())
      }
      url.searchParams.set('limit', '40')

      const res = await fetch(url.toString(), {
        headers: {
          'x-user-role': 'PICKER',
        },
      })
      const data = await res.json()
      if (res.ok && data.products) {
        setProducts(data.products)
      }
    } catch (e) {
      console.error('[PickerPriceManagerModal] fetch error:', e)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    if (isOpen) {
      fetchProducts(searchQuery)
    }
  }, [isOpen])

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    fetchProducts(searchQuery)
  }

  const handleOpenEdit = (prod: any) => {
    setEditingProduct({
      id: prod.id,
      name: prod.name,
      mrp: prod.mrp,
      price: prod.price,
      discount: prod.discount,
      stock: prod.stock,
      unit: prod.unit,
      imageUrl: prod.imageUrl,
      barcode: prod.barcode,
      location: prod.location,
      isAvailable: prod.isAvailable,
    })
    setIsEditModalOpen(true)
  }

  const handleProductUpdated = (updated: any) => {
    setProducts((prev) =>
      prev.map((p) => (p.id === updated.id ? { ...p, ...updated } : p))
    )
  }

  if (!isOpen) return null

  return (
    <>
      <div className="fixed inset-0 z-40 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-sm">
        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.96 }}
          className="relative w-full max-w-2xl max-h-[88vh] flex flex-col overflow-hidden bg-white rounded-2xl shadow-2xl border border-slate-200"
        >
          {/* Top Bar */}
          <div className="flex items-center justify-between p-4 bg-gradient-to-r from-blue-700 via-indigo-700 to-slate-800 text-white shrink-0">
            <div className="flex items-center gap-2.5">
              <div className="p-2 bg-white/20 rounded-xl backdrop-blur-sm">
                <Tag className="h-5 w-5 text-white" />
              </div>
              <div>
                <h3 className="text-sm sm:text-base font-black tracking-tight">
                  Grocery Catalog & Pricing
                </h3>
                <p className="text-[11px] text-white/80">
                  Search products, edit selling prices & inventory
                </p>
              </div>
            </div>
            <button
              onClick={onClose}
              className="h-8 w-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          {/* Search Header */}
          <div className="p-3 sm:p-4 border-b border-slate-100 bg-slate-50 shrink-0">
            <form onSubmit={handleSearch} className="flex gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search item name, barcode, or shelf..."
                  className="w-full pl-9 pr-3 py-2 text-xs sm:text-sm font-semibold bg-white border border-slate-200 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
                />
              </div>
              <button
                type="submit"
                disabled={isLoading}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-xl transition-colors shrink-0 flex items-center gap-1.5 cursor-pointer"
              >
                {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Search'}
              </button>
            </form>
          </div>

          {/* Product Items List */}
          <div className="flex-1 overflow-y-auto p-3 sm:p-4 space-y-2.5">
            {isLoading ? (
              <div className="flex flex-col items-center justify-center py-16 text-slate-400">
                <Loader2 className="h-8 w-8 animate-spin text-blue-500 mb-2" />
                <p className="text-xs font-semibold">Loading grocery catalog...</p>
              </div>
            ) : products.length === 0 ? (
              <div className="text-center py-12 text-slate-500 space-y-2">
                <Package className="h-10 w-10 text-slate-300 mx-auto" />
                <p className="text-xs font-bold">No grocery products found</p>
                <p className="text-[11px] text-slate-400">
                  Try searching with a different term or barcode.
                </p>
              </div>
            ) : (
              products.map((prod) => {
                const discount =
                  prod.mrp && prod.mrp > prod.price
                    ? Math.round(((prod.mrp - prod.price) / prod.mrp) * 100)
                    : 0
                return (
                  <div
                    key={prod.id}
                    className="p-3 bg-white border border-slate-200/80 rounded-xl shadow-sm hover:border-blue-300 transition-all flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="h-12 w-12 rounded-lg bg-slate-50 border border-slate-100 p-1 flex-shrink-0 flex items-center justify-center overflow-hidden">
                        <ProductImage
                          src={prod.imageUrl}
                          alt={prod.name}
                          className="h-full w-full object-contain"
                        />
                      </div>
                      <div className="min-w-0">
                        <h4 className="text-xs sm:text-sm font-extrabold text-slate-800 truncate">
                          {prod.name}
                        </h4>
                        <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                          {prod.unit && (
                            <span className="text-[10px] font-bold text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded">
                              {prod.unit}
                            </span>
                          )}
                          {prod.barcode && (
                            <span className="text-[10px] text-slate-400 font-mono">
                              SKU: {prod.barcode}
                            </span>
                          )}
                          {prod.location && (
                            <span className="text-[9px] font-bold text-amber-700 bg-amber-50 border border-amber-200/80 px-1 py-0.2 rounded">
                              📍 {prod.location}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-3 shrink-0">
                      {/* Price Strip */}
                      <div className="text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <span className="text-sm sm:text-base font-black text-slate-900">
                            ₹{prod.price}
                          </span>
                          {prod.mrp && prod.mrp > prod.price && (
                            <span className="text-[11px] text-slate-400 line-through">
                              ₹{prod.mrp}
                            </span>
                          )}
                        </div>
                        <div className="flex items-center justify-end gap-1 mt-0.5">
                          {discount > 0 && (
                            <span className="text-[9px] font-extrabold text-emerald-700 bg-emerald-50 border border-emerald-200 px-1 py-0.2 rounded">
                              {discount}% OFF
                            </span>
                          )}
                          <span className="text-[10px] font-semibold text-slate-400">
                            Stock: {prod.stock ?? 0}
                          </span>
                        </div>
                      </div>

                      {/* Edit Price Button */}
                      <button
                        onClick={() => handleOpenEdit(prod)}
                        className="px-3 py-1.5 bg-orange-50 hover:bg-orange-100 text-orange-700 border border-orange-200/80 rounded-xl text-xs font-black transition-colors flex items-center gap-1 cursor-pointer"
                      >
                        <Edit2 className="h-3 w-3" />
                        <span>Edit</span>
                      </button>
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </motion.div>
      </div>

      {/* Embedded Sub-Modal for Price Editing */}
      <EditProductPriceModal
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        product={editingProduct}
        onSuccess={handleProductUpdated}
      />
    </>
  )
}
