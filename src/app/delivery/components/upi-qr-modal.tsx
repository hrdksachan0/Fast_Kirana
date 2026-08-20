'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Loader2, CheckCircle2, ShieldCheck, QrCode, X } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

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
    upiVpa: string
    qrImageUrl: string
    paymentStatus?: string
    paymentMethod?: string
  } | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!order?.id) return
    let isCancelled = false
    setIsLoading(true)

    async function loadQrData() {
      try {
        const res = await fetch(`/api/delivery/orders/${order.id}/qr`)
        if (res.ok) {
          const data = await res.json()
          if (!isCancelled) {
            setQrData({
              upiVpa: data.upiVpa || '7054470303@paytm',
              qrImageUrl: data.qrImageUrl,
              paymentStatus: data.paymentStatus,
              paymentMethod: data.paymentMethod,
            })
          }
        }
      } catch (err) {
        console.error('Failed to fetch dynamic QR details:', err)
      } finally {
        if (!isCancelled) setIsLoading(false)
      }
    }

    loadQrData()
    return () => {
      isCancelled = true
    }
  }, [order?.id])

  if (!order) return null

  const isAlreadyPaid = order.paymentStatus === 'PAID' || qrData?.paymentStatus === 'PAID'
  const isOnlinePayment = order.paymentMethod !== 'COD'

  // Fallback calculation if endpoint is loading
  const fallbackUpiUrl = `upi://pay?pa=7054470303@paytm&pn=FastKirana&am=${order.total}&cu=INR&tn=Order_${order.readableId || order.id.slice(0, 8)}`
  const fallbackQrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=280x280&data=${encodeURIComponent(fallbackUpiUrl)}`

  const activeQrSrc = qrData?.qrImageUrl || fallbackQrSrc
  const activeVpa = qrData?.upiVpa || '7054470303@paytm'

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[100] bg-black/70 backdrop-blur-md flex items-center justify-center p-4"
      >
        <motion.div
          initial={{ scale: 0.95, y: 15 }}
          animate={{ scale: 1, y: 0 }}
          exit={{ scale: 0.95, y: 15 }}
          className="bg-card w-full max-w-sm rounded-3xl border border-border/80 p-6 shadow-2xl space-y-5 flex flex-col items-center relative overflow-hidden"
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
              <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase text-emerald-600 tracking-wider bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200 dark:bg-emerald-500/10 dark:border-emerald-500/30 dark:text-emerald-400">
                <CheckCircle2 className="h-3 w-3" />
                ONLINE PAYMENT CONFIRMED ✅
              </span>
            ) : (
              <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase text-emerald-600 tracking-wider bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200 dark:bg-emerald-500/10 dark:border-emerald-500/30 dark:text-emerald-400">
                <QrCode className="h-3 w-3" />
                RAZORPAY / STORE UPI QR ACTIVE
              </span>
            )}
            
            <h3 className="text-base font-extrabold text-text-primary pt-1">
              {isAlreadyPaid ? 'Paid Online via Razorpay' : 'Scan QR Code to Pay'}
            </h3>
            <p className="text-xs text-text-muted">
              Order #{order.readableId || order.id.slice(0, 8)} • <span className="font-black text-text-primary">{formatPrice(order.total)}</span>
            </p>
          </div>

          {isAlreadyPaid ? (
            /* Already Paid Screen for Rider */
            <div className="w-full bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-5 flex flex-col items-center text-center space-y-3">
              <div className="h-16 w-16 bg-emerald-500/20 rounded-full flex items-center justify-center text-emerald-600 dark:text-emerald-400">
                <CheckCircle2 className="h-10 w-10" />
              </div>
              <div>
                <h4 className="text-sm font-black text-emerald-700 dark:text-emerald-300">
                  Payment Verified ✅
                </h4>
                <p className="text-xs text-emerald-600 dark:text-emerald-400 font-medium mt-1">
                  Customer has paid {formatPrice(order.total)} via {isOnlinePayment ? 'Razorpay Online' : 'UPI'}.
                </p>
                <div className="mt-3 bg-card/80 border border-emerald-500/20 px-3 py-1.5 rounded-xl text-[11px] font-black text-emerald-800 dark:text-emerald-200">
                  Collect ₹0 Cash from Customer 🚀
                </div>
              </div>
            </div>
          ) : (
            /* QR Code Wrapper for Doorstep UPI */
            <>
              <div className="relative h-52 w-52 bg-white border-2 border-emerald-500/20 rounded-2xl p-3 shadow-md flex items-center justify-center overflow-hidden">
                {isLoading ? (
                  <div className="flex flex-col items-center gap-2">
                    <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                    <span className="text-[10px] font-bold text-slate-500">Loading Razorpay QR...</span>
                  </div>
                ) : (
                  <img
                    src={activeQrSrc}
                    alt="FastKirana Razorpay Store QR"
                    className="w-full h-full object-contain"
                  />
                )}
              </div>

              {/* UPI ID Badge */}
              <div className="bg-muted/40 border border-border/60 px-3.5 py-2 rounded-xl text-center w-full">
                <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block">Store UPI ID</span>
                <span className="text-xs font-mono font-black text-primary select-all">{activeVpa}</span>
              </div>
            </>
          )}

          {/* Action Buttons */}
          <div className="flex flex-col gap-2 w-full pt-1">
            {!isAlreadyPaid && (
              <button
                type="button"
                onClick={() => onConfirmPaid(order.id)}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2"
              >
                <ShieldCheck className="h-4 w-4" />
                Confirm Payment Received (UPI)
              </button>
            )}
            <button
              type="button"
              onClick={onBack}
              className="w-full py-2.5 border border-border hover:bg-muted/40 text-text-secondary font-bold text-xs rounded-xl transition-colors"
            >
              {isAlreadyPaid ? 'Close Window' : 'Back to Order Details'}
            </button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
