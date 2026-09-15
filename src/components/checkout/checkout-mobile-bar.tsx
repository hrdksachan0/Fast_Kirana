'use client'

import { Loader2, ChevronsRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatPrice } from '@/lib/formatters'
import { Address } from '@/types'

interface CheckoutMobileBarProps {
  grandTotal: number
  selectedAddress?: Address
  isPlacingOrder: boolean
  isSavingAddress: boolean
  paymentMethod: string
  handlePlaceOrderClick: () => void
}

export function CheckoutMobileBar({
  grandTotal,
  selectedAddress,
  isPlacingOrder,
  isSavingAddress,
  paymentMethod,
  handlePlaceOrderClick,
}: CheckoutMobileBarProps) {
  return (
    <div
      className="fixed bottom-0 left-0 right-0 z-40 md:hidden bg-white dark:bg-zinc-950 border-t border-border/80 shadow-[0_-8px_30px_rgba(0,0,0,0.08)] px-4 py-3 flex items-center justify-between"
      style={{ paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 12px)' }}
    >
      <div className="flex flex-col min-w-0 pr-2">
        <span className="text-[10px] text-text-secondary font-medium leading-none">To Pay</span>
        <span className="text-lg font-black text-primary leading-tight mt-0.5">
          {formatPrice(grandTotal)}
        </span>
        <div className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1 mt-0.5 truncate">
          {selectedAddress ? (
            <span className="truncate">📍 {selectedAddress.label || selectedAddress.street}</span>
          ) : (
            <span className="text-rose-500">📍 Select Address</span>
          )}
        </div>
      </div>

      <button
        type="button"
        disabled={isPlacingOrder || isSavingAddress}
        onClick={handlePlaceOrderClick}
        className={cn(
          'group relative overflow-hidden text-white rounded-2xl font-black text-xs sm:text-sm tracking-wide px-5 h-12 transition-all duration-300 active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg shrink-0',
          paymentMethod !== 'COD'
            ? 'bg-gradient-to-r from-emerald-600 to-teal-600 shadow-emerald-500/25 hover:shadow-emerald-500/40'
            : 'bg-gradient-to-r from-primary to-primary-dark shadow-primary/25 hover:shadow-primary/40',
          (isPlacingOrder || isSavingAddress) && 'opacity-60 cursor-not-allowed shadow-none'
        )}
      >
        {isPlacingOrder || isSavingAddress ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin text-white relative z-10" />
            <span className="relative z-10">
              {isSavingAddress ? 'Saving Address...' : 'Processing...'}
            </span>
          </>
        ) : (
          <>
            <span className="relative z-10">Place Order ({formatPrice(grandTotal)})</span>
            <ChevronsRight className="h-4 w-4 text-white relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
          </>
        )}
      </button>
    </div>
  )
}
