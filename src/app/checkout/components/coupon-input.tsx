'use client'

import React, { useState } from 'react'
import { Tag, Check, X, Loader2 } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface CouponInputProps {
  appliedCoupon: string | null
  discount: number
  onApplyCoupon: (code: string) => Promise<boolean>
  onRemoveCoupon: () => void
}

export function CheckoutCouponInput({
  appliedCoupon,
  discount,
  onApplyCoupon,
  onRemoveCoupon,
}: CouponInputProps) {
  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(false)

  const handleApply = async () => {
    if (!code.trim()) return
    setLoading(true)
    const success = await onApplyCoupon(code.trim())
    setLoading(false)
    if (success) setCode('')
  }

  return (
    <div className="bg-card border border-border p-4 rounded-2xl shadow-xs space-y-3">
      <div className="flex items-center gap-2 text-xs font-black text-text-primary">
        <Tag className="h-4 w-4 text-accent" />
        <span>Apply Promo Code</span>
      </div>

      {appliedCoupon ? (
        <div className="flex items-center justify-between p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-xs">
          <div className="flex items-center gap-2">
            <Check className="h-4 w-4 text-emerald-600 font-bold" />
            <div>
              <span className="font-extrabold text-emerald-700 dark:text-emerald-400 uppercase">
                {appliedCoupon}
              </span>
              <p className="text-[10px] text-text-secondary">Saved {formatPrice(discount)}!</p>
            </div>
          </div>
          <button
            onClick={onRemoveCoupon}
            className="p-1 text-text-muted hover:text-text-primary transition-colors cursor-pointer"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      ) : (
        <div className="flex gap-2">
          <input
            type="text"
            placeholder="ENTER COUPON"
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            className="flex-1 px-3 py-2 text-xs font-mono font-bold rounded-xl border border-border bg-muted/20 focus:outline-none focus:border-accent uppercase"
          />
          <button
            onClick={handleApply}
            disabled={loading || !code.trim()}
            className="px-4 py-2 bg-accent hover:bg-accent/90 text-white font-black text-xs rounded-xl transition-all disabled:opacity-50 cursor-pointer flex items-center gap-1"
          >
            {loading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : 'Apply'}
          </button>
        </div>
      )}
    </div>
  )
}
