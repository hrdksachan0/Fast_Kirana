'use client'

import React, { useState, useEffect, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { AlertTriangle, Banknote, XCircle, CheckCircle2, Clock, RefreshCw, X } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'

export interface PaymentFailedCodModalProps {
  isOpen: boolean
  orderId: string
  orderReadableId?: string
  totalAmount: number
  onClose: () => void
  onSuccessCod: (orderId: string) => void
  onRetryPayment?: () => void
}

const TOTAL_COUNTDOWN_SECONDS = 60

export function PaymentFailedCodModal({
  isOpen,
  orderId,
  orderReadableId,
  totalAmount,
  onClose,
  onSuccessCod,
  onRetryPayment,
}: PaymentFailedCodModalProps) {
  const [secondsRemaining, setSecondsRemaining] = useState(TOTAL_COUNTDOWN_SECONDS)
  const [isProcessing, setIsProcessing] = useState(false)
  const [isCancelled, setIsCancelled] = useState(false)
  const timerRef = useRef<NodeJS.Timeout | null>(null)

  // Reset countdown when modal opens
  useEffect(() => {
    if (isOpen) {
      setSecondsRemaining(TOTAL_COUNTDOWN_SECONDS)
      setIsProcessing(false)
      setIsCancelled(false)
      triggerHaptic('warning')

      timerRef.current = setInterval(() => {
        setSecondsRemaining((prev) => {
          if (prev <= 1) {
            if (timerRef.current) clearInterval(timerRef.current)
            return 0
          }
          return prev - 1
        })
      }, 1000)
    }

    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [isOpen])

  // SAFEGUARD: When countdown expires without user action, AUTO-CANCEL the order.
  // NEVER auto-convert to COD without explicit customer consent!
  useEffect(() => {
    if (isOpen && secondsRemaining === 0 && !isProcessing && !isCancelled) {
      handleStopAndCancel(true)
    }
  }, [secondsRemaining, isOpen, isProcessing, isCancelled])

  const handleStopAndCancel = async (isAutoTimeout = false) => {
    if (isProcessing) return
    setIsProcessing(true)
    setIsCancelled(true)
    if (timerRef.current) clearInterval(timerRef.current)

    try {
      triggerHaptic('light')
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'CANCELLED',
          scope: 'ALL',
          updateCombined: true,
        }),
      })

      if (res.ok) {
        toast.info(
          isAutoTimeout
            ? '⏳ Payment na hone par order cancel kar diya gaya hai. Koi charge nahi kata.'
            : '🛑 Order cancel kar diya gaya hai. Koi charge nahi kata.'
        )
      } else {
        toast.info('Order cancelled.')
      }
    } catch (err) {
      console.error('Error cancelling order:', err)
      toast.info('Order cancelled.')
    } finally {
      setIsProcessing(false)
      onClose()
    }
  }

  const handleConfirmCod = async () => {
    if (isProcessing || isCancelled) return
    setIsProcessing(true)
    if (timerRef.current) clearInterval(timerRef.current)

    try {
      triggerHaptic('success')
      const res = await fetch(`/api/orders/${orderId}/convert-to-cod`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })

      const data = await res.json()
      if (res.ok && data.success) {
        toast.success('🎉 Order Cash on Delivery (COD) confirm ho gaya!')
        onSuccessCod(orderId)
      } else {
        toast.error(data.error || 'Failed to convert order to COD')
        setIsProcessing(false)
      }
    } catch (err) {
      console.error('Error converting order to COD:', err)
      toast.error('Network error. Please try again.')
      setIsProcessing(false)
    }
  }

  const handleRetry = () => {
    if (isProcessing) return
    if (timerRef.current) clearInterval(timerRef.current)
    onClose()
    if (onRetryPayment) {
      onRetryPayment()
    }
  }

  if (!isOpen) return null

  const progressPercent = (secondsRemaining / TOTAL_COUNTDOWN_SECONDS) * 100
  const formattedTime = `00:${secondsRemaining < 10 ? '0' : ''}${secondsRemaining}`

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-3 sm:p-4 bg-black/65 backdrop-blur-sm">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          transition={{ duration: 0.25, ease: 'easeOut' }}
          className="w-full max-w-md bg-white dark:bg-zinc-900 rounded-3xl shadow-2xl border border-slate-200 dark:border-zinc-800 overflow-hidden relative"
        >
          {/* Top Decorative Warning Bar */}
          <div className="bg-gradient-to-r from-amber-500 via-orange-500 to-rose-500 h-2 w-full" />

          {/* Close button */}
          <button
            type="button"
            onClick={() => handleStopAndCancel(false)}
            disabled={isProcessing}
            className="absolute top-4 right-4 p-1.5 rounded-full text-slate-400 hover:text-slate-700 dark:hover:text-zinc-200 hover:bg-slate-100 dark:hover:bg-zinc-800 transition-colors"
            title="Cancel & Close"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="p-5 sm:p-6">
            {/* Header Icon & Title */}
            <div className="flex items-start gap-3.5 mb-4">
              <div className="w-12 h-12 rounded-2xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 flex items-center justify-center shrink-0 shadow-sm">
                <AlertTriangle className="w-6 h-6 text-amber-600 dark:text-amber-400" />
              </div>
              <div className="pr-6">
                <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-400 text-xs font-bold mb-1 border border-rose-200 dark:border-rose-800">
                  <span>Payment Incomplete</span>
                </div>
                <h3 className="text-lg font-black text-slate-900 dark:text-zinc-100 tracking-tight leading-tight">
                  Online Payment Cancel Ho Gaya
                </h3>
                {orderReadableId && (
                  <p className="text-xs text-slate-500 dark:text-zinc-400 font-medium mt-0.5">
                    Order #{orderReadableId} • Total ₹{totalAmount}
                  </p>
                )}
              </div>
            </div>

            {/* Explanation Card */}
            <div className="bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-2xl p-3.5 mb-4 text-slate-700 dark:text-zinc-300 text-xs leading-relaxed">
              <p className="font-semibold text-slate-900 dark:text-zinc-100 mb-1 flex items-center gap-1.5">
                <Banknote className="w-4 h-4 text-emerald-600 inline" />
                Aap kya karna chahenge?
              </p>
              Aapka online payment pura nahi hua. Aap is order ko <strong>Cash on Delivery (Ghar par payment)</strong> par mangwa sakte hain ya dobara online pay kar sakte hain.
            </div>

            {/* Countdown Slider & Timer Visual */}
            <div className="bg-amber-50/70 dark:bg-amber-950/30 border border-amber-200/80 dark:border-amber-800/50 rounded-2xl p-3.5 mb-5">
              <div className="flex items-center justify-between text-xs font-bold text-amber-900 dark:text-amber-300 mb-2">
                <span className="flex items-center gap-1.5">
                  <Clock className="w-3.5 h-3.5 text-amber-600 animate-spin" style={{ animationDuration: '4s' }} />
                  Auto-cancel countdown:
                </span>
                <span className="font-mono text-sm font-black text-amber-700 dark:text-amber-400 bg-white dark:bg-zinc-800 px-2 py-0.5 rounded-lg border border-amber-200 dark:border-amber-800 shadow-2xs">
                  {formattedTime}
                </span>
              </div>

              {/* Progress Slider Track */}
              <div className="w-full h-2.5 bg-amber-200/60 dark:bg-amber-900/40 rounded-full overflow-hidden p-0.5 shadow-inner">
                <motion.div
                  className="h-full bg-gradient-to-r from-amber-500 to-rose-500 rounded-full"
                  initial={{ width: '100%' }}
                  animate={{ width: `${progressPercent}%` }}
                  transition={{ duration: 1, ease: 'linear' }}
                />
              </div>

              <p className="text-[11px] text-amber-800/80 dark:text-amber-400/80 font-medium text-center mt-2">
                {secondsRemaining > 0
                  ? `⏰ 1 minute me decision na lene par order automatically cancel ho jayega`
                  : '⏳ Cancelling unpaid order...'}
              </p>
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col gap-2.5">
              {/* Primary Explicit COD Confirm Button */}
              <button
                type="button"
                onClick={handleConfirmCod}
                disabled={isProcessing}
                className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-700 hover:to-emerald-800 active:scale-[0.99] text-white font-black text-sm transition-all duration-150 flex items-center justify-center gap-2 shadow-md shadow-emerald-600/20 cursor-pointer disabled:opacity-50"
              >
                <CheckCircle2 className="w-4 h-4 text-white" />
                <span>💵 Cash on Delivery (COD) Chunein (₹{totalAmount})</span>
              </button>

              {/* Secondary Retry Online Payment Button */}
              {onRetryPayment && (
                <button
                  type="button"
                  onClick={handleRetry}
                  disabled={isProcessing}
                  className="w-full py-3 px-4 rounded-xl border-2 border-primary/30 hover:border-primary bg-primary/5 hover:bg-primary/10 text-primary font-black text-sm transition-all duration-150 flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
                >
                  <RefreshCw className="w-4 h-4 text-primary" />
                  <span>🔄 Payment Dobara Try Karein</span>
                </button>
              )}

              {/* Cancel Order Button */}
              <button
                type="button"
                onClick={() => handleStopAndCancel(false)}
                disabled={isProcessing}
                className="w-full py-2.5 px-4 rounded-xl border border-slate-200 dark:border-zinc-700 hover:bg-slate-100 dark:hover:bg-zinc-800 text-slate-600 dark:text-zinc-400 font-bold text-xs transition-all duration-150 flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
              >
                <XCircle className="w-3.5 h-3.5 text-slate-500" />
                <span>🛑 Nahi Chahiye / Cancel Order</span>
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  )
}
