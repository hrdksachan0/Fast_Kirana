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
      const url = `/api/admin/reports?startDate=${startDate}&endDate=${endDate}`
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

  // Excel / CSV Exporter with UTF-8 BOM
  const handleDownloadCSV = () => {
    try {
      let csv = '\uFEFF' // UTF-8 Byte Order Mark for Excel
      csv += 'FASTKIRANA COMPREHENSIVE FINANCIAL REPORT\n'
      csv += `Date Range,"${startDate} to ${endDate}"\n`
      csv += `Filtered Category,"${selectedCategory === 'all' ? 'All Categories (Full Store)' : selectedCategory}"\n`
      csv += `Generated On,"${new Date().toLocaleString()}"\n\n`

      // 1. Financial Summary
      csv += '--- STORE FINANCIAL SUMMARY ---\n'
      csv += 'Metric,Amount (INR)\n'
      csv += `Total Net Sales (Revenue),₹${summary.totalSales.toFixed(2)}\n`
      csv += `Cost of Goods / Payouts (COGS),₹${summary.totalCost.toFixed(2)}\n`
      csv += `Net Profit (Earnings),₹${summary.totalProfit.toFixed(2)}\n`
      csv += `Overall Profit Margin,${summary.profitMargin}%\n`
      csv += `Total Orders Delivered,${summary.totalOrders}\n`
      csv += `Average Order Value,₹${summary.averageOrderValue.toFixed(2)}\n`
      csv += `Delivery Fees Collected,₹${(summary.totalDeliveryFee || 0).toFixed(2)}\n`
      csv += `Packaging & Handling Fees,₹${(summary.totalMiscFee || 0).toFixed(2)}\n`
      csv += `GST / Taxes Collected,₹${(summary.totalTaxes || 0).toFixed(2)}\n\n`

      // 2. Category-Wise Financial Breakdown
      csv += '--- CATEGORY-WISE FINANCIAL BREAKDOWN ---\n'
      csv += 'Category Name,Type,Units Sold,Total Sales (INR),Product Cost (INR),Net Profit (INR),Margin (%)\n'
      rawCategorySales.forEach(cat => {
        const catCost = cat.cost ?? (cat.sales - cat.profit)
        const margin = cat.sales > 0 ? ((cat.profit / cat.sales) * 100).toFixed(1) : '0'
        csv += `"${cat.categoryName}","${cat.type || 'grocery'}",${cat.quantity || '-'},₹${cat.sales.toFixed(2)},₹${catCost.toFixed(2)},₹${cat.profit.toFixed(2)},${margin}%\n`
      })
      csv += '\n'

      // 3. Itemized Product Performance
      csv += '--- ITEMIZED PRODUCT SALES ---\n'
      csv += 'Product Name,Category,Selling Price (INR),Cost Price (INR),Qty Sold,Total Revenue (INR),Net Profit (INR),Margin (%)\n'
      filteredProducts.forEach(prod => {
        const margin = prod.sales > 0 ? ((prod.profit / prod.sales) * 100).toFixed(1) : '0'
        csv += `"${prod.name}","${prod.categoryName || '-'}",₹${(prod.price || 0).toFixed(2)},₹${(prod.costPrice || 0).toFixed(2)},${prod.quantity},₹${prod.sales.toFixed(2)},₹${prod.profit.toFixed(2)},${margin}%\n`
      })

      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `FastKirana_Finance_${startDate}_to_${endDate}.csv`)
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)

      toast.success('Financial report exported successfully!')
    } catch (err) {
      console.error(err)
      toast.error('Could not export report')
    }
  }

  return (
    <div className="space-y-6">
      
      {/* Top Header & Date Presets */}
      <div className="bg-card border border-border p-5 md:p-6 rounded-3xl shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
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

          {/* Export CSV Button */}
          <button
            onClick={handleDownloadCSV}
            disabled={loading}
            className="h-9 px-4 rounded-2xl text-xs font-black bg-emerald-600 hover:bg-emerald-700 text-white transition-all shadow-xs flex items-center gap-1.5 disabled:opacity-50 cursor-pointer"
          >
            <Download className="h-3.5 w-3.5" />
            <span>Export Excel (.csv)</span>
          </button>
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

          {/* Fulfillment Channel Split (Delivery vs. Self Pickup) */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
