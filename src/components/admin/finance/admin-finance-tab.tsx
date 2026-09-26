'use client'

import { useState, useEffect, useMemo } from 'react'
import {
  IndianRupee,
  Calendar,
  RefreshCw,
  Download,
  Search,
  CheckCircle2,
  Clock,
  AlertCircle,
  Truck,
  ArrowUpRight,
  Wallet,
  Building2,
  QrCode,
  Check,
  ChevronRight,
  UserCheck,
  ShieldCheck,
  CreditCard,
  Banknote,
  RotateCcw,
} from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'

interface FinanceSummary {
  onlineBankTotal: number
  onlineOrderCount: number
  counterCashTotal: number
  counterCashCount: number
  riderCashTotal: number
  riderCashCount: number
  pendingCodTotal: number
  pendingCodCount: number
  pendingOnlineTotal: number
  pendingOnlineCount: number
  totalReconciled: number
  totalOrdersCount: number
}

interface RiderSummary {
  id: string
  name: string
  phone: string
  cashInHand: number
  todayDeliveredCount: number
  todayDeliveredTotal: number
}

interface FinanceTransaction {
  id: string
  readableId: string
  createdAt: string
  timeStr: string
  total: number
  customerName: string
  customerPhone: string
  shopName: string
  paymentMethod: string
  paymentStatus: string
  orderStatus: string
  category: string
  verifiedBy: string
  riderName: string | null
  cashSettled: boolean
  cashSettledAt: string | null
}

interface FinanceData {
  date: string
  isToday: boolean
  summary: FinanceSummary
  riders: RiderSummary[]
  transactions: FinanceTransaction[]
}

interface AdminFinanceTabProps {
  storeId?: string | null
}

