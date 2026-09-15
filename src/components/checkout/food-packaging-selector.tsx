'use client'

import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'

interface FoodPackagingSelectorProps {
  packagingOption: 'NORMAL' | 'PREMIUM'
  setPackagingOption: (val: 'NORMAL' | 'PREMIUM') => void
}

export function FoodPackagingSelector({
  packagingOption,
  setPackagingOption,
}: FoodPackagingSelectorProps) {
  return (
    <div className="border-t border-border/40 pt-4 space-y-2.5">
      <div className="flex items-center justify-between">
        <h3 className="text-xs sm:text-sm font-black text-text-primary flex items-center gap-1.5">
          <span>🍱</span>
          <span>Food Packaging</span>
        </h3>
        <span className="text-[10px] font-bold text-text-muted">Safe & Hot Delivery</span>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
        {/* Standard Packaging (₹0) */}
        <div
          onClick={() => {
            triggerHaptic('light')
            setPackagingOption('NORMAL')
          }}
          className={cn(
            'p-3 rounded-xl border-2 cursor-pointer transition-all flex items-center justify-between select-none',
            packagingOption === 'NORMAL'
              ? 'border-primary bg-primary/[0.02] shadow-xs'
              : 'border-border/60 hover:border-border'
          )}
        >
          <div>
            <div className="flex items-center gap-1.5 font-bold text-xs text-text-primary">
              <span>📦</span> Standard Eco Box
            </div>
            <p className="text-[10.5px] text-text-muted mt-0.5">Eco-friendly packaging</p>
          </div>
          <span className="text-emerald-600 dark:text-emerald-400 font-black text-[11px] bg-emerald-50 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md">
            FREE
          </span>
        </div>

        {/* Premium Thermal Packaging (₹15) */}
        <div
          onClick={() => {
            triggerHaptic('light')
            setPackagingOption('PREMIUM')
          }}
          className={cn(
            'p-3 rounded-xl border-2 cursor-pointer transition-all flex items-center justify-between select-none',
            packagingOption === 'PREMIUM'
              ? 'border-amber-500 bg-amber-500/[0.04] shadow-xs ring-1 ring-amber-500/20'
              : 'border-border/60 hover:border-amber-500/40'
          )}
        >
          <div>
            <div className="flex items-center gap-1.5 font-bold text-xs text-text-primary">
              <span>✨</span> Thermal Hot Box
            </div>
            <p className="text-[10.5px] text-text-muted mt-0.5">Insulated + spill-proof</p>
          </div>
          <span className="text-amber-600 dark:text-amber-400 font-black text-[11px] bg-amber-50 dark:bg-amber-950/40 px-2 py-0.5 rounded-md">
            +₹15
          </span>
        </div>
      </div>
    </div>
  )
}
