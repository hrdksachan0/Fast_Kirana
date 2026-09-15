'use client'

import React, { useState, useEffect, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { AlertTriangle, Banknote, XCircle, CheckCircle2, Clock } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'

export interface PaymentFailedCodModalProps {
  isOpen: boolean
  orderId: string
  orderReadableId?: string
  totalAmount: number
  onClose: () => void
  onSuccessCod: (orderId: string) => void
}

const TOTAL_COUNTDOWN_SECONDS = 60

export function PaymentFailedCodModal({
  isOpen,
  orderId,
  orderReadableId,
  totalAmount,
  onClose,
  onSuccessCod,
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

  // Handle auto-confirmation when countdown expires
  useEffect(() => {
    if (isOpen && secondsRemaining === 0 && !isProcessing && !isCancelled) {
      handleConfirmCod(true)
    }
  }, [secondsRemaining, isOpen, isProcessing, isCancelled])

  const handleStopAndCancel = async () => {
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
        toast.info('🛑 Order cancel kar diya gaya hai. Koi charge nahi kata.')
      } else {
        toast.info('Order cancelled.')
      }
    } catch (err) {
      console.error('Error cancelling order on stop click:', err)
      toast.info('Order cancel request submitted.')
    } finally {
      setIsProcessing(false)
      onClose()
    }
  }

  const handleConfirmCod = async (isAuto = false) => {
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
        toast.success(
          isAuto
            ? '🚚 Order COD par confirm ho gaya hai! Ghar par cash pay karein.'
            : '🎉 Order Cash on Delivery (COD) confirm ho gaya!'
        )
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
          className="w-full max-w-md bg-white rounded-3xl shadow-2xl border border-slate-200 overflow-hidden"
        >
          {/* Top Decorative Warning Bar */}
          <div className="bg-gradient-to-r from-amber-500 via-orange-500 to-rose-500 h-2 w-full" />

          <div className="p-5 sm:p-6">
            {/* Header Icon & Title */}
            <div className="flex items-start gap-3.5 mb-4">
              <div className="w-12 h-12 rounded-2xl bg-amber-50 border border-amber-200 flex items-center justify-center shrink-0 shadow-sm">
                <AlertTriangle className="w-6 h-6 text-amber-600 animate-bounce" />
              </div>
              <div>
                <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-rose-50 text-rose-700 text-xs font-bold mb-1 border border-rose-200">
                  <span>Payment Not Completed</span>
                </div>
                <h3 className="text-lg font-black text-slate-900 tracking-tight leading-tight">
                  Online Payment Cancel Ho Gaya
                </h3>
                {orderReadableId && (
                  <p className="text-xs text-slate-500 font-medium mt-0.5">
                    Order #{orderReadableId} • Total ₹{totalAmount}
                  </p>
                )}
              </div>
            </div>

            {/* Explanation Card */}
            <div className="bg-slate-50 border border-slate-200 rounded-2xl p-3.5 mb-4 text-slate-700 text-xs leading-relaxed">
              <p className="font-semibold text-slate-900 mb-1 flex items-center gap-1.5">
                <Banknote className="w-4 h-4 text-emerald-600 inline" />
                Koi baat nahi! Order COD par mangwayein:
              </p>
              Aapka order automatically <strong>Cash on Delivery (Ghar par payment)</strong> mein convert ho raha hai. Agar aapko yeh order nahi chahiye, toh turant <strong>'Roko / Cancel'</strong> dabayein.
            </div>

            {/* Countdown Slider & Timer Visual */}
            <div className="bg-amber-50/70 border border-amber-200/80 rounded-2xl p-3.5 mb-5">
              <div className="flex items-center justify-between text-xs font-bold text-amber-900 mb-2">
                <span className="flex items-center gap-1.5">
                  <Clock className="w-3.5 h-3.5 text-amber-600 animate-spin" style={{ animationDuration: '4s' }} />
                  COD mein convert hone ka samay:
                </span>
                <span className="font-mono text-sm font-black text-amber-700 bg-white px-2 py-0.5 rounded-lg border border-amber-200 shadow-2xs">
                  {formattedTime}
                </span>
              </div>

              {/* Progress Slider Track */}
              <div className="w-full h-3 bg-amber-200/60 rounded-full overflow-hidden p-0.5 shadow-inner">
                <motion.div
                  className="h-full bg-gradient-to-r from-amber-500 to-orange-500 rounded-full"
                  initial={{ width: '100%' }}
                  animate={{ width: `${progressPercent}%` }}
                  transition={{ duration: 1, ease: 'linear' }}
                />
              </div>

              <p className="text-[11px] text-amber-800/80 font-medium text-center mt-2">
                {secondsRemaining > 0
                  ? `⏰ 1 minute slider chal raha hai — rokein ya confirm karein`
                  : '⏳ Converting to Cash on Delivery...'}
              </p>
            </div>

            {/* Dual Action Buttons */}
            <div className="flex flex-col gap-2.5">
              {/* Primary STOP / CANCEL Button ("Roko") */}
              <button
                type="button"
                onClick={handleStopAndCancel}
                disabled={isProcessing}
                className="w-full py-3.5 px-4 rounded-xl border-2 border-rose-300 hover:border-rose-500 bg-rose-50 hover:bg-rose-100/80 active:bg-rose-200 text-rose-700 font-black text-sm transition-all duration-150 flex items-center justify-center gap-2 shadow-xs cursor-pointer disabled:opacity-50"
              >
                <XCircle className="w-4 h-4 text-rose-600" />
                <span>🛑 Roko / Cancel Order (Nahi Chahiye)</span>
              </button>

              {/* Secondary Instant COD Confirm Button */}
              <button
                type="button"
                onClick={() => handleConfirmCod(false)}
                disabled={isProcessing}
                className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-emerald-600 to-emerald-700 hover:from-emerald-700 hover:to-emerald-800 active:scale-[0.99] text-white font-black text-sm transition-all duration-150 flex items-center justify-center gap-2 shadow-md shadow-emerald-600/20 cursor-pointer disabled:opacity-50"
              >
                <CheckCircle2 className="w-4 h-4 text-white" />
                <span>💵 Abhi COD Confirm Karein (₹{totalAmount})</span>
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  )
}
