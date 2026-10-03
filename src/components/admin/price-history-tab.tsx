'use client';
import { apiUrl } from '@/lib/api-url';

import { useState, useEffect, useCallback } from 'react'
import {
  History,
  Search,
  RefreshCw,
  TrendingUp,
  TrendingDown,
  Clock,
  ArrowRight,
  Filter,
  CheckCircle2,
  Store,
  Calendar,
  AlertCircle,
  Sparkles,
} from 'lucide-react'
import Image from 'next/image'
import { toast } from 'sonner'
import { formatPrice, cn } from '@/lib/utils'
import { formatOrderTime } from '@/lib/date-helpers'

interface PriceHistoryRecord {
  id: string
  productId: string
  productName: string
  productImage: string | null
  restaurantName: string | null
  categoryName: string | null
  currentPrice: number
  oldPrice: number
  newPrice: number
  oldMrp: number
  newMrp: number
  priceDiff: number
  percentChange: number
  changeType: string
  changedBy: string
  createdAt: string
}

interface PriceHistoryStats {
  totalRecords: number
  recent24hCount: number
  totalIncreases: number
  totalDecreases: number
}

interface PriceHistoryTabProps {
  storeId?: string | null
}

export function PriceHistoryTab({ storeId }: PriceHistoryTabProps) {
  const [records, setRecords] = useState<PriceHistoryRecord[]>([])
  const [stats, setStats] = useState<PriceHistoryStats>({
    totalRecords: 0,
    recent24hCount: 0,
    totalIncreases: 0,
    totalDecreases: 0,
  })
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [filterType, setFilterType] = useState<'ALL' | 'VENDOR_UPDATE' | 'ADMIN_UPDATE'>('ALL')
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)

  const fetchHistory = useCallback(
    async (showToast = false) => {
      try {
        if (showToast) setRefreshing(true)
        else setLoading(true)

        const params = new URLSearchParams()
        if (searchQuery.trim()) params.set('search', searchQuery.trim())
        if (filterType !== 'ALL') params.set('type', filterType)
        params.set('page', String(page))
        params.set('limit', '30')

        const res = await fetch(`${apiUrl()}/api/admin/price-history?${params.toString()}`)
        if (!res.ok) throw new Error('Failed to load price history')

        const data = await res.json()
        setRecords(data.records || [])
        setStats(
          data.stats || {
            totalRecords: 0,
            recent24hCount: 0,
            totalIncreases: 0,
            totalDecreases: 0,
          }
        )
        setTotalPages(data.pagination?.totalPages || 1)

        if (showToast) {
          toast.success('Price history refreshed!')
        }
      } catch (err: any) {
        console.error('Price history fetch error:', err)
        toast.error('Could not load price change history')
      } finally {
        setLoading(false)
        setRefreshing(false)
      }
    },
    [searchQuery, filterType, page]
  )

  useEffect(() => {
    fetchHistory()
  }, [fetchHistory])

  // Format relative time (e.g. "5m ago", "2h ago", "Yesterday")
  const formatTimeAgo = (dateStr: string) => {
    const diffSec = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000)
    if (diffSec < 60) return 'Just now'
    const diffMin = Math.floor(diffSec / 60)
    if (diffMin < 60) return `${diffMin}m ago`
    const diffHours = Math.floor(diffMin / 60)
    if (diffHours < 24) return `${diffHours}h ago`
    const diffDays = Math.floor(diffHours / 24)
    if (diffDays === 1) return 'Yesterday'
    if (diffDays < 7) return `${diffDays}d ago`
    return new Date(dateStr).toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div className="space-y-6 animate-fade-in max-w-7xl mx-auto pb-12">
      {/* Header Banner */}
      <div className="bg-card border border-border/80 rounded-3xl p-6 sm:p-7 shadow-xs relative overflow-hidden">
        <div className="absolute right-0 top-0 w-80 h-80 bg-gradient-to-bl from-amber-500/10 via-primary/5 to-transparent rounded-full blur-3xl pointer-events-none" />

        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 relative z-10">
          <div className="space-y-1.5">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-700 dark:text-amber-400 text-xs font-bold">
              <History className="w-3.5 h-3.5 text-amber-600 dark:text-amber-400" />
              <span>Audit Trail & Margin Monitor</span>
            </div>
            <h2 className="text-2xl sm:text-3xl font-black text-text-primary tracking-tight">
              Vendor Rate & Price History
            </h2>
            <p className="text-sm text-text-muted max-w-2xl font-medium">
              Real-time audit log of dish and product price updates made by vendors, restaurants, and admins. Tracks old vs. new rates and profit variance.
            </p>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={() => fetchHistory(true)}
              disabled={refreshing || loading}
              className="inline-flex items-center gap-2 px-4 py-2.5 rounded-2xl bg-muted/80 hover:bg-muted text-text-secondary hover:text-text-primary text-xs font-bold transition-all border border-border/70 active:scale-95 cursor-pointer shadow-2xs"
            >
              <RefreshCw className={cn('w-3.5 h-3.5', refreshing && 'animate-spin')} />
              <span>Refresh Log</span>
            </button>
          </div>
        </div>

        {/* Executive Stat Counters */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4 mt-6 pt-6 border-t border-border/60">
          <div className="p-3.5 sm:p-4 rounded-2xl bg-muted/40 border border-border/50">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-text-muted">Total Rate Changes</span>
              <History className="w-4 h-4 text-text-muted" />
            </div>
            <div className="text-2xl font-black text-text-primary mt-1">
              {stats.totalRecords}
            </div>
            <span className="text-[11px] text-text-muted font-medium">All logged updates</span>
          </div>

          <div className="p-3.5 sm:p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-emerald-800 dark:text-emerald-400">Last 24 Hours</span>
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
            </div>
            <div className="text-2xl font-black text-emerald-800 dark:text-emerald-300 mt-1">
              {stats.recent24hCount}
            </div>
            <span className="text-[11px] text-emerald-700 dark:text-emerald-400/80 font-medium">Recent modifications</span>
          </div>

          <div className="p-3.5 sm:p-4 rounded-2xl bg-amber-500/10 border border-amber-500/20">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-amber-800 dark:text-amber-400">Price Hikes</span>
              <TrendingUp className="w-4 h-4 text-amber-600 dark:text-amber-400" />
            </div>
            <div className="text-2xl font-black text-amber-800 dark:text-amber-300 mt-1">
              {stats.totalIncreases}
            </div>
            <span className="text-[11px] text-amber-700 dark:text-amber-400/80 font-medium">Rates increased</span>
          </div>

          <div className="p-3.5 sm:p-4 rounded-2xl bg-blue-500/10 border border-blue-500/20">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-blue-800 dark:text-blue-400">Price Reductions</span>
              <TrendingDown className="w-4 h-4 text-blue-600 dark:text-blue-400" />
            </div>
            <div className="text-2xl font-black text-blue-800 dark:text-blue-300 mt-1">
              {stats.totalDecreases}
            </div>
            <span className="text-[11px] text-blue-700 dark:text-blue-400/80 font-medium">Discounts & cuts</span>
          </div>
        </div>
      </div>

      {/* Control Bar: Search & Filter Tabs */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-card border border-border/80 rounded-2xl p-3 shadow-2xs">
        {/* Search Input */}
        <div className="relative flex-1">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-text-muted" />
          <input
            type="text"
            placeholder="Search dish, product, vendor name, or changer phone..."
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value)
              setPage(1)
            }}
            className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all font-medium"
          />
          {searchQuery && (
            <button
              onClick={() => {
                setSearchQuery('')
                setPage(1)
              }}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-xs font-bold text-text-muted hover:text-text-primary px-1.5 py-0.5 rounded-md hover:bg-muted"
            >
              Clear
            </button>
          )}
        </div>

        {/* Filter Segmented Pills */}
        <div className="flex items-center gap-1.5 p-1 rounded-xl bg-muted/60 border border-border/50 shrink-0">
          <button
            onClick={() => {
              setFilterType('ALL')
              setPage(1)
            }}
            className={cn(
              'px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer',
              filterType === 'ALL'
                ? 'bg-card text-text-primary shadow-xs'
                : 'text-text-secondary hover:text-text-primary'
            )}
          >
            All Logs
          </button>
          <button
            onClick={() => {
              setFilterType('VENDOR_UPDATE')
              setPage(1)
            }}
            className={cn(
              'px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer',
              filterType === 'VENDOR_UPDATE'
                ? 'bg-card text-amber-700 dark:text-amber-400 shadow-xs'
                : 'text-text-secondary hover:text-text-primary'
            )}
          >
            Vendor Updates
          </button>
          <button
            onClick={() => {
              setFilterType('ADMIN_UPDATE')
              setPage(1)
            }}
            className={cn(
              'px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer',
              filterType === 'ADMIN_UPDATE'
                ? 'bg-card text-blue-700 dark:text-blue-400 shadow-xs'
                : 'text-text-secondary hover:text-text-primary'
            )}
          >
            Admin Updates
          </button>
        </div>
      </div>

      {/* Main Content Area */}
      {loading ? (
        <div className="bg-card border border-border/70 rounded-3xl p-16 flex flex-col items-center justify-center text-center">
          <div className="w-12 h-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center animate-pulse mb-3">
            <History className="w-6 h-6 animate-spin" />
          </div>
          <h4 className="text-base font-bold text-text-primary">Loading Price History...</h4>
          <p className="text-xs text-text-muted mt-1">Retrieving recent vendor rate modifications</p>
        </div>
      ) : records.length === 0 ? (
        <div className="bg-card border border-border/70 rounded-3xl p-16 flex flex-col items-center justify-center text-center">
          <div className="w-14 h-14 rounded-2xl bg-muted text-text-muted flex items-center justify-center mb-4">
            <CheckCircle2 className="w-7 h-7 text-emerald-500" />
          </div>
          <h4 className="text-base font-bold text-text-primary">No Price Changes Found</h4>
          <p className="text-xs text-text-muted mt-1 max-w-md">
            {searchQuery
              ? `No price modifications match "${searchQuery}". Try a different search query.`
              : 'Whenever a vendor or restaurant owner updates a dish or product price, the complete audit log will appear here.'}
          </p>
        </div>
      ) : (
        <div className="bg-card border border-border/80 rounded-3xl shadow-xs overflow-hidden">
          {/* Desktop Table View */}
          <div className="hidden md:block overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-border/70 bg-muted/30 text-[11px] font-black uppercase tracking-wider text-text-muted">
                  <th className="py-3.5 px-5">Item / Dish</th>
                  <th className="py-3.5 px-4">Vendor / Outlet</th>
                  <th className="py-3.5 px-4">Rate Change</th>
                  <th className="py-3.5 px-4">Variance</th>
                  <th className="py-3.5 px-4">Updated By</th>
                  <th className="py-3.5 px-5 text-right">Time</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/50 text-sm">
                {records.map((r) => {
                  const isHike = r.priceDiff > 0
                  const isCut = r.priceDiff < 0

                  return (
                    <tr
                      key={r.id}
                      className="hover:bg-muted/30 transition-colors group"
                    >
                      {/* Product details */}
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-xl bg-muted border border-border/60 overflow-hidden relative shrink-0">
                            {r.productImage ? (
                              <Image
                                src={r.productImage}
                                alt={r.productName}
                                fill
                                className="object-cover"
                                sizes="40px"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center text-text-muted text-xs font-bold">
                                FK
                              </div>
                            )}
                          </div>
                          <div>
                            <span className="font-extrabold text-text-primary line-clamp-1 group-hover:text-primary transition-colors">
                              {r.productName}
                            </span>
                            {r.categoryName && (
                              <span className="text-[11px] text-text-muted font-medium block">
                                {r.categoryName}
                              </span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* Outlet */}
                      <td className="py-4 px-4">
                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-muted/60 border border-border/60 text-xs font-semibold text-text-secondary">
                          <Store className="w-3 h-3 text-text-muted" />
                          <span className="line-clamp-1">{r.restaurantName || 'Darkstore Grocery'}</span>
                        </div>
                      </td>

                      {/* Rate Change */}
                      <td className="py-4 px-4">
                        <div className="flex items-center gap-2">
                          <span className="text-xs line-through text-text-muted font-semibold">
                            {formatPrice(r.oldPrice)}
                          </span>
                          <ArrowRight className="w-3.5 h-3.5 text-text-muted" />
                          <span className="text-sm font-black text-text-primary">
                            {formatPrice(r.newPrice)}
                          </span>
                        </div>
                        {r.newMrp !== r.newPrice && (
                          <span className="text-[10.5px] text-text-muted block mt-0.5">
                            MRP: {formatPrice(r.newMrp)}
                          </span>
                        )}
                      </td>

                      {/* Variance & % Badge */}
                      <td className="py-4 px-4">
                        <span
                          className={cn(
                            'inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold border',
                            isHike
                              ? 'bg-amber-500/10 text-amber-700 dark:text-amber-400 border-amber-500/20'
                              : isCut
                              ? 'bg-blue-500/10 text-blue-700 dark:text-blue-400 border-blue-500/20'
                              : 'bg-muted text-text-secondary border-border'
                          )}
                        >
                          {isHike && <TrendingUp className="w-3 h-3" />}
                          {isCut && <TrendingDown className="w-3 h-3" />}
                          <span>
                            {isHike ? '+' : ''}
                            {formatPrice(r.priceDiff)} ({r.percentChange > 0 ? '+' : ''}
                            {r.percentChange}%)
                          </span>
                        </span>
                      </td>

                      {/* Changed By */}
                      <td className="py-4 px-4">
                        <div className="flex flex-col">
                          <span className="text-xs font-bold text-text-primary line-clamp-1">
                            {r.changedBy}
                          </span>
                          <span className="text-[10px] uppercase font-black tracking-wider text-text-muted mt-0.5">
                            {r.changeType === 'VENDOR_UPDATE' ? 'Vendor Portal' : 'Admin Console'}
                          </span>
                        </div>
                      </td>

                      {/* Time */}
                      <td className="py-4 px-5 text-right">
                        <div className="flex flex-col items-end">
                          <span className="text-xs font-bold text-text-secondary">
                            {formatTimeAgo(r.createdAt)}
                          </span>
                          <span className="text-[10.5px] text-text-muted font-medium mt-0.5">
                            {formatOrderTime(r.createdAt)}
                          </span>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {/* Mobile Card List View (Clean & Spacious) */}
          <div className="md:hidden divide-y divide-border/60">
            {records.map((r) => {
              const isHike = r.priceDiff > 0
              const isCut = r.priceDiff < 0

              return (
                <div key={r.id} className="p-4 space-y-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="w-11 h-11 rounded-xl bg-muted border border-border/60 overflow-hidden relative shrink-0">
                        {r.productImage ? (
                          <Image
                            src={r.productImage}
                            alt={r.productName}
                            fill
                            className="object-cover"
                            sizes="44px"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-text-muted text-xs font-bold">
                            FK
                          </div>
                        )}
                      </div>
                      <div>
                        <h4 className="font-extrabold text-sm text-text-primary line-clamp-1">
                          {r.productName}
                        </h4>
                        <div className="flex items-center gap-1.5 text-xs text-text-muted mt-0.5">
                          <Store className="w-3 h-3 text-text-muted" />
                          <span className="line-clamp-1">{r.restaurantName || 'Darkstore Mart'}</span>
                        </div>
                      </div>
                    </div>

                    <span className="text-xs text-text-muted font-semibold shrink-0">
                      {formatTimeAgo(r.createdAt)}
                    </span>
                  </div>

                  {/* Price Transition & Variance Box */}
                  <div className="flex items-center justify-between p-2.5 rounded-xl bg-muted/40 border border-border/50">
                    <div className="flex items-center gap-2">
                      <span className="text-xs line-through text-text-muted font-bold">
                        {formatPrice(r.oldPrice)}
                      </span>
                      <ArrowRight className="w-3.5 h-3.5 text-text-muted" />
                      <span className="text-base font-black text-text-primary">
                        {formatPrice(r.newPrice)}
                      </span>
                    </div>

                    <span
                      className={cn(
                        'inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-black border',
                        isHike
                          ? 'bg-amber-500/10 text-amber-700 dark:text-amber-400 border-amber-500/20'
                          : isCut
                          ? 'bg-blue-500/10 text-blue-700 dark:text-blue-400 border-blue-500/20'
                          : 'bg-muted text-text-secondary border-border'
                      )}
                    >
                      {isHike && <TrendingUp className="w-3 h-3" />}
                      {isCut && <TrendingDown className="w-3 h-3" />}
                      <span>
                        {isHike ? '+' : ''}
                        {formatPrice(r.priceDiff)} ({r.percentChange > 0 ? '+' : ''}
                        {r.percentChange}%)
                      </span>
                    </span>
                  </div>

                  <div className="flex items-center justify-between text-[11px] text-text-muted font-medium pt-1">
                    <span>
                      Changed by: <strong className="text-text-primary">{r.changedBy}</strong>
                    </span>
                    <span className="px-2 py-0.5 rounded bg-muted text-[10px] font-black uppercase">
                      {r.changeType === 'VENDOR_UPDATE' ? 'Vendor' : 'Admin'}
                    </span>
                  </div>
                </div>
              )
            })}
          </div>

          {/* Pagination Controls */}
          {totalPages > 1 && (
            <div className="p-4 border-t border-border/70 flex items-center justify-between bg-muted/20">
              <span className="text-xs text-text-muted font-bold">
                Page {page} of {totalPages}
              </span>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page <= 1}
                  className="px-3 py-1.5 rounded-xl border border-border/70 bg-card text-xs font-bold disabled:opacity-40 disabled:cursor-not-allowed hover:bg-muted cursor-pointer transition-all"
                >
                  Previous
                </button>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page >= totalPages}
                  className="px-3 py-1.5 rounded-xl border border-border/70 bg-card text-xs font-bold disabled:opacity-40 disabled:cursor-not-allowed hover:bg-muted cursor-pointer transition-all"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
