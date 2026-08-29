'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { MapPin, Phone, User, ShoppingBag, CheckCircle2, Loader2, Navigation, ChevronDown, ChevronUp, Sparkles } from 'lucide-react'
import { formatPrice, formatPhone, formatAddress } from '@/lib/utils'

interface ActiveDeliveryCardProps {
  order: any
  idx: number
  updatingId: string | null
  onMarkDelivered: (orderId: string) => void
}

const itemVariants = {
  hidden: { opacity: 0, y: 18, scale: 0.97 },
  show: { opacity: 1, y: 0, scale: 1, transition: { type: 'spring' as const, stiffness: 280, damping: 24 } },
  exit: { opacity: 0, y: -12, scale: 0.96, transition: { duration: 0.2 } },
} as const

export default function ActiveDeliveryCard({
  order,
  idx,
  updatingId,
  onMarkDelivered,
}: ActiveDeliveryCardProps) {
  const [showAllItems, setShowAllItems] = useState(false)
  const isCod = order.paymentMethod === 'COD'
  const totalAmount = (order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0)
  const allItems = [...(order.items || []), ...(order.companionOrder?.items || [])]

  const customerPhone = order.address?.phone || order.user?.phone || order.shopPhone
  const customerAddress = formatAddress(order.address)
  const mapUrl =
    (order.deliveryLat || order.address?.lat) && (order.deliveryLng || order.address?.lng)
      ? `https://www.google.com/maps/search/?api=1&query=${order.deliveryLat || order.address.lat},${order.deliveryLng || order.address.lng}`
      : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(customerAddress)}`

  return (
    <motion.div
      key={order.id}
      variants={itemVariants}
      initial="hidden"
      animate="show"
      exit="exit"
      layout
      className={`relative bg-card border rounded-3xl shadow-xl overflow-hidden transition-all duration-200 ${
        isCod
          ? 'border-amber-500/30 hover:border-amber-500/50 shadow-amber-500/5'
          : 'border-emerald-500/30 hover:border-emerald-500/50 shadow-emerald-500/5'
      }`}
    >
      {/* Top ambient highlight strip */}
      <div className={`h-1.5 w-full ${
        isCod
          ? 'bg-gradient-to-r from-amber-400 via-orange-500 to-amber-500'
          : 'bg-gradient-to-r from-emerald-400 via-teal-500 to-emerald-600'
      }`} />

      <div className="p-4 sm:p-5 space-y-4">
        {/* Combined Multi-Pickup Banner */}
        {order.companionOrder && (
          <div className="bg-gradient-to-r from-purple-500/15 via-indigo-500/15 to-purple-500/15 border border-purple-500/30 p-2.5 rounded-2xl flex items-center justify-between shadow-xs">
            <div className="flex items-center gap-2 text-xs font-black text-purple-700 dark:text-purple-300">
              <span className="p-1 rounded-lg bg-purple-500 text-white text-[10px]">🛍️</span>
              <span>COMBINED MULTI-PICKUP ORDER</span>
            </div>
            <span className="text-[10px] font-black bg-purple-500/20 text-purple-700 dark:text-purple-300 px-2.5 py-0.5 rounded-full border border-purple-500/30">
              2 Pickups
            </span>
          </div>
        )}

        {/* Header Row: Stop Badge, Order ID, Payment Type */}
        <div className="flex justify-between items-start gap-2 border-b border-border/40 pb-3">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <span className="relative flex h-2.5 w-2.5 shrink-0">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
              </span>
              <span className="px-2 py-0.5 rounded-md bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 text-[10px] font-black uppercase tracking-wider border border-emerald-500/25">
                Stop #{idx + 1} • Active Drop
              </span>
            </div>
            <div className="flex items-center gap-1.5 flex-wrap pt-0.5">
              <span className="text-xs font-mono font-black text-text-primary">
                #{order.readableId || order.id.slice(0, 8)}
              </span>
              {order.companionOrder && (
                <span className="text-[9px] font-bold text-purple-600 dark:text-purple-400 bg-purple-500/10 px-1.5 py-0.5 rounded">
                  🛒 Grocery + 🍽️ Kitchen
                </span>
              )}
            </div>
          </div>

          <div className={`px-3 py-1 rounded-xl text-[10px] font-black tracking-wide shrink-0 ${
            isCod
              ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/30 shadow-xs'
              : 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 shadow-xs'
          }`}>
            {isCod ? '💵 Collect Cash (COD)' : '✅ Paid Online'}
          </div>
        </div>

        {/* Customer Info & Quick Communication Grid */}
        <div className="p-3.5 rounded-2xl bg-secondary/30 border border-border/50 space-y-2.5">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="h-10 w-10 rounded-2xl bg-gradient-to-br from-emerald-400 to-teal-600 flex items-center justify-center text-white text-xs font-black shadow-md shadow-emerald-500/20 shrink-0">
                <User className="h-4 w-4" />
              </div>
              <div className="min-w-0">
                <div className="text-xs font-black text-text-primary truncate">
                  {order.user?.name || order.userName || 'Customer'}
                </div>
                <div className="text-[11px] text-text-secondary font-mono mt-0.5">
                  {formatPhone(customerPhone) || 'No phone provided'}
                </div>
              </div>
            </div>
          </div>

          {/* Action Pills */}
          <div className="grid grid-cols-2 gap-2 pt-0.5">
            <a
              href={mapUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-1.5 py-2.5 px-3 min-h-[44px] rounded-xl bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 text-xs font-black tracking-tight transition-all active:scale-95 shadow-xs"
            >
              <Navigation className="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" />
              <span>Open in Maps 📍</span>
            </a>

            {customerPhone ? (
              <a
                href={`tel:${formatPhone(customerPhone).replace(/\s+/g, '')}`}
                className="flex items-center justify-center gap-1.5 py-2.5 px-3 min-h-[44px] rounded-xl bg-blue-500/15 hover:bg-blue-500/25 text-blue-700 dark:text-blue-300 border border-blue-500/30 text-xs font-black tracking-tight transition-all active:scale-95 shadow-xs"
              >
                <Phone className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />
                <span>Call Customer 📞</span>
              </a>
            ) : (
              <span className="flex items-center justify-center gap-1.5 py-2.5 px-3 min-h-[44px] rounded-xl bg-muted/40 text-text-muted text-xs font-bold opacity-60">
                <Phone className="h-3.5 w-3.5" />
                <span>No Phone</span>
              </span>
            )}
          </div>
        </div>

        {/* Route Timeline: Store -> Destination */}
        <div className="p-3.5 rounded-2xl bg-muted/20 border border-border/40 space-y-2">
          {/* Pickup Step */}
          <div className="flex items-start gap-2.5">
            <div className="flex flex-col items-center shrink-0">
              <div className="h-6 w-6 rounded-lg bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-600 dark:text-emerald-400 text-[10px] font-black">
                1
              </div>
              <div className="w-0.5 h-6 bg-gradient-to-b from-emerald-500/40 to-teal-500/40 my-1 rounded-full" />
            </div>
            <div className="pt-0.5">
              <span className="text-[9px] font-black text-text-muted uppercase tracking-wider block">
                Pickup Source
              </span>
              <span className="text-xs font-bold text-text-primary block mt-0.5">
                {order.shopName || '🏪 FastKirana Darkstore Hub'}
              </span>
              {order.companionOrder && (
                <span className="text-[11px] font-semibold text-purple-600 dark:text-purple-400 block mt-1">
                  + {order.companionOrder.shopName || 'FastKirana Kitchen'}
                </span>
              )}
            </div>
          </div>

          {/* Delivery Step */}
          <a
            href={mapUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-start gap-2.5 group p-1 -m-1 rounded-xl hover:bg-secondary/40 transition-colors"
          >
            <div className="h-6 w-6 rounded-lg bg-blue-500/20 border border-blue-500/40 flex items-center justify-center text-blue-600 dark:text-blue-400 text-[10px] font-black shrink-0 mt-0.5">
              2
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5">
                <span className="text-[9px] font-black text-text-muted uppercase tracking-wider">
                  Deliver To
                </span>
                <span className="text-[8px] font-black text-emerald-600 dark:text-emerald-400 bg-emerald-500/15 px-1.5 py-0.2 rounded border border-emerald-500/25">
                  MAP
                </span>
              </div>
              <span className="text-xs font-bold text-text-primary block mt-0.5 leading-relaxed group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                {customerAddress}
              </span>
            </div>
          </a>
        </div>

        {/* Collapsible Order Items Bag */}
        <div className="border-t border-border/40 pt-2 space-y-2">
          <button
            type="button"
            onClick={() => setShowAllItems((prev) => !prev)}
            className="w-full flex items-center justify-between text-xs font-bold text-text-secondary hover:text-text-primary py-1 cursor-pointer"
          >
            <span className="flex items-center gap-1.5">
              <ShoppingBag className="h-3.5 w-3.5 text-emerald-500" />
              Bag Contents ({allItems.length} items)
            </span>
            <span className="flex items-center gap-1 text-[11px] text-emerald-600 dark:text-emerald-400 font-bold">
              {showAllItems ? 'Hide' : 'View'}
              {showAllItems ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
            </span>
          </button>

          {showAllItems ? (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              className="bg-secondary/20 rounded-2xl p-3 border border-border/40 space-y-1.5 max-h-48 overflow-y-auto"
            >
              {order.items?.map((item: any) => (
                <div key={item.id} className="flex justify-between items-center text-[11px] py-1 border-b border-border/20 last:border-0">
                  <div className="truncate pr-2">
                    <span className="text-text-primary font-bold">{item.name}</span>
                    {item.price > 0 && (
                      <span className="text-[10px] text-emerald-600 dark:text-emerald-400 ml-1 font-semibold">
                        ({formatPrice(item.price)})
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-text-secondary font-bold bg-muted/40 px-1.5 py-0.5 rounded text-[10px]">
                      ×{item.quantity}
                    </span>
                    <span className="font-black text-text-primary">
                      {formatPrice((item.price || 0) * (item.quantity || 1))}
                    </span>
                  </div>
                </div>
              ))}

              {order.companionOrder?.items?.map((item: any) => (
                <div key={`comp-${item.id}`} className="flex justify-between items-center text-[11px] py-1 border-b border-border/20 last:border-0 text-purple-700 dark:text-purple-300">
                  <div className="truncate pr-2">
                    <span className="font-bold">🍽️ {item.name}</span>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <span className="bg-purple-500/15 px-1.5 py-0.5 rounded text-[10px] font-bold">
                      ×{item.quantity}
                    </span>
                    <span className="font-black">
                      {formatPrice((item.price || 0) * (item.quantity || 1))}
                    </span>
                  </div>
                </div>
              ))}
            </motion.div>
          ) : (
            /* Compact preview chips */
            <div className="flex flex-wrap gap-1.5">
              {allItems.slice(0, 3).map((item: any, i: number) => (
                <span
                  key={i}
                  className="inline-flex items-center gap-1 text-[10px] font-bold bg-secondary/60 border border-border/40 px-2 py-0.5 rounded-lg text-text-secondary truncate max-w-[140px]"
                >
                  <span>{item.name}</span>
                  <span className="text-text-muted">×{item.quantity || 1}</span>
                </span>
              ))}
              {allItems.length > 3 && (
                <span className="text-[10px] font-bold bg-secondary text-text-muted px-2 py-0.5 rounded-lg border border-border/30">
                  +{allItems.length - 3} more
                </span>
              )}
            </div>
          )}
        </div>

        {/* Footer: Total to Collect & Primary Action Button */}
        <div className="flex items-center justify-between gap-3 pt-3 border-t border-border/40">
          <div>
            <span className="text-[9px] font-black uppercase tracking-wider text-text-muted block">
              {isCod ? '💵 Collect at Doorstep' : '✅ Order Value (Paid)'}
            </span>
            <span className="text-xl font-black text-text-primary tracking-tight">
              {formatPrice(totalAmount)}
            </span>
          </div>

          <button
            onClick={() => onMarkDelivered(order.id)}
            disabled={updatingId === order.id}
            className="flex-1 max-w-[200px] flex items-center justify-center gap-2 py-3.5 px-4 min-h-[48px] bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 hover:from-emerald-600 hover:to-teal-700 text-white text-xs font-black rounded-2xl transition-all shadow-lg shadow-emerald-500/25 active:scale-95 disabled:opacity-60 cursor-pointer"
          >
            {updatingId === order.id ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <>
                <CheckCircle2 className="h-4 w-4" />
                <span>{order.companionOrder ? 'Deliver Both ✅' : 'Mark Delivered ✅'}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </motion.div>
  )
}
