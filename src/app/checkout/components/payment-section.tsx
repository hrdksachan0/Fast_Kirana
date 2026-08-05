'use client'

import React from 'react'
import { CreditCard, QrCode, Smartphone } from 'lucide-react'

export interface PaymentSectionProps {
  paymentMethod: 'COD' | 'ONLINE' | 'PAYTM'
  setPaymentMethod: (method: 'COD' | 'ONLINE' | 'PAYTM') => void
}

export function CheckoutPaymentSection({
  paymentMethod,
  setPaymentMethod,
}: PaymentSectionProps) {
  const options = [
    {
      id: 'COD',
      title: 'Cash / Pay on Delivery',
      subtitle: 'Pay via Cash, UPI, or Scanner at doorstep',
      icon: CreditCard,
    },
    {
      id: 'ONLINE',
      title: 'UPI / Cards / NetBanking',
      subtitle: 'Instant & 100% secure payment gateway',
      icon: Smartphone,
    },
    {
      id: 'PAYTM',
      title: 'Paytm Wallet / Postpaid',
      subtitle: 'Fast 1-click payment via Paytm',
      icon: QrCode,
    },
  ] as const

  return (
    <div className="bg-card border border-border p-4 sm:p-5 rounded-2xl shadow-xs space-y-4">
      <h3 className="font-extrabold text-sm text-text-primary border-b border-border/40 pb-2.5">
        Payment Method
      </h3>
      <div className="grid grid-cols-1 gap-2.5">
        {options.map((opt) => {
          const Icon = opt.icon
          const selected = paymentMethod === opt.id
          return (
            <button
              key={opt.id}
              type="button"
              onClick={() => setPaymentMethod(opt.id as any)}
              className={`flex items-start gap-3 p-3.5 rounded-xl border text-left transition-all cursor-pointer ${
                selected
                  ? 'border-accent bg-accent/5 ring-1 ring-accent/30'
                  : 'border-border/60 hover:bg-muted/20'
              }`}
            >
              <div
                className={`p-2 rounded-lg shrink-0 mt-0.5 ${
                  selected ? 'bg-accent text-white' : 'bg-muted text-text-secondary'
                }`}
              >
                <Icon className="h-4 w-4" />
              </div>
              <div>
                <p className="font-extrabold text-xs text-text-primary">{opt.title}</p>
                <p className="text-[10px] text-text-secondary mt-0.5">{opt.subtitle}</p>
              </div>
            </button>
          )
        })}
      </div>
    </div>
  )
}
