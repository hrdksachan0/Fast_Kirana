'use client'

import { RefObject } from 'react'

interface CartCouponSectionProps {
  appliedCoupon: any
  couponDiscount: number
  couponInput: string
  isCouponLoading: boolean
  couponInputRef: RefObject<HTMLInputElement | null>
  onCouponInputChange: (value: string) => void
  onApplyCoupon: (e: React.FormEvent) => void
  onRemoveCoupon: () => void
}

export function CartCouponSection({
  appliedCoupon,
  couponDiscount,
  couponInput,
  isCouponLoading,
  couponInputRef,
  onCouponInputChange,
  onApplyCoupon,
  onRemoveCoupon,
}: CartCouponSectionProps) {
  return (
    <div className="bg-zinc-50 dark:bg-zinc-900 border border-zinc-150 dark:border-zinc-800 p-3.5 rounded-2xl space-y-2 mt-4 mx-1">
      <h4 className="text-xs font-black text-zinc-800 dark:text-zinc-250 flex items-center gap-1.5 leading-none">
        <span>🎟️</span> Apply Promo / Coupon Code
      </h4>
      {appliedCoupon ? (
        <div className="flex items-center justify-between border border-accent/20 bg-accent/5 p-2 rounded-xl">
          <div className="text-left">
            <div className="flex items-center gap-1.5">
              <span className="text-[10px] font-black text-accent bg-accent/10 px-2 py-0.5 rounded border border-accent/20">
                {appliedCoupon.code}
              </span>
              {appliedCoupon.bogoType && (
                <span className="text-[9px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-1.5 py-0.5 rounded">
                  🎁 BOGO
                </span>
              )}
            </div>
            <p className="text-[9px] text-accent font-semibold mt-1">
              {appliedCoupon.bogoType
                ? `Saved ₹${couponDiscount.toFixed(0)} on free item!`
                : `Saved ₹${couponDiscount.toFixed(0)}`}
            </p>
          </div>
          <button
            onClick={onRemoveCoupon}
            className="text-[10px] text-red-500 hover:bg-red-500/10 font-bold px-2 py-1 rounded cursor-pointer"
          >
            Remove
          </button>
        </div>
      ) : (
        <form onSubmit={onApplyCoupon} className="flex gap-2">
          <input
            ref={couponInputRef}
            placeholder="Enter Coupon Code"
            value={couponInput}
            onChange={(e) => onCouponInputChange(e.target.value)}
            className="uppercase w-full px-3 py-1.5 border border-zinc-200 dark:border-zinc-800 rounded-xl text-xs bg-white dark:bg-zinc-900 focus:outline-none focus:border-primary/45 font-bold"
          />
          <button
            type="submit"
            disabled={isCouponLoading || !couponInput.trim()}
            className="bg-primary text-white hover:bg-primary/95 text-xs font-black px-4 py-1.5 rounded-xl disabled:opacity-50 cursor-pointer"
          >
            {isCouponLoading ? 'Applying...' : 'Apply'}
          </button>
        </form>
      )}
    </div>
  )
}
