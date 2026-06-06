'use client'

import { useState, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { 
  Building2, 
  Search, 
  Plus, 
  Calendar, 
  IndianRupee, 
  Package, 
  Loader2,
  FileSpreadsheet,
  CheckCircle,
  HelpCircle
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { motion, AnimatePresence } from 'framer-motion'

interface Product {
  id: string
  name: string
  slug: string
  stock: number
  price: number
  mrp: number
  costPrice: number
  imageUrl: string | null
  category: {
    name: string
  }
}

interface AdminInwardProps {
  onInwardCompleted?: () => void
}

export function AdminInward({ onInwardCompleted }: AdminInwardProps) {
  const [products, setProducts] = useState<Product[]>([])
  const [loadingProducts, setLoadingProducts] = useState(true)
  const [search, setSearch] = useState('')
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null)
  
  // GRN Form States
  const [quantity, setQuantity] = useState('50')
  const [costPrice, setCostPrice] = useState('')
  const [expiryDate, setExpiryDate] = useState('')
  const [batchCode, setBatchCode] = useState('')
  const [submitting, setSubmitting] = useState(false)

  // Success logs for session
  const [recentLogs, setRecentLogs] = useState<Array<{
    id: string
    productName: string
    batchCode: string
    quantity: number
    costPrice: number
    expiryDate: string
    timestamp: string
  }>>([])

  // Load products list on mount
  const fetchProducts = async () => {
    try {
      setLoadingProducts(true)
      const res = await fetch('/api/products?limit=1000')
      if (!res.ok) throw new Error('Failed to load products')
      const data = await res.json()
      setProducts(data.products || [])
    } catch (err) {
      console.error(err)
      toast.error('Could not load products catalog')
    } finally {
      setLoadingProducts(false)
    }
  }

  useEffect(() => {
    fetchProducts()
  }, [])

  // Auto-generate batch code and suggest cost price when product changes
  useEffect(() => {
    if (selectedProduct) {
      // Suggest costPrice (existing costPrice or 75% of price as a smart fallback)
      setCostPrice(String(selectedProduct.costPrice > 0 ? selectedProduct.costPrice : Math.round(selectedProduct.price * 0.75)))
      
      // Auto-generate standard batch code: B_YYYYMMDD_[4 random alphanumeric chars]
      const today = new Date().toISOString().split('T')[0].replace(/-/g, '')
      const rand = Math.random().toString(36).slice(2, 6).toUpperCase()
      setBatchCode(`B_${today}_${rand}`)
    } else {
      setCostPrice('')
      setBatchCode('')
    }
  }, [selectedProduct])

  // Filter products by search input
  const filteredProducts = useMemo(() => {
    if (!search.trim()) return []
    return products.filter(p => 
      p.name.toLowerCase().includes(search.toLowerCase()) || 
      p.category.name.toLowerCase().includes(search.toLowerCase())
    ).slice(0, 5) // Show top 5 matches
  }, [search, products])

  // Expiry Date Presets helpers
  const applyExpiryPreset = (months: number) => {
    const d = new Date()
    d.setMonth(d.getMonth() + months)
    setExpiryDate(d.toISOString().split('T')[0])
  }

  // Handle GRN submission
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedProduct) {
      toast.error('Please select a product first')
      return
    }

    if (!batchCode.trim() || !quantity || !costPrice || !expiryDate) {
      toast.error('Please fill in all details')
      return
    }

    try {
      setSubmitting(true)
      const res = await fetch('/api/admin/inward', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          productId: selectedProduct.id,
          batchCode: batchCode.trim(),
          quantity: parseInt(quantity, 10),
          costPrice: parseFloat(costPrice),
          expiryDate: new Date(expiryDate).toISOString()
        })
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to inward product batch')
      }

      const data = await res.json()
      toast.success(data.message || 'Product Batch registered successfully!')
      
      // Add to session log
      setRecentLogs(prev => [
        {
          id: Math.random().toString(),
          productName: selectedProduct.name,
          batchCode: batchCode.trim(),
          quantity: parseInt(quantity, 10),
          costPrice: parseFloat(costPrice),
          expiryDate,
          timestamp: new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
        },
        ...prev
      ])

      // Re-trigger product catalog updates
      await fetchProducts()
      if (onInwardCompleted) onInwardCompleted()

      // Reset form states selectively (keep quantity and expiry presets for rapid subsequent entries)
      setSelectedProduct(null)
      setSearch('')
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error processing batch inwarding')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <motion.div 
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, ease: 'easeOut' }}
      className="grid grid-cols-1 lg:grid-cols-3 gap-6"
    >
      
      {/* Search and Parameter selection columns */}
      <div className="lg:col-span-2 space-y-6">
        
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          <div>
            <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
              <Building2 className="h-5 w-5 text-accent animate-pulse-slow" />
              Goods Receipt Note (GRN) Inwarding
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Inward new catalog shipments, create trackable expiry-date batches, and update stock aggregates.
            </p>
          </div>

          <div className="space-y-4">
            {/* Product search bar */}
            <div className="space-y-1 relative">
              <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">1. Search Catalog Product</label>
              <div className="relative">
                <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                <input
                  type="text"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Type product name (e.g. Milk, Onion, Atta)..."
                  className="w-full bg-muted/40 border border-border/80 pl-9 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-primary focus:bg-card font-semibold"
                />
              </div>

              {/* Dynamic search suggestions */}
              <AnimatePresence>
                {search.trim() !== '' && filteredProducts.length > 0 && !selectedProduct && (
                  <motion.div 
                    initial={{ opacity: 0, y: -10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: -10, scale: 0.95 }}
                    transition={{ duration: 0.2 }}
                    className="absolute z-20 w-full bg-card border border-border rounded-xl shadow-lg mt-1 overflow-hidden divide-y divide-border/60"
                  >
                    {filteredProducts.map((p) => (
                      <button
                        key={p.id}
                        type="button"
                        onClick={() => {
                          setSelectedProduct(p)
                          setSearch(p.name)
                        }}
                        className="w-full text-left px-4 py-2.5 hover:bg-muted/50 transition-colors flex items-center justify-between text-xs font-semibold"
                      >
                        <div className="flex items-center gap-3">
                          <span className="text-lg">{p.imageUrl || '📦'}</span>
                          <div>
                            <span className="text-text-primary block leading-tight">{p.name}</span>
                            <span className="text-[10px] text-text-muted block mt-0.5">{p.category.name}</span>
                          </div>
                        </div>
                        <div className="text-right shrink-0">
                          <span className="text-[10px] text-text-secondary block">Stock: {p.stock} units</span>
                          <span className="text-[10px] text-accent block font-bold">MRP: {formatPrice(p.mrp)}</span>
                        </div>
                      </button>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            {/* Selected Product Context Banner */}
            <AnimatePresence mode="wait">
              {selectedProduct && (
                <motion.div
                  initial={{ opacity: 0, height: 0, y: -10 }}
                  animate={{ opacity: 1, height: 'auto', y: 0 }}
                  exit={{ opacity: 0, height: 0, y: -10 }}
                  transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                  className="p-4 rounded-xl border border-accent/20 bg-accent/5 flex items-center justify-between text-xs overflow-hidden"
                >
                  <div className="flex items-center gap-3">
                    <span className="text-2xl">{selectedProduct.imageUrl || '📦'}</span>
                    <div>
                      <h4 className="font-bold text-text-primary">{selectedProduct.name}</h4>
                      <p className="text-[10px] text-text-muted mt-0.5">
                        Current Database Stock: <strong className="text-text-primary font-bold">{selectedProduct.stock} units</strong>
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className="text-[10px] text-text-secondary block">Retail Price: {formatPrice(selectedProduct.price)}</span>
                    <span className="text-[10px] text-text-muted block">MRP: {formatPrice(selectedProduct.mrp)}</span>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Batch parameters entry form */}
            <AnimatePresence>
              {selectedProduct && (
                <motion.form
                  onSubmit={handleSubmit}
                  initial={{ opacity: 0, height: 0, y: -20 }}
                  animate={{ opacity: 1, height: 'auto', y: 0 }}
                  exit={{ opacity: 0, height: 0, y: -20 }}
                  transition={{ type: 'spring', stiffness: 350, damping: 28 }}
                  className="space-y-4 pt-2 border-t border-border/40 overflow-hidden"
                >
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    
                    {/* Batch Code */}
                    <div className="space-y-1">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Batch Identification Code</label>
                      <input
                        type="text"
                        required
                        value={batchCode}
                        onChange={(e) => setBatchCode(e.target.value.toUpperCase())}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-mono font-bold"
                      />
                    </div>

                    {/* Quantity received with quick presets */}
                    <div className="space-y-1">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Quantity Received (units)</label>
                      <div className="flex gap-2">
                        <input
                          type="number"
                          min="1"
                          required
                          value={quantity}
                          onChange={(e) => setQuantity(e.target.value)}
                          className="w-24 bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                        />
                        {/* Presets */}
                        {['20', '50', '100', '200'].map((qty) => (
                          <button
                            key={qty}
                            type="button"
                            onClick={() => setQuantity(qty)}
                            className={`flex-1 border text-[10px] font-bold rounded-lg transition-colors cursor-pointer ${
                              quantity === qty ? 'bg-primary text-white border-primary' : 'bg-card border-border text-text-secondary hover:bg-muted/50'
                            }`}
                          >
                            +{qty}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Cost Price */}
                    <div className="space-y-1">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Batch Cost Price (₹ Per Unit)</label>
                      <div className="relative">
                        <IndianRupee className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
                        <input
                          type="number"
                          step="0.01"
                          min="0"
                          required
                          value={costPrice}
                          onChange={(e) => setCostPrice(e.target.value)}
                          placeholder="Cost of purchase"
                          className="w-full bg-muted/40 border border-border pl-8 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-accent"
                        />
                      </div>
                    </div>

                    {/* Expiry Date with quick presets */}
                    <div className="space-y-1">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Expiry Date</label>
                      <div className="space-y-2">
                        <div className="relative">
                          <Calendar className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                          <input
                            type="date"
                            required
                            value={expiryDate}
                            onChange={(e) => setExpiryDate(e.target.value)}
                            className="w-full bg-muted/40 border border-border pl-9 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                          />
                        </div>
                        {/* Presets */}
                        <div className="flex gap-1.5 overflow-x-auto scrollbar-hide py-0.5">
                          {[
                            { label: '+10 Days', val: 0.33 },
                            { label: '+1 Month', val: 1 },
                            { label: '+3 Months', val: 3 },
                            { label: '+6 Months', val: 6 },
                            { label: '+1 Year', val: 12 }
                          ].map((p) => (
                            <button
                              key={p.label}
                              type="button"
                              onClick={() => {
                                // If +10 days
                                if (p.val === 0.33) {
                                  const d = new Date()
                                  d.setDate(d.getDate() + 10)
                                  setExpiryDate(d.toISOString().split('T')[0])
                                } else {
                                  applyExpiryPreset(p.val)
                                }
                              }}
                              className="flex-1 py-1 px-1.5 border border-border text-[9px] font-bold rounded bg-card text-text-secondary hover:bg-muted/50 transition-colors whitespace-nowrap cursor-pointer"
                            >
                              {p.label}
                            </button>
                          ))}
                        </div>
                      </div>
                    </div>

                  </div>

                  {/* Submitting GRN action button */}
                  <div className="pt-4 border-t border-border/40">
                    <button
                      type="submit"
                      disabled={submitting}
                      className="w-full h-10 rounded-xl bg-accent hover:bg-accent-dark text-white font-black text-xs transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60 cursor-pointer shadow active:scale-98"
                    >
                      {submitting ? (
                        <>
                          <Loader2 className="h-4 w-4 animate-spin" />
                          Logging Shipment GRN into database...
                        </>
                      ) : (
                        <>
                          <Plus className="h-4 w-4" />
                          Register Incoming Batch (Inward GRN)
                        </>
                      )}
                    </button>
                  </div>
                </motion.form>
              )}
            </AnimatePresence>

            {/* Informational banner when no product is picked */}
            <AnimatePresence>
              {!selectedProduct && (
                <motion.div 
                  initial={{ opacity: 0, scale: 0.98 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.98 }}
                  className="p-10 border border-dashed border-border rounded-xl text-center bg-muted/10 text-xs text-text-secondary"
                >
                  <Package className="h-10 w-10 text-text-muted mx-auto mb-2" />
                  Select a product from the search query above to inward a new batch.
                </motion.div>
              )}
            </AnimatePresence>

          </div>
        </div>

      </div>

      {/* Session Logs Panel Column */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between">
        <div className="space-y-4">
          <div className="flex items-center gap-2 border-b border-border/60 pb-3">
            <FileSpreadsheet className="h-5 w-5 text-accent animate-pulse-slow" />
            <div>
              <h4 className="text-sm font-bold text-text-primary">Inwarding Logs (This Session)</h4>
              <p className="text-[10px] text-text-muted">A summary of batches registered just now.</p>
            </div>
          </div>

          <div className="max-h-[380px] overflow-y-auto pr-1">
            <AnimatePresence initial={false} mode="popLayout">
              {recentLogs.length === 0 ? (
                <motion.div 
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="py-20 text-center text-xs text-text-secondary"
                >
                  No batches inwarded during this session.
                </motion.div>
              ) : (
                <div className="space-y-3">
                  {recentLogs.map((log) => (
                    <motion.div
                      key={log.id}
                      layout
                      initial={{ opacity: 0, x: 30, scale: 0.95 }}
                      animate={{ opacity: 1, x: 0, scale: 1 }}
                      exit={{ opacity: 0, x: -30, scale: 0.95 }}
                      transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                      className="p-3 bg-muted/20 border border-border/80 rounded-xl space-y-1.5"
                    >
                      <div className="flex justify-between items-center text-[10px]">
                        <span className="font-extrabold text-accent bg-accent/5 px-2 py-0.5 rounded border border-accent/15">
                          {log.batchCode}
                        </span>
                        <span className="text-text-muted">{log.timestamp}</span>
                      </div>
                      
                      <div className="text-xs">
                        <strong className="text-text-primary block font-extrabold leading-tight">{log.productName}</strong>
                        <span className="text-text-secondary block mt-0.5">
                          Quantity: <strong className="text-text-primary font-extrabold">+{log.quantity} units</strong> @ {formatPrice(log.costPrice)}/unit
                        </span>
                        <span className="text-[10px] text-red-500 font-semibold block mt-1">
                          Expiry: {new Date(log.expiryDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                        </span>
                      </div>
                    </motion.div>
                  ))}
                </div>
              )}
            </AnimatePresence>
          </div>
        </div>

        <div className="mt-4 pt-4 border-t border-border/60 text-[9px] text-text-muted flex items-start gap-1">
          <CheckCircle className="h-3.5 w-3.5 text-accent shrink-0 mt-0.5" />
          <span>Completed in-session batches are logged permanently. You can audit and search their stocks inside the Alerts & Analytics tabs.</span>
        </div>
      </div>

    </motion.div>
  )
}
