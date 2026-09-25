'use client'

import { Suspense, useEffect, useState, useCallback, useRef } from 'react'
import { useSearchParams } from 'next/navigation'
import { useCartStore } from '@/stores/cart-store'
import { Loader2, CheckCircle2, AlertCircle, ShieldCheck } from 'lucide-react'

function CheckoutVerifyContent() {
  const searchParams = useSearchParams()
  const orderId = searchParams.get('order_id') || ''
  const cfOrderId = searchParams.get('cf_order_id') || ''

  const [status, setStatus] = useState<'verifying' | 'success' | 'failed' | 'timeout'>('verifying')
  const [pollCount, setPollCount] = useState(0)
  const clearCart = useCartStore((s) => s.clearCart)
  const hasRedirected = useRef(false)

  const verify = useCallback(async (): Promise<boolean> => {
    if (!orderId && !cfOrderId) return false
    try {
      const res = await fetch('/api/payment/cashfree/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId, cfOrderId }),
      })
      const data = await res.json()
      if (res.ok && (data.paymentStatus === 'PAID' || data.isPaid === true)) {
        return true
      }
    } catch (_) {}
    return false
  }, [orderId, cfOrderId])

  useEffect(() => {
    if (!orderId && !cfOrderId) {
      setStatus('failed')
      return
    }

    let active = true
    let attempts = 0
    const maxAttempts = 20

    const poll = async () => {
      if (!active || hasRedirected.current) return
      attempts++
      setPollCount(attempts)

      const isPaid = await verify()
      if (isPaid && active && !hasRedirected.current) {
        hasRedirected.current = true
        setStatus('success')
        clearCart()

        // Play success chime
        try {
          const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext
          if (AudioContextClass) {
            const ctx = new AudioContextClass()
            const now = ctx.currentTime
            const osc = ctx.createOscillator()
            const gain = ctx.createGain()
            osc.type = 'triangle'
            osc.frequency.setValueAtTime(880, now)
            gain.gain.setValueAtTime(0.12, now)
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5)
            osc.connect(gain)
            gain.connect(ctx.destination)
            osc.start(now)
            osc.stop(now + 0.5)
          }
        } catch (_) {}

        setTimeout(() => {
          const targetId = orderId || cfOrderId
          window.location.replace(`/order/${targetId}/success`)
        }, 1200)
        return
      }

      if (attempts >= maxAttempts && active) {
        setStatus('timeout')
        return
      }

      if (active) {
        setTimeout(poll, 1500)
      }
    }

    poll()

    // Also verify on visibility change (returning from UPI app)
    const handleVisibility = () => {
      if (document.visibilityState === 'visible' && active && !hasRedirected.current) {
        poll()
      }
    }
    document.addEventListener('visibilitychange', handleVisibility)

    return () => {
      active = false
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [orderId, cfOrderId, verify, clearCart])

  const handleRetry = () => {
    setStatus('verifying')
    setPollCount(0)
    hasRedirected.current = false
    // Re-trigger by navigating to self
    window.location.reload()
  }

  const handleGoHome = () => {
    window.location.replace('/')
  }

  return (
    <div className="fixed inset-0 z-[100] bg-white dark:bg-zinc-950 flex flex-col items-center justify-center px-6">
      {status === 'verifying' && (
        <div className="flex flex-col items-center text-center space-y-5 animate-fade-in">
          {/* Pulsating radar */}
          <div className="relative h-24 w-24">
            <div className="absolute inset-0 rounded-full bg-primary/10 animate-ping" />
            <div className="absolute inset-2 rounded-full bg-primary/20 animate-ping" style={{ animationDelay: '0.3s' }} />
            <div className="relative h-24 w-24 rounded-full bg-primary/5 border-2 border-primary/30 flex items-center justify-center">
              <ShieldCheck className="h-10 w-10 text-primary animate-pulse" />
            </div>
          </div>
          <h1 className="text-xl font-black text-text-primary">
            Verifying Payment with Bank...
          </h1>
          <p className="text-sm text-text-secondary font-medium max-w-xs">
            Please wait while we confirm your payment with the bank. This usually takes a few seconds.
          </p>
          <div className="flex items-center gap-2 text-xs text-text-muted">
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
            <span>Attempt {pollCount} of 20</span>
          </div>
        </div>
      )}

      {status === 'success' && (
        <div className="flex flex-col items-center text-center space-y-5 animate-fade-in">
          <div className="h-24 w-24 rounded-full bg-emerald-500/10 border-2 border-emerald-500/30 flex items-center justify-center">
            <CheckCircle2 className="h-12 w-12 text-emerald-500" />
          </div>
          <h1 className="text-2xl font-black text-emerald-600 dark:text-emerald-400">
            🎉 Payment Successful!
          </h1>
          <p className="text-sm text-text-secondary font-medium">
            Redirecting to your order tracking...
          </p>
          <Loader2 className="h-5 w-5 animate-spin text-primary" />
        </div>
      )}

      {(status === 'failed' || status === 'timeout') && (
        <div className="flex flex-col items-center text-center space-y-5 animate-fade-in">
          <div className="h-24 w-24 rounded-full bg-amber-500/10 border-2 border-amber-500/30 flex items-center justify-center">
            <AlertCircle className="h-12 w-12 text-amber-500" />
          </div>
          <h1 className="text-xl font-black text-text-primary">
            {status === 'timeout' ? 'Payment Verification Timed Out' : 'Could Not Verify Payment'}
          </h1>
          <p className="text-sm text-text-secondary font-medium max-w-xs">
            {status === 'timeout'
              ? 'If money was deducted, your order will be confirmed automatically within 2 minutes. You can also check your order status.'
              : 'No order ID was found. Please try again from the checkout page.'}
          </p>
          <div className="flex gap-3 mt-2">
            {status === 'timeout' && orderId && (
              <a
                href={`/order/${orderId}`}
                className="px-5 py-2.5 bg-primary text-white font-black text-sm rounded-xl hover:bg-primary/90 transition-all"
              >
                Check Order Status
              </a>
            )}
            <button
              onClick={status === 'timeout' ? handleRetry : handleGoHome}
              className="px-5 py-2.5 bg-zinc-100 dark:bg-zinc-800 text-text-primary font-bold text-sm rounded-xl hover:bg-zinc-200 dark:hover:bg-zinc-700 transition-all cursor-pointer"
            >
              {status === 'timeout' ? 'Retry Verification' : 'Go Home'}
            </button>
          </div>
        </div>
      )}

      {/* Footer trust badge */}
      <div className="absolute bottom-8 flex items-center gap-1.5 text-[10px] text-text-muted font-medium">
        <ShieldCheck className="h-3.5 w-3.5" />
        <span>Secured by Cashfree Payments & FastKirana</span>
      </div>
    </div>
  )
}

export default function CheckoutVerifyPage() {
  return (
    <Suspense
      fallback={
        <div className="fixed inset-0 z-[100] bg-white dark:bg-zinc-950 flex flex-col items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      }
    >
      <CheckoutVerifyContent />
    </Suspense>
  )
}
