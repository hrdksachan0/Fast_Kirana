'use client';
import { apiUrl } from '@/lib/api-url';

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Loader2, CheckCircle2, QrCode, X, RefreshCw, ShieldCheck, Zap, Layers, Landmark } from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { speakDoorstepPaymentReceived } from '@/lib/audio'

interface UpiQrModalProps {
  order: any
  onBack: () => void
  onConfirmPaid: (orderId: string) => void
}

export default function UpiQrModal({
  order,
  onBack,
  onConfirmPaid,
}: UpiQrModalProps) {
  const [qrData, setQrData] = useState<{
    qrImageUrl: string
    razorpayQrUrl?: string
    directUpiQrUrl?: string
    paymentStatus?: string
    paymentMethod?: string
    paymentLinkUrl?: string
    customerPhone?: string
    upiVpa?: string
    gateway?: string
    isCombined?: boolean
    combinedTotal?: number
    readableId?: string
    amount?: number
  } | null>(null)

  const [qrMode, setQrMode] = useState<'razorpay' | 'direct_upi'>('razorpay')
  const [isLoading, setIsLoading] = useState(true)
  const [livePaid, setLivePaid] = useState(false)

  useEffect(() => {
    if (!order?.id) return
    let isCancelled = false

    async function loadQrData() {
      try {
        const res = await fetch(`${apiUrl()}/api/delivery/orders/${order.id}/qr?t=${Date.now()}`)
        if (res.ok) {
          const data = await res.json()
          if (!isCancelled) {
            setQrData({
              qrImageUrl: data.qrImageUrl,
              razorpayQrUrl: data.razorpayQrUrl || data.cashfreeQrUrl,
              directUpiQrUrl: data.directUpiQrUrl,
              paymentStatus: data.paymentStatus,
              paymentMethod: data.paymentMethod,
              paymentLinkUrl: data.paymentLinkUrl,
              customerPhone: data.customerPhone,
              upiVpa: data.upiVpa,
              gateway: data.gateway,
              isCombined: Boolean(data.isCombined),
              combinedTotal: data.combinedTotal,
              readableId: data.readableId,
              amount: data.amount,
            })
            if (data.paymentStatus === 'PAID') {
              if (!livePaid) {
                try {
                  triggerHaptic('success')
                  const effectiveAmt = data.combinedTotal || data.amount || order.combinedTotal || order.total
                  speakDoorstepPaymentReceived(effectiveAmt, data.readableId || order.readableId)
                } catch (e) {}
              }
              setLivePaid(true)
            }
          }
        }
      } catch (err) {
        console.error('Failed to fetch dynamic QR details:', err)
      } finally {
        if (!isCancelled) setIsLoading(false)
      }
    }

    loadQrData()

    // 2-Second Live Polling for Automatic Razorpay Payment Detection
    const pollInterval = setInterval(() => {
      if (document.visibilityState === 'visible' && !livePaid) {
        loadQrData()
      }
    }, 2000)

    return () => {
      isCancelled = true
      clearInterval(pollInterval)
    }
  }, [order?.id, livePaid, order?.combinedTotal, order?.total, order?.readableId])

  if (!order) return null

  const isAlreadyPaid = order.paymentStatus === 'PAID' || qrData?.paymentStatus === 'PAID' || livePaid

  const displayId = String(qrData?.readableId || order.readableId || order.id.slice(0, 8))
  const effectiveTotal = qrData?.combinedTotal || qrData?.amount || order.combinedTotal || order.total
  const isCombined = Boolean(qrData?.isCombined || order.companionOrder || order.combinedId)

  // Select QR according to active mode
  const hasRzpQr = Boolean(qrData?.razorpayQrUrl && qrData.razorpayQrUrl.startsWith('http'))
  const activeQrSrc = qrMode === 'razorpay'
    ? (hasRzpQr ? qrData?.razorpayQrUrl : '')
    : (qrData?.directUpiQrUrl || qrData?.qrImageUrl || '')
  const customerPhone = qrData?.customerPhone || (order.address?.phone || order.user?.phone || '').replace(/\D/g, '').slice(-10)

  const handleShareWhatsApp = () => {
    const doorstepPayUrl = (qrData as any)?.doorstepPayUrl || `${window.location.origin}/doorstep-pay/${order.id}`
    const text = encodeURIComponent(
      `Namaste! Aapka FastMinute Order #${displayId} ka bill ₹${effectiveTotal} hai.\n\nOnline pay karne ke liye yahan click karein:\n${doorstepPayUrl}\n\nGPay, PhonePe, Paytm, UPI — sab supported hai.`
    )
    const targetPhone = customerPhone ? `91${customerPhone}` : ''
    const waUrl = targetPhone ? `https://wa.me/${targetPhone}?text=${text}` : `https://wa.me/?text=${text}`
    window.open(waUrl, '_blank')
  }

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[100] bg-black/75 backdrop-blur-md flex items-center justify-center p-4"
      >
        <motion.div
          initial={{ scale: 0.95, y: 15 }}
          animate={{ scale: 1, y: 0 }}
          exit={{ scale: 0.95, y: 15 }}
          className="bg-card w-full max-w-sm rounded-3xl border border-border/80 p-5 shadow-2xl space-y-3.5 flex flex-col items-center relative overflow-hidden"
        >
          {/* Close Button */}
          <button
            type="button"
            onClick={onBack}
            className="absolute top-4 right-4 h-8 w-8 rounded-full bg-muted/60 text-text-secondary hover:text-text-primary flex items-center justify-center transition-colors cursor-pointer"
          >
            <X className="h-4 w-4" />
          </button>

          {/* Header */}
          <div className="text-center space-y-1 w-full pt-1">
            {isAlreadyPaid ? (
              <span className="inline-flex items-center gap-1.5 text-[10px] font-black uppercase text-emerald-600 tracking-wider bg-emerald-50 px-3.5 py-1 rounded-full border border-emerald-300 dark:bg-emerald-500/15 dark:border-emerald-500/30 dark:text-emerald-400 animate-pulse">
                <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" />
                PAYMENT RECEIVED ✅
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 text-[10px] font-black uppercase text-emerald-600 dark:text-emerald-400 tracking-wider bg-emerald-50 dark:bg-emerald-500/10 px-3.5 py-1 rounded-full border border-emerald-200 dark:border-emerald-500/20">
                <Zap className="h-3.5 w-3.5 fill-emerald-500 text-emerald-500" />
                FASTMINUTE RAZORPAY QR ⚡
              </span>
            )}
            
            <h3 className="text-base font-extrabold text-text-primary pt-0.5">
              {isAlreadyPaid ? '🎉 Payment Confirmed!' : 'Scan via GPay / PhonePe / Paytm'}
            </h3>
            <p className="text-xs text-text-muted">
              Order #{displayId} • <span className="font-black text-text-primary">{formatPrice(effectiveTotal)}</span>
            </p>
          </div>

          {/* Combined Order Highlight */}
          {isCombined && (
            <div className="w-full bg-emerald-50 dark:bg-emerald-500/10 border border-emerald-300 dark:border-emerald-500/30 rounded-xl px-3 py-1.5 flex items-center justify-center gap-1.5 text-[10px] font-black text-emerald-800 dark:text-emerald-300">
              <Layers className="h-3.5 w-3.5 text-emerald-600" />
              <span>📦 Combined Order (Grocery + Kitchen) • Bill: {formatPrice(effectiveTotal)}</span>
            </div>
          )}

          {isAlreadyPaid ? (
            /* Already Paid Green Screen for Rider */
            <div className="w-full bg-emerald-500/15 border-2 border-emerald-500/40 rounded-2xl p-5 flex flex-col items-center text-center space-y-3 animate-card-enter shadow-lg shadow-emerald-500/10">
              <div className="h-16 w-16 bg-emerald-500/20 rounded-full flex items-center justify-center text-emerald-600 dark:text-emerald-400 border border-emerald-500/40 shadow-inner">
                <CheckCircle2 className="h-10 w-10 text-emerald-500 animate-bounce-subtle" />
              </div>
              <div>
                <h4 className="text-base font-black text-emerald-700 dark:text-emerald-300">
                  Payment Verified ✅
                </h4>
                <p className="text-xs text-emerald-600 dark:text-emerald-400 font-medium mt-1">
                  {formatPrice(effectiveTotal)} received via Razorpay.
                </p>
                <div className="mt-3 bg-emerald-600 text-white px-4 py-2 rounded-xl text-xs font-black shadow-md border border-emerald-400/30">
                  Collect ₹0 Cash from Customer 🚀
                </div>
              </div>
            </div>
          ) : (
            /* Active Mode Selector & QR Code Display */
            <>
              {/* Tab Selector: ⚡ Auto-Verify vs 🏦 Normal UPI */}
              <div className="grid grid-cols-2 gap-1 p-1 bg-muted/60 rounded-xl w-full text-[11px] font-black">
                <button
                  type="button"
                  onClick={() => setQrMode('razorpay')}
                  className={`py-1.5 px-2 rounded-lg flex items-center justify-center gap-1 transition-all cursor-pointer ${
                    qrMode === 'razorpay'
                      ? 'bg-card text-emerald-600 shadow-xs border border-border/80 font-black'
                      : 'text-text-muted hover:text-text-primary'
                  }`}
                >
                  <Zap className="h-3 w-3 fill-emerald-500 text-emerald-500 shrink-0" />
                  <span className="truncate">Auto-Verify ⚡</span>
                </button>
                <button
                  type="button"
                  onClick={() => setQrMode('direct_upi')}
                  className={`py-1.5 px-2 rounded-lg flex items-center justify-center gap-1 transition-all cursor-pointer ${
                    qrMode === 'direct_upi'
                      ? 'bg-card text-text-primary shadow-xs border border-border/80 font-black'
                      : 'text-text-muted hover:text-text-primary'
                  }`}
                >
                  <Landmark className="h-3 w-3 text-slate-500 shrink-0" />
                  <span className="truncate">Normal UPI 🏦</span>
                </button>
              </div>

              {/* QR Container */}
              <div className="relative h-56 w-56 bg-white border-2 border-emerald-500/40 rounded-2xl p-2.5 shadow-xl flex flex-col items-center justify-center overflow-hidden group">
                {isLoading ? (
                  <div className="flex flex-col items-center gap-2">
                    <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                    <span className="text-[10px] font-bold text-slate-500">Generating Secure Razorpay QR...</span>
                  </div>
                ) : qrMode === 'razorpay' && !hasRzpQr ? (
                  <div className="flex flex-col items-center text-center p-3 gap-1.5">
                    <QrCode className="h-10 w-10 text-amber-500" />
                    <span className="text-xs font-black text-slate-800">Auto-Verify QR Unavailable</span>
                    <span className="text-[10px] text-slate-500 font-medium">Please switch to Normal UPI tab to accept payment</span>
                    <button
                      type="button"
                      onClick={() => setQrMode('direct_upi')}
                      className="mt-2 text-[10px] font-black bg-slate-900 text-white px-3 py-1 rounded-lg"
                    >
                      Switch to Normal UPI 🏦
                    </button>
                  </div>
                ) : (
                  <>
                    <img
                      src={activeQrSrc}
                      alt="FastMinute QR"
                      className="w-full h-full object-contain"
                    />
                    <div className="absolute bottom-1 bg-emerald-600 text-white text-[8.5px] font-black uppercase px-2 py-0.5 rounded-full shadow-sm flex items-center gap-1">
                      <span>{qrMode === 'razorpay' ? 'OFFICIAL RAZORPAY LOCKED ⚡' : 'STORE DIRECT UPI 🏦'}</span>
                    </div>
                  </>
                )}
              </div>

              {/* Instructional Text */}
              <div className="text-center space-y-0.5">
                <p className="text-[11px] font-extrabold text-text-primary">
                  {qrMode === 'razorpay'
                    ? `Amount ${formatPrice(effectiveTotal)} pre-locked • Fraud-Proof`
                    : `Direct Store VPA: ${qrData?.upiVpa || '7054470303-2@ibl'}`}
                </p>
                <p className="text-[10px] text-text-muted font-medium">
                  {qrMode === 'razorpay'
                    ? 'GPay, PhonePe, Paytm, CRED — sab supported'
                    : 'Customer manually enters amount if Razorpay fails'}
                </p>
              </div>

              {/* Share via WhatsApp */}
              <button
                type="button"
                onClick={handleShareWhatsApp}
                className="w-full py-2 px-3 bg-green-500/15 hover:bg-green-500/25 text-green-700 dark:text-green-300 border border-green-500/30 text-[11px] font-black rounded-xl transition-all active:scale-95 flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <span>📲 WhatsApp se Payment Link bhejein</span>
              </button>

              {/* Live Auto-Detect Status */}
              {qrMode === 'razorpay' && (
                <div className="flex items-center justify-center gap-2 text-[10px] font-bold text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-500/10 px-3.5 py-1.5 rounded-xl border border-emerald-300 dark:border-emerald-500/20 w-full">
                  <RefreshCw className="h-3 w-3 animate-spin text-emerald-500 shrink-0" />
                  <span className="leading-tight">Auto-detecting Razorpay Payment (2s)...</span>
                </div>
              )}
            </>
          )}

          {/* Action Buttons */}
          <div className="flex flex-col gap-2 w-full pt-1">
            {isAlreadyPaid ? (
              <button
                type="button"
                onClick={() => onConfirmPaid(order.id)}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer"
              >
                <CheckCircle2 className="h-4 w-4" />
                Complete Delivery ✅
              </button>
            ) : (
              <button
                type="button"
                onClick={() => onConfirmPaid(order.id)}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer"
              >
                <ShieldCheck className="h-4 w-4" />
                Confirm Customer Paid {formatPrice(effectiveTotal)} ✅
              </button>
            )}
            {!isAlreadyPaid && (
              <p className="text-[9.5px] text-center text-text-muted px-2">
                💡 Razorpay se payment auto-detect hote hi awaz aayegi. Fallback mode me manually confirm karein.
              </p>
            )}
            <button
              type="button"
              onClick={onBack}
              className="w-full py-2 border border-border hover:bg-muted/40 text-text-secondary font-bold text-xs rounded-xl transition-colors cursor-pointer text-center"
            >
              {isAlreadyPaid ? 'Cancel' : 'Back to Order Details'}
            </button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
