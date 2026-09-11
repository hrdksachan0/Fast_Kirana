'use client'

import React, { useState } from 'react'
import { formatPrice } from '@/lib/utils'
import { toast } from 'sonner'
import { RotateCcw, X, Check, Loader2, AlertCircle } from 'lucide-react'

interface RecordRefundModalProps {
  order: any
  isOpen: boolean
  onClose: () => void
  onSuccess?: (updatedOrder: any) => void
}

export function RecordRefundModal({
  order,
  isOpen,
  onClose,
  onSuccess
}: RecordRefundModalProps) {
  const [selectedItemId, setSelectedItemId] = useState<string | null>(null)
  const [amount, setAmount] = useState<string>('')
  const [reason, setReason] = useState<string>('')
  const [submitting, setSubmitting] = useState(false)

  if (!isOpen || !order) return null

  const items = order.items || []
  const orderTotal = Number(order.total) || 0
  const currentRefund = Number(order.refundAmount) || 0
  const maxRefundAllowed = Math.max(0, orderTotal - currentRefund)

  const handleSelectItem = (item: any) => {
    if (selectedItemId === item.id) {
      setSelectedItemId(null)
      setAmount('')
    } else {
      setSelectedItemId(item.id)
      const lineTotal = (Number(item.price) || 0) * (Number(item.quantity) || 1)
      const itemRemaining = Math.max(0, lineTotal - (Number(item.refundAmount) || 0))
      setAmount(itemRemaining.toString())
      if (!reason.trim()) {
        setReason(`Refund for ${item.name}`)
      }
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const refundVal = parseFloat(amount)
    if (isNaN(refundVal) || refundVal <= 0) {
      toast.error('Please enter a valid refund amount greater than 0')
      return
    }

    if (refundVal > maxRefundAllowed) {
      toast.error(`Refund amount cannot exceed remaining order balance of ₹${maxRefundAllowed}`)
      return
    }

    setSubmitting(true)
    try {
      const res = await fetch(`/api/admin/orders/${order.id}/refund`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          amount: refundVal,
          itemId: selectedItemId || undefined,
          reason: reason.trim() || undefined
        })
      })

      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to record refund')
      }

      toast.success(`Refund of ₹${refundVal} recorded successfully!`)
      if (onSuccess) {
        onSuccess(data.order)
      }
      onClose()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error recording refund')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 animate-fade-in">
      <div className="bg-white dark:bg-zinc-900 border border-border rounded-2xl max-w-lg w-full p-6 shadow-2xl space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-border/60 pb-3">
          <div className="flex items-center gap-2 text-rose-600 dark:text-rose-400">
            <div className="h-9 w-9 rounded-xl bg-rose-500/10 flex items-center justify-center text-lg">
              ↩️
            </div>
            <div>
              <h3 className="text-sm font-black text-text-primary">
                Record Refund for #{order.readableId || order.id.slice(0, 8)}
              </h3>
              <p className="text-[11px] text-text-muted">
                Deducts from sales and restaurant payout calculations
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg hover:bg-muted text-text-muted hover:text-text-primary transition-colors cursor-pointer"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Order Amount Overview */}
        <div className="bg-muted/40 p-3 rounded-xl border border-border/60 text-xs flex items-center justify-between">
          <div>
            <span className="text-[10px] text-text-muted font-bold block uppercase">Order Total</span>
            <span className="text-sm font-black text-text-primary">{formatPrice(orderTotal)}</span>
          </div>
          {currentRefund > 0 && (
            <div className="text-center">
              <span className="text-[10px] text-rose-600 font-bold block uppercase">Already Refunded</span>
              <span className="text-sm font-black text-rose-600">-{formatPrice(currentRefund)}</span>
            </div>
          )}
          <div className="text-right">
            <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold block uppercase">Net Balance</span>
            <span className="text-sm font-black text-emerald-600 dark:text-emerald-400">{formatPrice(maxRefundAllowed)}</span>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Select Specific Item (Optional) */}
          {items.length > 0 && (
            <div>
              <label className="text-[11px] font-bold text-text-secondary block mb-1.5">
                Select Item to Refund (Optional)
              </label>
              <div className="space-y-1.5 max-h-40 overflow-y-auto pr-1">
                {items.map((item: any) => {
                  const isSelected = selectedItemId === item.id
                  const isAlreadyRefunded = item.isRefunded || (Number(item.refundAmount) || 0) > 0
                  return (
                    <div
                      key={item.id}
                      onClick={() => handleSelectItem(item)}
                      className={`p-2 rounded-xl border text-xs flex items-center justify-between cursor-pointer transition-all ${
                        isSelected
                          ? 'border-rose-500 bg-rose-500/10 text-rose-700 dark:text-rose-300'
                          : 'border-border/60 hover:bg-muted/30 text-text-primary'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        <div className={`h-4 w-4 rounded-md border flex items-center justify-center text-[10px] ${
                          isSelected ? 'border-rose-500 bg-rose-500 text-white' : 'border-border'
                        }`}>
                          {isSelected && <Check className="h-3 w-3 stroke-[3]" />}
                        </div>
                        <span className="font-semibold">
                          {item.quantity}x {item.name}
                        </span>
                        {isAlreadyRefunded && (
                          <span className="text-[9px] bg-rose-500/15 text-rose-600 px-1.5 py-0.5 rounded font-bold">
                            Refunded ₹{item.refundAmount || item.price}
                          </span>
                        )}
                      </div>
                      <span className="font-black">
                        {formatPrice(item.price * item.quantity)}
                      </span>
                    </div>
                  )
                })}
              </div>
            </div>
          )}

          {/* Refund Amount Input */}
          <div>
            <label className="text-[11px] font-bold text-text-secondary block mb-1">
              Refund Amount (₹) *
            </label>
            <input
              type="number"
              step="any"
              min="1"
              max={maxRefundAllowed}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder={`Max ₹${maxRefundAllowed}`}
              required
              className="w-full h-10 px-3 rounded-xl border border-border bg-card text-text-primary font-bold text-sm focus:outline-none focus:ring-2 focus:ring-rose-500/30"
            />
          </div>

          {/* Reason / Remarks Input */}
          <div>
            <label className="text-[11px] font-bold text-text-secondary block mb-1">
              Refund Reason / Note
            </label>
            <input
              type="text"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. Item missing, customer complaint, damaged"
              className="w-full h-10 px-3 rounded-xl border border-border bg-card text-text-primary text-xs focus:outline-none focus:ring-2 focus:ring-rose-500/30"
            />
          </div>

          {/* Warning Banner */}
          <div className="flex items-start gap-2 p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-700 dark:text-amber-300 text-[11px] font-medium leading-relaxed">
            <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
            <span>
              This refund will be immediately excluded from restaurant finance and company sales. If paid online via Razorpay/UPI, please execute the payout or bank refund if not already processed.
            </span>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-border/60">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 bg-muted hover:bg-muted/80 text-text-primary text-xs font-bold rounded-xl transition-all cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting || !amount || parseFloat(amount) <= 0}
              className="px-5 py-2 bg-rose-600 hover:bg-rose-700 disabled:opacity-50 text-white text-xs font-black rounded-xl shadow-md shadow-rose-600/20 transition-all flex items-center gap-1.5 cursor-pointer active:scale-95"
            >
              {submitting ? (
                <>
                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                  Recording...
                </>
              ) : (
                <>
                  <RotateCcw className="h-3.5 w-3.5" />
                  Confirm &amp; Record Refund
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