export function AdminFinanceTab({ storeId }: AdminFinanceTabProps) {
  const [data, setData] = useState<FinanceData | null>(null)
  const [loading, setLoading] = useState(true)
  const [selectedDate, setSelectedDate] = useState<string>('')
  const [searchQuery, setSearchQuery] = useState('')
  const [activeFilter, setActiveFilter] = useState<'ALL' | 'ONLINE' | 'RIDER_CASH' | 'COUNTER_CASH' | 'PENDING'>('ALL')
  const [settlingRiderId, setSettlingRiderId] = useState<string | null>(null)

  // Fetch Finance Data
  const fetchFinanceData = async (dateOverride?: string) => {
    setLoading(true)
    try {
      const targetDate = dateOverride !== undefined ? dateOverride : selectedDate
      const params = new URLSearchParams()
      if (targetDate) params.set('date', targetDate)
      if (storeId && storeId.toLowerCase() !== 'all') params.set('storeId', storeId)

      // Try Next.js route first
      let res = await fetch(`/api/admin/finance/daily?${params.toString()}`)
      if (!res.ok) {
        // Fallback to FastAPI
        res = await fetch(`/api/admin/finance/daily?${params.toString()}`)
      }

      if (!res.ok) throw new Error('Failed to load finance data')
      const json: FinanceData = await res.json()
      setData(json)
      if (!selectedDate && json.date) {
        setSelectedDate(json.date)
      }
    } catch (err: any) {
      console.error('Finance tab load error:', err)
      toast.error(err.message || 'Error loading finance reconciliation')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchFinanceData()
  }, [storeId])

  // Handle Date Preset Changes
  const handleDateChange = (newDate: string) => {
    setSelectedDate(newDate)
    fetchFinanceData(newDate)
  }

  const setPresetToday = () => {
    const todayStr = new Date().toISOString().slice(0, 10)
    handleDateChange(todayStr)
  }

  const setPresetYesterday = () => {
    const yest = new Date(Date.now() - 86400000).toISOString().slice(0, 10)
    handleDateChange(yest)
  }

  // 1-Click Settle Rider Cash Handover
  const handleSettleRiderCash = async (rider: RiderSummary) => {
    if (rider.cashInHand <= 0) {
      toast.info(`${rider.name} ke paas koi cash pending nahi hai.`)
      return
    }

    const confirm = window.confirm(
      `Confirm Cash Handover:\n\nKya aapne Rider "${rider.name}" se ${formatPrice(rider.cashInHand)} cash collect kar liya hai?`
    )
    if (!confirm) return

    setSettlingRiderId(rider.id)
    try {
      const res = await fetch('/api/admin/rider-cash', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          riderId: rider.id,
          amount: rider.cashInHand,
          notes: `Day End Settlement (${selectedDate})`,
        }),
      })

      if (!res.ok) throw new Error('Settlement failed')
      toast.success(`${rider.name} ka ${formatPrice(rider.cashInHand)} cash counter me deposit ho gaya! ✅`)
      fetchFinanceData()
    } catch (err: any) {
      toast.error(err.message || 'Failed to settle rider cash')
    } finally {
      setSettlingRiderId(null)
    }
  }

  // Filtered Transactions
  const filteredTransactions = useMemo(() => {
    if (!data?.transactions) return []

    return data.transactions.filter((tx) => {
      // Category Filter
      if (activeFilter === 'ONLINE' && tx.category !== 'ONLINE_BANK') return false
      if (activeFilter === 'RIDER_CASH' && tx.category !== 'RIDER_CASH') return false
      if (activeFilter === 'COUNTER_CASH' && tx.category !== 'COUNTER_CASH') return false
      if (activeFilter === 'PENDING' && !tx.category.startsWith('PENDING')) return false

      // Search Query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim()
        const matchId = tx.readableId.toLowerCase().includes(q)
        const matchCustomer = tx.customerName.toLowerCase().includes(q)
        const matchPhone = tx.customerPhone.includes(q)
        const matchStore = tx.shopName.toLowerCase().includes(q)
        const matchVerifier = tx.verifiedBy.toLowerCase().includes(q)
        if (!matchId && !matchCustomer && !matchPhone && !matchStore && !matchVerifier) {
          return false
        }
      }

      return true
    })
  }, [data, activeFilter, searchQuery])

  // Export CSV
  const handleExportCSV = () => {
    if (!data?.transactions || data.transactions.length === 0) {
      toast.error('No transactions to export')
      return
    }

    const headers = [
      'Time',
      'Order ID',
      'Store',
      'Customer',
      'Phone',
      'Amount (INR)',
      'Payment Mode',
      'Payment Status',
      'Order Status',
      'Verified / Collected By',
      'Cash Settled',
    ]

    const rows = data.transactions.map((tx) => [
      `"${tx.timeStr}"`,
      `"#${tx.readableId}"`,
      `"${tx.shopName}"`,
      `"${tx.customerName}"`,
      `"${tx.customerPhone}"`,
      tx.total,
      `"${tx.paymentMethod}"`,
      `"${tx.paymentStatus}"`,
      `"${tx.orderStatus}"`,
      `"${tx.verifiedBy}"`,
      tx.cashSettled ? 'YES' : 'NO',
    ])

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n')
    const encodedUri = encodeURI(csvContent)
    const link = document.createElement('a')
    link.setAttribute('href', encodedUri)
    link.setAttribute('download', `FastKirana_Finance_${selectedDate || 'today'}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    toast.success('Finance CSV report downloaded!')
  }

  const summary = data?.summary || {
    onlineBankTotal: 0,
    onlineOrderCount: 0,
    counterCashTotal: 0,
    counterCashCount: 0,
    riderCashTotal: 0,
    riderCashCount: 0,
    pendingCodTotal: 0,
    pendingCodCount: 0,
    pendingOnlineTotal: 0,
    pendingOnlineCount: 0,
    totalReconciled: 0,
    totalOrdersCount: 0,
  }

  return (
    <div className="space-y-6 animate-in fade-in duration-200">
      {/* ── HEADER & DATE FILTERS ── */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 bg-card/60 backdrop-blur-md p-4 md:p-6 rounded-3xl border border-border/80 shadow-xs">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-600 dark:text-emerald-400">
              <IndianRupee className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">
                Finance & Cash Reconciliation
              </h2>
              <p className="text-xs text-text-secondary font-medium">
                Realtime Bank / Cashfree, Counter Galla & Rider Cash Ledger
              </p>
            </div>
          </div>
        </div>

        {/* Date Controls */}
        <div className="flex flex-wrap items-center gap-2 self-stretch md:self-auto">
          <div className="flex items-center bg-background border border-border rounded-2xl p-1 shadow-2xs">
            <button
              type="button"
              onClick={setPresetToday}
              className={`px-3 py-1.5 text-xs font-bold rounded-xl transition-all ${
                data?.isToday
                  ? 'bg-emerald-600 text-white shadow-xs'
                  : 'text-text-secondary hover:text-text-primary hover:bg-muted'
              }`}
            >
              Aaj (Today)
            </button>
            <button
              type="button"
              onClick={setPresetYesterday}
              className={`px-3 py-1.5 text-xs font-bold rounded-xl transition-all ${
                !data?.isToday && selectedDate === new Date(Date.now() - 86400000).toISOString().slice(0, 10)
                  ? 'bg-emerald-600 text-white shadow-xs'
                  : 'text-text-secondary hover:text-text-primary hover:bg-muted'
              }`}
            >
              Kal (Yesterday)
            </button>
          </div>

          <div className="flex items-center gap-1.5 bg-background border border-border rounded-2xl px-3 py-1.5 shadow-2xs">
            <Calendar className="w-3.5 h-3.5 text-text-secondary" />
            <input
              type="date"
              value={selectedDate}
              onChange={(e) => handleDateChange(e.target.value)}
              className="bg-transparent text-xs font-bold text-text-primary outline-hidden cursor-pointer"
            />
          </div>

          <button
            type="button"
            onClick={() => fetchFinanceData()}
            disabled={loading}
            className="p-2.5 rounded-2xl border border-border bg-background hover:bg-muted text-text-secondary hover:text-text-primary transition-all active:scale-95 shadow-2xs cursor-pointer"
            title="Refresh Data"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-emerald-600' : ''}`} />
          </button>

          <button
            type="button"
            onClick={handleExportCSV}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-2xl bg-text-primary text-background font-bold text-xs hover:opacity-90 transition-all shadow-xs cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Export CSV</span>
          </button>
        </div>
      </div>

      {/* ── 3-PILLAR SUMMARY STAT CARDS ── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* PILLAR 1: Online in Bank / Cashfree */}
        <div className="relative overflow-hidden bg-gradient-to-br from-emerald-500/10 via-emerald-500/5 to-transparent border border-emerald-500/25 rounded-3xl p-5 shadow-xs">
          <div className="flex items-start justify-between">
            <div className="p-3 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-600 dark:text-emerald-400">
              <CreditCard className="w-6 h-6" />
            </div>
            <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wider bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 px-2.5 py-1 rounded-full border border-emerald-500/30">
              <Check className="w-3 h-3" /> Bank / PG Direct
            </span>
          </div>
          <div className="mt-4">
            <p className="text-xs font-bold text-text-secondary uppercase tracking-wider">
              1. Online in Bank (Cashfree & UPI)
            </p>
            <h3 className="text-3xl font-black text-emerald-600 dark:text-emerald-400 mt-1">
              {formatPrice(summary.onlineBankTotal)}
            </h3>
            <p className="text-xs font-semibold text-text-secondary mt-1">
              {summary.onlineOrderCount} orders paid digitally & verified
            </p>
          </div>
        </div>

        {/* PILLAR 2: Counter Cash (Galla) */}
        <div className="relative overflow-hidden bg-gradient-to-br from-blue-500/10 via-blue-500/5 to-transparent border border-blue-500/25 rounded-3xl p-5 shadow-xs">
          <div className="flex items-start justify-between">
            <div className="p-3 rounded-2xl bg-blue-500/15 border border-blue-500/30 text-blue-600 dark:text-blue-400">
              <Banknote className="w-6 h-6" />
            </div>
            <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wider bg-blue-500/20 text-blue-700 dark:text-blue-300 px-2.5 py-1 rounded-full border border-blue-500/30">
              <Building2 className="w-3 h-3" /> In Safe / Register
            </span>
          </div>
          <div className="mt-4">
            <p className="text-xs font-bold text-text-secondary uppercase tracking-wider">
              2. Counter Cash (Galla)
            </p>
            <h3 className="text-3xl font-black text-blue-600 dark:text-blue-400 mt-1">
              {formatPrice(summary.counterCashTotal)}
            </h3>
            <p className="text-xs font-semibold text-text-secondary mt-1">
              {summary.counterCashCount} orders cash settled at counter
            </p>
          </div>
        </div>

        {/* PILLAR 3: Cash with Riders */}
        <div className="relative overflow-hidden bg-gradient-to-br from-amber-500/10 via-amber-500/5 to-transparent border border-amber-500/25 rounded-3xl p-5 shadow-xs">
          <div className="flex items-start justify-between">
            <div className="p-3 rounded-2xl bg-amber-500/15 border border-amber-500/30 text-amber-600 dark:text-amber-400">
              <Truck className="w-6 h-6" />
            </div>
            <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wider bg-amber-500/20 text-amber-700 dark:text-amber-300 px-2.5 py-1 rounded-full border border-amber-500/30">
              <Clock className="w-3 h-3" /> With Delivery Fleet
            </span>
          </div>
          <div className="mt-4">
            <p className="text-xs font-bold text-text-secondary uppercase tracking-wider">
              3. Cash with Riders (Unsettled)
            </p>
            <h3 className="text-3xl font-black text-amber-600 dark:text-amber-400 mt-1">
              {formatPrice(summary.riderCashTotal)}
            </h3>
            <p className="text-xs font-semibold text-text-secondary mt-1">
              {summary.riderCashCount} delivered COD orders in rider hands
            </p>
          </div>
        </div>
      </div>

      {/* ── TOTAL DAY RECONCILED BANNER ── */}
      <div className="bg-text-primary text-background p-5 md:p-6 rounded-3xl shadow-md flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <span className="text-[10px] font-black uppercase tracking-widest text-background/70">
            Total Reconciled Day Collection ({selectedDate || 'Today'})
          </span>
          <h2 className="text-3xl md:text-4xl font-black tracking-tight mt-0.5">
            {formatPrice(summary.totalReconciled)}
          </h2>
          <p className="text-xs font-medium text-background/80 mt-1">
            Bank ({formatPrice(summary.onlineBankTotal)}) + Galla ({formatPrice(summary.counterCashTotal)}) + Rider Cash ({formatPrice(summary.riderCashTotal)})
          </p>
        </div>

        {summary.pendingCodTotal > 0 && (
          <div className="bg-background/10 border border-background/20 px-4 py-2.5 rounded-2xl text-left md:text-right">
            <p className="text-[11px] font-bold text-background/90 uppercase tracking-wide">
              🛵 COD on the way (Delivering)
            </p>
            <p className="text-lg font-black text-background">
              {formatPrice(summary.pendingCodTotal)} <span className="text-xs font-semibold opacity-80">({summary.pendingCodCount} orders)</span>
            </p>
          </div>
        )}
      </div>

      {/* ── RIDER CASH HANDOVER (1-CLICK SETTLE) ── */}
      {data?.riders && data.riders.length > 0 && (
        <div className="bg-card border border-border rounded-3xl p-5 md:p-6 shadow-xs space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-black text-text-primary flex items-center gap-2">
                <Wallet className="w-4 h-4 text-emerald-600" />
                Delivery Riders Cash Handover
              </h3>
              <p className="text-xs text-text-secondary font-medium">
                End-of-shift physical cash collection from delivery boys
              </p>
            </div>
            <span className="text-xs font-bold bg-muted px-3 py-1 rounded-xl text-text-secondary">
              {data.riders.length} Active Rider(s)
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {data.riders.map((r) => (
              <div
                key={r.id}
                className="bg-background border border-border/80 rounded-2xl p-4 flex items-center justify-between gap-3 shadow-2xs hover:border-emerald-500/30 transition-all"
              >
                <div>
                  <h4 className="font-bold text-sm text-text-primary">{r.name}</h4>
                  <p className="text-xs text-text-secondary font-medium mt-0.5">{r.phone || 'No phone'}</p>
                  <div className="flex items-center gap-2 mt-2">
                    <span className="text-[11px] font-bold text-text-secondary">
                      Delivered: <strong className="text-text-primary">{r.todayDeliveredCount}</strong>
                    </span>
                    <span className="text-[11px] font-black text-amber-600 dark:text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded-md">
                      Cash: {formatPrice(r.cashInHand)}
                    </span>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => handleSettleRiderCash(r)}
                  disabled={settlingRiderId === r.id || r.cashInHand <= 0}
                  className={`px-3 py-2 rounded-xl text-xs font-black transition-all active:scale-95 cursor-pointer shadow-2xs shrink-0 ${
                    r.cashInHand > 0
                      ? 'bg-emerald-600 text-white hover:bg-emerald-700 shadow-emerald-600/20'
                      : 'bg-muted text-text-secondary opacity-60 cursor-not-allowed'
                  }`}
                >
                  {settlingRiderId === r.id ? 'Settling...' : '✓ Settle Cash'}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── REALTIME TRANSACTION LEDGER TABLE ── */}
      <div className="bg-card border border-border rounded-3xl p-5 md:p-6 shadow-xs space-y-4">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-3">
          <div>
            <h3 className="text-base font-black text-text-primary flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-emerald-600" />
              Day Transaction Ledger & Verified By
            </h3>
            <p className="text-xs text-text-secondary font-medium">
              Every order with payment method and verification trail
            </p>
          </div>

          {/* Search Input */}
          <div className="relative w-full md:w-72">
            <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary" />
            <input
              type="text"
              placeholder="Search Order #, customer, UTR..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 text-xs bg-background border border-border rounded-xl text-text-primary font-medium outline-hidden focus:border-emerald-500"
            />
          </div>
        </div>

        {/* Filter Chips */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1 text-xs">
          <button
            type="button"
            onClick={() => setActiveFilter('ALL')}
            className={`px-3 py-1.5 rounded-xl font-bold cursor-pointer transition-all ${
              activeFilter === 'ALL'
                ? 'bg-text-primary text-background shadow-xs'
                : 'bg-muted text-text-secondary hover:text-text-primary'
            }`}
          >
            All Orders ({data?.transactions?.length || 0})
          </button>
          <button
            type="button"
            onClick={() => setActiveFilter('ONLINE')}
            className={`px-3 py-1.5 rounded-xl font-bold cursor-pointer transition-all ${
              activeFilter === 'ONLINE'
                ? 'bg-emerald-600 text-white shadow-xs'
                : 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-500/20'
            }`}
          >
            📱 Online Bank ({summary.onlineOrderCount})
          </button>
          <button
            type="button"
            onClick={() => setActiveFilter('RIDER_CASH')}
            className={`px-3 py-1.5 rounded-xl font-bold cursor-pointer transition-all ${
              activeFilter === 'RIDER_CASH'
                ? 'bg-amber-600 text-white shadow-xs'
                : 'bg-amber-500/10 text-amber-700 dark:text-amber-300 hover:bg-amber-500/20'
            }`}
          >
            🛵 Rider Cash ({summary.riderCashCount})
          </button>
          <button
            type="button"
            onClick={() => setActiveFilter('COUNTER_CASH')}
            className={`px-3 py-1.5 rounded-xl font-bold cursor-pointer transition-all ${
              activeFilter === 'COUNTER_CASH'
                ? 'bg-blue-600 text-white shadow-xs'
                : 'bg-blue-500/10 text-blue-700 dark:text-blue-300 hover:bg-blue-500/20'
            }`}
          >
            💵 Counter Galla ({summary.counterCashCount})
          </button>
          {summary.pendingCodCount > 0 && (
            <button
              type="button"
              onClick={() => setActiveFilter('PENDING')}
              className={`px-3 py-1.5 rounded-xl font-bold cursor-pointer transition-all ${
                activeFilter === 'PENDING'
                  ? 'bg-purple-600 text-white shadow-xs'
                  : 'bg-purple-500/10 text-purple-700 dark:text-purple-300 hover:bg-purple-500/20'
              }`}
            >
              ⏳ On The Way ({summary.pendingCodCount})
            </button>
          )}
        </div>

        {/* Table View */}
        <div className="overflow-x-auto rounded-2xl border border-border">
          <table className="w-full text-left text-xs">
            <thead className="bg-muted/50 text-text-secondary uppercase text-[10px] font-black tracking-wider border-b border-border">
              <tr>
                <th className="px-4 py-3">Time</th>
                <th className="px-4 py-3">Order #</th>
                <th className="px-4 py-3">Store / Outlet</th>
                <th className="px-4 py-3">Customer</th>
                <th className="px-4 py-3 text-right">Amount</th>
                <th className="px-4 py-3">Payment Mode</th>
                <th className="px-4 py-3">Verified By</th>
                <th className="px-4 py-3 text-center">Settlement</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60 font-medium">
              {filteredTransactions.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-4 py-10 text-center text-text-secondary">
                    No transactions found for this date & filter.
                  </td>
                </tr>
              ) : (
                filteredTransactions.map((tx) => (
                  <tr key={tx.id} className="hover:bg-muted/20 transition-colors">
                    <td className="px-4 py-3 font-mono text-[11px] text-text-secondary whitespace-nowrap">
                      {tx.timeStr}
                    </td>
                    <td className="px-4 py-3 font-bold text-text-primary whitespace-nowrap">
                      <span className="font-mono text-emerald-600 dark:text-emerald-400">#{tx.readableId}</span>
                    </td>
                    <td className="px-4 py-3 text-text-secondary whitespace-nowrap">
                      {tx.shopName}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <p className="font-bold text-text-primary leading-none">{tx.customerName}</p>
                      <p className="text-[10px] text-text-secondary mt-0.5">{tx.customerPhone}</p>
                    </td>
                    <td className="px-4 py-3 text-right font-black text-text-primary whitespace-nowrap">
                      {formatPrice(tx.total)}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      {tx.paymentStatus === 'PAID' ? (
                        <span className="inline-flex items-center gap-1 text-[9.5px] font-black uppercase bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 px-2 py-0.5 rounded-md">
                          <CheckCircle2 className="w-2.5 h-2.5" />
                          {tx.paymentMethod} (PAID)
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[9.5px] font-black uppercase bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20 px-2 py-0.5 rounded-md">
                          <Clock className="w-2.5 h-2.5" />
                          {tx.paymentMethod} (PENDING)
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span
                        className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-lg border ${
                          tx.category === 'ONLINE_BANK'
                            ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30'
                            : tx.category === 'RIDER_CASH'
                            ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30'
                            : tx.category === 'COUNTER_CASH'
                            ? 'bg-blue-500/15 text-blue-700 dark:text-blue-300 border-blue-500/30'
                            : 'bg-muted text-text-secondary border-border'
                        }`}
                      >
                        {tx.verifiedBy}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center whitespace-nowrap">
                      {tx.category === 'ONLINE_BANK' ? (
                        <span className="text-[10px] font-bold text-emerald-600 flex items-center justify-center gap-1">
                          <Check className="w-3 h-3" /> In Bank
                        </span>
                      ) : tx.cashSettled ? (
                        <span className="text-[10px] font-bold text-blue-600 flex items-center justify-center gap-1">
                          <Check className="w-3 h-3" /> Counter Safe
                        </span>
                      ) : tx.category === 'RIDER_CASH' ? (
                        <span className="text-[10px] font-bold text-amber-600 flex items-center justify-center gap-1">
                          <Clock className="w-3 h-3" /> In Rider Hand
                        </span>
                      ) : (
                        <span className="text-[10px] font-medium text-text-secondary">
                          Delivering
                        </span>
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
