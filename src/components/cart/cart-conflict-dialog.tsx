'use client'

import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { AlertTriangle, ShoppingBag, Sparkles } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { triggerHaptic } from '@/lib/haptic'

export function CartConflictDialog() {
  const { pendingConflictProduct, setPendingConflictProduct } = useUIStore()
  const { addItem, clearCart } = useCart()

  const isOpen = pendingConflictProduct !== null

  const handleConfirm = () => {
    triggerHaptic('medium')
    clearCart()
    if (pendingConflictProduct) {
      // Add the new item
      addItem(pendingConflictProduct)
    }
    setPendingConflictProduct(null)
  }

  const handleCancel = () => {
    triggerHaptic('light')
    setPendingConflictProduct(null)
  }

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && setPendingConflictProduct(null)}>
      <DialogContent showCloseButton={false} className="max-w-[310px] w-[92%] mx-auto border border-zinc-200/80 dark:border-zinc-800 bg-white dark:bg-zinc-950 rounded-[24px] shadow-elevated overflow-hidden p-4 sm:p-5 gap-0">
        
        <DialogHeader className="pt-1 flex flex-col items-center text-center">
          {/* Glowing Caution Badge */}
          <div className="h-11 w-11 rounded-[14px] bg-amber-500/10 text-amber-500 flex items-center justify-center border border-amber-500/20 shadow-inner mb-3">
            <AlertTriangle size={20} className="stroke-[2.5]" />
          </div>

          <DialogTitle className="text-sm font-black text-text-primary tracking-tight flex items-center gap-1.5 justify-center">
            Replace Cart Items?
            <Sparkles className="h-3.5 w-3.5 text-amber-500 fill-amber-500/20" />
          </DialogTitle>
          <DialogDescription className="text-[10px] font-bold text-text-secondary mt-1.5 max-w-[250px] leading-normal">
            Your cart contains items from another store segment. Adding this item will clear your current cart.
          </DialogDescription>
        </DialogHeader>

        {/* Selected Product Preview Card */}
        {pendingConflictProduct && (
          <div className="my-3 rounded-xl border border-zinc-150 dark:border-zinc-800/80 bg-zinc-50 dark:bg-zinc-900/30 p-2 flex items-center gap-2.5">
            {pendingConflictProduct.imageUrl ? (
              <img
                src={pendingConflictProduct.imageUrl}
                alt={pendingConflictProduct.name}
                className="h-8 w-8 rounded-lg object-cover border border-zinc-200 dark:border-zinc-800"
              />
            ) : (
              <div className="h-8 w-8 rounded-lg bg-muted flex items-center justify-center border border-zinc-200 dark:border-zinc-800 text-zinc-400">
                <ShoppingBag size={14} />
              </div>
            )}
            <div className="text-left min-w-0 flex-1">
              <p className="text-[8px] font-extrabold text-[#00b140] uppercase tracking-wider">New Segment Item</p>
              <h4 className="text-[11px] font-black text-text-primary truncate leading-tight mt-0.5">{pendingConflictProduct.name}</h4>
              <p className="text-[9px] text-text-muted mt-0.5 font-bold">₹{pendingConflictProduct.price} • {pendingConflictProduct.unit}</p>
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="grid grid-cols-2 gap-2 mt-1">
          <Button
            type="button"
            variant="outline"
            onClick={handleCancel}
            className="w-full h-9 border-border bg-white dark:bg-zinc-900 hover:bg-muted/40 text-[11px] font-black rounded-xl transition-all cursor-pointer shadow-3xs"
          >
            Cancel
          </Button>
          <Button
            type="button"
            onClick={handleConfirm}
            className="w-full h-9 bg-gradient-to-r from-accent to-accent-dark hover:from-accent/95 hover:to-accent-dark/95 text-white text-[11px] font-black rounded-xl transition-all cursor-pointer shadow-sm shadow-accent/25 hover:shadow-md hover:shadow-accent/40"
          >
            Yes, Replace
          </Button>
        </div>

      </DialogContent>
    </Dialog>
  )
}
