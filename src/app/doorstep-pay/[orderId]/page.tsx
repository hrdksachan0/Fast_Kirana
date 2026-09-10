'use client'

import { useEffect, useState, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'

/**
 * Doorstep Cashfree Payment Page
 * 
 * When a delivery rider shows QR at doorstep, customer scans and lands here.
 * This page loads Cashfree JS SDK, auto-opens checkout modal,
 * and auto-detects payment via polling + webhook.
 * 
 * URL: /doorstep-pay/[orderId]
 * QR encodes: https://fast-kirana-gtm.vercel.app/doorstep-pay/<orderId>
 */

function loadCashfreeScript(): Promise<boolean> {
  return new Promise((resolve) => {
    if ((window as any).Cashfree) {
      resolve(true)
      return
    }
    const script = document.createElement('script')
    script.src = 'https://sdk.cashfree.com/js/v3/cashfree.js'
    script.onload = () => resolve(true)
    script.onerror = () => resolve(false)
    document.body.appendChild(script)
  })
}

export default function DoorstepPayPage() {
  const params = useParams()
  const router = useRouter()
  const orderId = params?.orderId as string

  const [status, setStatus] = useState<'loading' | 'ready' | 'paying' | 'paid' | 'error'>('loading')
  const [orderInfo, setOrderInfo] = useState<{
    amount: number
    readableId: string
    shopName?: string
  } | null>(null)
  const [errorMsg, setErrorMsg] = useState('')

  // Step 1: Fetch order details + create Cashfree session + open checkout
  const initPayment = useCallback(async () => {
    if (!orderId) return

    try {
      setStatus('loading')

      // 1a. Fetch order info for display
      const orderRes = await fetch(`/api/delivery/orders/${orderId}/qr?t=${Date.now()}`)
      if (!orderRes.ok) {
        setErrorMsg('Order not found or expired.')
        setStatus('error')
        return
      }
      const orderData = await orderRes.json()

      if (orderData.paymentStatus === 'PAID') {
        setOrderInfo({ amount: orderData.amount, readableId: orderData.readableId || orderId.slice(0, 8) })
        setStatus('paid')
        return
      }

      setOrderInfo({
        amount: orderData.amount,
        readableId: orderData.readableId || orderId.slice(0, 8),
      })

      // 1b. Create Cashfree payment session
      const cfRes = await fetch('/api/payment/cashfree/create-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId }),
      })
      const cfData = await cfRes.json()

      if (!cfRes.ok || !cfData.paymentSessionId) {
        setErrorMsg(cfData.error || 'Payment session creation failed. Please try again.')
        setStatus('error')
        return
      }

      // 1c. Load Cashfree JS SDK
      const loaded = await loadCashfreeScript()
      if (!loaded || !(window as any).Cashfree) {
        setErrorMsg('Payment SDK failed to load. Please check your internet connection.')
        setStatus('error')
        return
      }

      setStatus('ready')

      // 1d. Launch Cashfree checkout modal
      const cashfree = (window as any).Cashfree({
        mode: process.env.NEXT_PUBLIC_CASHFREE_ENV === 'SANDBOX' ? 'sandbox' : 'production'
      })

      setStatus('paying')

      // Start polling for auto-detect
      let paymentSuccess = false
      let pollCount = 0
      const pollTimer = setInterval(async () => {
        pollCount++
        if (pollCount > 120 || paymentSuccess) {
          clearInterval(pollTimer)
          return
        }
        try {
          const verifyRes = await fetch('/api/payment/cashfree/verify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId }),
          })
          const verifyData = await verifyRes.json()
          if (verifyRes.ok && verifyData.paymentStatus === 'PAID') {
            paymentSuccess = true
            clearInterval(pollTimer)
            setStatus('paid')
          }
        } catch (_) {}
      }, 2500)

      try {
        await cashfree.checkout({
          paymentSessionId: cfData.paymentSessionId,
          redirectTarget: '_modal',
        })
      } catch (checkoutErr) {
        console.warn('Cashfree checkout modal note:', checkoutErr)
      }

      // After modal closes, check once more
      if (!paymentSuccess) {
        try {
          const verifyRes = await fetch('/api/payment/cashfree/verify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId }),
          })
          const verifyData = await verifyRes.json()
          if (verifyRes.ok && verifyData.paymentStatus === 'PAID') {
            paymentSuccess = true
            clearInterval(pollTimer)
            setStatus('paid')
          }
        } catch (_) {}
      }

      // If still not paid after modal close, show ready state to retry
      if (!paymentSuccess) {
        setStatus('ready')
      }
    } catch (err: any) {
      console.error('Doorstep payment error:', err)
      setErrorMsg(err.message || 'Something went wrong. Please try again.')
      setStatus('error')
    }
  }, [orderId])

  useEffect(() => {
    initPayment()
  }, [initPayment])

  return (
    <div className="min-h-screen bg-gradient-to-b from-emerald-50 to-white dark:from-zinc-950 dark:to-zinc-900 flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white dark:bg-zinc-900 rounded-3xl shadow-2xl border border-emerald-200 dark:border-zinc-700 overflow-hidden">

        {/* Header */}
        <div className="bg-emerald-600 text-white px-6 py-5 text-center">
          <div className="text-2xl font-black tracking-tight">FastKirana</div>
          <div className="text-emerald-100 text-xs font-medium mt-1">Doorstep Payment</div>
        </div>

        <div className="p-6 space-y-5">

          {/* Order Info */}
          {orderInfo && (
            <div className="bg-emerald-50 dark:bg-emerald-500/10 rounded-2xl p-4 text-center border border-emerald-200 dark:border-emerald-500/20">
              <p className="text-xs text-emerald-600 dark:text-emerald-400 font-bold">
                Order #{orderInfo.readableId}
              </p>
              <p className="text-3xl font-black text-emerald-700 dark:text-emerald-300 mt-1">
                ₹{Number(orderInfo.amount).toFixed(0)}
              </p>
            </div>
          )}

          {/* Status States */}
          {status === 'loading' && (
            <div className="flex flex-col items-center gap-3 py-8">
              <div className="h-10 w-10 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin" />
              <p className="text-sm font-bold text-zinc-600 dark:text-zinc-400">Loading payment...</p>
            </div>
          )}

          {status === 'paying' && (
            <div className="flex flex-col items-center gap-3 py-6">
              <div className="h-10 w-10 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin" />
              <p className="text-sm font-bold text-zinc-600 dark:text-zinc-400">
                Waiting for payment confirmation...
              </p>
              <p className="text-[10px] text-zinc-400">Auto-detecting payment every 2.5 seconds</p>
            </div>
          )}

          {status === 'ready' && (
            <div className="space-y-4">
              <p className="text-sm text-center text-zinc-600 dark:text-zinc-400 font-medium">
                Click below to pay securely via GPay, PhonePe, Paytm or any UPI app
              </p>
              <button
                onClick={initPayment}
                className="w-full py-4 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-base rounded-2xl shadow-lg transition-all active:scale-[0.97] flex items-center justify-center gap-2"
              >
                💳 Pay ₹{orderInfo ? Number(orderInfo.amount).toFixed(0) : '...'} Now
              </button>
              <p className="text-[10px] text-center text-zinc-400">
                Secured by Cashfree Payments • 100% Safe & Encrypted
              </p>
            </div>
          )}

          {status === 'paid' && (
            <div className="flex flex-col items-center gap-4 py-6">
              <div className="h-16 w-16 bg-emerald-100 dark:bg-emerald-500/20 rounded-full flex items-center justify-center">
                <svg className="h-10 w-10 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <div className="text-center">
                <h3 className="text-lg font-black text-emerald-700 dark:text-emerald-300">
                  Payment Successful! 🎉
                </h3>
                <p className="text-sm text-zinc-500 dark:text-zinc-400 mt-1">
                  ₹{orderInfo ? Number(orderInfo.amount).toFixed(0) : '...'} paid to FastKirana
                </p>
                <p className="text-xs text-emerald-600 dark:text-emerald-400 font-bold mt-2">
                  Order #{orderInfo?.readableId}
                </p>
              </div>
              <div className="bg-emerald-50 dark:bg-emerald-500/10 rounded-xl px-4 py-2 text-xs font-bold text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-500/20">
                ✅ Delivery partner ko batayein ki payment ho gaya
              </div>
            </div>
          )}

          {status === 'error' && (
            <div className="flex flex-col items-center gap-4 py-6">
              <div className="h-14 w-14 bg-red-100 dark:bg-red-500/20 rounded-full flex items-center justify-center">
                <svg className="h-8 w-8 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <div className="text-center">
                <h3 className="text-base font-black text-red-600 dark:text-red-400">
                  Payment Error
                </h3>
                <p className="text-xs text-zinc-500 mt-1">{errorMsg}</p>
              </div>
              <button
                onClick={initPayment}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm rounded-xl shadow-md transition-all active:scale-[0.97]"
              >
                🔄 Try Again
              </button>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="bg-zinc-50 dark:bg-zinc-800 px-6 py-3 text-center border-t border-zinc-200 dark:border-zinc-700">
          <p className="text-[10px] text-zinc-400">
            FastKirana • Powered by Cashfree Payments
          </p>
        </div>
      </div>
    </div>
  )
}
