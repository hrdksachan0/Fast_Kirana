'use client';
import { apiUrl } from '@/lib/api-url';

import { useState, useEffect } from 'react'
import {
  Wallet,
  DollarSign,
  TrendingUp,
  Store,
  RefreshCw,
  CheckCircle2,
  AlertTriangle,
  Lock,
  Phone,
  UserCheck,
  History,
  ArrowDownRight,
  ShieldCheck,
  Search,
  Trash2,
  MessageSquare,
  PhoneCall,
  Package,
  Bike,
  IndianRupee,
} from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'
import { formatOrderTime } from '@/lib/date-helpers'
import { motion, AnimatePresence } from 'framer-motion'

interface RiderCashInfo {
  id: string
  name: string
  email: string
  phone: string
  image: string | null
  cashInHand: number
  cashLimit: number
  totalCollected: number
  totalDeposited: number
  activeOrdersCount?: number
  todayTotalOrdersCount?: number
  todayTotalDeliveredMoney?: number
  todayCodOrdersCount: number
  todayCodTotal: number
  todayOnlineOrdersCount?: number
  todayOnlineTotal?: number
  todayDepositedTotal: number
  assignedStoreId?: string | null
  storeName?: string | null
}

interface SummaryInfo {
  onlineRevenueToday: number
  deliveredCodToday: number
  counterCashToday: number
  totalCashDepositedToday: number
  pendingRiderCash: number
  activeRidersCount: number
  totalDeliveredMoneyToday?: number
  totalOrdersDeliveredToday?: number
}

interface DepositLog {
  id: string
  riderName: string
  riderPhone: string
  adminName: string
  amount: number
  notes: string
  createdAt: string
}

interface AdminRiderCashProps {
  storeId?: string | null
}

