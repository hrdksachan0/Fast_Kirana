'use client'

import { useState, useEffect } from 'react'
import { Calendar, IndianRupee, RefreshCw, CheckCircle, Clock, Plus, Tag } from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'

interface Payout {
  id: string
  startDate: string
  endDate: string
  amount: number
  status: 'PENDING' | 'PAID'
  transactionId: string | null
  paidAt: string | null
  notes: string | null
  createdAt: string
}

interface RestaurantPayoutsLedgerProps {
  isAdmin?: boolean
  type?: 'RESTAURANT' | 'CAFE'
}

export function RestaurantPayoutsLedger({ isAdmin = false, type = 'RESTAURANT' }: RestaurantPayoutsLedgerProps) {
  const [payouts, setPayouts] = useState<Payout[]>([])
  const [loading, setLoading] = useState(true)
  
  // Calculate Payout Form state
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [notes, setNotes] = useState('')
  const [calculating, setCalculating] = useState(false)

  // Settle Modal state
  const [settlingPayoutId, setSettlingPayoutId] = useState<string | null>(null)
  const [transactionId, setTransactionId] = useState('')
  const [settleNotes, setSettleNotes] = useState('')
  const [settling, setSettling] = useState(false)

  const fetchPayouts = async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/admin/payouts?type=${type}`)
      if (!res.ok) throw new Error('Failed to load payouts')
      const data = await res.json()
      setPayouts(data || [])
    } catch (err) {
      toast.error('Could not fetch payouts ledger')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchPayouts()
  }, [type])

  const handleCalculatePayout = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!startDate || !endDate) {
      toast.error('Please select both start and end dates')
      return
    }

    setCalculating(true)
    try {
      const res = await fetch('/api/admin/payouts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ startDate, endDate, notes, type })
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to calculate payout')
      }

      toast.success('Payout calculation completed successfully!')
      setStartDate('')
      setEndDate('')
      setNotes('')
      fetchPayouts()
    } catch (err: any) {
      toast.error(err.message || 'Failed to calculate payout')
      console.error(err)
    } finally {
      setCalculating(false)
    }
  }

  const handleSettlePayout = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!settlingPayoutId) return

    setSettling(true)
    try {
      const res = await fetch('/api/admin/payouts', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: settlingPayoutId,
          transactionId: transactionId.trim() || undefined,
          notes: settleNotes.trim() || undefined
        })
      })

      if (!res.ok) throw new Error('Failed to settle payout')

      toast.success('Payout marked as paid!')
      setSettlingPayoutId(null)
      setTransactionId('')
      setSettleNotes('')
      fetchPayouts()
    } catch (err) {
      toast.error('Failed to settle payout')
      console.error(err)
    } finally {
      setSettling(false)
    }
  }

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    })
  }

  return (
    <div className="space-y-6">
      {/* Calculate Payout Panel (Admin Only) */}
      {isAdmin && (
        <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-4">
          <div className="flex items-center gap-2 border-b border-border/40 pb-3">
            <Plus className="h-5 w-5 text-red-600" />
            <div>
              <h3 className="text-xs font-black text-text-primary uppercase tracking-wider">Calculate {type === 'CAFE' ? 'Cafe' : 'Restaurant'} Payout</h3>
              <p className="text-[10px] text-text-muted mt-0.5">Generate a settlement draft based on delivered {type === 'CAFE' ? 'cafe' : 'restaurant'} orders.</p>
            </div>
          </div>

          <form onSubmit={handleCalculatePayout} className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
            <div className="space-y-1.5">
              <label className="text-[9px] font-black uppercase tracking-wider text-text-secondary">Start Date</label>
              <input
                type="date"
                required
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold text-text-primary"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-[9px] font-black uppercase tracking-wider text-text-secondary">End Date</label>
              <input
                type="date"
                required
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold text-text-primary"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-[9px] font-black uppercase tracking-wider text-text-secondary">Payout Description / Notes</label>
              <input
                type="text"
                placeholder="e.g. Weekly settlement"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold text-text-primary"
              />
            </div>

            <button
              type="submit"
              disabled={calculating}
              className="w-full bg-red-600 hover:bg-red-700 disabled:bg-muted text-white text-xs font-black py-2.5 rounded-xl uppercase tracking-wider transition-all cursor-pointer shadow-md shadow-red-500/10"
            >
              {calculating ? 'Calculating...' : 'Calculate Share'}
            </button>
          </form>
        </div>
      )}

      {/* Settle Modal/Form overlay */}
      {settlingPayoutId && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-fade-in">
          <form onSubmit={handleSettlePayout} className="bg-card border border-border rounded-3xl p-6 max-w-md w-full space-y-4 shadow-xl select-none">
            <div>
              <h3 className="text-sm font-black text-text-primary uppercase tracking-tight">Mark Payout as Settled</h3>
              <p className="text-[10px] text-text-secondary mt-0.5">Please provide payment transaction details for tracking.</p>
            </div>

            <div className="space-y-1.5">
              <label className="text-[9px] font-black uppercase tracking-wider text-text-secondary">Transaction Reference ID / UPI Ref</label>
              <input
                type="text"
                required
                placeholder="e.g. UPI 20392019283"
                value={transactionId}
                onChange={(e) => setTransactionId(e.target.value)}
                className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-[9px] font-black uppercase tracking-wider text-text-secondary">Settlement Notes (Optional)</label>
              <input
                type="text"
                placeholder="e.g. Transferred to owner's GPay"
                value={settleNotes}
                onChange={(e) => setSettleNotes(e.target.value)}
                className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
              />
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="button"
                onClick={() => setSettlingPayoutId(null)}
                className="flex-1 bg-muted/40 hover:bg-muted/60 text-text-primary text-xs font-black py-2.5 rounded-xl uppercase tracking-wider transition-all cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={settling}
                className="flex-1 bg-emerald-600 hover:bg-emerald-700 disabled:bg-muted text-white text-xs font-black py-2.5 rounded-xl uppercase tracking-wider transition-all cursor-pointer shadow-md shadow-emerald-500/10"
              >
                {settling ? 'Settling...' : 'Confirm Paid'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Payouts list table */}
      <div className="bg-card border border-border/50 rounded-3xl p-5 shadow-sm space-y-4">
        <div className="flex justify-between items-center border-b border-border/40 pb-3">
          <div className="flex items-center gap-2">
            <IndianRupee className="h-5 w-5 text-emerald-600" />
            <div>
              <h3 className="text-xs font-black text-text-primary uppercase tracking-wider">Settlement History</h3>
              <p className="text-[10px] text-text-muted mt-0.5">List of all weekly/monthly payouts and transaction proofs.</p>
            </div>
          </div>
          <button
            onClick={fetchPayouts}
            className="p-2 bg-muted/40 hover:bg-muted/60 rounded-xl transition-all cursor-pointer"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>

        {loading ? (
          <div className="flex flex-col items-center justify-center py-16 gap-2">
            <RefreshCw className="h-6 w-6 text-red-600 animate-spin" />
            <p className="text-[10px] text-text-secondary font-bold">Loading payouts ledger...</p>
          </div>
        ) : payouts.length === 0 ? (
          <div className="text-center py-16 text-xs text-text-secondary font-bold bg-muted/10 rounded-2xl border border-dashed border-border/60">
            No payouts have been generated yet.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-border/40 text-[9px] font-black uppercase tracking-wider text-text-secondary">
                  <th className="py-3 px-2">Date Generated</th>
                  <th className="py-3 px-2">Settlement Period</th>
                  <th className="py-3 px-2">Amount</th>
                  <th className="py-3 px-2">Status</th>
                  <th className="py-3 px-2">Transaction Details</th>
                  {isAdmin && <th className="py-3 px-2 text-right">Actions</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-border/20">
                {payouts.map((p) => (
                  <tr key={p.id} className="hover:bg-muted/10 font-medium">
                    <td className="py-3.5 px-2 text-text-muted text-[10px]">
                      {formatDate(p.createdAt)}
                    </td>
                    <td className="py-3.5 px-2 font-bold text-text-primary">
                      {formatDate(p.startDate)} – {formatDate(p.endDate)}
                    </td>
                    <td className="py-3.5 px-2 font-black text-text-primary text-sm">
                      {formatPrice(p.amount)}
                    </td>
                    <td className="py-3.5 px-2">
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[9px] font-black uppercase tracking-wider ${
                        p.status === 'PAID'
                          ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                          : 'bg-amber-500/10 text-amber-600 border border-amber-500/20'
                      }`}>
                        {p.status === 'PAID' ? <CheckCircle className="h-3 w-3" /> : <Clock className="h-3 w-3" />}
                        {p.status}
                      </span>
                    </td>
                    <td className="py-3.5 px-2">
                      {p.status === 'PAID' ? (
                        <div className="space-y-0.5">
                          {p.transactionId && (
                            <p className="font-mono text-[10px] font-black text-text-primary flex items-center gap-1">
                              <Tag className="h-3 w-3 text-text-muted shrink-0" />
                              {p.transactionId}
                            </p>
                          )}
                          {p.notes && <p className="text-[10px] text-text-muted italic">{p.notes}</p>}
                        </div>
                      ) : (
                        <span className="text-[10px] text-text-muted italic">Waiting for settlement</span>
                      )}
                    </td>
                    {isAdmin && (
                      <td className="py-3.5 px-2 text-right">
                        {p.status === 'PENDING' && (
                          <button
                            onClick={() => setSettlingPayoutId(p.id)}
                            className="px-3 py-1 bg-emerald-600 hover:bg-emerald-700 text-white text-[10px] font-black rounded-lg transition-all cursor-pointer shadow-xs uppercase tracking-wider"
                          >
                            Pay Partner
                          </button>
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
