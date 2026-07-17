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
  FileText
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface DailySale {
  date: string
  sales: number
  profit: number
  orders: number
}

interface CategorySale {
  categoryName: string
  sales: number
  profit: number
}

interface TopProduct {
  productId: string
  name: string
  quantity: number
  sales: number
  profit: number
  categoryName?: string
}

interface ReportSummary {
  totalSales: number
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
}

export function AdminReports() {
  const [dateRange, setDateRange] = useState<'today' | '7days' | '30days' | 'custom'>('30days')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [loading, setLoading] = useState(true)
  const [segment, setSegment] = useState<'all' | 'grocery' | 'cafe' | 'restaurant'>('all')
  
  // Loaded report data
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

  // Category segment helpers
  const isCafeCategory = (catName: string) => {
    const name = catName.toLowerCase().replace(/é/g, 'e')
    return name.includes('cafe') || name.includes('sandwich') || name.includes('pasta') || name.includes('roll') || name.includes('bite') || name.includes('sip') || name.includes('shake') || name.includes('mocktail') || name.includes('soda') || name.includes('beverage') || name.includes('ice cream') || name.includes('dessert') || name.includes('chilled')
  }

  const isRestaurantCategory = (catName: string) => {
    const name = catName.toLowerCase()
    return name.includes('restaurant') || name.includes('indian') || name.includes('biryani') || name.includes('rice') || name.includes('meal') || name.includes('combo') || name.includes('thali') || name.includes('roti') || name.includes('paneer') || name.includes('curry')
  }

  const isGroceryCategory = (catName: string) => {
    return !isCafeCategory(catName) && !isRestaurantCategory(catName)
  }

  // Derived filtered calculations
  const categorySales = useMemo(() => {
    if (segment === 'all') return rawCategorySales
    if (segment === 'grocery') return rawCategorySales.filter(c => isGroceryCategory(c.categoryName))
    if (segment === 'cafe') return rawCategorySales.filter(c => isCafeCategory(c.categoryName))
    return rawCategorySales.filter(c => isRestaurantCategory(c.categoryName))
  }, [rawCategorySales, segment])

  const topProducts = useMemo(() => {
    if (segment === 'all') return rawTopProducts
    if (segment === 'grocery') return rawTopProducts.filter(p => isGroceryCategory(p.categoryName || ''))
    if (segment === 'cafe') return rawTopProducts.filter(p => isCafeCategory(p.categoryName || ''))
    return rawTopProducts.filter(p => isRestaurantCategory(p.categoryName || ''))
  }, [rawTopProducts, segment])

  const summary = useMemo(() => {
    if (segment === 'all') return rawSummary
    const sales = categorySales.reduce((sum, c) => sum + (c.sales || 0), 0)
    const profit = categorySales.reduce((sum, c) => sum + (c.profit || 0), 0)
    const cost = sales - profit
    const totalOrders = segment === 'grocery' 
      ? rawSummary.totalOrders 
      : Math.round(sales / (rawSummary.averageOrderValue || 50))
    const averageOrderValue = totalOrders > 0 ? sales / totalOrders : 0
    const profitMargin = sales > 0 ? (profit / sales) * 100 : 0
    return {
      ...rawSummary,
      totalSales: Math.round(sales * 100) / 100,
      totalProfit: Math.round(profit * 100) / 100,
      totalCost: Math.round(cost * 100) / 100,
      totalOrders: totalOrders || 0,
      averageOrderValue: Math.round(averageOrderValue * 100) / 100,
      profitMargin: Math.round(profitMargin * 10) / 10
    }
  }, [rawSummary, categorySales, segment])

  const dailySales = useMemo(() => {
    if (segment === 'all') return rawDailySales
    const allSales = rawCategorySales.reduce((sum, c) => sum + (c.sales || 0), 0) || 1
    const filteredSales = categorySales.reduce((sum, c) => sum + (c.sales || 0), 0)
    const ratio = filteredSales / allSales
    return rawDailySales.map(d => ({
      ...d,
      sales: Math.round(d.sales * ratio * 100) / 100,
      profit: Math.round(d.profit * ratio * 100) / 100
    }))
  }, [rawDailySales, rawCategorySales, categorySales, segment])

  // Set default dates on load
  useEffect(() => {
    const end = new Date()
    const start = new Date()
    start.setDate(end.getDate() - 30)
    
    setStartDate(start.toISOString().split('T')[0])
    setEndDate(end.toISOString().split('T')[0])
  }, [])

  // Auto fetch when date range selection changes
  const fetchReport = async () => {
    try {
      setLoading(true)
      
      let startStr = startDate
      let endStr = endDate

      if (dateRange === 'today') {
        const today = new Date().toISOString().split('T')[0]
        startStr = today
        endStr = today
      } else if (dateRange === '7days') {
        const d = new Date()
        d.setDate(d.getDate() - 7)
        startStr = d.toISOString().split('T')[0]
        endStr = new Date().toISOString().split('T')[0]
      } else if (dateRange === '30days') {
        const d = new Date()
        d.setDate(d.getDate() - 30)
        startStr = d.toISOString().split('T')[0]
        endStr = new Date().toISOString().split('T')[0]
      }

      const url = `/api/admin/reports?startDate=${startStr}&endDate=${endStr}`
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
  }, [dateRange, startDate, endDate])

  // Custom SVG Line Graph calculations
  const svgChartPath = useMemo(() => {
    if (dailySales.length < 2) return { salesPath: '', profitPath: '', salesArea: '', profitArea: '', points: [], maxValue: 100 }
    
    const width = 800
    const height = 240
    const padding = 35

    const chartWidth = width - padding * 2
    const chartHeight = height - padding * 2

    // Find max value in dataset to scale Y axis
    const maxSalesVal = Math.max(...dailySales.map(d => d.sales), 100)
    const maxProfitVal = Math.max(...dailySales.map(d => d.profit), 100)
    const maxValue = Math.max(maxSalesVal, maxProfitVal) * 1.15 // Add 15% headroom

    const points = dailySales.map((d, index) => {
      const x = padding + (index / (dailySales.length - 1)) * chartWidth
      // Y goes from top to bottom in SVG, so subtract from chartHeight
      const ySales = padding + chartHeight - (d.sales / maxValue) * chartHeight
      const yProfit = padding + chartHeight - (d.profit / maxValue) * chartHeight
      return { x, ySales, yProfit, label: d.date, sales: d.sales, profit: d.profit }
    })

    // Construct SVG path strings
    const salesPath = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.ySales}`).join(' ')
    const profitPath = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.yProfit}`).join(' ')

    // Fills for area under the curves
    const salesArea = `${salesPath} L ${points[points.length - 1].x} ${height - padding} L ${points[0].x} ${height - padding} Z`
    const profitArea = `${profitPath} L ${points[points.length - 1].x} ${height - padding} L ${points[0].x} ${height - padding} Z`

    return { salesPath, profitPath, salesArea, profitArea, points, maxValue }
  }, [dailySales])

  // CSV Exporter
  const handleDownloadCSV = () => {
    try {
      // 1. Prepare Summary CSV Data
      let csvContent = 'data:text/csv;charset=utf-8,'
      csvContent += 'REPORT SUMMARY\n'
      csvContent += `Total Sales (Collected),${summary.totalSales}\n`
      csvContent += `Gross Product Sales,${summary.productSales || 0}\n`
      csvContent += `GST / Taxes,${summary.totalTaxes || 0}\n`
      csvContent += `Delivery Charges,${summary.totalDeliveryFee || 0}\n`
      csvContent += `Miscellaneous / Packaging Fees,${summary.totalMiscFee || 0}\n`
      csvContent += `Total Cost Basis (COGS),${summary.totalCost}\n`
      csvContent += `Total Profit,${summary.totalProfit}\n`
      csvContent += `Profit Margin (%),${summary.profitMargin}%\n`
      csvContent += `Total Orders,${summary.totalOrders}\n`
      csvContent += `Average Order Value,${summary.averageOrderValue}\n`
      csvContent += `Items Missing Cost Price,${summary.missingCostCount || 0}\n\n`

      // 2. Add Daily sales trend log
      csvContent += 'DAILY TREND LOG\nDate,Sales (INR),Profit (INR),Orders Count\n'
      dailySales.forEach(row => {
        csvContent += `${row.date},${row.sales},${row.profit},${row.orders}\n`
      })
      csvContent += '\n'

      // 3. Add Category breakdown
      csvContent += 'CATEGORY BREAKDOWN\nCategory Name,Total Sales (INR),Net Profit (INR)\n'
      categorySales.forEach(row => {
        csvContent += `"${row.categoryName}",${row.sales},${row.profit}\n`
      })
      csvContent += '\n'

      // 4. Add Top Products
      csvContent += 'TOP SELLING PRODUCTS\nProduct Name,Quantity Sold,Sales Revenue (INR),Profit Generated (INR)\n'
      topProducts.forEach(row => {
        csvContent += `"${row.name}",${row.quantity},${row.sales},${row.profit}\n`
      })

      // Trigger download
      const encodedUri = encodeURI(csvContent)
      const link = document.createElement('a')
      link.setAttribute('href', encodedUri)
      
      const fileName = `FastKirana_Sales_Report_${startDate}_to_${endDate}.csv`
      link.setAttribute('download', fileName)
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      toast.success('Report downloaded successfully!')
    } catch (err) {
      console.error(err)
      toast.error('Could not build report download file')
    }
  }

  return (
    <div className="space-y-6">
      
      {/* Date selector header */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
            <Calendar className="h-5 w-5 text-accent" />
            Financial & Sales Reports
          </h3>
          <p className="text-xs text-text-secondary mt-0.5">
            Review detailed financial records, profit margins, categories, and top product performances.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Quick ranges */}
          <div className="flex bg-muted/60 p-1 rounded-xl border border-border text-[11px] font-bold">
            {(['today', '7days', '30days', 'custom'] as const).map((r) => (
              <button
                key={r}
                onClick={() => setDateRange(r)}
                className={`px-3 py-1 rounded-lg capitalize transition-colors ${
                  dateRange === r ? 'bg-card text-primary shadow-sm' : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                {r === '7days' ? '7 Days' : r === '30days' ? '30 Days' : r}
              </button>
            ))}
          </div>

          {/* Custom Date Picker Inputs */}
          {dateRange === 'custom' && (
            <div className="flex items-center gap-2 text-xs">
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="bg-muted border border-border px-2.5 py-1.5 rounded-lg text-text-primary focus:outline-none"
              />
              <span className="text-text-muted">to</span>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="bg-muted border border-border px-2.5 py-1.5 rounded-lg text-text-primary focus:outline-none"
              />
            </div>
          )}

          <button
            onClick={handleDownloadCSV}
            disabled={loading}
            className="h-9 px-4 rounded-xl text-xs font-bold bg-accent hover:bg-accent-dark text-white transition-colors flex items-center gap-1.5 disabled:opacity-50"
          >
            <Download className="h-3.5 w-3.5" />
            Download CSV
          </button>
        </div>
      </div>

      {/* Segment Category Filters */}
      <div className="flex bg-muted/30 p-1 rounded-2xl border border-border/60 text-[11px] font-bold max-w-lg mb-6 shadow-xs gap-1">
        {([
          { key: 'all', label: 'All Sales' },
          { key: 'grocery', label: 'Grocery 📦' },
          { key: 'cafe', label: 'Cafe ☕' },
          { key: 'restaurant', label: 'Restaurant 🍳' }
        ] as const).map((seg) => (
          <button
            key={seg.key}
            onClick={() => setSegment(seg.key)}
            className={`flex-1 py-2 text-center rounded-xl uppercase tracking-wider transition-all duration-200 cursor-pointer ${
              segment === seg.key 
                ? 'bg-primary text-primary-foreground shadow-sm scale-[1.02]' 
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/40'
            }`}
          >
            {seg.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center text-text-secondary">
          <Loader2 className="h-8 w-8 animate-spin text-primary mb-2" />
          <span className="text-xs font-semibold">Generating report charts...</span>
        </div>
      ) : (
        <>
          {/* Summary Metric Grid */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            
            {/* Sales Card */}
            <div className="bg-card border border-border p-5 rounded-2xl shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">Total Sales</span>
                <IndianRupee className="h-4 w-4 text-accent" />
              </div>
              <h4 className="text-lg md:text-xl font-black text-text-primary mt-2">{formatPrice(summary.totalSales)}</h4>
              <p className="text-[9px] text-text-muted mt-1">Net revenue generated in period</p>
            </div>

            {/* Cost basis Card */}
            <div className="bg-card border border-border p-5 rounded-2xl shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">Cost Basis</span>
                <Activity className="h-4 w-4 text-blue-500" />
              </div>
              <h4 className="text-lg md:text-xl font-black text-text-primary mt-2">{formatPrice(summary.totalCost)}</h4>
              <p className="text-[9px] text-text-muted mt-1">Acquisition cost of items sold</p>
            </div>

            {/* Profit Card */}
            <div className="bg-card border border-border p-5 rounded-2xl shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">Net profit</span>
                <span className="flex items-center text-accent text-[9px] font-bold bg-accent/10 px-1.5 py-0.5 rounded">
                  <TrendingUp className="h-3 w-3 mr-0.5" />
                  {summary.profitMargin}% Margin
                </span>
              </div>
              <h4 className="text-lg md:text-xl font-black text-accent mt-2">{formatPrice(summary.totalProfit)}</h4>
              <p className="text-[9px] text-text-muted mt-1">Earnings post product cost deduction</p>
            </div>

            {/* Orders summary */}
            <div className="bg-card border border-border p-5 rounded-2xl shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">Orders Count</span>
                <ShoppingBag className="h-4 w-4 text-primary" />
              </div>
              <h4 className="text-lg md:text-xl font-black text-text-primary mt-2">{summary.totalOrders}</h4>
              <p className="text-[9px] text-text-muted mt-1">Average Order Value: {formatPrice(summary.averageOrderValue)}</p>
            </div>

          </div>

          {/* Detailed Revenue & Cost Price Warnings */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 my-6">
            {/* Revenue Breakdown */}
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
              <div className="flex items-center gap-2 border-b border-border/60 pb-3">
                <FileText className="h-5 w-5 text-primary" />
                <div>
                  <h4 className="text-sm font-bold text-text-primary">Revenue & Fee Breakdown</h4>
                  <p className="text-[10px] text-text-muted">Breakdown of gross sales, taxes, delivery fees, and packaging charges.</p>
                </div>
              </div>

              <div className="space-y-3 text-xs">
                <div className="flex justify-between items-center py-1">
                  <span className="text-text-secondary">Gross Product Sales:</span>
                  <span className="font-bold text-text-primary">{formatPrice(summary.productSales || 0)}</span>
                </div>
                <div className="flex justify-between items-center py-1">
                  <span className="text-text-secondary">GST / Taxes Collected:</span>
                  <span className="font-bold text-[#00b140]">{formatPrice(summary.totalTaxes || 0)}</span>
                </div>
                <div className="flex justify-between items-center py-1">
                  <span className="text-text-secondary">Delivery Charges Collected:</span>
                  <span className="font-bold text-blue-500">{formatPrice(summary.totalDeliveryFee || 0)}</span>
                </div>
                <div className="flex justify-between items-center py-1 border-b border-border/40 pb-2">
                  <span className="text-text-secondary">Packaging / Miscellaneous Charges:</span>
                  <span className="font-bold text-purple-500">{formatPrice(summary.totalMiscFee || 0)}</span>
                </div>
                <div className="flex justify-between items-center pt-2 text-sm">
                  <span className="font-extrabold text-text-primary">Total Collected Revenue:</span>
                  <span className="font-black text-primary">{formatPrice(summary.totalSales)}</span>
                </div>
              </div>
            </div>

            {/* Cost Price Diagnostics */}
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2 border-b border-border/60 pb-3">
                  <Activity className="h-5 w-5 text-rose-500" />
                  <div>
                    <h4 className="text-sm font-bold text-text-primary">Cost Price Analysis</h4>
                    <p className="text-[10px] text-text-muted">Status of product cost prices and net margin calculations.</p>
                  </div>
                </div>

                <div className="mt-3 space-y-3 text-xs">
                  {summary.missingCostCount && summary.missingCostCount > 0 ? (
                    <div className="p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-600 space-y-1">
                      <h5 className="font-bold text-[11px] flex items-center gap-1">
                        <span>⚠️</span> Cost Price Missing: {summary.missingCostCount} Products
                      </h5>
                      <p className="text-[10px] text-rose-600/90 leading-relaxed font-semibold">
                        Some items sold in this period do not have a cost price set. Profit margins for these items are currently calculated using a 25% fallback margin.
                      </p>
                    </div>
                  ) : (
                    <div className="p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-emerald-600">
                      <h5 className="font-bold text-[11px] flex items-center gap-1">
                        <span>✅</span> Perfect Cost Price Coverage
                      </h5>
                      <p className="text-[10px] text-emerald-600/90 leading-relaxed font-semibold">
                        All items sold in this period have cost prices configured. Margins are 100% accurate.
                      </p>
                    </div>
                  )}

                  {missingCostProducts.length > 0 && (
                    <div className="space-y-1.5 mt-2">
                      <span className="text-[10px] font-bold text-text-secondary uppercase block">Items needing Cost Price update:</span>
                      <div className="max-h-24 overflow-y-auto divide-y divide-border/40 border border-border/60 rounded-lg p-2 bg-muted/20">
                        {missingCostProducts.map((p) => (
                          <div key={p.id} className="flex justify-between py-1 text-[10px]">
                            <span className="truncate max-w-[180px] font-medium text-text-primary">{p.name}</span>
                            <span className="text-text-muted">Price: {formatPrice(p.price)}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Suggestions Box */}
              <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl text-blue-600 text-[10px] leading-relaxed font-semibold">
                <strong>💡 Suggestion:</strong> Update product cost prices in the <em>Inventory</em> tab. Accurate cost prices are critical for matching correct profit margins, calculating actual product COGS, and generating exact tax sheets.
              </div>
            </div>
          </div>

          {/* SVG line Graph of daily sales vs. profit */}
          {dailySales.length >= 2 ? (
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm">
              <div className="flex justify-between items-center mb-4 border-b border-border/60 pb-3">
                <div>
                  <h4 className="text-sm font-bold text-text-primary">Sales & Profit Trends</h4>
                  <p className="text-[10px] text-text-muted">Visual graph mapping revenue (Purple) and profit (Green).</p>
                </div>
                
                <div className="flex gap-4 text-xs font-semibold">
                  <div className="flex items-center gap-1.5">
                    <span className="h-2 w-5 rounded bg-primary inline-block" />
                    <span className="text-text-secondary">Sales</span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <span className="h-2 w-5 rounded bg-accent inline-block" />
                    <span className="text-text-secondary">Profit</span>
                  </div>
                </div>
              </div>

              {/* Responsive custom SVG line chart */}
              <div className="w-full overflow-x-auto scrollbar-hide">
                <svg viewBox="0 0 800 240" className="w-full min-w-[700px] h-60">
                  <defs>
                    <linearGradient id="salesGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="var(--color-primary, #e20a22)" stopOpacity="0.15" />
                      <stop offset="100%" stopColor="var(--color-primary, #e20a22)" stopOpacity="0.0" />
                    </linearGradient>
                    <linearGradient id="profitGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="var(--color-accent, #00b140)" stopOpacity="0.15" />
                      <stop offset="100%" stopColor="var(--color-accent, #00b140)" stopOpacity="0.0" />
                    </linearGradient>
                  </defs>

                  {/* Horizontal gridlines */}
                  {[0, 0.25, 0.5, 0.75, 1].map((ratio) => {
                    const y = 35 + ratio * (240 - 70)
                    const gridVal = Math.round(svgChartPath.maxValue * (1 - ratio))
                    return (
                      <g key={ratio} className="opacity-40">
                        <line x1="35" y1={y} x2="765" y2={y} stroke="var(--color-border, #e5e7eb)" strokeDasharray="3 3" />
                        <text x="30" y={y + 3} textAnchor="end" fill="var(--color-text-muted, #9ca3af)" className="text-[9px] font-mono">
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
                  <path d={svgChartPath.profitPath} fill="none" stroke="var(--color-accent, #00b140)" strokeWidth="2" strokeLinecap="round" />

                  {/* Date labels at bottom */}
                  {svgChartPath.points.map((p, i) => {
                    // Only show every few dates to avoid overlap
                    const showLabel = svgChartPath.points.length <= 10 || i % Math.ceil(svgChartPath.points.length / 8) === 0
                    if (!showLabel) return null
                    
                    const datePart = p.label.split('-')[2]
                    const monthPart = new Date(p.label).toLocaleDateString('en-US', { month: 'short' })
                    
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
                      <circle cx={p.x} cy={p.yProfit} r="3.5" fill="var(--color-accent, #00b140)" className="hover:r-5 transition-all" />
                    </g>
                  ))}
                </svg>
              </div>
            </div>
          ) : (
            <div className="bg-card border border-border p-10 rounded-2xl shadow-sm text-center text-xs text-text-secondary">
              Not enough daily data points to plot the sales visual trend chart.
            </div>
          )}

          {/* Breakdown Tables (Categories vs. Products) */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            
            {/* Category Performance Breakdown */}
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
              <div className="flex items-center gap-2 border-b border-border/60 pb-3">
                <Layers className="h-5 w-5 text-accent" />
                <div>
                  <h4 className="text-sm font-bold text-text-primary">Sales by Category</h4>
                  <p className="text-[10px] text-text-muted">Division of sales revenues and margin percentage per category.</p>
                </div>
              </div>

              <div className="divide-y divide-border/60 max-h-80 overflow-y-auto pr-1">
                {categorySales.map((cat) => {
                  const percentOfTotal = Math.round((cat.sales / (summary.totalSales || 1)) * 100)
                  const categoryMargin = cat.sales > 0 ? Math.round((cat.profit / cat.sales) * 100) : 0
                  
                  return (
                    <div key={cat.categoryName} className="py-3 space-y-2">
                      <div className="flex justify-between items-center text-xs">
                        <span className="font-semibold text-text-primary">{cat.categoryName}</span>
                        <div className="text-right space-x-3">
                          <strong className="text-text-primary">{formatPrice(cat.sales)}</strong>
                          <span className="text-[10px] text-accent font-bold bg-accent/15 px-1.5 py-0.5 rounded border border-accent/10">
                            {categoryMargin}% margin
                          </span>
                        </div>
                      </div>
                      <div className="h-2 w-full bg-muted rounded-full overflow-hidden flex">
                        <div 
                          className="h-full rounded-full bg-primary" 
                          style={{ width: `${percentOfTotal}%` }} 
                        />
                      </div>
                      <div className="flex justify-between text-[9px] text-text-muted">
                        <span>{percentOfTotal}% of total revenue</span>
                        <span>Net Profit: {formatPrice(cat.profit)}</span>
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>

            {/* Top Selling Products Breakdown */}
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
              <div className="flex items-center gap-2 border-b border-border/60 pb-3">
                <Award className="h-5 w-5 text-accent animate-bounce-slow" />
                <div>
                  <h4 className="text-sm font-bold text-text-primary">Top 10 Selling Products</h4>
                  <p className="text-[10px] text-text-muted">The highest volume and revenue generator items.</p>
                </div>
              </div>

              <div className="overflow-x-auto divide-y divide-border/60 max-h-80 overflow-y-auto pr-1">
                <table className="w-full text-left border-collapse text-xs">
                  <thead>
                    <tr className="text-[10px] font-bold text-text-secondary uppercase tracking-wider">
                      <th className="pb-2">Name</th>
                      <th className="pb-2 text-center">Qty Sold</th>
                      <th className="pb-2 text-right">Revenue</th>
                      <th className="pb-2 text-right">Profit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {topProducts.map((prod) => (
                      <tr key={prod.productId} className="hover:bg-muted/10">
                        <td className="py-2.5 font-semibold text-text-primary truncate max-w-[150px]">{prod.name}</td>
                        <td className="py-2.5 text-center font-bold text-text-secondary">{prod.quantity}</td>
                        <td className="py-2.5 text-right font-bold text-text-primary">{formatPrice(prod.sales)}</td>
                        <td className="py-2.5 text-right font-bold text-accent">{formatPrice(prod.profit)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

          </div>
        </>
      )}

    </div>
  )
}
