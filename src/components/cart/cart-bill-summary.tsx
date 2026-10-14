'use client'

import { formatPrice } from '@/lib/utils'
import { cn } from '@/lib/utils'
import { ChevronDown, ChevronUp } from 'lucide-react'

export interface CartBillBreakdownProps {
  subtotal: number
  deliveryFee: number
  activeThreshold: number
  miscFee: number
  miscFeeLabel: string
  couponDiscount: number
  appliedCouponCode?: string | null
  savings: number
  showBillDetails: boolean
}

export function CartBillBreakdown({
  subtotal,
  deliveryFee,
  activeThreshold,
  miscFee,
  miscFeeLabel,
  couponDiscount,
  appliedCouponCode,
  savings,
  showBillDetails,
}: CartBillBreakdownProps) {
  return (
    <>
      {/* Expandable Bill details */}
      {showBillDetails && (
        <div className="mb-4 space-y-2 border-b border-zinc-100 dark:border-zinc-900 pb-3.5 animate-slide-down">
          <div className="flex justify-between text-xs text-zinc-500 font-bold">
            <span>Items Subtotal</span>
            <span>{formatPrice(subtotal)}</span>
          </div>
          {couponDiscount > 0 && (
            <div className="flex justify-between text-xs text-emerald-600 dark:text-emerald-450 font-bold">
              <span>Coupon Applied ({appliedCouponCode})</span>
              <span>-₹{couponDiscount.toFixed(0)}</span>
            </div>
          )}
          <div className="flex justify-between text-xs text-zinc-500 font-bold items-center">
            <div className="flex flex-col text-left">
              <span>Delivery Charges</span>
              <span className="text-[9px] text-zinc-400 font-normal">
                {deliveryFee === 0 ? `FREE on orders above ₹${activeThreshold}` : `₹${deliveryFee} fee on orders under ₹${activeThreshold}`}
              </span>
            </div>
            <span className={cn(deliveryFee === 0 ? "text-accent font-black text-xs" : "font-bold text-zinc-800 dark:text-zinc-200 text-xs")}>
              {deliveryFee === 0 ? 'FREE 🎉' : `₹${deliveryFee}`}
            </span>
          </div>
          {miscFee > 0 && (
            <div className="flex justify-between text-xs text-zinc-500 font-bold items-center">
              <span>{miscFeeLabel}</span>
              <span className="font-bold text-zinc-800 dark:text-zinc-200 text-xs">₹{miscFee.toFixed(0)}</span>
            </div>
          )}
        </div>
      )}

      {/* Savings reminder badge */}
      {(savings + couponDiscount) > 0 && (
        <div className="flex items-center justify-between rounded-xl bg-emerald-50/60 dark:bg-emerald-950/20 border border-emerald-100/50 dark:border-emerald-900/30 px-3.5 py-2 mb-3.5 animate-pulse-gentle">
          <span className="text-xs font-extrabold text-[#00b140] flex items-center gap-1.5 leading-none">
            🎉 You are saving {formatPrice(savings + couponDiscount)} on this order!
          </span>
          {couponDiscount > 0 && (
            <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-2 py-0.5 rounded-full">
              Incl. ₹{couponDiscount.toFixed(0)} deal
            </span>
          )}
        </div>
      )}
    </>
  )
}

export interface CartBillSummaryProps extends CartBillBreakdownProps {
  total: number
  onToggleBillDetails: () => void
}

export function CartBillSummary({
  subtotal,
  total,
  savings,
  deliveryFee,
  activeThreshold,
  miscFee,
  miscFeeLabel,
  couponDiscount,
  appliedCouponCode,
  showBillDetails,
  onToggleBillDetails,
}: CartBillSummaryProps) {
  return (
    <div>
      <CartBillBreakdown
        subtotal={subtotal}
        deliveryFee={deliveryFee}
        activeThreshold={activeThreshold}
        miscFee={miscFee}
        miscFeeLabel={miscFeeLabel}
        couponDiscount={couponDiscount}
        appliedCouponCode={appliedCouponCode}
        savings={savings}
        showBillDetails={showBillDetails}
      />

      {/* Price + View Bill Toggle Header */}
      <div className="flex flex-col text-left shrink-0">
        <span className="text-[10px] text-zinc-400 dark:text-zinc-500 font-extrabold uppercase tracking-wider">To Pay</span>
        <span className="text-xl font-black text-zinc-900 dark:text-zinc-100 leading-tight tabular-nums">
          {formatPrice(total)}
        </span>
        <button
          onClick={onToggleBillDetails}
          className="text-[10.5px] font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-0.5 hover:underline cursor-pointer select-none leading-none mt-1"
        >
          <span>{showBillDetails ? 'Hide Bill' : 'View Bill'}</span>
          {showBillDetails ? <ChevronDown size={11} /> : <ChevronUp size={11} />}
        </button>
      </div>
    </div>
  )
}
