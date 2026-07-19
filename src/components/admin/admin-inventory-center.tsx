'use client'

import { useState, useEffect, useMemo, useRef } from 'react'
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
  HelpCircle,
  QrCode,
  ShoppingCart,
  Trash2,
  RotateCcw,
  Sparkles,
  ArrowRight,
  TrendingDown,
  Activity,
  History,
  Tag,
  AlertCircle,
  Camera
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { motion, AnimatePresence } from 'framer-motion'

interface Product {
  id: string
  readableId?: number
  barcode?: string | null
  name: string
  mrp: number
  price: number
  stock: number
  unit: string
  imageUrl: string | null
  categoryName: string
  categorySlug: string
  costPrice: number
}

interface CartItem {
  product: Product
  quantity: number
  price: number // can be edited at the counter
}

interface StockHistoryLog {
  id: string
  productId: string
  quantity: number
  type: 'INWARD_GRN' | 'RETAIL_POS' | 'ONLINE_ORDER' | 'MANUAL_ADJUST' | 'BULK_IMPORT'
  prevStock: number
  newStock: number
  createdAt: string
  product?: {
    name: string
    readableId: number
    barcode?: string
    unit: string
  }
}

export function AdminInventoryCenter() {
  const [activeTab, setActiveTab] = useState<'inward' | 'pos' | 'import' | 'history'>('inward')
  
  // Shared state: products catalog (loaded on mount)
  const [products, setProducts] = useState<Product[]>([])
  const [categories, setCategories] = useState<Array<{ id: string, name: string, slug: string }>>([])
  const [loadingCatalog, setLoadingCatalog] = useState(true)

  const fetchCatalog = async () => {
    try {
      setLoadingCatalog(true)
      const res = await fetch('/api/products?limit=1000')
      if (!res.ok) throw new Error('Failed to load products')
      const data = await res.json()
      setProducts(data.products || [])
      
      const catRes = await fetch('/api/categories')
      if (catRes.ok) {
        const catData = await catRes.json()
        setCategories(catData.categories || [])
      }
    } catch (err) {
      console.error(err)
      toast.error('Could not load catalog')
    } finally {
      setLoadingCatalog(false)
    }
  }

  useEffect(() => {
    fetchCatalog()
  }, [])

  // =========================================================================
  // TAB 1: QUICK INWARD & SCAN (BLINKIT-STYLE)
  // =========================================================================
  const [inwardBarcode, setInwardBarcode] = useState('')
  const [searchingMaster, setSearchingMaster] = useState(false)
  const [scannedProduct, setScannedProduct] = useState<any | null>(null) // holds found DB product or Master product or new placeholder
  const [inwardQty, setInwardQty] = useState('50')
  const [inwardCost, setInwardCost] = useState('')
  const [inwardExpiry, setInwardExpiry] = useState('')
  const [inwardBatchCode, setInwardBatchCode] = useState('')
  const [submittingInward, setSubmittingInward] = useState(false)

  // Link barcode to existing product states
  const [isLinkingMode, setIsLinkingMode] = useState(false)
  const [linkSearchQuery, setLinkSearchQuery] = useState('')

  // Refs for auto-focus jumps
  const barcodeInputRef = useRef<HTMLInputElement>(null)
  const qtyInputRef = useRef<HTMLInputElement>(null)

  // Camera scanner states for Inward
  const [isInwardCameraScanning, setIsInwardCameraScanning] = useState(false)
  const inwardVideoRef = useRef<HTMLVideoElement>(null)
  const inwardVideoStreamRef = useRef<MediaStream | null>(null)

  const startInwardCamera = async () => {
    setIsInwardCameraScanning(true)
  }

  const stopInwardCamera = () => {
    setIsInwardCameraScanning(false)
    if (inwardVideoStreamRef.current) {
      inwardVideoStreamRef.current.getTracks().forEach(track => track.stop())
      inwardVideoStreamRef.current = null
    }
  }

  useEffect(() => {
    if (isInwardCameraScanning) {
      navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      }).then(stream => {
        inwardVideoStreamRef.current = stream
        if (inwardVideoRef.current) {
          inwardVideoRef.current.srcObject = stream
        }
      }).catch(err => {
        console.warn('Camera access error:', err)
        toast.error('Could not access camera. Please check permissions.')
        setIsInwardCameraScanning(false)
      })
    } else {
      if (inwardVideoStreamRef.current) {
        inwardVideoStreamRef.current.getTracks().forEach(track => track.stop())
        inwardVideoStreamRef.current = null
      }
    }
    return () => {
      if (inwardVideoStreamRef.current) {
        inwardVideoStreamRef.current.getTracks().forEach(track => track.stop())
      }
    }
  }, [isInwardCameraScanning])

  // Focus scanner on tab switch & mount
  useEffect(() => {
    if (activeTab === 'inward' && barcodeInputRef.current) {
      barcodeInputRef.current.focus()
    }
  }, [activeTab])

  // Trigger search when barcode is entered (supports handheld scanner instant submit)
  const handleBarcodeSubmit = async (e?: React.FormEvent, customBarcode?: string) => {
    if (e) e.preventDefault()
    const barcodeToSearch = (customBarcode || inwardBarcode).trim()
    if (!barcodeToSearch) return

    if (customBarcode) {
      setInwardBarcode(customBarcode)
    }

    try {
      setSearchingMaster(true)
      setScannedProduct(null)
      setIsLinkingMode(false)

      const res = await fetch(`/api/admin/inventory/master-lookup?barcode=${barcodeToSearch}`)
      if (!res.ok) throw new Error('Master lookup failed')
      const data = await res.json()

      if (data.exists) {
        // Exists in active store catalog
        setScannedProduct({
          ...data.product,
          status: 'exists'
        })
        setInwardCost(String(data.product.costPrice > 0 ? data.product.costPrice : Math.round(data.product.price * 0.75)))
        
        // Auto-generate batch code
        const today = new Date().toISOString().split('T')[0].replace(/-/g, '')
        const rand = Math.random().toString(36).slice(2, 6).toUpperCase()
        setInwardBatchCode(`B_${today}_${rand}`)

        // Jump focus to quantity input
        setTimeout(() => qtyInputRef.current?.focus(), 150)
      } else if (data.foundInMaster) {
        // Exists in Master Catalog (Blinkit Auto-fill!)
        setScannedProduct({
          ...data.product,
          status: 'master'
        })
        setInwardCost(String(Math.round(data.product.price * 0.75)))
        
        const today = new Date().toISOString().split('T')[0].replace(/-/g, '')
        const rand = Math.random().toString(36).slice(2, 6).toUpperCase()
        setInwardBatchCode(`B_${today}_${rand}`)

        toast.success(`✨ Blinkit Auto-fill: Found "${data.product.name}" in Master Catalog!`, { duration: 3000 })
        setTimeout(() => qtyInputRef.current?.focus(), 150)
      } else {
        // Not found anywhere -> Open Add New Product form
        setScannedProduct({
          barcode: barcodeToSearch,
          name: '',
          brand: '',
          categoryId: categories[0]?.id || '',
          mrp: 0,
          price: 0,
          unit: '1 pc',
          imageUrl: '',
          status: 'new'
        })
        toast.info('Barcode not found. Please create a new product entry.', { duration: 3000 })
      }
    } catch (err) {
      console.error(err)
      toast.error('Barcode lookup failed')
    } finally {
      setSearchingMaster(false)
    }
  }

  // Barcode Detection Loop
  useEffect(() => {
    if (!isInwardCameraScanning) return

    let active = true
    let barcodeDetector: any = null

    if (typeof window !== 'undefined' && 'BarcodeDetector' in window) {
      try {
        // @ts-ignore
        barcodeDetector = new window.BarcodeDetector({
          formats: ['ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'qr_code']
        })
      } catch (e) {
        console.warn('BarcodeDetector initialization failed:', e)
      }
    }

    const checkFrame = async () => {
      if (!active || !isInwardCameraScanning || !inwardVideoRef.current) return

      const video = inwardVideoRef.current
      if (video.readyState === video.HAVE_ENOUGH_DATA && barcodeDetector) {
        try {
          const barcodes = await barcodeDetector.detect(video)
          if (barcodes && barcodes.length > 0 && active) {
            const code = barcodes[0].rawValue
            toast.success(`📸 Barcode detected: ${code}`)
            handleBarcodeSubmit(undefined, code)
            active = false
            stopInwardCamera()
            return
          }
        } catch (err) {
          // ignore single frame errors
        }
      }
      
      if (active) {
        requestAnimationFrame(checkFrame)
      }
    }

    const timeout = setTimeout(() => {
      if (active) {
        checkFrame()
      }
    }, 1000)

    return () => {
      active = false
      clearTimeout(timeout)
    }
  }, [isInwardCameraScanning])

  // Handle Inward Register Submit
  const handleInwardSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!scannedProduct) return

    if (scannedProduct.status === 'new' || scannedProduct.status === 'master') {
      // 1. We must create the product first
      try {
        setSubmittingInward(true)
        const createRes = await fetch('/api/admin/products', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: scannedProduct.name,
            categoryId: scannedProduct.categoryId,
            barcode: scannedProduct.barcode,
            mrp: parseFloat(scannedProduct.mrp),
            price: parseFloat(scannedProduct.price),
            stock: 0, // Inward batch will set the stock
            unit: scannedProduct.unit,
            imageUrl: scannedProduct.imageUrl || null,
            brand: scannedProduct.brand || 'Generic',
            isAvailable: true
          })
        })

        if (!createRes.ok) {
          const errData = await createRes.json()
          throw new Error(errData.error || 'Failed to create product')
        }

        const newProd = await createRes.json()
        scannedProduct.id = newProd.id
        scannedProduct.status = 'exists'
      } catch (err: any) {
        toast.error(err.message || 'Error creating product')
        setSubmittingInward(false)
        return
      }
    } else if (scannedProduct.status === 'exists') {
      // Direct Price Update during Inward
      const originalProd = products.find(p => p.id === scannedProduct.id)
      if (originalProd && (originalProd.mrp !== parseFloat(scannedProduct.mrp) || originalProd.price !== parseFloat(scannedProduct.price))) {
        try {
          const updateRes = await fetch(`/api/products/${scannedProduct.id}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              mrp: parseFloat(scannedProduct.mrp),
              price: parseFloat(scannedProduct.price)
            })
          })
          if (!updateRes.ok) throw new Error('Failed to update catalog prices')
          toast.success('🏷️ Product catalog prices updated successfully!')
        } catch (err: any) {
          toast.error(err.message || 'Error updating product catalog prices')
        }
      }
    }

    // 2. Register inward batch
    try {
      setSubmittingInward(true)
      const res = await fetch('/api/admin/inward', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          productId: scannedProduct.id,
          batchCode: inwardBatchCode.trim(),
          quantity: parseInt(inwardQty, 10),
          costPrice: parseFloat(inwardCost),
          expiryDate: inwardExpiry ? new Date(inwardExpiry).toISOString() : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString() // default +30 days if blank
        })
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to inward stock')
      }

      toast.success('🎉 Stock added successfully!')
      
      // Reset scanner tab
      setScannedProduct(null)
      setInwardBarcode('')
      setInwardExpiry('')
      fetchCatalog()
      fetchHistory()
      
      // Refocus barcode input
      setTimeout(() => barcodeInputRef.current?.focus(), 200)
    } catch (err: any) {
      toast.error(err.message || 'Failed to inward stock')
    } finally {
      setSubmittingInward(false)
    }
  }

  // Quick Barcode Linking
  const filteredLinkingProducts = useMemo(() => {
    if (!linkSearchQuery.trim()) return []
    return products.filter(p => 
      !p.barcode && 
      p.name.toLowerCase().includes(linkSearchQuery.toLowerCase())
    ).slice(0, 5)
  }, [linkSearchQuery, products])

  const handleLinkBarcode = async (prodId: string) => {
    try {
      setSearchingMaster(true)
      const res = await fetch(`/api/products/${prodId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ barcode: inwardBarcode.trim() })
      })

      if (!res.ok) throw new Error('Failed to link barcode')
      toast.success('🔗 Barcode linked successfully to product!')
      
      // Refetch and auto-trigger search for the newly linked barcode
      await fetchCatalog()
      handleBarcodeSubmit()
    } catch (err) {
      console.error(err)
      toast.error('Could not link barcode')
    } finally {
      setSearchingMaster(false)
    }
  }

  // =========================================================================
  // TAB 2: RETAIL POS COUNTER (STORE CHECKOUT)
  // =========================================================================
  const [posSearchQuery, setPosSearchQuery] = useState('')
  const [highlightedIndex, setHighlightedIndex] = useState(0)
  const [showSearchResults, setShowSearchResults] = useState(false)
  const [posCart, setPosCart] = useState<CartItem[]>([])
  const [posPricingMode, setPosPricingMode] = useState<'mrp' | 'website'>('mrp')
  const [posPaymentMethod, setPosPaymentMethod] = useState<'COD' | 'UPI'>('COD')
  const [checkoutLoading, setCheckoutLoading] = useState(false)
  const posBarcodeRef = useRef<HTMLInputElement>(null)

  // Focus scanner when POS tab loads
  useEffect(() => {
    if (activeTab === 'pos' && posBarcodeRef.current) {
      posBarcodeRef.current.focus()
    }
  }, [activeTab])

  // Filter products for the search results dropdown
  const posSearchResults = useMemo(() => {
    const query = posSearchQuery.trim().toLowerCase()
    if (!query) return []
    return products.filter(p => 
      p.name.toLowerCase().includes(query) || 
      (p.barcode && p.barcode.toLowerCase().includes(query))
    ).slice(0, 10)
  }, [posSearchQuery, products])

  const handleAddProductToCart = (product: Product) => {
    setPosCart(prev => {
      const existing = prev.find(item => item.product.id === product.id)
      const price = posPricingMode === 'mrp' ? product.mrp : product.price

      if (existing) {
        return prev.map(item => 
          item.product.id === product.id 
            ? { ...item, quantity: item.quantity + 1 }
            : item
        )
      } else {
        return [...prev, { product, quantity: 1, price }]
      }
    })
    toast.success(`🛒 Added ${product.name} to retail cart`, { duration: 1000 })
  }

  // Scan or search product into Retail POS cart
  const handlePosBarcodeSubmit = (e?: React.FormEvent) => {
    if (e) e.preventDefault()
    const query = posSearchQuery.trim()
    if (!query) return

    // 1. Try to find by exact barcode
    let product = products.find(p => p.barcode === query)

    // 2. If not found by barcode, select the highlighted search result if available
    if (!product && posSearchResults.length > 0 && highlightedIndex >= 0 && highlightedIndex < posSearchResults.length) {
      product = posSearchResults[highlightedIndex]
    }

    if (product) {
      handleAddProductToCart(product)
      setPosSearchQuery('')
      setShowSearchResults(false)
      setHighlightedIndex(0)
    } else {
      toast.error(`❌ Product or Barcode "${query}" not found in catalog!`, { duration: 2500 })
    }
  }

  // Recalculate cart prices when pricing mode (MRP vs Website Price) changes
  useEffect(() => {
    setPosCart(prev => prev.map(item => ({
      ...item,
      price: posPricingMode === 'mrp' ? item.product.mrp : item.product.price
    })))
  }, [posPricingMode])

  // Cart Calculations
  const cartSubtotal = useMemo(() => {
    return posCart.reduce((sum, item) => sum + (item.price * item.quantity), 0)
  }, [posCart])

  const cartMrpTotal = useMemo(() => {
    return posCart.reduce((sum, item) => sum + (item.product.mrp * item.quantity), 0)
  }, [posCart])

  const cartDiscount = useMemo(() => {
    return Math.max(0, cartMrpTotal - cartSubtotal)
  }, [cartMrpTotal, cartSubtotal])

  // Update POS Cart item quantity or price manually
  const updateCartItem = (prodId: string, updates: Partial<CartItem>) => {
    setPosCart(prev => prev.map(item => {
      if (item.product.id === prodId) {
        return { ...item, ...updates }
      }
      return item
    }).filter(item => item.quantity > 0))
  }

  // POS Checkout Complete
  const handlePosCheckout = async () => {
    if (posCart.length === 0) return

    try {
      setCheckoutLoading(true)
      const res = await fetch('/api/admin/inventory/pos-checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: posCart.map(item => ({
            productId: item.product.id,
            quantity: item.quantity,
            price: item.price
          })),
          paymentMethod: posPaymentMethod,
          subtotal: cartMrpTotal,
          discount: cartDiscount,
          total: cartSubtotal
        })
      })

      if (!res.ok) throw new Error('POS Transaction failed')
      const data = await res.json()

      toast.success(`✅ Sale registered successfully! Order ID: FK${String(data.readableId).padStart(6, '0')}`)
      
      // Clear cart
      setPosCart([])
      fetchCatalog()
      fetchHistory()
      
      // Refocus input
      setTimeout(() => posBarcodeRef.current?.focus(), 150)
    } catch (err) {
      console.error(err)
      toast.error('Checkout failed')
    } finally {
      setCheckoutLoading(false)
    }
  }

  // =========================================================================
  // TAB 3: BULK IMPORT (GOOGLE SHEET PASTE)
  // =========================================================================
  const [importText, setImportText] = useState('')
  const [importPreview, setImportPreview] = useState<any[]>([])
  const [importing, setImporting] = useState(false)

  const handleParseImport = () => {
    if (!importText.trim()) return

    const rows = importText.trim().split('\n')
    const parsed = rows.map((row, idx) => {
      const cols = row.split('\t') // split by tabs (standard copy-paste from Sheets)
      if (cols.length < 3) return null

      // Expecting order: Barcode | Name | Category Slug | Brand | MRP | Selling Price | Stock Qty | Unit | Image URL
      return {
        barcode: cols[0]?.trim() || '',
        name: cols[1]?.trim() || '',
        categorySlug: cols[2]?.trim().toLowerCase() || 'other-essentials',
        brand: cols[3]?.trim() || 'Generic',
        mrp: parseFloat(cols[4]) || 0,
        price: parseFloat(cols[5]) || 0,
        stockQty: parseInt(cols[6], 10) || 0,
        unit: cols[7]?.trim() || '1 pc',
        imageUrl: cols[8]?.trim() || ''
      }
    }).filter(Boolean)

    setImportPreview(parsed)
    toast.info(`Parsed ${parsed.length} rows. Please verify preview before importing.`)
  }

  const handleRunImport = async () => {
    if (importPreview.length === 0) return

    try {
      setImporting(true)
      const res = await fetch('/api/admin/inventory/import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items: importPreview })
      })

      if (!res.ok) throw new Error('Bulk import failed')
      const data = await res.json()

      toast.success(data.message)
      setImportPreview([])
      setImportText('')
      fetchCatalog()
      fetchHistory()
    } catch (err) {
      console.error(err)
      toast.error('Bulk import process failed')
    } finally {
      setImporting(false)
    }
  }

  // =========================================================================
  // TAB 4: STOCK HISTORY LOGS
  // =========================================================================
  const [historyLogs, setHistoryLogs] = useState<StockHistoryLog[]>([])
  const [historyTotal, setHistoryTotal] = useState(0)
  const [loadingHistory, setLoadingHistory] = useState(false)

  const fetchHistory = async () => {
    try {
      setLoadingHistory(true)
      const res = await fetch('/api/admin/inventory/history?limit=50')
      if (!res.ok) throw new Error('Failed to load history')
      const data = await res.json()
      setHistoryLogs(data.logs || [])
      setHistoryTotal(data.total || 0)
    } catch (err) {
      console.error(err)
    } finally {
      setLoadingHistory(false)
    }
  }

  useEffect(() => {
    if (activeTab === 'history') {
      fetchHistory()
    }
  }, [activeTab])

  // Expiry dates preset helper
  const applyExpiryPreset = (months: number) => {
    const d = new Date()
    d.setMonth(d.getMonth() + months)
    setInwardExpiry(d.toISOString().split('T')[0])
  }

  return (
    <div className="space-y-6">
      
      {/* Navigation Headers / Tabs */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-border/80 pb-4">
        <div>
          <h2 className="text-xl font-black tracking-tight text-text-primary flex items-center gap-2">
            <Building2 className="h-6 w-6 text-accent" />
            Unified Inventory & POS System
          </h2>
          <p className="text-xs text-text-secondary mt-0.5">
            Manage barcodes, scan stock shipments, counter sales, and spreadsheet imports.
          </p>
        </div>

        {/* Tab selector */}
        <div className="flex bg-muted/60 p-1 rounded-xl border border-border/60">
          {[
            { id: 'inward', label: '1. Inward & Scan', icon: QrCode },
            { id: 'pos', label: '2. Retail POS Counter', icon: ShoppingCart },
            { id: 'import', label: '3. Excel Import', icon: FileSpreadsheet },
            { id: 'history', label: '4. Stock Logs', icon: History }
          ].map(tab => {
            const Icon = tab.icon
            const isActive = activeTab === tab.id
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                  isActive 
                    ? 'bg-card text-accent shadow-sm border border-border/40' 
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                <Icon className="h-4 w-4" />
                {tab.label}
              </button>
            )
          })}
        </div>
      </div>

      {/* Main Tab Views container */}
      <div className="min-h-[500px]">
        <AnimatePresence mode="wait">
          
          {/* TAB 1: QUICK INWARD & SCAN */}
          {activeTab === 'inward' && (
            <motion.div
              key="inward-tab"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="grid grid-cols-1 lg:grid-cols-3 gap-6"
            >
              
              {/* Scan box columns */}
              <div className="lg:col-span-2 space-y-6">
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
                  <div>
                    <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                      <QrCode className="h-5 w-5 text-accent" />
                      Scan Barcode to Inward Stock
                    </h3>
                    <p className="text-xs text-text-secondary mt-0.5">
                      Point your barcode scanner or type the barcode of the item in hand.
                    </p>
                  </div>

                  <form onSubmit={(e) => handleBarcodeSubmit(e)} className="space-y-4">
                    <div className="space-y-1 relative">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Scan Item Barcode</label>
                      <div className="flex gap-2">
                        <div className="relative flex-1">
                          <Search className="absolute left-3 top-3.5 h-4 w-4 text-text-muted" />
                          <input
                            ref={barcodeInputRef}
                            type="text"
                            value={inwardBarcode}
                            onChange={(e) => setInwardBarcode(e.target.value)}
                            placeholder="Scan packet barcode or type code..."
                            className="w-full bg-muted/40 border border-border/80 pl-9 pr-10 py-2.5 rounded-xl text-sm focus:outline-none focus:border-accent focus:bg-card font-mono font-bold"
                          />
                          <button
                            type="button"
                            onClick={startInwardCamera}
                            className="absolute right-3 top-2.5 text-text-secondary hover:text-accent p-1 rounded-lg transition-colors cursor-pointer"
                            title="Open Camera Barcode Scanner"
                          >
                            <Camera className="h-4 w-4" />
                          </button>
                        </div>
                        <button
                          type="submit"
                          disabled={searchingMaster}
                          className="px-6 rounded-xl bg-accent hover:bg-accent-dark text-white font-extrabold text-xs transition-colors shrink-0 flex items-center gap-1.5 cursor-pointer shadow"
                        >
                          {searchingMaster ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Search'}
                        </button>
                      </div>
                    </div>
                  </form>

                  {/* If searched and barcode needs linking to existing product */}
                  {inwardBarcode && !scannedProduct && !searchingMaster && (
                    <div className="p-4 rounded-xl border border-warning/20 bg-warning/5 text-xs space-y-3">
                      <div className="flex items-start gap-2">
                        <AlertCircle className="h-4 w-4 text-warning shrink-0 mt-0.5" />
                        <div>
                          <p className="font-extrabold text-warning">This Barcode is not linked to any product yet.</p>
                          <p className="text-[10px] text-text-secondary mt-0.5">
                            You can either create a new product from scratch, or link it to an existing product in your catalog!
                          </p>
                        </div>
                      </div>

                      {/* Linking toggle */}
                      {!isLinkingMode ? (
                        <button
                          onClick={() => setIsLinkingMode(true)}
                          className="px-4 py-1.5 border border-border rounded-lg font-bold hover:bg-muted/40 cursor-pointer"
                        >
                          🔗 Link to an Existing Catalog Product
                        </button>
                      ) : (
                        <div className="space-y-3 pt-2 border-t border-border/40">
                          <input
                            type="text"
                            value={linkSearchQuery}
                            onChange={(e) => setLinkSearchQuery(e.target.value)}
                            placeholder="Type product name to search (e.g. Marie Gold)..."
                            className="w-full bg-muted/40 border border-border/80 px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-accent"
                          />
                          {filteredLinkingProducts.length > 0 && (
                            <div className="divide-y divide-border border border-border rounded-lg bg-card overflow-hidden">
                              {filteredLinkingProducts.map(p => (
                                <button
                                  key={p.id}
                                  onClick={() => handleLinkBarcode(p.id)}
                                  className="w-full text-left px-3 py-2 hover:bg-muted/30 text-xs flex justify-between items-center"
                                >
                                  <div>
                                    <span className="font-bold block text-text-primary">{p.name}</span>
                                    <span className="text-[9px] text-text-muted">{p.categoryName}</span>
                                  </div>
                                  <span className="text-[10px] font-black text-accent">Link Barcode</span>
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  )}

                  {/* Prefilled product form if found/new */}
                  {scannedProduct && (
                    <motion.div
                      initial={{ opacity: 0, y: 15 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="border border-border/80 rounded-2xl p-6 bg-muted/10 space-y-6"
                    >
                      {/* Badge identifying status */}
                      <div className="flex items-center justify-between">
                        <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                          Product Context details
                        </span>
                        {scannedProduct.status === 'exists' && (
                          <span className="bg-emerald-500/10 text-emerald-500 border border-emerald-500/20 px-2 py-0.5 rounded text-[10px] font-black">
                            Catalog Match Found
                          </span>
                        )}
                        {scannedProduct.status === 'master' && (
                          <span className="bg-indigo-500/10 text-indigo-500 border border-indigo-500/20 px-2 py-0.5 rounded text-[10px] font-black flex items-center gap-1">
                            <Sparkles className="h-3 w-3 animate-pulse" />
                            Blinkit Auto-fill
                          </span>
                        )}
                        {scannedProduct.status === 'new' && (
                          <span className="bg-amber-500/10 text-amber-500 border border-amber-500/20 px-2 py-0.5 rounded text-[10px] font-black">
                            New Product Setup
                          </span>
                        )}
                      </div>

                      {/* Info grid */}
                      <div className="flex items-start gap-4 pb-4 border-b border-border/40">
                        <div className="w-16 h-16 rounded-xl bg-card border border-border flex items-center justify-center overflow-hidden shrink-0">
                          {scannedProduct.imageUrl ? (
                            <img src={scannedProduct.imageUrl} alt="Product" className="object-cover w-full h-full" />
                          ) : (
                            <Package className="h-8 w-8 text-text-muted" />
                          )}
                        </div>
                        <div className="space-y-1 flex-1">
                          {scannedProduct.status === 'exists' ? (
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-1">
                              <div className="space-y-1 md:col-span-2">
                                <h4 className="font-extrabold text-sm text-text-primary leading-tight">{scannedProduct.name}</h4>
                                <p className="text-xs text-text-muted mt-0.5">
                                  ID: <strong className="text-text-primary">FK{String(scannedProduct.readableId || '').padStart(6, '0')}</strong> | Barcode: <strong className="text-text-primary">{scannedProduct.barcode}</strong> | Current stock: <strong className="text-accent font-black">{scannedProduct.stock} {scannedProduct.unit}</strong>
                                </p>
                              </div>
                              <div className="space-y-1">
                                <label className="text-[9px] font-extrabold text-text-secondary uppercase">Current MRP (₹) [Edit to update]</label>
                                <input
                                  type="number"
                                  value={scannedProduct.mrp}
                                  onChange={(e) => setScannedProduct({ ...scannedProduct, mrp: parseFloat(e.target.value) || 0 })}
                                  className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none focus:border-accent"
                                />
                              </div>
                              <div className="space-y-1">
                                <label className="text-[9px] font-extrabold text-text-secondary uppercase">Current Price (₹) [Edit to update]</label>
                                <input
                                  type="number"
                                  value={scannedProduct.price}
                                  onChange={(e) => setScannedProduct({ ...scannedProduct, price: parseFloat(e.target.value) || 0 })}
                                  className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none focus:border-accent"
                                />
                              </div>
                            </div>
                          ) : (
                            // Input fields for creating new / master product details
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-1">
                              <div className="space-y-1">
                                <label className="text-[9px] font-extrabold text-text-secondary uppercase">Product Name</label>
                                <input
                                  type="text"
                                  value={scannedProduct.name}
                                  onChange={(e) => setScannedProduct({ ...scannedProduct, name: e.target.value })}
                                  className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none focus:border-accent"
                                  placeholder="e.g. Britannia Rusk"
                                  required
                                />
                              </div>
                              <div className="space-y-1">
                                <label className="text-[9px] font-extrabold text-text-secondary uppercase">Category</label>
                                <select
                                  value={scannedProduct.categoryId}
                                  onChange={(e) => setScannedProduct({ ...scannedProduct, categoryId: e.target.value })}
                                  className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none focus:border-accent"
                                >
                                  {categories.map(c => (
                                    <option key={c.id} value={c.id}>{c.name}</option>
                                  ))}
                                </select>
                              </div>
                              <div className="space-y-1">
                                <label className="text-[9px] font-extrabold text-text-secondary uppercase">Brand</label>
                                <input
                                  type="text"
                                  value={scannedProduct.brand}
                                  onChange={(e) => setScannedProduct({ ...scannedProduct, brand: e.target.value })}
                                  className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none"
                                  placeholder="e.g. Nestlé"
                                />
                              </div>
                              <div className="grid grid-cols-2 gap-2">
                                <div className="space-y-1">
                                  <label className="text-[9px] font-extrabold text-text-secondary uppercase">MRP (₹)</label>
                                  <input
                                    type="number"
                                    value={scannedProduct.mrp}
                                    onChange={(e) => setScannedProduct({ ...scannedProduct, mrp: parseFloat(e.target.value) || 0 })}
                                    className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none"
                                  />
                                </div>
                                <div className="space-y-1">
                                  <label className="text-[9px] font-extrabold text-text-secondary uppercase">Selling Price (₹)</label>
                                  <input
                                    type="number"
                                    value={scannedProduct.price}
                                    onChange={(e) => setScannedProduct({ ...scannedProduct, price: parseFloat(e.target.value) || 0 })}
                                    className="w-full bg-card border border-border px-2 py-1 rounded-lg text-xs font-semibold focus:outline-none"
                                  />
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      </div>

                      {/* Inward details form */}
                      <form onSubmit={handleInwardSubmit} className="space-y-4">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                          {/* Batch Code */}
                          <div className="space-y-1">
                            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Batch Identification Code</label>
                            <input
                              type="text"
                              required
                              value={inwardBatchCode}
                              onChange={(e) => setInwardBatchCode(e.target.value.toUpperCase())}
                              className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-accent font-mono font-bold"
                            />
                          </div>

                          {/* Quantity */}
                          <div className="space-y-1">
                            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Quantity Received (units)</label>
                            <div className="flex gap-2">
                              <input
                                ref={qtyInputRef}
                                type="number"
                                min="1"
                                required
                                value={inwardQty}
                                onChange={(e) => setInwardQty(e.target.value)}
                                className="w-24 bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-accent font-bold"
                              />
                              {['10', '20', '50', '100'].map((qty) => (
                                <button
                                  key={qty}
                                  type="button"
                                  onClick={() => setInwardQty(qty)}
                                  className={`flex-1 border text-[10px] font-bold rounded-xl transition-colors cursor-pointer ${
                                    inwardQty === qty ? 'bg-accent text-white border-accent' : 'bg-card border-border text-text-secondary hover:bg-muted/50'
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
                                value={inwardCost}
                                onChange={(e) => setInwardCost(e.target.value)}
                                className="w-full bg-card border border-border pl-8 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-accent font-bold text-emerald-500"
                              />
                            </div>
                          </div>

                          {/* Expiry Date */}
                          <div className="space-y-1">
                            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Expiry Date</label>
                            <div className="space-y-2">
                              <div className="relative">
                                <Calendar className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                                <input
                                  type="date"
                                  value={inwardExpiry}
                                  onChange={(e) => setInwardExpiry(e.target.value)}
                                  className="w-full bg-card border border-border pl-9 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-accent font-semibold"
                                />
                              </div>
                              <div className="flex gap-1 overflow-x-auto py-0.5">
                                {[
                                  { label: '+10 Days', val: 0.33 },
                                  { label: '+1 Mo', val: 1 },
                                  { label: '+3 Mo', val: 3 },
                                  { label: '+6 Mo', val: 6 },
                                  { label: '+1 Yr', val: 12 }
                                ].map((p) => (
                                  <button
                                    key={p.label}
                                    type="button"
                                    onClick={() => {
                                      if (p.val === 0.33) {
                                        const d = new Date()
                                        d.setDate(d.getDate() + 10)
                                        setInwardExpiry(d.toISOString().split('T')[0])
                                      } else {
                                        applyExpiryPreset(p.val)
                                      }
                                    }}
                                    className="flex-1 py-1 px-1.5 border border-border text-[9px] font-bold rounded-lg bg-card text-text-secondary hover:bg-muted/50 whitespace-nowrap cursor-pointer"
                                  >
                                    {p.label}
                                  </button>
                                ))}
                              </div>
                            </div>
                          </div>
                        </div>

                        <button
                          type="submit"
                          disabled={submittingInward}
                          className="w-full h-11 bg-accent hover:bg-accent-dark text-white rounded-xl font-black text-xs tracking-wider uppercase transition-all shadow-sm disabled:opacity-60 flex items-center justify-center gap-1.5 cursor-pointer mt-4"
                        >
                          {submittingInward ? (
                            <>
                              <Loader2 className="h-4 w-4 animate-spin" />
                              Saving Stock Batch...
                            </>
                          ) : (
                            <>
                              <Plus className="h-4 w-4" />
                              {scannedProduct.status === 'exists' ? 'Inward Incoming Stock' : 'Create & Inward Product'}
                            </>
                          )}
                        </button>
                      </form>
                    </motion.div>
                  )}

                </div>
              </div>

              {/* Side helper instructions panel */}
              <div className="space-y-6">
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
                  <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">How to use scanner</h4>
                  <ul className="space-y-3 text-[11px] text-text-secondary">
                    <li className="flex gap-2">
                      <span className="bg-accent/10 text-accent h-4 w-4 rounded-full flex items-center justify-center shrink-0 font-bold">1</span>
                      <span>Connect any USB or Bluetooth barcode scanner to your computer.</span>
                    </li>
                    <li className="flex gap-2">
                      <span className="bg-accent/10 text-accent h-4 w-4 rounded-full flex items-center justify-center shrink-0 font-bold">2</span>
                      <span>Focus the <strong>Scan Item Barcode</strong> input box at the top.</span>
                    </li>
                    <li className="flex gap-2">
                      <span className="bg-accent/10 text-accent h-4 w-4 rounded-full flex items-center justify-center shrink-0 font-bold">3</span>
                      <span>Scan the barcode. The product will fetch automatically.</span>
                    </li>
                    <li className="flex gap-2">
                      <span className="bg-accent/10 text-accent h-4 w-4 rounded-full flex items-center justify-center shrink-0 font-bold">4</span>
                      <span>Cursor will auto-jump to **Quantity**. Type quantity and hit **Enter** to save!</span>
                    </li>
                  </ul>
                </div>
              </div>

            </motion.div>
          )}

          {/* TAB 2: RETAIL POS COUNTER */}
          {activeTab === 'pos' && (
            <motion.div
              key="pos-tab"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="grid grid-cols-1 lg:grid-cols-3 gap-6"
            >
              
              {/* POS Scanning input and cart lists */}
              <div className="lg:col-span-2 space-y-6">
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
                  
                  {/* Header POS controls */}
                  <div className="flex flex-wrap justify-between items-center gap-4">
                    <div>
                      <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                        <ShoppingCart className="h-5 w-5 text-accent" />
                        Professional Retail POS
                      </h3>
                      <p className="text-xs text-text-secondary mt-0.5">
                        Scan barcodes or search products to checkout walk-in retail customers.
                      </p>
                    </div>

                    {/* Bill pricing mode toggle */}
                    <div className="flex bg-muted/60 p-0.5 rounded-xl border border-border/50 text-[10px] font-black uppercase">
                      <button
                        onClick={() => setPosPricingMode('mrp')}
                        className={`px-3 py-1 rounded-lg transition-colors cursor-pointer ${
                          posPricingMode === 'mrp' ? 'bg-card text-accent shadow-sm' : 'text-text-secondary'
                        }`}
                      >
                        MRP (Retail Price)
                      </button>
                      <button
                        onClick={() => setPosPricingMode('website')}
                        className={`px-3 py-1 rounded-lg transition-colors cursor-pointer ${
                          posPricingMode === 'website' ? 'bg-card text-accent shadow-sm' : 'text-text-secondary'
                        }`}
                      >
                        Website Discount
                      </button>
                    </div>
                  </div>

                  {/* POS Barcode scan / product search form */}
                  <div className="relative">
                    <form onSubmit={handlePosBarcodeSubmit} className="relative">
                      <Search className="absolute left-3 top-3.5 h-4 w-4 text-text-muted" />
                      <input
                        ref={posBarcodeRef}
                        type="text"
                        value={posSearchQuery}
                        onChange={(e) => {
                          setPosSearchQuery(e.target.value)
                          setHighlightedIndex(0)
                          setShowSearchResults(true)
                        }}
                        onFocus={() => setShowSearchResults(true)}
                        onBlur={() => setTimeout(() => setShowSearchResults(false), 200)}
                        placeholder="Search product by name, brand or scan barcode..."
                        className="w-full bg-muted/40 border border-border/80 pl-9 pr-4 py-2.5 rounded-xl text-sm focus:outline-none focus:border-accent focus:bg-card font-bold"
                        onKeyDown={(e) => {
                          if (e.key === 'ArrowDown') {
                            e.preventDefault()
                            setHighlightedIndex(prev => Math.min(prev + 1, posSearchResults.length - 1))
                          } else if (e.key === 'ArrowUp') {
                            e.preventDefault()
                            setHighlightedIndex(prev => Math.max(prev - 1, 0))
                          } else if (e.key === 'Escape') {
                            setShowSearchResults(false)
                          }
                        }}
                      />
                    </form>

                    {/* Floating Search Results Dropdown */}
                    {showSearchResults && posSearchQuery.trim() && (
                      <div className="absolute z-50 left-0 right-0 mt-2 bg-card border border-border rounded-2xl shadow-xl max-h-80 overflow-y-auto divide-y divide-border/60">
                        {posSearchResults.length === 0 ? (
                          <div className="p-4 text-center text-xs text-text-secondary">
                            No products found matching "{posSearchQuery}"
                          </div>
                        ) : (
                          posSearchResults.map((product, index) => (
                            <button
                              key={product.id}
                              type="button"
                              onClick={() => {
                                handleAddProductToCart(product)
                                setPosSearchQuery('')
                                setShowSearchResults(false)
                              }}
                              className={`w-full text-left px-4 py-3 flex items-center justify-between gap-3 text-xs transition-colors cursor-pointer ${
                                index === highlightedIndex ? 'bg-accent/5 text-accent border-l-4 border-accent font-bold' : 'text-text-primary hover:bg-muted/30 font-semibold'
                              }`}
                            >
                              <div className="flex items-center gap-3 min-w-0">
                                <div className="w-10 h-10 rounded-lg bg-muted border border-border/40 flex items-center justify-center overflow-hidden shrink-0">
                                  {product.imageUrl ? (
                                    <img src={product.imageUrl} alt={product.name} className="object-cover w-full h-full" />
                                  ) : (
                                    <Package className="h-5 w-5 text-text-muted" />
                                  )}
                                </div>
                                <div className="min-w-0 text-left">
                                  <span className="font-extrabold block truncate text-text-primary">{product.name}</span>
                                  <span className="text-[10px] text-text-muted mt-0.5 block">
                                    MRP: {formatPrice(product.mrp)} | Stock: {product.stock} {product.unit} | Barcode: {product.barcode || 'N/A'}
                                  </span>
                                </div>
                              </div>
                              <span className="text-[10px] font-black text-accent shrink-0 bg-accent/10 px-2.5 py-1 rounded-lg">
                                Add to Cart
                              </span>
                            </button>
                          ))
                        )}
                      </div>
                    )}
                  </div>

                  {/* POS Cart List */}
                  <div className="space-y-4">
                    <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary block">
                      Counter Cart ({posCart.length} items)
                    </span>

                    {posCart.length === 0 ? (
                      <div className="p-12 border border-dashed border-border rounded-xl text-center bg-muted/5 text-xs text-text-secondary">
                        <ShoppingCart className="h-8 w-8 text-text-muted mx-auto mb-2 opacity-50" />
                        Counter cart is empty. Scan items to add.
                      </div>
                    ) : (
                      <div className="divide-y divide-border border border-border rounded-xl bg-card overflow-hidden">
                        {posCart.map(item => (
                          <div key={item.product.id} className="p-4 flex items-center justify-between gap-4 text-xs font-semibold hover:bg-muted/10 transition-colors">
                            <div className="flex items-center gap-3 min-w-0">
                              <span className="text-xl shrink-0">{item.product.imageUrl ? <img src={item.product.imageUrl} className="w-8 h-8 rounded-lg object-cover" /> : '📦'}</span>
                              <div className="min-w-0">
                                <span className="font-extrabold text-text-primary block truncate">{item.product.name}</span>
                                <span className="text-[9px] text-text-muted block mt-0.5">
                                  MRP: {formatPrice(item.product.mrp)} | Stock: {item.product.stock}
                                </span>
                              </div>
                            </div>

                            {/* Quantity and Billed Price edits */}
                            <div className="flex items-center gap-6 shrink-0">
                              {/* Quantity Counter */}
                              <div className="flex items-center gap-1.5 border border-border rounded-lg bg-muted/20 px-1 py-0.5">
                                <button
                                  onClick={() => updateCartItem(item.product.id, { quantity: item.quantity - 1 })}
                                  className="h-5 w-5 hover:bg-card hover:text-accent rounded flex items-center justify-center cursor-pointer font-bold"
                                >
                                  -
                                </button>
                                <span className="w-6 text-center font-bold text-xs">{item.quantity}</span>
                                <button
                                  onClick={() => updateCartItem(item.product.id, { quantity: item.quantity + 1 })}
                                  className="h-5 w-5 hover:bg-card hover:text-accent rounded flex items-center justify-center cursor-pointer font-bold"
                                >
                                  +
                                </button>
                              </div>

                              {/* Price edit (allows shopkeeper to customize/discount) */}
                              <div className="flex items-center gap-1">
                                <span className="text-[10px] text-text-muted">₹</span>
                                <input
                                  type="number"
                                  value={item.price}
                                  onChange={(e) => updateCartItem(item.product.id, { price: parseFloat(e.target.value) || 0 })}
                                  className="w-16 border border-border rounded px-1.5 py-0.5 text-center font-bold focus:outline-none focus:border-accent text-accent"
                                />
                              </div>

                              {/* Subtotal */}
                              <span className="w-16 text-right font-extrabold text-text-primary">
                                {formatPrice(item.price * item.quantity)}
                              </span>

                              {/* Remove */}
                              <button
                                onClick={() => updateCartItem(item.product.id, { quantity: 0 })}
                                className="text-text-muted hover:text-danger cursor-pointer transition-colors p-1"
                              >
                                <Trash2 className="h-4 w-4" />
                              </button>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                </div>
              </div>

              {/* Checkout details sidebar */}
              <div className="space-y-6">
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
                  <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Payment & Checkout</h4>

                  {/* Calculations breakdown */}
                  <div className="space-y-3 pt-2 text-xs font-semibold">
                    <div className="flex justify-between text-text-secondary">
                      <span>Total MRP:</span>
                      <span>{formatPrice(cartMrpTotal)}</span>
                    </div>
                    {cartDiscount > 0 && (
                      <div className="flex justify-between text-emerald-500 font-extrabold">
                        <span>POS Savings / Discount:</span>
                        <span>-{formatPrice(cartDiscount)}</span>
                      </div>
                    )}
                    <div className="flex justify-between border-t border-border/80 pt-3 text-sm font-black text-text-primary">
                      <span>Grand Total:</span>
                      <span className="text-accent text-base">{formatPrice(cartSubtotal)}</span>
                    </div>
                  </div>

                  {/* Payment Method Selector */}
                  <div className="space-y-2 pt-2 border-t border-border/40">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Payment Mode</label>
                    <div className="grid grid-cols-2 gap-2">
                      <button
                        onClick={() => setPosPaymentMethod('COD')}
                        className={`py-3 rounded-xl border text-xs font-black tracking-wider transition-all cursor-pointer ${
                          posPaymentMethod === 'COD' 
                            ? 'bg-accent/10 border-accent text-accent shadow-sm' 
                            : 'bg-card border-border text-text-secondary hover:bg-muted/50'
                        }`}
                      >
                        💵 CASH
                      </button>
                      <button
                        onClick={() => setPosPaymentMethod('UPI')}
                        className={`py-3 rounded-xl border text-xs font-black tracking-wider transition-all cursor-pointer ${
                          posPaymentMethod === 'UPI' 
                            ? 'bg-accent/10 border-accent text-accent shadow-sm' 
                            : 'bg-card border-border text-text-secondary hover:bg-muted/50'
                        }`}
                      >
                        📱 UPI / SCAN
                      </button>
                    </div>
                  </div>

                  {/* Submit sale */}
                  <button
                    onClick={handlePosCheckout}
                    disabled={posCart.length === 0 || checkoutLoading}
                    className="w-full h-11 bg-accent hover:bg-accent-dark disabled:opacity-50 text-white rounded-xl font-black text-xs tracking-wider uppercase transition-all shadow flex items-center justify-center gap-1.5 cursor-pointer"
                  >
                    {checkoutLoading ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin" />
                        Finalizing Sale...
                      </>
                    ) : (
                      <>
                        <CheckCircle className="h-4 w-4" />
                        Complete Counter Checkout (₹{cartSubtotal.toFixed(0)})
                      </>
                    )}
                  </button>

                  {/* Clear Cart */}
                  {posCart.length > 0 && (
                    <button
                      onClick={() => setPosCart([])}
                      className="w-full text-center text-[10px] text-text-muted hover:text-text-primary font-bold cursor-pointer transition-colors"
                    >
                      Clear POS Cart
                    </button>
                  )}
                </div>
              </div>

            </motion.div>
          )}

          {/* TAB 3: BULK IMPORT */}
          {activeTab === 'import' && (
            <motion.div
              key="import-tab"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="space-y-6"
            >
              <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
                <div>
                  <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                    <FileSpreadsheet className="h-5 w-5 text-accent" />
                    Google Sheets / Excel Bulk Import
                  </h3>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Copy columns from your grocery spreadsheet and paste them directly below to import or update inventory.
                  </p>
                </div>

                {/* Import Textbox */}
                <div className="space-y-2">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                    Paste Spreadsheet Rows (TAB Separated)
                  </label>
                  <textarea
                    rows={8}
                    value={importText}
                    onChange={(e) => setImportText(e.target.value)}
                    placeholder="Barcode&#9;Product Name&#9;Category Slug&#9;Brand&#9;MRP&#9;Selling Price&#9;Stock Quantity&#9;Unit&#9;Image URL"
                    className="w-full bg-muted/40 border border-border/80 p-4 rounded-xl text-xs focus:outline-none focus:border-accent focus:bg-card font-mono leading-relaxed"
                  />
                  <div className="flex justify-between items-center">
                    <span className="text-[9px] text-text-muted font-bold">
                      Format: Barcode [Tab] Name [Tab] CategorySlug [Tab] Brand [Tab] MRP [Tab] Price [Tab] StockQty [Tab] Unit [Tab] ImageURL
                    </span>
                    <button
                      onClick={handleParseImport}
                      className="px-4 py-1.5 bg-accent hover:bg-accent-dark text-white rounded-lg text-xs font-extrabold cursor-pointer transition-colors shadow"
                    >
                      Preview & Validate Data
                    </button>
                  </div>
                </div>

                {/* Preview Grid */}
                {importPreview.length > 0 && (
                  <div className="space-y-4 pt-4 border-t border-border/40">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                        Data Preview Grid ({importPreview.length} items parsed)
                      </span>
                      <button
                        onClick={handleRunImport}
                        disabled={importing}
                        className="px-6 py-2 bg-emerald-500 hover:bg-emerald-600 text-white rounded-xl text-xs font-black tracking-wider uppercase transition-colors shadow flex items-center gap-1.5 cursor-pointer"
                      >
                        {importing ? <Loader2 className="h-4.5 w-4.5 animate-spin" /> : <Sparkles className="h-4.5 w-4.5" />}
                        Apply Bulk Import & Sync
                      </button>
                    </div>

                    <div className="overflow-x-auto border border-border rounded-xl">
                      <table className="w-full text-left border-collapse text-[10px] font-semibold">
                        <thead>
                          <tr className="bg-muted/50 border-b border-border text-text-secondary uppercase text-[8px] font-extrabold tracking-wider">
                            <th className="px-4 py-3">Barcode</th>
                            <th className="px-4 py-3">Product Name</th>
                            <th className="px-4 py-3">Category</th>
                            <th className="px-4 py-3">Brand</th>
                            <th className="px-4 py-3 text-right">MRP</th>
                            <th className="px-4 py-3 text-right">Sale Price</th>
                            <th className="px-4 py-3 text-center">Qty to Add</th>
                            <th className="px-4 py-3">Unit</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                          {importPreview.map((item, idx) => (
                            <tr key={idx} className="hover:bg-muted/10 transition-colors">
                              <td className="px-4 py-2.5 font-mono text-text-primary">{item.barcode || '—'}</td>
                              <td className="px-4 py-2.5 text-text-primary font-bold">{item.name}</td>
                              <td className="px-4 py-2.5 text-text-secondary">{item.categorySlug}</td>
                              <td className="px-4 py-2.5 text-text-secondary">{item.brand}</td>
                              <td className="px-4 py-2.5 text-right text-text-secondary">₹{item.mrp}</td>
                              <td className="px-4 py-2.5 text-right text-accent font-bold">₹{item.price}</td>
                              <td className="px-4 py-2.5 text-center text-text-primary font-bold">+{item.stockQty}</td>
                              <td className="px-4 py-2.5 text-text-secondary">{item.unit}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          )}

          {/* TAB 4: STOCK HISTORY LOGS */}
          {activeTab === 'history' && (
            <motion.div
              key="history-tab"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="space-y-6"
            >
              <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
                <div className="flex justify-between items-center gap-4">
                  <div>
                    <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                      <History className="h-5 w-5 text-accent" />
                      Stock Audit Trail Logs
                    </h3>
                    <p className="text-xs text-text-secondary mt-0.5">
                      Review all historic additions, sales, and bulk modifications of inventory.
                    </p>
                  </div>
                  <button
                    onClick={fetchHistory}
                    disabled={loadingHistory}
                    className="p-2 border border-border rounded-xl hover:bg-muted/50 cursor-pointer"
                  >
                    <RotateCcw className={`h-4 w-4 text-text-secondary ${loadingHistory ? 'animate-spin' : ''}`} />
                  </button>
                </div>

                {loadingHistory && historyLogs.length === 0 ? (
                  <div className="py-20 flex justify-center items-center">
                    <Loader2 className="h-6 w-6 text-accent animate-spin" />
                  </div>
                ) : historyLogs.length === 0 ? (
                  <div className="py-20 text-center text-xs text-text-secondary">
                    No stock transaction logs recorded yet.
                  </div>
                ) : (
                  <div className="space-y-4">
                    <div className="overflow-x-auto border border-border rounded-xl">
                      <table className="w-full text-left border-collapse text-[11px] font-semibold">
                        <thead>
                          <tr className="bg-muted/50 border-b border-border text-text-secondary uppercase text-[8px] font-extrabold tracking-wider">
                            <th className="px-4 py-3.5">Date & Time</th>
                            <th className="px-4 py-3.5">Product Name</th>
                            <th className="px-4 py-3.5">Barcode / ID</th>
                            <th className="px-4 py-3.5 text-center">Change Qty</th>
                            <th className="px-4 py-3.5">Action Type</th>
                            <th className="px-4 py-3.5 text-right">Prev Stock</th>
                            <th className="px-4 py-3.5 text-right">New Stock</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                          {historyLogs.map(log => {
                            const isPositive = log.quantity > 0
                            return (
                              <tr key={log.id} className="hover:bg-muted/10 transition-colors">
                                <td className="px-4 py-3 text-text-secondary">
                                  {new Date(log.createdAt).toLocaleString('en-IN', {
                                    day: 'numeric',
                                    month: 'short',
                                    hour: '2-digit',
                                    minute: '2-digit'
                                  })}
                                </td>
                                <td className="px-4 py-3 text-text-primary font-black">
                                  {log.product?.name || 'Deleted Product'}
                                </td>
                                <td className="px-4 py-3 font-mono text-text-muted">
                                  {log.product?.barcode || `FK${String(log.product?.readableId || '').padStart(6, '0')}`}
                                </td>
                                <td className={`px-4 py-3 text-center font-black ${isPositive ? 'text-emerald-500' : 'text-danger'}`}>
                                  {isPositive ? `+${log.quantity}` : log.quantity} {log.product?.unit}
                                </td>
                                <td className="px-4 py-3">
                                  <span className={`px-2 py-0.5 rounded text-[9px] font-black uppercase border ${
                                    log.type === 'INWARD_GRN' ? 'bg-emerald-500/10 border-emerald-500/10 text-emerald-500' :
                                    log.type === 'RETAIL_POS' ? 'bg-amber-500/10 border-amber-500/10 text-amber-500' :
                                    log.type === 'ONLINE_ORDER' ? 'bg-blue-500/10 border-blue-500/10 text-blue-500' :
                                    'bg-indigo-500/10 border-indigo-500/10 text-indigo-500'
                                  }`}>
                                    {log.type.replace('_', ' ')}
                                  </span>
                                </td>
                                <td className="px-4 py-3 text-right text-text-muted">{log.prevStock}</td>
                                <td className="px-4 py-3 text-right text-text-primary font-bold">{log.newStock}</td>
                              </tr>
                            )
                          })}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}

              </div>
            </motion.div>
          )}

        </AnimatePresence>
      </div>

      {/* Camera Scanner Modal Overlay for Inward */}
      <AnimatePresence>
        {isInwardCameraScanning && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
          >
            <motion.div
              initial={{ scale: 0.95, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.95, y: 20 }}
              className="bg-zinc-900 border border-zinc-800 text-white rounded-3xl p-5 w-full max-w-sm flex flex-col items-center space-y-4 shadow-2xl"
            >
              <div className="text-center w-full flex justify-between items-center pb-2 border-b border-zinc-800">
                <span className="text-xs font-extrabold tracking-wider text-accent flex items-center gap-1.5">
                  <Camera className="h-4 w-4" /> CAMERA BARCODE SCANNER
                </span>
                <button
                  type="button"
                  onClick={stopInwardCamera}
                  className="text-xs text-zinc-400 hover:text-white font-bold cursor-pointer transition-colors"
                >
                  Close
                </button>
              </div>

              {/* Camera view screen */}
              <div className="relative w-full h-[240px] rounded-2xl overflow-hidden bg-black border border-zinc-800 flex items-center justify-center">
                <video
                  ref={inwardVideoRef}
                  autoPlay
                  playsInline
                  className="w-full h-full object-cover"
                />
                
                {/* Scanner targeting laser line */}
                <div className="absolute left-4 right-4 h-0.5 bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.8)] animate-pulse" style={{ top: '50%' }} />
                
                {/* Simulated frame */}
                <div className="absolute inset-8 border border-white/20 rounded-xl pointer-events-none flex items-center justify-center">
                  <span className="text-[10px] text-white/50 font-bold bg-black/40 px-2 py-0.5 rounded">Center Barcode</span>
                </div>
              </div>

              <div className="text-center w-full space-y-2">
                <p className="text-[11px] font-bold text-zinc-400 animate-pulse">
                  Hold barcode up to camera...
                </p>
                <p className="text-[9px] text-zinc-500">
                  Detects standard barcodes (UPC/EAN/Code-128) automatically.
                </p>
              </div>

              {/* Backup / Simulator for testing */}
              <div className="w-full pt-3 border-t border-zinc-800 space-y-2">
                <span className="text-[9px] font-extrabold uppercase tracking-wider text-zinc-500 block">
                  Scan Simulator / Backup Selection
                </span>
                <div className="flex gap-2">
                  <select
                    className="flex-1 bg-zinc-800 border border-zinc-700 text-white rounded-lg px-2 py-1.5 text-[10px] focus:outline-none focus:border-accent font-semibold"
                    onChange={(e) => {
                      const val = e.target.value
                      if (val) {
                        const prod = products.find(p => p.id === val)
                        if (prod && prod.barcode) {
                          handleBarcodeSubmit(undefined, prod.barcode)
                          stopInwardCamera()
                        } else {
                          toast.error("This product has no barcode to scan!")
                        }
                      }
                    }}
                    defaultValue=""
                  >
                    <option value="" disabled>Select a product to simulate scan...</option>
                    {products.map(p => (
                      <option key={p.id} value={p.id}>
                        {p.name} {p.barcode ? `(${p.barcode})` : '(No Barcode)'}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  )
}
