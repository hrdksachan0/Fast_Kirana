'use client'

import { X, ChevronsRight, ShieldCheck } from 'lucide-react'

export interface PaymentSelectionModalProps {
  isOpen: boolean
  onClose: () => void
  grandTotal: number
  onlyCod: boolean
  deliveryMethod: string
  isPlacingOrder: boolean
  onSelectCod: () => void
  onSelectOnline: () => void
}

export function PaymentSelectionModal({
  isOpen,
  onClose,
  grandTotal,
  onlyCod,
  deliveryMethod,
  isPlacingOrder,
  onSelectCod,
  onSelectOnline,
}: PaymentSelectionModalProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="bg-white dark:bg-zinc-900 border border-border/80 w-full sm:max-w-md rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4 transform transition-all animate-in slide-in-from-bottom-5 sm:zoom-in-95 duration-200">
        {/* Modal Header */}
        <div className="flex items-center justify-between border-b border-border/40 pb-3.5">
          <div>
            <h3 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
              💳 Select Payment Method
            </h3>
            <p className="text-xs text-text-secondary font-medium mt-0.5">
              Grand Total:{' '}
              <span className="font-extrabold text-emerald-600 dark:text-emerald-400">
                ₹{grandTotal.toFixed(0)}
              </span>
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="h-8 w-8 rounded-full bg-zinc-100 dark:bg-zinc-800 text-text-secondary hover:text-text-primary flex items-center justify-center transition-colors cursor-pointer"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {onlyCod && (
          <div className="border border-amber-500/20 bg-amber-500/5 p-3 rounded-xl text-xs font-semibold text-amber-600 dark:text-amber-400 flex items-center gap-2">
            <span>ℹ️</span>
            <span>Online payment options are temporarily disabled by the store.</span>
          </div>
        )}

        {/* 2 Big Action Buttons */}
        <div className="space-y-3 pt-1">
          {/* Option 1: Cash on Delivery (DEFAULT) */}
          <button
            type="button"
            disabled={isPlacingOrder}
            onClick={onSelectCod}
            className="group relative overflow-hidden w-full p-4 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 text-white font-black text-left transition-all duration-200 hover:scale-[1.01] active:scale-[0.99] shadow-lg shadow-emerald-600/25 flex items-center justify-between border border-emerald-400/30 cursor-pointer"
          >
            <div className="flex items-center gap-3.5 relative z-10">
              <div className="h-11 w-11 rounded-xl bg-white/20 backdrop-blur-md flex items-center justify-center text-2xl shrink-0">
                💵
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-sm sm:text-base font-black tracking-wide">
                    {deliveryMethod === 'PICKUP' ? 'Cash on Pickup (काउंटर पर नकद)' : 'Cash on Delivery (कैश ऑन डिलीवरी)'}
                  </span>
                  <span className="bg-white/25 text-white text-[9px] font-black uppercase px-2 py-0.5 rounded-full shadow-sm">
                    POPULAR ⚡
                  </span>
                </div>
                <p className="text-xs text-emerald-100 font-medium mt-0.5">
                  {deliveryMethod === 'PICKUP'
                    ? 'दुकान काउंटर पर कैश या UPI से भुगतान करें'
                    : 'सामान मिलने पर डिलीवरी बॉय को कैश या UPI दें'}
                </p>
              </div>
            </div>
            <ChevronsRight className="h-5 w-5 text-white/90 relative z-10 transition-transform group-hover:translate-x-1 shrink-0" />
            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
          </button>

          {/* Option 2: Pay Online (Razorpay/UPI) */}
          {!onlyCod && (
            <button
              type="button"
              disabled={isPlacingOrder}
              onClick={onSelectOnline}
              className="group relative w-full p-4 rounded-2xl bg-zinc-50 dark:bg-zinc-800/80 hover:bg-zinc-100 dark:hover:bg-zinc-800 border-2 border-zinc-200 dark:border-zinc-700 text-text-primary font-black text-left transition-all duration-200 hover:scale-[1.01] active:scale-[0.99] flex items-center justify-between cursor-pointer"
            >
              <div className="flex items-center gap-3.5">
                <div className="h-11 w-11 rounded-xl bg-zinc-200/80 dark:bg-zinc-700 flex items-center justify-center text-2xl shrink-0">
                  📱
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm sm:text-base font-black tracking-wide">
                      Online Payment (ऑनलाइन पेमेंट)
                    </span>
                    <span className="text-xs font-black text-primary">₹{grandTotal.toFixed(0)}</span>
                  </div>
                  <p className="text-xs text-text-secondary font-medium mt-0.5">
                    GPay, PhonePe, Paytm UPI, कार्ड या नेट बैंकिंग
                  </p>
                </div>
              </div>
              <ChevronsRight className="h-5 w-5 text-text-secondary transition-transform group-hover:translate-x-1 shrink-0" />
            </button>
          )}
        </div>

        {/* Footer Trust Badge */}
        <div className="flex items-center justify-center gap-1.5 text-[10px] font-bold text-text-secondary pt-1">
          <ShieldCheck className="h-4 w-4 text-emerald-600 shrink-0" />
          <span>100% Safe Payment • Verified by FastKirana</span>
        </div>
      </div>
    </div>
  )
}
