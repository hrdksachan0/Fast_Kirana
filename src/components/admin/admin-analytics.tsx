'use client'

import { useState, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'
import { 
  TrendingUp, 
  TrendingDown, 
  AlertTriangle, 
  Package, 
  IndianRupee, 
  ShoppingBag, 
  Activity,
  ArrowRight,
  Sparkles,
  PieChart
} from 'lucide-react'

interface Product {
  id: string
  name: string
  price: number
  mrp: number
  costPrice: number
  stock: number
  minStock: number
  expiryDate: string | null
  isAvailable: boolean
  tags?: string[]
  category: {
    id: string
    name: string
    slug: string
  }
}

interface Order {
  id: string
  total: number
  createdAt: string
  status: string
}

interface Category {
  id: string
  name: string
  _count: {
    products: number
  }
}

interface AdminAnalyticsProps {
  products: Product[]
  orders: Order[]
  categories: Category[]
  stats: {
    revenue: number
    orderCount: number
    lowStockCount: number
  }
}

export function AdminAnalytics({ products, orders, categories, stats }: AdminAnalyticsProps) {
  const [forecast, setForecast] = useState<any[]>([])
  const [loadingForecast, setLoadingForecast] = useState(true)
  const [inwardingId, setInwardingId] = useState<string | null>(null)

  const fetchForecast = async () => {
    try {
      setLoadingForecast(true)
      const res = await fetch('/api/admin/inventory/forecast')
      if (res.ok) {
        const data = await res.json()
        setForecast(data.forecast || [])
      }
    } catch (err) {
      console.error('Failed to fetch forecast:', err)
    } finally {
      setLoadingForecast(false)
    }
  }

  useEffect(() => {
    fetchForecast()
  }, [])

  const handleQuickRestock = async (product: any) => {
    if (product.suggestedRestock <= 0) return
    try {
      setInwardingId(product.id)
      const res = await fetch('/api/admin/inward', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          productId: product.id,
          batchCode: `AUTO_AI_${Date.now().toString().slice(-6)}`,
          quantity: product.suggestedRestock,
          costPrice: product.costPrice,
          expiryDate: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
        })
      })

      if (res.ok) {
        toast.success(`Successfully replenishment inwarded for ${product.name}!`)
        fetchForecast()
        // Reload products view
        window.location.reload()
      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to replenish stock')
      }
    } catch (err) {
      console.error(err)
      toast.error('Network error during quick restock')
    } finally {
      setInwardingId(null)
    }
  }

  // 1. Calculate general inventory metrics separately for Grocery and Cafe
  const metrics = useMemo(() => {
    let groceryStockValue = 0
    let groceryCostValue = 0
    let groceryOutOfStock = 0
    let groceryLowStock = 0
    let groceryHealthyStock = 0
    let groceryActiveCount = 0

    let cafeActiveCount = 0

    for (const p of products) {
      if (!p.isAvailable) continue
      const isCafe = p.category?.slug === 'cafe' || p.tags?.some((t: string) => t.toLowerCase() === 'cafe')
      
      if (isCafe) {
        cafeActiveCount++
      } else {
        groceryActiveCount++
        groceryStockValue += p.price * p.stock
        const cost = p.costPrice > 0 ? p.costPrice : p.price * 0.75
        groceryCostValue += cost * p.stock

        if (p.stock === 0) {
          groceryOutOfStock++
        } else if (p.stock <= p.minStock) {
          groceryLowStock++
        } else {
          groceryHealthyStock++
        }
      }
    }

    const groceryProfit = Math.max(0, groceryStockValue - groceryCostValue)
    const groceryMargin = groceryStockValue > 0 ? (groceryProfit / groceryStockValue) * 100 : 0

    return {
      grocery: {
        totalStockValue: groceryStockValue,
        totalCostValue: groceryCostValue,
        potentialProfit: groceryProfit,
        margin: Math.round(groceryMargin * 10) / 10,
        outOfStockCount: groceryOutOfStock,
        lowStockCount: groceryLowStock,
        healthyStockCount: groceryHealthyStock,
        totalActiveProducts: groceryActiveCount,
      },
      cafe: {
        totalActiveProducts: cafeActiveCount,
      }
    }
  }, [products])

  // 2. Group products by category and calculate stock value (skipping Cafe product valuations)
  const categoryMetrics = useMemo(() => {
    const data: Record<string, { name: string; count: number; value: number; lowStock: number }> = {}

    for (const p of products) {
      if (!p.isAvailable) continue
      const isCafe = p.category?.slug === 'cafe' || p.tags?.some((t: string) => t.toLowerCase() === 'cafe')
      const catName = p.category.name
      if (!data[catName]) {
        data[catName] = { name: catName, count: 0, value: 0, lowStock: 0 }
      }
      data[catName].count++
      if (!isCafe) {
        data[catName].value += p.price * p.stock
        if (p.stock <= p.minStock) {
          data[catName].lowStock++
        }
      }
    }

    return Object.values(data).sort((a, b) => b.value - a.value)
  }, [products])

  return (
    <div className="space-y-6">
      
      {/* Grocery Analytics Section Header */}
      <div className="border-b border-border/60 pb-2">
        <h4 className="text-xs font-extrabold text-text-secondary uppercase tracking-wider flex items-center gap-1.5">
          <Package className="h-4.5 w-4.5 text-accent" />
          Grocery Inventory Valuation
        </h4>
      </div>

      {/* Visual Stock Status Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        {/* Inventory Value Card */}
        <div className="relative overflow-hidden bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between group">
          <div className="absolute top-0 right-0 -mt-4 -mr-4 w-24 h-24 bg-accent/5 rounded-full blur-xl group-hover:scale-125 transition-transform" />
          <div className="flex items-start justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">
                Inventory Valuation (Price)
              </span>
              <h3 className="text-2xl font-black text-text-primary">
                {formatPrice(metrics.grocery.totalStockValue)}
              </h3>
            </div>
            <div className="h-10 w-10 rounded-xl bg-accent/10 flex items-center justify-center text-accent">
              <IndianRupee className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-border/60 flex items-center justify-between text-xs text-text-secondary">
            <span>Cost Basis: <strong className="text-text-primary font-bold">{formatPrice(metrics.grocery.totalCostValue)}</strong></span>
            <span className="flex items-center text-accent font-semibold">
              <TrendingUp className="h-3 w-3 mr-0.5" />
              Est. Profit: {formatPrice(metrics.grocery.potentialProfit)}
            </span>
          </div>
        </div>

        {/* Expected Profit Margin Card */}
        <div className="relative overflow-hidden bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between group">
          <div className="absolute top-0 right-0 -mt-4 -mr-4 w-24 h-24 bg-blue-500/5 rounded-full blur-xl group-hover:scale-125 transition-transform" />
          <div className="flex items-start justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">
                Average Markup Margin
              </span>
              <h3 className="text-2xl font-black text-text-primary">
                {metrics.grocery.margin}%
              </h3>
            </div>
            <div className="h-10 w-10 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-500">
              <Activity className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-border/60 text-xs text-text-secondary flex justify-between">
            <span>Active SKU catalog: <strong className="text-text-primary font-bold">{metrics.grocery.totalActiveProducts} items</strong></span>
            <span className="text-blue-500 font-semibold flex items-center">
              <Sparkles className="h-3 w-3 mr-0.5 animate-pulse" />
              Optimal target: 30%
            </span>
          </div>
        </div>

        {/* Stock Health Card */}
        <div className="relative overflow-hidden bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between group">
          <div className="absolute top-0 right-0 -mt-4 -mr-4 w-24 h-24 bg-red-500/5 rounded-full blur-xl group-hover:scale-125 transition-transform" />
          <div className="flex items-start justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">
                Stock Health Index
              </span>
              <div className="flex items-baseline gap-2">
                <h3 className="text-2xl font-black text-text-primary">
                  {Math.round((metrics.grocery.healthyStockCount / (metrics.grocery.totalActiveProducts || 1)) * 100)}%
                </h3>
                <span className="text-xs font-semibold text-text-secondary">Healthy</span>
              </div>
            </div>
            <div className="h-10 w-10 rounded-xl bg-red-500/10 flex items-center justify-center text-red-500">
              <AlertTriangle className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-border/60 text-xs text-text-secondary grid grid-cols-3 gap-1">
            <div className="text-center border-r border-border/60">
              <span className="block text-text-muted text-[9px] uppercase font-bold">Low Stock</span>
              <strong className="text-orange-500 font-extrabold">{metrics.grocery.lowStockCount}</strong>
            </div>
            <div className="text-center border-r border-border/60">
              <span className="block text-text-muted text-[9px] uppercase font-bold">Out of Stock</span>
              <strong className="text-red-500 font-extrabold">{metrics.grocery.outOfStockCount}</strong>
            </div>
            <div className="text-center">
              <span className="block text-text-muted text-[9px] uppercase font-bold">Healthy SKUs</span>
              <strong className="text-accent font-extrabold">{metrics.grocery.healthyStockCount}</strong>
            </div>
          </div>
        </div>

      </div>

      {/* Cafe Analytics Section Header */}
      <div className="border-b border-border/60 pb-2 pt-2">
        <h4 className="text-xs font-extrabold text-rose-500 uppercase tracking-wider flex items-center gap-1.5">
          <span>☕</span>
          Café Kitchen Analytics
        </h4>
      </div>

      {/* Cafe Status Card */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="relative overflow-hidden bg-card border border-rose-500/25 p-6 rounded-2xl shadow-sm flex flex-col justify-between group">
          <div className="absolute top-0 right-0 -mt-4 -mr-4 w-24 h-24 bg-rose-500/5 rounded-full blur-xl group-hover:scale-125 transition-transform" />
          <div className="flex items-start justify-between">
            <div className="space-y-1">
              <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">
                Active Café Products
              </span>
              <h3 className="text-2xl font-black text-text-primary">
                {metrics.cafe.totalActiveProducts} Menu Items
              </h3>
            </div>
            <div className="h-10 w-10 rounded-xl bg-rose-500/10 flex items-center justify-center text-rose-500">
              <Sparkles className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-border/60 text-xs text-text-secondary flex justify-between">
            <span>Stock Strategy: <strong className="text-rose-600 dark:text-rose-400 font-extrabold">Prepared On-Demand</strong></span>
            <span className="text-text-muted italic font-bold">Unlimited Stock</span>
          </div>
        </div>
      </div>

      {/* Visual Charts / Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 pt-2">
        
        {/* Inventory Stock Breakdown by Category */}
        <div className="lg:col-span-2 bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col">
          <div className="flex items-center gap-2 mb-4">
            <PieChart className="h-5 w-5 text-accent" />
            <div>
              <h4 className="text-sm font-bold text-text-primary">Category Stock Distribution</h4>
              <p className="text-[10px] text-text-muted">Total inventory value and alerts count grouped by category.</p>
            </div>
          </div>

          <div className="space-y-4 flex-1">
            {categoryMetrics.slice(0, 6).map((cat) => {
              const isCafeCategory = cat.name.toLowerCase().includes('cafe')
              const percentage = Math.round((cat.value / (metrics.grocery.totalStockValue || 1)) * 100)
              
              return (
                <div key={cat.name} className="space-y-1.5">
                  <div className="flex justify-between items-center text-xs">
                    <span className="font-semibold text-text-primary">{cat.name}</span>
                    <div className="space-x-2 text-right">
                      <span className="text-text-muted">({cat.count} products)</span>
                      {isCafeCategory ? (
                        <strong className="text-rose-600 dark:text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded text-[10px] font-extrabold uppercase">Fresh Prepared</strong>
                      ) : (
                        <>
                          <strong className="text-text-primary">{formatPrice(cat.value)}</strong>
                          <span className="text-text-secondary bg-muted px-1.5 py-0.5 rounded text-[10px] font-bold">{percentage}%</span>
                        </>
                      )}
                    </div>
                  </div>
                  {!isCafeCategory && (
                    <>
                      <div className="h-2 w-full bg-muted rounded-full overflow-hidden flex">
                        <div 
                          className={`h-full rounded-full bg-gradient-to-r ${
                            cat.lowStock > 0 ? 'from-orange-500 to-amber-400' : 'from-accent to-emerald-400'
                          }`}
                          style={{ width: `${percentage}%` }}
                        />
                      </div>
                      {cat.lowStock > 0 && (
                        <span className="text-[10px] text-orange-500 font-semibold flex items-center gap-0.5">
                          <AlertTriangle className="h-3 w-3" /> {cat.lowStock} item(s) low on stock in this category
                        </span>
                      )}
                    </>
                  )}
                </div>
              )
            })}
          </div>
        </div>

        {/* Stock Alerts Overview Quick Card */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between">
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-orange-500" />
              <div>
                <h4 className="text-sm font-bold text-text-primary">Stock Alerts Summary</h4>
                <p className="text-[10px] text-text-muted">Quick breakdown of urgent inventory issues.</p>
              </div>
            </div>

            <div className="space-y-3 pt-2">
              <div className="flex items-center justify-between p-3 rounded-xl bg-red-500/5 border border-red-500/10">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-red-500 animate-ping-slow" />
                  <span className="text-xs font-semibold text-text-primary">Out of Stock items</span>
                </div>
                <strong className="text-sm font-black text-red-500">{metrics.grocery.outOfStockCount}</strong>
              </div>

              <div className="flex items-center justify-between p-3 rounded-xl bg-orange-500/5 border border-orange-500/10">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-orange-500" />
                  <span className="text-xs font-semibold text-text-primary">Low stock items</span>
                </div>
                <strong className="text-sm font-black text-orange-500">{metrics.grocery.lowStockCount}</strong>
              </div>

              <div className="flex items-center justify-between p-3 rounded-xl bg-accent/5 border border-accent/10">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-accent" />
                  <span className="text-xs font-semibold text-text-primary">Healthy stock items</span>
                </div>
                <strong className="text-sm font-black text-accent">{metrics.grocery.healthyStockCount}</strong>
              </div>
            </div>
          </div>

          <div className="pt-4 mt-4 border-t border-border/60">
            <div className="p-3 bg-muted/50 rounded-xl flex items-center justify-between text-xs text-text-secondary hover:text-text-primary transition-colors cursor-pointer group">
              <span>View detailed stock alerts</span>
              <ArrowRight className="h-4 w-4 text-text-muted group-hover:translate-x-1 transition-transform" />
            </div>
          </div>
        </div>

      </div>

      {/* AI Stock Forecasting section */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Sparkles className="h-5 w-5 text-accent animate-pulse" />
            <div>
              <h4 className="text-sm font-bold text-text-primary">AI Stock Depletion & Replenishment Forecast</h4>
              <p className="text-[10px] text-text-muted">Analyzing last 30 days sales velocity to predict stockouts and recommend Purchase Orders.</p>
            </div>
          </div>
          <button 
            onClick={fetchForecast}
            disabled={loadingForecast}
            className="text-[10px] font-extrabold text-accent bg-accent/10 px-3 py-1.5 rounded-lg border border-accent/20 active:bg-accent/20 transition-colors uppercase tracking-wider"
          >
            Refresh Forecast
          </button>
        </div>

        {loadingForecast ? (
          <div className="py-12 flex justify-center items-center gap-2">
            <span className="animate-spin h-5 w-5 border-2 border-accent border-t-transparent rounded-full" />
            <span className="text-xs text-text-secondary font-bold">Calculating sales velocity...</span>
          </div>
        ) : forecast.filter(f => f.isUrgent || f.stock === 0).length === 0 ? (
          <div className="py-10 text-center bg-muted/40 rounded-xl border border-dashed border-border/80">
            <span className="text-2xl">🌱</span>
            <p className="text-xs text-text-secondary font-bold mt-2">All product stock levels healthy. No urgent depletion warnings.</p>
          </div>
        ) : (
          <div className="overflow-x-auto border border-border/60 rounded-xl bg-muted/20">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="bg-muted/80 border-b border-border/65 text-text-secondary font-extrabold uppercase text-[9px] tracking-wider">
                  <th className="p-3">Product</th>
                  <th className="p-3">Category</th>
                  <th className="p-3 text-center">Current Stock</th>
                  <th className="p-3 text-center">Sales Velocity (30d)</th>
                  <th className="p-3 text-center">Days to Runout</th>
                  <th className="p-3 text-center">Recommended Restock</th>
                  <th className="p-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60">
                {forecast.filter(f => !f.isCafe && (f.isUrgent || f.stock === 0)).slice(0, 8).map((product) => {
                  const velocityStr = product.velocity > 0 ? `${product.velocity.toFixed(2)} units/day` : '0 units/day'
                  const runoutStr = product.stock === 0 ? 'Out of Stock' : product.daysToDepletion !== null ? `${product.daysToDepletion.toFixed(1)} days` : 'Infinite'
                  const runoutColor = product.stock === 0 ? 'text-red-500 bg-red-500/10 border-red-500/20 font-black' : product.daysToDepletion !== null && product.daysToDepletion <= 3 ? 'text-orange-500 bg-orange-500/10 border-orange-500/20 font-bold' : 'text-amber-500 bg-amber-500/10 border-amber-500/20'

                  return (
                    <tr key={product.id} className="hover:bg-muted/30 transition-colors">
                      <td className="p-3 font-semibold text-text-primary">{product.name}</td>
                      <td className="p-3 text-text-secondary font-medium">{product.category?.name || 'General'}</td>
                      <td className="p-3 text-center font-bold text-text-primary">
                        <span className={product.stock === 0 ? 'text-red-500 font-extrabold' : product.stock <= product.minStock ? 'text-orange-500' : 'text-text-primary'}>
                          {product.stock}
                        </span>
                        <span className="text-[9px] text-text-muted font-normal block">Min: {product.minStock}</span>
                      </td>
                      <td className="p-3 text-center text-text-secondary font-bold">{velocityStr}</td>
                      <td className="p-3 text-center">
                        <span className={`px-2 py-0.5 rounded-full text-[10px] border ${runoutColor}`}>
                          {runoutStr}
                        </span>
                      </td>
                      <td className="p-3 text-center font-extrabold text-accent">
                        {product.suggestedRestock > 0 ? `+${product.suggestedRestock} units` : 'Healthy'}
                      </td>
                      <td className="p-3 text-right">
                        {product.suggestedRestock > 0 ? (
                          <button
                            onClick={() => handleQuickRestock(product)}
                            disabled={inwardingId !== null}
                            className="bg-accent text-white px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-wider hover:bg-accent/90 active:bg-accent/80 transition-all flex items-center justify-center gap-1 ml-auto"
                          >
                            {inwardingId === product.id ? (
                              <span className="animate-spin h-3.5 w-3.5 border-2 border-white border-t-transparent rounded-full" />
                            ) : (
                              'Inward Restock'
                            )}
                          </button>
                        ) : (
                          <span className="text-text-muted font-semibold italic text-[10px]">Balanced</span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

    </div>
  )
}
