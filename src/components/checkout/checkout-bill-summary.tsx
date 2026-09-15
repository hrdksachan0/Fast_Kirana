'use client'

import { ShieldCheck } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatPrice, formatPriceDiscount, formatPriceSurcharge } from '@/lib/formatters'
import { Address } from '@/types'

interface CheckoutBillSummaryProps {
  totalItemsCount: number
  grocerySavings: number
  groceryB2BDiscount: number
  cafeSavings: number
  cafeB2BDiscount: number
  groceryMrpSubtotal: number
  cafeMrpSubtotal: number
  grocerySubtotal: number
  cafeSubtotal: number
  deliveryRules: any
  adjustedSubtotal: number
  groceryThreshold: number
  baseDeliveryFee: number
  appliedSurgeFee: number
  packagingFee: number
  couponDiscount: number
  appliedCoupon: { code: string; discountAmount: number } | null
  taxRate: number
  taxes: number
  effectiveMiscFee: number
  miscFeeLabel: string
  selectedAddress?: Address
  distanceKm: number | null
  grandTotal: number
}

export function CheckoutBillSummary({
  totalItemsCount,
  grocerySavings,
  groceryB2BDiscount,
  cafeSavings,
  cafeB2BDiscount,
  groceryMrpSubtotal,
  cafeMrpSubtotal,
  grocerySubtotal,
  cafeSubtotal,
  deliveryRules,
  adjustedSubtotal,
  groceryThreshold,
  baseDeliveryFee,
  appliedSurgeFee,
  packagingFee,
  couponDiscount,
  appliedCoupon,
  taxRate,
  taxes,
  effectiveMiscFee,
  miscFeeLabel,
  selectedAddress,
  distanceKm,
  grandTotal,
}: CheckoutBillSummaryProps) {
  const totalProductDiscount =
    grocerySavings + groceryB2BDiscount + cafeSavings + cafeB2BDiscount
  const totalSavings = totalProductDiscount + couponDiscount

  return (
    <div className="bg-white/80 dark:bg-zinc-900/85 backdrop-blur-md border border-white/60 dark:border-zinc-800/60 p-5 rounded-2xl shadow-[0_8px_30px_rgb(0,0,0,0.02)] h-fit space-y-5">
      <h3 className="text-sm font-black text-text-primary border-b border-border/40 pb-2.5 flex items-center justify-between">
        <span className="flex items-center gap-1.5">
          <span>🧾</span> Bill Summary
        </span>
        <span className="text-xs text-text-muted font-bold">{totalItemsCount} items</span>
      </h3>

      <div className="space-y-2.5 text-xs font-semibold">
        {totalProductDiscount > 0 ? (
          <>
            <div className="flex justify-between text-text-secondary">
              <span>Item Total (MRP)</span>
              <span>{formatPrice(groceryMrpSubtotal + cafeMrpSubtotal)}</span>
            </div>
            <div className="flex justify-between text-accent font-bold">
              <span>Product Discount</span>
              <span>{formatPriceDiscount(totalProductDiscount)}</span>
            </div>
          </>
        ) : (
          <div className="flex justify-between text-text-secondary">
            <span>Item Total</span>
            <span>{formatPrice(grocerySubtotal + cafeSubtotal)}</span>
          </div>
        )}

        <div className="flex justify-between text-text-secondary items-center">
          <div className="flex flex-col text-left">
            <span>Delivery Charge</span>
            <span className="text-[9px] text-text-muted">
              {deliveryRules?.zoneName ? `${deliveryRules.zoneName} · ` : ''}
              {adjustedSubtotal >=
              (deliveryRules && deliveryRules.isServiceable
                ? deliveryRules.freeDeliveryThreshold
                : groceryThreshold || 200)
                ? `Free delivery on orders ${formatPrice(
                    deliveryRules && deliveryRules.isServiceable
                      ? deliveryRules.freeDeliveryThreshold
                      : groceryThreshold || 200
                  )}+`
                : `Standard delivery fee`}
            </span>
          </div>
          <span className={cn(baseDeliveryFee === 0 ? 'text-accent font-black text-xs' : '')}>
            {baseDeliveryFee === 0 ? 'FREE 🎉' : formatPrice(baseDeliveryFee)}
          </span>
        </div>

        {appliedSurgeFee > 0 && (
          <div className="flex justify-between items-center text-amber-700 dark:text-amber-400 font-bold bg-amber-500/10 px-2.5 py-1.5 rounded-lg border border-amber-500/20">
            <div className="flex flex-col text-left">
              <span className="flex items-center gap-1 text-xs">
                <span>⚡</span> {deliveryRules?.surgeReason || 'Delivery Surge'}
              </span>
              <span className="text-[9px] text-amber-600/80 dark:text-amber-400/80 font-normal">
                Applied for rider safety &amp; high demand
              </span>
            </div>
            <span>{formatPriceSurcharge(appliedSurgeFee)}</span>
          </div>
        )}

        {packagingFee > 0 && (
          <div className="flex justify-between items-center text-amber-700 dark:text-amber-400 font-extrabold bg-amber-500/10 px-2.5 py-1 rounded-lg border border-amber-500/20">
            <span className="flex items-center gap-1.5 text-xs">
              <span>✨</span> Premium Packaging
            </span>
            <span>{formatPriceSurcharge(packagingFee)}</span>
          </div>
        )}

        {couponDiscount > 0 && (
          <div className="flex justify-between text-emerald-600 dark:text-emerald-400 font-semibold">
            <span>Coupon Applied ({appliedCoupon?.code})</span>
            <span>{formatPriceDiscount(couponDiscount)}</span>
          </div>
        )}

        {taxRate > 0 && (
          <div className="flex justify-between text-text-secondary">
            <span>GST &amp; Taxes ({Math.round(taxRate * 100)}%)</span>
            <span>{formatPrice(taxes)}</span>
          </div>
        )}

        {effectiveMiscFee > 0 && (
          <div className="flex justify-between text-text-secondary">
            <span>{miscFeeLabel}</span>
            <span>{formatPrice(effectiveMiscFee)}</span>
          </div>
        )}

        {selectedAddress && (
          <>
            {deliveryRules && !deliveryRules.isServiceable && (
              <div className="bg-rose-50 dark:bg-rose-950/20 border border-rose-200 dark:border-rose-900/50 p-2.5 rounded-xl text-center mt-2">
                <p className="text-[10px] font-black text-rose-600 dark:text-rose-400">
                  ❌ Address is {distanceKm?.toFixed(1)} km away. Delivery only available up to 5
                  km.
                </p>
              </div>
            )}
            {deliveryRules && deliveryRules.isServiceable && (
              <div
                className={cn(
                  'p-2.5 rounded-xl border text-center mt-2 flex items-center justify-center gap-1.5',
                  adjustedSubtotal >= deliveryRules.freeDeliveryThreshold
                    ? 'bg-emerald-50 dark:bg-emerald-950/20 border-emerald-200/50 dark:border-emerald-900/30 text-emerald-700 dark:text-emerald-300 font-extrabold text-[10.5px]'
                    : 'bg-blue-50 dark:bg-blue-950/20 border-blue-200/50 dark:border-blue-900/30 text-blue-700 dark:text-blue-300 font-extrabold text-[10.5px]'
                )}
              >
                <span>{adjustedSubtotal >= deliveryRules.freeDeliveryThreshold ? '🎉' : '🚚'}</span>
                <span>
                  {adjustedSubtotal >= deliveryRules.freeDeliveryThreshold
                    ? 'Congratulations! FREE Delivery Unlocked for your location!'
                    : `Add ${formatPrice(
                        deliveryRules.freeDeliveryThreshold - adjustedSubtotal
                      )} more for FREE Delivery (Free on ${formatPrice(
                        deliveryRules.freeDeliveryThreshold
                      )}+)`}
                </span>
              </div>
            )}
          </>
        )}

        {/* Savings Callout */}
        {totalSavings > 0 && (
          <div className="bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 p-2.5 rounded-xl text-xs font-black flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <span>🎉</span> You Save on this Order
            </span>
            <span>{formatPrice(totalSavings)}</span>
          </div>
        )}

        {/* Grand Total */}
        <div className="border-t-2 border-dashed border-border/60 pt-3 mt-3 flex justify-between items-center text-base font-black text-text-primary">
          <span>To Pay</span>
          <span className="text-primary text-xl font-black">{formatPrice(grandTotal)}</span>
        </div>
      </div>

      <div className="text-[10px] text-text-muted text-center pt-2 leading-relaxed flex items-center justify-center gap-1.5">
        <ShieldCheck className="h-3.5 w-3.5 text-emerald-500" />
        <span>100% Safe &amp; Contactless Delivery</span>
      </div>
    </div>
  )
}
