'use client'

import { X, AlertCircle, Loader2 } from 'lucide-react'

interface TrackerCancelModalProps {
  isOpen: boolean
  isCancelling: boolean
  onClose: () => void
  onConfirmCancel: () => void
}

export function TrackerCancelModal({
  isOpen,
  isCancelling,
  onClose,
  onConfirmCancel,
}: TrackerCancelModalProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-fade-in">
      <div className="bg-card border border-border/80 rounded-3xl p-6 sm:p-7 max-w-md w-full shadow-2xl space-y-5 animate-scale-in">
        <div className="flex items-start justify-between">
          <div className="h-12 w-12 rounded-2xl bg-red-100 dark:bg-red-950/50 text-red-600 dark:text-red-400 flex items-center justify-center text-xl font-bold">
            ⚠️
          </div>
          <button
            onClick={onClose}
            className="text-text-muted hover:text-text-primary p-1 rounded-lg transition-colors cursor-pointer"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div>
          <h3 className="text-lg font-black text-text-primary">Cancel Order?</h3>
          <p className="text-xs text-text-secondary mt-1.5 leading-relaxed">
            Are you sure you want to cancel this order? This action cannot be undone. If you paid online via UPI/Card, the refund will be credited back to your original payment method.
          </p>
        </div>

        <div className="bg-muted/40 border border-border/40 rounded-xl p-3 flex items-start gap-2 text-xs text-text-secondary">
          <AlertCircle className="h-4 w-4 text-amber-500 shrink-0 mt-0.5" />
          <span>Cancellation is only permitted while your order is pending store confirmation.</span>
        </div>

        <div className="flex items-center gap-3 pt-2">
          <button
            onClick={onClose}
            disabled={isCancelling}
            className="flex-1 py-3 px-4 rounded-xl border border-border/80 font-bold text-xs text-text-secondary hover:bg-muted transition-colors cursor-pointer"
          >
            Keep Order
          </button>
          <button
            onClick={onConfirmCancel}
            disabled={isCancelling}
            className="flex-1 py-3 px-4 rounded-xl bg-red-600 hover:bg-red-700 text-white font-black text-xs transition-colors flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
          >
            {isCancelling ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                <span>Cancelling...</span>
              </>
            ) : (
              <span>Yes, Cancel</span>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
