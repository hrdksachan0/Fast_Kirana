'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { 
  AlertTriangle, 
  Package, 
  Hourglass, 
  CalendarCheck,
  RefreshCw,
  Search,
  CheckCircle,
  Truck,
  Plus,
  Loader2,
  Calendar,
  XCircle,
  Clock,
  Eye
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface AlertItem {
  id: string
  name: string
  slug: string
  imageUrl: string | null
  stock: number
  minStock: number
  expiryDate: string | null
  categoryId: string
  alertType: 'OUT_OF_STOCK' | 'LOW_STOCK' | 'EXPIRING_SOON' | 'EXPIRED' | 'PACKING_DELAY'
}

interface Counts {
  outOfStock: number
  lowStock: number
  expiringSoon: number
  expired: number
  packingDelay: number
  total: number
}

interface AdminAlertsProps {
  onProductUpdated?: () => void
}

export function AdminAlerts({ onProductUpdated }: AdminAlertsProps) {
  const [alerts, setAlerts] = useState<AlertItem[]>([])
  const [counts, setCounts] = useState<Counts>({ outOfStock: 0, lowStock: 0, expiringSoon: 0, expired: 0, packingDelay: 0, total: 0 })
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [submittingRestock, setSubmittingRestock] = useState<string | null>(null)
  
  // Search and tabs filter
  const [search, setSearch] = useState('')
  const [activeSubTab, setActiveSubTab] = useState<'ALL' | 'OUT_OF_STOCK' | 'LOW_STOCK' | 'EXPIRING_SOON' | 'EXPIRED' | 'PACKING_DELAY'>('ALL')
  
  // Restock state
  const [restockAmount, setRestockAmount] = useState<Record<string, string>>({})

  // Fetch alerts
  const fetchAlerts = async (showToast = false) => {
    try {
      setLoading(true)
      const res = await fetch('/api/admin/alerts')
      if (!res.ok) throw new Error('Failed to fetch')
      const data = await res.json()
      setAlerts(data.alerts || [])
      setCounts(data.counts || { outOfStock: 0, lowStock: 0, expiringSoon: 0, expired: 0, packingDelay: 0, total: 0 })
      if (showToast) {
        toast.success('Alerts updated successfully!')
      }
    } catch (err) {
      console.error(err)
      toast.error('Could not load inventory alerts')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchAlerts()
  }, [])

  // Force recalculate alerts in database
  const handleRecalculate = async () => {
    try {
      setRefreshing(true)
      const res = await fetch('/api/admin/alerts', { method: 'POST' })
      if (!res.ok) throw new Error('Recalculation failed')
      const data = await res.json()
      toast.success(data.message || 'System alerts refreshed')
      await fetchAlerts()
    } catch (err) {
      console.error(err)
      toast.error('Alert database refresh failed')
    } finally {
      setRefreshing(false)
    }
  }

  // Quick Restock Product
  const handleRestock = async (productId: string, currentStock: number) => {
    const amountStr = restockAmount[productId]
    const amount = parseInt(amountStr, 10)
    
    if (isNaN(amount) || amount <= 0) {
      toast.error('Please enter a valid stock amount greater than 0')
      return
    }

    try {
      setSubmittingRestock(productId)
      
      // We call the bulk-update API to SET the stock
      const res = await fetch('/api/admin/bulk-update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          productIds: [productId],
          updateType: 'STOCK',
          mode: 'SET_VALUE',
          value: currentStock + amount,
        })
      })

      if (!res.ok) throw new Error('Restock failed')
      
      toast.success('Product stock updated!')
      setRestockAmount(prev => ({ ...prev, [productId]: '' }))
      
      // Update alerts and counts local view, trigger parent reload
      await fetchAlerts()
      if (onProductUpdated) onProductUpdated()
    } catch (err) {
      console.error(err)
      toast.error('Restock operation failed')
    } finally {
      setSubmittingRestock(null)
    }
  }

  // Filter alerts by sub-tab and search query
  const filteredAlerts = alerts.filter(item => {
    const matchesSearch = item.name.toLowerCase().includes(search.toLowerCase())
    if (activeSubTab === 'ALL') return matchesSearch
    return item.alertType === activeSubTab && matchesSearch
  })

  // Format Expiry Date safely
  const formatExpiry = (dateStr: string | null, alertType?: string) => {
    if (!dateStr) return 'N/A'
    if (alertType === 'PACKING_DELAY') {
      const diffMs = new Date().getTime() - new Date(dateStr).getTime()
      const diffMin = Math.floor(diffMs / 60000)
      return `Accepted ${diffMin}m ago`
    }
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
  }

  // Get status details based on Alert Type
  const getBadgeStyle = (type: string) => {
    switch (type) {
      case 'OUT_OF_STOCK':
        return {
          bg: 'bg-red-500/10 text-red-500 border border-red-500/20',
          label: 'Out of Stock',
          icon: XCircle
        }
      case 'LOW_STOCK':
        return {
          bg: 'bg-orange-500/10 text-orange-500 border border-orange-500/20',
          label: 'Low Stock',
          icon: AlertTriangle
        }
      case 'EXPIRING_SOON':
        return {
          bg: 'bg-amber-500/10 text-amber-500 border border-amber-500/20',
          label: 'Expiring Soon',
          icon: Hourglass
        }
      case 'EXPIRED':
        return {
          bg: 'bg-red-600/10 text-red-600 border border-red-600/20',
          label: 'Expired',
          icon: CalendarCheck
        }
      case 'PACKING_DELAY':
        return {
          bg: 'bg-rose-500/10 text-rose-500 border border-rose-500/20 animate-pulse',
          label: 'Packing Delay',
          icon: Clock
        }
      default:
        return {
          bg: 'bg-muted text-muted-foreground',
          label: 'Unknown',
          icon: Package
        }
    }
  }

  return (
    <div className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden">
      
      {/* Tab Header Controls */}
      <div className="p-6 border-b border-border/60 flex flex-col md:flex-row md:items-center justify-between gap-4 bg-muted/20">
        <div>
          <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
            <AlertTriangle className="h-5 w-5 text-orange-500" />
            Inventory Stock & Expiry Alerts
          </h3>
          <p className="text-xs text-text-secondary mt-0.5">
            Monitor and resolve out of stock items, critical low levels, and products nearing expiration dates.
          </p>
        </div>
        <div className="flex items-center gap-2 self-start md:self-auto">
          <button
            onClick={handleRecalculate}
            disabled={refreshing || loading}
            className="h-9 px-4 rounded-xl text-xs font-bold bg-primary text-white hover:bg-primary-dark transition-colors flex items-center gap-1.5 disabled:opacity-60"
          >
            {refreshing ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <RefreshCw className="h-3.5 w-3.5" />
            )}
            Refresh Status
          </button>
        </div>
      </div>

      {/* Tabs list with metrics counts */}
      <div className="px-6 border-b border-border/60 overflow-x-auto flex gap-4 scrollbar-hide py-2">
        {[
          { key: 'ALL', label: 'All Alerts', count: counts.total },
          { key: 'OUT_OF_STOCK', label: 'Out of Stock', count: counts.outOfStock },
          { key: 'LOW_STOCK', label: 'Low Stock', count: counts.lowStock },
          { key: 'EXPIRING_SOON', label: 'Expiring Soon', count: counts.expiringSoon },
          { key: 'EXPIRED', label: 'Expired', count: counts.expired },
          { key: 'PACKING_DELAY', label: 'Packing Delay', count: counts.packingDelay }
        ].map((subTab) => (
          <button
            key={subTab.key}
            onClick={() => setActiveSubTab(subTab.key as any)}
            className={`py-2 px-3 text-xs font-extrabold border-b-2 whitespace-nowrap transition-colors flex items-center gap-1.5 -mb-[9px] ${
              activeSubTab === subTab.key
                ? 'border-primary text-primary'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            {subTab.label}
            <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full ${
              activeSubTab === subTab.key ? 'bg-primary/10 text-primary' : 'bg-muted text-text-secondary'
            }`}>
              {subTab.count}
            </span>
          </button>
        ))}
      </div>

      {/* Search Input bar */}
      <div className="p-4 border-b border-border/60 flex items-center gap-2 bg-card">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search alerting products by name..."
            className="w-full bg-muted/40 border border-border/80 pl-9 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-primary/50 focus:bg-card"
          />
        </div>
      </div>

      {/* Alerts Table view */}
      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center text-text-secondary">
          <Loader2 className="h-8 w-8 animate-spin text-primary mb-2" />
          <span className="text-xs font-semibold">Scanning inventory state...</span>
        </div>
      ) : filteredAlerts.length === 0 ? (
        <div className="py-16 text-center">
          <span className="text-3xl">🎉</span>
          <h4 className="text-sm font-bold text-text-primary mt-2">All Clear! No alerts here</h4>
          <p className="text-xs text-text-secondary mt-1">No products fit this filter criteria right now.</p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-border text-[10px] font-bold text-text-secondary bg-muted/30 uppercase tracking-wider">
                <th className="px-6 py-3">Product Name</th>
                <th className="px-6 py-3">Alert Reason</th>
                <th className="px-6 py-3">Current Stock</th>
                <th className="px-6 py-3">Min Level</th>
                <th className="px-6 py-3">Expiry Date</th>
                <th className="px-6 py-3 text-right">Quick Restock</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60">
              {filteredAlerts.map((item) => {
                const badge = getBadgeStyle(item.alertType)
                const BadgeIcon = badge.icon
                
                return (
                  <tr key={`${item.id}-${item.alertType}`} className="hover:bg-muted/10 transition-colors">
                    
                    {/* Name */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="h-9 w-9 rounded-lg bg-muted flex items-center justify-center text-lg border">
                          {item.imageUrl ? (
                            <img src={item.imageUrl} alt={item.name} className="h-7 w-7 object-contain" />
                          ) : (
                            '📦'
                          )}
                        </div>
                        <div>
                          <span className="text-xs font-bold text-text-primary block leading-tight">{item.name}</span>
                          <span className="text-[10px] text-text-muted block mt-0.5">ID: {item.id}</span>
                        </div>
                      </div>
                    </td>

                    {/* Alert Type */}
                    <td className="px-6 py-4">
                      <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold ${badge.bg}`}>
                        <BadgeIcon className="h-3 w-3" />
                        {badge.label}
                      </span>
                    </td>

                    {/* Stock */}
                    <td className="px-6 py-4">
                      {item.alertType === 'PACKING_DELAY' ? (
                        <span className="text-xs text-text-secondary">N/A</span>
                      ) : (
                        <span className={`text-xs font-bold ${
                          item.stock === 0 ? 'text-red-500' : item.stock <= item.minStock ? 'text-orange-500' : 'text-text-primary'
                        }`}>
                          {item.stock} unit{item.stock !== 1 ? 's' : ''}
                        </span>
                      )}
                    </td>

                    {/* Min Stock */}
                    <td className="px-6 py-4">
                      <span className="text-xs text-text-secondary">
                        {item.alertType === 'PACKING_DELAY' ? 'N/A' : item.minStock}
                      </span>
                    </td>

                    {/* Expiry */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-1 text-xs text-text-secondary font-bold">
                        {item.alertType === 'PACKING_DELAY' ? (
                          <Clock className="h-3.5 w-3.5 text-rose-500" />
                        ) : (
                          <Calendar className="h-3.5 w-3.5 text-text-muted" />
                        )}
                        <span className={item.alertType === 'EXPIRED' || item.alertType === 'PACKING_DELAY' ? 'text-rose-600 font-bold' : ''}>
                          {formatExpiry(item.expiryDate, item.alertType)}
                        </span>
                      </div>
                    </td>

                    {/* Restock Actions */}
                    <td className="px-6 py-4 text-right">
                      {item.alertType === 'PACKING_DELAY' ? (
                        <div className="flex items-center justify-end">
                          <a
                            href={`/order/${item.id}/track`}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-primary hover:bg-primary/95 text-white hover:text-white text-xs font-bold transition-all shadow-sm active:scale-95 cursor-pointer"
                          >
                            <Eye className="h-3.5 w-3.5" />
                            <span>View Order</span>
                          </a>
                        </div>
                      ) : (
                        <div className="flex items-center justify-end gap-2">
                          <input
                            type="number"
                            min="1"
                            value={restockAmount[item.id] || ''}
                            onChange={(e) => setRestockAmount(prev => ({ ...prev, [item.id]: e.target.value }))}
                            placeholder="+Qty"
                            className="w-16 bg-muted/50 border border-border text-center rounded-lg px-2 py-1 text-xs focus:outline-none focus:border-primary"
                          />
                          <button
                            onClick={() => handleRestock(item.id, item.stock)}
                            disabled={submittingRestock === item.id}
                            className="p-1 bg-accent text-white hover:bg-accent-dark rounded-lg transition-colors disabled:opacity-50"
                            title="Quick restock items"
                          >
                            {submittingRestock === item.id ? (
                              <Loader2 className="h-4.5 w-4.5 animate-spin" />
                            ) : (
                              <Plus className="h-4.5 w-4.5" />
                            )}
                          </button>
                        </div>
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
  )
}
