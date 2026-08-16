'use client'

import { useState, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { 
  IndianRupee, 
  Calendar, 
  Download, 
  Utensils, 
  RefreshCw, 
  Edit2, 
  Check, 
  Store,
  Loader2,
  X,
  CreditCard,
  History,
  CheckCircle2,
  FileText
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface RestaurantSalesData {
  id: string
  name: string
  slug: string
  logoUrl: string | null
  isOpen: boolean
  commissionRate: number
  totalOrders: number
  totalProductSales: number
  adminCommission: number
  restaurantShare: number
  avgOrderValue: number
  topDish: string
  totalDeliveryFee: number
  totalPackaging: number
  lastSettledDate?: string | null
  lastSettledAmount?: number | null
  lastSettledTxnId?: string | null
  deliveryOrders?: number
  deliverySales?: number
  pickupOrders?: number
  pickupSales?: number
}

interface SettlementLog {
  id: string
  startDate: string
  endDate: string
  amount: number
  status: 'PENDING' | 'PAID'
  transactionId: string | null
  paidAt: string | null
  notes: string | null
  createdAt: string
  restaurant?: { name: string; slug: string } | null
}

export function AdminRestaurantReport() {
  const [loading, setLoading] = useState(true)
  const [data, setData] = useState<RestaurantSalesData[]>([])
  
  // Date range state
  const [rangePreset, setRangePreset] = useState<'today' | 'yesterday' | '7days' | '30days' | 'custom'>('7days')
  const [startDate, setStartDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() - 7)
    return d.toISOString().split('T')[0]
  })
  const [endDate, setEndDate] = useState(() => {
    return new Date().toISOString().split('T')[0]
  })
  
  // Edit commission state
  const [editingComm, setEditingComm] = useState<string | null>(null)
  const [commValue, setCommValue] = useState<string>('')
  const [updatingComm, setUpdatingComm] = useState(false)

  // Settlement Modal state
  const [settlingRest, setSettlingRest] = useState<RestaurantSalesData | null>(null)
  const [settleAmount, setSettleAmount] = useState<string>('')
  const [settleTxnId, setSettleTxnId] = useState<string>('')
  const [settleNotes, setSettleNotes] = useState<string>('')
  const [isSettling, setIsSettling] = useState(false)

  // Past Settlements Ledger state
  const [pastPayouts, setPastPayouts] = useState<SettlementLog[]>([])
  const [loadingPayouts, setLoadingPayouts] = useState(false)
  const [showHistory, setShowHistory] = useState(false)

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

    if (preset !== 'custom') {
      setStartDate(start.toISOString().split('T')[0])
      setEndDate(end.toISOString().split('T')[0])
    }
  }

  const fetchReport = async () => {
    setLoading(true)
    try {
      const url = `/api/admin/restaurant-sales?startDate=${startDate}&endDate=${endDate}`
      const res = await fetch(url)
      if (!res.ok) throw new Error('Failed to fetch data')
      const json = await res.json()
      setData(json.restaurants || json)
    } catch (err) {
      console.error(err)
      toast.error('Failed to load restaurant report')
    } finally {
      setLoading(false)
    }
  }

  const fetchPastPayouts = async () => {
    setLoadingPayouts(true)
    try {
      const res = await fetch('/api/admin/payouts')
      if (!res.ok) throw new Error('Failed to load payouts')
      const json = await res.json()
      setPastPayouts(json || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoadingPayouts(false)
    }
  }

  useEffect(() => {
    if (rangePreset !== 'custom' || (startDate && endDate)) {
      fetchReport()
    }
    fetchPastPayouts()
  }, [startDate, endDate, rangePreset])

  const handleOpenSettleModal = (rest: RestaurantSalesData) => {
    setSettlingRest(rest)
    setSettleAmount(rest.restaurantShare.toString())
    setSettleTxnId('')
    setSettleNotes(`Settlement for ${startDate} to ${endDate} (${rest.name})`)
  }

  const handleConfirmSettle = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!settlingRest) return
    const amt = Number(settleAmount)
    if (isNaN(amt) || amt <= 0) {
      toast.error('Please enter a valid payout amount')
      return
    }

    setIsSettling(true)
    try {
      const res = await fetch('/api/admin/payouts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          startDate,
          endDate,
          restaurantId: settlingRest.id,
          amount: amt,
          status: 'PAID',
          transactionId: settleTxnId.trim() || undefined,
          notes: settleNotes.trim() || undefined,
          type: 'RESTAURANT'
        })
      })

      if (!res.ok) {
        const errJson = await res.json()
        throw new Error(errJson.error || 'Failed to record settlement')
      }

      toast.success(`Settlement of ${formatPrice(amt)} for ${settlingRest.name} recorded as PAID!`)
      setSettlingRest(null)
      fetchReport()
      fetchPastPayouts()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Failed to record settlement')
    } finally {
      setIsSettling(false)
    }
  }

  const handleUpdateCommission = async (id: string) => {
    if (!commValue || isNaN(Number(commValue))) {
      toast.error('Please enter a valid commission percentage')
      return
    }
    
    setUpdatingComm(true)
    try {
      const res = await fetch(`/api/restaurants/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ commissionRate: Number(commValue) / 100 })
      })
      if (!res.ok) throw new Error('Failed to update')
      
      toast.success('Commission updated successfully!')
      setEditingComm(null)
      fetchReport()
    } catch (err) {
      console.error(err)
      toast.error('Failed to update commission rate')
    } finally {
      setUpdatingComm(false)
    }
  }

  const handleDownloadCSV = () => {
    try {
      let csvContent = 'data:text/csv;charset=utf-8,'
      csvContent += 'Restaurant Name,Status,Commission (%),Total Orders,Total Product Sales (INR),Admin Commission (INR),Restaurant Payout Share (INR),Doorstep Delivery Orders,Doorstep Delivery Sales (INR),Self Pickup Orders,Self Pickup Sales (INR),Avg Order (INR),Top Dish,Delivery Fee (INR),Packaging Fee (INR)\n'
      
      data.forEach(r => {
        const comm = (r.commissionRate * 100).toFixed(1)
        const status = r.isOpen ? 'Open' : 'Closed'
        csvContent += `"${r.name}",${status},${comm}%,${r.totalOrders},${r.totalProductSales},${r.adminCommission},${r.restaurantShare},${r.deliveryOrders || 0},${r.deliverySales || 0},${r.pickupOrders || 0},${r.pickupSales || 0},${r.avgOrderValue},"${r.topDish}",${r.totalDeliveryFee},${r.totalPackaging}\n`
      })
      
      const encodedUri = encodeURI(csvContent)
      const link = document.createElement('a')
      link.setAttribute('href', encodedUri)
      link.setAttribute('download', `Restaurant_Payout_Report_${startDate}_to_${endDate}.csv`)
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      toast.success('CSV Report downloaded successfully')
    } catch (e) {
      console.error(e)
      toast.error('Failed to export CSV report')
    }
  }

  const totals = useMemo(() => {
    return data.reduce((acc, curr) => ({
      productSales: acc.productSales + curr.totalProductSales,
      adminCommission: acc.adminCommission + curr.adminCommission,
      restaurantShare: acc.restaurantShare + curr.restaurantShare,
      orders: acc.orders + curr.totalOrders
    }), {
      productSales: 0,
      adminCommission: 0,
      restaurantShare: 0,
      orders: 0
    })
  }, [data])

  return (
    <div className="space-y-6 pb-24 relative min-h-[70vh]">
      
      {/* Header & Date Range section */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h3 className="text-xl font-black text-text-primary flex items-center gap-2">
            <Utensils className="h-6 w-6 text-accent" />
            Restaurant Settlement & Payout Report
          </h3>
          <p className="text-xs text-text-secondary mt-1 font-semibold">
            Track weekly restaurant earnings and payout amounts (Delivery & packaging charges excluded)
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Quick ranges */}
          <div className="flex bg-muted/60 p-1 rounded-xl border border-border text-[11px] font-bold">
            {(['today', 'yesterday', '7days', '30days', 'custom'] as const).map((r) => {
              const labels: Record<string, string> = {
                'today': 'Aaj',
                'yesterday': 'Kal',
                '7days': '7 Din',
                '30days': '30 Din',
                'custom': 'Custom'
              }
              return (
                <button
                  key={r}
                  onClick={() => handlePresetChange(r)}
                  className={`px-3 py-1.5 rounded-lg capitalize transition-colors ${
                    rangePreset === r ? 'bg-card text-primary shadow-sm border border-border/50' : 'text-text-secondary hover:text-text-primary'
                  }`}
                >
                  {labels[r]}
                </button>
              )
            })}
          </div>

          {/* Custom Date Picker Inputs */}
          {rangePreset === 'custom' && (
            <div className="flex items-center gap-2 text-xs">
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="bg-muted border border-border px-2.5 py-1.5 rounded-lg text-text-primary font-semibold focus:outline-none"
              />
              <span className="text-text-muted font-black">to</span>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="bg-muted border border-border px-2.5 py-1.5 rounded-lg text-text-primary font-semibold focus:outline-none"
              />
              <button
                onClick={fetchReport}
                className="p-1.5 bg-card border border-border hover:bg-muted/40 rounded-lg transition-all"
              >
                <RefreshCw className="h-4 w-4" />
              </button>
            </div>
          )}

          <button
            onClick={handleDownloadCSV}
            disabled={loading || data.length === 0}
            className="h-9 px-4 rounded-xl text-xs font-bold bg-accent hover:bg-accent-dark text-white transition-colors flex items-center gap-1.5 disabled:opacity-50"
          >
            <Download className="h-3.5 w-3.5" />
            Export CSV
          </button>
        </div>
      </div>

      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center text-text-secondary">
          <Loader2 className="h-8 w-8 animate-spin text-primary mb-3" />
          <span className="text-xs font-semibold">Hisaab calculate ho raha hai...</span>
        </div>
      ) : data.length === 0 ? (
        <div className="bg-card border border-border p-12 rounded-2xl shadow-sm text-center">
          <Store className="h-12 w-12 text-muted-foreground opacity-30 mx-auto mb-3" />
          <h3 className="text-lg font-bold text-text-primary">No Data Found</h3>
          <p className="text-xs text-text-secondary mt-1">No completed restaurant sales in this date range.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {data.map(r => (
            <div key={r.id} className="bg-card border border-border p-5 rounded-2xl shadow-sm flex flex-col md:flex-row gap-5">
              
              {/* Left Info */}
              <div className="flex flex-col md:w-64 shrink-0 border-r border-border/50 pr-4">
                <div className="flex items-center gap-3 mb-3">
                  <div className="h-10 w-10 rounded-full bg-muted border border-border overflow-hidden flex items-center justify-center shrink-0">
                    {r.logoUrl ? (
                      <img src={r.logoUrl} alt={r.name} className="w-full h-full object-cover" />
                    ) : (
                      <Store className="h-5 w-5 text-text-muted" />
                    )}
                  </div>
                  <div>
                    <h4 className="font-bold text-text-primary text-base line-clamp-1">{r.name}</h4>
                    <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full inline-block mt-0.5 ${r.isOpen ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'}`}>
                      {r.isOpen ? 'Open' : 'Closed'}
                    </span>
                  </div>
                </div>

                <div className="mt-auto space-y-2">
                  <div className="flex items-center justify-between text-xs border-t border-border/40 pt-2">
                    <span className="text-text-secondary font-semibold">Commission Setup:</span>
                    {editingComm === r.id ? (
                      <div className="flex items-center gap-1">
                        <input 
                          type="number" 
                          className="w-14 px-1.5 py-1 bg-muted border border-border rounded text-[10px] font-bold text-center focus:outline-none" 
                          value={commValue} 
                          onChange={e => setCommValue(e.target.value)} 
                        />
                        <button 
                          onClick={() => handleUpdateCommission(r.id)} 
                          disabled={updatingComm}
                          className="p-1 bg-accent text-white rounded hover:bg-accent/90 cursor-pointer"
                        >
                          {updatingComm ? <Loader2 className="h-3 w-3 animate-spin" /> : <Check className="h-3 w-3" />}
                        </button>
                        <button onClick={() => setEditingComm(null)} className="p-1 bg-muted border border-border text-text-secondary rounded hover:bg-muted/80 cursor-pointer">
                          <X className="h-3 w-3" />
                        </button>
                      </div>
                    ) : (
                      <div className="flex items-center gap-1.5">
                        <span className="font-bold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30 px-1.5 py-0.5 rounded text-[10px]">{(r.commissionRate * 100).toFixed(1)}%</span>
                        <button 
                          onClick={() => { setEditingComm(r.id); setCommValue((r.commissionRate * 100).toString()) }} 
                          className="text-text-secondary hover:text-primary transition-colors cursor-pointer"
                        >
                          <Edit2 className="h-3 w-3" />
                        </button>
                      </div>
                    )}
                  </div>

                  <div className="flex items-center justify-between text-xs border-t border-border/40 pt-2">
                    <span className="text-text-secondary font-semibold">Last Settled:</span>
                    {r.lastSettledDate ? (
                      <span className="font-bold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded text-[10px] border border-emerald-500/20">
                        {new Date(r.lastSettledDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                        {r.lastSettledAmount ? ` (${formatPrice(r.lastSettledAmount)})` : ''}
                      </span>
                    ) : (
                      <span className="text-[10px] font-bold text-amber-600 bg-amber-500/10 px-1.5 py-0.5 rounded border border-amber-500/20">
                        Pending Settlement
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Right Metrics */}
              <div className="flex-1 flex flex-col justify-between">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                  <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-3">
                    <p className="text-[10px] font-bold text-emerald-600 dark:text-emerald-400 uppercase tracking-wider mb-1">Total Product Sales</p>
                    <p className="text-lg font-black text-emerald-700 dark:text-emerald-300">{formatPrice(r.totalProductSales)}</p>
                  </div>
                  
                  <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-3">
                    <p className="text-[10px] font-bold text-blue-600 dark:text-blue-400 uppercase tracking-wider mb-1">Admin Comm.</p>
                    <p className="text-lg font-black text-blue-700 dark:text-blue-300">{formatPrice(r.adminCommission)}</p>
                  </div>

                  <div className="bg-primary/10 border-2 border-primary/30 rounded-xl p-3 md:col-span-1 shadow-sm flex flex-col justify-between">
                    <div>
                      <p className="text-[10px] font-bold text-primary uppercase tracking-wider mb-1">Payout to Restaurant</p>
                      <p className="text-xl md:text-2xl font-black text-primary">{formatPrice(r.restaurantShare)}</p>
                    </div>
                    <button
                      onClick={() => handleOpenSettleModal(r)}
                      className="mt-2.5 w-full py-1.5 px-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-[10px] font-black tracking-wide flex items-center justify-center gap-1.5 transition-all shadow-xs cursor-pointer active:scale-95"
                      title="Settle & Record Payment to this Restaurant"
                    >
                      <CreditCard className="h-3.5 w-3.5" />
                      <span>💳 Settle Hisab</span>
                    </button>
                  </div>
                  
                  <div className="bg-purple-500/10 border border-purple-500/20 rounded-xl p-3">
                    <p className="text-[10px] font-bold text-purple-600 dark:text-purple-400 uppercase tracking-wider mb-1">Orders</p>
                    <p className="text-lg font-black text-purple-700 dark:text-purple-300">{r.totalOrders}</p>
                  </div>
                </div>

                {/* Channel Split: Delivery vs Pickup */}
                <div className="mt-3 grid grid-cols-2 gap-2 text-[11px]">
                  <div className="flex items-center justify-between p-2 rounded-lg bg-blue-500/5 border border-blue-500/15">
                    <span className="flex items-center gap-1.5 font-bold text-blue-700 dark:text-blue-300 text-[10px]">
                      <span>🛵</span> Doorstep Delivery:
                    </span>
                    <span className="font-black text-text-primary text-[10px]">
                      {r.deliveryOrders || 0} orders ({formatPrice(r.deliverySales || 0)})
                    </span>
                  </div>

                  <div className="flex items-center justify-between p-2 rounded-lg bg-emerald-500/5 border border-emerald-500/15">
                    <span className="flex items-center gap-1.5 font-bold text-emerald-700 dark:text-emerald-300 text-[10px]">
                      <span>🛍️</span> Self Pickup:
                    </span>
                    <span className="font-black text-text-primary text-[10px]">
                      {r.pickupOrders || 0} orders ({formatPrice(r.pickupSales || 0)})
                    </span>
                  </div>
                </div>

                <div className="mt-2.5 flex flex-col md:flex-row justify-between text-[10px] font-semibold text-text-secondary bg-muted/40 p-2 rounded-lg border border-border/40 gap-2">
                  <span className="flex items-center gap-1">
                    <Utensils className="h-3 w-3" /> Top Dish: <span className="text-text-primary font-bold">{r.topDish || 'N/A'}</span> <span className="mx-1 text-border">|</span> Avg Order: <span className="text-text-primary font-bold">{formatPrice(r.avgOrderValue)}</span>
                  </span>
                  <span className="text-text-muted">
                    Delivery {formatPrice(r.totalDeliveryFee)} + Packaging {formatPrice(r.totalPackaging)} — excluded from commission
                  </span>
                </div>
              </div>
              
            </div>
          ))}
        </div>
      )}

      {/* Settlements History & Paid Ledger Section */}
      <div className="bg-card border border-border/60 rounded-3xl p-5 shadow-xs space-y-4">
        <div className="flex items-center justify-between border-b border-border/40 pb-3">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
              <History className="h-4 w-4" />
            </div>
            <div>
              <h3 className="text-sm font-black text-text-primary uppercase tracking-wider">
                Settlement History &amp; Paid Ledger ({pastPayouts.length})
              </h3>
              <p className="text-[11px] text-text-muted">
                Audit record of settled restaurant accounts with UTR transaction IDs.
              </p>
            </div>
          </div>

          <button
            onClick={fetchPastPayouts}
            disabled={loadingPayouts}
            className="p-2 border border-border hover:bg-muted text-text-secondary rounded-xl transition-all cursor-pointer"
            title="Refresh Settlements Ledger"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loadingPayouts ? 'animate-spin' : ''}`} />
          </button>
        </div>

        {loadingPayouts ? (
          <div className="p-6 text-center text-xs font-bold text-text-muted flex items-center justify-center gap-2">
            <Loader2 className="h-4 w-4 animate-spin text-primary" /> Loading settled payouts...
          </div>
        ) : pastPayouts.length === 0 ? (
          <div className="p-6 text-center text-xs font-bold text-text-muted">
            No settlement payouts recorded yet. Click &quot;💳 Settle Hisab&quot; on any restaurant card above to record a payout.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-border/60 bg-muted/30 text-text-secondary uppercase text-[10px] font-black">
                  <th className="py-2.5 px-3">Date Settled</th>
                  <th className="py-2.5 px-3">Restaurant / Outlet</th>
                  <th className="py-2.5 px-3">Settlement Period</th>
                  <th className="py-2.5 px-3">Amount Paid</th>
                  <th className="py-2.5 px-3">UTR / Txn ID</th>
                  <th className="py-2.5 px-3">Status</th>
                  <th className="py-2.5 px-3">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/30">
                {pastPayouts.map((p) => (
                  <tr key={p.id} className="hover:bg-muted/15">
                    <td className="py-2.5 px-3 font-semibold text-text-primary whitespace-nowrap">
                      {p.paidAt ? new Date(p.paidAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'}
                    </td>
                    <td className="py-2.5 px-3 font-black text-text-primary">
                      {p.restaurant?.name || 'All Restaurants'}
                    </td>
                    <td className="py-2.5 px-3 text-[11px] text-text-muted">
                      {new Date(p.startDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })} – {new Date(p.endDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}
                    </td>
                    <td className="py-2.5 px-3 font-black text-emerald-600 dark:text-emerald-400">
                      {formatPrice(p.amount)}
                    </td>
                    <td className="py-2.5 px-3 font-mono text-[11px] text-text-secondary">
                      {p.transactionId || '—'}
                    </td>
                    <td className="py-2.5 px-3">
                      <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full border ${
                        p.status === 'PAID' ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20' : 'bg-amber-500/10 text-amber-600 border-amber-500/20'
                      }`}>
                        {p.status}
                      </span>
                    </td>
                    <td className="py-2.5 px-3 text-[11px] text-text-muted line-clamp-1 max-w-[200px]">
                      {p.notes || '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Settle Hisab Popup Modal */}
      {settlingRest && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="bg-card border border-border rounded-3xl w-full max-w-md overflow-hidden shadow-2xl space-y-0 my-auto animate-in fade-in zoom-in-95 duration-200">
            <div className="p-5 bg-gradient-to-r from-emerald-500/15 to-teal-500/10 border-b border-border flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="h-9 w-9 rounded-xl bg-emerald-600 text-white flex items-center justify-center">
                  <CreditCard className="h-5 w-5" />
                </div>
                <div>
                  <h3 className="font-extrabold text-sm text-text-primary uppercase tracking-wider">
                    Settle Restaurant Hisab
                  </h3>
                  <p className="text-[10px] text-text-muted">
                    {settlingRest.name}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSettlingRest(null)}
                className="h-8 w-8 rounded-full flex items-center justify-center bg-muted/60 hover:bg-muted text-text-secondary transition-all cursor-pointer"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <form onSubmit={handleConfirmSettle} className="p-5 space-y-4">
              <div className="bg-muted/30 border border-border/60 rounded-2xl p-3.5 space-y-2 text-xs">
                <div className="flex justify-between items-center text-text-secondary">
                  <span>Settlement Period:</span>
                  <span className="font-bold text-text-primary">{startDate} to {endDate}</span>
                </div>
                <div className="flex justify-between items-center text-text-secondary">
                  <span>Gross Product Sales:</span>
                  <span className="font-bold text-emerald-600">{formatPrice(settlingRest.totalProductSales)}</span>
                </div>
                <div className="flex justify-between items-center text-text-secondary">
                  <span>FastKirana Commission ({((settlingRest.commissionRate || 0.15) * 100).toFixed(1)}%):</span>
                  <span className="font-bold text-blue-600">-{formatPrice(settlingRest.adminCommission)}</span>
                </div>
                <div className="border-t border-border/50 pt-2 flex justify-between items-center font-black text-sm text-text-primary">
                  <span>Net Payout to Settle:</span>
                  <span className="text-emerald-600 dark:text-emerald-400 font-extrabold">{formatPrice(settlingRest.restaurantShare)}</span>
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                  Payout Amount (INR) *
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-xs font-bold text-text-muted">₹</span>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={settleAmount}
                    onChange={(e) => setSettleAmount(e.target.value)}
                    className="w-full pl-7 pr-3 py-2 bg-muted/30 border border-border rounded-xl text-xs font-black text-text-primary focus:outline-none focus:border-primary"
                    placeholder="Enter amount to pay"
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                  Transaction / UTR Reference ID
                </label>
                <input
                  type="text"
                  value={settleTxnId}
                  onChange={(e) => setSettleTxnId(e.target.value)}
                  placeholder="e.g. UPI Ref: 4239812903 or NEFT/IMPS UTR"
                  className="w-full px-3 py-2 bg-muted/30 border border-border rounded-xl text-xs font-semibold text-text-primary focus:outline-none focus:border-primary"
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                  Settlement Notes / Remarks
                </label>
                <input
                  type="text"
                  value={settleNotes}
                  onChange={(e) => setSettleNotes(e.target.value)}
                  placeholder="e.g. Weekly settlement via PhonePe"
                  className="w-full px-3 py-2 bg-muted/30 border border-border rounded-xl text-xs font-semibold text-text-primary focus:outline-none focus:border-primary"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setSettlingRest(null)}
                  className="px-4 py-2 border border-border rounded-xl text-xs font-bold hover:bg-muted transition-all cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSettling}
                  className="px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-black transition-all shadow-xs flex items-center gap-1.5 cursor-pointer disabled:opacity-50 active:scale-95"
                >
                  {isSettling ? (
                    <>
                      <Loader2 className="h-3.5 w-3.5 animate-spin" />
                      <span>Recording...</span>
                    </>
                  ) : (
                    <>
                      <CheckCircle2 className="h-3.5 w-3.5" />
                      <span>Confirm &amp; Mark Paid</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Grand Totals Sticky Bar */}
      {!loading && data.length > 0 && (
        <div className="fixed bottom-0 left-0 right-0 bg-card border-t-2 border-primary/20 p-4 shadow-[0_-4px_20px_rgba(0,0,0,0.05)] z-40 md:pl-64">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-4">
            <h4 className="font-black text-text-primary text-sm uppercase flex items-center gap-2">
              <IndianRupee className="h-5 w-5 text-accent" />
              Grand Total Summary
            </h4>
            
            <div className="flex gap-4 md:gap-8 overflow-x-auto pb-1 md:pb-0 scrollbar-hide">
              <div className="shrink-0">
                <p className="text-[10px] font-bold text-text-secondary uppercase">TOTAL PRODUCT SALES</p>
                <p className="text-base font-black text-emerald-600 dark:text-emerald-400">{formatPrice(totals.productSales)}</p>
              </div>
              <div className="shrink-0">
                <p className="text-[10px] font-bold text-text-secondary uppercase">ADMIN COMMISSION</p>
                <p className="text-base font-black text-blue-600 dark:text-blue-400">{formatPrice(totals.adminCommission)}</p>
              </div>
              <div className="shrink-0 bg-primary/10 px-3 py-1 rounded-lg border border-primary/20">
                <p className="text-[10px] font-bold text-primary uppercase">PAYOUT TO RESTAURANTS</p>
                <p className="text-lg font-black text-primary">{formatPrice(totals.restaurantShare)}</p>
              </div>
              <div className="shrink-0">
                <p className="text-[10px] font-bold text-text-secondary uppercase">TOTAL ORDERS</p>
                <p className="text-base font-black text-purple-600 dark:text-purple-400">{totals.orders}</p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
