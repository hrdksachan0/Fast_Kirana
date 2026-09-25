'use client'

import { useEffect, useState } from 'react'
import { Loader2, CheckCircle2, ShieldCheck, Truck, ChefHat } from 'lucide-react'

export type CheckoutOverlayState =
  | 'creating-order'
  | 'awaiting-payment'
  | 'verifying-payment'
  | 'success'
  | null

interface CheckoutProcessingOverlayProps {
  state: CheckoutOverlayState
  orderReadableId?: string
}

export function CheckoutProcessingOverlay({ state, orderReadableId }: CheckoutProcessingOverlayProps) {
  const [dots, setDots] = useState('.')

  useEffect(() => {
    if (!state) return
    const timer = setInterval(() => {
      setDots((prev) => (prev.length >= 3 ? '.' : prev + '.'))
    }, 500)
    return () => clearInterval(timer)
  }, [state])

  if (!state) return null

  return (
    <div className="fixed inset-0 z-[200] bg-white/95 dark:bg-zinc-950/95 backdrop-blur-md flex flex-col items-center justify-center px-6 transition-all animate-in fade-in duration-300">
      {state === 'creating-order' && (
        <div className="flex flex-col items-center text-center space-y-5">
          {/* Animated truck icon */}
          <div className="relative h-20 w-20">
            <div className="absolute inset-0 rounded-full bg-primary/10 animate-pulse" />
            <div className="relative h-20 w-20 rounded-full bg-gradient-to-br from-primary/10 to-accent/10 border-2 border-primary/20 flex items-center justify-center">
              <Truck className="h-9 w-9 text-primary animate-bounce" style={{ animationDuration: '1.5s' }} />
            </div>
          </div>
          <h2 className="text-lg font-black text-text-primary">
            Creating Your Express Order{dots}
          </h2>
          <p className="text-xs text-text-secondary font-medium max-w-xs">
            Securing your items and calculating fastest delivery route ⚡
          </p>
          <Loader2 className="h-5 w-5 animate-spin text-primary" />
        </div>
      )}

      {state === 'awaiting-payment' && (
        <div className="flex flex-col items-center text-center space-y-5">
          <div className="relative h-20 w-20">
            <div className="absolute inset-0 rounded-full bg-blue-500/10 animate-ping" style={{ animationDuration: '2s' }} />
            <div className="absolute inset-3 rounded-full bg-blue-500/15 animate-ping" style={{ animationDuration: '2s', animationDelay: '0.5s' }} />
            <div className="relative h-20 w-20 rounded-full bg-blue-500/5 border-2 border-blue-500/30 flex items-center justify-center">
              <ShieldCheck className="h-9 w-9 text-blue-500" />
            </div>
          </div>
          <h2 className="text-lg font-black text-text-primary">
            Complete Payment in Your UPI App
          </h2>
          <p className="text-xs text-text-secondary font-medium max-w-xs">
            Open Google Pay, PhonePe, or Paytm to approve the payment. We'll detect it automatically.
          </p>
          <div className="flex items-center gap-2 text-xs text-text-muted">
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
            <span>Waiting for bank confirmation{dots}</span>
          </div>
        </div>
      )}

      {state === 'verifying-payment' && (
        <div className="flex flex-col items-center text-center space-y-5">
          <div className="relative h-20 w-20">
            <div className="absolute inset-0 rounded-full bg-amber-500/10 animate-ping" style={{ animationDuration: '1.5s' }} />
            <div className="relative h-20 w-20 rounded-full bg-amber-500/5 border-2 border-amber-500/30 flex items-center justify-center">
              <ShieldCheck className="h-9 w-9 text-amber-500 animate-pulse" />
            </div>
          </div>
          <h2 className="text-lg font-black text-text-primary">
            Verifying with Bank{dots}
          </h2>
          <p className="text-xs text-text-secondary font-medium max-w-xs">
            Almost done! Confirming your payment status with the payment gateway.
          </p>
          <Loader2 className="h-5 w-5 animate-spin text-amber-500" />
        </div>
      )}

      {state === 'success' && (
        <div className="flex flex-col items-center text-center space-y-5">
          <div className="relative h-24 w-24">
            <div className="absolute inset-0 rounded-full bg-emerald-500/20 animate-ping" style={{ animationDuration: '1s', animationIterationCount: '2' }} />
            <div className="relative h-24 w-24 rounded-full bg-emerald-500/10 border-2 border-emerald-500/30 flex items-center justify-center">
              <CheckCircle2 className="h-12 w-12 text-emerald-500" />
            </div>
          </div>
          <h2 className="text-2xl font-black text-emerald-600 dark:text-emerald-400">
            🎉 Order Placed Successfully!
          </h2>
          {orderReadableId && (
            <p className="text-sm font-extrabold text-text-primary">
              Order #{orderReadableId}
            </p>
          )}
          <div className="flex items-center gap-3 mt-1">
            <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-3 py-1.5 rounded-full">
              <ChefHat className="h-3.5 w-3.5" />
              <span>Kitchen Notified</span>
            </div>
            <div className="flex items-center gap-1.5 text-xs font-bold text-blue-600 dark:text-blue-400 bg-blue-500/10 px-3 py-1.5 rounded-full">
              <Truck className="h-3.5 w-3.5" />
              <span>Rider Assigned</span>
            </div>
          </div>
          <p className="text-xs text-text-secondary font-medium mt-1">
            Redirecting to live order tracking...
          </p>
          <Loader2 className="h-4 w-4 animate-spin text-primary" />
        </div>
      )}
    </div>
  )
}
