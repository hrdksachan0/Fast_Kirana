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
  hidden: { opacity: 0, y: 20, scale: 0.95 },
  show: { opacity: 1, y: 0, scale: 1, transition: { type: 'spring' as const, stiffness: 300, damping: 24, mass: 0.8 } },
  exit: { opacity: 0, y: -10, scale: 0.95, transition: { duration: 0.2 } },
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
    PACKED: { strip: 'bg-gradient-to-r from-emerald-400 to-teal-500', pill: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20', label: 'PACKED' },
    PREPARING: { strip: 'bg-gradient-to-r from-amber-400 to-orange-500 animate-pulse', pill: 'bg-amber-500/10 text-amber-500 border-amber-500/20', label: 'PREPARING' },
    CONFIRMED: { strip: 'bg-gradient-to-r from-blue-400 to-indigo-500', pill: 'bg-blue-500/10 text-blue-500 border-blue-500/20', label: 'CONFIRMED' }
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
      className={`relative bg-slate-950 dark:bg-slate-900 border rounded-3xl shadow-lg overflow-hidden transition-all ${
        isRestaurant
          ? 'border-rose-500/10'
          : 'border-blue-500/10'
      }`}
    >
      {/* 1. Status strip at top */}
      <div className={`absolute top-0 left-0 right-0 h-[3px] ${statusStyle.strip}`} />
      
      {/* 3. Color-coded left accent */}
      <div className={`absolute left-0 top-[3px] bottom-0 w-[2px] ${
        isRestaurant
          ? 'bg-gradient-to-b from-rose-500 to-pink-600'
          : 'bg-gradient-to-b from-blue-500 to-indigo-600'
      }`} />

      <div className="p-5 space-y-5">
        {/* Combined Multi-Pickup Banner */}
        {order.companionOrder && (
          <div className="bg-purple-500/10 border border-purple-500/20 p-3 rounded-2xl flex items-center justify-between">
            <div className="flex items-center gap-2 text-xs font-bold text-purple-400">
              <span className="p-1.5 rounded-lg bg-purple-500/20 text-purple-300 text-[10px]">🛍️</span>
              <span>MULTI-PICKUP ORDER</span>
            </div>
            <span className="text-[10px] font-bold bg-purple-500/20 text-purple-300 px-2.5 py-1 rounded-full border border-purple-500/30">
              2 Pickups
            </span>
          </div>
        )}

        {/* 2. Compact header */}
        <div className="flex justify-between items-center">
          <div className="flex flex-col">
            <div className="flex items-center gap-2">
              <span className="text-sm font-mono font-bold text-text-primary">
                #{order.readableId || order.id.slice(0, 8)}
              </span>
              {isRestaurant && (
                <span className="bg-rose-500/10 text-rose-400 text-[9px] px-1.5 py-0.5 rounded-md font-bold uppercase tracking-wider">
                  FOOD
                </span>
              )}
            </div>
          </div>
          <span className={`px-2.5 py-1 rounded-lg text-[10px] font-bold tracking-wider shrink-0 border ${statusStyle.pill}`}>
            {statusStyle.label}
          </span>
        </div>

        {/* 4. Customer + actions row */}
        <div className="flex justify-between items-center bg-white/[0.03] border border-white/[0.06] p-3 rounded-2xl">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-full bg-slate-800 flex items-center justify-center text-sm font-bold text-slate-300 border border-slate-700">
              {(order.user?.name || order.userName || 'C').charAt(0).toUpperCase()}
            </div>
            <div className="flex flex-col">
              <span className="text-sm font-bold text-text-primary">
                {order.user?.name || order.userName || 'Customer'}
              </span>
              {(order.address?.phone || order.user?.phone) && (
                <span className="text-xs font-medium text-text-muted">
                  {formatPhone(order.address?.phone || order.user?.phone)}
                </span>
              )}
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <a
              href={mapUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="h-11 w-11 rounded-xl bg-slate-800/80 hover:bg-slate-700 border border-slate-700 flex items-center justify-center transition-colors active:scale-95"
            >
              <MapPin className="h-5 w-5 text-emerald-400" />
            </a>
            {phoneUrl ? (
              <a
                href={phoneUrl}
                className="h-11 w-11 rounded-xl bg-slate-800/80 hover:bg-slate-700 border border-slate-700 flex items-center justify-center transition-colors active:scale-95"
              >
                <Phone className="h-5 w-5 text-blue-400" />
              </a>
            ) : (
              <div className="h-11 w-11 rounded-xl bg-slate-800/40 border border-slate-800 flex items-center justify-center opacity-50">
                <Phone className="h-5 w-5 text-slate-500" />
              </div>
            )}
          </div>
        </div>

        {/* 5. Route info */}
        <div className="space-y-3">
          <div className="flex items-center gap-3">
            <div className="h-2 w-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]" />
            <div className="flex flex-col">
              <span className="text-[10px] text-text-muted uppercase tracking-wider font-semibold">Pickup</span>
              <span className="text-sm font-bold text-text-primary">
                {order.shopName || (isRestaurant ? 'Restaurant' : 'FastKirana Hub')}
                {order.companionOrder && <span className="text-purple-400 ml-1">+ {order.companionOrder.shopName || 'Store'}</span>}
              </span>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="h-2 w-2 rounded-full bg-rose-500 shadow-[0_0_8px_rgba(244,63,94,0.5)]" />
            <div className="flex flex-col">
              <span className="text-[10px] text-text-muted uppercase tracking-wider font-semibold">Delivery</span>
              <span className="text-sm font-medium text-text-secondary truncate max-w-[240px]">
                {formatAddress(order.address, false)}
              </span>
            </div>
          </div>
        </div>

        {/* 6. Items preview */}
        {allItems.length > 0 && (
          <div className="flex items-center gap-2 flex-wrap">
            <ShoppingBag className="h-4 w-4 text-text-muted mr-1" />
            {previewItems.map((item: any, idx: number) => (
              <span 
                key={item.id || idx} 
                className={`px-2 py-1 rounded-lg text-xs font-medium border ${
                  item.isCompanion 
                    ? 'bg-purple-500/10 text-purple-300 border-purple-500/20' 
                    : 'bg-slate-800 text-slate-300 border-slate-700'
                }`}
              >
                {item.quantity}x {item.name}
              </span>
            ))}
            {remainingItemsCount > 0 && (
              <span className="px-2 py-1 rounded-lg text-xs font-medium bg-slate-800 text-slate-400 border border-slate-700">
                +{remainingItemsCount} more
              </span>
            )}
          </div>
        )}

        {/* 7. Footer */}
        <div className="pt-2 border-t border-white/[0.06] flex items-center justify-between">
          <div className="flex flex-col">
            <span className="text-[10px] font-semibold text-text-muted">Total Amount</span>
            <span className="text-xl font-bold text-text-primary">
              {formatPrice((order.total || 0) + (order.companionOrder?.total || 0))}
            </span>
            <span className="text-[10px] font-medium text-emerald-400">
              {order.paymentMethod === 'COD' ? 'Collect Cash' : 'Paid Online'}
            </span>
          </div>

          <div className="flex-1 ml-4">
            {order.status === 'PACKED' ? (
              <button
                onClick={() => onUpdateStatus(order.id, 'SHIPPED')}
                disabled={updatingId === order.id}
                className={`w-full flex items-center justify-center gap-2 h-12 text-white text-sm font-bold rounded-2xl transition-all shadow-lg active:scale-95 disabled:opacity-60 cursor-pointer ${
                  isRestaurant
                    ? 'bg-gradient-to-r from-rose-500 to-pink-600 shadow-rose-500/20'
                    : 'bg-gradient-to-r from-blue-500 to-indigo-600 shadow-blue-500/20'
                }`}
              >
                {updatingId === order.id ? (
                  <Loader2 className="h-5 w-5 animate-spin" />
                ) : (
                  <>
                    <Navigation className="h-5 w-5" />
                    Pick Up Order
                  </>
                )}
              </button>
            ) : (
              <div className="flex flex-col items-end gap-2 w-full">
                <button
                  disabled
                  className="w-full flex items-center justify-center gap-2 h-12 bg-amber-500/10 border border-amber-500/20 text-amber-500 text-sm font-bold rounded-2xl cursor-not-allowed"
                >
                  <Clock className="h-4 w-4 animate-spin" />
                  Preparing...
                </button>
                <button
                  onClick={() => onUpdateStatus(order.id, 'SHIPPED')}
                  disabled={updatingId === order.id}
                  className="text-[10px] font-bold text-emerald-500 hover:text-emerald-400 flex items-center gap-1 cursor-pointer active:scale-95 text-right"
                >
                  Handed Over? Pick Up Anyway
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </motion.div>
  )
}
