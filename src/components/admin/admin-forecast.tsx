'use client'

import { useState, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { 
  TrendingUp, 
  AlertTriangle, 
  Sparkles, 
  Package, 
  Calendar, 
  IndianRupee, 
  Search, 
  Building2, 
  CheckCircle, 
  Loader2, 
  BrainCircuit, 
  ShoppingBag,
  ArrowRight,
  RefreshCw,
  Plus
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'

interface ForecastItem {
  id: string
  name: string
  slug: string
  imageUrl: string | null
  stock: number
  minStock: number
  costPrice: number
  price: number
  category: {
    id: string
    name: string
    slug: string
  }
  salesVelocity: number
  weekdayVelocity: number
  weekendVelocity: number
  weekendBoost: number
  daysRemaining: number
  recommendedReorder: number
  reorderByDay: string
  suggestion: string
  isAtRisk: boolean
  revenueAtRisk: number
}

interface AdminForecastProps {
  onRestockCompleted?: () => void
  categories: Array<{ id: string; name: string; slug: string }>
}

export function AdminForecast({ onRestockCompleted, categories }: AdminForecastProps) {
  const [forecastList, setForecastList] = useState<ForecastItem[]>([])
  const [metrics, setMetrics] = useState({ itemsAtRisk: 0, totalRevenueAtRisk: 0, averageVelocity: 0 })
  const [loading, setLoading] = useState(true)
  const [restocking, setRestocking] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('ALL')

  const fetchForecast = async (showToast = false) => {
    try {
      setLoading(true)
      const res = await fetch('/api/admin/forecast')
      if (!res.ok) throw new Error('Failed to fetch forecast analytics')
      const data = await res.json()
      setForecastList(data.forecast || [])
      setMetrics(data.metrics || { itemsAtRisk: 0, totalRevenueAtRisk: 0, averageVelocity: 0 })
      if (showToast) {
        toast.success('AI demand forecast models recalculated!')
      }
    } catch (err) {
      console.error(err)
      toast.error('Could not compute sales forecasting models')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchForecast()
  }, [])

  // Auto-replenish all at-risk products
  const handleAutoReplenish = async () => {
    triggerHaptic('medium')
    const atRiskItems = forecastList.filter(f => f.isAtRisk && f.recommendedReorder > 0)
    if (atRiskItems.length === 0) {
      toast.info('No products require replenishing at this time.')
      return
    }

    try {
      setRestocking(true)
      toast.loading(`Auto-generating stock batches for ${atRiskItems.length} items...`, { id: 'replenish-loader' })

      let completedCount = 0
      let totalStockAdded = 0

      // RESTOCK: Loop over all at-risk products and post to Inward API
      for (const item of atRiskItems) {
        const today = new Date().toISOString().split('T')[0].replace(/-/g, '')
        const rand = Math.random().toString(36).slice(2, 6).toUpperCase()
        const batchCode = `AUTO_AI_${today}_${rand}`
        const expiryDate = new Date()
        expiryDate.setMonth(expiryDate.getMonth() + 6) // Standard 6-month expiry fallback

        const res = await fetch('/api/admin/inward', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            productId: item.id,
            batchCode,
            quantity: item.recommendedReorder,
            costPrice: item.costPrice,
            expiryDate: expiryDate.toISOString()
          })
        })

        if (res.ok) {
          completedCount++
          totalStockAdded += item.recommendedReorder
        }
      }

      toast.success(`🎉 Auto-restocked ${completedCount} items! Inwarded ${totalStockAdded} units to store inventory.`, {
        id: 'replenish-loader'
      })

      // Refresh data
      await fetchForecast()
      if (onRestockCompleted) {
        onRestockCompleted()
      }
    } catch (err) {
      console.error('Replenishing failed:', err)
      toast.error('Failed to auto-restock all items', { id: 'replenish-loader' })
    } finally {
      setRestocking(false)
    }
  }

  // Filter list based on search and category
  const filteredList = useMemo(() => {
    return forecastList.filter((f) => {
      const matchesSearch = f.name.toLowerCase().includes(searchQuery.toLowerCase())
      const matchesCategory = selectedCategory === 'ALL' || f.category.id === selectedCategory
      return matchesSearch && matchesCategory
    })
  }, [forecastList, searchQuery, selectedCategory])

  // Get items with high weekend demand
  const weekendSurgeItems = useMemo(() => {
    return forecastList
      .filter((f) => f.weekendBoost > 1.25)
      .slice(0, 4)
  }, [forecastList])

  return (
    <div className="space-y-6">
      
      {/* Page Title & Reload */}
      <div className="flex justify-between items-center bg-muted/20 p-4 rounded-2xl border border-border/40">
        <div className="flex items-center gap-2.5">
          <div className="h-10 w-10 bg-primary/10 rounded-xl flex items-center justify-center text-primary border border-primary/20">
            <BrainCircuit className="h-5.5 w-5.5" />
          </div>
          <div>
            <h3 className="text-sm font-extrabold text-text-primary flex items-center gap-1.5">
              AI-Driven Demand Forecasting
              <Sparkles className="h-4 w-4 text-amber-500 fill-amber-500/20" />
            </h3>
            <p className="text-[10px] text-text-secondary leading-snug font-semibold mt-0.5">
              Predict stock depletion timelines and auto-generate inward replenishment sheets.
            </p>
          </div>
        </div>
        <button
          onClick={() => {
            triggerHaptic('light')
            fetchForecast(true)
          }}
          disabled={loading}
          className="h-9 w-9 bg-card hover:bg-muted/40 border border-border text-text-secondary rounded-xl flex items-center justify-center transition-colors cursor-pointer"
          title="Recalculate models"
        >
          {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
        </button>
      </div>

      {/* Analytics KPI Row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Metric 1 */}
        <div className="bg-card border border-border/60 p-5 rounded-2xl flex items-center gap-4 shadow-sm relative overflow-hidden">
          <div className="absolute top-0 right-0 -mr-6 -mt-6 h-16 w-16 bg-rose-500/5 rounded-full blur-lg" />
          <div className="h-11 w-11 bg-rose-500/10 text-rose-600 rounded-xl flex items-center justify-center shrink-0 border border-rose-500/20">
            <AlertTriangle className="h-5.5 w-5.5" />
          </div>
          <div>
            <span className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider block">Items at Risk</span>
            <span className="text-xl font-black text-rose-600 mt-1 block">
              {loading ? <Loader2 className="h-5 w-5 animate-spin text-rose-500" /> : metrics.itemsAtRisk}
            </span>
          </div>
        </div>

        {/* Metric 2 */}
        <div className="bg-card border border-border/60 p-5 rounded-2xl flex items-center gap-4 shadow-sm relative overflow-hidden">
          <div className="absolute top-0 right-0 -mr-6 -mt-6 h-16 w-16 bg-amber-500/5 rounded-full blur-lg" />
          <div className="h-11 w-11 bg-amber-500/10 text-amber-600 rounded-xl flex items-center justify-center shrink-0 border border-amber-500/20">
            <IndianRupee className="h-5.5 w-5.5" />
          </div>
          <div>
            <span className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider block">Revenue At Risk</span>
            <span className="text-xl font-black text-text-primary mt-1 block">
              {loading ? <Loader2 className="h-5 w-5 animate-spin text-amber-500" /> : formatPrice(metrics.totalRevenueAtRisk)}
            </span>
          </div>
        </div>

        {/* Metric 3 */}
        <div className="bg-card border border-border/60 p-5 rounded-2xl flex items-center gap-4 shadow-sm relative overflow-hidden">
          <div className="absolute top-0 right-0 -mr-6 -mt-6 h-16 w-16 bg-emerald-500/5 rounded-full blur-lg" />
          <div className="h-11 w-11 bg-emerald-500/10 text-emerald-600 rounded-xl flex items-center justify-center shrink-0 border border-emerald-500/20">
            <TrendingUp className="h-5.5 w-5.5" />
          </div>
          <div>
            <span className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider block">Avg Daily Velocity</span>
            <span className="text-xl font-black text-text-primary mt-1 block">
              {loading ? <Loader2 className="h-5 w-5 animate-spin text-emerald-500" /> : `${metrics.averageVelocity} units / day`}
            </span>
          </div>
        </div>
      </div>

      {/* Main Forecast Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Left 2 Columns: Reorder alerts & auto-inward actions */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* Reorder Alerts Pane */}
          <div className="bg-card border border-border rounded-2xl p-5 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-3 border-b border-border/60 pb-3">
              <div>
                <h4 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
                  <Package className="h-4 w-4 text-primary" />
                  Auto-Generated Reorder Recommendations
                </h4>
                <p className="text-[10px] text-text-secondary leading-snug font-semibold mt-0.5">
                  Calculated based on average sales velocity over the past 30 days.
                </p>
              </div>

              {metrics.itemsAtRisk > 0 && (
                <button
                  onClick={handleAutoReplenish}
                  disabled={restocking || loading}
                  className="h-9 px-4 bg-primary hover:bg-primary/95 text-white font-extrabold text-[10.5px] rounded-xl flex items-center justify-center gap-1.5 transition-all shadow-md active:scale-98 cursor-pointer disabled:opacity-70 disabled:cursor-not-allowed shrink-0"
                >
                  {restocking ? (
                    <>
                      <Loader2 size={12} className="animate-spin" />
                      Auto-Replenishing...
                    </>
                  ) : (
                    <>
                      <Building2 size={12} />
                      Auto-Replenish Batches
                    </>
                  )}
                </button>
              )}
            </div>

            {loading ? (
              <div className="flex flex-col items-center justify-center py-12 text-text-secondary">
                <Loader2 className="h-8 w-8 animate-spin text-primary mb-2" />
                <p className="text-xs font-extrabold">Analyzing order history and sales velocities...</p>
              </div>
            ) : forecastList.filter(f => f.isAtRisk).length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 text-center border-2 border-dashed border-border/60 rounded-xl bg-muted/10">
                <CheckCircle className="h-8 w-8 text-emerald-600 mb-2" />
                <h5 className="text-xs font-extrabold text-text-primary">All Stock Levels Healthy</h5>
                <p className="text-[10px] text-text-secondary font-semibold mt-0.5">No products require reordering.</p>
              </div>
            ) : (
              <div className="grid gap-3.5 max-h-[360px] overflow-y-auto pr-1">
                {forecastList.filter(f => f.isAtRisk).map((item) => (
                  <div key={item.id} className="flex items-start justify-between gap-4 p-3 bg-muted/20 border border-border/50 rounded-xl hover:bg-muted/40 transition-colors">
                    <div className="flex gap-3 min-w-0">
                      {item.imageUrl ? (
                        <div className="h-10 w-10 rounded-lg overflow-hidden border border-border bg-card shrink-0">
                          <img src={item.imageUrl} alt={item.name} className="object-cover h-full w-full" />
                        </div>
                      ) : (
                        <div className="h-10 w-10 bg-primary/10 rounded-lg flex items-center justify-center text-primary shrink-0 border border-primary/20">
                          <Package size={16} />
                        </div>
                      )}
                      <div className="min-w-0">
                        <h5 className="text-xs font-extrabold text-text-primary truncate">{item.name}</h5>
                        <p className="text-[10px] text-text-secondary mt-0.5 leading-relaxed font-semibold">
                          {item.suggestion}
                        </p>
                      </div>
                    </div>

                    <div className="text-right shrink-0">
                      <span className="text-[10.5px] font-black text-rose-600 block">
                        {item.stock === 0 ? 'Out of Stock' : `${item.daysRemaining} days left`}
                      </span>
                      <span className="text-[9px] text-text-muted mt-1 block font-bold">
                        Stock: {item.stock} / Min: {item.minStock}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Right 1 Column: Weekend sales surge analytics */}
        <div className="space-y-6">
          <div className="bg-card border border-border rounded-2xl p-5 shadow-sm space-y-4">
            <div>
              <h4 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
                <TrendingUp className="h-4 w-4 text-emerald-650" />
                Weekend Sales Surge
              </h4>
              <p className="text-[10px] text-text-secondary leading-snug font-semibold mt-0.5">
                High sales velocity items on Friday-Sunday.
              </p>
            </div>

            {loading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-5 w-5 animate-spin text-primary" />
              </div>
            ) : weekendSurgeItems.length === 0 ? (
              <p className="text-[10px] text-text-muted font-bold text-center py-6">No significant weekend surges identified.</p>
            ) : (
              <div className="space-y-3.5">
                {weekendSurgeItems.map((item) => (
                  <div key={item.id} className="space-y-1.5">
                    <div className="flex justify-between items-center text-[10.5px]">
                      <span className="font-extrabold text-text-primary truncate max-w-[140px]">{item.name}</span>
                      <span className="font-black text-emerald-600 bg-emerald-500/10 px-1.5 py-0.5 rounded text-[9px] border border-emerald-500/25">
                        +{Math.round((item.weekendBoost - 1) * 100)}% Surge
                      </span>
                    </div>
                    {/* Visual Comparison Progress Bars */}
                    <div className="space-y-1">
                      <div className="flex justify-between items-center text-[8px] text-text-muted font-bold">
                        <span>Weekday Avg: {item.weekdayVelocity} / day</span>
                        <span>Weekend Avg: {item.weekendVelocity} / day</span>
                      </div>
                      <div className="h-2 w-full bg-muted rounded-full overflow-hidden flex gap-0.5">
                        <div 
                          className="h-full bg-primary/40 rounded-l-full" 
                          style={{ width: `${Math.min(100, (item.weekdayVelocity / Math.max(1, item.weekendVelocity)) * 100)}%` }} 
                        />
                        <div 
                          className="h-full bg-emerald-500 rounded-r-full" 
                          style={{ width: `${Math.min(100, ((item.weekendVelocity - item.weekdayVelocity) / Math.max(1, item.weekendVelocity)) * 100)}%` }} 
                        />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

      </div>

      {/* Velocity and Forecasting Table */}
      <div className="bg-card border border-border rounded-2xl p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-4">
          <div>
            <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">
              Velocity & Depletion Table
            </h4>
            <p className="text-[10px] text-text-secondary mt-0.5 font-semibold">
              Live stock levels mapped against 30-day sales trajectories.
            </p>
          </div>

          {/* Table Filters */}
          <div className="flex items-center gap-3 shrink-0">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted" />
              <input
                type="text"
                placeholder="Search products..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-8.5 pr-4 h-9 border border-border bg-card rounded-xl text-xs font-semibold focus:outline-none focus:border-primary w-48 sm:w-56"
              />
            </div>
            
            <select
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
              className="h-9 border border-border bg-card rounded-xl px-3 text-xs font-bold focus:outline-none focus:border-primary"
            >
              <option value="ALL">All Categories</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Forecast Table */}
        <div className="overflow-x-auto border border-border/60 rounded-xl">
          <table className="w-full border-collapse text-left text-xs font-semibold text-text-primary">
            <thead>
              <tr className="border-b border-border/60 bg-muted/30 text-[10.5px] font-black text-text-secondary uppercase tracking-wider">
                <th className="p-3">Product</th>
                <th className="p-3">Category</th>
                <th className="p-3 text-center">Stock</th>
                <th className="p-3 text-center">Daily Velocity</th>
                <th className="p-3 text-center">Weekend Surge</th>
                <th className="p-3 text-center">Est. Remaining</th>
                <th className="p-3 text-right">Reorder Qty</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-text-secondary">
                    <Loader2 className="h-6 w-6 animate-spin text-primary mx-auto mb-2" />
                    Generating forecasting records...
                  </td>
                </tr>
              ) : filteredList.length === 0 ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-text-muted font-bold">
                    No matching products found.
                  </td>
                </tr>
              ) : (
                filteredList.map((item) => (
                  <tr 
                    key={item.id} 
                    className={`border-b border-border/40 last:border-none transition-colors hover:bg-muted/10 ${
                      item.isAtRisk ? 'bg-rose-500/[0.02]' : ''
                    }`}
                  >
                    <td className="p-3 min-w-[180px]">
                      <div className="flex items-center gap-3">
                        {item.imageUrl ? (
                          <div className="h-8 w-8 rounded-lg overflow-hidden border border-border shrink-0 bg-card">
                            <img src={item.imageUrl} alt={item.name} className="object-cover h-full w-full" />
                          </div>
                        ) : (
                          <div className="h-8 w-8 bg-primary/10 rounded-lg flex items-center justify-center text-primary shrink-0 border border-primary/20">
                            <Package size={14} />
                          </div>
                        )}
                        <span className="font-extrabold truncate max-w-[180px]">{item.name}</span>
                      </div>
                    </td>
                    <td className="p-3 font-semibold text-text-secondary">{item.category.name}</td>
                    <td className="p-3 text-center font-bold">
                      <span className={item.stock <= item.minStock ? 'text-rose-600 font-extrabold' : ''}>
                        {item.stock}
                      </span>
                      <span className="text-[9px] text-text-muted ml-1 font-bold">/ {item.minStock}</span>
                    </td>
                    <td className="p-3 text-center font-bold">{item.salesVelocity} / day</td>
                    <td className="p-3 text-center">
                      {item.weekendBoost > 1.25 ? (
                        <span className="text-emerald-650 font-black text-[10px] bg-emerald-500/10 px-1.5 py-0.5 rounded border border-emerald-500/25">
                          {item.weekendBoost}x
                        </span>
                      ) : (
                        <span className="text-text-muted text-[10px]">{item.weekendBoost}x</span>
                      )}
                    </td>
                    <td className="p-3 text-center font-bold">
                      {item.daysRemaining === 999 ? (
                        <span className="text-text-muted">—</span>
                      ) : (
                        <span 
                          className={
                            item.daysRemaining <= 2 
                              ? 'text-rose-600 font-extrabold animate-pulse' 
                              : item.daysRemaining <= 5 
                              ? 'text-amber-600 font-extrabold' 
                              : 'text-text-primary'
                          }
                        >
                          {item.daysRemaining} {item.daysRemaining === 1 ? 'day' : 'days'}
                        </span>
                      )}
                    </td>
                    <td className="p-3 text-right">
                      {item.recommendedReorder > 0 ? (
                        <span className="text-rose-600 font-black text-[11px] bg-rose-500/10 px-2 py-0.75 rounded-lg border border-rose-500/20">
                          +{item.recommendedReorder}
                        </span>
                      ) : (
                        <span className="text-text-muted">—</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

    </div>
  )
}
