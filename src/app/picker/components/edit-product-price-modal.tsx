'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, Tag, IndianRupee, Package, Check, AlertCircle, Loader2, Layers, Plus, Trash2 } from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { toast } from 'sonner'

export interface EditableGroceryProduct {
  id: string
  name: string
  mrp?: number | null
  price: number
  discount?: number | null
  stock?: number | null
  unit?: string | null
  imageUrl?: string | null
  barcode?: string | null
  location?: string | null
  isAvailable?: boolean | null
  variants?: any[] | null
}

interface EditProductPriceModalProps {
  isOpen: boolean
  onClose: () => void
  product: EditableGroceryProduct | null
  onSuccess?: (updatedProduct: any) => void
}

export function EditProductPriceModal({
  isOpen,
  onClose,
  product,
  onSuccess,
}: EditProductPriceModalProps) {
  const [mrp, setMrp] = useState<string>('')
  const [price, setPrice] = useState<string>('')
  const [stock, setStock] = useState<string>('')
  const [isAvailable, setIsAvailable] = useState<boolean>(true)
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const [variants, setVariants] = useState<any[]>([])
  const [showAddVariant, setShowAddVariant] = useState(false)
  const [varName, setVarName] = useState('')
  const [varPrice, setVarPrice] = useState('')
  const [varMrp, setVarMrp] = useState('')
  const [varStock, setVarStock] = useState('20')

  useEffect(() => {
    if (product) {
      setMrp(product.mrp ? String(product.mrp) : String(product.price))
      setPrice(String(product.price))
      setStock(product.stock !== undefined && product.stock !== null ? String(product.stock) : '20')
      setIsAvailable(product.isAvailable !== false && (product.stock ?? 1) > 0)
      const rawVars = (product as any).variants
      if (Array.isArray(rawVars)) {
        setVariants(rawVars)
      } else if (typeof rawVars === 'string' && rawVars.trim()) {
        try {
          const parsed = JSON.parse(rawVars)
          if (Array.isArray(parsed)) setVariants(parsed)
        } catch (_) {}
      } else {
        setVariants([])
      }
      setShowAddVariant(false)
      setErrorMsg(null)
    }
  }, [product, isOpen])

  if (!isOpen || !product) return null

  const parsedMrp = parseFloat(mrp) || 0
  const parsedPrice = parseFloat(price) || 0
  const parsedStock = parseInt(stock, 10) || 0

  const computedDiscount =
    parsedMrp > parsedPrice && parsedMrp > 0
      ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100))
      : 0

  const isInvalidPrice = parsedPrice > parsedMrp && parsedMrp > 0

  const handleAddVariant = () => {
    if (!varName.trim()) {
      setErrorMsg('Variant name is required (e.g. 500g, 1kg)')
      return
    }
    const vp = parseFloat(varPrice) || 0
    const vm = parseFloat(varMrp) || vp
    if (vp <= 0) {
      setErrorMsg('Variant selling price must be greater than ₹0')
      return
    }
    if (vp > vm && vm > 0) {
      setErrorMsg('Variant selling price cannot exceed MRP')
      return
    }
    setVariants((prev) => [
      ...prev,
      {
        name: varName.trim(),
        price: vp,
        mrp: vm,
        stock: parseInt(varStock, 10) || 20,
      },
    ])
    setVarName('')
    setVarPrice('')
    setVarMrp('')
    setVarStock('20')
    setShowAddVariant(false)
    setErrorMsg(null)
  }

  const handleRemoveVariant = (idx: number) => {
    setVariants((prev) => prev.filter((_, i) => i !== idx))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMsg(null)

    if (parsedMrp <= 0) {
      setErrorMsg('MRP must be greater than ₹0')
      return
    }

    if (parsedPrice <= 0) {
      setErrorMsg('Selling price must be greater than ₹0')
      return
    }

    if (parsedPrice > parsedMrp) {
      setErrorMsg(`Selling price (₹${parsedPrice}) cannot exceed MRP (₹${parsedMrp})`)
      return
    }

    setIsSubmitting(true)
    try {
      const res = await fetch('/api/picker/products', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'x-user-role': 'PICKER',
        },
        body: JSON.stringify({
          productId: product.id,
          mrp: parsedMrp,
          price: parsedPrice,
          stock: parsedStock,
          isAvailable: isAvailable && parsedStock > 0,
          variants: variants,
        }),
      })

      const data = await res.json()

      if (!res.ok) {
        throw new Error(data.error || 'Failed to update pricing')
      }

      toast.success('Price Updated! 🛒', {
        description: `${product.name} set to ₹${parsedPrice} (${computedDiscount}% OFF)`,
      })

      if (onSuccess) {
        onSuccess(data.product)
      }
      onClose()
    } catch (err: any) {
      setErrorMsg(err?.message || 'Failed to update product pricing')
      toast.error('Price update failed', {
        description: err?.message,
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 15 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 15 }}
          className="relative w-full max-w-md overflow-hidden bg-white rounded-2xl shadow-2xl border border-gray-100"
        >
          {/* Header Banner */}
          <div className="flex items-center justify-between p-4 bg-gradient-to-r from-orange-500 to-amber-600 text-white">
            <div className="flex items-center gap-2.5">
              <div className="p-2 bg-white/20 rounded-xl backdrop-blur-md">
                <Tag className="h-5 w-5 text-white" />
              </div>
              <div>
                <h3 className="text-sm font-black tracking-tight">Edit Grocery Pricing</h3>
                <p className="text-[11px] text-white/80 font-medium">Dark Store Inventory Control</p>
              </div>
            </div>
            <button
              onClick={onClose}
              className="h-8 w-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          {/* Product Summary Card */}
          <div className="p-4 bg-slate-50 border-b border-slate-100 flex items-center gap-3">
            <div className="h-12 w-12 bg-white rounded-xl border border-slate-200 p-1 flex-shrink-0 flex items-center justify-center overflow-hidden shadow-sm">
              <ProductImage
                src={product.imageUrl || ''}
                alt={product.name}
                className="h-full w-full object-contain"
              />
            </div>
            <div className="min-w-0 flex-1">
              <h4 className="text-xs sm:text-sm font-black text-slate-800 line-clamp-1">
                {product.name}
              </h4>
              <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                {product.unit && (
                  <span className="text-[10px] text-slate-500 font-bold bg-slate-200/70 px-1.5 py-0.5 rounded">
                    {product.unit}
                  </span>
                )}
                {product.barcode && (
                  <span className="text-[10px] text-slate-500 font-mono">
                    SKU: {product.barcode}
                  </span>
                )}
                {product.location && (
                  <span className="text-[10px] text-amber-700 bg-amber-100/80 px-1.5 py-0.5 rounded font-bold">
                    📍 {product.location}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="p-4 sm:p-5 space-y-4">
            {errorMsg && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-xl flex items-center gap-2 text-red-700 text-xs font-semibold animate-shake">
                <AlertCircle className="h-4 w-4 shrink-0 text-red-500" />
                <span>{errorMsg}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              {/* MRP Field */}
              <div>
                <label className="block text-[11px] font-black uppercase tracking-wider text-slate-600 mb-1.5">
                  MRP (₹) <span className="text-red-500">*</span>
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-400">
                    <IndianRupee className="h-4 w-4" />
                  </div>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    required
                    value={mrp}
                    onChange={(e) => setMrp(e.target.value)}
                    placeholder="100.00"
                    className="w-full pl-8 pr-3 py-2.5 text-sm font-black text-slate-800 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 outline-none transition-all"
                  />
                </div>
              </div>

              {/* Selling Price Field */}
              <div>
                <label className="block text-[11px] font-black uppercase tracking-wider text-slate-600 mb-1.5">
                  Selling Price (₹) <span className="text-red-500">*</span>
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-orange-500">
                    <IndianRupee className="h-4 w-4" />
                  </div>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    required
                    value={price}
                    onChange={(e) => setPrice(e.target.value)}
                    placeholder="85.00"
                    className={`w-full pl-8 pr-3 py-2.5 text-sm font-black text-slate-800 bg-slate-50 border rounded-xl focus:bg-white outline-none transition-all ${
                      isInvalidPrice
                        ? 'border-red-400 focus:border-red-500 focus:ring-2 focus:ring-red-500/20'
                        : 'border-slate-200 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20'
                    }`}
                  />
                </div>
              </div>
            </div>

            {/* Live Discount & Feedback Badge */}
            <div className="p-2.5 bg-gradient-to-r from-orange-50 to-amber-50 rounded-xl border border-orange-200/60 flex items-center justify-between">
              <span className="text-xs font-bold text-slate-600">Calculated Discount:</span>
              <div className="flex items-center gap-1.5">
                {isInvalidPrice ? (
                  <span className="text-[11px] font-black text-red-600">
                    ⚠️ Price cannot exceed MRP
                  </span>
                ) : (
                  <span className="px-2 py-0.5 bg-emerald-100 text-emerald-800 border border-emerald-300 rounded text-xs font-black">
                    {computedDiscount}% OFF
                  </span>
                )}
              </div>
            </div>

            {/* Stock Count */}
            <div>
              <label className="block text-[11px] font-black uppercase tracking-wider text-slate-600 mb-1.5">
                Stock Quantity (Units)
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-400">
                  <Package className="h-4 w-4" />
                </div>
                <input
                  type="number"
                  min="0"
                  value={stock}
                  onChange={(e) => setStock(e.target.value)}
                  placeholder="20"
                  className="w-full pl-8 pr-3 py-2.5 text-sm font-bold text-slate-800 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 outline-none transition-all"
                />
              </div>
            </div>

            {/* Product Variants Section */}
            <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <Layers className="h-4 w-4 text-orange-600" />
                  <span className="text-xs font-black text-slate-800">
                    Product Variants ({variants.length})
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddVariant(!showAddVariant)}
                  className="px-2 py-1 bg-orange-100 hover:bg-orange-200 text-orange-700 text-[11px] font-black rounded-lg transition-colors flex items-center gap-1 cursor-pointer"
                >
                  <Plus className="h-3.5 w-3.5" />
                  <span>{showAddVariant ? 'Close' : 'Add Variant'}</span>
                </button>
              </div>

              {/* Add Variant Mini-Form */}
              {showAddVariant && (
                <div className="p-3 bg-white border border-orange-200 rounded-xl space-y-2 animate-fade-in shadow-sm">
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="block text-[10px] font-bold text-slate-600">Name</label>
                      <input
                        type="text"
                        placeholder="e.g. 1 kg"
                        value={varName}
                        onChange={(e) => setVarName(e.target.value)}
                        className="w-full px-2 py-1.5 text-xs font-bold bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-orange-500"
                      />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-slate-600">Stock</label>
                      <input
                        type="number"
                        placeholder="20"
                        value={varStock}
                        onChange={(e) => setVarStock(e.target.value)}
                        className="w-full px-2 py-1.5 text-xs font-bold bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-orange-500"
                      />
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="block text-[10px] font-bold text-slate-600">MRP (₹)</label>
                      <input
                        type="number"
                        placeholder="100"
                        value={varMrp}
                        onChange={(e) => setVarMrp(e.target.value)}
                        className="w-full px-2 py-1.5 text-xs font-bold bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-orange-500"
                      />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-orange-600">Price (₹)</label>
                      <input
                        type="number"
                        placeholder="85"
                        value={varPrice}
                        onChange={(e) => setVarPrice(e.target.value)}
                        className="w-full px-2 py-1.5 text-xs font-bold bg-orange-50 border border-orange-200 rounded-lg outline-none focus:border-orange-500"
                      />
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={handleAddVariant}
                    className="w-full py-1.5 bg-orange-600 hover:bg-orange-700 text-white text-xs font-black rounded-lg transition-colors cursor-pointer"
                  >
                    + Save Variant to List
                  </button>
                </div>
              )}

              {/* Variants List */}
              {variants.length === 0 ? (
                <p className="text-[11px] text-slate-400 italic">No pack variants configured (using single unit price above)</p>
              ) : (
                <div className="space-y-1.5 max-h-36 overflow-y-auto">
                  {variants.map((v, i) => (
                    <div
                      key={i}
                      className="p-2 bg-white border border-slate-200 rounded-lg flex items-center justify-between gap-2 shadow-2xs"
                    >
                      <div className="min-w-0">
                        <span className="text-xs font-black text-slate-800">{v.name}</span>
                        <div className="flex items-center gap-1.5 text-[10px] text-slate-500">
                          <span className="font-bold text-orange-600">₹{v.price}</span>
                          {v.mrp && v.mrp > v.price && (
                            <span className="line-through">₹{v.mrp}</span>
                          )}
                          <span>• Stock: {v.stock ?? 20}</span>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleRemoveVariant(i)}
                        className="p-1 hover:bg-red-50 text-slate-400 hover:text-red-500 rounded transition-colors cursor-pointer"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* In Stock Toggle */}
            <div className="flex items-center justify-between p-3 bg-slate-50 border border-slate-200 rounded-xl">
              <div>
                <span className="text-xs font-black text-slate-800">In Stock for Customers</span>
                <p className="text-[10px] text-slate-500">Instantly activates item on FastKirana</p>
              </div>
              <button
                type="button"
                onClick={() => setIsAvailable(!isAvailable)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer ${
                  isAvailable && parsedStock > 0 ? 'bg-emerald-500' : 'bg-slate-300'
                }`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    isAvailable && parsedStock > 0 ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-2.5 pt-2">
              <button
                type="button"
                onClick={onClose}
                disabled={isSubmitting}
                className="flex-1 py-2.5 text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting || isInvalidPrice}
                className="flex-1 py-2.5 text-xs font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed rounded-xl transition-all shadow-md shadow-orange-500/20 flex items-center justify-center gap-1.5 cursor-pointer"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <>
                    <Check className="h-4 w-4 stroke-[3]" />
                    <span>Save Pricing</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </motion.div>
      </div>
    </AnimatePresence>
  )
}
