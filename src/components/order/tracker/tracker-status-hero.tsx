'use client'

import { Clock, X, CheckCircle2, Store, Truck, ShoppingBag, Package } from 'lucide-react'
import { cn } from '@/lib/utils'
import { formatOrderTime, formatDate } from '@/lib/date-helpers'

interface TrackerStatusHeroProps {
  order: any
  combinedStatus: string
  activeStep: number
  compOrder?: any | null
  isScheduled?: boolean | null
  onOpenCancelModal: () => void
}

export function TrackerStatusHero({
  order,
  combinedStatus,
  activeStep,
  compOrder,
  isScheduled,
  onOpenCancelModal,
}: TrackerStatusHeroProps) {
  const steps = [
    {
      label: 'Placed',
      icon: ShoppingBag,
      stepIdx: 0,
      activeWhen: ['PENDING', 'ADMIN_PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'],
      isCurrent: order.status === 'PENDING' || order.status === 'ADMIN_PENDING'
    },
    {
      label: 'Confirmed',
      icon: CheckCircle2,
      stepIdx: 1,
      activeWhen: ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'],
      isCurrent: order.status === 'CONFIRMED'
    },
    {
      label: order.deliveryMethod === 'PICKUP' ? 'Ready' : 'Out for Delivery',
      icon: order.deliveryMethod === 'PICKUP' ? Store : Truck,
      stepIdx: 2,
      activeWhen: ['PACKED', 'SHIPPED', 'DELIVERED'],
      isCurrent: order.deliveryMethod === 'PICKUP'
        ? (order.status === 'PACKED' || order.status === 'SHIPPED')
        : order.status === 'SHIPPED'
    },
    {
      label: order.deliveryMethod === 'PICKUP' ? 'Picked Up' : 'Delivered',
      icon: CheckCircle2,
      stepIdx: 3,
      activeWhen: ['DELIVERED'],
      isCurrent: order.status === 'DELIVERED'
    },
  ]

  return (
    <div className="bg-card border border-border/80 p-5 sm:p-7 rounded-3xl shadow-xl space-y-6 overflow-hidden relative">
      {/* Background Decorative Gradient Glow */}
      <div className="absolute -top-20 -right-20 w-64 h-64 bg-gradient-to-br from-primary/15 via-emerald-500/10 to-transparent rounded-full blur-3xl pointer-events-none" />

      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-border/50 pb-5 relative z-10">
        <div>
          <div className="flex flex-wrap items-center gap-2 mb-2">
            <span className="font-mono font-black text-xs px-2.5 py-1 rounded-lg bg-muted border border-border/60 text-text-primary tracking-tight">
              #{String(order.baseReadableId || order.readableId || '').replace(/-[GR\d]+$/i, '') || order.id?.slice(0, 8)}
            </span>
            <span className={cn(
              "text-[10px] uppercase font-black px-2.5 py-1 rounded-full tracking-wider shadow-2xs flex items-center gap-1.5",
              combinedStatus === 'CANCELLED'
                ? "text-red-600 bg-red-100 dark:text-red-400 dark:bg-red-950/40 border border-red-500/20"
                : combinedStatus === 'DELIVERED'
                ? "text-emerald-700 bg-emerald-100 dark:text-emerald-400 dark:bg-emerald-950/40 border border-emerald-500/20"
                : order.status === 'SHIPPED'
                ? "text-blue-700 bg-blue-100 dark:text-blue-400 dark:bg-blue-950/40 border border-blue-500/20"
                : "text-amber-700 bg-amber-100 dark:text-amber-400 dark:bg-amber-950/40 border border-amber-500/20"
            )}>
              <span className={cn(
                "h-1.5 w-1.5 rounded-full",
                combinedStatus === 'CANCELLED' ? "bg-red-500" :
                combinedStatus === 'DELIVERED' ? "bg-emerald-500" :
                order.status === 'SHIPPED' ? "bg-blue-500 animate-ping" :
                "bg-amber-500 animate-pulse"
              )} />
              {combinedStatus === 'CANCELLED' ? 'Cancelled' : 
               combinedStatus === 'DELIVERED' ? 'Delivered' : 
               order.status === 'SHIPPED' ? 'Out for Delivery' : 
               order.status === 'PACKED' ? 'Packed & Ready' : 
               order.status === 'CONFIRMED' ? 'Confirmed & Preparing' : 
               (order.status === 'ADMIN_PENDING' || combinedStatus === 'ADMIN_PENDING') ? 'Verifying Order' : 'Order Placed'}
            </span>

            {/* Live Payment Status Pill in Header */}
            {order.paymentStatus === 'PAID' ? (
              <span className="text-[10px] font-black px-2.5 py-1 rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 flex items-center gap-1">
                💳 Paid Online ✅
              </span>
            ) : combinedStatus !== 'CANCELLED' ? (
              <span className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/30 flex items-center gap-1">
                💵 Cash on Delivery
              </span>
            ) : null}

            {order.isCombined ? (
              <span className="text-[10px] font-black px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
                🛍️ Grocery + 🍽️ Restaurant Combined
              </span>
            ) : ((order as any).restaurantName || order.shopName) ? (
              <span className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20 flex items-center gap-1">
                🏪 {(order as any).restaurantName || order.shopName}
              </span>
            ) : (
              <span className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
                🛒 FastKirana DarkStore
              </span>
            )}
          </div>

          <h1 className="text-2xl sm:text-3xl font-black text-text-primary tracking-tight">
            {combinedStatus === 'CANCELLED'
              ? 'Order Cancelled'
              : combinedStatus === 'DELIVERED' 
              ? (order.deliveryMethod === 'PICKUP' ? 'Order Picked Up! 🎉' : 'Order Delivered! 🎉') 
              : order.deliveryMethod === 'PICKUP' 
              ? (
                  (order.status === 'PACKED' || order.status === 'SHIPPED' || ['READY_FOR_PICKUP', 'READY', 'PREPARED'].includes(order.status))
                    ? 'Ready for Counter Pickup!'
                    : 'Preparing for Pickup'
                )
              : order.status === 'SHIPPED'
              ? 'Rider On The Way 🛵'
              : order.status === 'PACKED'
              ? 'Order Packed & Ready'
              : order.status === 'CONFIRMED'
              ? 'Order Confirmed & Preparing'
              : (order.status === 'ADMIN_PENDING' || combinedStatus === 'ADMIN_PENDING')
              ? 'Verifying Order Details 🛡️'
              : 'Order Placed'}
          </h1>

          <p className="text-xs font-semibold text-text-secondary mt-1">
            {combinedStatus === 'CANCELLED'
              ? 'This order has been cancelled.'
              : combinedStatus === 'DELIVERED'
              ? 'Thank you for ordering with FastKirana!'
              : order.deliveryMethod === 'PICKUP'
              ? (
                  (order.status === 'PACKED' || order.status === 'SHIPPED' || ['READY_FOR_PICKUP', 'READY', 'PREPARED'].includes(order.status))
                    ? 'Your order is ready at the store counter. Please collect it at your convenience.'
                    : 'Your order is being freshly prepared by the store.'
                )
              : order.status === 'SHIPPED'
              ? 'Your delivery partner has picked up the order and is on the way.'
              : order.status === 'PACKED'
              ? 'Items packed safely. Waiting for rider pickup.'
              : (order.status === 'ADMIN_PENDING' || combinedStatus === 'ADMIN_PENDING')
              ? 'Our team is reviewing your order details. Verification takes less than 2 minutes.'
              : 'Your order is being freshly prepared with hygiene checks.'}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2 shrink-0">
          <div className="flex items-center gap-1.5 text-xs font-semibold text-text-secondary bg-muted/50 px-3 py-1.5 rounded-xl border border-border/50">
            <Clock className="h-3.5 w-3.5 text-primary" />
            <span>Placed at: {formatOrderTime(order.createdAt)}</span>
          </div>

          {/* Cancel Order Button: Only accessible before confirmation */}
          {(order.status === 'PENDING' || order.status === 'ADMIN_PENDING') && (combinedStatus === 'PENDING' || combinedStatus === 'ADMIN_PENDING') && (
            <button
              onClick={onOpenCancelModal}
              className="flex items-center gap-1.5 text-xs font-bold text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-950/30 hover:bg-red-100 dark:hover:bg-red-900/40 px-3 py-1.5 rounded-xl border border-red-200 dark:border-red-900/50 transition-colors shadow-2xs cursor-pointer"
              title="Cancel order before store confirmation"
            >
              <X className="h-3.5 w-3.5" />
              <span>Cancel Order</span>
            </button>
          )}
        </div>
      </div>

      {/* Visual Stepper Bar */}
      <div className="pt-2">
        <div className="grid grid-cols-4 gap-2">
          {steps.map((step, idx) => {
            const isReached = step.activeWhen.includes(order.status)
            const isCurrent = step.isCurrent
            const StepIcon = step.icon

            return (
              <div key={idx} className="flex flex-col items-center text-center group">
                <div className="w-full flex items-center mb-2">
                  <div className={cn(
                    "h-1 w-full rounded-full transition-colors",
                    idx === 0 ? "invisible" : isReached ? "bg-emerald-500" : "bg-muted"
                  )} />
                  <div className={cn(
                    "h-9 w-9 rounded-2xl flex items-center justify-center shrink-0 transition-all duration-300 shadow-sm",
                    isCurrent
                      ? "bg-primary text-white scale-110 shadow-md ring-4 ring-primary/20"
                      : isReached
                      ? "bg-emerald-500 text-white"
                      : "bg-muted/70 text-text-muted border border-border/60"
                  )}>
                    <StepIcon className="h-4 w-4" strokeWidth={2.2} />
                  </div>
                  <div className={cn(
                    "h-1 w-full rounded-full transition-colors",
                    idx === 3 ? "invisible" : isReached && idx < (activeStep || 1) ? "bg-emerald-500" : "bg-muted"
                  )} />
                </div>
                <span className={cn(
                  "text-[10px] sm:text-xs font-black leading-tight",
                  isCurrent ? "text-primary" : isReached ? "text-text-primary" : "text-text-muted"
                )}>
                  {step.label}
                </span>
              </div>
            )
          })}
        </div>
      </div>

      {/* Pre-Confirmation Cancel Option Banner */}
      {order.status === 'PENDING' && combinedStatus === 'PENDING' && (
        <div className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/25 flex flex-wrap items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-2 text-amber-800 dark:text-amber-300 font-medium">
            <span className="text-base">⏳</span>
            <span>Awaiting store confirmation. Need to change your mind? You can cancel right now.</span>
          </div>
          <button
            onClick={onOpenCancelModal}
            className="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white font-bold rounded-xl text-xs transition-colors shrink-0 shadow-xs cursor-pointer flex items-center gap-1"
          >
            <X className="h-3.5 w-3.5" />
            <span>Cancel Order</span>
          </button>
        </div>
      )}

      {/* Fulfillment Details Badge Row */}
      <div className="flex flex-wrap items-center gap-2 pt-1">
        {order.deliveryMethod === 'PICKUP' ? (
          <span className="text-[10px] font-black text-purple-800 bg-purple-100 dark:bg-purple-900/30 dark:text-purple-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
            <Store className="h-3.5 w-3.5 shrink-0" /> Self-Pickup (Take Away)
          </span>
        ) : (
          <span className="text-[10px] font-black text-sky-800 bg-sky-100 dark:bg-sky-900/30 dark:text-sky-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
            <Truck className="h-3.5 w-3.5 shrink-0" /> Doorstep Fast Delivery
          </span>
        )}
        {isScheduled && order.estimatedDelivery && (
          <span className="text-[10px] font-black text-amber-800 bg-amber-100 dark:bg-amber-900/30 dark:text-amber-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
            <Clock className="h-3.5 w-3.5 shrink-0" /> Scheduled: {formatDate(order.estimatedDelivery, 'yyyy-MM-dd')} {formatOrderTime(order.estimatedDelivery)}
          </span>
        )}
      </div>

      {/* Dual-Store Combined Order Fulfillment Status */}
      {order.isCombined && order.subOrders && order.subOrders.length > 0 ? (
        <div className="rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/5 via-accent/5 to-card p-4 space-y-3 shadow-xs">
          <div className="flex items-center justify-between">
            <h3 className="text-text-primary font-black text-xs uppercase tracking-wider flex items-center gap-1.5">
              <Store className="h-4 w-4 text-primary shrink-0" />
              <span>Multi-Store Preparation Progress</span>
            </h3>
            <span className="text-[9.5px] font-black uppercase px-2 py-0.5 rounded-md bg-purple-500/15 text-purple-700 dark:text-purple-400 border border-purple-500/30">
              🔗 1 Delivery · 2 Stops
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {order.subOrders.map((sub: any, idx: number) => {
              const isRest = sub.type === 'RESTAURANT'
              return (
                <div key={sub.id || idx} className="bg-card p-3 rounded-xl border border-border/70 flex items-center justify-between shadow-2xs">
                  <div className="flex items-center gap-2.5 min-w-0">
                    <div className="h-9 w-9 rounded-xl flex items-center justify-center text-base shrink-0 bg-muted/60">
                      {isRest ? '🍳' : '🛒'}
                    </div>
                    <div className="min-w-0">
                      <div className="text-text-primary font-black text-xs truncate">
                        {isRest ? (sub.shopName || 'Restaurant') : 'FastKirana Darkstore'}
                      </div>
                      <div className="text-[10px] text-text-muted font-medium mt-0.5">
                        {sub.itemsCount || sub.items?.length || 0} {isRest ? 'Dishes' : 'Grocery items'}
                      </div>
                    </div>
                  </div>

                  <span className={cn(
                    "text-[9px] font-black px-2.5 py-1 rounded-full uppercase tracking-wider shrink-0",
                    sub.status === 'DELIVERED' ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30' :
                    sub.status === 'CANCELLED' ? 'bg-red-500/15 text-red-600 dark:text-red-400 border border-red-500/30' :
                    sub.status === 'SHIPPED' ? 'bg-blue-500/15 text-blue-600 dark:text-blue-400 border border-blue-500/30' :
                    sub.status === 'PACKED' ? 'bg-purple-500/15 text-purple-600 dark:text-purple-400 border border-purple-500/30' :
                    'bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/30'
                  )}>
                    {sub.status === 'PACKED' ? (isRest ? '🍳 Food Ready' : '📦 Packed') : sub.status}
                  </span>
                </div>
              )
            })}
          </div>
        </div>
      ) : null}
    </div>
  )
}
