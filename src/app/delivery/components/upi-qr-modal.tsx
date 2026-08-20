'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Loader2, CheckCircle2, QrCode, X, RefreshCw, ShieldCheck, Zap } from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'

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
    razorpayQrImageUrl?: string
    paymentStatus?: string
    paymentMethod?: string
    paymentLinkUrl?: string
    upiVpa?: string
  } | null>(null)
  const [qrMode, setQrMode] = useState<'razorpay' | 'direct_upi'>('razorpay')
  const [isLoading, setIsLoading] = useState(true)
  const [livePaid, setLivePaid] = useState(false)

  useEffect(() => {
    if (!order?.id) return
    let isCancelled = false

    async function loadQrData() {
      try {
        const res = await fetch(`/api/delivery/orders/${order.id}/qr?t=${Date.now()}`)
        if (res.ok) {
          const data = await res.json()
          if (!isCancelled) {
            setQrData({
              qrImageUrl: data.qrImageUrl,
              razorpayQrImageUrl: data.razorpayQrImageUrl,
              paymentStatus: data.paymentStatus,
              paymentMethod: data.paymentMethod,
              paymentLinkUrl: data.paymentLinkUrl,
              upiVpa: data.upiVpa,
            })
            if (data.paymentStatus === 'PAID') {
              if (!livePaid) {
                try {
                  triggerHaptic('success')
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

    // 3-Second Live Polling for Automatic Razorpay Payment Detection
    const pollInterval = setInterval(() => {
      if (document.visibilityState === 'visible' && !livePaid) {
        loadQrData()
      }
    }, 3000)

    return () => {
      isCancelled = true
      clearInterval(pollInterval)
    }
  }, [order?.id, livePaid])

  if (!order) return null

  const isAlreadyPaid = order.paymentStatus === 'PAID' || qrData?.paymentStatus === 'PAID' || livePaid

  const displayId = String(order.readableId || order.id.slice(0, 8))
  const upiVpa = qrData?.upiVpa || '7054470303@paytm'
  const defaultUpiUri = `upi://pay?pa=${upiVpa}&pn=FastKirana%20Store&am=${Number(order.total).toFixed(2)}&cu=INR&tn=Order%20%23${displayId}&tr=FK${displayId}`
  const directUpiQrSrc = qrData?.qrImageUrl || `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(defaultUpiUri)}`
  const razorpayQrSrc = qrData?.razorpayQrImageUrl || directUpiQrSrc

  const activeQrSrc = qrMode === 'razorpay' && qrData?.razorpayQrImageUrl ? razorpayQrSrc : directUpiQrSrc

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
          className="bg-card w-full max-w-sm rounded-3xl border border-border/80 p-6 shadow-2xl space-y-4 flex flex-col items-center relative overflow-hidden"
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
          <div className="text-center space-y-1.5 w-full pt-1">
            {isAlreadyPaid ? (
              <span className="inline-flex items-center gap-1.5 text-[10px] font-black uppercase text-emerald-600 tracking-wider bg-emerald-50 px-3.5 py-1 rounded-full border border-emerald-300 dark:bg-emerald-500/15 dark:border-emerald-500/30 dark:text-emerald-400 animate-pulse">
                <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" />
                PAYMENT RECEIVED ✅
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 text-[10px] font-black uppercase text-emerald-600 dark:text-emerald-400 tracking-wider bg-emerald-50 dark:bg-emerald-500/10 px-3.5 py-1 rounded-full border border-emerald-200 dark:border-emerald-500/20">
                <QrCode className="h-3.5 w-3.5 text-emerald-500" />
                DOORSTEP PAYMENT QR ⚡
              </span>
            )}
            
            <h3 className="text-base font-extrabold text-text-primary pt-1">
              {isAlreadyPaid ? '🎉 Payment Confirmed!' : 'Scan QR with GPay / PhonePe / Paytm'}
            </h3>
            <p className="text-xs text-text-muted">
              Order #{displayId} • <span className="font-black text-text-primary">{formatPrice(order.total)}</span>
            </p>
          </div>

          {!isAlreadyPaid && (
            /* Mode Switcher Tabs */
            <div className="flex bg-muted/50 p-1 rounded-2xl border border-border/50 w-full text-xs font-black">
              <button
                type="button"
                onClick={() => setQrMode('razorpay')}
                className={`flex-1 py-2 px-3 rounded-xl transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                  qrMode === 'razorpay'
                    ? 'bg-card text-emerald-600 shadow-md border border-emerald-500/20'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                <Zap className="h-3.5 w-3.5 fill-emerald-500" />
                <span>Razorpay Gateway</span>
              </button>
              <button
                type="button"
                onClick={() => setQrMode('direct_upi')}
                className={`flex-1 py-2 px-3 rounded-xl transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                  qrMode === 'direct_upi'
                    ? 'bg-card text-emerald-600 shadow-md border border-emerald-500/20'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                <QrCode className="h-3.5 w-3.5" />
                <span>Direct UPI VPA</span>
              </button>
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
                  {formatPrice(order.total)} credited successfully.
                </p>
                <div className="mt-3 bg-emerald-600 text-white px-4 py-2 rounded-xl text-xs font-black shadow-md border border-emerald-400/30">
                  Collect ₹0 Cash from Customer 🚀
                </div>
              </div>
            </div>
          ) : (
            /* QR Code Display */
            <>
              <div className="relative h-60 w-60 bg-white border-2 border-emerald-500/30 rounded-2xl p-3 shadow-xl flex flex-col items-center justify-center overflow-hidden group">
                {isLoading ? (
                  <div className="flex flex-col items-center gap-2">
                    <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                    <span className="text-[10px] font-bold text-slate-500">Generating Payment QR...</span>
                  </div>
                ) : (
                  <>
                    <img
                      src={activeQrSrc}
                      alt="FastKirana Doorstep QR"
                      className="w-full h-full object-contain"
                    />
                    <div className="absolute bottom-1 bg-emerald-600 text-white text-[9px] font-black uppercase px-2.5 py-0.5 rounded-full shadow-sm flex items-center gap-1">
                      <span>{qrMode === 'razorpay' ? 'RAZORPAY AUTO-DETECT ⚡' : 'DIRECT UPI VPA 📱'}</span>
                    </div>
                  </>
                )}
              </div>

              {/* Instructional Text */}
              <div className="text-center space-y-1">
                <p className="text-[11px] font-extrabold text-text-primary">
                  {qrMode === 'razorpay'
                    ? 'Scan with GPay, PhonePe or Paytm to pay on Razorpay Gateway'
                    : 'Scan with GPay, PhonePe, Paytm or BHIM for direct transfer'}
                </p>
                <p className="text-[10px] font-mono text-emerald-600 dark:text-emerald-400 font-bold">
                  Store VPA: {upiVpa}
                </p>
              </div>

              {/* Status Indicator */}
              <div className="flex items-center justify-center gap-2 text-[10px] font-bold text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-500/10 px-3.5 py-2 rounded-xl border border-emerald-300 dark:border-emerald-500/20 w-full">
                <RefreshCw className="h-3.5 w-3.5 animate-spin text-emerald-500 shrink-0" />
                <span className="leading-tight">Live Checking Razorpay Payment Every 3s...</span>
              </div>
            </>
          )}

          {/* Action Buttons */}
          <div className="flex flex-col gap-2 w-full pt-1">
            {!isAlreadyPaid && (
              <button
                type="button"
                onClick={() => onConfirmPaid(order.id)}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer"
              >
                <ShieldCheck className="h-4 w-4" />
                Confirm Payment Received ✅
              </button>
            )}
            <p className="text-[10px] text-center text-text-muted px-2">
              💡 Customer shows PhonePe/GPay success screen → Rider taps button above to confirm.
            </p>
            <button
              type="button"
              onClick={onBack}
              className="w-full py-2.5 border border-border hover:bg-muted/40 text-text-secondary font-bold text-xs rounded-xl transition-colors cursor-pointer text-center"
            >
              {isAlreadyPaid ? 'Close Window' : 'Back to Order Details'}
            </button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
