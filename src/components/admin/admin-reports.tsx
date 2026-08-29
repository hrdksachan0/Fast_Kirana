'use client'

import { useState, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { 
  Calendar, 
  Download, 
  TrendingUp, 
  IndianRupee, 
  ShoppingBag, 
  Percent, 
  ArrowUpRight, 
  Activity,
  Award,
  Layers,
  Loader2,
  FileText,
  Filter,
  Search,
  CheckCircle2,
  AlertTriangle,
  RefreshCw
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { formatDate } from '@/lib/date-helpers'
import * as XLSX from 'xlsx'

interface DailySale {
  date: string
  sales: number
  profit: number
  orders: number
}

interface CategorySale {
  categoryName: string
  sales: number
  cost?: number
  profit: number
  quantity?: number
  type?: 'restaurant' | 'grocery'
}

interface TopProduct {
  productId: string
  name: string
  mrp?: number
  price?: number
  costPrice?: number
  quantity: number
  sales: number
  profit: number
  categoryName?: string
  type?: 'restaurant' | 'grocery'
}

interface ChannelMetrics {
  ordersCount: number
  sales: number
  profit: number
}

interface ReportSummary {
  totalSales: number
  totalCollected?: number
  totalProfit: number
  totalCost: number
  totalOrders: number
  averageOrderValue: number
  profitMargin: number
  totalMiscFee?: number
  totalTaxes?: number
  totalDeliveryFee?: number
  productSales?: number
  missingCostCount?: number
  delivery?: ChannelMetrics
  pickup?: ChannelMetrics
  retail?: ChannelMetrics
}

// Category Icon & Color Mapping for Premium Polish
const getCategoryMeta = (catName: string) => {
  const name = catName.toLowerCase()
  if (name.includes('restaurant') || name.includes('wedson') || name.includes('meal') || name.includes('thali') || name.includes('biryani')) {
    return { icon: '🍽️', badge: 'bg-rose-500/10 text-rose-600 border-rose-500/20 dark:text-rose-400' }
  }
  if (name.includes('cafe') || name.includes('burger') || name.includes('sandwich') || name.includes('pasta') || name.includes('pizza') || name.includes('wrap')) {
    return { icon: '☕', badge: 'bg-amber-500/10 text-amber-600 border-amber-500/20 dark:text-amber-400' }
  }
  if (name.includes('dairy') || name.includes('milk') || name.includes('paneer') || name.includes('curd') || name.includes('butter') || name.includes('cheese')) {
    return { icon: '🥛', badge: 'bg-blue-500/10 text-blue-600 border-blue-500/20 dark:text-blue-400' }
  }
  if (name.includes('snack') || name.includes('munch') || name.includes('chips') || name.includes('namkeen') || name.includes('biscuit') || name.includes('cookie')) {
    return { icon: '🍿', badge: 'bg-orange-500/10 text-orange-600 border-orange-500/20 dark:text-orange-400' }
  }
  if (name.includes('atta') || name.includes('rice') || name.includes('dal') || name.includes('oil') || name.includes('ghee') || name.includes('flour') || name.includes('kitchen')) {
    return { icon: '🍚', badge: 'bg-yellow-500/10 text-yellow-700 border-yellow-500/20 dark:text-yellow-400' }
  }
  if (name.includes('beverage') || name.includes('drink') || name.includes('juice') || name.includes('cold drink') || name.includes('water') || name.includes('soda')) {
    return { icon: '🥤', badge: 'bg-cyan-500/10 text-cyan-600 border-cyan-500/20 dark:text-cyan-400' }
  }
  if (name.includes('ice cream') || name.includes('dessert') || name.includes('sweet') || name.includes('kulfi') || name.includes('cone')) {
    return { icon: '🍦', badge: 'bg-pink-500/10 text-pink-600 border-pink-500/20 dark:text-pink-400' }
  }
  if (name.includes('bakery') || name.includes('cake') || name.includes('bread') || name.includes('pastry') || name.includes('rusk')) {
    return { icon: '🥖', badge: 'bg-amber-600/10 text-amber-700 border-amber-600/20 dark:text-amber-300' }
  }
  if (name.includes('personal') || name.includes('care') || name.includes('soap') || name.includes('shampoo') || name.includes('paste') || name.includes('beauty')) {
    return { icon: '🧴', badge: 'bg-fuchsia-500/10 text-fuchsia-600 border-fuchsia-500/20 dark:text-fuchsia-400' }
  }
  if (name.includes('house') || name.includes('clean') || name.includes('detergent') || name.includes('home')) {
    return { icon: '🧹', badge: 'bg-teal-500/10 text-teal-600 border-teal-500/20 dark:text-teal-400' }
  }
  if (name.includes('fruit') || name.includes('veg') || name.includes('sabzi')) {
    return { icon: '🥬', badge: 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20 dark:text-emerald-400' }
  }
  return { icon: '📦', badge: 'bg-zinc-500/10 text-zinc-600 border-zinc-500/20 dark:text-zinc-400' }
}

export function AdminReports() {
  const [rangePreset, setRangePreset] = useState<'today' | 'yesterday' | '7days' | '30days' | 'custom'>('30days')
  const [startDate, setStartDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() - 30)
    return d.toISOString().split('T')[0]
  })
  const [endDate, setEndDate] = useState(() => {
    return new Date().toISOString().split('T')[0]
  })
  const [loading, setLoading] = useState(true)
  
  // Active Category Filter: 'all' or specific category name (e.g., 'Dairy & Breakfast', 'Wedson Restaurant')
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [productSearch, setProductSearch] = useState('')
  
  // Loaded report data from server
  const [rawSummary, setRawSummary] = useState<ReportSummary>({
    totalSales: 0,
    totalProfit: 0,
    totalCost: 0,
    totalOrders: 0,
    averageOrderValue: 0,
    profitMargin: 0,
    totalMiscFee: 0,
    totalTaxes: 0,
    totalDeliveryFee: 0,
    productSales: 0,
    missingCostCount: 0
  })
  const [rawDailySales, setRawDailySales] = useState<DailySale[]>([])
  const [rawCategorySales, setRawCategorySales] = useState<CategorySale[]>([])
  const [rawTopProducts, setRawTopProducts] = useState<TopProduct[]>([])
  const [missingCostProducts, setMissingCostProducts] = useState<any[]>([])

  // Handle Preset selection
  const handlePresetChange = (preset: typeof rangePreset) => {
    setRangePreset(preset)
    const now = new Date()
    let start = new Date()
    let end = new Date()

    if (preset === 'today') {
      start = now
    } else if (preset === 'yesterday') {
      start.setDate(now.getDate() - 1)
      end.setDate(now.getDate() - 1)
    } else if (preset === '7days') {
      start.setDate(now.getDate() - 7)
    } else if (preset === '30days') {
      start.setDate(now.getDate() - 30)
    }

    setStartDate(start.toISOString().split('T')[0])
    setEndDate(end.toISOString().split('T')[0])
  }

  // Fetch report from server API
  const fetchReport = async () => {
    try {
      setLoading(true)
      const url = `/api/admin/reports?startDate=${startDate}&endDate=${endDate}&t=${Date.now()}`
      const res = await fetch(url)
      if (!res.ok) throw new Error('Failed to fetch report data')
      
      const data = await res.json()
      setRawSummary(data.summary)
      setRawDailySales(data.dailySales || [])
      setRawCategorySales(data.categorySales || [])
      setRawTopProducts(data.topProducts || [])
      setMissingCostProducts(data.missingCostProducts || [])
    } catch (err) {
      console.error(err)
      toast.error('Could not generate sales reports')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (startDate && endDate) {
      fetchReport()
    }
  }, [startDate, endDate])

  // Filtered Products based on Selected Category & Search Query
  const filteredProducts = useMemo(() => {
    let list = rawTopProducts
    if (selectedCategory !== 'all') {
      list = list.filter(p => p.categoryName?.toLowerCase() === selectedCategory.toLowerCase())
    }
    if (productSearch.trim()) {
      const q = productSearch.toLowerCase().trim()
      list = list.filter(p => 
        p.name.toLowerCase().includes(q) || 
        (p.categoryName && p.categoryName.toLowerCase().includes(q))
      )
    }
    return list
  }, [rawTopProducts, selectedCategory, productSearch])

  // Filtered Summary based on Selected Category
  const summary = useMemo(() => {
    if (selectedCategory === 'all') return rawSummary

    const targetCat = rawCategorySales.find(c => c.categoryName.toLowerCase() === selectedCategory.toLowerCase())
    const catSales = targetCat?.sales || 0
    const catProfit = targetCat?.profit || 0
    const catCost = targetCat?.cost ?? (catSales - catProfit)
    const margin = catSales > 0 ? (catProfit / catSales) * 100 : 0

    return {
      ...rawSummary,
      totalSales: Math.round(catSales * 100) / 100,
      totalProfit: Math.round(catProfit * 100) / 100,
      totalCost: Math.round(catCost * 100) / 100,
      profitMargin: Math.round(margin * 10) / 10,
      productSales: Math.round(catSales * 100) / 100
    }
  }, [rawSummary, rawCategorySales, selectedCategory])

  // Split calculations for Main Shop (Grocery) vs Food/Restaurant
  const grocerySales = useMemo(() => {
    return rawCategorySales.filter(c => c.type === 'grocery').reduce((acc, c) => acc + (c.sales || 0), 0)
  }, [rawCategorySales])

  const groceryProfit = useMemo(() => {
    return rawCategorySales.filter(c => c.type === 'grocery').reduce((acc, c) => acc + (c.profit || 0), 0)
  }, [rawCategorySales])

  const restaurantSales = useMemo(() => {
    return rawCategorySales.filter(c => c.type === 'restaurant').reduce((acc, c) => acc + (c.sales || 0), 0)
  }, [rawCategorySales])

  const restaurantProfit = useMemo(() => {
    return rawCategorySales.filter(c => c.type === 'restaurant').reduce((acc, c) => acc + (c.profit || 0), 0)
  }, [rawCategorySales])

  // Custom SVG Line Graph calculations
  const svgChartPath = useMemo(() => {
    if (rawDailySales.length < 2) return { salesPath: '', profitPath: '', salesArea: '', profitArea: '', points: [], maxValue: 100 }
    
    const width = 800
    const height = 240
    const padding = 35
    const chartWidth = width - padding * 2
    const chartHeight = height - padding * 2

    const maxSalesVal = Math.max(...rawDailySales.map(d => d.sales), 100)
    const maxProfitVal = Math.max(...rawDailySales.map(d => d.profit), 100)
    const maxValue = Math.max(maxSalesVal, maxProfitVal) * 1.15 // Add 15% headroom

    const points = rawDailySales.map((d, index) => {
      const x = padding + (index / (rawDailySales.length - 1)) * chartWidth
      const ySales = padding + chartHeight - (d.sales / maxValue) * chartHeight
      const yProfit = padding + chartHeight - (d.profit / maxValue) * chartHeight
      return { x, ySales, yProfit, label: d.date, sales: d.sales, profit: d.profit }
    })

    const salesPath = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.ySales}`).join(' ')
    const profitPath = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.yProfit}`).join(' ')

    const salesArea = `${salesPath} L ${points[points.length - 1].x} ${height - padding} L ${points[0].x} ${height - padding} Z`
    const profitArea = `${profitPath} L ${points[points.length - 1].x} ${height - padding} L ${points[0].x} ${height - padding} Z`

    return { salesPath, profitPath, salesArea, profitArea, points, maxValue }
  }, [rawDailySales])

  // Real Excel (.xlsx) Exporter with SheetJS
  const handleDownloadXLSX = (scope: 'all' | 'grocery' | 'restaurant' = 'all') => {
    try {
      const scopeLabel = scope === 'grocery' ? 'Grocery' : scope === 'restaurant' ? 'Restaurant' : 'Overall'
      
      // Filter categories and products based on scope
      const targetCategories = rawCategorySales.filter(cat => {
        if (scope === 'grocery') return cat.type === 'grocery'
        if (scope === 'restaurant') return cat.type === 'restaurant'
        return true
      })

      const targetProducts = (rawTopProducts || []).filter((prod: TopProduct) => {
        if (selectedCategory !== 'all' && prod.categoryName !== selectedCategory) return false
        if (scope === 'grocery') return prod.type === 'grocery'
        if (scope === 'restaurant') return prod.type === 'restaurant'
        return true
      })

      const scopeSales = targetCategories.reduce((sum, c) => sum + (c.sales || 0), 0)
      const scopeCost = targetCategories.reduce((sum, c) => sum + (c.cost ?? (c.sales - c.profit)), 0)
      const scopeProfit = targetCategories.reduce((sum, c) => sum + (c.profit || 0), 0)
      const scopeMargin = scopeSales > 0 ? (scopeProfit / scopeSales) * 100 : 0

      // 1. Tab 1: Financial Summary Sheet
      const summaryRows = [
        ['FastKirana Financial Report', ''],
        ['Report Type', `${scopeLabel} Financials`],
        ['Date Range', `${startDate} to ${endDate}`],
        ['Generated On', new Date().toLocaleString()],
        ['', ''],
        ['Metric', 'Amount (INR)'],
        ['Total Net Sales (Revenue)', scopeSales],
        ['Product Cost / Restaurant Payouts (COGS)', scopeCost],
        ['Store Net Profit (Earnings)', scopeProfit],
        ['Profit Margin', `${scopeMargin.toFixed(1)}%`],
      ]

      if (scope === 'all') {
        summaryRows.push(
          ['Total Orders Delivered', summary.totalOrders],
          ['Average Order Value', summary.averageOrderValue],
          ['Delivery Fees Collected', summary.totalDeliveryFee || 0],
          ['Packaging & Handling Fees', summary.totalMiscFee || 0],
          ['GST / Taxes Collected', summary.totalTaxes || 0]
        )
      }

      const wsSummary = XLSX.utils.aoa_to_sheet(summaryRows)

      // 2. Tab 2: Category Breakdown Sheet
      const catHeader = scope === 'restaurant' 
        ? ['Restaurant Name', 'Type', 'Units Sold', 'Total Sales (INR)', 'Restaurant Payout Share (INR)', 'FastKirana Commission (INR)', 'Margin']
        : ['Category Name', 'Type', 'Units Sold', 'Total Sales (INR)', 'Product Cost (INR)', 'Net Profit (INR)', 'Margin']
      
      const catRows = targetCategories.map(cat => {
        const catCost = cat.cost ?? (cat.sales - cat.profit)
        const margin = cat.sales > 0 ? ((cat.profit / cat.sales) * 100) : 0
        return [
          cat.categoryName,
          cat.type || 'grocery',
          cat.quantity || 0,
          cat.sales,
          catCost,
          cat.profit,
          `${margin.toFixed(1)}%`
        ]
      })

      const wsCategory = XLSX.utils.aoa_to_sheet([catHeader, ...catRows])

      // 3. Tab 3: Product Sales Sheet
      const prodHeader = ['Product / Dish Name', 'Category / Outlet', 'Selling Price (INR)', 'Cost / Payout (INR)', 'Qty Sold', 'Total Sales (INR)', 'Net Profit (INR)', 'Margin']
      const prodRows = targetProducts.map((prod: TopProduct) => {
        const margin = prod.sales > 0 ? ((prod.profit / prod.sales) * 100) : 0
        return [
          prod.name,
          prod.categoryName || '-',
          prod.price || 0,
          prod.costPrice || 0,
          prod.quantity,
          prod.sales,
          prod.profit,
          `${margin.toFixed(1)}%`
        ]
      })

      const wsProduct = XLSX.utils.aoa_to_sheet([prodHeader, ...prodRows])

      // Create Workbook and Append Sheets
      const wb = XLSX.utils.book_new()
      XLSX.utils.book_append_sheet(wb, wsSummary, 'Summary')
      XLSX.utils.book_append_sheet(wb, wsCategory, 'Categories')
      XLSX.utils.book_append_sheet(wb, wsProduct, 'Products')

      // Save Workbook
      XLSX.writeFile(wb, `FastKirana_${scopeLabel}_Report_${startDate}_to_${endDate}.xlsx`)
      toast.success(`${scopeLabel} Excel report exported successfully!`)
    } catch (e) {
      console.error('Error exporting Excel report:', e)
      toast.error('Failed to export Excel report')
    }
  }

  // ORDER-WISE Excel Exporter: Each row = 1 order with ReadableID, Customer, Payment, Items, Restaurant
  const [orderExportLoading, setOrderExportLoading] = useState(false)
  const handleDownloadOrderWiseXLSX = async (scope: 'all' | 'restaurant' = 'all') => {
    try {
      setOrderExportLoading(true)
      toast.loading('Fetching order-wise data...', { id: 'order-excel' })

      const res = await fetch(`/api/admin/reports/orders?startDate=${startDate}&endDate=${endDate}&t=${Date.now()}`)
      if (!res.ok) throw new Error('Failed to fetch order data')
      const data = await res.json()
      const orders = data.orders || []

      if (orders.length === 0) {
        toast.error('No delivered orders found in this date range', { id: 'order-excel' })
        return
      }

      const formatDateTime = (d: string | null) => {
        if (!d) return '-'
        const dt = new Date(d)
        return dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) + 
               ' ' + dt.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true })
      }

      const scopeLabel = scope === 'restaurant' ? 'Restaurant_OrderWise' : 'All_OrderWise'

      // Filter orders based on scope
      const targetOrders = scope === 'restaurant' 
        ? orders.filter((o: any) => o.orderType === 'RESTAURANT' || o._restaurantNames?.length > 0)
        : orders

      // ── Sheet 1: All Orders (Order-Wise)
      const header = [
        'Order #', 'Customer Name', 'Phone', 'Order Date', 'Delivered At',
        'Type', 'Delivery / Self-Pick', 'Delivered By (Rider/Admin)', 'Payment Method', 'Payment Status',
        'Restaurant / Shop', 'Items', 'Item Count',
        'Subtotal (₹)', 'Discount (₹)', 'Delivery Fee (₹)', 'Taxes (₹)', 'Handling Fee (₹)', 'Total (₹)',
        'Cost (₹)', 'Profit (₹)', 'Coupon', 'Notes'
      ]

      const rows = targetOrders.map((o: any) => [
        `#${o.readableId}`,
        o.customerName,
        o.customerPhone,
        formatDateTime(o.orderDate),
        formatDateTime(o.deliveredAt),
        o.orderType,
        o.fulfillmentType || o.deliveryMethod || 'Doorstep Delivery',
        o.deliveredBy || (o.deliveredByName ? `Rider: ${o.deliveredByName}` : 'Admin / Direct'),
        o.paymentMethod,
        o.paymentStatus,
        o.restaurantName || o.shopName || '-',
        o.items,
        o.itemCount,
        o.subtotal,
        o.discount,
        o.deliveryFee,
        o.taxes,
        o.miscFee,
        o.total,
        o.totalCost,
        o.profit,
        o.couponCode,
        o.notes,
      ])

      // Totals row
      const totalRow = [
        'TOTAL', '', '', '', '', '', '', '', '', '',
        `${targetOrders.length} Orders`,
        targetOrders.reduce((s: number, o: any) => s + o.itemCount, 0),
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.subtotal, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.discount, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.deliveryFee, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.taxes, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.miscFee, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.totalCost, 0) * 100) / 100,
        Math.round(targetOrders.reduce((s: number, o: any) => s + o.profit, 0) * 100) / 100,
        '', ''
      ]

      const wsAll = XLSX.utils.aoa_to_sheet([header, ...rows, [], totalRow])

      // Set column widths for readability
      wsAll['!cols'] = [
        { wch: 10 }, { wch: 18 }, { wch: 14 }, { wch: 20 }, { wch: 20 },
        { wch: 12 }, { wch: 18 }, { wch: 22 }, { wch: 14 }, { wch: 12 },
        { wch: 22 }, { wch: 45 }, { wch: 8 },
        { wch: 10 }, { wch: 10 }, { wch: 12 }, { wch: 10 }, { wch: 12 }, { wch: 10 },
        { wch: 10 }, { wch: 10 }, { wch: 12 }, { wch: 20 },
      ]

      const wb = XLSX.utils.book_new()
      XLSX.utils.book_append_sheet(wb, wsAll, scope === 'restaurant' ? 'Restaurant Orders' : 'All Orders')

      // ── Sheet 2: Payment Summary
      const codOrders = targetOrders.filter((o: any) => o.paymentMethod === 'COD')
      const onlineOrders = targetOrders.filter((o: any) => o.paymentMethod !== 'COD')
      const paidOrders = targetOrders.filter((o: any) => o.paymentStatus === 'PAID')
      const pendingPayOrders = targetOrders.filter((o: any) => o.paymentStatus === 'PENDING')

      const paymentSummary = [
        ['📊 Payment Summary', ''],
        ['Date Range', `${startDate} to ${endDate}`],
        ['', ''],
        ['Payment Method', 'Orders', 'Total Amount (₹)'],
        ['COD (Cash on Delivery)', codOrders.length, Math.round(codOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100],
        ['Online (UPI/Card/Net Banking)', onlineOrders.length, Math.round(onlineOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100],
        ['', '', ''],
        ['Payment Status', 'Orders', 'Total Amount (₹)'],
        ['PAID', paidOrders.length, Math.round(paidOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100],
        ['PENDING', pendingPayOrders.length, Math.round(pendingPayOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100],
        ['', '', ''],
        ['Grand Total', targetOrders.length, Math.round(targetOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100],
      ]
      const wsPayment = XLSX.utils.aoa_to_sheet(paymentSummary)
      wsPayment['!cols'] = [{ wch: 30 }, { wch: 10 }, { wch: 18 }]
      XLSX.utils.book_append_sheet(wb, wsPayment, 'Payment Summary')

      // ── Sheet 3+: Per-Restaurant Sheets (only if scope is 'all' or 'restaurant')
      const restaurantGroups: Record<string, any[]> = {}
      for (const o of targetOrders) {
        const rName = (o as any).restaurantName && (o as any).restaurantName !== '-' 
          ? (o as any).restaurantName 
          : (o as any).orderType === 'RESTAURANT' ? ((o as any).shopName || 'Unknown Restaurant') : null
        if (rName) {
          if (!restaurantGroups[rName]) restaurantGroups[rName] = []
          restaurantGroups[rName].push(o)
        }
      }

      for (const [rName, rOrders] of Object.entries(restaurantGroups)) {
        const rHeader = [
          'Order #', 'Customer Name', 'Phone', 'Order Date',
          'Delivery Mode', 'Delivered By', 'Payment Method', 'Payment Status', 'Items', 'Item Count',
          'Total (₹)', 'Cost (₹)', 'Profit (₹)'
        ]
        const rRows = rOrders.map((o: any) => [
          `#${o.readableId}`,
          o.customerName,
          o.customerPhone,
          formatDateTime(o.orderDate),
          o.fulfillmentType || o.deliveryMethod || 'Doorstep Delivery',
          o.deliveredBy || (o.deliveredByName ? `Rider: ${o.deliveredByName}` : 'Admin / Direct'),
          o.paymentMethod,
          o.paymentStatus,
          o.items,
          o.itemCount,
          o.total,
          o.totalCost,
          o.profit,
        ])
        const rTotal = [
          'TOTAL', '', '', '', '', '', '',
          `${rOrders.length} Orders`,
          rOrders.reduce((s: number, o: any) => s + o.itemCount, 0),
          Math.round(rOrders.reduce((s: number, o: any) => s + o.total, 0) * 100) / 100,
          Math.round(rOrders.reduce((s: number, o: any) => s + o.totalCost, 0) * 100) / 100,
          Math.round(rOrders.reduce((s: number, o: any) => s + o.profit, 0) * 100) / 100,
        ]
        const wsR = XLSX.utils.aoa_to_sheet([rHeader, ...rRows, [], rTotal])
        wsR['!cols'] = [
          { wch: 10 }, { wch: 18 }, { wch: 14 }, { wch: 20 },
          { wch: 16 }, { wch: 22 }, { wch: 14 }, { wch: 12 }, { wch: 40 }, { wch: 8 },
          { wch: 10 }, { wch: 10 }, { wch: 10 },
        ]
        // Sheet name max 31 chars
        const sheetName = rName.length > 28 ? rName.slice(0, 28) + '...' : rName
        XLSX.utils.book_append_sheet(wb, wsR, sheetName)
      }

      XLSX.writeFile(wb, `FastKirana_${scopeLabel}_${startDate}_to_${endDate}.xlsx`)
      toast.success(`Order-wise Excel exported! (${targetOrders.length} orders)`, { id: 'order-excel' })
    } catch (e) {
      console.error('Error exporting order-wise Excel:', e)
      toast.error('Failed to export order-wise Excel', { id: 'order-excel' })
    } finally {
      setOrderExportLoading(false)
    }
  }

  // Excel / CSV Exporter with UTF-8 BOM
  // Excel / CSV Exporter with UTF-8 BOM
  const handleDownloadCSV = (scope: 'all' | 'grocery' | 'restaurant' = 'all') => {
    try {
      let csv = '\uFEFF' // UTF-8 Byte Order Mark for Excel
      const scopeLabel = scope === 'grocery' ? 'GROCERY WISE' : scope === 'restaurant' ? 'RESTAURANTS WISE' : 'ALL FINANCIAL'
      csv += `FASTKIRANA ${scopeLabel} REPORT\n`
      csv += `Date Range,"${startDate} to ${endDate}"\n`
      csv += `Report Type,"${scopeLabel}"\n`
      csv += `Filtered Category,"${selectedCategory === 'all' ? 'All Categories (Full Store)' : selectedCategory}"\n`
      csv += `Generated On,"${new Date().toLocaleString()}"\n\n`

      // Filter categories and products based on scope
      const targetCategories = rawCategorySales.filter(cat => {
        if (scope === 'grocery') return cat.type === 'grocery'
        if (scope === 'restaurant') return cat.type === 'restaurant'
        return true
      })

      const targetProducts = (rawTopProducts || []).filter((prod: TopProduct) => {
        if (selectedCategory !== 'all' && prod.categoryName !== selectedCategory) return false
        if (scope === 'grocery') return prod.type === 'grocery'
        if (scope === 'restaurant') return prod.type === 'restaurant'
        return true
      })

      const scopeSales = targetCategories.reduce((sum, c) => sum + (c.sales || 0), 0)
      const scopeCost = targetCategories.reduce((sum, c) => sum + (c.cost ?? (c.sales - c.profit)), 0)
      const scopeProfit = targetCategories.reduce((sum, c) => sum + (c.profit || 0), 0)
      const scopeMargin = scopeSales > 0 ? ((scopeProfit / scopeSales) * 100).toFixed(1) : '0'

      // 1. Financial Summary
      csv += `--- ${scopeLabel} SUMMARY ---\n`
      csv += 'Metric,Amount (INR)\n'
      csv += `Total Net Sales (Revenue),₹${scopeSales.toFixed(2)}\n`
      csv += `Product Cost / Restaurant Payouts (COGS),₹${scopeCost.toFixed(2)}\n`
      csv += `Store Net Profit (Earnings),₹${scopeProfit.toFixed(2)}\n`
      csv += `Profit Margin,${scopeMargin}%\n`
      if (scope === 'all') {
        csv += `Total Orders Delivered,${summary.totalOrders}\n`
        csv += `Average Order Value,₹${summary.averageOrderValue.toFixed(2)}\n`
        csv += `Delivery Fees Collected,₹${(summary.totalDeliveryFee || 0).toFixed(2)}\n`
        csv += `Packaging & Handling Fees,₹${(summary.totalMiscFee || 0).toFixed(2)}\n`
        csv += `GST / Taxes Collected,₹${(summary.totalTaxes || 0).toFixed(2)}\n`
      }
      csv += '\n'

      // 2. Category-Wise Financial Breakdown
      csv += `--- ${scope === 'restaurant' ? 'OUTLET-WISE RESTAURANTS BREAKDOWN' : 'CATEGORY-WISE FINANCIAL BREAKDOWN'} ---\n`
      csv += `${scope === 'restaurant' ? 'Restaurant Name' : 'Category Name'},Type,Units Sold,Total Sales (INR),${scope === 'restaurant' ? 'Restaurant Payout Share (INR)' : 'Product Cost (INR)'},${scope === 'restaurant' ? 'FastKirana Commission (INR)' : 'Net Profit (INR)'},Margin (%)\n`
      targetCategories.forEach(cat => {
        const catCost = cat.cost ?? (cat.sales - cat.profit)
        const margin = cat.sales > 0 ? ((cat.profit / cat.sales) * 100).toFixed(1) : '0'
        csv += `"${cat.categoryName}","${cat.type || 'grocery'}",${cat.quantity || '-'},₹${cat.sales.toFixed(2)},₹${catCost.toFixed(2)},₹${cat.profit.toFixed(2)},${margin}%\n`
      })
      csv += '\n'

      // 3. Itemized Product Performance
      csv += `--- ITEMIZED ${scopeLabel} SALES PERFORMANCE ---\n`
      csv += 'Product / Dish Name,Category / Outlet,Selling Price (INR),Cost / Payout (INR),Qty Sold,Total Sales (INR),Net Profit (INR),Margin (%)\n'
      targetProducts.forEach((prod: TopProduct) => {
        const margin = prod.sales > 0 ? ((prod.profit / prod.sales) * 100).toFixed(1) : '0'
        csv += `"${prod.name}","${prod.categoryName || '-'}",₹${(prod.price || 0).toFixed(2)},₹${(prod.costPrice || 0).toFixed(2)},${prod.quantity},₹${prod.sales.toFixed(2)},₹${prod.profit.toFixed(2)},${margin}%\n`
      })

      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `FastKirana_${scopeLabel.replace(/\s+/g, '_')}_${startDate}_to_${endDate}.csv`)
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)

      toast.success(`${scopeLabel} report exported successfully!`)
    } catch (err) {
      console.error(err)
      toast.error('Could not export report')
    }
  }

  return (
    <div className="space-y-6">
      
      {/* Top Header & Date Presets */}
      <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs flex flex-col xl:flex-row xl:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <div className="h-9 w-9 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold">
              <IndianRupee className="h-5 w-5" />
            </div>
            <div>
              <h3 className="text-base md:text-lg font-black text-text-primary">
                Store Financial &amp; Category Reports
              </h3>
              <p className="text-xs text-text-secondary mt-0.5 font-medium">
                Category-wise revenue, product cost (COGS), net profit, and profit margins.
              </p>
            </div>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {/* Quick Date Presets */}
          <div className="flex bg-muted/60 p-1 rounded-2xl border border-border/80 text-xs font-bold">
            {(['today', 'yesterday', '7days', '30days', 'custom'] as const).map((r) => (
              <button
                key={r}
                onClick={() => handlePresetChange(r)}
                className={`px-3 py-1.5 rounded-xl capitalize transition-all duration-200 cursor-pointer ${
                  rangePreset === r ? 'bg-card text-primary font-black shadow-xs' : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                {r === 'today' ? 'Today' : r === 'yesterday' ? 'Yesterday' : r === '7days' ? '7 Days' : r === '30days' ? '30 Days' : 'Custom'}
              </button>
            ))}
          </div>

          {/* Custom Date Pickers */}
          {rangePreset === 'custom' && (
            <div className="flex items-center gap-1.5 text-xs bg-muted/60 p-1 rounded-2xl border border-border">
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="bg-card border border-border/60 px-2.5 py-1 rounded-xl text-text-primary focus:outline-none font-bold text-xs"
              />
              <span className="text-text-muted text-[11px] font-bold">to</span>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="bg-card border border-border/60 px-2.5 py-1 rounded-xl text-text-primary focus:outline-none font-bold text-xs"
              />
            </div>
          )}

          {/* Export Buttons Group (All / Grocery Wise / Restaurant Wise) */}
          <div className="flex items-center gap-1.5 bg-muted/50 p-1 rounded-2xl border border-border/80">
            <button
              onClick={() => handleDownloadXLSX('all')}
              disabled={loading}
              className="h-8 px-3 rounded-xl text-xs font-black bg-emerald-600 hover:bg-emerald-700 text-white transition-all shadow-xs flex items-center gap-1.5 disabled:opacity-50 cursor-pointer active:scale-95"
              title="Download Full Store Comprehensive Financial Report"
            >
              <Download className="h-3 w-3" />
              <span>All Excel</span>
            </button>

            <button
              onClick={() => handleDownloadXLSX('grocery')}
              disabled={loading}
              className="h-8 px-2.5 rounded-xl text-xs font-black bg-teal-500/10 hover:bg-teal-500/20 text-teal-700 dark:text-teal-300 border border-teal-500/30 transition-all flex items-center gap-1.5 disabled:opacity-50 cursor-pointer active:scale-95"
              title="Download Grocery-Only Category & Product Excel Sheet"
            >
              <span>🛒</span>
              <span>Grocery Wise</span>
            </button>

            <button
              onClick={() => handleDownloadXLSX('restaurant')}
              disabled={loading}
              className="h-8 px-2.5 rounded-xl text-xs font-black bg-orange-500/10 hover:bg-orange-500/20 text-orange-700 dark:text-orange-300 border border-orange-500/30 transition-all flex items-center gap-1.5 disabled:opacity-50 cursor-pointer active:scale-95"
              title="Download Restaurant-Only Outlet & Dishes Excel Sheet"
            >
              <span>🍽️</span>
              <span>Restaurants Wise</span>
            </button>

            {/* Secondary CSV Download option */}
            <button
              onClick={() => handleDownloadCSV('all')}
              disabled={loading}
              className="h-8 w-8 rounded-xl text-[9px] font-black bg-muted hover:bg-muted/85 border border-border flex items-center justify-center transition-all disabled:opacity-50 cursor-pointer active:scale-95 text-text-secondary"
              title="Download raw CSV format instead"
            >
              CSV
            </button>
          </div>

          {/* Order-Wise Excel Export Buttons */}
          <div className="flex items-center gap-1.5 bg-violet-500/5 p-1 rounded-2xl border border-violet-500/20">
            <button
              onClick={() => handleDownloadOrderWiseXLSX('all')}
              disabled={loading || orderExportLoading}
              className="h-8 px-3 rounded-xl text-xs font-black bg-violet-600 hover:bg-violet-700 text-white transition-all shadow-xs flex items-center gap-1.5 disabled:opacity-50 cursor-pointer active:scale-95"
              title="Download Order-Wise Excel with Payment Details & Readable ID"
            >
              {orderExportLoading ? <Loader2 className="h-3 w-3 animate-spin" /> : <FileText className="h-3 w-3" />}
              <span>📋 Order Wise</span>
            </button>
            <button
              onClick={() => handleDownloadOrderWiseXLSX('restaurant')}
              disabled={loading || orderExportLoading}
              className="h-8 px-2.5 rounded-xl text-xs font-black bg-orange-500/10 hover:bg-orange-500/20 text-orange-700 dark:text-orange-300 border border-orange-500/30 transition-all flex items-center gap-1.5 disabled:opacity-50 cursor-pointer active:scale-95"
              title="Download Restaurant Order-Wise Excel with per-Restaurant Sheets"
            >
              <span>🍽️</span>
              <span>Restaurant Orders</span>
            </button>
          </div>
        </div>
      </div>

      {/* Category Filter Pills Row */}
      <div className="space-y-2">
        <div className="flex items-center justify-between px-1">
          <span className="text-[11px] font-black text-text-secondary uppercase tracking-wider flex items-center gap-1.5">
            <Filter className="h-3.5 w-3.5 text-primary" /> Filter Financials by Category
          </span>
          {selectedCategory !== 'all' && (
            <button
              onClick={() => setSelectedCategory('all')}
              className="text-[11px] font-bold text-primary hover:underline cursor-pointer"
            >
              Reset to All Categories
            </button>
          )}
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none select-none">
          <button
            onClick={() => setSelectedCategory('all')}
            className={`px-4 py-2 rounded-2xl text-xs font-black whitespace-nowrap transition-all border cursor-pointer ${
              selectedCategory === 'all'
                ? 'bg-primary text-white border-primary shadow-sm scale-102'
                : 'bg-card text-text-secondary border-border hover:bg-muted/50 hover:text-text-primary'
            }`}
          >
            🏪 All Categories ({rawCategorySales.length})
          </button>

          {rawCategorySales.map((cat) => {
            const meta = getCategoryMeta(cat.categoryName)
            const isSelected = selectedCategory.toLowerCase() === cat.categoryName.toLowerCase()
            return (
              <button
                key={cat.categoryName}
                onClick={() => setSelectedCategory(cat.categoryName)}
                className={`px-3.5 py-2 rounded-2xl text-xs font-bold whitespace-nowrap transition-all border flex items-center gap-1.5 cursor-pointer ${
                  isSelected
                    ? 'bg-zinc-900 text-white border-zinc-900 dark:bg-white dark:text-zinc-950 dark:border-white shadow-sm scale-102 font-black'
                    : 'bg-card text-text-secondary border-border hover:bg-muted/50 hover:text-text-primary'
                }`}
              >
                <span>{meta.icon}</span>
                <span>{cat.categoryName}</span>
                <span className="text-[10px] opacity-75 font-mono">({formatPrice(cat.sales)})</span>
              </button>
            )
          })}
        </div>
      </div>

      {loading ? (
        <div className="py-24 flex flex-col items-center justify-center text-text-secondary">
          <Loader2 className="h-8 w-8 animate-spin text-primary mb-2" />
          <span className="text-xs font-bold">Calculating category-wise financial records...</span>
        </div>
      ) : (
        <>
          {/* Key Financial Metric Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5">
            
            {/* 1. Total Net Sales */}
            <div className="bg-card border border-border p-5 rounded-3xl shadow-xs">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-black text-text-secondary uppercase tracking-wider block">
                  {selectedCategory === 'all' ? 'Total Revenue (Sales)' : `${selectedCategory} Sales`}
                </span>
                <IndianRupee className="h-4 w-4 text-primary" />
              </div>
              <h4 className="text-xl md:text-2xl font-black text-text-primary mt-2">
                {formatPrice(summary.totalSales)}
              </h4>
              <p className="text-[10px] text-text-muted mt-1 font-medium">
                {selectedCategory === 'all' ? 'Gross product revenue collected' : `Net revenue for ${selectedCategory}`}
              </p>
            </div>

            {/* 2. Cost of Goods (COGS / Payouts) */}
            <div className="bg-card border border-border p-5 rounded-3xl shadow-xs">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-black text-text-secondary uppercase tracking-wider block">
                  Product Cost (COGS)
                </span>
                <Activity className="h-4 w-4 text-blue-500" />
              </div>
              <h4 className="text-xl md:text-2xl font-black text-blue-600 dark:text-blue-400 mt-2">
                {formatPrice(summary.totalCost)}
              </h4>
              <p className="text-[10px] text-text-muted mt-1 font-medium">
                Inventory acquisition &amp; partner payouts
              </p>
            </div>

            {/* 3. Net Profit & Margin */}
            <div className="bg-card border border-border p-5 rounded-3xl shadow-xs">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-black text-text-secondary uppercase tracking-wider block">
                  Net Profit (Earnings)
                </span>
                <span className="flex items-center text-emerald-600 dark:text-emerald-400 text-[10px] font-black bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                  <TrendingUp className="h-3 w-3 mr-0.5" />
                  {summary.profitMargin}% Margin
                </span>
              </div>
              <h4 className="text-xl md:text-2xl font-black text-emerald-600 dark:text-emerald-400 mt-2">
                {formatPrice(summary.totalProfit)}
              </h4>
              <p className="text-[10px] text-text-muted mt-1 font-medium">
                Net earnings after deducting product costs
              </p>
            </div>

            {/* 4. Completed Orders */}
            <div className="bg-card border border-border p-5 rounded-3xl shadow-xs">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-black text-text-secondary uppercase tracking-wider block">
                  Delivered Orders
                </span>
                <ShoppingBag className="h-4 w-4 text-amber-500" />
              </div>
              <h4 className="text-xl md:text-2xl font-black text-text-primary mt-2">
                {summary.totalOrders}
              </h4>
              <p className="text-[10px] text-text-muted mt-1 font-medium">
                Avg Order Value: <strong>{formatPrice(summary.averageOrderValue)}</strong>
              </p>
            </div>

          </div>

          {/* Business Channel Revenue Split: Main Kirana Shop vs Restaurant Outlets */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Main Shop POS / Walk-in Counter Revenue Card */}
            <div className="bg-card border-2 border-blue-500/20 bg-gradient-to-br from-blue-500/[0.04] to-transparent rounded-3xl p-5 shadow-xs space-y-3">
              <div className="flex items-center justify-between border-b border-border/50 pb-3">
                <div className="flex items-center gap-3">
                  <div className="h-11 w-11 rounded-2xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-xl">
                    🏪
                  </div>
                  <div>
                    <span className="text-[10px] font-black text-blue-600 dark:text-blue-400 uppercase tracking-wider block">POS Counter Sales</span>
                    <h4 className="text-sm font-black text-text-primary">Main Shop Walk-in Revenue</h4>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-lg md:text-xl font-black text-blue-600 dark:text-blue-400 block">
                    {formatPrice(rawSummary.retail?.sales || 0)}
                  </span>
                  <span className="text-[10px] text-text-muted font-bold">Total Counter Sales</span>
                </div>
              </div>
              <div className="flex items-center justify-between text-xs pt-1">
                <span className="text-text-secondary font-medium">Walk-in Customers / Bills:</span>
                <strong className="font-black text-blue-600 dark:text-blue-400 text-sm">
                  {rawSummary.retail?.ordersCount || 0} Orders
                </strong>
              </div>
            </div>

            {/* Restaurant & Food Outlets Revenue Card */}
            <div className="bg-card border-2 border-purple-500/20 bg-gradient-to-br from-purple-500/[0.04] to-transparent rounded-3xl p-5 shadow-xs space-y-3">
              <div className="flex items-center justify-between border-b border-border/50 pb-3">
                <div className="flex items-center gap-3">
                  <div className="h-11 w-11 rounded-2xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-xl">
                    🍽️
                  </div>
                  <div>
                    <span className="text-[10px] font-black text-purple-600 dark:text-purple-400 uppercase tracking-wider block">Food Partner Network</span>
                    <h4 className="text-sm font-black text-text-primary">Restaurant Outlets Revenue</h4>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-lg md:text-xl font-black text-purple-600 dark:text-purple-400 block">
                    {formatPrice(restaurantSales)}
                  </span>
                  <span className="text-[10px] text-text-muted font-bold">Gross Food Sales</span>
                </div>
              </div>
              <div className="flex items-center justify-between text-xs pt-1">
                <span className="text-text-secondary font-medium">Commission &amp; Earnings:</span>
                <strong className="font-black text-emerald-600 dark:text-emerald-400 text-sm">
                  {formatPrice(restaurantProfit)}
                </strong>
              </div>
            </div>
          </div>

          {/* Fulfillment Channel Split (Delivery vs. Self Pickup vs. Walk-in Retail) */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Doorstep Delivery Revenue */}
            <div className="bg-card border border-border/70 rounded-3xl p-5 shadow-xs space-y-3 bg-gradient-to-br from-blue-500/[0.02] to-transparent">
              <div className="flex items-center justify-between border-b border-border/50 pb-2.5">
                <div className="flex items-center gap-2">
                  <span className="text-xl">🛵</span>
                  <div>
                    <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Doorstep Delivery Revenue</h4>
                    <p className="text-[10px] text-text-muted font-medium">{rawSummary.delivery?.ordersCount || 0} Orders delivered to customers</p>
                  </div>
                </div>
                <span className="text-xs font-black text-blue-600 dark:text-blue-400 bg-blue-500/10 px-2.5 py-1 rounded-full border border-blue-500/20">
                  {formatPrice(rawSummary.delivery?.sales || 0)}
                </span>
              </div>

              <div className="flex items-center justify-between text-xs pt-0.5">
                <span className="text-text-secondary font-medium">Net Profit on Deliveries:</span>
                <strong className="font-black text-emerald-600 dark:text-emerald-400 text-sm">
                  {formatPrice(rawSummary.delivery?.profit || 0)}
                </strong>
              </div>
            </div>

            {/* Self Pickup Revenue */}
            <div className="bg-card border border-border/70 rounded-3xl p-5 shadow-xs space-y-3 bg-gradient-to-br from-emerald-500/[0.02] to-transparent">
              <div className="flex items-center justify-between border-b border-border/50 pb-2.5">
                <div className="flex items-center gap-2">
                  <span className="text-xl">🛍️</span>
                  <div>
                    <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Self Pickup / Takeaway Revenue</h4>
                    <p className="text-[10px] text-text-muted font-medium">{rawSummary.pickup?.ordersCount || 0} Orders picked up directly</p>
                  </div>
                </div>
                <span className="text-xs font-black text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2.5 py-1 rounded-full border border-emerald-500/20">
                  {formatPrice(rawSummary.pickup?.sales || 0)}
                </span>
              </div>

              <div className="flex items-center justify-between text-xs pt-0.5">
                <span className="text-text-secondary font-medium">Net Profit on Pickups:</span>
                <strong className="font-black text-emerald-600 dark:text-emerald-400 text-sm">
                  {formatPrice(rawSummary.pickup?.profit || 0)}
                </strong>
              </div>
            </div>

            {/* Walk-in / Retail Counter Revenue */}
            <div className="bg-card border border-border/70 rounded-3xl p-5 shadow-xs space-y-3 bg-gradient-to-br from-amber-500/[0.02] to-transparent">
              <div className="flex items-center justify-between border-b border-border/50 pb-2.5">
                <div className="flex items-center gap-2">
                  <span className="text-xl">🛒</span>
                  <div>
                    <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Walk-in / Retail Counter Revenue</h4>
                    <p className="text-[10px] text-text-muted font-medium">{rawSummary.retail?.ordersCount || 0} Counter sales completed</p>
                  </div>
                </div>
                <span className="text-xs font-black text-amber-600 dark:text-amber-400 bg-amber-500/10 px-2.5 py-1 rounded-full border border-amber-500/20">
                  {formatPrice(rawSummary.retail?.sales || 0)}
                </span>
              </div>

              <div className="flex items-center justify-between text-xs pt-0.5">
                <span className="text-text-secondary font-medium">Net Profit on Retail:</span>
                <strong className="font-black text-emerald-600 dark:text-emerald-400 text-sm">
                  {formatPrice(rawSummary.retail?.profit || 0)}
                </strong>
              </div>
            </div>
          </div>

          {/* Category-Wise Performance Ledger Table */}
          <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-border/60 pb-3.5">
              <div className="flex items-center gap-2">
                <div className="h-8 w-8 rounded-xl bg-accent/10 text-accent flex items-center justify-center font-bold">
                  <Layers className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-black text-text-primary">
                    Category-Wise Financial Breakdown ({rawCategorySales.length} Categories)
                  </h4>
                  <p className="text-[10px] text-text-muted font-medium">
                    Detailed sales, product costs (COGS), net profit, and profit margin per category.
                  </p>
                </div>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="text-[10px] font-black text-text-secondary uppercase tracking-wider border-b border-border/80">
                    <th className="pb-3 pl-2">Category Name</th>
                    <th className="pb-3 text-center">Units Sold</th>
                    <th className="pb-3 text-right">Total Sales (Revenue)</th>
                    <th className="pb-3 text-right">Product Cost (COGS)</th>
                    <th className="pb-3 text-right">Net Profit</th>
                    <th className="pb-3 text-center">Profit Margin</th>
                    <th className="pb-3 text-right pr-2">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40">
                  {rawCategorySales.map((cat) => {
                    const meta = getCategoryMeta(cat.categoryName)
                    const catCost = cat.cost ?? (cat.sales - cat.profit)
                    const margin = cat.sales > 0 ? Math.round((cat.profit / cat.sales) * 100) : 0
                    const percentOfStore = Math.round((cat.sales / (rawSummary.totalSales || 1)) * 100)
                    const isSelected = selectedCategory.toLowerCase() === cat.categoryName.toLowerCase()

                    return (
                      <tr 
                        key={cat.categoryName} 
                        className={`transition-colors ${
                          isSelected ? 'bg-primary/5 font-bold' : 'hover:bg-muted/20'
                        }`}
                      >
                        <td className="py-3 pl-2">
                          <div className="flex items-center gap-2">
                            <span className="text-base">{meta.icon}</span>
                            <div>
                              <span className="font-black text-text-primary text-xs block">
                                {cat.categoryName}
                              </span>
                              <div className="flex items-center gap-1.5 mt-0.5">
                                <span className={`text-[9px] font-bold px-1.5 py-0.2 rounded-md border ${meta.badge}`}>
                                  {cat.type === 'restaurant' ? 'Kitchen & Restaurant' : 'Grocery'}
                                </span>
                                <span className="text-[9.5px] text-text-muted font-medium">
                                  {percentOfStore}% of store sales
                                </span>
                              </div>
                            </div>
                          </div>
                        </td>

                        <td className="py-3 text-center font-bold text-text-secondary">
                          {cat.quantity || '-'}
                        </td>

                        <td className="py-3 text-right font-black text-text-primary text-xs">
                          {formatPrice(cat.sales)}
                        </td>

                        <td className="py-3 text-right font-bold text-blue-600 dark:text-blue-400">
                          {formatPrice(catCost)}
                        </td>

                        <td className="py-3 text-right font-black text-emerald-600 dark:text-emerald-400">
                          {formatPrice(cat.profit)}
                        </td>

                        <td className="py-3 text-center">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-black border ${
                            margin >= 30 
                              ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20'
                              : margin >= 15
                              ? 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/20'
                              : 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20'
                          }`}>
                            {margin}%
                          </span>
                        </td>

                        <td className="py-3 text-right pr-2">
                          <button
                            onClick={() => setSelectedCategory(isSelected ? 'all' : cat.categoryName)}
                            className={`px-2.5 py-1 rounded-xl text-[10px] font-black transition-all cursor-pointer ${
                              isSelected
                                ? 'bg-primary text-white'
                                : 'bg-muted/60 hover:bg-muted text-text-secondary hover:text-text-primary'
                            }`}
                          >
                            {isSelected ? 'Viewing' : 'View Products'}
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>

          {/* Itemized Product Sales Table */}
          <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-border/60 pb-3.5">
              <div className="flex items-center gap-2">
                <div className="h-8 w-8 rounded-xl bg-amber-500/10 text-amber-600 flex items-center justify-center font-bold">
                  <Award className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-black text-text-primary">
                    Itemized Product Sales ({filteredProducts.length} Products)
                  </h4>
                  <p className="text-[10px] text-text-muted font-medium">
                    {selectedCategory === 'all'
                      ? 'Showing products sold across all categories.'
                      : `Filtered to products under "${selectedCategory}".`}
                  </p>
                </div>
              </div>

              <div className="relative w-full sm:w-64">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="text"
                  placeholder="Search product name..."
                  value={productSearch}
                  onChange={(e) => setProductSearch(e.target.value)}
                  className="bg-muted border border-border pl-9 pr-3 py-1.5 rounded-2xl text-xs font-bold text-text-primary focus:outline-none w-full"
                />
              </div>
            </div>

            <div className="overflow-x-auto max-h-96 overflow-y-auto pr-1">
              <table className="w-full text-left border-collapse text-xs">
                <thead className="sticky top-0 bg-card z-10">
                  <tr className="text-[10px] font-black text-text-secondary uppercase tracking-wider border-b border-border/80">
                    <th className="pb-2.5 pl-2">Product Name</th>
                    <th className="pb-2.5">Category</th>
                    <th className="pb-2.5 text-right">Selling Price</th>
                    <th className="pb-2.5 text-right">Cost Price</th>
                    <th className="pb-2.5 text-center">Qty Sold</th>
                    <th className="pb-2.5 text-right">Total Revenue</th>
                    <th className="pb-2.5 text-right">Net Profit</th>
                    <th className="pb-2.5 text-center pr-2">Margin</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40">
                  {filteredProducts.map((prod) => {
                    const margin = prod.sales > 0 ? Math.round((prod.profit / prod.sales) * 100) : 0
                    const meta = getCategoryMeta(prod.categoryName || '')

                    return (
                      <tr key={prod.productId} className="hover:bg-muted/15 transition-colors">
                        <td className="py-2.5 pl-2">
                          <span className="font-bold text-text-primary block truncate max-w-[200px]" title={prod.name}>
                            {prod.name}
                          </span>
                        </td>

                        <td className="py-2.5">
                          <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[9.5px] font-bold border ${meta.badge}`}>
                            <span>{meta.icon}</span>
                            <span className="truncate max-w-[110px]">{prod.categoryName || 'General'}</span>
                          </span>
                        </td>

                        <td className="py-2.5 text-right font-black text-text-primary">
                          {formatPrice(prod.price || 0)}
                        </td>

                        <td className="py-2.5 text-right font-semibold text-blue-600 dark:text-blue-400">
                          {formatPrice(prod.costPrice || 0)}
                        </td>

                        <td className="py-2.5 text-center font-black text-text-secondary">
                          {prod.quantity}
                        </td>

                        <td className="py-2.5 text-right font-black text-text-primary">
                          {formatPrice(prod.sales)}
                        </td>

                        <td className="py-2.5 text-right font-black text-emerald-600 dark:text-emerald-400">
                          {formatPrice(prod.profit)}
                        </td>

                        <td className="py-2.5 text-center pr-2">
                          <span className={`text-[10px] font-black px-1.5 py-0.5 rounded-md ${
                            margin >= 30 ? 'text-emerald-600 dark:text-emerald-400 bg-emerald-500/10' :
                            margin >= 15 ? 'text-blue-600 dark:text-blue-400 bg-blue-500/10' :
                            'text-amber-600 dark:text-amber-400 bg-amber-500/10'
                          }`}>
                            {margin}%
                          </span>
                        </td>
                      </tr>
                    )
                  })}

                  {filteredProducts.length === 0 && (
                    <tr>
                      <td colSpan={8} className="py-10 text-center text-text-muted text-xs font-bold">
                        {productSearch ? `No products found matching "${productSearch}".` : 'No products sold in this category.'}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Revenue & Fee Diagnostic Summary */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            
            {/* Revenue Breakdown */}
            <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs space-y-3.5">
              <div className="flex items-center gap-2 border-b border-border/60 pb-3">
                <FileText className="h-5 w-5 text-primary" />
                <div>
                  <h4 className="text-sm font-black text-text-primary">Store Fee &amp; Collection Breakdown</h4>
                  <p className="text-[10px] text-text-muted font-medium">Gross sales, delivery charges, packaging fees, and taxes collected.</p>
                </div>
              </div>

              <div className="space-y-2.5 text-xs">
                <div className="flex justify-between items-center py-1">
                  <span className="text-text-secondary font-medium">Gross Product Sales:</span>
                  <span className="font-black text-text-primary">{formatPrice(summary.productSales || 0)}</span>
                </div>
                <div className="flex justify-between items-center py-1">
                  <span className="text-text-secondary font-medium">Delivery Charges Collected:</span>
                  <span className="font-black text-blue-500">{formatPrice(summary.totalDeliveryFee || 0)}</span>
                </div>
                <div className="flex justify-between items-center py-1">
                  <span className="text-text-secondary font-medium">Packaging &amp; Handling Fees:</span>
                  <span className="font-black text-purple-500">{formatPrice(summary.totalMiscFee || 0)}</span>
                </div>
                {(summary.totalTaxes || 0) > 0 && (
                  <div className="flex justify-between items-center py-1">
                    <span className="text-text-secondary font-medium">GST / Taxes Collected:</span>
                    <span className="font-black text-emerald-600 dark:text-emerald-400">{formatPrice(summary.totalTaxes || 0)}</span>
                  </div>
                )}
                <div className="flex justify-between items-center pt-2.5 border-t border-border/60 text-sm">
                  <span className="font-black text-text-primary">Total Collected Cash Flow:</span>
                  <span className="font-black text-primary text-base">
                    {formatPrice(
                      summary.totalCollected || (
                        (summary.productSales || summary.totalSales || 0) + 
                        (summary.totalDeliveryFee || 0) + 
                        (summary.totalMiscFee || 0) + 
                        (summary.totalTaxes || 0)
                      )
                    )}
                  </span>
                </div>
              </div>
            </div>

            {/* Cost Price Diagnostics */}
            <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs space-y-3.5 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2 border-b border-border/60 pb-3">
                  <Activity className="h-5 w-5 text-rose-500" />
                  <div>
                    <h4 className="text-sm font-black text-text-primary">Inventory Cost Price Health</h4>
                    <p className="text-[10px] text-text-muted font-medium">Accuracy status of product cost prices for accounting.</p>
                  </div>
                </div>

                <div className="mt-3 text-xs space-y-2">
                  {summary.missingCostCount && summary.missingCostCount > 0 ? (
                    <div className="p-3 bg-rose-500/10 border border-rose-500/20 rounded-2xl text-rose-600 space-y-1">
                      <h5 className="font-black text-xs flex items-center gap-1.5">
                        <AlertTriangle className="h-3.5 w-3.5" /> {summary.missingCostCount} Items Missing Cost Price
                      </h5>
                      <p className="text-[10.5px] leading-relaxed font-semibold text-rose-700 dark:text-rose-400">
                        Some items sold in this period have no Cost Price set. Profit is estimated using a 25% fallback margin. Update Cost Price in the <strong>Inventory</strong> tab.
                      </p>
                    </div>
                  ) : (
                    <div className="p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-2xl text-emerald-600">
                      <h5 className="font-black text-xs flex items-center gap-1.5">
                        <CheckCircle2 className="h-3.5 w-3.5" /> 100% Cost Price Coverage
                      </h5>
                      <p className="text-[10.5px] leading-relaxed font-semibold text-emerald-700 dark:text-emerald-400">
                        All sold items have exact Cost Prices configured. Accounting margins are 100% accurate.
                      </p>
                    </div>
                  )}
                </div>
              </div>

              <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-2xl text-blue-700 dark:text-blue-300 text-[10.5px] font-semibold leading-relaxed">
                💡 <strong>Tip:</strong> You can click any category in the list above to isolate that category's revenue, product costs, and top products.
              </div>
            </div>

          </div>

          {/* SVG Trend Line Graph */}
          {rawDailySales.length >= 2 && (
            <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs">
              <div className="flex justify-between items-center mb-4 border-b border-border/60 pb-3">
                <div>
                  <h4 className="text-sm font-black text-text-primary">Daily Sales vs. Profit Trend</h4>
                  <p className="text-[10px] text-text-muted font-medium">Visual trend mapping daily revenue vs. net earnings.</p>
                </div>
                
                <div className="flex gap-4 text-xs font-bold">
                  <div className="flex items-center gap-1.5">
                    <span className="h-2.5 w-5 rounded-full bg-primary inline-block" />
                    <span className="text-text-secondary">Sales</span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <span className="h-2.5 w-5 rounded-full bg-emerald-500 inline-block" />
                    <span className="text-text-secondary">Profit</span>
                  </div>
                </div>
              </div>

              <div className="w-full overflow-x-auto scrollbar-hide">
                <svg viewBox="0 0 800 240" className="w-full min-w-[700px] h-60">
                  <defs>
                    <linearGradient id="salesGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="var(--color-primary, #e20a22)" stopOpacity="0.15" />
                      <stop offset="100%" stopColor="var(--color-primary, #e20a22)" stopOpacity="0.0" />
                    </linearGradient>
                    <linearGradient id="profitGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#10b981" stopOpacity="0.15" />
                      <stop offset="100%" stopColor="#10b981" stopOpacity="0.0" />
                    </linearGradient>
                  </defs>

                  {/* Horizontal gridlines */}
                  {[0, 0.25, 0.5, 0.75, 1].map((ratio) => {
                    const y = 35 + ratio * (240 - 70)
                    const gridVal = Math.round(svgChartPath.maxValue * (1 - ratio))
                    return (
                      <g key={ratio} className="opacity-40">
                        <line x1="35" y1={y} x2="765" y2={y} stroke="var(--color-border, #e5e7eb)" strokeDasharray="3 3" />
                        <text x="30" y={y + 3} textAnchor="end" fill="var(--color-text-muted, #9ca3af)" className="text-[9px] font-mono font-bold">
                          {gridVal >= 1000 ? `${(gridVal/1000).toFixed(1)}k` : gridVal}
                        </text>
                      </g>
                    )
                  })}

                  {/* Area fills */}
                  <path d={svgChartPath.salesArea} fill="url(#salesGrad)" />
                  <path d={svgChartPath.profitArea} fill="url(#profitGrad)" />

                  {/* Trend paths */}
                  <path d={svgChartPath.salesPath} fill="none" stroke="var(--color-primary, #e20a22)" strokeWidth="2.5" strokeLinecap="round" />
                  <path d={svgChartPath.profitPath} fill="none" stroke="#10b981" strokeWidth="2" strokeLinecap="round" />

                  {/* Date labels at bottom */}
                  {svgChartPath.points.map((p, i) => {
                    const showLabel = svgChartPath.points.length <= 10 || i % Math.ceil(svgChartPath.points.length / 8) === 0
                    if (!showLabel) return null
                    const datePart = p.label.split('-')[2]
                    const monthPart = formatDate(p.label, 'MMM')
                    return (
                      <g key={i} className="opacity-80">
                        <text x={p.x} y="225" textAnchor="middle" fill="var(--color-text-secondary, #4b5563)" className="text-[9px] font-bold">
                          {`${datePart} ${monthPart}`}
                        </text>
                      </g>
                    )
                  })}

                  {/* Interactive circles */}
                  {svgChartPath.points.map((p, i) => (
                    <g key={i} className="group/dot cursor-pointer">
                      <circle cx={p.x} cy={p.ySales} r="3" fill="var(--color-primary, #e20a22)" className="hover:r-5 transition-all" />
                      <circle cx={p.x} cy={p.yProfit} r="3.5" fill="#10b981" className="hover:r-5 transition-all" />
                    </g>
                  ))}
                </svg>
              </div>
            </div>
          )}

        </>
      )}

    </div>
  )
}
