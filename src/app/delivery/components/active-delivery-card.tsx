'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { MapPin, Phone, User, ShoppingBag, CheckCircle2, Loader2, Navigation, ChevronDown, ChevronUp, Sparkles, QrCode } from 'lucide-react'
import { formatPrice, formatPhone, formatAddress } from '@/lib/utils'
import { parseOrderRecipient } from '../recipient-helper'
import { detectOrderRoute } from '@/lib/route-detector'

interface ActiveDeliveryCardProps {
  order: any
  idx: number
  updatingId: string | null
  onMarkDelivered: (orderId: string) => void
  onOpenQr?: (order: any) => void
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
  onOpenQr,
}: ActiveDeliveryCardProps) {
  const [showAllItems, setShowAllItems] = useState(false)
  const isCod = order.paymentMethod === 'COD'
  const totalAmount = order.combinedTotal || ((order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0))
  const allItems = [...(order.items || []), ...(order.companionOrder?.items || [])]

  const recipient = parseOrderRecipient(order)
  const routeInfo = detectOrderRoute(order)
  const customerPhone = recipient.recipientPhone || order.address?.phone || order.user?.phone || order.shopPhone
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

        {/* Recipient Details Badge if ordered for someone else */}
        {recipient.isOrderForSomeone && (
          <div className="p-3 bg-gradient-to-r from-amber-500/15 via-orange-500/15 to-amber-500/15 border border-amber-500/30 rounded-2xl flex items-center justify-between gap-2 shadow-xs">
            <div className="flex items-center gap-2.5 min-w-0">
              <span className="text-xl shrink-0">🎁</span>
              <div className="min-w-0">
                <div className="text-[10px] font-black uppercase text-amber-700 dark:text-amber-400 tracking-wider flex items-center gap-1">
                  <span>ORDER FOR SOMEONE ELSE</span>
                </div>
                <div className="text-xs font-black text-text-primary truncate">
                  Deliver to: {recipient.recipientName}
                </div>
                {recipient.buyerName && (
                  <div className="text-[10px] font-bold text-text-secondary truncate">
                    Ordered by: {recipient.buyerName}
                  </div>
                )}
              </div>
            </div>
            <span className="text-[10px] font-black bg-amber-500/20 text-amber-700 dark:text-amber-400 px-2.5 py-0.5 rounded-full border border-amber-500/30 shrink-0">
              Gift Order
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
              <span className={`text-[9px] font-black px-1.5 py-0.5 rounded border ${routeInfo.colorBadgeClass}`}>
                {routeInfo.emoji} {routeInfo.shortLabel}
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
                <div className="flex items-center gap-1.5 min-w-0">
                  <div className="text-xs font-black text-text-primary truncate">
                    {recipient.recipientName}
                  </div>
                  {recipient.isOrderForSomeone && (
                    <span className="text-[9px] font-black uppercase px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-700 dark:text-amber-400 border border-amber-500/30 shrink-0">
                      Recipient
                    </span>
                  )}
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
                <span>Call {recipient.isOrderForSomeone ? 'Recipient' : 'Customer'} 📞</span>
              </a>
            ) : (
              <span className="flex items-center justify-center gap-1.5 py-2.5 px-3 min-h-[44px] rounded-xl bg-muted/40 text-text-muted text-xs font-bold opacity-60">
                <Phone className="h-3.5 w-3.5" />
                <span>No Phone</span>
              </span>
            )}
          </div>

          {/* Delivery Note if present */}
          {recipient.deliveryInstructions && (
            <div className="p-2.5 bg-amber-500/10 border border-amber-500/20 rounded-xl flex items-start gap-2 text-xs">
              <span className="shrink-0 text-amber-600 font-bold">📝 Note:</span>
              <span className="font-semibold text-text-primary leading-tight">{recipient.deliveryInstructions}</span>
            </div>
          )}
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
                {order.shopName || '🏪 FastMinute Darkstore Hub'}
              </span>
              {order.companionOrder && (
                <span className="text-[11px] font-semibold text-purple-600 dark:text-purple-400 block mt-1">
                  + {order.companionOrder.shopName || 'FastMinute Kitchen'}
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
              className="bg-secondary/20 rounded-2xl p-2.5 border border-border/40 space-y-2 max-h-56 overflow-y-auto"
            >
              {allItems.map((item: any, idx: number) => {
                const imgUrl = item.imageUrl || item.image || item.product?.imageUrl || item.product?.image
                const unit = item.unit || item.variantTitle || item.variant?.name
                return (
                  <div
                    key={item.id || idx}
                    className={`flex items-center justify-between p-2 rounded-xl border gap-2.5 ${
                      item.isCompanion
                        ? 'bg-purple-500/5 border-purple-500/20'
                        : 'bg-background/80 border-border/30'
                    }`}
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <div className="relative h-9 w-9 rounded-lg overflow-hidden bg-muted/60 border border-border/50 shrink-0 flex items-center justify-center">
                        {imgUrl ? (
                          <img src={imgUrl} alt={item.name} className="h-full w-full object-cover" />
                        ) : (
                          <span className="text-sm">{item.isCompanion ? '🍽️' : '📦'}</span>
                        )}
                        <span className="absolute bottom-0 right-0 bg-black/80 text-white font-mono text-[8px] font-black px-1 rounded-tl">
                          {item.quantity}x
                        </span>
                      </div>
                      <div className="min-w-0">
                        <div className="text-xs font-bold text-text-primary truncate">
                          {item.isCompanion && <span className="text-purple-600 dark:text-purple-400 mr-1">🍽️</span>}
                          {item.name}
                        </div>
                        {unit && (
                          <div className="text-[10px] text-text-muted font-medium truncate">
                            {unit}
                          </div>
                        )}
                      </div>
                    </div>
                    <div className="text-xs font-black text-text-primary shrink-0">
                      {formatPrice((item.price || 0) * (item.quantity || 1))}
                    </div>
                  </div>
                )
              })}
            </motion.div>
          ) : (
            /* Compact preview with images */
            <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
              {allItems.slice(0, 3).map((item: any, i: number) => {
                const imgUrl = item.imageUrl || item.image || item.product?.imageUrl || item.product?.image
                return (
                  <div
                    key={item.id || i}
                    className="flex items-center gap-1.5 p-1.5 pr-2.5 rounded-xl bg-secondary/50 border border-border/40 shrink-0 max-w-[170px]"
                  >
                    <div className="relative h-7 w-7 rounded-md overflow-hidden bg-muted shrink-0 flex items-center justify-center">
                      {imgUrl ? (
                        <img src={imgUrl} alt={item.name} className="h-full w-full object-cover" />
                      ) : (
                        <span className="text-xs">{item.isCompanion ? '🍲' : '📦'}</span>
                      )}
                      <span className="absolute bottom-0 right-0 bg-black/80 text-white font-mono text-[7px] font-black px-0.5 rounded-tl">
                        {item.quantity}x
                      </span>
                    </div>
                    <span className="text-[10px] font-bold text-text-primary truncate">
                      {item.name}
                    </span>
                  </div>
                )
              })}
              {allItems.length > 3 && (
                <button
                  type="button"
                  onClick={() => setShowAllItems(true)}
                  className="text-[10px] font-bold text-primary bg-primary/10 hover:bg-primary/20 px-2.5 py-1.5 rounded-xl shrink-0 border border-primary/20 cursor-pointer"
                >
                  +{allItems.length - 3} more
                </button>
              )}
            </div>
          )}
        </div>

        {/* Footer: Total to Collect & Primary Action Button */}
        <div className="flex items-center justify-between gap-2.5 pt-3 border-t border-border/40">
          <div className="min-w-0">
            <span className="text-[9px] font-black uppercase tracking-wider text-text-muted block truncate">
              {isCod ? '💵 Collect (COD)' : '✅ Order Value (Paid)'}
            </span>
            <span className="text-lg sm:text-xl font-black text-text-primary tracking-tight">
              {formatPrice(totalAmount)}
            </span>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            {isCod && onOpenQr && (
              <button
                type="button"
                onClick={() => onOpenQr(order)}
                className="flex items-center justify-center gap-1.5 py-3 px-3 min-h-[44px] bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 text-xs font-black rounded-2xl transition-all shadow-xs active:scale-95 cursor-pointer"
                title="Doorstep Cashfree QR"
              >
                <QrCode className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                <span>Doorstep QR</span>
              </button>
            )}

            <button
              onClick={() => onMarkDelivered(order.id)}
              disabled={updatingId === order.id}
              className="flex items-center justify-center gap-2 py-3 px-3.5 min-h-[44px] bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 hover:from-emerald-600 hover:to-teal-700 text-white text-xs font-black rounded-2xl transition-all shadow-lg shadow-emerald-500/25 active:scale-95 disabled:opacity-60 cursor-pointer"
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
      </div>
    </motion.div>
  )
}
