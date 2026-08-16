'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { IndianRupee, CheckCircle2 } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface CodPaymentModalProps {
  order: any
  onClose: () => void
  onSelectCash: (orderId: string) => void
  onSelectOnline: (orderId: string) => void
}

export default function CodPaymentModal({
  order,
  onClose,
  onSelectCash,
  onSelectOnline,
}: CodPaymentModalProps) {
  if (!order) return null

  const orderTotal = (order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0)
  const displayId = order.readableId || order.id.slice(0, 8)

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
          className="bg-card w-full max-w-sm rounded-3xl border border-border p-5 sm:p-6 shadow-2xl space-y-4"
        >
          <div className="text-center space-y-1.5">
            <div className="mx-auto h-12 w-12 rounded-2xl bg-gradient-to-br from-emerald-400 to-teal-600 text-white flex items-center justify-center shadow-md shadow-emerald-500/20">
              <IndianRupee className="h-6 w-6 stroke-[2.5]" />
            </div>
            <h3 className="text-lg font-black text-text-primary tracking-tight">Payment Collection</h3>
            <p className="text-xs text-text-secondary font-medium">
              Order <span className="font-mono font-black text-text-primary">#{displayId}</span> • Total to Collect:{' '}
              <span className="font-black text-text-primary text-sm">{formatPrice(orderTotal)}</span>
            </p>
          </div>

          <div className="grid grid-cols-1 gap-3 pt-1">
            {/* Option 1: Cash Collected */}
            <button
              type="button"
              onClick={() => onSelectCash(order.id)}
              className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10 hover:border-amber-500/50 transition-all text-left cursor-pointer active:scale-98 shadow-xs group"
            >
              <div className="flex items-center gap-3 min-w-0">
                <div className="h-11 w-11 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-2xl shrink-0">
                  💵
                </div>
                <div className="min-w-0">
                  <p className="text-amber-700 dark:text-amber-300 font-black text-xs">
                    Cash Collected (नकद मिला)
                  </p>
                  <p className="text-[10px] text-text-muted mt-0.5 font-semibold">
                    Rider collected cash in hand
                  </p>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-lg bg-amber-500/20 text-amber-700 dark:text-amber-300 text-[10px] font-black shrink-0">
                Cash
              </span>
            </button>

            {/* Option 2: Online Payment Received */}
            <button
              type="button"
              onClick={() => onSelectOnline(order.id)}
              className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-emerald-500/30 bg-emerald-500/5 hover:bg-emerald-500/10 hover:border-emerald-500/50 transition-all text-left cursor-pointer active:scale-98 shadow-xs group"
            >
              <div className="flex items-center gap-3 min-w-0">
                <div className="h-11 w-11 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-2xl shrink-0">
                  📱
                </div>
                <div className="min-w-0">
                  <p className="text-emerald-700 dark:text-emerald-300 font-black text-xs">
                    Online Received (ऑनलाइन मिला)
                  </p>
                  <p className="text-[10px] text-text-muted mt-0.5 font-semibold">
                    Customer paid via UPI / Bank
                  </p>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-lg bg-emerald-500 text-white text-[10px] font-black shrink-0 flex items-center gap-1 shadow-xs">
                <CheckCircle2 className="h-3 w-3" />
                Received
              </span>
            </button>
          </div>

          <button
            type="button"
            onClick={onClose}
            className="w-full text-center text-xs font-bold text-text-muted hover:text-text-primary transition-colors py-2 cursor-pointer"
          >
            Cancel
          </button>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
