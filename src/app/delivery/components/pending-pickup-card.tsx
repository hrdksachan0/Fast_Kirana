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
  hidden: { opacity: 0, y: 16, scale: 0.97 },
  show: { opacity: 1, y: 0, scale: 1, transition: { type: 'spring' as const, stiffness: 280, damping: 24 } },
  exit: { opacity: 0, y: -10, scale: 0.97, transition: { duration: 0.2 } },
} as const

export default function PendingPickupCard({
  order,
  updatingId,
  onUpdateStatus,
}: PendingPickupCardProps) {
  const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
  
  // Maps URL
  const mapUrl = (order.deliveryLat || order.address?.lat) && (order.deliveryLng || order.address?.lng)
    ? `https://www.google.com/maps/search/?api=1&query=${order.deliveryLat || order.address.lat},${order.deliveryLng || order.address.lng}`
    : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(formatAddress(order.address))}`
    
  // Phone
  const phoneRaw = order.address?.phone || order.user?.phone || order.shopPhone
  const phoneUrl = phoneRaw ? `tel:${formatPhone(phoneRaw).replace(/\s+/g, '')}` : null

  // Items
  const allItems = [
    ...(order.items || []).map((i: any) => ({ ...i, isCompanion: false })),
    ...(order.companionOrder?.items || []).map((i: any) => ({ ...i, isCompanion: true }))
  ]
  const previewItems = allItems.slice(0, 2)
  const remainingItemsCount = allItems.length - 2

  // Status colors
  const statusConfig = {
    PACKED: { strip: 'bg-gradient-to-r from-emerald-500 to-teal-500', pill: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30', label: 'PACKED • READY' },
    PREPARING: { strip: 'bg-gradient-to-r from-amber-400 to-orange-500 animate-pulse', pill: 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30', label: 'PREPARING' },
    CONFIRMED: { strip: 'bg-gradient-to-r from-blue-400 to-indigo-500', pill: 'bg-blue-500/15 text-blue-700 dark:text-blue-300 border-blue-500/30', label: 'CONFIRMED' }
  }
  const statusStyle = statusConfig[order.status as keyof typeof statusConfig] || statusConfig.CONFIRMED

  return (
    <motion.div
      key={order.id}
      variants={itemVariants}
      initial="hidden"
      animate="show"
      exit="exit"
      layout
      className={`relative bg-card border rounded-3xl shadow-md hover:shadow-lg overflow-hidden transition-all duration-200 ${
        isRestaurant
          ? 'border-rose-200/80 dark:border-rose-500/20'
          : 'border-blue-200/80 dark:border-blue-500/20'
      }`}
    >
      {/* 1. Status strip at top */}
      <div className={`h-1.5 w-full ${statusStyle.strip}`} />

      <div className="p-4 sm:p-5 space-y-4">
        {/* Combined Multi-Pickup Banner */}
        {order.companionOrder && (
          <div className="bg-purple-500/10 border border-purple-500/25 p-2.5 rounded-2xl flex items-center justify-between shadow-2xs">
            <div className="flex items-center gap-2 text-xs font-black text-purple-700 dark:text-purple-300">
              <span className="p-1 rounded-lg bg-purple-500 text-white text-[10px]">🛍️</span>
              <span>MULTI-PICKUP ORDER</span>
            </div>
            <span className="text-[10px] font-black bg-purple-500/20 text-purple-700 dark:text-purple-300 px-2.5 py-0.5 rounded-full border border-purple-500/30">
              2 Pickups
            </span>
          </div>
        )}

        {/* 2. Compact header */}
        <div className="flex justify-between items-start border-b border-border/40 pb-3">
          <div className="space-y-0.5">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-xs font-mono font-black text-text-primary">
                #{order.readableId || order.id.slice(0, 8)}
              </span>
              {isRestaurant && (
                <span className="bg-rose-100 dark:bg-rose-500/15 text-rose-700 dark:text-rose-300 text-[9px] px-2 py-0.5 rounded-md font-black uppercase tracking-wider border border-rose-200 dark:border-rose-500/20">
                  🍽️ Food
                </span>
              )}
            </div>
            <span className="text-[10px] text-text-muted font-bold block">
              {order.shopName || (isRestaurant ? 'Partner Kitchen' : 'FastKirana Central Darkstore')}
            </span>
          </div>
          <span className={`px-2.5 py-1 rounded-xl text-[10px] font-black tracking-wider shrink-0 border shadow-2xs ${statusStyle.pill}`}>
            {statusStyle.label}
          </span>
        </div>

        {/* 4. Customer + actions row */}
        <div className="flex justify-between items-center bg-secondary/30 border border-border/50 p-3 rounded-2xl gap-2">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="h-9 w-9 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-xs font-black text-white shadow-sm shrink-0">
              {(order.user?.name || order.userName || 'C').charAt(0).toUpperCase()}
            </div>
            <div className="min-w-0">
              <span className="text-xs font-black text-text-primary truncate block">
                {order.user?.name || order.userName || 'Customer'}
              </span>
              {(order.address?.phone || order.user?.phone) && (
                <span className="text-[11px] font-mono text-text-secondary mt-0.5 block">
                  {formatPhone(order.address?.phone || order.user?.phone)}
                </span>
              )}
            </div>
          </div>
          
          <div className="flex items-center gap-1.5 shrink-0">
            <a
              href={mapUrl}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Map"
              className="h-10 w-10 rounded-xl bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/30 flex items-center justify-center transition-all active:scale-95 text-emerald-700 dark:text-emerald-300 cursor-pointer shadow-2xs"
            >
              <MapPin className="h-4 w-4" />
            </a>
            {phoneUrl ? (
              <a
                href={phoneUrl}
                aria-label="Call"
                className="h-10 w-10 rounded-xl bg-blue-500/15 hover:bg-blue-500/25 border border-blue-500/30 flex items-center justify-center transition-all active:scale-95 text-blue-700 dark:text-blue-300 cursor-pointer shadow-2xs"
              >
                <Phone className="h-4 w-4" />
              </a>
            ) : (
              <div className="h-10 w-10 rounded-xl bg-muted/40 border border-border flex items-center justify-center opacity-40">
                <Phone className="h-4 w-4 text-text-muted" />
              </div>
            )}
          </div>
        </div>

        {/* 5. Route info */}
        <div className="p-3 rounded-2xl bg-muted/20 border border-border/40 space-y-2 text-xs font-bold">
          <div className="flex items-center gap-2.5">
            <div className="h-2 w-2 rounded-full bg-emerald-500 shrink-0" />
            <div className="truncate">
              <span className="text-[9px] font-black text-text-muted uppercase tracking-wider mr-1.5">Pickup:</span>
              <span className="text-text-primary">
                {order.shopName || (isRestaurant ? 'Restaurant Kitchen' : 'FastKirana Hub')}
                {order.companionOrder && <span className="text-purple-600 dark:text-purple-400 ml-1">+ {order.companionOrder.shopName || 'Store'}</span>}
              </span>
            </div>
          </div>
          <div className="flex items-center gap-2.5">
            <div className="h-2 w-2 rounded-full bg-blue-500 shrink-0" />
            <div className="truncate">
              <span className="text-[9px] font-black text-text-muted uppercase tracking-wider mr-1.5">Deliver:</span>
              <span className="text-text-secondary font-medium truncate">
                {formatAddress(order.address, false)}
              </span>
            </div>
          </div>
        </div>

        {/* 6. Items preview */}
        {allItems.length > 0 && (
          <div className="flex items-center gap-1.5 flex-wrap pt-0.5">
            <ShoppingBag className="h-3.5 w-3.5 text-text-muted mr-0.5" />
            {previewItems.map((item: any, idx: number) => (
              <span 
                key={item.id || idx} 
                className={`px-2 py-0.5 rounded-lg text-[10px] font-bold border ${
                  item.isCompanion 
                    ? 'bg-purple-500/10 text-purple-700 dark:text-purple-300 border-purple-500/20' 
                    : 'bg-secondary/60 text-text-secondary border-border/40'
                }`}
              >
                {item.quantity}× {item.name}
              </span>
            ))}
            {remainingItemsCount > 0 && (
              <span className="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-secondary text-text-muted border border-border/30">
                +{remainingItemsCount} more
              </span>
            )}
          </div>
        )}

        {/* 7. Footer */}
        <div className="pt-3 border-t border-border/40 flex items-center justify-between gap-3">
          <div>
            <span className="text-[9px] font-black uppercase tracking-wider text-text-muted block">
              Total Order Value
            </span>
            <span className="text-lg font-black text-text-primary">
              {formatPrice((order.total || 0) + (order.companionOrder?.total || 0))}
            </span>
            <span className="text-[9px] font-extrabold text-emerald-600 dark:text-emerald-400 block mt-0.5">
              {order.paymentMethod === 'COD' ? '💰 Collect Cash' : '✅ Paid Online'}
            </span>
          </div>

          <div className="flex-1 max-w-[200px]">
            {order.status === 'PACKED' ? (
              <button
                onClick={() => onUpdateStatus(order.id, 'SHIPPED')}
                disabled={updatingId === order.id}
                className={`w-full flex items-center justify-center gap-2 h-11 text-white text-xs font-black rounded-2xl transition-all shadow-md active:scale-95 disabled:opacity-60 cursor-pointer ${
                  isRestaurant
                    ? 'bg-gradient-to-r from-rose-500 to-pink-600 hover:from-rose-600 hover:to-pink-700 shadow-rose-500/20'
                    : 'bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 shadow-blue-500/20'
                }`}
              >
                {updatingId === order.id ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <>
                    <Navigation className="h-4 w-4" />
                    <span>Pick Up Order ➔</span>
                  </>
                )}
              </button>
            ) : (
              <div className="flex flex-col items-end gap-1 w-full">
                <button
                  disabled
                  className="w-full flex items-center justify-center gap-1.5 h-10 bg-amber-500/15 border border-amber-500/30 text-amber-700 dark:text-amber-300 text-xs font-bold rounded-xl cursor-not-allowed"
                >
                  <Clock className="h-3.5 w-3.5 animate-spin" />
                  <span>Preparing in Kitchen...</span>
                </button>
                <button
                  onClick={() => onUpdateStatus(order.id, 'SHIPPED')}
                  disabled={updatingId === order.id}
                  className="text-[9px] font-black text-emerald-600 dark:text-emerald-400 hover:underline cursor-pointer active:scale-95 text-right pt-0.5"
                >
                  Food Ready? Pick Up Anyway
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </motion.div>
  )
}
