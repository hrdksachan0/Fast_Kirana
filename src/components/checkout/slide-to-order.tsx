'use client'

import { Loader2, ChevronsRight } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface SlideToOrderProps {
  onConfirm: () => void
  isPlacingOrder: boolean
  disabled?: boolean
  amount: number
}

export function SlideToOrder({ onConfirm, isPlacingOrder, disabled, amount }: SlideToOrderProps) {
  return (
    <button
      type="button"
      disabled={isPlacingOrder || disabled}
      onClick={onConfirm}
      className={cn(
        'group relative overflow-hidden w-full h-14 bg-gradient-to-r from-accent to-accent-dark text-white rounded-full font-black text-sm sm:text-base tracking-wide uppercase transition-all duration-300 hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg shadow-accent/25 hover:shadow-xl hover:shadow-accent/45',
        (isPlacingOrder || disabled) && 'opacity-60 cursor-not-allowed shadow-none'
      )}
    >
      {isPlacingOrder ? (
        <>
          <Loader2 className="h-4 w-4 animate-spin text-white relative z-10" />
          <span className="relative z-10">Processing Order...</span>
        </>
      ) : (
        <>
          <span className="relative z-10">Place Order (₹{amount.toFixed(0)})</span>
          <ChevronsRight className="h-4 w-4 text-white relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
        </>
      )}
    </button>
  )
}
