'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { IndianRupee, Store } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface CodPaymentModalProps {
  order: any
  onClose: () => void
  onSelectRiderCash: (orderId: string) => void
  onSelectOwnerCash: (orderId: string) => void
  onSelectUpi: (orderId: string) => void
}

export default function CodPaymentModal({
  order,
  onClose,
  onSelectRiderCash,
  onSelectOwnerCash,
  onSelectUpi,
}: CodPaymentModalProps) {
  if (!order) return null

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
          className="bg-card w-full max-w-sm rounded-3xl border border-border p-6 shadow-2xl space-y-4"
        >
          <div className="text-center space-y-1.5">
            <div className="mx-auto h-12 w-12 rounded-full bg-amber-500/10 flex items-center justify-center text-amber-500">
              <IndianRupee className="h-6 w-6" />
            </div>
            <h3 className="text-lg font-black text-text-primary">Order Payment Settlement</h3>
            <p className="text-xs text-text-muted">
              Collect <span className="font-extrabold text-text-primary">{formatPrice(order.total)}</span> for Order #{order.readableId || order.id.slice(0, 8)}. How was this payment received?
            </p>
          </div>

          <div className="grid grid-cols-1 gap-2.5 pt-1">
            {/* Option 1: Rider Cash in Hand */}
            <button
              onClick={() => onSelectRiderCash(order.id)}
              className="flex items-center gap-3 w-full p-3.5 rounded-2xl border border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10 hover:border-amber-500/50 transition-all font-bold text-sm text-left cursor-pointer active:scale-98"
            >
              <span className="text-2xl">💵</span>
              <div>
                <p className="text-amber-700 dark:text-amber-400 font-black text-xs">
                  Cash Collected by Rider (जेब में नकद)
                </p>
                <p className="text-[10px] text-text-muted mt-0.5">
                  Rider received physical cash (adds to Cash in Hand)
                </p>
              </div>
            </button>

            {/* Option 2: Cash Received by Store Owner/Admin */}
            <button
              onClick={() => onSelectOwnerCash(order.id)}
              className="flex items-center gap-3 w-full p-3.5 rounded-2xl border border-purple-500/30 bg-purple-500/5 hover:bg-purple-500/10 hover:border-purple-500/50 transition-all font-bold text-sm text-left cursor-pointer active:scale-98"
            >
              <span className="text-2xl">🏪</span>
              <div>
                <p className="text-purple-700 dark:text-purple-300 font-black text-xs">
                  Cash Received by Store Owner / Admin
                </p>
                <p className="text-[10px] text-text-muted mt-0.5">
                  Customer paid cash directly to Owner/Counter (Not Rider Cash)
                </p>
              </div>
            </button>

            {/* Option 3: Online UPI Scan */}
            <button
              onClick={() => onSelectUpi(order.id)}
              className="flex items-center gap-3 w-full p-3.5 rounded-2xl border border-emerald-500/30 bg-emerald-500/5 hover:bg-emerald-500/10 hover:border-emerald-500/50 transition-all font-bold text-sm text-left cursor-pointer active:scale-98"
            >
              <span className="text-2xl">📱</span>
              <div>
                <p className="text-emerald-700 dark:text-emerald-400 font-black text-xs">
                  Online UPI QR Code Scan
                </p>
                <p className="text-[10px] text-text-muted mt-0.5">
                  Customer scanned QR — paid directly to store bank
                </p>
              </div>
            </button>
          </div>

          <button
            onClick={onClose}
            className="w-full text-center text-xs font-bold text-text-muted hover:text-text-primary transition-colors py-1 cursor-pointer pt-1"
          >
            Cancel
          </button>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
