'use client'

import React from 'react'
import { RefreshCw } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface LiveCartItem {
  productName: string
  selectedVariant?: string
  quantity: number
}

export interface LiveCart {
  id: string
  userId: string
  userName: string
  userEmail: string
  userPhone: string
  items: LiveCartItem[]
  subtotal: number
  updatedAt: string | Date
}

export interface LiveCartsPanelProps {
  activeCarts: LiveCart[]
  isLoadingCarts: boolean
  onRefresh: () => void
  onSendCartNotification: (userId: string, userName: string) => void
  onOpenWhatsAppModal: (userName: string, userPhone: string) => void
}

export function LiveCartsPanel({
  activeCarts,
  isLoadingCarts,
  onRefresh,
  onSendCartNotification,
  onOpenWhatsAppModal,
}: LiveCartsPanelProps) {
  return (
    <div className="bg-card p-4 rounded-2xl border border-border/80 shadow-xs space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h4 className="text-sm font-black text-text-primary flex items-center gap-2">
            Active Shopping Carts
            <span className="flex h-2 w-2 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
            </span>
          </h4>
          <p className="text-[10px] text-text-secondary mt-0.5">
            Real-time view of products customers are adding to their carts
          </p>
        </div>
        <button
          onClick={onRefresh}
          disabled={isLoadingCarts}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-muted hover:bg-muted/80 text-text-primary text-xs font-bold rounded-lg border border-border transition-colors cursor-pointer disabled:opacity-50"
        >
          <RefreshCw className={`h-3 w-3 ${isLoadingCarts ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      {activeCarts.length === 0 ? (
        <div className="text-center py-8">
          <span className="text-2xl">🛒</span>
          <p className="text-xs text-text-secondary mt-2">
            No active customer shopping carts in the last 12 hours.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-border/60 text-xs">
            <thead>
              <tr className="text-text-secondary font-extrabold border-b border-border/40">
                <th className="py-2 px-3 text-left">Customer</th>
                <th className="py-2 px-3 text-left">Items in Cart</th>
                <th className="py-2 px-3 text-right">Cart Total</th>
                <th className="py-2 px-3 text-right">Last Active</th>
                <th className="py-2 px-3 text-center">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/40 font-medium">
              {activeCarts.map((cart) => {
                const timeAgoMin = Math.floor(
                  (new Date().getTime() - new Date(cart.updatedAt).getTime()) / 60000
                )
                let timeString = `${timeAgoMin}m ago`
                if (timeAgoMin === 0) timeString = 'Just now'
                else if (timeAgoMin >= 60) {
                  const hours = Math.floor(timeAgoMin / 60)
                  timeString = `${hours}h ago`
                }

                return (
                  <tr key={cart.id} className="hover:bg-muted/10 transition-colors">
                    <td className="py-3 px-3">
                      <p className="font-extrabold text-text-primary">{cart.userName}</p>
                      <p className="text-[10px] text-text-secondary mt-0.5">
                        {cart.userPhone} • {cart.userEmail}
                      </p>
                    </td>
                    <td className="py-3 px-3 max-w-xs md:max-w-md">
                      <div className="flex flex-wrap gap-1.5">
                        {cart.items.map((item, idx) => (
                          <span
                            key={idx}
                            className="inline-flex items-center gap-1 px-2 py-0.5 bg-muted border border-border/50 rounded-md text-[10px] text-text-primary font-bold"
                          >
                            {item.productName}
                            {item.selectedVariant && (
                              <span className="text-text-muted text-[9px]">
                                ({item.selectedVariant})
                              </span>
                            )}
                            <span className="text-primary font-black ml-1">x{item.quantity}</span>
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="py-3 px-3 text-right font-bold text-text-primary">
                      {formatPrice(cart.subtotal)}
                    </td>
                    <td className="py-3 px-3 text-right text-text-secondary font-bold">
                      {timeString}
                    </td>
                    <td className="py-3 px-3 text-center">
                      <div className="flex flex-col sm:flex-row gap-1.5 justify-center items-center">
                        <button
                          onClick={() => onSendCartNotification(cart.userId, cart.userName)}
                          className="px-2.5 py-1 bg-amber-500 hover:bg-amber-600 text-white text-[10px] font-black rounded-lg transition-colors cursor-pointer flex items-center gap-1 shrink-0"
                          title="Send Push Notification Alert to Customer"
                        >
                          🔔 Send Alert
                        </button>
                        <button
                          onClick={() => onOpenWhatsAppModal(cart.userName, cart.userPhone)}
                          className="px-2.5 py-1 bg-emerald-500 hover:bg-emerald-600 text-white text-[10px] font-black rounded-lg transition-colors cursor-pointer flex items-center gap-1 shrink-0"
                          title="Send WhatsApp Alert to Customer"
                        >
                          💬 WhatsApp
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
