'use client'

import { useState } from 'react'
import { CreditCard, Loader2, ShieldCheck, ArrowRight, Lock } from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'

interface PayOnlineButtonProps {
  orderId: string
  amount: number
  readableId?: string | number
  customerName?: string
  customerPhone?: string
  onPaymentSuccess?: () => void
  variant?: 'banner' | 'button' | 'card'
  className?: string
}

export function PayOnlineButton({
  orderId,
  amount,
  readableId,
  customerName,
  customerPhone,
  onPaymentSuccess,
  variant = 'card',
  className = '',
}: PayOnlineButtonProps) {
  const [isProcessing, setIsProcessing] = useState(false)
  const [isVerifying, setIsVerifying] = useState(false)

  const loadRazorpayScript = (): Promise<boolean> => {
    return new Promise((resolve) => {
      if ((window as any).Razorpay) {
        resolve(true)
        return
      }
      const script = document.createElement('script')
      script.src = 'https://checkout.razorpay.com/v1/checkout.js'
      script.onload = () => resolve(true)
      script.onerror = () => resolve(false)
      document.body.appendChild(script)
    })
  }

  const handlePayOnline = async () => {
    try {
      triggerHaptic('light')
    } catch (e) {}

    setIsProcessing(true)

    try {
      // 1. Create Razorpay Payment Order
      const res = await fetch('/api/payment/razorpay/create-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.detail || data.error || 'Failed to initiate payment')
        setIsProcessing(false)
        return
      }

      // 2. Load SDK
      const loaded = await loadRazorpayScript()
      if (!loaded) {
        toast.error('Failed to load Razorpay Payment Gateway. Check internet connection.')
        setIsProcessing(false)
        return
      }

      const displayId = readableId ? `#${readableId}` : `#${orderId.slice(0, 8).toUpperCase()}`

      // 3. Launch Razorpay Modal
      const options = {
        key: data.keyId,
        amount: data.amount,
        currency: data.currency,
        name: 'FastKirana',
        description: `Order ${displayId} Payment`,
        order_id: data.razorpayOrderId,
        prefill: {
          name: customerName || '',
          contact: customerPhone || '',
        },
        theme: {
          color: '#059669',
        },
        handler: async function (response: any) {
          setIsVerifying(true)
          try {
            const verifyRes = await fetch('/api/payment/razorpay/verify-signature', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                orderId,
                razorpay_order_id: response.razorpay_order_id,
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_signature: response.razorpay_signature,
              }),
            })

            const verifyData = await verifyRes.json()

            if (verifyRes.ok) {
              try {
                triggerHaptic('success')
              } catch (e) {}
              toast.success('🎉 Payment Successful! Your order is now Paid Online.')
              if (onPaymentSuccess) {
                onPaymentSuccess()
              } else {
                window.location.reload()
              }
            } else {
              toast.error(verifyData.error || 'Payment verification failed.')
            }
          } catch (err: any) {
            toast.error(err.message || 'Error verifying payment')
          } finally {
            setIsVerifying(false)
            setIsProcessing(false)
          }
        },
        modal: {
          ondismiss: function () {
            setIsProcessing(false)
          },
        },
      }

      const rzp = new (window as any).Razorpay(options)
      rzp.on('payment.failed', function (response: any) {
        toast.error(`Payment Failed: ${response.error.description || 'Transaction declined'}`)
        setIsProcessing(false)
      })
      rzp.open()
    } catch (err: any) {
      console.error('Pay Online Error:', err)
      toast.error(err.message || 'Failed to open payment gateway')
      setIsProcessing(false)
    }
  }

  if (variant === 'button') {
    return (
      <button
        type="button"
        onClick={handlePayOnline}
        disabled={isProcessing || isVerifying}
        className={`w-full py-3.5 px-5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm rounded-2xl shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer ${className}`}
      >
        {isProcessing || isVerifying ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" />
            <span>{isVerifying ? 'Verifying Payment...' : 'Opening Payment Gateway...'}</span>
          </>
        ) : (
          <>
            <CreditCard className="h-4 w-4" />
            <span>Pay {formatPrice(amount)} Online</span>
            <ArrowRight className="h-4 w-4 ml-auto" />
          </>
        )}
      </button>
    )
  }

  if (variant === 'banner') {
    return (
      <div className={`p-4 bg-emerald-50/80 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-900/50 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-3 shadow-sm ${className}`}>
        <div className="flex items-center gap-3 text-left">
          <div className="h-9 w-9 rounded-xl bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400 flex items-center justify-center shrink-0">
            <CreditCard className="h-4 w-4" />
          </div>
          <div>
            <h4 className="text-xs font-bold text-text-primary">
              Pay Online via UPI or Card
            </h4>
            <p className="text-[11px] text-text-secondary font-normal mt-0.5">
              Avoid cash hassle at doorstep
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={handlePayOnline}
          disabled={isProcessing || isVerifying}
          className="w-full sm:w-auto px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs rounded-xl shadow-sm transition-all active:scale-95 flex items-center justify-center gap-1.5 shrink-0 cursor-pointer"
        >
          {isProcessing || isVerifying ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <>
              <span>Pay {formatPrice(amount)}</span>
              <ArrowRight className="h-3.5 w-3.5" />
            </>
          )}
        </button>
      </div>
    )
  }

  // Default clean, minimalist, high-end card variant
  return (
    <div className={`p-5 min-[375px]:p-6 bg-card border border-emerald-500/30 dark:border-emerald-500/20 rounded-3xl shadow-sm space-y-4 hover:border-emerald-500/50 transition-all ${className}`}>
      <div className="flex items-center justify-between gap-2 border-b border-border/40 pb-3">
        <div className="flex items-center gap-2">
          <div className="h-7 w-7 rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 flex items-center justify-center font-bold text-xs border border-emerald-500/20">
            💳
          </div>
          <span className="text-xs font-bold uppercase tracking-wider text-text-primary">
            Pay Online
          </span>
        </div>
        <div className="flex items-center gap-1 text-[11px] font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/40 px-2.5 py-1 rounded-full border border-emerald-200 dark:border-emerald-900/50">
          <ShieldCheck className="h-3.5 w-3.5" />
          <span>Instant & Secure</span>
        </div>
      </div>

      <div>
        <h3 className="text-base font-bold text-text-primary tracking-tight">
          Pay {formatPrice(amount)} Online
        </h3>
        <p className="text-xs text-text-secondary mt-1 leading-relaxed">
          Order is currently set to <span className="font-semibold text-amber-600 dark:text-amber-400">Cash on Delivery</span>. You can pay online using Google Pay, PhonePe, Paytm, BHIM, UPI or Cards.
        </p>
      </div>

      <button
        type="button"
        onClick={handlePayOnline}
        disabled={isProcessing || isVerifying}
        className="w-full py-3.5 px-6 bg-emerald-600 hover:bg-emerald-700 active:scale-[0.98] text-white font-bold text-sm rounded-2xl shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
      >
        {isProcessing || isVerifying ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin text-white" />
            <span>{isVerifying ? 'Verifying Payment...' : 'Opening Payment Gateway...'}</span>
          </>
        ) : (
          <>
            <Lock className="h-4 w-4" />
            <span>Pay {formatPrice(amount)} Online Now</span>
            <ArrowRight className="h-4 w-4 ml-auto" />
          </>
        )}
      </button>
    </div>
  )
}
