'use client'

import { useState } from 'react'
import { CreditCard, Loader2, Zap, ShieldCheck, ArrowRight } from 'lucide-react'
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
          color: '#E20A22',
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
        className={`w-full py-3 px-5 bg-gradient-to-r from-emerald-600 via-emerald-500 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-black text-xs min-[375px]:text-sm rounded-2xl shadow-lg hover:shadow-xl transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer border border-emerald-400/30 ${className}`}
      >
        {isProcessing || isVerifying ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" />
            <span>{isVerifying ? 'Verifying Payment...' : 'Opening Payment Gateway...'}</span>
          </>
        ) : (
          <>
            <CreditCard className="h-4 w-4" />
            <span>Pay {formatPrice(amount)} Online Now</span>
            <ArrowRight className="h-4 w-4 ml-auto" />
          </>
        )}
      </button>
    )
  }

  if (variant === 'banner') {
    return (
      <div className={`p-4 bg-gradient-to-r from-emerald-500/15 via-emerald-500/10 to-teal-500/15 border border-emerald-500/30 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-3 shadow-md ${className}`}>
        <div className="flex items-center gap-3 text-left">
          <div className="h-10 w-10 rounded-xl bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 flex items-center justify-center shrink-0 border border-emerald-500/30">
            <Zap className="h-5 w-5 fill-emerald-500" />
          </div>
          <div>
            <h4 className="text-xs font-black text-text-primary flex items-center gap-1.5">
              <span>Paying Cash on Delivery?</span>
              <span className="bg-emerald-500 text-white text-[9px] font-black uppercase px-2 py-0.5 rounded-full">Fast Pay</span>
            </h4>
            <p className="text-[11px] text-text-secondary font-medium mt-0.5">
              Switch to Online Payment via UPI, GPay, PhonePe or Cards
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={handlePayOnline}
          disabled={isProcessing || isVerifying}
          className="w-full sm:w-auto px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-95 flex items-center justify-center gap-1.5 shrink-0 cursor-pointer"
        >
          {isProcessing || isVerifying ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <>
              <CreditCard className="h-4 w-4" />
              <span>Pay {formatPrice(amount)}</span>
            </>
          )}
        </button>
      </div>
    )
  }

  // Default 'card' variant (Swiggy / Zepto Style prominent card)
  return (
    <div className={`relative overflow-hidden p-5 bg-gradient-to-br from-emerald-950/20 via-card to-emerald-900/10 border-2 border-emerald-500/40 rounded-3xl shadow-xl transition-all hover:border-emerald-500/60 ${className}`}>
      {/* Background glow circle */}
      <div className="absolute -top-12 -right-12 w-32 h-32 bg-emerald-500/15 rounded-full blur-2xl pointer-events-none" />

      <div className="flex flex-col space-y-3.5 relative z-10">
        {/* Top Header & Badge */}
        <div className="flex items-center justify-between gap-2">
          <span className="inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-wider bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30 px-3 py-1 rounded-full">
            <Zap className="h-3 w-3 text-emerald-500 fill-emerald-500" />
            SWIGGY / ZEPTO STYLE ONLINE PAY
          </span>
          <div className="flex items-center gap-1 text-[10px] font-bold text-text-secondary">
            <ShieldCheck className="h-3.5 w-3.5 text-emerald-500" />
            100% Safe & Instant
          </div>
        </div>

        {/* Title & Description */}
        <div>
          <h3 className="text-base font-black text-text-primary tracking-tight">
            Avoid Cash Hassle — Pay Online Now 💳
          </h3>
          <p className="text-xs font-medium text-text-secondary mt-1 leading-relaxed">
            Order is currently set to <span className="font-bold text-amber-600 dark:text-amber-400 uppercase">Cash on Delivery</span>. You can pay online anytime via UPI, GPay, PhonePe, Paytm, QR or Cards.
          </p>
        </div>

        {/* Payment Icons Bar */}
        <div className="flex items-center gap-2 bg-muted/40 p-2.5 rounded-2xl border border-border/50 text-[11px] font-bold text-text-secondary">
          <span className="text-sm">📱</span>
          <span>Supports GPay, PhonePe, Paytm, BHIM, Cards & NetBanking</span>
        </div>

        {/* Action Button */}
        <button
          type="button"
          onClick={handlePayOnline}
          disabled={isProcessing || isVerifying}
          className="w-full py-3.5 px-6 bg-gradient-to-r from-emerald-600 via-emerald-500 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-black text-sm rounded-2xl shadow-lg hover:shadow-xl transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer border border-emerald-400/40"
        >
          {isProcessing || isVerifying ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin text-white" />
              <span>{isVerifying ? 'Verifying Payment...' : 'Opening Payment Gateway...'}</span>
            </>
          ) : (
            <>
              <CreditCard className="h-4.5 w-4.5" />
              <span>Pay {formatPrice(amount)} Online Now</span>
              <ArrowRight className="h-4 w-4 ml-auto" />
            </>
          )}
        </button>
      </div>
    </div>
  )
}
