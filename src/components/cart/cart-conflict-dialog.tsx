'use client'

import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { UtensilsCrossed, ShoppingBag, Store, Sparkles, CheckCircle2 } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { triggerHaptic } from '@/lib/haptic'
import { isCafeProduct } from '@/lib/utils'
import { getOutletName } from '@/lib/constants'
import { toast } from 'sonner'

export function CartConflictDialog() {
  const { pendingConflictProduct, setPendingConflictProduct } = useUIStore()
  const { items, addItem, clearRestaurantItems } = useCart()

  const isOpen = pendingConflictProduct !== null

  // Find existing restaurant in cart
  const existingRestaurantItem = items.find((item) => isCafeProduct(item.product))
  const existingOutletName = existingRestaurantItem ? getOutletName(existingRestaurantItem.product) : 'Current Restaurant'
  const newOutletName = pendingConflictProduct ? getOutletName(pendingConflictProduct) : 'New Restaurant'

  // Count grocery items that will remain safe
  const groceryItemsCount = items.filter((item) => !isCafeProduct(item.product)).length

  const handleConfirm = () => {
    triggerHaptic('medium')
    
    // Clear ONLY dishes from the previous restaurant — keep all grocery items intact!
    clearRestaurantItems()
    
    if (pendingConflictProduct) {
      addItem(pendingConflictProduct)
    }
    
    setPendingConflictProduct(null)
    
    if (groceryItemsCount > 0) {
      toast.success(`Switched to ${newOutletName}. ${groceryItemsCount} grocery item(s) kept safe in cart! 🛒`, {
        icon: '✨',
      })
    } else {
      toast.success(`Switched to ${newOutletName}! 🍽️`)
    }
  }

  const handleCancel = () => {
    triggerHaptic('light')
    setPendingConflictProduct(null)
  }

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && setPendingConflictProduct(null)}>
      <DialogContent showCloseButton={false} className="max-w-[340px] w-[92%] mx-auto border border-zinc-200/80 dark:border-zinc-800 bg-white dark:bg-zinc-950 rounded-[28px] shadow-2xl overflow-hidden p-5 gap-0">
        
        <DialogHeader className="pt-1 flex flex-col items-center text-center">
          {/* Outlet Switch Icon Badge */}
          <div className="h-12 w-12 rounded-2xl bg-amber-500/15 text-amber-600 dark:text-amber-400 flex items-center justify-center border border-amber-500/25 shadow-inner mb-3">
            <UtensilsCrossed size={22} className="stroke-[2.5]" />
          </div>

          <DialogTitle className="text-base font-black text-text-primary tracking-tight flex items-center gap-1.5 justify-center">
            Switch Restaurant?
          </DialogTitle>
          
          <DialogDescription className="text-xs font-semibold text-text-secondary mt-1.5 leading-relaxed">
            Your cart contains dishes from <strong className="text-amber-600 dark:text-amber-400">{existingOutletName}</strong>. You can only order food from 1 restaurant at a time.
          </DialogDescription>
        </DialogHeader>

        {/* Selected Product Preview Card */}
        {pendingConflictProduct && (
          <div className="my-3.5 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900/50 p-3 flex items-center gap-3">
            {pendingConflictProduct.imageUrl ? (
              <img
                src={pendingConflictProduct.imageUrl}
                alt={pendingConflictProduct.name}
                className="h-10 w-10 rounded-xl object-cover border border-zinc-200 dark:border-zinc-800 shrink-0"
              />
            ) : (
              <div className="h-10 w-10 rounded-xl bg-muted flex items-center justify-center border border-zinc-200 dark:border-zinc-800 text-zinc-400 shrink-0">
                <ShoppingBag size={16} />
              </div>
            )}
            <div className="text-left min-w-0 flex-1">
              <span className="inline-flex items-center gap-1 text-[9px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/10 px-1.5 py-0.5 rounded border border-emerald-500/20 uppercase tracking-wide">
                <Store size={10} /> {newOutletName}
              </span>
              <h4 className="text-xs font-black text-text-primary truncate leading-tight mt-1">{pendingConflictProduct.name}</h4>
              <p className="text-[10px] text-text-muted mt-0.5 font-bold">₹{pendingConflictProduct.price} • {pendingConflictProduct.unit}</p>
            </div>
          </div>
        )}

        {/* Grocery Protection Reassurance Banner */}
        <div className="mb-4 rounded-xl bg-emerald-500/10 border border-emerald-500/25 p-2.5 flex items-center gap-2">
          <CheckCircle2 size={16} className="text-emerald-600 dark:text-emerald-400 shrink-0" />
          <p className="text-[10.5px] font-bold text-emerald-700 dark:text-emerald-300 leading-tight">
            {groceryItemsCount > 0 ? (
              <>Your <span className="underline font-black">{groceryItemsCount} Grocery item(s)</span> will stay safe in your cart!</>
            ) : (
              <>Grocery items can always be combined with any restaurant!</>
            )}
          </p>
        </div>

        {/* Action Buttons */}
        <div className="grid grid-cols-2 gap-2.5">
          <Button
            type="button"
            variant="outline"
            onClick={handleCancel}
            className="w-full h-10 border-border bg-white dark:bg-zinc-900 hover:bg-muted/40 text-xs font-black rounded-xl transition-all cursor-pointer shadow-xs"
          >
            Cancel
          </Button>
          <Button
            type="button"
            onClick={handleConfirm}
            className="w-full h-10 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white text-xs font-black rounded-xl transition-all cursor-pointer shadow-sm shadow-emerald-600/25 hover:shadow-md"
          >
            Switch to {newOutletName.split(' ')[0]}
          </Button>
        </div>

      </DialogContent>
    </Dialog>
  )
}
