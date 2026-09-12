'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'
import {
  Truck,
  Plus,
  Search,
  Calendar,
  IndianRupee,
  Phone,
  Building2,
  Download,
  Send,
  CheckCircle2,
  AlertTriangle,
  RefreshCw,
  Edit2,
  Copy,
  ExternalLink,
  Package,
  Layers,
  ArrowUpRight,
  TrendingUp,
  CreditCard,
  FileSpreadsheet,
  X,
  Loader2,
  ChevronRight,
  Trash2,
} from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'
import * as XLSX from 'xlsx'

interface Vendor {
  id: string
  vendorCode?: string
  name: string
  phone: string | null
  email: string | null
  companyName: string | null
  gstin: string | null
  upiId: string | null
  bankName: string | null
  accountNo: string | null
  ifscCode: string | null
  address: string | null
  isActive: boolean
  storeId?: string | null
  productCount?: number
  payoutCount?: number
}

interface VendorPayout {
  id: string
  vendorId: string
  amount: number
  startDate: string
  endDate: string
  paymentMethod: string
  transactionId: string | null
  paidAt: string | null
  status: string
  notes: string | null
  createdAt: string
}

interface ItemizedSale {
  productId: string
  name: string
  categoryName: string
  barcode: string | null
  unitsSold: number
  unitCostPrice: number
  sellingPrice: number
  totalPayable: number
  currentStock: number
}

interface LowStockItem {
  id: string
  name: string
  barcode: string | null
  stock: number
  minStock: number
  costPrice: number
  isLow: boolean
}

interface ProductItem {
  id: string
  name: string
  barcode: string | null
  price: number
  mrp: number
  costPrice: number
  stock: number
  category?: string
  imageUrl?: string | null
  isAvailable: boolean
}

interface AdminVendorConsoleProps {
  storeId?: string
}

