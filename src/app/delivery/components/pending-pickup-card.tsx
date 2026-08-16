'use client'

import { motion } from 'framer-motion'
import { MapPin, Phone, ShoppingBag, Navigation, Clock, Loader2 } from 'lucide-react'
import { formatPrice, formatPhone, formatAddress } from '@/lib/utils'

interface PendingPickupCardProps {
  order: any
  updatingId: string | null
  onUpdateStatus: (orderId: string, status: string) => void
}

const itemVariants = {
  hidden: { opacity: 0, y: 18, scale: 0.97 },
  show: { opacity: 1, y: 0, scale: 1, transition: { type: 'spring' as const, stiffness: 260, damping: 24 } },
  exit: { opacity: 0, y: -12, scale: 0.96, transition: { duration: 0.22 } },
} as const

export default function PendingPickupCard({
  order,
  updatingId,
  onUpdateStatus,
}: PendingPickupCardProps) {
  const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'

  return (
    <motion.div
      key={order.id}
      variants={itemVariants}
      initial="hidden"
      animate="show"
      exit="exit"
      layout
      className={`relative bg-card border rounded-2xl shadow-sm overflow-hidden transition-all ${
        isRestaurant
          ? 'border-rose-200/80 dark:border-rose-500/20'
          : 'border-blue-200/60 dark:border-blue-500/15'
      }`}
    >
      {/* Subtle left accent */}
      <div className={`absolute left-0 top-0 bottom-0 w-0.5 rounded-l-2xl ${
        isRestaurant
          ? 'bg-gradient-to-b from-rose-400 to-pink-500'
          : 'bg-gradient-to-b from-blue-400 to-indigo-500'
      }`} />

      <div className="pl-4 pr-4 pt-4 pb-4 space-y-3">
        {/* Combined Multi-Pickup Banner */}
        {order.companionOrder && (
          <div className="bg-gradient-to-r from-amber-500/15 via-purple-500/15 to-indigo-500/15 border border-purple-500/30 p-2.5 rounded-xl flex items-center justify-between shadow-xs">
            <div className="flex items-center gap-2 text-xs font-black text-purple-700 dark:text-purple-300">
              <span className="p-1 rounded-lg bg-purple-500 text-white text-[10px]">🛍️</span>
              <span>COMBINED MULTI-PICKUP ORDER</span>
            </div>
            <span className="text-[10px] font-black bg-purple-500/20 text-purple-700 dark:text-purple-300 px-2 py-0.5 rounded-full border border-purple-500/30">
              2 Pickups
            </span>
          </div>
        )}

        {/* ID & Status */}
        <div className="flex justify-between items-center border-b border-border/40 pb-2.5">
          <div>
            <span className="text-[9px] font-bold text-text-muted flex items-center gap-1.5">
              Order ID
              {isRestaurant && (
                <span className="bg-rose-100 dark:bg-rose-500/10 text-rose-700 dark:text-rose-400 text-[8px] px-1.5 py-0.5 rounded-md font-black uppercase tracking-wider">
                  🥘 food
                </span>
              )}
            </span>
            <span className="text-xs font-mono font-black text-text-primary flex items-center gap-1.5 flex-wrap">
              #{order.readableId || order.id.slice(0, 8)}
              {order.companionOrder && (
                <span className="text-[10px] font-bold text-purple-600 dark:text-purple-400 bg-purple-500/10 px-1.5 py-0.5 rounded">
                  🛒 + 🍽️ Combined
                </span>
              )}
            </span>
          </div>
          <span className={`px-2.5 py-1 rounded-lg text-[9px] font-black uppercase tracking-wider ${
            order.status === 'PACKED'
              ? 'bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-500/10 dark:to-teal-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-200/60 dark:border-emerald-500/20'
              : order.status === 'PREPARING'
              ? 'bg-amber-500/10 text-amber-600 border border-amber-500/20 animate-pulse'
              : 'bg-blue-500/10 text-blue-600 border border-blue-500/20'
          }`}>
            {order.status === 'PACKED' ? '✅ Packed (Ready)' : order.status === 'PREPARING' ? '🍳 Kitchen Preparing' : '⏳ Order Confirmed'}
          </span>
        </div>

        {/* Pickup & Deliver info */}
        <div className="space-y-2 text-[11px] text-text-secondary font-semibold bg-gradient-to-b from-muted/10 to-transparent p-3 rounded-xl border border-border/30">
          <div className="flex items-start gap-2">
            <div className={`h-5 w-5 rounded-md flex items-center justify-center shrink-0 mt-0.5 text-[9px] font-black text-white ${
              isRestaurant ? 'bg-gradient-to-br from-rose-400 to-pink-500' : 'bg-gradient-to-br from-blue-400 to-indigo-500'
            }`}>
              P
            </div>
            <div>
              <span className="text-[9px] font-bold text-text-muted uppercase tracking-wider block">Pickup Point 1</span>
              <span className="text-text-primary font-bold">
                {order.shopName || (isRestaurant ? '🥘 Restaurant' : '🏪 FastKirana Central Hub')}
              </span>
            </div>
          </div>

          {order.companionOrder && (
            <div className="flex items-start gap-2 pt-1 border-t border-border/30">
              <div className="h-5 w-5 rounded-md bg-gradient-to-br from-purple-500 to-indigo-600 flex items-center justify-center shrink-0 mt-0.5 text-[9px] font-black text-white">
                P2
              </div>
              <div>
                <span className="text-[9px] font-bold text-purple-600 dark:text-purple-400 uppercase tracking-wider block">Pickup Point 2 (Companion)</span>
                <span className="text-text-primary font-bold">
                  {order.companionOrder.shopName || '🏪 FastKirana Store'}
                </span>
              </div>
            </div>
          )}

          <div className="h-px bg-border/30 ml-7" />
          <a
            href={
              (order.deliveryLat || order.address?.lat) && (order.deliveryLng || order.address?.lng)
                ? `https://www.google.com/maps/search/?api=1&query=${order.deliveryLat || order.address.lat},${order.deliveryLng || order.address.lng}`
                : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(formatAddress(order.address))}`
            }
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-start gap-2 hover:bg-muted/50 p-1 -m-1 rounded-lg transition-colors cursor-pointer group"
          >
            <div className="h-5 w-5 rounded-md bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center shrink-0 mt-0.5 group-hover:scale-105 transition-transform">
              <MapPin className="h-3 w-3 text-white" />
            </div>
            <div>
              <span className="text-[9px] font-bold text-text-muted uppercase tracking-wider block">
                Deliver To <span className="text-[7px] text-emerald-600 font-black ml-1 bg-emerald-50 dark:bg-emerald-500/10 px-1 py-0.2 rounded">NAV 🗺️</span>
              </span>
              <span className="text-text-primary font-bold group-hover:underline">{formatAddress(order.address, false)}</span>
            </div>
          </a>
        </div>

        {/* 2 Quick Action Buttons: Customer Map & Call */}
        <div className="grid grid-cols-2 gap-2 pt-1 border-t border-border/30">
          <a
            href={
              (order.deliveryLat || order.address?.lat) && (order.deliveryLng || order.address?.lng)
                ? `https://www.google.com/maps/search/?api=1&query=${order.deliveryLat || order.address.lat},${order.deliveryLng || order.address.lng}`
                : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(formatAddress(order.address))}`
            }
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-700 dark:text-emerald-400 border border-emerald-500/20 text-xs font-black tracking-tight transition-all active:scale-95 text-center"
          >
            <MapPin className="h-4 w-4 text-emerald-600" />
            Customer Map 📍
          </a>

          {(order.address?.phone || order.user?.phone || order.shopPhone) ? (
            <a
              href={`tel:${formatPhone(order.address?.phone || order.user?.phone || order.shopPhone).replace(/\s+/g, '')}`}
              className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-blue-500/10 hover:bg-blue-500/20 text-blue-700 dark:text-blue-400 border border-blue-500/20 text-xs font-black tracking-tight transition-all active:scale-95 text-center"
            >
              <Phone className="h-4 w-4 text-blue-600" />
              Call Customer 📞
            </a>
          ) : (
            <span className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl bg-muted text-text-muted text-xs font-bold opacity-50 text-center">
              <Phone className="h-4 w-4" />
              No Phone
            </span>
          )}
        </div>

        {/* Items summary with product price & total for pending pickup */}
        <div className="border-t border-border/40 pt-2 space-y-1.5">
          <div className="flex items-center justify-between text-[10px] font-bold text-text-secondary">
            <span className="flex items-center gap-1.5">
              <ShoppingBag className="h-3 w-3 text-text-muted" />
              Items to Pickup ({order.items?.length || 0 + (order.companionOrder?.items?.length || 0)})
            </span>
            {order.companionOrder && (
              <span className="text-purple-600 dark:text-purple-400 font-black text-[9px]">
                Multi-Store
              </span>
            )}
          </div>
          <div className="bg-muted/10 p-2.5 rounded-xl border border-border/30 space-y-1.5 max-h-[160px] overflow-y-auto">
            {order.items?.map((item: any) => (
              <div key={item.id} className="flex justify-between items-center text-[11px] py-0.5 border-b border-border/20 last:border-0">
                <div className="flex items-center gap-1.5 overflow-hidden pr-2">
                  <span className="text-text-primary font-bold truncate">{item.name}</span>
                  {item.price > 0 && (
                    <span className="text-[10px] font-semibold text-emerald-600 dark:text-emerald-400 shrink-0">
                      ({formatPrice(item.price)})
                    </span>
                  )}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span className="text-text-secondary font-semibold bg-muted/20 px-1.5 py-0.5 rounded text-[10px]">×{item.quantity}</span>
                  <span className="font-extrabold text-text-primary text-[11px]">
                    {formatPrice((item.price || 0) * (item.quantity || 1))}
                  </span>
                </div>
              </div>
            ))}

            {order.companionOrder?.items?.map((item: any) => (
              <div key={`comp-${item.id}`} className="flex justify-between items-center text-[11px] pt-1.5 border-t border-dashed border-purple-500/20 text-purple-700 dark:text-purple-300 py-0.5">
                <div className="flex items-center gap-1.5 overflow-hidden pr-2">
                  <span className="font-bold truncate">🧊 {item.name} ({order.companionOrder.shopName || 'Companion'})</span>
                  {item.price > 0 && (
                    <span className="text-[10px] font-semibold text-purple-600 dark:text-purple-400 shrink-0">
                      ({formatPrice(item.price)})
                    </span>
                  )}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span className="font-semibold bg-purple-500/10 px-1.5 py-0.5 rounded text-[10px]">×{item.quantity}</span>
                  <span className="font-extrabold text-purple-900 dark:text-purple-200 text-[11px]">
                    {formatPrice((item.price || 0) * (item.quantity || 1))}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="flex justify-between items-center pt-1.5 border-t border-border/40">
          <div>
            <span className="text-[9px] font-bold text-text-secondary block">
              {order.companionOrder ? 'Combined Amount' : 'Amount'}
            </span>
            <span className="text-sm font-black text-text-primary">
              {formatPrice((order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0))}
            </span>
            <span className="text-[8px] text-text-muted font-bold block">
              ({order.paymentMethod === 'COD' ? '💰 Collect Cash' : '✅ Paid Online'})
            </span>
          </div>

          {order.status === 'PACKED' ? (
            <button
              onClick={() => onUpdateStatus(order.id, 'SHIPPED')}
              disabled={updatingId === order.id}
              className={`flex items-center gap-1.5 px-4 py-3 min-h-[44px] text-white text-xs font-bold rounded-xl transition-all shadow-md active:scale-95 disabled:opacity-60 cursor-pointer ${
                isRestaurant
                  ? 'bg-gradient-to-r from-rose-500 to-pink-600 hover:from-rose-600 hover:to-pink-700 shadow-rose-500/15'
                  : 'bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 shadow-blue-500/15'
              }`}
            >
              {updatingId === order.id ? (
                <Loader2 className="h-3.5 w-3.5 animate-spin" />
              ) : (
                <>
                  <Navigation className="h-3.5 w-3.5" />
                  Pick Up Order
                </>
              )}
            </button>
          ) : (
            <div className="flex flex-col items-end gap-1">
              <button
                disabled
                className="flex items-center gap-1.5 px-3 py-2 bg-amber-500/10 border border-amber-500/30 text-amber-600 dark:text-amber-400 text-xs font-bold rounded-xl cursor-not-allowed opacity-90 shadow-xs"
              >
                <Clock className="h-3.5 w-3.5 animate-spin" />
                Preparing in Kitchen...
              </button>
              <button
                onClick={() => onUpdateStatus(order.id, 'SHIPPED')}
                disabled={updatingId === order.id}
                className="text-[9px] font-black text-emerald-600 dark:text-emerald-400 hover:underline flex items-center gap-1 cursor-pointer pt-0.5 active:scale-95"
                title="Click if kitchen handed over food but forgot to press Pack on console"
              >
                <span>Food Handed Over? Pick Up Anyway 📦</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  )
}
