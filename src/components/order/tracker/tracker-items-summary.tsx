'use client'

import { cn } from '@/lib/utils'

interface TrackerItemsSummaryProps {
  order: any
  mergedItems: any[]
  combinedSubtotal: number
  combinedDiscount: number
  combinedDeliveryFee: number
  combinedTaxes: number
  combinedMiscFee: number
  combinedTotal: number
  combinedRefundAmount: number
}

export function TrackerItemsSummary({
  order,
  mergedItems,
  combinedSubtotal,
  combinedDiscount,
  combinedDeliveryFee,
  combinedTaxes,
  combinedMiscFee,
  combinedTotal,
  combinedRefundAmount,
}: TrackerItemsSummaryProps) {
  return (
    <div className="bg-white dark:bg-zinc-900 border border-border/60 p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4">
      <div className="flex items-center gap-2 border-b border-dashed border-border/60 pb-3">
        <span className="text-lg">🧾</span>
        <div>
          <h3 className="text-xs font-black uppercase tracking-wider text-text-primary">
            Order Receipt
          </h3>
          <p className="text-[9px] text-text-muted font-bold uppercase mt-0.5">
            Payment Mode: {order.paymentMethod === 'COD' ? 'Cash on Delivery' : order.paymentMethod}
          </p>
        </div>
      </div>

      <div className="space-y-3">
        {/* Items List */}
        <div className="space-y-3">
          {order.isCombined && order.subOrders && order.subOrders.length > 1 ? (
            order.subOrders.map((sub: any, subIdx: number) => {
              const isRest = sub.type === 'RESTAURANT'
              const subItems = sub.items || []
              if (subItems.length === 0) return null
              return (
                <div key={sub.id || subIdx} className="rounded-xl border border-border/50 overflow-hidden bg-muted/10">
                  <div className="bg-muted/40 px-3 py-1.5 text-[10px] font-black uppercase tracking-wider flex items-center justify-between text-text-secondary border-b border-border/40">
                    <span>{isRest ? `🍽️ ${sub.shopName || 'Restaurant'}` : `🥘 ${sub.shopName || 'FastKirana Dark Store'}`}</span>
                    <span className="text-[9px] font-mono text-text-muted">{subItems.length} items</span>
                  </div>
                  <div className="p-3 space-y-2 divide-y divide-border/20">
                    {subItems.map((item: any) => (
                      <div key={item.id} className="flex justify-between items-center pt-2 first:pt-0">
                        <div className="flex items-center gap-2.5 min-w-0">
                          <span className="inline-flex items-center justify-center text-[10px] font-black text-accent bg-accent/5 dark:bg-accent/10 px-2 py-0.5 rounded-lg border border-accent/10 shrink-0">
                            {item.quantity}x
                          </span>
                          <div className="min-w-0">
                            <p className="text-xs font-bold text-text-primary truncate">
                              {item.name} {item.selectedVariant ? `(${item.selectedVariant})` : ''}
                            </p>
                            {(item.isRefunded || (Number(item.refundAmount) > 0) || item.notes?.includes('Refund')) ? (
                              <span className="text-[9px] bg-rose-500/15 text-rose-600 dark:text-rose-400 font-bold px-1.5 py-0.5 rounded mt-0.5 inline-block">
                                ↩️ Refunded (-₹{item.refundAmount || item.price})
                              </span>
                            ) : null}
                            {item.notes && !item.notes.includes('Refund') && (
                              <p className="text-[9px] text-amber-600 dark:text-amber-400 font-medium">
                                📝 {item.notes}
                              </p>
                            )}
                          </div>
                        </div>
                        <span className="text-xs font-extrabold text-text-primary shrink-0 ml-4">
                          ₹{item.price * item.quantity}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )
            })
          ) : (
            mergedItems.map((item: any) => (
              <div key={item.id} className="flex justify-between items-center py-1">
                <div className="flex items-center gap-2.5 min-w-0">
                  <span className="inline-flex items-center justify-center text-[10px] font-black text-accent bg-accent/5 dark:bg-accent/10 px-2 py-0.5 rounded-lg border border-accent/10 shrink-0">
                    {item.quantity}x
                  </span>
                  <div className="min-w-0">
                    <p className="text-xs font-bold text-text-primary truncate">
                      {item.name} {item.selectedVariant ? `(${item.selectedVariant})` : ''}
                    </p>
                    {(item.isRefunded || (Number(item.refundAmount) > 0) || item.notes?.includes('Refund')) ? (
                      <span className="text-[9px] bg-rose-500/15 text-rose-600 dark:text-rose-400 font-bold px-1.5 py-0.5 rounded mt-0.5 inline-block">
                        ↩️ Refunded (-₹{item.refundAmount || item.price})
                      </span>
                    ) : null}
                    {item.shopName && (
                      <p className="text-[9px] text-text-muted font-semibold flex items-center gap-0.5 mt-0.5">
                        <span>🏢</span> {item.shopName}
                      </p>
                    )}
                  </div>
                </div>
                <span className="text-xs font-extrabold text-text-primary shrink-0 ml-4">
                  ₹{item.price * item.quantity}
                </span>
              </div>
            ))
          )}
        </div>
        
        {/* Cost Breakdown */}
        <div className="border-t border-dashed border-border/60 pt-3.5 space-y-2.5 text-xs">
          <div className="flex justify-between text-text-secondary font-semibold">
            <span>Subtotal</span>
            <span className="font-bold text-text-primary">₹{combinedSubtotal}</span>
          </div>
          {combinedDiscount > 0 && (
            <div className="flex justify-between text-emerald-600 dark:text-emerald-400 font-bold">
              <span>Discount Applied</span>
              <span>-₹{combinedDiscount}</span>
            </div>
          )}
          <div className="flex justify-between text-text-secondary font-semibold">
            <span>Delivery Charge</span>
            <span className={cn(combinedDeliveryFee === 0 ? "text-emerald-600 dark:text-emerald-400 font-black" : "font-bold text-text-primary")}>
              {combinedDeliveryFee > 0 ? `₹${combinedDeliveryFee}` : 'FREE 🎉'}
            </span>
          </div>
          {combinedTaxes > 0 && (
            <div className="flex justify-between text-text-secondary font-semibold">
              <span>Taxes & GST</span>
              <span className="font-bold text-text-primary">₹{combinedTaxes.toFixed(1)}</span>
            </div>
          )}
          {combinedMiscFee > 0 && (
            <div className="flex justify-between text-text-secondary font-semibold">
              <span>Packaging &amp; Handling Fee</span>
              <span className="font-bold text-text-primary">₹{combinedMiscFee}</span>
            </div>
          )}
          {combinedRefundAmount > 0 && (
            <div className="flex justify-between text-rose-600 dark:text-rose-400 font-black bg-rose-500/10 px-2.5 py-1.5 rounded-lg border border-rose-500/20">
              <span className="flex items-center gap-1">↩️ Refund Credited</span>
              <span>-₹{combinedRefundAmount}</span>
            </div>
          )}
        </div>

        {/* Grand Total */}
        <div className="flex justify-between items-center text-text-primary font-black border-t-2 border-dashed border-border/80 pt-4 mt-1">
          <div>
            <span className="text-xs uppercase tracking-wider text-text-secondary block">
              {combinedRefundAmount > 0 ? 'Net Paid Total' : 'Grand Total'}
            </span>
            {combinedRefundAmount > 0 && (
              <span className="text-[10px] text-text-muted font-medium">
                Original: ₹{combinedTotal.toFixed(0)}
              </span>
            )}
          </div>
          <span className="text-primary text-lg font-black tracking-tight">
            ₹{(combinedTotal - combinedRefundAmount).toFixed(0)}
          </span>
        </div>
      </div>
    </div>
  )
}
