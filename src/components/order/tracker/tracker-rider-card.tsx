'use client'

import { Phone, Navigation, Store, CheckCircle2, Clock } from 'lucide-react'
import { cn, formatPhone, formatAddress } from '@/lib/utils'

interface TrackerRiderCardProps {
  order: any
  supportPhone: string
  storeLat: number
  storeLng: number
  trackingMetrics?: {
    distance: string
    eta: number
    isArrived: boolean
  } | null
}

export function TrackerRiderCard({
  order,
  supportPhone,
  storeLat,
  storeLng,
  trackingMetrics,
}: TrackerRiderCardProps) {
  return (
    <div className="space-y-4">
      {/* Out For Delivery Dedicated Contact Card */}
      {order.status === 'SHIPPED' && order.deliveryMethod !== 'PICKUP' && (
        <div className="bg-gradient-to-br from-emerald-500/10 via-teal-500/5 to-card border border-emerald-500/30 p-4 sm:p-5 rounded-2xl shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-3.5 w-full sm:w-auto">
            <div className="h-12 w-12 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-2xl shrink-0 shadow-2xs">
              🛵
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-black text-emerald-700 dark:text-emerald-400 uppercase tracking-wide">
                  Delivery Partner Assigned
                </span>
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
              </div>
              <div className="text-sm font-black text-text-primary mt-0.5 truncate">
                {order.deliveryUser?.name && order.deliveryUser.name !== 'Admin'
                  ? order.deliveryUser.name
                  : 'FastKirana Delivery Executive'}
              </div>
              <div className="text-[10px] text-text-muted font-medium flex items-center gap-2 mt-0.5">
                <span>Verified Delivery Partner</span>
                {trackingMetrics && (
                  <>
                    <span>•</span>
                    <span className="font-bold text-emerald-600 dark:text-emerald-400">
                      {trackingMetrics.isArrived ? 'Arriving now' : `${trackingMetrics.distance} km (${trackingMetrics.eta} mins away)`}
                    </span>
                  </>
                )}
              </div>
            </div>
          </div>

          <a
            href={`tel:${formatPhone(order.deliveryUser?.phone || '+919696503759').replace(/\s+/g, '')}`}
            className="flex items-center justify-center gap-2 w-full sm:w-auto px-5 py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-95 text-center shrink-0 cursor-pointer"
          >
            <Phone className="h-4 w-4" />
            <span>Call Rider</span>
          </a>
        </div>
      )}

      {/* Self-Pickup Counter Details Card */}
      {order.deliveryMethod === 'PICKUP' && order.status !== 'DELIVERED' && (
        <div className="bg-gradient-to-br from-amber-500/10 via-orange-500/5 to-card border border-amber-500/25 p-4 sm:p-5 rounded-2xl shadow-xs flex flex-col gap-4">
          <div className="flex items-start gap-3.5">
            <div className="h-11 w-11 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-xl shrink-0">
              🏪
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-black text-amber-700 dark:text-amber-400 uppercase tracking-widest">
                  Self-Pickup Order
                </span>
                <span className="h-1.5 w-1.5 rounded-full bg-amber-500 animate-pulse" />
              </div>
              <div className="text-sm font-black text-text-primary mt-0.5">
                {order.shopName || 'FastKirana Outlet'}
              </div>
              <div className="text-xs text-text-secondary mt-1 font-semibold">
                Pickup Address: <span className="text-text-primary font-bold">{order.address?.street || 'FastKirana Store counter'}</span>
              </div>
              <p className="text-[10.5px] text-text-muted mt-1.5">
                Please show your Order ID <span className="font-extrabold text-primary">#{order.baseReadableId || order.readableId || order.id?.slice(-6).toUpperCase()}</span> at the counter to collect your items.
              </p>
            </div>
          </div>

          <div className="flex gap-2.5 w-full border-t border-border/40 pt-3 mt-1">
            <a
              href={`tel:${supportPhone}`}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-muted/60 hover:bg-muted text-text-primary font-bold text-xs rounded-xl transition-all cursor-pointer"
            >
              <Phone className="h-3.5 w-3.5" />
              <span>Call Store</span>
            </a>
            <a
              href={`https://www.google.com/maps/dir/?api=1&destination=${order.address?.lat || storeLat},${order.address?.lng || storeLng}`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-primary text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-95 cursor-pointer"
            >
              <Navigation className="h-3.5 w-3.5" />
              <span>Get Directions</span>
            </a>
          </div>
        </div>
      )}

      {/* Support Call Buttons for non-shipped delivery orders */}
      {order.status !== 'SHIPPED' && order.deliveryMethod !== 'PICKUP' && (
        <div className="flex flex-col sm:flex-row gap-3 pt-1">
          <a
            href={`tel:${supportPhone.replace(/\D/g, '') || '8112849854'}`}
            className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 border-2 border-primary/20 bg-primary/5 hover:bg-primary/10 text-primary font-black text-xs rounded-xl transition-all"
          >
            <Phone className="h-4 w-4" />
            FastKirana Support ({supportPhone})
          </a>
        </div>
      )}
    </div>
  )
}
