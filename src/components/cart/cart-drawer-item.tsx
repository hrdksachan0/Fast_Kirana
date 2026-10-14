'use client'

import { Minus, Plus } from 'lucide-react'
import { formatPrice, formatTime12h, cn } from '@/lib/utils'
import { ProductImage } from '@/components/product/product-image'

interface CartDrawerItemProps {
  item: any
  freeInfo?: { freeQty: number; badgeText?: string }
  isStoreClosed: boolean
  settings: any
  onRemove: (id: string, name: string) => void
  onUpdateQuantity: (id: string, name: string, quantity: number) => void
}

export function CartDrawerItem({
  item,
  freeInfo,
  isStoreClosed,
  settings,
  onRemove,
  onUpdateQuantity,
}: CartDrawerItemProps) {
  const isFreeItem = Boolean(freeInfo && freeInfo.freeQty > 0)
  const freeQty = freeInfo ? freeInfo.freeQty : 0
  const isFullyFree = isFreeItem && freeQty >= item.quantity
  const isPartiallyFree = isFreeItem && freeQty > 0 && freeQty < item.quantity

  const perItemSaving = isFullyFree
    ? item.product.price * item.quantity
    : isPartiallyFree
    ? item.product.price * freeQty
    : item.product.mrp > item.product.price
    ? (item.product.mrp - item.product.price) * item.quantity
    : 0

  return (
    <div className="mb-3">
      <div
        className={cn(
          "flex flex-col gap-2 rounded-2xl border p-3.5 transition-all duration-300 relative overflow-hidden",
          isFullyFree
            ? "border-emerald-500/50 bg-gradient-to-r from-emerald-500/10 via-emerald-50/40 to-white dark:from-emerald-950/40 dark:via-emerald-950/20 dark:to-zinc-900 shadow-sm"
            : isPartiallyFree
            ? "border-emerald-500/30 bg-emerald-50/30 dark:bg-emerald-950/20"
            : "border-zinc-100 dark:border-zinc-800/80 bg-zinc-50/50 dark:bg-zinc-900/40"
        )}
      >
        {/* Free Badge ribbon */}
        {isFreeItem && (
          <div className="flex items-center justify-between gap-1.5 -mt-0.5 mb-1 pb-1.5 border-b border-emerald-500/20">
            <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-600 text-white shadow-xs">
              <span>🎁</span>
              <span>{freeInfo?.badgeText || '100% FREE (BOGO)'}</span>
            </span>
            <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 flex items-center gap-0.5">
              <span>✨</span>
              <span>{isFullyFree ? '100% Free Item Unlocked' : `${freeQty} of ${item.quantity} Free`}</span>
            </span>
          </div>
        )}

        <div className="flex items-center gap-3.5">
          {/* Product image */}
          <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-xl bg-white dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80 overflow-hidden shadow-sm">
            <ProductImage
              src={item.product.imageUrl}
              alt={item.product.name}
              categorySlug={item.product.category?.slug}
              className="h-full w-full object-contain p-1"
            />
          </div>

          {/* Product details */}
          <div className="flex-1 min-w-0">
            <h4 className="text-xs sm:text-sm font-bold text-zinc-850 dark:text-zinc-100 line-clamp-2 leading-snug break-words">
              {item.product.name}
            </h4>
            <p className="text-[10px] text-zinc-500 font-bold mt-0.5">{item.product.unit}</p>
            {Array.isArray(item.product.selectedAddons) && item.product.selectedAddons.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-1">
                {item.product.selectedAddons.map((addon: any) => (
                  <span
                    key={addon.name}
                    className="inline-flex items-center text-[9px] font-bold text-emerald-700 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/40 px-1.5 py-0.5 rounded-md border border-emerald-200 dark:border-emerald-800/40"
                  >
                    +{addon.name} (₹{addon.price})
                  </span>
                ))}
              </div>
            )}
            <div className="flex items-center gap-2 mt-1.5 flex-wrap">
              {isFullyFree ? (
                <>
                  <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-bold">
                    {formatPrice(item.product.price * item.quantity)}
                  </span>
                  <span className="text-sm sm:text-base font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5 drop-shadow-xs">
                    <span className="text-xs">₹</span>0
                    <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded-md bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 shadow-2xs">
                      FREE
                    </span>
                  </span>
                </>
              ) : isPartiallyFree ? (
                <>
                  <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-bold">
                    {formatPrice(item.product.price * item.quantity)}
                  </span>
                  <span className="text-sm font-black text-emerald-600 dark:text-emerald-400">
                    {formatPrice(item.product.price * (item.quantity - freeQty))}
                  </span>
                  <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-1.5 py-0.5 rounded border border-emerald-500/25">
                    ({freeQty} FREE)
                  </span>
                </>
              ) : (
                <>
                  <span className="text-sm font-black text-zinc-850 dark:text-zinc-100">{formatPrice(item.product.price)}</span>
                  {item.product.mrp > item.product.price && (
                    <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-semibold">{formatPrice(item.product.mrp)}</span>
                  )}
                </>
              )}
            </div>
            {/* Per-item savings */}
            {perItemSaving > 0 && (
              <p className="text-[10px] font-extrabold text-emerald-600 dark:text-emerald-400 mt-1 bg-emerald-500/10 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md w-fit border border-emerald-500/20">
                {isFreeItem ? `🎉 Free Item (${formatPrice(perItemSaving)} saved)` : `Save ${formatPrice(perItemSaving)}`}
              </p>
            )}
            {isStoreClosed ? (
              <p className="text-[9px] font-black text-rose-500 mt-1.5 flex items-center gap-1 leading-none">
                <span>🏪</span> Closed (Timings: {
                  (item.product.category?.slug === 'restaurant')
                    ? `${formatTime12h(settings.restaurant_open_time)} - ${formatTime12h(settings.restaurant_close_time)}`
                    : `${formatTime12h(settings.cafe_open_time)} - ${formatTime12h(settings.cafe_close_time)}`
                })
              </p>
            ) : item.product.stock <= 0 || item.product.isAvailable === false ? (
              <p className="text-[9px] font-black text-red-550 mt-1.5 flex items-center gap-1">
                <span>❌</span> Out of Stock
              </p>
            ) : item.product.stock > 0 && item.quantity > item.product.stock ? (
              <p className="text-[9px] font-black text-amber-600 dark:text-amber-400 mt-1.5 flex items-center gap-1">
                <span>⚠️</span> Only {item.product.stock} available
              </p>
            ) : null}
          </div>

          {/* Quantity controller */}
          <div className="flex items-center gap-2 rounded-xl bg-white dark:bg-zinc-800 p-1 border border-zinc-200/80 dark:border-zinc-700/80 shadow-2xs">
            <button
              onClick={() => {
                if (item.quantity === 1) {
                  onRemove(item.product.id, item.product.name)
                } else {
                  onUpdateQuantity(item.product.id, item.product.name, item.quantity - 1)
                }
              }}
              className="flex h-7 w-7 items-center justify-center rounded-lg bg-zinc-50 dark:bg-zinc-900 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer active:scale-90"
              aria-label="Decrease quantity"
            >
              <Minus size={13} strokeWidth={2.5} />
            </button>
            <span className="w-5 text-center text-xs font-black text-zinc-800 dark:text-zinc-200">
              {item.quantity}
            </span>
            <button
              disabled={(item.product.stock > 0 && item.quantity >= item.product.stock) || isStoreClosed}
              onClick={() => onUpdateQuantity(item.product.id, item.product.name, item.quantity + 1)}
              className="flex h-7 w-7 items-center justify-center rounded-lg bg-zinc-50 dark:bg-zinc-900 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer active:scale-90 disabled:opacity-30 disabled:pointer-events-none"
              aria-label="Increase quantity"
            >
              <Plus size={13} strokeWidth={2.5} />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
