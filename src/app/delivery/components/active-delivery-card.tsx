'use client'

import { motion } from 'framer-motion'
import { MapPin, Phone, User, ShoppingBag, CheckCircle2, Loader2 } from 'lucide-react'
import { formatPrice, formatPhone, formatAddress } from '@/lib/utils'

interface ActiveDeliveryCardProps {
  order: any
  idx: number
  updatingId: string | null
  onMarkDelivered: (orderId: string) => void
}

const itemVariants = {
  hidden: { opacity: 0, y: 18, scale: 0.97 },
  show: { opacity: 1, y: 0, scale: 1, transition: { type: 'spring' as const, stiffness: 260, damping: 24 } },
  exit: { opacity: 0, y: -12, scale: 0.96, transition: { duration: 0.22 } },
} as const

export default function ActiveDeliveryCard({
  order,
  idx,
  updatingId,
  onMarkDelivered,
}: ActiveDeliveryCardProps) {
  return (
    <motion.div
      key={order.id}
      variants={itemVariants}
      initial="hidden"
      animate="show"
      exit="exit"
      layout
      className="relative bg-card border border-border rounded-2xl shadow-md overflow-hidden"
    >
      {/* Green gradient left accent */}
      <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-emerald-400 via-teal-500 to-emerald-600 rounded-l-2xl" />

      <div className="pl-4 pr-4 pt-4 pb-4 space-y-3.5">
        {/* Combined Multi-Pickup Banner if companionOrder present */}
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

        {/* Top row: ID & Payment + pulsing indicator */}
        <div className="flex justify-between items-start border-b border-border/40 pb-3">
          <div className="flex items-center gap-2">
            <span className="relative flex h-2.5 w-2.5 shrink-0">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
            </span>
            <div>
              <div className="flex items-center gap-1.5">
                <span className="text-[10px] font-bold text-text-muted">Active Order</span>
                <span className="px-1.5 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-[8px] font-black uppercase tracking-wider border border-emerald-500/20">
                  Stop #{idx + 1}
                </span>
              </div>
              <span className="text-xs font-mono font-black text-text-primary flex items-center gap-1.5 flex-wrap">
                #{order.readableId || order.id.slice(0, 8)}
                {order.companionOrder && (
                  <span className="text-[10px] font-bold text-purple-600 dark:text-purple-400 bg-purple-500/10 px-1.5 py-0.5 rounded">
                    🛒 + 🍽️ Combined
                  </span>
                )}
              </span>
            </div>
          </div>
          <div className={`px-2.5 py-1 rounded-lg text-[10px] font-bold ${
            order.paymentMethod === 'COD' 
              ? 'bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-500/10 dark:to-orange-500/10 text-amber-700 dark:text-amber-400 border border-amber-200/60 dark:border-amber-500/20 animate-pulse-gentle' 
              : 'bg-accent/10 text-accent border border-accent/20'
          }`}>
            {order.paymentMethod === 'COD' ? '💰 Collect Cash (COD)' : '✅ Paid Online'}
          </div>
        </div>

        {/* Customer contact card & Quick Actions */}
        <div className="space-y-2 bg-gradient-to-r from-muted/30 to-muted/10 p-3 rounded-xl border border-border/40">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="h-9 w-9 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center text-white text-[10px] font-bold shadow-md shadow-emerald-500/15">
                <User className="h-4 w-4" />
              </div>
              <div>
                <div className="text-xs font-bold text-text-primary">{order.user?.name || 'Customer'}</div>
                <div className="text-[10px] text-text-secondary">{formatPhone(order.address?.phone || order.user?.phone || order.shopPhone) || 'No phone'}</div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2 pt-1">
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
        </div>

        {/* Pickup & Delivery with step indicators */}
        <div className="bg-gradient-to-b from-muted/15 to-muted/5 p-3.5 rounded-xl border border-border/40 space-y-0">
          <div className="flex gap-3">
            <div className="flex flex-col items-center shrink-0">
              <div className="h-7 w-7 rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center text-white text-[10px] font-black shadow-sm">
                1
              </div>
              <div className="w-0.5 flex-1 bg-gradient-to-b from-teal-400 to-emerald-300 my-1 rounded-full min-h-[20px]" />
            </div>
            <div className="pb-3 space-y-1">
              <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider">Pickup Point 1</span>
              <span className="text-[11px] leading-relaxed text-text-primary font-bold block">
                {order.shopName || '🏪 FastKirana Central Hub (Grocery Darkstore)'}
              </span>

              {order.companionOrder && (
                <div className="pt-2 border-t border-border/40">
                  <span className="text-[10px] font-bold text-purple-600 dark:text-purple-400 uppercase tracking-wider block">Pickup Point 2 (Companion)</span>
                  <span className="text-[11px] leading-relaxed text-text-primary font-bold block mt-0.5">
                    {order.companionOrder.shopName || '🏪 FastKirana Cafe / Restaurant'}
                  </span>
                </div>
              )}
            </div>
          </div>

          <a
            href={
              (order.deliveryLat || order.address?.lat) && (order.deliveryLng || order.address?.lng)
                ? `https://www.google.com/maps/search/?api=1&query=${order.deliveryLat || order.address.lat},${order.deliveryLng || order.address.lng}`
                : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(formatAddress(order.address))}`
            }
            target="_blank"
            rel="noopener noreferrer"
            className="flex gap-3 group/map hover:bg-emerald-50/50 dark:hover:bg-emerald-500/5 -mx-1 px-1 py-1 rounded-lg transition-colors cursor-pointer"
            title="Click to navigate with Google Maps"
          >
            <div className="flex flex-col items-center shrink-0">
              <div className="h-7 w-7 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-[10px] font-black shadow-sm">
                2
              </div>
            </div>
            <div>
              <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider flex items-center gap-1.5">
                Deliver To
                <span className="text-[8px] font-black text-emerald-600 bg-emerald-50 dark:bg-emerald-500/10 dark:text-emerald-400 px-1.5 py-0.5 rounded-md tracking-wider group-hover/map:bg-emerald-100 transition-colors">
                  NAVIGATE 🗺️
                </span>
              </span>
              <span className="text-[11px] leading-relaxed text-text-primary font-bold block mt-0.5 group-hover/map:underline">
                {formatAddress(order.address)}
              </span>
            </div>
          </a>
        </div>

        {/* Items bag summary with unit price & total price */}
        <div className="border-t border-border/40 pt-3 space-y-1.5">
          <div className="flex items-center justify-between text-[10px] font-bold text-text-secondary">
            <span className="flex items-center gap-1.5">
              <ShoppingBag className="h-3 w-3 text-text-muted" />
              Items in bag ({order.items.length + (order.companionOrder?.items?.length || 0)})
            </span>
            {order.companionOrder && (
              <span className="text-purple-600 dark:text-purple-400 font-black">
                Multi-Store Order
              </span>
            )}
          </div>
          <div className="bg-muted/10 p-2.5 rounded-xl border border-border/30 space-y-1.5 max-h-[180px] overflow-y-auto">
            {order.items.map((item: any) => (
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

        {/* COD total + action */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-t border-border/40 pt-3">
          <div>
            <span className="text-[10px] font-bold text-text-secondary block">
              {order.companionOrder ? 'Combined Total to Collect' : 'Total to Collect'}
            </span>
            <span className="text-lg font-black text-text-primary">
              {formatPrice((order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0))}
            </span>
          </div>
          
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <button
              onClick={() => onMarkDelivered(order.id)}
              disabled={updatingId === order.id}
              className="w-full sm:w-auto flex items-center justify-center gap-1.5 px-5 sm:px-6 py-3 min-h-[44px] bg-gradient-to-r from-emerald-500 to-teal-600 text-white text-xs font-black rounded-xl hover:from-emerald-600 hover:to-teal-700 transition-all shadow-md shadow-emerald-500/20 active:scale-95 disabled:opacity-60 cursor-pointer"
            >
              {updatingId === order.id ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <>
                  <CheckCircle2 className="h-4 w-4" />
                  <span>{order.companionOrder ? 'Deliver Both Orders ✅' : 'Mark Delivered ✅'}</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  )
}
