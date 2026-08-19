'use client'

import { useState, useEffect, useMemo } from 'react'
import { Calendar, IndianRupee, TrendingUp, ShoppingBag, Percent, RefreshCw, FileSpreadsheet, Download } from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'

interface ChannelMetrics {
  ordersCount: number
  sales: number
  restaurantProfit: number
  adminProfit: number
}

interface Summary {
  totalSales: number
  totalCost: number
  totalDiscount: number
  totalTaxes: number
  totalMisc: number
  netProfit: number
  restaurantProfit: number
  adminProfit: number
  ordersCount: number
  avgOrderValue: number
  commissionRate?: number
  profitShareRate?: number
  lastSettledDate?: string | null
  lastSettledAmount?: number | null
  lastSettledTxnId?: string | null
  delivery?: ChannelMetrics
  pickup?: ChannelMetrics
}

interface DailySale {
  date: string
  sales: number
  profit: number
  orders: number
}

interface TopProduct {
  name: string
  quantity: number
  sales: number
  profit: number
}

export function RestaurantSalesConsole() {
  const [loading, setLoading] = useState(true)
  const [selectedChannel, setSelectedChannel] = useState<'all' | 'delivery' | 'pickup'>('all')
  const [summary, setSummary] = useState<Summary>({
    totalSales: 0,
    totalCost: 0,
    totalDiscount: 0,
    totalTaxes: 0,
    totalMisc: 0,
    netProfit: 0,
    restaurantProfit: 0,
    adminProfit: 0,
    ordersCount: 0,
    avgOrderValue: 0,
    commissionRate: 10,
    profitShareRate: 15,
    delivery: { ordersCount: 0, sales: 0, restaurantProfit: 0, adminProfit: 0 },
    pickup: { ordersCount: 0, sales: 0, restaurantProfit: 0, adminProfit: 0 }
  })
  const [dailySales, setDailySales] = useState<DailySale[]>([])
  const [topProducts, setTopProducts] = useState<TopProduct[]>([])

  // Date range state
  const [rangePreset, setRangePreset] = useState<'today' | 'yesterday' | '7days' | '30days'>('7days')
  const [startDate, setStartDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() - 7)
    return d.toISOString().split('T')[0]
  })
  const [endDate, setEndDate] = useState(() => {
    return new Date().toISOString().split('T')[0]
  })

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

  const fetchReports = async () => {
    setLoading(true)
    try {
      const url = `/api/restaurant/reports?startDate=${startDate}&endDate=${endDate}&t=${Date.now()}`
      const res = await fetch(url)
      if (!res.ok) throw new Error('Failed to load restaurant financials')
      
      const data = await res.json()
      setSummary(data.summary || {})
      setDailySales(data.dailySales || [])
      setTopProducts(data.topProducts || [])
    } catch (err) {
      toast.error('Could not generate restaurant sales reports')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchReports()
  }, [startDate, endDate])

  // Custom SVG line chart generation
  const chartData = useMemo(() => {
    if (dailySales.length < 2) return { salesPath: '', profitPath: '', salesArea: '', profitArea: '', points: [], maxValue: 100 }

    const width = 600
    const height = 180
    const padding = 15
    const chartWidth = width - padding * 2
    const chartHeight = height - padding * 2

    const maxSalesVal = Math.max(...dailySales.map(d => d.sales), 100)
    const maxProfitVal = Math.max(...dailySales.map(d => d.profit), 100)
    const maxValue = Math.max(maxSalesVal, maxProfitVal) * 1.15 // 15% headroom

    const points = dailySales.map((d, index) => {
      const x = padding + (index / (dailySales.length - 1)) * chartWidth
      const ySales = padding + chartHeight - (d.sales / maxValue) * chartHeight
      const yProfit = padding + chartHeight - (d.profit / maxValue) * chartHeight
      return { x, ySales, yProfit, label: d.date, sales: d.sales, profit: d.profit }
    })

    const salesPath = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.ySales}`).join(' ')
    const profitPath = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.yProfit}`).join(' ')

    const salesArea = `${salesPath} L ${points[points.length - 1].x} ${height - padding} L ${points[0].x} ${height - padding} Z`
    const profitArea = `${profitPath} L ${points[points.length - 1].x} ${height - padding} L ${points[0].x} ${height - padding} Z`

    return { salesPath, profitPath, salesArea, profitArea, points, maxValue }
  }, [dailySales])

  const exportToExcel = () => {
    try {
      // Generate CSV content with Excel BOM for UTF-8 compatibility
      let csv = '\uFEFF' // UTF-8 Byte Order Mark for Excel
      
      // Header & Metadata
      csv += 'FASTKIRANA RESTAURANT SALES REPORT\n'
      csv += `Date Range,"${startDate} to ${endDate}"\n`
      csv += `Generated On,"${new Date().toLocaleString()}"\n\n`
      
      // Financial Summary Section
      csv += '--- FINANCIAL SUMMARY ---\n'
      csv += 'Metric,Value (INR)\n'
      csv += `Total Net Sales,₹${(summary.totalSales || 0).toFixed(2)}\n`
      csv += `Restaurant Margin / Net Share,₹${(summary.restaurantProfit || 0).toFixed(2)}\n`
      csv += `FastKirana Admin Commission,₹${(summary.adminProfit || 0).toFixed(2)}\n`
      csv += `Completed Orders Count,${summary.ordersCount || 0}\n`
      csv += `Average Order Value,₹${(summary.avgOrderValue || 0).toFixed(2)}\n`
      csv += `Commission Rate,${summary.commissionRate || 10}%\n`
      csv += `Restaurant Margin Rate,${100 - (summary.commissionRate || 10)}%\n\n`
      
      // Channel Breakdown Section
      csv += '--- FULFILLMENT CHANNEL BREAKDOWN ---\n'
      csv += 'Channel,Orders Count,Gross Sales (INR),Restaurant Share (INR),Admin Commission (INR)\n'
      csv += `Doorstep Delivery,${summary.delivery?.ordersCount || 0},₹${(summary.delivery?.sales || 0).toFixed(2)},₹${(summary.delivery?.restaurantProfit || 0).toFixed(2)},₹${(summary.delivery?.adminProfit || 0).toFixed(2)}\n`
      csv += `Self Pickup / Takeaway,${summary.pickup?.ordersCount || 0},₹${(summary.pickup?.sales || 0).toFixed(2)},₹${(summary.pickup?.restaurantProfit || 0).toFixed(2)},₹${(summary.pickup?.adminProfit || 0).toFixed(2)}\n\n`
      
      // Daily Breakdown Table
      csv += '--- DAILY SALES BREAKDOWN ---\n'
      csv += 'Date,Completed Orders,Net Sales (INR),Restaurant Margin (INR),Admin Commission (INR)\n'
      if (dailySales.length > 0) {
        dailySales.forEach(d => {
          const comm = (d.sales || 0) - (d.profit || 0)
          csv += `"${d.date}",${d.orders},${(d.sales || 0).toFixed(2)},${(d.profit || 0).toFixed(2)},${comm > 0 ? comm.toFixed(2) : '0.00'}\n`
        })
      } else {
        csv += 'No daily sales data available\n'
      }
      csv += '\n'
      
      // Top Dishes Table
      csv += '--- DISHES & ITEMS SOLD ---\n'
      csv += 'Rank,Dish Name,Units Sold,Total Revenue (INR),Restaurant Margin (INR)\n'
      if (topProducts.length > 0) {
        topProducts.forEach((p, idx) => {
          csv += `${idx + 1},"${(p.name || '').replace(/"/g, '""')}",${p.quantity},${(p.sales || 0).toFixed(2)},${(p.profit || 0).toFixed(2)}\n`
        })
      } else {
        csv += 'No product sales recorded in this period\n'
      }

      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `Restaurant_Sales_Report_${startDate}_to_${endDate}.csv`)
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
      
      toast.success('Excel Sheet downloaded successfully!')
    } catch (err) {
      console.error(err)
      toast.error('Failed to export sales Excel sheet')
    }
  }

  return (
    <div className="space-y-6 select-none">
      {/* Analytics Controls */}
      <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4 bg-muted/20 p-5 rounded-3xl border border-border/40">
        <div className="flex bg-muted/40 p-1 rounded-xl border border-border/40 gap-1 overflow-x-auto w-full sm:w-auto">
          {(['today', 'yesterday', '7days', '30days'] as const).map(preset => (
            <button
              key={preset}
              onClick={() => handlePresetChange(preset)}
              className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all uppercase tracking-wider cursor-pointer ${
                rangePreset === preset 
                  ? 'bg-card text-red-600 shadow-sm border border-border/55' 
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              {preset === 'today' && 'Today'}
              {preset === 'yesterday' && 'Yesterday'}
              {preset === '7days' && '7 Days'}
              {preset === '30days' && '30 Days'}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-2 w-full lg:w-auto">
          <Calendar className="h-4 w-4 text-text-muted shrink-0" />
          <input
            type="date"
            value={startDate}
            onChange={(e) => {
              setRangePreset('7days') // Reset preset to clear select states
              setStartDate(e.target.value)
            }}
            className="bg-card border border-border px-3 py-1.5 rounded-xl text-xs font-semibold text-text-primary focus:outline-none w-full sm:w-auto"
          />
          <span className="text-text-muted text-xs font-black">to</span>
          <input
            type="date"
            value={endDate}
            onChange={(e) => {
              setRangePreset('7days')
              setEndDate(e.target.value)
            }}
            className="bg-card border border-border px-3 py-1.5 rounded-xl text-xs font-semibold text-text-primary focus:outline-none w-full sm:w-auto"
          />
          <button
            onClick={fetchReports}
            title="Refresh Report"
            className="p-2 bg-card border border-border hover:bg-muted/40 rounded-xl transition-all cursor-pointer"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
          <button
            onClick={exportToExcel}
            disabled={loading || (summary.ordersCount === 0 && topProducts.length === 0)}
            title="Download Excel Sheet / CSV"
            className="inline-flex items-center gap-1.5 px-3 sm:px-3.5 py-1.5 sm:py-2 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white text-[11px] sm:text-xs font-black rounded-xl transition-all shadow-xs cursor-pointer active:scale-95 shrink-0"
          >
            <FileSpreadsheet className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            <span>Excel Sheet</span>
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3">
          <RefreshCw className="h-8 w-8 text-red-600 animate-spin" />
          <p className="text-xs text-text-secondary font-bold">Generating Sales Reports...</p>
        </div>
      ) : (
        <>
          {/* Last Settlement Status Bar */}
          <div className="flex flex-wrap items-center justify-between gap-3 bg-card border border-border/60 p-3.5 sm:p-4 rounded-2xl sm:rounded-3xl shadow-xs">
            <div className="flex items-center gap-2.5">
              <span className="text-xl">🧾</span>
              <div>
                <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                  Last Settlement Status
                </span>
                <p className="text-xs font-black text-text-primary">
                  {summary.lastSettledDate ? (
                    <span className="text-emerald-600 dark:text-emerald-400">
                      Settled on {new Date(summary.lastSettledDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                      {summary.lastSettledAmount ? ` (${formatPrice(summary.lastSettledAmount)})` : ''}
                    </span>
                  ) : (
                    <span className="text-amber-600 dark:text-amber-400">
                      Pending First Settlement Draft
                    </span>
                  )}
                </p>
              </div>
            </div>

            {summary.lastSettledTxnId && (
              <span className="text-[10px] font-mono font-bold text-text-muted bg-muted/40 px-2.5 py-1 rounded-xl border border-border/40">
                Txn Ref: {summary.lastSettledTxnId}
              </span>
            )}
          </div>

          {/* Summary Cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
            {/* Sales Card */}
            <div className="bg-card border border-border/50 rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 shadow-xs space-y-1.5 sm:space-y-2">
               <div className="flex justify-between items-center gap-1">
                <span className="text-[9px] sm:text-[10px] font-extrabold uppercase tracking-wider text-text-secondary truncate">Net Sales</span>
                 <div className="h-7 w-7 sm:h-8 sm:w-8 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center shrink-0">
                   <IndianRupee className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                 </div>
               </div>
               <h3 className="text-base sm:text-2xl font-black text-text-primary truncate">{formatPrice(summary.totalSales)}</h3>
              <p className="text-[8px] sm:text-[9px] font-bold text-emerald-500">Net Sales</p>
             </div>
 
             {/* Restaurant Margin Card */}
             <div className="bg-card border border-border/50 rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 shadow-xs space-y-1.5 sm:space-y-2">
               <div className="flex justify-between items-center gap-1">
                <span className="text-[9px] sm:text-[10px] font-extrabold uppercase tracking-wider text-text-secondary truncate">Margin ({100 - (summary.commissionRate || 10)}%)</span>
                 <div className="h-7 w-7 sm:h-8 sm:w-8 rounded-lg bg-red-500/10 text-red-500 flex items-center justify-center shrink-0">
                   <Percent className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                 </div>
               </div>
               <h3 className="text-base sm:text-2xl font-black text-text-primary truncate">{formatPrice(summary.restaurantProfit)}</h3>
               <p className="text-[8px] sm:text-[9px] font-bold text-red-500">Net Share</p>
             </div>
 
             {/* Admin Commission Card */}
             <div className="bg-card border border-border/50 rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 shadow-xs space-y-1.5 sm:space-y-2">
               <div className="flex justify-between items-center gap-1">
                <span className="text-[9px] sm:text-[10px] font-extrabold uppercase tracking-wider text-text-secondary truncate">Commission ({summary.commissionRate || 10}%)</span>
                 <div className="h-7 w-7 sm:h-8 sm:w-8 rounded-lg bg-blue-500/10 text-blue-600 flex items-center justify-center shrink-0">
                   <TrendingUp className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                 </div>
               </div>
               <h3 className="text-base sm:text-2xl font-black text-text-primary truncate">{formatPrice(summary.adminProfit)}</h3>
               <p className="text-[8px] sm:text-[9px] font-bold text-blue-500">FastKirana Share</p>
             </div>
 
            {/* Orders Card */}
            <div className="bg-card border border-border/50 rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 shadow-xs space-y-1.5 sm:space-y-2">
              <div className="flex justify-between items-center gap-1">
                <span className="text-[9px] sm:text-[10px] font-extrabold uppercase tracking-wider text-text-secondary truncate">Orders</span>
                <div className="h-7 w-7 sm:h-8 sm:w-8 rounded-lg bg-purple-500/10 text-purple-500 flex items-center justify-center shrink-0">
                  <ShoppingBag className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                </div>
              </div>
              <h3 className="text-base sm:text-2xl font-black text-text-primary truncate">{summary.ordersCount}</h3>
              <p className="text-[8px] sm:text-[9px] font-bold text-purple-500">Completed</p>
            </div>
          </div>

          {/* Fulfillment Channel Comparison (Delivery vs. Pickup) */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Doorstep Delivery Card */}
            <div className="bg-card border border-border/60 rounded-3xl p-5 shadow-xs space-y-3 bg-gradient-to-br from-blue-500/[0.02] to-transparent">
              <div className="flex items-center justify-between border-b border-border/40 pb-2.5">
                <div className="flex items-center gap-2">
                  <span className="text-xl">🛵</span>
                  <div>
                    <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Doorstep Delivery</h4>
                    <p className="text-[10px] text-text-muted font-medium">{summary.delivery?.ordersCount || 0} Orders delivered by fleet</p>
                  </div>
                </div>
                <span className="text-xs font-black text-blue-600 dark:text-blue-400 bg-blue-500/10 px-2.5 py-1 rounded-full border border-blue-500/20">
                  {formatPrice(summary.delivery?.sales || 0)} Sales
                </span>
              </div>

              <div className="grid grid-cols-2 gap-2 text-xs">
                <div className="p-2.5 rounded-2xl bg-muted/40 border border-border/40">
                  <span className="text-[9.5px] font-bold text-text-secondary uppercase block">Restaurant Share</span>
                  <strong className="text-sm font-black text-text-primary mt-0.5 block">
                    {formatPrice(summary.delivery?.restaurantProfit || 0)}
                  </strong>
                </div>
                <div className="p-2.5 rounded-2xl bg-muted/40 border border-border/40">
                  <span className="text-[9.5px] font-bold text-text-secondary uppercase block">FastKirana Commission</span>
                  <strong className="text-sm font-black text-blue-600 dark:text-blue-400 mt-0.5 block">
                    {formatPrice(summary.delivery?.adminProfit || 0)}
                  </strong>
                </div>
              </div>
            </div>

            {/* Self Pickup Card */}
            <div className="bg-card border border-border/60 rounded-3xl p-5 shadow-xs space-y-3 bg-gradient-to-br from-emerald-500/[0.02] to-transparent">
              <div className="flex items-center justify-between border-b border-border/40 pb-2.5">
                <div className="flex items-center gap-2">
                  <span className="text-xl">🛍️</span>
                  <div>
                    <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Self Pickup / Takeaway</h4>
                    <p className="text-[10px] text-text-muted font-medium">{summary.pickup?.ordersCount || 0} Orders picked up at counter</p>
                  </div>
                </div>
                <span className="text-xs font-black text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2.5 py-1 rounded-full border border-emerald-500/20">
                  {formatPrice(summary.pickup?.sales || 0)} Sales
                </span>
              </div>

              <div className="grid grid-cols-2 gap-2 text-xs">
                <div className="p-2.5 rounded-2xl bg-muted/40 border border-border/40">
                  <span className="text-[9.5px] font-bold text-text-secondary uppercase block">Restaurant Share</span>
                  <strong className="text-sm font-black text-text-primary mt-0.5 block">
                    {formatPrice(summary.pickup?.restaurantProfit || 0)}
                  </strong>
                </div>
                <div className="p-2.5 rounded-2xl bg-muted/40 border border-border/40">
                  <span className="text-[9.5px] font-bold text-text-secondary uppercase block">FastKirana Commission</span>
                  <strong className="text-sm font-black text-emerald-600 dark:text-emerald-400 mt-0.5 block">
                    {formatPrice(summary.pickup?.adminProfit || 0)}
                  </strong>
                </div>
              </div>
            </div>
          </div>

          {/* Line Chart & Top Selling Items Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Sales Trend Chart */}
            <div className="lg:col-span-2 bg-card border border-border/55 rounded-3xl p-5 shadow-sm space-y-3 flex flex-col justify-between">
              <div>
                <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Restaurant Sales Trend</h4>
                <p className="text-[10px] text-text-muted mt-0.5">Visualization of daily gross revenue vs profit margin.</p>
              </div>

              {dailySales.length < 2 ? (
                <div className="h-48 flex items-center justify-center text-xs text-text-secondary font-bold bg-muted/10 rounded-2xl border border-dashed border-border/60">
                  Not enough historical data in selected range to generate trendlines.
                </div>
              ) : (
                <div className="w-full overflow-x-auto scrollbar-none">
                  <svg viewBox="0 0 600 180" className="w-full min-w-[500px] h-auto overflow-visible select-none">
                    <defs>
                      <linearGradient id="salesGrad" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#10b981" stopOpacity="0.18" />
                        <stop offset="100%" stopColor="#10b981" stopOpacity="0" />
                      </linearGradient>
                      <linearGradient id="profitGrad" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#ef4444" stopOpacity="0.18" />
                        <stop offset="100%" stopColor="#ef4444" stopOpacity="0" />
                      </linearGradient>
                    </defs>

                    {/* Area Gradients */}
                    <path d={chartData.salesArea} fill="url(#salesGrad)" />
                    <path d={chartData.profitArea} fill="url(#profitGrad)" />

                    {/* Line Paths */}
                    <path d={chartData.salesPath} fill="none" stroke="#10b981" strokeWidth="2.5" strokeLinecap="round" />
                    <path d={chartData.profitPath} fill="none" stroke="#ef4444" strokeWidth="2.5" strokeLinecap="round" />

                    {/* Interactive Points / Tooltips */}
                    {chartData.points.map((pt, i) => (
                      <g key={i} className="group cursor-pointer">
                        <circle cx={pt.x} cy={pt.ySales} r="4" fill="#10b981" className="transition-transform group-hover:scale-150" />
                        <circle cx={pt.x} cy={pt.yProfit} r="4" fill="#ef4444" className="transition-transform group-hover:scale-150" />
                        <text
                          x={pt.x}
                          y="175"
                          textAnchor="middle"
                          fill="#888"
                          fontSize="7"
                          fontWeight="bold"
                        >
                          {pt.label}
                        </text>
                      </g>
                    ))}
                  </svg>
                </div>
              )}

              {/* Legend */}
              <div className="flex gap-4 text-[9px] font-extrabold uppercase tracking-wider text-text-secondary border-t border-border/30 pt-3">
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded bg-emerald-500 block" /> Gross Sales</span>
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded bg-rose-500 block" /> Net Profit</span>
              </div>
            </div>

            {/* Dishes & Items Sold */}
            <div className="bg-card border border-border/55 rounded-3xl p-5 shadow-sm space-y-4 flex flex-col justify-between">
              <div>
                <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Dishes &amp; Items Sold</h4>
                <p className="text-[10px] text-text-muted mt-0.5">All items sold in this date range.</p>
              </div>

              {topProducts.length === 0 ? (
                <div className="h-48 flex items-center justify-center text-xs text-text-secondary font-bold bg-muted/10 rounded-2xl border border-dashed border-border/60">
                  No products sold in this date range.
                </div>
              ) : (
                <div className="space-y-3 flex-1 pt-2 max-h-96 overflow-y-auto pr-1">
                  {topProducts.map((p, idx) => (
                    <div key={idx} className="flex justify-between items-center text-xs font-semibold border-b border-border/30 pb-2">
                      <div className="truncate pr-4 flex-1">
                        <p className="text-text-primary font-bold truncate">{p.name}</p>
                        <p className="text-[9px] text-text-muted font-bold uppercase">{p.quantity} Units Sold</p>
                      </div>
                      <div className="text-right">
                        <p className="text-text-primary font-black">{formatPrice(p.sales)}</p>
                        <p className="text-[9px] text-red-500 font-bold uppercase">Restaurant Margin: {formatPrice(p.profit)}</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