export function AdminVendorConsole({ storeId }: AdminVendorConsoleProps) {
  const [vendors, setVendors] = useState<Vendor[]>([])
  const [selectedVendorId, setSelectedVendorId] = useState<string>('')
  const [loadingVendors, setLoadingVendors] = useState<boolean>(true)
  const [loadingDetails, setLoadingDetails] = useState<boolean>(false)

  // Sub-tabs: 'ledger' | 'catalog' | 'reorder'
  const [activeTab, setActiveTab] = useState<'ledger' | 'catalog' | 'reorder'>('ledger')

  // Date range filter
  const todayStr = useMemo(() => new Date().toISOString().split('T')[0], [])
  const firstDayThisMonth = useMemo(() => {
    const d = new Date()
    return new Date(d.getFullYear(), d.getMonth(), 1).toISOString().split('T')[0]
  }, [])
  const [startDate, setStartDate] = useState<string>(firstDayThisMonth)
  const [endDate, setEndDate] = useState<string>(todayStr)
  const [dateFilterPreset, setDateFilterPreset] = useState<'thisMonth' | 'lastMonth' | 'last30' | 'custom'>('thisMonth')

  // Details Data
  const [vendorDetails, setVendorDetails] = useState<Vendor | null>(null)
  const [kpis, setKpis] = useState({
    totalProducts: 0,
    totalUnitsSold: 0,
    totalPayableAmount: 0,
    totalPaidInPeriod: 0,
    pendingBalance: 0,
    totalPaidLifetime: 0,
    lowStockCount: 0,
  })
  const [itemizedSales, setItemizedSales] = useState<ItemizedSale[]>([])
  const [payouts, setPayouts] = useState<VendorPayout[]>([])
  const [productsCatalog, setProductsCatalog] = useState<ProductItem[]>([])
  const [lowStockItems, setLowStockItems] = useState<LowStockItem[]>([])

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('')

  // Modals
  const [showVendorModal, setShowVendorModal] = useState(false)
  const [vendorModalMode, setVendorModalMode] = useState<'create' | 'edit'>('create')
  const [savingVendor, setSavingVendor] = useState(false)
  const [vendorFormData, setVendorFormData] = useState({
    id: '',
    name: '',
    phone: '',
    email: '',
    companyName: '',
    gstin: '',
    upiId: '',
    bankName: '',
    accountNo: '',
    ifscCode: '',
    address: '',
    isActive: true,
    storeId: '',
  })
  const [storesList, setStoresList] = useState<{ id: string; name: string }[]>([])

  useEffect(() => {
    fetch('/api/admin/stores')
      .then((res) => res.json())
      .then((data) => {
        const list = Array.isArray(data.stores) ? data.stores : (Array.isArray(data) ? data : [])
        setStoresList(list)
      })
      .catch(() => {})
  }, [])

  // Record Payout Modal
  const [showPayoutModal, setShowPayoutModal] = useState(false)
  const [savingPayout, setSavingPayout] = useState(false)
  const [payoutFormData, setPayoutFormData] = useState({
    amount: '',
    paymentMethod: 'UPI',
    transactionId: '',
    notes: '',
  })

  // WhatsApp PO Quantities
  const [orderQuantities, setOrderQuantities] = useState<Record<string, number>>({})

  // Fetch Vendors list
  const fetchVendors = useCallback(async () => {
    setLoadingVendors(true)
    try {
      const storeParam = storeId && storeId !== 'all' ? `?storeId=${encodeURIComponent(storeId)}` : ''
      const res = await fetch(`/api/admin/vendors${storeParam}`)
      if (res.ok) {
        const data = await res.json()
        const list = Array.isArray(data.vendors) ? data.vendors : []
        setVendors(list)
        if (list.length > 0 && !selectedVendorId) {
          setSelectedVendorId(list[0].id)
        }
      }
    } catch (e) {
      console.error('Failed to load vendors:', e)
      toast.error('Could not load vendors list')
    } finally {
      setLoadingVendors(false)
    }
  }, [selectedVendorId, storeId])

  useEffect(() => {
    fetchVendors()
  }, [fetchVendors])

  // Fetch Single Vendor Details
  const fetchVendorDetails = useCallback(async () => {
    if (!selectedVendorId) return
    setLoadingDetails(true)
    try {
      const storeParam = storeId && storeId !== 'all' ? `&storeId=${encodeURIComponent(storeId)}` : ''
      const res = await fetch(
        `/api/admin/vendors/${selectedVendorId}?startDate=${startDate}&endDate=${endDate}${storeParam}`
      )
      if (res.ok) {
        const data = await res.json()
        setVendorDetails(data.vendor)
        setKpis(data.kpis || {
          totalProducts: 0,
          totalUnitsSold: 0,
          totalPayableAmount: 0,
          totalPaidInPeriod: 0,
          pendingBalance: 0,
          totalPaidLifetime: 0,
          lowStockCount: 0,
        })
        setItemizedSales(data.itemizedSales || [])
        setPayouts(data.payouts || [])
        setProductsCatalog(data.products || [])
        setLowStockItems(data.lowStockItems || [])

        // Initialize default PO quantities (e.g. 20 units or reorder delta)
        const initialQtys: Record<string, number> = {}
        ;(data.lowStockItems || []).forEach((item: LowStockItem) => {
          initialQtys[item.id] = Math.max(10, (item.minStock * 2) - item.stock)
        })
        setOrderQuantities(initialQtys)
      } else {
        toast.error('Failed to load vendor ledger')
      }
    } catch (e) {
      console.error(e)
      toast.error('Error fetching vendor data')
    } finally {
      setLoadingDetails(false)
    }
  }, [selectedVendorId, startDate, endDate, storeId])

  useEffect(() => {
    fetchVendorDetails()
  }, [fetchVendorDetails])

  // Preset Date Handlers
  const handlePresetDate = (preset: 'thisMonth' | 'lastMonth' | 'last30') => {
    setDateFilterPreset(preset)
    const now = new Date()
    if (preset === 'thisMonth') {
      const s = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const e = todayStr
      setStartDate(s)
      setEndDate(e)
    } else if (preset === 'lastMonth') {
      const s = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString().split('T')[0]
      const e = new Date(now.getFullYear(), now.getMonth(), 0).toISOString().split('T')[0]
      setStartDate(s)
      setEndDate(e)
    } else if (preset === 'last30') {
      const d = new Date()
      d.setDate(d.getDate() - 30)
      setStartDate(d.toISOString().split('T')[0])
      setEndDate(todayStr)
    }
  }

  // Open Create Modal
  const handleOpenCreateModal = () => {
    setVendorModalMode('create')
    setVendorFormData({
      id: '',
      name: '',
      phone: '',
      email: '',
      companyName: '',
      gstin: '',
      upiId: '',
      bankName: '',
      accountNo: '',
      ifscCode: '',
      address: '',
      isActive: true,
      storeId: storeId && storeId !== 'all' ? storeId : '',
    })
    setShowVendorModal(true)
  }

  // Open Edit Modal
  const handleOpenEditModal = () => {
    if (!vendorDetails) return
    setVendorModalMode('edit')
    setVendorFormData({
      id: vendorDetails.id,
      name: vendorDetails.name,
      phone: vendorDetails.phone || '',
      email: vendorDetails.email || '',
      companyName: vendorDetails.companyName || '',
      gstin: vendorDetails.gstin || '',
      upiId: vendorDetails.upiId || '',
      bankName: vendorDetails.bankName || '',
      accountNo: vendorDetails.accountNo || '',
      ifscCode: vendorDetails.ifscCode || '',
      address: vendorDetails.address || '',
      isActive: vendorDetails.isActive,
      storeId: vendorDetails.storeId || '',
    })
    setShowVendorModal(true)
  }

  // Save Vendor
  const handleSaveVendor = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!vendorFormData.name.trim()) {
      toast.error('Vendor name is required')
      return
    }
    setSavingVendor(true)
    try {
      const res = await fetch('/api/admin/vendors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...vendorFormData,
          storeId: vendorFormData.storeId || null,
        }),
      })

      const data = await res.json()
      if (res.ok) {
        toast.success(vendorModalMode === 'create' ? 'Vendor created successfully' : 'Vendor updated successfully')
        setShowVendorModal(false)
        await fetchVendors()
        if (data.vendor?.id) {
          setSelectedVendorId(data.vendor.id)
        }
      } else {
        toast.error(data.error || 'Failed to save vendor')
      }
    } catch (e: any) {
      toast.error(e.message || 'Error saving vendor')
    } finally {
      setSavingVendor(false)
    }
  }

  // Open Record Payout Modal
  const handleOpenPayoutModal = () => {
    setPayoutFormData({
      amount: kpis.pendingBalance > 0 ? String(kpis.pendingBalance) : '',
      paymentMethod: 'UPI',
      transactionId: '',
      notes: `Settlement for period ${startDate} to ${endDate}`,
    })
    setShowPayoutModal(true)
  }

  // Save Payout
  const handleSavePayout = async (e: React.FormEvent) => {
    e.preventDefault()
    const amountNum = parseFloat(payoutFormData.amount)
    if (isNaN(amountNum) || amountNum <= 0) {
      toast.error('Please enter a valid amount')
      return
    }

    setSavingPayout(true)
    try {
      const res = await fetch('/api/admin/vendors/payout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          vendorId: selectedVendorId,
          amount: amountNum,
          startDate,
          endDate,
          paymentMethod: payoutFormData.paymentMethod,
          transactionId: payoutFormData.transactionId,
          notes: payoutFormData.notes,
          storeId: storeId && storeId !== 'all' ? storeId : null,
        }),
      })

      if (res.ok) {
        toast.success('Payout recorded successfully!')
        setShowPayoutModal(false)
        fetchVendorDetails()
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to record payout')
      }
    } catch (e: any) {
      toast.error(e.message || 'Error recording payout')
    } finally {
      setSavingPayout(false)
    }
  }

  // Delete Payout
  const handleDeletePayout = async (payoutId: string) => {
    if (!confirm('Are you sure you want to void this payout entry?')) return
    try {
      const res = await fetch(`/api/admin/vendors/payout?payoutId=${encodeURIComponent(payoutId)}`, {
        method: 'DELETE',
      })
      if (res.ok) {
        toast.success('Payout deleted')
        fetchVendorDetails()
      } else {
        toast.error('Failed to delete payout')
      }
    } catch (e) {
      toast.error('Error deleting payout')
    }
  }

  // Copy to clipboard helper
  const copyToClipboard = (text: string, label: string) => {
    if (!text) return
    navigator.clipboard.writeText(text)
    toast.success(`Copied ${label} to clipboard!`)
  }

  // Generate WhatsApp Purchase Order
  const handleSendWhatsAppPO = () => {
    if (!vendorDetails?.phone) {
      toast.error('Vendor phone number is missing! Add phone in Edit Profile.')
      return
    }

    const itemsToOrder = lowStockItems.map((item) => {
      const qty = orderQuantities[item.id] || Math.max(10, item.minStock * 2 - item.stock)
      return {
        name: item.name,
        qty,
        stock: item.stock,
      }
    })

    if (itemsToOrder.length === 0) {
      toast.info('No low-stock items detected for this vendor.')
      return
    }

    let message = `*PURCHASE ORDER - FASTKIRANA*\n`
    message += `Vendor Code: *${vendorDetails.vendorCode || 'VND-001'}*\n`
    message += `To: ${vendorDetails.name} (${vendorDetails.companyName || 'Supplier'})\n`
    message += `Date: ${todayStr}\n`
    message += `Store: Akbarpur Central Hub\n\n`
    message += `*Items Required Immediately:*\n`

    itemsToOrder.forEach((item, index) => {
      message += `${index + 1}. *${item.name}* - *Qty: ${item.qty}* (Current Stock: ${item.stock})\n`
    })

    message += `\nPlease confirm dispatch time and estimated invoice. Thank you!\n`
    message += `— FastKirana Procurement Team`

    const cleanPhone = vendorDetails.phone.replace(/\D/g, '')
    const phoneWithCountry = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone
    const url = `https://wa.me/${phoneWithCountry}?text=${encodeURIComponent(message)}`
    window.open(url, '_blank')
  }

  // Export Vendor Statement to Excel (.xlsx)
  const handleExportStatement = () => {
    if (!vendorDetails) return

    try {
      const wb = XLSX.utils.book_new()

      // Sheet 1: Sales & Bill Summary
      const summaryRows: any[] = [
        ['FASTKIRANA - VENDOR BILLING STATEMENT'],
        ['Generated At:', new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })],
        ['Period:', `${startDate} to ${endDate}`],
        [],
        ['VENDOR PROFILE'],
        ['Vendor Code:', vendorDetails.vendorCode || 'N/A'],
        ['Vendor Name:', vendorDetails.name],
        ['Company / Entity:', vendorDetails.companyName || 'N/A'],
        ['Contact Phone:', vendorDetails.phone || 'N/A'],
        ['UPI ID:', vendorDetails.upiId || 'N/A'],
        ['Bank Details:', `${vendorDetails.bankName || ''} - A/C: ${vendorDetails.accountNo || ''} (IFSC: ${vendorDetails.ifscCode || ''})`],
        ['GSTIN:', vendorDetails.gstin || 'N/A'],
        [],
        ['FINANCIAL LEDGER SUMMARY'],
        ['Total Products Linked:', kpis.totalProducts],
        ['Units Sold (Delivered):', kpis.totalUnitsSold],
        ['Total Payable (At Cost Price):', `Rs. ${kpis.totalPayableAmount.toFixed(2)}`],
        ['Total Paid in Period:', `Rs. ${kpis.totalPaidInPeriod.toFixed(2)}`],
        ['Pending Balance to Pay:', `Rs. ${kpis.pendingBalance.toFixed(2)}`],
        [],
        ['DELIVERED ITEMS BREAKDOWN (AT COST PRICE)'],
        ['S.No', 'Product Name', 'Category', 'Barcode', 'Current Stock', 'Units Delivered', 'Unit Cost Price (Rs)', 'Total Payable (Rs)'],
      ]

      itemizedSales.forEach((item, idx) => {
        summaryRows.push([
          idx + 1,
          item.name,
          item.categoryName,
          item.barcode || '',
          item.currentStock,
          item.unitsSold,
          item.unitCostPrice,
          item.totalPayable,
        ])
      })

      // Sheet 2: Payouts History
      const payoutRows: any[] = [
        ['FASTKIRANA - RECORDED VENDOR PAYOUTS'],
        ['Vendor Name:', vendorDetails.name],
        [],
        ['S.No', 'Date & Time', 'Amount (Rs)', 'Payment Method', 'UTR / Ref No', 'Status', 'Notes'],
      ]

      payouts.forEach((p, idx) => {
        payoutRows.push([
          idx + 1,
          new Date(p.paidAt || p.createdAt).toLocaleString('en-IN'),
          p.amount,
          p.paymentMethod,
          p.transactionId || 'N/A',
          p.status,
          p.notes || '',
        ])
      })

      const wsSummary = XLSX.utils.aoa_to_sheet(summaryRows)
      const wsPayouts = XLSX.utils.aoa_to_sheet(payoutRows)

      XLSX.utils.book_append_sheet(wb, wsSummary, 'Billing_Summary')
      XLSX.utils.book_append_sheet(wb, wsPayouts, 'Recorded_Payouts')

      const sanitizedVendorName = vendorDetails.name.replace(/[^a-zA-Z0-9_-]/g, '_')
      const fileName = `FastKirana_Vendor_${sanitizedVendorName}_${startDate}_to_${endDate}.xlsx`
      XLSX.writeFile(wb, fileName)
      toast.success(`Statement exported to ${fileName}`)
    } catch (e: any) {
      console.error(e)
      toast.error('Failed to export statement')
    }
  }

  // Filter items in tables
  const filteredSales = useMemo(() => {
    if (!searchQuery.trim()) return itemizedSales
    const q = searchQuery.toLowerCase()
    return itemizedSales.filter(
      (item) =>
        item.name.toLowerCase().includes(q) ||
        (item.barcode && item.barcode.includes(q)) ||
        item.categoryName.toLowerCase().includes(q)
    )
  }, [itemizedSales, searchQuery])

  const filteredCatalog = useMemo(() => {
    if (!searchQuery.trim()) return productsCatalog
    const q = searchQuery.toLowerCase()
    return productsCatalog.filter(
      (prod) =>
        prod.name.toLowerCase().includes(q) ||
        (prod.barcode && prod.barcode.includes(q)) ||
        (prod.category && prod.category.toLowerCase().includes(q))
    )
  }, [productsCatalog, searchQuery])

  return (
    <div className="space-y-6 animate-fade-in pb-12">
      {/* ── Top Header & Global Actions ── */}
      <div className="flex flex-col lg:flex-row gap-4 items-start lg:items-center justify-between bg-card p-5 rounded-2xl border border-border/80 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="h-12 w-12 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary shadow-inner">
            <Truck className="h-6 w-6" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-black text-text-primary tracking-tight">Vendor Management Console</h1>
              <span className="px-2 py-0.5 text-[10px] font-black uppercase rounded-full bg-emerald-500/10 text-emerald-600 border border-emerald-500/20">
                Relational ID Mode
              </span>
            </div>
            <p className="text-xs text-text-secondary mt-0.5">
              Cost-price sales settlement, instant ledger, digital payout slips & WhatsApp purchase orders
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2.5 w-full lg:w-auto">
          {/* Vendor Selector Dropdown */}
          <div className="relative min-w-[220px] flex-1 lg:flex-none">
            <select
              value={selectedVendorId}
              onChange={(e) => setSelectedVendorId(e.target.value)}
              disabled={loadingVendors || vendors.length === 0}
              className="w-full pl-3 pr-8 py-2.5 text-xs font-bold rounded-xl border border-border bg-background focus:outline-none focus:ring-2 focus:ring-primary/20 appearance-none cursor-pointer"
            >
              {vendors.length === 0 && <option value="">No vendors found</option>}
              {vendors.map((v) => (
                <option key={v.id} value={v.id}>
                  [{v.vendorCode || 'VND'}] {v.name} {v.companyName ? `(${v.companyName})` : ''} • {v.productCount || 0} items
                </option>
              ))}
            </select>
            <ChevronRight className="absolute right-3 top-3 h-4 w-4 text-text-muted rotate-90 pointer-events-none" />
          </div>

          {/* Add Vendor Button */}
          <button
            type="button"
            onClick={handleOpenCreateModal}
            className="flex items-center gap-1.5 px-3.5 py-2.5 bg-primary text-primary-foreground text-xs font-black rounded-xl hover:bg-primary/90 transition shadow-sm cursor-pointer select-none"
          >
            <Plus className="h-4 w-4" />
            <span>New Vendor</span>
          </button>

          {/* Refresh button */}
          <button
            type="button"
            onClick={() => {
              fetchVendors()
              fetchVendorDetails()
            }}
            disabled={loadingDetails}
            className="p-2.5 rounded-xl border border-border hover:bg-muted/50 transition cursor-pointer text-text-muted hover:text-text-primary"
            title="Refresh Ledger"
          >
            <RefreshCw className={`h-4 w-4 ${loadingDetails ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* ── Active Vendor Profile Banner ── */}
      {vendorDetails ? (
        <div className="bg-gradient-to-br from-card via-card to-primary/5 p-5 rounded-2xl border border-primary/20 shadow-sm space-y-4">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2.5 flex-wrap">
                <span className="px-2.5 py-1 text-xs font-black rounded-lg bg-primary text-primary-foreground font-mono shadow-sm">
                  {vendorDetails.vendorCode || 'VND-001'}
                </span>
                <h2 className="text-lg font-black text-text-primary">{vendorDetails.name}</h2>
                {vendorDetails.companyName && (
                  <span className="text-xs font-bold text-text-muted">({vendorDetails.companyName})</span>
                )}
                <span
                  className={`px-2 py-0.5 text-[10px] font-black rounded-full ${
                    vendorDetails.isActive
                      ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                      : 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                  }`}
                >
                  {vendorDetails.isActive ? 'ACTIVE' : 'INACTIVE'}
                </span>
              </div>
              <p className="text-xs text-text-secondary flex items-center gap-2 flex-wrap">
                <span>Vendor Code: <strong className="text-primary font-mono">{vendorDetails.vendorCode || 'VND-001'}</strong></span>
                <span className="text-text-muted">•</span>
                <span>DB ID: <code className="bg-muted px-1.5 py-0.5 rounded font-mono text-[10px] text-text-muted">{vendorDetails.id}</code></span>
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                onClick={handleOpenEditModal}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-lg border border-border hover:bg-muted transition text-text-secondary hover:text-text-primary"
              >
                <Edit2 className="h-3.5 w-3.5" />
                <span>Edit Profile</span>
              </button>

              <button
                type="button"
                onClick={handleSendWhatsAppPO}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white transition shadow-sm"
              >
                <Send className="h-3.5 w-3.5" />
                <span>WhatsApp PO ({lowStockItems.length} Low)</span>
              </button>

              <button
                type="button"
                onClick={handleExportStatement}
                className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-lg bg-primary text-primary-foreground hover:bg-primary/90 transition shadow-sm"
              >
                <FileSpreadsheet className="h-3.5 w-3.5" />
                <span>Export Statement (.xlsx)</span>
              </button>
            </div>
          </div>

          {/* Quick Details Chips */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 pt-2 border-t border-border/60">
            {/* Phone */}
            <div className="flex items-center gap-2.5 text-xs">
              <Phone className="h-4 w-4 text-primary shrink-0" />
              <div>
                <span className="text-[10px] uppercase font-bold text-text-muted block">Phone / WhatsApp</span>
                <span className="font-bold text-text-primary">{vendorDetails.phone || 'Not provided'}</span>
              </div>
            </div>

            {/* UPI ID */}
            <div className="flex items-center gap-2.5 text-xs">
              <CreditCard className="h-4 w-4 text-indigo-500 shrink-0" />
              <div className="flex-1 min-w-0">
                <span className="text-[10px] uppercase font-bold text-text-muted block">UPI ID</span>
                <div className="flex items-center gap-1.5">
                  <span className="font-bold text-text-primary truncate">{vendorDetails.upiId || 'Not provided'}</span>
                  {vendorDetails.upiId && (
                    <button
                      type="button"
                      onClick={() => copyToClipboard(vendorDetails.upiId!, 'UPI ID')}
                      className="text-text-muted hover:text-primary transition"
                      title="Copy UPI"
                    >
                      <Copy className="h-3 w-3" />
                    </button>
                  )}
                </div>
              </div>
            </div>

            {/* Bank Info */}
            <div className="flex items-center gap-2.5 text-xs">
              <Building2 className="h-4 w-4 text-emerald-500 shrink-0" />
              <div className="flex-1 min-w-0">
                <span className="text-[10px] uppercase font-bold text-text-muted block">Bank Account / IFSC</span>
                <span className="font-bold text-text-primary truncate block">
                  {vendorDetails.bankName || 'Bank'} {vendorDetails.accountNo ? `• ${vendorDetails.accountNo}` : 'N/A'}
                </span>
              </div>
            </div>

            {/* GSTIN */}
            <div className="flex items-center gap-2.5 text-xs">
              <IndianRupee className="h-4 w-4 text-amber-500 shrink-0" />
              <div>
                <span className="text-[10px] uppercase font-bold text-text-muted block">GSTIN</span>
                <span className="font-bold text-text-primary">{vendorDetails.gstin || 'Unregistered'}</span>
              </div>
            </div>
          </div>
        </div>
      ) : (
        <div className="p-8 text-center bg-card rounded-2xl border border-dashed border-border">
          <Truck className="h-10 w-10 text-text-muted mx-auto mb-2 opacity-50" />
          <h3 className="text-sm font-bold text-text-primary">No Vendor Selected</h3>
          <p className="text-xs text-text-muted mt-1 max-w-sm mx-auto">
            Please add a vendor or select one from the dropdown to view ledger, sales at cost price, and payouts.
          </p>
          <button
            type="button"
            onClick={handleOpenCreateModal}
            className="mt-4 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl shadow-sm"
          >
            + Create First Vendor
          </button>
        </div>
      )}

      {/* ── Date Range Controls ── */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-card p-3.5 rounded-2xl border border-border shadow-sm">
        <div className="flex items-center gap-1.5 overflow-x-auto scrollbar-none">
          <button
            type="button"
            onClick={() => handlePresetDate('thisMonth')}
            className={`px-3 py-1.5 text-xs font-black rounded-xl transition cursor-pointer select-none ${
              dateFilterPreset === 'thisMonth'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-muted/60 text-text-secondary hover:text-text-primary'
            }`}
          >
            This Month
          </button>
          <button
            type="button"
            onClick={() => handlePresetDate('lastMonth')}
            className={`px-3 py-1.5 text-xs font-black rounded-xl transition cursor-pointer select-none ${
              dateFilterPreset === 'lastMonth'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-muted/60 text-text-secondary hover:text-text-primary'
            }`}
          >
            Last Month
          </button>
          <button
            type="button"
            onClick={() => handlePresetDate('last30')}
            className={`px-3 py-1.5 text-xs font-black rounded-xl transition cursor-pointer select-none ${
              dateFilterPreset === 'last30'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-muted/60 text-text-secondary hover:text-text-primary'
            }`}
          >
            Last 30 Days
          </button>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 bg-muted/40 px-3 py-1.5 rounded-xl border border-border/60">
            <Calendar className="h-3.5 w-3.5 text-text-muted" />
            <input
              type="date"
              value={startDate}
              onChange={(e) => {
                setStartDate(e.target.value)
                setDateFilterPreset('custom')
              }}
              className="bg-transparent text-xs font-bold text-text-primary focus:outline-none cursor-pointer"
            />
            <span className="text-text-muted text-xs">to</span>
            <input
              type="date"
              value={endDate}
              onChange={(e) => {
                setEndDate(e.target.value)
                setDateFilterPreset('custom')
              }}
              className="bg-transparent text-xs font-bold text-text-primary focus:outline-none cursor-pointer"
            />
          </div>
        </div>
      </div>

      {/* ── KPI Cards ── */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3.5">
        {/* Products Linked */}
        <div className="bg-card p-4 rounded-2xl border border-border shadow-sm">
          <div className="flex items-center justify-between text-text-muted mb-1.5">
            <span className="text-[11px] font-bold uppercase tracking-wider">Catalog Items</span>
            <Package className="h-4 w-4 text-primary" />
          </div>
          <div className="text-xl font-black text-text-primary">{kpis.totalProducts}</div>
          <p className="text-[10px] text-text-muted mt-1">Assigned to this vendor</p>
        </div>

        {/* Units Sold (Delivered) */}
        <div className="bg-card p-4 rounded-2xl border border-border shadow-sm">
          <div className="flex items-center justify-between text-text-muted mb-1.5">
            <span className="text-[11px] font-bold uppercase tracking-wider">Units Delivered</span>
            <TrendingUp className="h-4 w-4 text-emerald-500" />
          </div>
          <div className="text-xl font-black text-emerald-600">{kpis.totalUnitsSold}</div>
          <p className="text-[10px] text-text-muted mt-1">In selected period</p>
        </div>

        {/* Total Payable */}
        <div className="bg-card p-4 rounded-2xl border border-border shadow-sm">
          <div className="flex items-center justify-between text-text-muted mb-1.5">
            <span className="text-[11px] font-bold uppercase tracking-wider">Total Billed</span>
            <IndianRupee className="h-4 w-4 text-blue-500" />
          </div>
          <div className="text-xl font-black text-blue-600">{formatPrice(kpis.totalPayableAmount)}</div>
          <p className="text-[10px] text-text-muted mt-1">At unit cost prices</p>
        </div>

        {/* Total Settled / Paid */}
        <div className="bg-card p-4 rounded-2xl border border-border shadow-sm">
          <div className="flex items-center justify-between text-text-muted mb-1.5">
            <span className="text-[11px] font-bold uppercase tracking-wider">Settled / Paid</span>
            <CheckCircle2 className="h-4 w-4 text-emerald-500" />
          </div>
          <div className="text-xl font-black text-emerald-600">{formatPrice(kpis.totalPaidInPeriod)}</div>
          <p className="text-[10px] text-text-muted mt-1">Paid in this period</p>
        </div>

        {/* Pending Balance */}
        <div
          className={`p-4 rounded-2xl border shadow-sm ${
            kpis.pendingBalance > 0
              ? 'bg-amber-500/10 border-amber-500/30'
              : 'bg-emerald-500/10 border-emerald-500/30'
          }`}
        >
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-[11px] font-bold uppercase tracking-wider text-text-primary">
              Pending Balance
            </span>
            <IndianRupee
              className={`h-4 w-4 ${kpis.pendingBalance > 0 ? 'text-amber-600' : 'text-emerald-600'}`}
            />
          </div>
          <div
            className={`text-xl font-black ${
              kpis.pendingBalance > 0 ? 'text-amber-600' : 'text-emerald-600'
            }`}
          >
            {formatPrice(kpis.pendingBalance)}
          </div>
          <button
            type="button"
            onClick={handleOpenPayoutModal}
            className="mt-1 text-[10px] font-black underline uppercase text-primary hover:text-primary/80 block"
          >
            + Record Payout Now
          </button>
        </div>
      </div>

      {/* ── Sub-Tab Navigation & Search ── */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 border-b border-border/80 pb-3">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setActiveTab('ledger')}
            className={`px-4 py-2 text-xs font-black rounded-xl transition cursor-pointer select-none ${
              activeTab === 'ledger'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-card text-text-secondary hover:text-text-primary border border-border'
            }`}
          >
            📊 Settlement & Payout Ledger
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('catalog')}
            className={`px-4 py-2 text-xs font-black rounded-xl transition cursor-pointer select-none ${
              activeTab === 'catalog'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-card text-text-secondary hover:text-text-primary border border-border'
            }`}
          >
            🏷️ Products Catalog ({productsCatalog.length})
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('reorder')}
            className={`px-4 py-2 text-xs font-black rounded-xl transition cursor-pointer select-none relative ${
              activeTab === 'reorder'
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-card text-text-secondary hover:text-text-primary border border-border'
            }`}
          >
            📱 WhatsApp Reorder PO
            {lowStockItems.length > 0 && (
              <span className="ml-1.5 px-1.5 py-0.2 text-[9px] font-bold rounded-full bg-rose-500 text-white">
                {lowStockItems.length}
              </span>
            )}
          </button>
        </div>

        <div className="relative w-full sm:w-64">
          <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
          <input
            type="text"
            placeholder="Search items or barcode..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-border bg-card focus:outline-none focus:ring-1 focus:ring-primary font-medium"
          />
        </div>
      </div>

      {/* ── TAB 1: SETTLEMENT & PAYOUTS LEDGER ── */}
      {activeTab === 'ledger' && (
        <div className="space-y-6">
          {/* Action Row */}
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
              <span>Delivered Sales at Cost Price</span>
              <span className="text-xs text-text-muted font-normal">
                ({filteredSales.length} items sold in selected period)
              </span>
            </h3>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={handleOpenPayoutModal}
                className="flex items-center gap-1 px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-sm transition cursor-pointer"
              >
                <Plus className="h-3.5 w-3.5" />
                <span>Record Payout</span>
              </button>
            </div>
          </div>

          {/* Delivered Sales Table */}
          <div className="bg-card rounded-2xl border border-border overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-muted/50 border-b border-border text-[11px] font-black uppercase text-text-muted">
                  <tr>
                    <th className="p-3">Product Name</th>
                    <th className="p-3">Category</th>
                    <th className="p-3">Barcode</th>
                    <th className="p-3 text-right">Units Sold</th>
                    <th className="p-3 text-right">Unit Cost</th>
                    <th className="p-3 text-right">Total Payable</th>
                    <th className="p-3 text-center">Current Stock</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60 font-medium">
                  {loadingDetails ? (
                    <tr>
                      <td colSpan={7} className="p-8 text-center text-text-muted">
                        <Loader2 className="h-6 w-6 animate-spin mx-auto mb-2 text-primary" />
                        Calculating delivered sales ledger...
                      </td>
                    </tr>
                  ) : filteredSales.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="p-8 text-center text-text-muted">
                        No sales found for this vendor in the selected period.
                      </td>
                    </tr>
                  ) : (
                    filteredSales.map((item) => (
                      <tr key={item.productId} className="hover:bg-muted/30 transition">
                        <td className="p-3 font-bold text-text-primary">{item.name}</td>
                        <td className="p-3 text-text-secondary">{item.categoryName}</td>
                        <td className="p-3 font-mono text-[11px] text-text-muted">
                          {item.barcode || '—'}
                        </td>
                        <td className="p-3 text-right font-black text-emerald-600">
                          {item.unitsSold}
                        </td>
                        <td className="p-3 text-right font-bold text-text-primary">
                          {formatPrice(item.unitCostPrice)}
                        </td>
                        <td className="p-3 text-right font-black text-primary">
                          {formatPrice(item.totalPayable)}
                        </td>
                        <td className="p-3 text-center">
                          <span
                            className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                              item.currentStock <= 5
                                ? 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                                : 'bg-muted text-text-secondary'
                            }`}
                          >
                            {item.currentStock} in stock
                          </span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Recorded Payouts History Section */}
          <div className="space-y-3 pt-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                <span>Payment & Payout History</span>
                <span className="text-xs text-text-muted font-normal">
                  ({payouts.length} transactions recorded)
                </span>
              </h3>
            </div>

            <div className="bg-card rounded-2xl border border-border overflow-hidden shadow-sm">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="bg-muted/50 border-b border-border text-[11px] font-black uppercase text-text-muted">
                    <tr>
                      <th className="p-3">Payment Date</th>
                      <th className="p-3">Amount</th>
                      <th className="p-3">Method</th>
                      <th className="p-3">UTR / Ref Number</th>
                      <th className="p-3">Billing Period</th>
                      <th className="p-3">Notes</th>
                      <th className="p-3 text-center">Status</th>
                      <th className="p-3 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border/60 font-medium">
                    {payouts.length === 0 ? (
                      <tr>
                        <td colSpan={8} className="p-6 text-center text-text-muted">
                          No payouts recorded yet for this vendor.
                        </td>
                      </tr>
                    ) : (
                      payouts.map((p) => (
                        <tr key={p.id} className="hover:bg-muted/30 transition">
                          <td className="p-3 font-bold text-text-primary">
                            {new Date(p.paidAt || p.createdAt).toLocaleDateString('en-IN', {
                              day: '2-digit',
                              month: 'short',
                              year: 'numeric',
                            })}
                          </td>
                          <td className="p-3 font-black text-emerald-600">
                            {formatPrice(p.amount)}
                          </td>
                          <td className="p-3 font-bold text-text-secondary">
                            <span className="px-2 py-0.5 rounded bg-muted text-[10px]">
                              {p.paymentMethod}
                            </span>
                          </td>
                          <td className="p-3 font-mono text-[11px] text-text-muted">
                            {p.transactionId || '—'}
                          </td>
                          <td className="p-3 text-[11px] text-text-muted">
                            {new Date(p.startDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })} –{' '}
                            {new Date(p.endDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}
                          </td>
                          <td className="p-3 text-text-secondary max-w-xs truncate">
                            {p.notes || '—'}
                          </td>
                          <td className="p-3 text-center">
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-emerald-500/10 text-emerald-600 border border-emerald-500/20">
                              PAID
                            </span>
                          </td>
                          <td className="p-3 text-right">
                            <button
                              type="button"
                              onClick={() => handleDeletePayout(p.id)}
                              className="text-text-muted hover:text-rose-600 transition p-1"
                              title="Void Payout"
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── TAB 2: PRODUCTS CATALOG ── */}
      {activeTab === 'catalog' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-black text-text-primary">
              All Products Supplied by {vendorDetails?.name || 'Vendor'}
            </h3>
            <span className="text-xs text-text-muted font-bold">
              {filteredCatalog.length} products
            </span>
          </div>

          <div className="bg-card rounded-2xl border border-border overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-muted/50 border-b border-border text-[11px] font-black uppercase text-text-muted">
                  <tr>
                    <th className="p-3">Product</th>
                    <th className="p-3">Category</th>
                    <th className="p-3">Barcode</th>
                    <th className="p-3 text-right">MRP</th>
                    <th className="p-3 text-right">Selling Price</th>
                    <th className="p-3 text-right">Cost Price</th>
                    <th className="p-3 text-right">Margin %</th>
                    <th className="p-3 text-center">Stock</th>
                    <th className="p-3 text-center">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60 font-medium">
                  {filteredCatalog.length === 0 ? (
                    <tr>
                      <td colSpan={9} className="p-8 text-center text-text-muted">
                        No products currently assigned to this vendor. Assign them in Products tab or Product Edit form.
                      </td>
                    </tr>
                  ) : (
                    filteredCatalog.map((prod) => {
                      const margin = prod.price > 0 && prod.costPrice > 0
                        ? (((prod.price - prod.costPrice) / prod.price) * 100).toFixed(1)
                        : null

                      return (
                        <tr key={prod.id} className="hover:bg-muted/30 transition">
                          <td className="p-3">
                            <div className="flex items-center gap-2.5">
                              {prod.imageUrl && prod.imageUrl !== '📦' ? (
                                <img
                                  src={prod.imageUrl}
                                  alt={prod.name}
                                  className="h-8 w-8 rounded-lg object-cover border border-border"
                                />
                              ) : (
                                <div className="h-8 w-8 rounded-lg bg-muted flex items-center justify-center text-sm">
                                  📦
                                </div>
                              )}
                              <div>
                                <span className="font-bold text-text-primary block">{prod.name}</span>
                                <span className="text-[10px] text-text-muted font-mono">ID: {prod.id.slice(0, 10)}...</span>
                              </div>
                            </div>
                          </td>
                          <td className="p-3 text-text-secondary">{prod.category || 'General'}</td>
                          <td className="p-3 font-mono text-[11px] text-text-muted">
                            {prod.barcode || '—'}
                          </td>
                          <td className="p-3 text-right font-bold text-text-muted">
                            {formatPrice(prod.mrp)}
                          </td>
                          <td className="p-3 text-right font-black text-text-primary">
                            {formatPrice(prod.price)}
                          </td>
                          <td className="p-3 text-right font-bold text-blue-600">
                            {formatPrice(prod.costPrice)}
                          </td>
                          <td className="p-3 text-right">
                            {margin ? (
                              <span
                                className={`font-bold ${
                                  Number(margin) >= 15 ? 'text-emerald-600' : 'text-amber-600'
                                }`}
                              >
                                {margin}%
                              </span>
                            ) : (
                              '—'
                            )}
                          </td>
                          <td className="p-3 text-center">
                            <span
                              className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                                prod.stock <= 5
                                  ? 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                                  : 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                              }`}
                            >
                              {prod.stock} units
                            </span>
                          </td>
                          <td className="p-3 text-center">
                            <span
                              className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                                prod.isAvailable
                                  ? 'bg-emerald-500/10 text-emerald-600'
                                  : 'bg-muted text-text-muted'
                              }`}
                            >
                              {prod.isAvailable ? 'Active' : 'Disabled'}
                            </span>
                          </td>
                        </tr>
                      )
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── TAB 3: WHATSAPP REORDER PURCHASE ORDER ── */}
      {activeTab === 'reorder' && (
        <div className="space-y-4">
          <div className="bg-card p-5 rounded-2xl border border-border shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                <AlertTriangle className="h-4 w-4 text-amber-500" />
                <span>Low-Stock Items Reorder Engine</span>
              </h3>
              <p className="text-xs text-text-secondary mt-0.5">
                Automatically detects items whose current stock is below threshold. Review quantities and send directly to vendor via WhatsApp.
              </p>
            </div>

            <button
              type="button"
              onClick={handleSendWhatsAppPO}
              disabled={lowStockItems.length === 0}
              className="flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white text-xs font-black rounded-xl shadow transition cursor-pointer"
            >
              <Send className="h-4 w-4" />
              <span>Send PO to {vendorDetails?.phone || 'Vendor WhatsApp'}</span>
            </button>
          </div>

          <div className="bg-card rounded-2xl border border-border overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-muted/50 border-b border-border text-[11px] font-black uppercase text-text-muted">
                  <tr>
                    <th className="p-3">Item Name</th>
                    <th className="p-3">Barcode</th>
                    <th className="p-3 text-center">Current Stock</th>
                    <th className="p-3 text-center">Min Alert Level</th>
                    <th className="p-3 text-right">Cost Price</th>
                    <th className="p-3 text-center w-36">Order Quantity</th>
                    <th className="p-3 text-right">Est. Cost</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60 font-medium">
                  {lowStockItems.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="p-8 text-center text-text-muted">
                        <CheckCircle2 className="h-8 w-8 text-emerald-500 mx-auto mb-2 opacity-60" />
                        All products for this vendor are well stocked! No low-stock alerts.
                      </td>
                    </tr>
                  ) : (
                    lowStockItems.map((item) => {
                      const qty = orderQuantities[item.id] || 10
                      const estCost = qty * (item.costPrice || 0)

                      return (
                        <tr key={item.id} className="hover:bg-muted/30 transition">
                          <td className="p-3 font-bold text-text-primary">{item.name}</td>
                          <td className="p-3 font-mono text-[11px] text-text-muted">
                            {item.barcode || '—'}
                          </td>
                          <td className="p-3 text-center">
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-rose-500/10 text-rose-600 border border-rose-500/20">
                              {item.stock} left
                            </span>
                          </td>
                          <td className="p-3 text-center text-text-secondary">
                            {item.minStock}
                          </td>
                          <td className="p-3 text-right font-bold text-text-primary">
                            {formatPrice(item.costPrice)}
                          </td>
                          <td className="p-3 text-center">
                            <input
                              type="number"
                              min="1"
                              value={qty}
                              onChange={(e) => {
                                const val = parseInt(e.target.value) || 0
                                setOrderQuantities((prev) => ({ ...prev, [item.id]: val }))
                              }}
                              className="w-20 px-2 py-1 text-center font-black rounded-lg border border-border bg-background focus:outline-none focus:border-primary text-xs"
                            />
                          </td>
                          <td className="p-3 text-right font-black text-primary">
                            {formatPrice(estCost)}
                          </td>
                        </tr>
                      )
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ── MODAL: CREATE / EDIT VENDOR ── */}
      {showVendorModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-fade-in">
          <div className="bg-card w-full max-w-xl rounded-2xl border border-border shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div className="flex items-center justify-between p-4 border-b border-border bg-muted/30">
              <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                <Truck className="h-4 w-4 text-primary" />
                <span>{vendorModalMode === 'create' ? 'Add New Vendor' : 'Edit Vendor Profile'}</span>
              </h3>
              <button
                type="button"
                onClick={() => setShowVendorModal(false)}
                className="p-1 rounded-lg text-text-muted hover:text-text-primary hover:bg-muted transition"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <form onSubmit={handleSaveVendor} className="p-5 space-y-4 overflow-y-auto flex-1">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">Vendor Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Bansal Foods"
                    value={vendorFormData.name}
                    onChange={(e) => setVendorFormData({ ...vendorFormData, name: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-bold"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">Company / Firm Name</label>
                  <input
                    type="text"
                    placeholder="e.g. Bansal FMCG Traders Pvt Ltd"
                    value={vendorFormData.companyName}
                    onChange={(e) => setVendorFormData({ ...vendorFormData, companyName: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">Phone / WhatsApp *</label>
                  <input
                    type="tel"
                    placeholder="e.g. 9876543210"
                    value={vendorFormData.phone}
                    onChange={(e) => setVendorFormData({ ...vendorFormData, phone: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-medium"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">Email Address</label>
                  <input
                    type="email"
                    placeholder="vendor@domain.com"
                    value={vendorFormData.email}
                    onChange={(e) => setVendorFormData({ ...vendorFormData, email: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">UPI ID (For Fast Settlement)</label>
                  <input
                    type="text"
                    placeholder="e.g. vendor@okhdfcbank"
                    value={vendorFormData.upiId}
                    onChange={(e) => setVendorFormData({ ...vendorFormData, upiId: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-medium"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">GSTIN Number</label>
                  <input
                    type="text"
                    placeholder="e.g. 09ABCDE1234F1Z5"
                    value={vendorFormData.gstin}
                    onChange={(e) => setVendorFormData({ ...vendorFormData, gstin: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-mono"
                  />
                </div>
              </div>

              {/* Bank Details */}
              <div className="bg-muted/30 p-3.5 rounded-xl border border-border/80 space-y-3">
                <span className="text-[10px] font-black uppercase text-text-muted block tracking-wider">
                  Bank Account Information
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary">Bank Name</label>
                    <input
                      type="text"
                      placeholder="e.g. HDFC Bank"
                      value={vendorFormData.bankName}
                      onChange={(e) => setVendorFormData({ ...vendorFormData, bankName: e.target.value })}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-border bg-background focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary">Account Number</label>
                    <input
                      type="text"
                      placeholder="e.g. 501002345678"
                      value={vendorFormData.accountNo}
                      onChange={(e) => setVendorFormData({ ...vendorFormData, accountNo: e.target.value })}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-border bg-background focus:outline-none font-mono"
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary">IFSC Code</label>
                    <input
                      type="text"
                      placeholder="e.g. HDFC0001234"
                      value={vendorFormData.ifscCode}
                      onChange={(e) => setVendorFormData({ ...vendorFormData, ifscCode: e.target.value })}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-border bg-background focus:outline-none font-mono"
                    />
                  </div>
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-[11px] font-bold text-text-secondary">Vendor Address / Godown Location</label>
                <textarea
                  rows={2}
                  placeholder="Address or market details"
                  value={vendorFormData.address}
                  onChange={(e) => setVendorFormData({ ...vendorFormData, address: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary resize-none"
                />
              </div>

              {/* Store Hub Hierarchy Assignment */}
              <div className="space-y-1 bg-muted/20 p-3 rounded-xl border border-border/70">
                <div className="flex items-center justify-between">
                  <label className="text-[11px] font-bold text-text-primary flex items-center gap-1.5">
                    <span>🏢 Store Hub Hierarchy</span>
                  </label>
                  <span className="text-[10px] text-text-muted font-bold">DarkStore Scoping</span>
                </div>
                <select
                  value={vendorFormData.storeId || ''}
                  onChange={(e) => setVendorFormData({ ...vendorFormData, storeId: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-bold"
                >
                  <option value="">🌐 All Store Hubs (Central Supplier)</option>
                  {storesList.map((s) => (
                    <option key={s.id} value={s.id}>
                      📍 {s.name} Hub ({s.id})
                    </option>
                  ))}
                </select>
                <p className="text-[10px] text-text-secondary">
                  Specific store select karne par is vendor ka stock aur billing usi store ke sath bound rahega. Central rakhne par sabhi stores me available hoga.
                </p>
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="vendor-active-toggle"
                  checked={vendorFormData.isActive}
                  onChange={(e) => setVendorFormData({ ...vendorFormData, isActive: e.target.checked })}
                  className="rounded border-border text-primary focus:ring-primary h-4 w-4 cursor-pointer"
                />
                <label htmlFor="vendor-active-toggle" className="text-xs font-bold text-text-primary cursor-pointer">
                  Vendor is actively operational
                </label>
              </div>

              <div className="flex items-center justify-end gap-2.5 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowVendorModal(false)}
                  className="px-4 py-2 rounded-xl border border-border text-xs font-bold text-text-secondary hover:bg-muted"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingVendor}
                  className="px-4 py-2 bg-primary text-primary-foreground text-xs font-black rounded-xl hover:bg-primary/90 transition shadow flex items-center gap-1.5"
                >
                  {savingVendor && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
                  <span>{vendorModalMode === 'create' ? 'Create Vendor' : 'Save Changes'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── MODAL: RECORD PAYOUT ── */}
      {showPayoutModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-fade-in">
          <div className="bg-card w-full max-w-md rounded-2xl border border-border shadow-2xl overflow-hidden">
            <div className="flex items-center justify-between p-4 border-b border-border bg-muted/30">
              <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                <CreditCard className="h-4 w-4 text-emerald-500" />
                <span>Record Vendor Payout</span>
              </h3>
              <button
                type="button"
                onClick={() => setShowPayoutModal(false)}
                className="p-1 rounded-lg text-text-muted hover:text-text-primary hover:bg-muted transition"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <form onSubmit={handleSavePayout} className="p-5 space-y-4">
              <div className="bg-muted/40 p-3 rounded-xl border border-border/60">
                <span className="text-[10px] uppercase font-bold text-text-muted block">Paying To</span>
                <span className="text-sm font-black text-text-primary block">{vendorDetails?.name}</span>
                {vendorDetails?.upiId && (
                  <span className="text-[11px] font-bold text-primary block mt-0.5">UPI: {vendorDetails.upiId}</span>
                )}
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between">
                  <label className="text-[11px] font-bold text-text-secondary">Amount (₹) *</label>
                  {kpis.pendingBalance > 0 && (
                    <button
                      type="button"
                      onClick={() => setPayoutFormData({ ...payoutFormData, amount: String(kpis.pendingBalance) })}
                      className="text-[10px] font-black text-primary hover:underline"
                    >
                      Fill Pending ({formatPrice(kpis.pendingBalance)})
                    </button>
                  )}
                </div>
                <input
                  type="number"
                  step="0.01"
                  required
                  placeholder="e.g. 5000"
                  value={payoutFormData.amount}
                  onChange={(e) => setPayoutFormData({ ...payoutFormData, amount: e.target.value })}
                  className="w-full px-3 py-2 text-sm rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-black text-text-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">Payment Method</label>
                  <select
                    value={payoutFormData.paymentMethod}
                    onChange={(e) => setPayoutFormData({ ...payoutFormData, paymentMethod: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-bold"
                  >
                    <option value="UPI">UPI</option>
                    <option value="NEFT">NEFT / Bank Transfer</option>
                    <option value="IMPS">IMPS</option>
                    <option value="CASH">Cash</option>
                    <option value="CHEQUE">Cheque</option>
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary">UTR / Reference No.</label>
                  <input
                    type="text"
                    placeholder="e.g. 423589123456"
                    value={payoutFormData.transactionId}
                    onChange={(e) => setPayoutFormData({ ...payoutFormData, transactionId: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary font-mono"
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-[11px] font-bold text-text-secondary">Notes / Remarks</label>
                <textarea
                  rows={2}
                  placeholder="Optional notes or remarks for this payout"
                  value={payoutFormData.notes}
                  onChange={(e) => setPayoutFormData({ ...payoutFormData, notes: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-primary resize-none"
                />
              </div>

              <div className="flex items-center justify-end gap-2.5 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowPayoutModal(false)}
                  className="px-4 py-2 rounded-xl border border-border text-xs font-bold text-text-secondary hover:bg-muted"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingPayout}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-black rounded-xl transition shadow flex items-center gap-1.5 cursor-pointer"
                >
                  {savingPayout && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
                  <span>Confirm & Save Payout</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
