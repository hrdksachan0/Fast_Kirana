'use client'

import { motion } from 'framer-motion'
import { formatPrice } from '@/lib/formatters'

interface HandoverConfirmModalProps {
  confirmDeliveryOrder: any | null
  onClose: () => void
  onConfirm: (order: any) => void
}

export function HandoverConfirmModal({
  confirmDeliveryOrder,
  onClose,
  onConfirm,
}: HandoverConfirmModalProps) {
  if (!confirmDeliveryOrder) return null

  return (
    <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
      <motion.div
        initial={{ scale: 0.92, opacity: 0, y: 10 }}
        animate={{ scale: 1, opacity: 1, y: 0 }}
        className="bg-card border border-border/80 w-full max-w-sm rounded-3xl p-6 space-y-4 text-center shadow-2xl relative overflow-hidden"
      >
        <div className="absolute -top-12 -right-12 h-28 w-28 rounded-full bg-emerald-500/10 blur-2xl pointer-events-none" />
        <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-400 to-teal-600 text-white mx-auto flex items-center justify-center text-2xl shadow-lg shadow-emerald-500/25">
          📦
        </div>
        <div>
          <h3 className="text-base font-black text-text-primary">Confirm Parcel Handover</h3>
          <p className="text-xs font-mono font-bold text-emerald-600 dark:text-emerald-400 mt-1">
            Order #{confirmDeliveryOrder.readableId || confirmDeliveryOrder.id.slice(0, 8)} •{' '}
            {formatPrice(confirmDeliveryOrder.total)}
          </p>
          <p className="text-xs font-medium text-text-secondary mt-2.5 bg-secondary/50 p-3 rounded-2xl border border-border/50 leading-relaxed">
            Kya aapne customer ko parcel safely handover kar diya hai?
          </p>
        </div>
        <div className="grid grid-cols-2 gap-2.5 pt-1">
          <button
            type="button"
            onClick={onClose}
            className="w-full py-3.5 px-3 min-h-[44px] rounded-2xl border border-border text-xs font-bold text-text-secondary hover:bg-secondary transition-colors cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => onConfirm(confirmDeliveryOrder)}
            className="w-full py-3.5 px-3 min-h-[44px] rounded-2xl bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 text-white text-xs font-black shadow-lg shadow-emerald-500/30 hover:from-emerald-600 hover:to-teal-700 transition-all active:scale-95 cursor-pointer"
          >
            Yes, Delivered ✅
          </button>
        </div>
      </motion.div>
    </div>
  )
}
