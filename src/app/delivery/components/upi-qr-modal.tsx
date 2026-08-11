'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Loader2 } from 'lucide-react'
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

  // Fallback calculation if endpoint is loading
  const fallbackUpiUrl = `upi://pay?pa=7054470303@paytm&pn=FastKirana&am=${order.total}&cu=INR&tn=Order_${order.readableId || order.id.slice(0, 8)}`
  const fallbackQrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(fallbackUpiUrl)}`

  const activeQrSrc = qrData?.qrImageUrl || fallbackQrSrc
  const activeVpa = qrData?.upiVpa || '7054470303@paytm'

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
      >
        <motion.div
          initial={{ scale: 0.95, y: 15 }}
          animate={{ scale: 1, y: 0 }}
          exit={{ scale: 0.95, y: 15 }}
          className="bg-card w-full max-w-sm rounded-3xl border border-border p-6 shadow-2xl space-y-5 flex flex-col items-center"
        >
          <div className="text-center space-y-1.5 w-full">
            <span className="text-xs font-black uppercase text-emerald-600 tracking-wider bg-emerald-50 px-2 py-0.5 rounded border border-emerald-100 dark:bg-emerald-500/10 dark:border-emerald-500/20 dark:text-emerald-400">
              UPI SCANNER ACTIVE
            </span>
            <h3 className="text-base font-extrabold text-text-primary pt-1">Scan QR to Pay</h3>
            <p className="text-xs text-text-muted">
              Pay <span className="font-black text-text-primary">{formatPrice(order.total)}</span> directly to FastKirana store bank
            </p>
          </div>

          {/* QR Code Wrapper */}
          <div className="relative h-48 w-48 bg-white border border-border rounded-2xl p-2.5 shadow-sm flex items-center justify-center overflow-hidden">
            {isLoading ? (
              <div className="flex flex-col items-center gap-2">
                <Loader2 className="h-7 w-7 animate-spin text-emerald-600" />
                <span className="text-[10px] font-bold text-slate-500">Loading QR...</span>
              </div>
            ) : (
              <img
                src={activeQrSrc}
                alt="UPI Payment QR Code"
                className="w-full h-full object-contain"
              />
            )}
          </div>

          <div className="text-center space-y-1">
            <p className="text-[10px] font-bold text-text-muted">
              Payee Handle: <span className="font-extrabold text-text-primary font-mono">{activeVpa}</span>
            </p>
            <p className="text-[9px] text-text-muted/80">
              Accepts GPay, PhonePe, Paytm, BHIM and all banking apps
            </p>
          </div>

          <div className="w-full grid grid-cols-2 gap-3.5 pt-2">
            <button
              onClick={onBack}
              className="h-11 border border-border rounded-xl text-xs font-bold hover:bg-muted text-text-secondary transition-colors cursor-pointer"
            >
              Go Back
            </button>
            <button
              onClick={() => onConfirmPaid(order.id)}
              className="h-11 bg-emerald-500 hover:bg-emerald-600 text-white rounded-xl text-xs font-extrabold transition-all shadow-md shadow-emerald-500/10 cursor-pointer active:scale-98"
            >
              Payment Received
            </button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
