'use client'

import { useState, useEffect, useMemo } from 'react'
import { Calendar, IndianRupee, TrendingUp, ShoppingBag, Percent, RefreshCw } from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'

interface Summary {
  totalSales: number
  totalCost: number
  totalDiscount: number
  totalTaxes: number
  totalMisc: number
  cafeProfit: number
  adminProfit: number
  netProfit: number
  ordersCount: number
  avgOrderValue: number
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

export function CafeSalesConsole() {
  const [loading, setLoading] = useState(true)
  const [summary, setSummary] = useState<Summary>({
    totalSales: 0,
    totalCost: 0,
    totalDiscount: 0,
    totalTaxes: 0,
    totalMisc: 0,
    cafeProfit: 0,
    adminProfit: 0,
    netProfit: 0,
    ordersCount: 0,
    avgOrderValue: 0
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
      const url = `/api/cafe/reports?startDate=${startDate}&endDate=${endDate}`
      const res = await fetch(url)
      if (!res.ok) throw new Error('Failed to load cafe financials')
      
      const data = await res.json()
      setSummary(data.summary || {})
      setDailySales(data.dailySales || [])
      setTopProducts(data.topProducts || [])
    } catch (err) {
      toast.error('Could not generate cafe sales reports')
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
                  ? 'bg-card text-orange-600 shadow-sm border border-border/55' 
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

        <div className="flex items-center gap-2 w-full lg:w-auto">
          <Calendar className="h-4 w-4 text-text-muted shrink-0" />
          <input
            type="date"
            value={startDate}
            onChange={(e) => {
              setRangePreset('7days')
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
            className="p-2 bg-card border border-border hover:bg-muted/40 rounded-xl transition-all cursor-pointer"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3">
          <RefreshCw className="h-8 w-8 text-orange-500 animate-spin" />
          <p className="text-xs text-text-secondary font-bold">Generating Cafe Sales Reports...</p>
        </div>
      ) : (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
            {/* Sales Card */}
            <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Gross Revenue</span>
                <div className="h-8 w-8 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center shadow-inner">
                  <IndianRupee className="h-4 w-4" />
                </div>
              </div>
              <h3 className="text-lg sm:text-2xl font-black text-text-primary">{formatPrice(summary.totalSales)}</h3>
              <p className="text-[9px] font-bold text-emerald-500">Collected Sales</p>
            </div>

            {/* Uska Profit Card */}
            <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Uska Profit (Cafe Share)</span>
                <div className="h-8 w-8 rounded-lg bg-rose-500/10 text-rose-600 flex items-center justify-center shadow-inner">
                  <Percent className="h-4 w-4" />
                </div>
              </div>
              <h3 className="text-lg sm:text-2xl font-black text-text-primary">{formatPrice(summary.cafeProfit)}</h3>
              <p className="text-[9px] font-bold text-rose-500">Cafe Net Profit Share</p>
            </div>

            {/* Mera Profit Card */}
            <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Mera Profit (Admin)</span>
                <div className="h-8 w-8 rounded-lg bg-orange-500/10 text-orange-600 flex items-center justify-center shadow-inner">
                  <Percent className="h-4 w-4" />
                </div>
              </div>
              <h3 className="text-lg sm:text-2xl font-black text-text-primary">{formatPrice(summary.adminProfit)}</h3>
              <p className="text-[9px] font-bold text-orange-500">Admin Commission</p>
            </div>

            {/* Orders Card */}
            <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Total Orders</span>
                <div className="h-8 w-8 rounded-lg bg-blue-500/10 text-blue-600 flex items-center justify-center shadow-inner">
                  <ShoppingBag className="h-4 w-4" />
                </div>
              </div>
              <h3 className="text-lg sm:text-2xl font-black text-text-primary">{summary.ordersCount}</h3>
              <p className="text-[9px] font-bold text-blue-500">Completed Orders</p>
            </div>

            {/* AOV Card */}
            <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Avg Order Value</span>
                <div className="h-8 w-8 rounded-lg bg-amber-500/10 text-amber-600 flex items-center justify-center shadow-inner">
                  <TrendingUp className="h-4 w-4" />
                </div>
              </div>
              <h3 className="text-lg sm:text-2xl font-black text-text-primary">{formatPrice(summary.avgOrderValue)}</h3>
              <p className="text-[9px] font-bold text-amber-500">Order Ticket Average</p>
            </div>
          </div>

          {/* Line Chart & Top Selling Items Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Sales Trend Chart */}
            <div className="lg:col-span-2 bg-card border border-border/55 rounded-3xl p-5 shadow-sm space-y-3 flex flex-col justify-between">
              <div>
                <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Cafe Sales Trend</h4>
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
                        <stop offset="0%" stopColor="#f97316" stopOpacity="0.18" />
                        <stop offset="100%" stopColor="#f97316" stopOpacity="0" />
                      </linearGradient>
                    </defs>

                    {/* Area Gradients */}
                    <path d={chartData.salesArea} fill="url(#salesGrad)" />
                    <path d={chartData.profitArea} fill="url(#profitGrad)" />

                    {/* Line Paths */}
                    <path d={chartData.salesPath} fill="none" stroke="#10b981" strokeWidth="2.5" strokeLinecap="round" />
                    <path d={chartData.profitPath} fill="none" stroke="#f97316" strokeWidth="2.5" strokeLinecap="round" />

                    {/* Interactive Points / Tooltips */}
                    {chartData.points.map((pt, i) => (
                      <g key={i} className="group cursor-pointer">
                        <circle cx={pt.x} cy={pt.ySales} r="4" fill="#10b981" className="transition-transform group-hover:scale-150" />
                        <circle cx={pt.x} cy={pt.yProfit} r="4" fill="#f97316" className="transition-transform group-hover:scale-150" />
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
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded bg-orange-550 block" /> Net Profit</span>
              </div>
            </div>

            {/* Top Products */}
            <div className="bg-card border border-border/55 rounded-3xl p-5 shadow-sm space-y-4 flex flex-col justify-between">
              <div>
                <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">Top Selling Cafe Items</h4>
                <p className="text-[10px] text-text-muted mt-0.5">Most ordered cafe snacks &amp; brews.</p>
              </div>

              {topProducts.length === 0 ? (
                <div className="h-48 flex items-center justify-center text-xs text-text-secondary font-bold bg-muted/10 rounded-2xl border border-dashed border-border/60">
                  No products sold in this date range.
                </div>
              ) : (
                <div className="space-y-3 flex-1 pt-2">
                  {topProducts.map((p, idx) => (
                    <div key={idx} className="flex justify-between items-center text-xs font-semibold border-b border-border/30 pb-2">
                      <div className="truncate pr-4 flex-1">
                        <p className="text-text-primary font-bold truncate">{p.name}</p>
                        <p className="text-[9px] text-text-muted font-bold uppercase">{p.quantity} Units Sold</p>
                      </div>
                      <div className="text-right">
                        <p className="text-text-primary font-black">{formatPrice(p.sales)}</p>
                        <p className="text-[9px] text-orange-500 font-bold uppercase">Profit: {formatPrice(p.profit)}</p>
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
