'use client'

import { useRouter } from 'next/navigation'
import { CheckCircle2, Camera, Navigation, MapPin } from 'lucide-react'
import { formatAddress, formatPrice } from '@/lib/utils'
import { PayOnlineButton } from '@/components/order/pay-online-button'
import { useOrderTracker, Order } from '@/hooks/order/use-order-tracker'
import { TrackerStatusHero } from '@/components/order/tracker/tracker-status-hero'
import { TrackerRiderCard } from '@/components/order/tracker/tracker-rider-card'
import { TrackerItemsSummary } from '@/components/order/tracker/tracker-items-summary'
import { TrackerCancelModal } from '@/components/order/tracker/tracker-cancel-modal'

interface OrderTrackerProps {
  initialOrder: Order
  companionOrder?: Order | null
  isCafeOpen?: boolean
}

export function OrderTracker({
  initialOrder,
  companionOrder,
  isCafeOpen: initialIsCafeOpen = true,
}: OrderTrackerProps) {
  const router = useRouter()
  const {
    order,
    setOrder,
    compOrder,
    activeStep,
    storeLat,
    storeLng,
    supportPhone,
    isCafeOpen,
    combinedStatus,
    mergedItems,
    combinedSubtotal,
    combinedDiscount,
    combinedDeliveryFee,
    combinedTaxes,
    combinedMiscFee,
    combinedTotal,
    combinedRefundAmount,
    trackingMetrics,
    isCafeOrder,
    isScheduled,
    isCancelModalOpen,
    setIsCancelModalOpen,
    isCancelling,
    handleCancelOrder,
  } = useOrderTracker({
    initialOrder,
    companionOrder,
    isCafeOpen: initialIsCafeOpen,
  })

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Kitchen Closed Banner */}
      {isCafeOrder && !isCafeOpen && (order.status === 'PENDING' || order.status === 'CONFIRMED') && (
        <div className="bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/50 p-4 rounded-2xl flex items-start gap-3">
          <div className="h-10 w-10 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-400 flex items-center justify-center shrink-0 font-bold">
            ⚠️
          </div>
          <div>
            <h2 className="text-sm font-bold text-amber-800 dark:text-amber-400">Kitchen is currently Closed</h2>
            <p className="text-xs text-amber-700 dark:text-amber-500 mt-0.5 leading-relaxed">
              Kitchen is closed. Active orders placed before closing are still processed and delivered. If you have any concerns or want to cancel/refund, please call support.
            </p>
          </div>
        </div>
      )}

      {/* Cancelled Banner */}
      {order.status === 'CANCELLED' && (
        <div className="bg-red-50 dark:bg-red-950/20 border border-red-200 dark:border-red-900/50 p-4 rounded-2xl flex items-start gap-3">
          <div className="h-10 w-10 rounded-full bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-400 flex items-center justify-center shrink-0 font-bold">
            ❌
          </div>
          <div>
            <h2 className="text-sm font-bold text-red-800 dark:text-red-400">Order Cancelled</h2>
            <p className="text-xs text-red-700 dark:text-red-500 mt-0.5">
              This order has been cancelled and will not be processed further. If payment was made, it will be refunded shortly.
            </p>
          </div>
        </div>
      )}

      {/* Refund Notice Banner */}
      {combinedRefundAmount > 0 && (
        <div className="bg-gradient-to-r from-rose-500/10 via-amber-500/10 to-rose-500/5 border-2 border-rose-500/30 p-4 rounded-2xl flex items-start gap-3.5 shadow-xs animate-fade-in">
          <div className="h-10 w-10 rounded-xl bg-rose-500/15 text-rose-600 dark:text-rose-400 flex items-center justify-center shrink-0 text-xl font-bold">
            ↩️
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <h2 className="text-sm font-black text-rose-800 dark:text-rose-400">
                ₹{combinedRefundAmount} Refund Initiated / Credited
              </h2>
              <span className="text-[10px] font-extrabold uppercase px-2 py-0.5 rounded-full bg-rose-500/20 text-rose-700 dark:text-rose-300">
                Refunded
              </span>
            </div>
            <p className="text-xs text-rose-700 dark:text-rose-300/90 mt-1 leading-relaxed font-medium">
              {order.notes?.includes('Refund') ? order.notes : `A refund of ₹${combinedRefundAmount} has been credited to your original payment method.`}
            </p>
          </div>
        </div>
      )}

      {/* Payment Status Reassurance or Pay Online Option */}
      {order.paymentStatus === 'PAID' ? (
        <div className="p-4 sm:p-5 bg-emerald-50/90 dark:bg-emerald-950/30 border border-emerald-500/30 rounded-3xl shadow-sm flex items-center gap-3.5">
          <div className="h-10 w-10 rounded-2xl bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 flex items-center justify-center text-lg shrink-0 border border-emerald-500/20">
            💳
          </div>
          <div className="flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h4 className="text-xs sm:text-sm font-bold text-emerald-900 dark:text-emerald-200">
                Payment Confirmed • {formatPrice(combinedTotal || order.total)} Paid Online
              </h4>
              <span className="text-[9px] font-black uppercase bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 px-2 py-0.5 rounded-full border border-emerald-500/30">
                {order.paymentMethod === 'UPI' ? 'UPI / Cashfree Online' : order.paymentMethod}
              </span>
            </div>
            <p className="text-[11px] sm:text-xs text-emerald-700 dark:text-emerald-400 mt-0.5 font-medium">
              Payment received successfully. No cash payment needed upon delivery! 🎉
            </p>
          </div>
        </div>
      ) : order.status !== 'CANCELLED' ? (
        <PayOnlineButton
          orderId={order.id}
          amount={combinedTotal || order.total}
          readableId={String(order.baseReadableId || order.readableId || '').replace(/-[GR\d]+$/i, '') || order.id?.slice(0, 8)}
          customerPhone={(order as any).customerPhone || (order as any).address?.phone || ''}
          customerName={(order as any).customerName || (order as any).userName || 'FastKirana Customer'}
          onPaymentSuccess={async () => {
            try {
              const refetchRes = await fetch(`/api/orders/${order.id}`)
              if (refetchRes.ok) {
                const freshData = await refetchRes.json()
                setOrder((prev: any) => ({
                  ...prev,
                  ...freshData,
                  paymentStatus: 'PAID',
                  paymentMethod: 'UPI',
                  status: freshData.status || (prev.status === 'PENDING' ? 'CONFIRMED' : prev.status),
                }))
              } else {
                setOrder((prev: any) => ({ ...prev, paymentStatus: 'PAID', paymentMethod: 'UPI', status: prev.status === 'PENDING' ? 'CONFIRMED' : prev.status }))
              }
            } catch (e) {
              setOrder((prev: any) => ({ ...prev, paymentStatus: 'PAID', paymentMethod: 'UPI', status: prev.status === 'PENDING' ? 'CONFIRMED' : prev.status }))
            }
            router.refresh()
          }}
          variant="card"
        />
      ) : null}

      {/* 1. Status Stepper Hero Card */}
      <TrackerStatusHero
        order={order}
        combinedStatus={combinedStatus}
        activeStep={activeStep}
        compOrder={compOrder}
        isScheduled={isScheduled}
        onOpenCancelModal={() => setIsCancelModalOpen(true)}
      />



      {/* 3. Rider Contact & Self-Pickup Card */}
      <TrackerRiderCard
        order={order}
        supportPhone={supportPhone}
        storeLat={storeLat}
        storeLng={storeLng}
        trackingMetrics={trackingMetrics}
      />

      {/* 4. Delivery Proof Card (When Delivered) */}
      {order.status === 'DELIVERED' && order.deliveryMethod !== 'PICKUP' && (
        <div className="bg-card border-2 border-accent p-4 min-[375px]:p-5 rounded-2xl shadow-md space-y-4 animate-fade-in">
          <h2 className="text-sm font-black text-text-primary flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 text-accent" />
            Proof of Delivery
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {order.deliveryPhoto ? (
              <div className="space-y-1.5">
                <span className="text-[10px] font-bold text-text-secondary block">Photo Confirmation</span>
                <div className="rounded-xl overflow-hidden border border-border">
                  <img
                    src={order.deliveryPhoto}
                    alt="Delivery confirmation proof"
                    className="w-full h-44 object-cover"
                    loading="lazy"
                  />
                </div>
              </div>
            ) : (
              <div className="space-y-2 flex flex-col justify-center items-center border border-dashed rounded-xl p-4 bg-muted/20">
                <Camera className="h-8 w-8 text-text-muted stroke-[1.2]" />
                <span className="text-xs text-text-muted">No photo proof uploaded</span>
              </div>
            )}
            
            <div className="space-y-3 flex flex-col justify-between">
              <div>
                <span className="text-[10px] font-bold text-text-secondary block">Delivery Location (GPS)</span>
                {order.deliveryLat && order.deliveryLng ? (
                  <div className="space-y-2 mt-1">
                    <p className="text-xs font-semibold text-text-primary leading-relaxed">
                      Delivered Executive Location: <br />
                      <span className="font-mono text-[11px] text-text-secondary">
                        {order.deliveryLat.toFixed(5)}° N, {order.deliveryLng.toFixed(5)}° E
                      </span>
                    </p>
                    <a
                      href={`https://www.google.com/maps/search/?api=1&query=${order.deliveryLat},${order.deliveryLng}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1.5 px-3.5 py-2.5 bg-accent text-white text-xs font-black rounded-xl hover:bg-accent/95 transition-all shadow-sm"
                    >
                      <Navigation className="h-3.5 w-3.5" />
                      View Delivery Spot on Google Maps
                    </a>
                  </div>
                ) : (
                  <p className="text-xs text-text-muted italic mt-1">GPS coordinates not captured for this order.</p>
                )}
              </div>
              
              <div className="bg-muted/40 p-3 rounded-xl border text-[11px] font-medium text-text-secondary leading-relaxed">
                Delivery address: <br />
                <span className="text-text-primary font-bold">{formatAddress(order.address, false)}</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 5. Destination Card */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3">
        <h3 className="text-sm font-bold text-text-primary border-b border-border/40 pb-2 flex items-center gap-2">
          <MapPin className="h-4 w-4 text-primary" />
          {order.deliveryMethod === 'PICKUP' ? 'Pickup Location' : 'Delivery Destination'}
        </h3>
        <div className="text-xs space-y-3">
          <p className="text-text-secondary leading-relaxed font-semibold">
            {formatAddress(order.address)}
            {order.deliveryMethod === 'PICKUP' && (
              <span className="block text-[10px] text-text-muted mt-1 font-bold">
                📍 Coordinates: {order.address?.lat || storeLat}, {order.address?.lng || storeLng}
              </span>
            )}
          </p>
          {order.deliveryMethod === 'PICKUP' ? (
            <a
              href={`https://www.google.com/maps/dir/?api=1&destination=${order.address?.lat || storeLat},${order.address?.lng || storeLng}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-accent/10 hover:bg-accent/20 text-accent text-xs font-black rounded-xl transition-all shadow-sm w-fit"
            >
              <Navigation className="h-3.5 w-3.5" />
              Get Store Directions
            </a>
          ) : (
            <a
              href={
                order.address.lat && order.address.lng
                  ? `https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`
                  : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                      formatAddress(order.address)
                    )}`
              }
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-accent/10 hover:bg-accent/20 text-accent text-xs font-black rounded-xl transition-all shadow-sm w-fit"
            >
              <Navigation className="h-3.5 w-3.5" />
              Locate Delivery Address on Google Maps
            </a>
          )}
        </div>
      </div>

      {/* 6. Itemized Receipt Breakdown */}
      <TrackerItemsSummary
        order={order}
        mergedItems={mergedItems}
        combinedSubtotal={combinedSubtotal}
        combinedDiscount={combinedDiscount}
        combinedDeliveryFee={combinedDeliveryFee}
        combinedTaxes={combinedTaxes}
        combinedMiscFee={combinedMiscFee}
        combinedTotal={combinedTotal}
        combinedRefundAmount={combinedRefundAmount}
      />

      {/* 7. Cancellation Confirmation Modal */}
      <TrackerCancelModal
        isOpen={isCancelModalOpen}
        isCancelling={isCancelling}
        onClose={() => setIsCancelModalOpen(false)}
        onConfirmCancel={handleCancelOrder}
      />
    </div>
  )
}
export default OrderTracker
