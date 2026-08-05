'use client'

import React from 'react'
import { formatPrice } from '@/lib/utils'
import { CartItem } from '@/types'

export interface OrderSummaryProps {
  items: CartItem[]
  subtotal: number
  deliveryFee: number
  taxes: number
  miscFee: number
  discount: number
  total: number
}

export function CheckoutOrderSummary({
  items,
  subtotal,
  deliveryFee,
  taxes,
  miscFee,
  discount,
  total,
}: OrderSummaryProps) {
  return (
    <div className="bg-card border border-border p-4 sm:p-5 rounded-2xl shadow-xs space-y-4">
      <h3 className="font-extrabold text-sm text-text-primary border-b border-border/40 pb-2.5 flex items-center justify-between">
        <span>Order Summary</span>
        <span className="text-xs text-text-secondary font-semibold">{items.length} items</span>
      </h3>

      {/* Items List */}
      <div className="divide-y divide-border/40 max-h-48 overflow-y-auto pr-1 text-xs font-semibold">
        {items.map((item) => (
          <div key={item.product.id} className="py-2 flex items-center justify-between gap-2">
            <div className="max-w-[70%]">
              <p className="text-text-primary font-bold truncate">{item.product.name}</p>
              <p className="text-[10px] text-text-secondary">
                {formatPrice(item.product.price)} x {item.quantity}
              </p>
            </div>
            <p className="font-extrabold text-text-primary">
              {formatPrice(item.product.price * item.quantity)}
            </p>
          </div>
        ))}
      </div>

      {/* Cost Breakdown */}
      <div className="border-t border-border/40 pt-3 space-y-2 text-xs font-semibold text-text-secondary">
        <div className="flex justify-between">
          <span>Items Subtotal</span>
          <span className="font-bold text-text-primary">{formatPrice(subtotal)}</span>
        </div>
        {discount > 0 && (
          <div className="flex justify-between text-emerald-600 font-bold">
            <span>Coupon Discount</span>
            <span>-{formatPrice(discount)}</span>
          </div>
        )}
        <div className="flex justify-between">
          <span>Delivery Fee</span>
          <span className="font-bold text-text-primary">
            {deliveryFee === 0 ? <span className="text-emerald-600 font-bold">FREE</span> : formatPrice(deliveryFee)}
          </span>
        </div>
        {miscFee > 0 && (
          <div className="flex justify-between">
            <span>Handling Fee</span>
            <span className="font-bold text-text-primary">{formatPrice(miscFee)}</span>
          </div>
        )}
        {taxes > 0 && (
          <div className="flex justify-between">
            <span>Taxes &amp; Charges</span>
            <span className="font-bold text-text-primary">{formatPrice(taxes)}</span>
          </div>
        )}

        <div className="border-t border-border/60 pt-3 flex justify-between text-sm font-black text-text-primary">
          <span>To Pay</span>
          <span className="text-primary text-base">{formatPrice(total)}</span>
        </div>
      </div>
    </div>
  )
}