export function AdminRiderCash({ storeId }: AdminRiderCashProps = {}) {
  const [riders, setRiders] = useState<RiderCashInfo[]>([])
  const [summary, setSummary] = useState<SummaryInfo | null>(null)
  const [recentDeposits, setRecentDeposits] = useState<DepositLog[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')

  // Settlement modal state
  const [selectedRider, setSelectedRider] = useState<RiderCashInfo | null>(null)
  const [depositAmount, setDepositAmount] = useState('')
  const [depositNotes, setDepositNotes] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  const fetchData = async () => {
    try {
      setIsLoading(true)
      const url = storeId ? `/api/admin/rider-cash?storeId=${encodeURIComponent(storeId)}` : '/api/admin/rider-cash'
      const res = await fetch(url)
      if (res.ok) {
        const data = await res.json()
        setRiders(data.riders || [])
        setSummary(data.summary || null)
        setRecentDeposits(data.recentDeposits || [])
      } else {
        toast.error('Failed to load rider cash balances')
      }
    } catch (err) {
      console.error('Error fetching rider cash data:', err)
      toast.error('Could not load cash reconciliation data')
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [storeId])

  const handleOpenSettleModal = (rider: RiderCashInfo) => {
    setSelectedRider(rider)
    setDepositAmount(rider.cashInHand > 0 ? rider.cashInHand.toString() : '')
    setDepositNotes('Daily Cash Deposit to Store Admin')
  }

  const handleConfirmSettlement = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedRider) return

    const numAmount = parseFloat(depositAmount)
    if (isNaN(numAmount) || numAmount <= 0) {
      toast.error('Please enter a valid deposit amount')
      return
    }

    try {
      setIsSubmitting(true)
      const res = await fetch(`${apiUrl()}/api/admin/rider-cash`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          riderId: selectedRider.id,
          amount: numAmount,
          notes: depositNotes
        })
      })

      const data = await res.json()
      if (res.ok && data.success) {
        toast.success(data.message || 'Cash settled successfully!')
        setSelectedRider(null)
        setDepositAmount('')
        setDepositNotes('')
        fetchData()
      } else {
        toast.error(data.error || 'Failed to settle cash')
      }
    } catch (err) {
      console.error('Error submitting cash deposit:', err)
      toast.error('Network error settling cash')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleDeleteDeposit = async (id: string) => {
    try {
      const res = await fetch(`${apiUrl()}/api/admin/rider-cash?id=${id}`, {
        method: 'DELETE'
      })
      const data = await res.json()
      if (res.ok && data.success) {
        toast.success('Deposit log deleted')
        fetchData()
      } else {
        toast.error(data.error || 'Failed to delete deposit log')
      }
    } catch (e) {
      console.error(e)
      toast.error('Error deleting deposit log')
    }
  }

  const handleClearAllDeposits = async () => {
    if (!confirm('Are you sure you want to delete all cash deposit logs to clean up data?')) return
    try {
      const storeParam = storeId && storeId !== 'all' ? `&storeId=${encodeURIComponent(storeId)}` : ''
      const res = await fetch(`${apiUrl()}/api/admin/rider-cash?clearAll=true${storeParam}`, {
        method: 'DELETE'
      })
      const data = await res.json()
      if (res.ok && data.success) {
        toast.success(data.message || 'Cleared all deposit logs')
        fetchData()
      } else {
        toast.error(data.error || 'Failed to clear deposit logs')
      }
    } catch (e) {
      console.error(e)
      toast.error('Error clearing deposit logs')
    }
  }

  const [filterTab, setFilterTab] = useState<'all' | 'needs-settle' | 'free' | 'busy'>('all')

  const totalDeliveredOrdersToday = riders.reduce((sum, r) => sum + (r.todayTotalOrdersCount || 0), 0)
  const totalDeliveredMoneyToday = riders.reduce((sum, r) => sum + (r.todayTotalDeliveredMoney || 0), 0)
  const busyRidersCount = riders.filter((r) => (r.activeOrdersCount || 0) > 0).length
  const freeRidersCount = riders.filter((r) => (r.activeOrdersCount || 0) === 0).length
  const needsSettleCount = riders.filter((r) => r.cashInHand >= r.cashLimit * 0.75 || r.cashInHand >= r.cashLimit).length

  const handleWhatsAppRider = (rider: RiderCashInfo) => {
    const cleanPhone = (rider.phone || '').replace(/\D/g, '').slice(-10)
    if (!cleanPhone || cleanPhone.length !== 10) {
      toast.error('Rider phone number invalid')
      return
    }
    const msg = `Hey ${rider.name}! Please deposit your pending cash of ${formatPrice(rider.cashInHand)} to the Store Admin counter.`
    window.open(`https://wa.me/91${cleanPhone}?text=${encodeURIComponent(msg)}`, '_blank')
  }

  const filteredRiders = riders.filter((r) => {
    const matchesSearch =
      r.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      r.phone.includes(searchQuery)
    if (!matchesSearch) return false

    if (filterTab === 'needs-settle') {
      return r.cashInHand >= r.cashLimit * 0.75 || r.cashInHand >= r.cashLimit
    }
    if (filterTab === 'free') {
      return (r.activeOrdersCount || 0) === 0
    }
    if (filterTab === 'busy') {
      return (r.activeOrdersCount || 0) > 0
    }
    return true
  })

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-card border border-border p-5 rounded-3xl shadow-xs">
        <div>
          <h1 className="text-xl sm:text-2xl font-black text-text-primary flex items-center gap-2.5">
            <span className="p-2 rounded-2xl bg-primary/10 text-primary">
              <Bike className="h-6 w-6" />
            </span>
            Rider Fleet, Work, Money &amp; Cash Ledger
          </h1>
          <p className="text-xs text-text-muted mt-1 font-medium">
            Live delivery workload, order fulfillment volume, collected cash reconciliation, and instant settlement.
          </p>
        </div>
        <button
          onClick={fetchData}
          disabled={isLoading}
          className="inline-flex items-center justify-center gap-2 bg-muted hover:bg-muted/80 text-text-primary px-4 py-2.5 rounded-2xl text-xs font-bold transition-all cursor-pointer disabled:opacity-50"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />
          <span>Refresh Fleet &amp; Cash</span>
        </button>
      </div>

      {/* Financial & Operational Summary Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-6 gap-3 sm:gap-3.5">
        {/* Card 1: Active Fleet */}
        <div className="bg-card border border-border/80 p-3.5 rounded-2xl space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-indigo-600 dark:text-indigo-400">
            <span className="text-[10px] font-black uppercase tracking-wider">Active Fleet</span>
            <Bike className="h-4 w-4" />
          </div>
          <p className="text-xl sm:text-2xl font-black text-text-primary">
            {riders.length}
          </p>
          <p className="text-[10px] text-text-muted font-bold truncate">
            🟢 {freeRidersCount} Free • 🟡 {busyRidersCount} Busy
          </p>
        </div>

        {/* Card 2: Today Deliveries (Work) */}
        <div className="bg-card border border-border/80 p-3.5 rounded-2xl space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-blue-600 dark:text-blue-400">
            <span className="text-[10px] font-black uppercase tracking-wider">Today Orders</span>
            <Package className="h-4 w-4" />
          </div>
          <p className="text-xl sm:text-2xl font-black text-blue-900 dark:text-blue-100">
            {totalDeliveredOrdersToday}
          </p>
          <p className="text-[10px] text-blue-700/80 dark:text-blue-400 font-bold">
            Delivered trips today
          </p>
        </div>

        {/* Card 3: Total Money Handled */}
        <div className="bg-card border border-border/80 p-3.5 rounded-2xl space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-purple-600 dark:text-purple-400">
            <span className="text-[10px] font-black uppercase tracking-wider">Money Handled</span>
            <IndianRupee className="h-4 w-4" />
          </div>
          <p className="text-xl sm:text-2xl font-black text-purple-900 dark:text-purple-100">
            {formatPrice(totalDeliveredMoneyToday)}
          </p>
          <p className="text-[10px] text-purple-700/80 dark:text-purple-400 font-bold">
            Delivered value today
          </p>
        </div>

        {/* Card 4: Online Bank Collection */}
        <div className="bg-gradient-to-br from-emerald-50 to-emerald-100/50 dark:from-emerald-950/30 dark:to-emerald-900/10 border border-emerald-200/60 dark:border-emerald-800/30 p-3.5 rounded-2xl space-y-1.5">
          <div className="flex items-center justify-between text-emerald-700 dark:text-emerald-300">
            <span className="text-[10px] font-black uppercase tracking-wider">Store Bank</span>
            <TrendingUp className="h-4 w-4" />
          </div>
          <p className="text-xl sm:text-2xl font-black text-emerald-900 dark:text-emerald-100">
            {formatPrice(summary?.onlineRevenueToday || 0)}
          </p>
          <p className="text-[10px] text-emerald-700/80 dark:text-emerald-400 font-bold">
            Directly in Bank (UPI)
          </p>
        </div>

        {/* Card 5: Pending in Rider Pockets */}
        <div className="bg-gradient-to-br from-amber-50 to-amber-100/50 dark:from-amber-950/30 dark:to-amber-900/10 border border-amber-200/60 dark:border-amber-800/30 p-3.5 rounded-2xl space-y-1.5">
          <div className="flex items-center justify-between text-amber-700 dark:text-amber-300">
            <span className="text-[10px] font-black uppercase tracking-wider">Pending Cash</span>
            <DollarSign className="h-4 w-4" />
          </div>
          <p className="text-xl sm:text-2xl font-black text-amber-900 dark:text-amber-100">
            {formatPrice(summary?.pendingRiderCash || 0)}
          </p>
          <p className="text-[10px] text-amber-700/80 dark:text-amber-400 font-bold">
            Rider pockets to collect
          </p>
        </div>

        {/* Card 6: Cash Deposited Today */}
        <div className="bg-gradient-to-br from-blue-50 to-blue-100/50 dark:from-blue-950/30 dark:to-blue-900/10 border border-blue-200/60 dark:border-blue-800/30 p-3.5 rounded-2xl space-y-1.5">
          <div className="flex items-center justify-between text-blue-700 dark:text-blue-300">
            <span className="text-[10px] font-black uppercase tracking-wider">Deposited</span>
            <ShieldCheck className="h-4 w-4" />
          </div>
          <p className="text-xl sm:text-2xl font-black text-blue-900 dark:text-blue-100">
            {formatPrice(summary?.totalCashDepositedToday || 0)}
          </p>
          <p className="text-[10px] text-blue-700/80 dark:text-blue-400 font-bold">
            Settled to Admin today
          </p>
        </div>
      </div>

      {/* Rider Cash Table Section */}
      <div className="bg-card border border-border rounded-3xl shadow-xs overflow-hidden">
        <div className="p-4 sm:p-5 border-b border-border flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex items-center gap-2 flex-wrap">
            <h2 className="text-base font-bold text-text-primary flex items-center gap-2 mr-2">
              <UserCheck className="h-4 w-4 text-primary" />
              Delivery Partners ({riders.length})
            </h2>

            {/* Quick Filter Tabs */}
            <div className="flex items-center gap-1 bg-muted/60 p-1 rounded-xl text-xs">
              <button
                type="button"
                onClick={() => setFilterTab('all')}
                className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                  filterTab === 'all'
                    ? 'bg-card text-text-primary shadow-2xs font-extrabold'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                All ({riders.length})
              </button>
              <button
                type="button"
                onClick={() => setFilterTab('needs-settle')}
                className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                  filterTab === 'needs-settle'
                    ? 'bg-card text-amber-600 shadow-2xs font-extrabold'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                ⚠️ Settle Cash ({needsSettleCount})
              </button>
              <button
                type="button"
                onClick={() => setFilterTab('free')}
                className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                  filterTab === 'free'
                    ? 'bg-card text-emerald-600 shadow-2xs font-extrabold'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                🟢 Free ({freeRidersCount})
              </button>
              <button
                type="button"
                onClick={() => setFilterTab('busy')}
                className={`px-2.5 py-1 rounded-lg font-bold transition-all cursor-pointer ${
                  filterTab === 'busy'
                    ? 'bg-card text-indigo-600 shadow-2xs font-extrabold'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                🛵 Busy ({busyRidersCount})
              </button>
            </div>
          </div>

          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
            <input
              type="text"
              placeholder="Search rider name or phone..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 bg-muted/30 border border-border rounded-xl text-xs font-medium focus:outline-none focus:border-primary"
            />
          </div>
        </div>

        {filteredRiders.length === 0 ? (
          <div className="p-12 text-center text-text-muted space-y-2">
            <p className="text-sm font-bold">No delivery riders found</p>
            <p className="text-xs">Ensure users are assigned the DELIVERY role for this store hub.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-muted/40 text-text-secondary uppercase text-[10px] tracking-wider font-extrabold border-b border-border">
                <tr>
                  <th className="py-3 px-4">Rider Details</th>
                  <th className="py-3 px-4">Work &amp; Trips</th>
                  <th className="py-3 px-4">Money Handled</th>
                  <th className="py-3 px-4">Cash in Pocket (COD)</th>
                  <th className="py-3 px-4">Today Deposited</th>
                  <th className="py-3 px-4 text-right">Settlement Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {filteredRiders.map((r) => {
                  const percentUsed = Math.min(100, Math.round((r.cashInHand / r.cashLimit) * 100))
                  const isLocked = r.cashInHand >= r.cashLimit
                  const isWarning = r.cashInHand >= r.cashLimit * 0.75
                  const activeCount = r.activeOrdersCount || 0

                  return (
                    <tr key={r.id} className="hover:bg-muted/20 transition-colors">
                      {/* Rider Details with Call & WhatsApp Actions */}
                      <td className="py-3.5 px-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-primary/10 text-primary font-black flex items-center justify-center text-sm border border-primary/20 shrink-0">
                            {r.name.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <div className="flex items-center gap-1.5 flex-wrap">
                              <p className="font-bold text-text-primary">{r.name}</p>
                              <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-bold bg-primary/10 text-primary border border-primary/20">
                                🏢 {r.storeName || (r.assignedStoreId ? (r.assignedStoreId.replace(/^hub-/, '').replace(/[-_]/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()) + ' Hub') : 'Store Hub')}
                              </span>
                            </div>
                            <div className="flex items-center gap-2 mt-1">
                              <a
                                href={`tel:${r.phone}`}
                                className="inline-flex items-center gap-1 text-[10px] text-text-secondary hover:text-primary font-bold transition-colors"
                                title="Call Rider"
                              >
                                <Phone className="h-3 w-3 text-primary" /> {r.phone}
                              </a>
                              {r.phone && (
                                <button
                                  type="button"
                                  onClick={() => handleWhatsAppRider(r)}
                                  className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 text-[9px] font-bold transition-colors cursor-pointer"
                                  title="WhatsApp Rider"
                                >
                                  <MessageSquare className="h-2.5 w-2.5" />
                                  <span>WhatsApp</span>
                                </button>
                              )}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Work & Trips Column */}
                      <td className="py-3.5 px-4">
                        <div className="space-y-1">
                          <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9px] font-black uppercase ${
                            activeCount === 0
                              ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30'
                              : 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/30'
                          }`}>
                            <span className={`h-1.5 w-1.5 rounded-full ${activeCount === 0 ? 'bg-emerald-500' : 'bg-amber-500 animate-pulse'}`} />
                            {activeCount === 0 ? '🟢 Free (0 active)' : `🟡 Busy (${activeCount} active)`}
                          </span>
                          <p className="text-[11px] font-bold text-text-primary">
                            {r.todayTotalOrdersCount || 0} Total Deliveries
                          </p>
                          <p className="text-[10px] text-text-muted">
                            {r.todayCodOrdersCount} Cash • {r.todayOnlineOrdersCount || 0} Online
                          </p>
                        </div>
                      </td>

                      {/* Money Handled Column */}
                      <td className="py-3.5 px-4">
                        <div>
                          <p className="font-black text-sm text-text-primary">
                            {formatPrice(r.todayTotalDeliveredMoney || 0)}
                          </p>
                          <p className="text-[10px] text-emerald-700 dark:text-emerald-400 font-bold">
                            📱 {formatPrice(r.todayOnlineTotal || 0)} Direct Bank
                          </p>
                          <p className="text-[9.5px] text-amber-700 dark:text-amber-400 font-semibold">
                            💵 {formatPrice(r.todayCodTotal)} COD Collected
                          </p>
                        </div>
                      </td>

                      {/* Cash in Pocket (COD) & Limit Status */}
                      <td className="py-3.5 px-4 min-w-[150px]">
                        <div className="space-y-1">
                          <div className="flex items-baseline justify-between">
                            <span className={`text-sm font-black ${
                              r.cashInHand > 0 ? 'text-amber-600 dark:text-amber-400' : 'text-emerald-600 dark:text-emerald-400'
                            }`}>
                              {formatPrice(r.cashInHand)}
                            </span>
                            {isLocked && (
                              <span className="text-[9px] bg-danger/10 text-danger px-1.5 py-0.2 rounded font-black flex items-center gap-0.5">
                                <Lock className="h-2.5 w-2.5" /> LOCKED
                              </span>
                            )}
                          </div>
                          <div className="flex justify-between text-[10px] font-bold text-text-muted">
                            <span>{percentUsed}% of {formatPrice(r.cashLimit)} limit</span>
                          </div>
                          <div className="w-full h-2 bg-muted rounded-full overflow-hidden">
                            <div
                              className={`h-full transition-all duration-300 ${
                                isLocked ? 'bg-danger' : (isWarning ? 'bg-amber-500' : 'bg-emerald-500')
                              }`}
                              style={{ width: `${percentUsed}%` }}
                            />
                          </div>
                        </div>
                      </td>

                      {/* Today Deposited */}
                      <td className="py-3.5 px-4">
                        <p className="font-black text-emerald-600 dark:text-emerald-400 text-sm">
                          {formatPrice(r.todayDepositedTotal)}
                        </p>
                        <p className="text-[10px] text-text-muted">Handed to Admin</p>
                      </td>

                      {/* Settlement Action */}
                      <td className="py-3.5 px-4 text-right">
                        <button
                          onClick={() => handleOpenSettleModal(r)}
                          className="bg-primary text-white hover:bg-primary-dark font-extrabold text-xs px-3.5 py-1.5 rounded-xl shadow-xs transition-all cursor-pointer inline-flex items-center gap-1.5 active:scale-95"
                        >
                          <CheckCircle2 className="h-3.5 w-3.5" />
                          <span>Settle Cash</span>
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Recent Cash Deposits Ledger */}
      <div className="bg-card border border-border rounded-3xl shadow-xs p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-bold text-text-primary flex items-center gap-2">
            <History className="h-4 w-4 text-primary" />
            Recent Cash Deposit Log
          </h2>

          {recentDeposits.length > 0 && (
            <button
              onClick={handleClearAllDeposits}
              className="text-[11px] font-bold text-rose-600 hover:text-rose-700 bg-rose-500/10 hover:bg-rose-500/20 px-2.5 py-1 rounded-xl transition-all flex items-center gap-1 cursor-pointer border border-rose-500/20"
              title="Delete all cash deposit logs"
            >
              <Trash2 className="h-3 w-3" />
              <span>Clear Logs</span>
            </button>
          )}
        </div>

        {recentDeposits.length === 0 ? (
          <p className="text-xs text-text-muted">No cash deposits recorded yet today.</p>
        ) : (
          <div className="space-y-2">
            {recentDeposits.map((d) => (
              <div key={d.id} className="flex items-center justify-between bg-muted/20 border border-border/40 p-3 rounded-2xl text-xs group">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 flex items-center justify-center shrink-0">
                    <ArrowDownRight className="h-4 w-4" />
                  </div>
                  <div>
                    <p className="font-bold text-text-primary">
                      Received <span className="text-emerald-600 dark:text-emerald-400 font-black">{formatPrice(d.amount)}</span> from {d.riderName}
                    </p>
                    <p className="text-[10px] text-text-muted">
                      Accepted by {d.adminName} • {formatOrderTime(d.createdAt)}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[10px] bg-accent/10 text-accent font-bold px-2 py-0.5 rounded border border-accent/20">
                    {d.notes || 'Handover'}
                  </span>
                  <button
                    onClick={() => handleDeleteDeposit(d.id)}
                    className="p-1.5 text-text-muted hover:text-rose-600 hover:bg-rose-500/10 rounded-lg transition-colors cursor-pointer"
                    title="Delete this log"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Settle Cash Modal */}
      <AnimatePresence>
        {selectedRider && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-card border border-border w-full max-w-md rounded-3xl p-6 shadow-2xl space-y-5"
            >
              <div className="flex items-center justify-between border-b border-border pb-4">
                <div>
                  <h3 className="text-lg font-black text-text-primary">Settle Cash Handover</h3>
                  <p className="text-xs text-text-muted mt-0.5">
                    Recording cash received from {selectedRider.name}
                  </p>
                </div>
                <button
                  onClick={() => setSelectedRider(null)}
                  className="text-text-muted hover:text-text-primary text-xl font-bold px-2"
                >
                  ✕
                </button>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="bg-amber-50 dark:bg-amber-950/30 border-2 border-amber-400/40 p-3.5 rounded-2xl">
                  <p className="text-[10px] font-black text-amber-800 dark:text-amber-300 uppercase tracking-wider">💵 Cash to Collect</p>
                  <p className="text-2xl font-black text-amber-900 dark:text-amber-100 mt-0.5">{formatPrice(selectedRider.cashInHand)}</p>
                  <p className="text-[10px] text-amber-700 dark:text-amber-400 font-bold mt-1">
                    {selectedRider.todayCodOrdersCount} Cash Orders • Rider se lo
                  </p>
                </div>
                <div className="bg-emerald-50 dark:bg-emerald-950/30 border-2 border-emerald-400/40 p-3.5 rounded-2xl">
                  <p className="text-[10px] font-black text-emerald-800 dark:text-emerald-300 uppercase tracking-wider">📱 Online / UPI (Bank)</p>
                  <p className="text-2xl font-black text-emerald-900 dark:text-emerald-100 mt-0.5">{formatPrice(selectedRider.todayOnlineTotal || 0)}</p>
                  <p className="text-[10px] text-emerald-700 dark:text-emerald-400 font-bold mt-1">
                    {selectedRider.todayOnlineOrdersCount || 0} QR Orders • Bank me check karo
                  </p>
                </div>
              </div>

              <div className="text-center text-[11px] font-bold text-text-muted">
                Total Deliveries Today: <strong className="text-text-primary">{selectedRider.todayCodOrdersCount + (selectedRider.todayOnlineOrdersCount || 0)} Orders</strong> (Value: {formatPrice((selectedRider.todayCodTotal || 0) + (selectedRider.todayOnlineTotal || 0))})
              </div>

              <form onSubmit={handleConfirmSettlement} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold text-text-secondary mb-1">
                    Amount Received from Rider (₹)
                  </label>
                  <input
                    type="number"
                    step="any"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    placeholder="e.g. 1450"
                    className="w-full px-4 py-2.5 bg-muted/30 border border-border rounded-xl text-sm font-black text-text-primary focus:outline-none focus:border-primary"
                    required
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-text-secondary mb-1">
                    Notes / Remarks (Optional)
                  </label>
                  <input
                    type="text"
                    value={depositNotes}
                    onChange={(e) => setDepositNotes(e.target.value)}
                    placeholder="e.g. Evening shift cash deposit"
                    className="w-full px-4 py-2.5 bg-muted/30 border border-border rounded-xl text-xs font-medium text-text-primary focus:outline-none focus:border-primary"
                  />
                </div>

                <div className="pt-2 flex gap-3">
                  <button
                    type="button"
                    onClick={() => setSelectedRider(null)}
                    className="w-1/2 py-2.5 rounded-xl border border-border text-xs font-bold hover:bg-muted transition-colors cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="w-1/2 py-2.5 rounded-xl bg-primary text-white font-extrabold text-xs hover:bg-primary-dark transition-all shadow-md cursor-pointer disabled:opacity-50"
                  >
                    {isSubmitting ? 'Processing...' : 'Confirm Handover ✅'}
                  </button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  )
}
