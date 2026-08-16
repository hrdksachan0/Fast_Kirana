'use client'

import { useCallback, useState } from 'react'
import { X, Loader2, Share2, Copy, Check, MessageSquare } from 'lucide-react'
import { toast } from 'sonner'
import Link from 'next/link'
import { formatOrderTime } from '@/lib/date-helpers'
import { formatAddress } from '@/lib/utils'

interface Address {
  phone?: string
  lat?: number
  lng?: number
  [key: string]: any
}

interface OrderItem {
  id: string
  name: string
  quantity: number
  price: number
  imageUrl?: string
  selectedVariant?: string
}

interface AssignedUser {
  name: string
}

interface Order {
  id: string
  readableId?: string
  status: string
  restaurantId?: string
  orderType?: string
  shopName?: string
  deliveryMethod?: string
  isSelfPickup?: boolean
  createdAt: string
  confirmedAt?: string
  packedAt?: string
  shippedAt?: string
  userName?: string
  userEmail?: string
  userPhone?: string
  address?: Address
  assignedPicker?: AssignedUser
  assignedChef?: AssignedUser
  deliveryUser?: AssignedUser
  items?: OrderItem[]
  paymentMethod?: string
  paymentStatus?: string
  total: number
}

interface OrderTrackingModalProps {
  selectedOrderForTracking: Order | null
  isLoadingOrderItems: boolean
  setSelectedOrderForTracking: (o: any) => void
}

export default function OrderTrackingModal({
  selectedOrderForTracking,
  isLoadingOrderItems,
  setSelectedOrderForTracking,
}: OrderTrackingModalProps) {
  const [copied, setCopied] = useState(false)
  const order = selectedOrderForTracking

  const generateRestaurantKOTText = (o: Order | null) => {
    if (!o) return ''
    const isPickup = ((o.deliveryMethod || '').toUpperCase() === 'SELF_PICKUP' || (o.deliveryMethod || '').toUpperCase() === 'PICKUP' || o.isSelfPickup)
    const orderId = o.readableId || o.id?.slice(0, 8) || 'Order'
    const orderTime = o.createdAt ? new Date(o.createdAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : ''
    
    let text = `🍳 *KITCHEN ORDER - #${orderId}*\n`
    text += `⏰ *Time:* ${orderTime}\n`
    text += `📦 *Type:* ${isPickup ? '🛍️ SELF PICKUP' : '🛵 DOORSTEP DELIVERY'}\n`
    if (o.shopName) {
      text += `🏪 *Restaurant:* ${o.shopName}\n`
    }
    text += `\n📋 *ITEMS TO PREPARE:*\n`
    
    if (o.items && o.items.length > 0) {
      o.items.forEach((item, index) => {
        const variantText = item.selectedVariant ? ` (${item.selectedVariant})` : ''
        text += `${index + 1}. *${item.name}${variantText}*  ✖  *${item.quantity}*\n`
      })
    } else {
      text += `(No items listed)\n`
    }

    const totalQty = o.items?.reduce((sum, item) => sum + (item.quantity || 1), 0) || 0
    text += `\n🔢 *Total Items:* ${totalQty} units\n`
    text += `⚠️ *Kitchen Copy: Only Product Preparation Details*`
    return text
  }

  const handleShareWhatsApp = () => {
    const text = generateRestaurantKOTText(order)
    const url = `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`
    window.open(url, '_blank')
  }

  const handleCopyKitchenDetails = () => {
    const text = generateRestaurantKOTText(order)
    navigator.clipboard.writeText(text)
    setCopied(true)
    toast.success('Kitchen order details copied to clipboard!')
    setTimeout(() => setCopied(false), 2000)
  }

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setSelectedOrderForTracking(null)
    }
  }, [setSelectedOrderForTracking])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs overflow-y-auto"
      role="dialog"
      aria-modal="true"
      aria-labelledby="order-tracking-title"
      onKeyDown={handleKeyDown}
    >
      <div className="bg-card border border-border rounded-3xl w-full max-w-2xl overflow-hidden shadow-2xl space-y-0 my-auto animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-5 bg-muted/40 border-b border-border flex items-center justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h3 id="order-tracking-title" className="font-extrabold text-base text-text-primary">
                Order #{order?.readableId || order?.id?.slice(0, 8)}
              </h3>
              <span className={`text-[10px] font-black px-2 py-0.5 rounded-full border ${
                order?.status === 'DELIVERED' ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20' :
                order?.status === 'SHIPPED' ? 'bg-indigo-500/10 text-indigo-600 border-indigo-500/20' :
                order?.status === 'PACKED' ? 'bg-purple-500/10 text-purple-600 border-purple-500/20' :
                order?.status === 'CONFIRMED' ? 'bg-blue-500/10 text-blue-600 border-blue-500/20' :
                order?.status === 'CANCELLED' ? 'bg-rose-500/10 text-rose-600 border-rose-500/20' :
                'bg-amber-500/10 text-amber-600 border-amber-500/20'
              }`}>
                {order?.status}
              </span>

              {/* Store Type Badge */}
              {order?.restaurantId || order?.orderType === 'RESTAURANT' ? (
                <span className="text-[9.5px] font-black px-2 py-0.5 rounded-md bg-rose-500/15 text-rose-700 dark:text-rose-300 border border-rose-500/30">
                  🍽️ {order?.shopName || 'RESTAURANT KITCHEN'}
                </span>
              ) : (
                <span className="text-[9.5px] font-black px-2 py-0.5 rounded-md bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30">
                  🛒 GROCERY STORE
                </span>
              )}

              {/* Fulfillment Method Badge */}
              {((order?.deliveryMethod || '').toUpperCase() === 'SELF_PICKUP' || (order?.deliveryMethod || '').toUpperCase() === 'PICKUP' || order?.isSelfPickup) ? (
                <span className="text-[9.5px] font-black px-2.5 py-0.5 rounded-full bg-purple-600 text-white shadow-xs animate-pulse">
                  🛍️ SELF PICKUP
                </span>
              ) : (
                <span className="text-[9.5px] font-black px-2 py-0.5 rounded-md bg-sky-500/15 text-sky-700 dark:text-sky-300 border border-sky-500/30">
                  🛵 HOME DELIVERY
                </span>
              )}
            </div>
            <p className="text-[11px] text-text-muted mt-0.5 font-mono">
              Placed on {order?.createdAt ? new Date(order.createdAt).toLocaleString() : ''}
            </p>
          </div>
          <button
            onClick={() => setSelectedOrderForTracking(null)}
            className="p-1.5 rounded-full hover:bg-muted text-text-secondary transition-colors cursor-pointer text-sm font-bold"
            aria-label="Close order tracking"
          >
            ✕
          </button>
        </div>

        <div className="p-5 space-y-6 max-h-[75vh] overflow-y-auto">
          {/* Tracking Timeline Stepper */}
          <div className="bg-muted/20 border border-border/60 rounded-2xl p-4 space-y-3">
            <h4 className="text-xs font-black uppercase tracking-wider text-text-secondary">
              📍 Order Progress Timeline & Timestamps
            </h4>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
              <div className={`p-2.5 rounded-xl border ${order?.createdAt ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-700 dark:text-emerald-400' : 'bg-muted border-border text-text-muted'}`}>
                <div className="text-[10px] font-black uppercase">1. Placed</div>
                <div className="text-[9px] font-mono mt-0.5 font-bold">
                  {order?.createdAt ? formatOrderTime(order.createdAt) : '—'}
                </div>
              </div>
              <div className={`p-2.5 rounded-xl border ${order?.confirmedAt ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-700 dark:text-emerald-400' : 'bg-muted border-border text-text-muted'}`}>
                <div className="text-[10px] font-black uppercase">2. Confirmed</div>
                <div className="text-[9px] font-mono mt-0.5 font-bold">
                  {order?.confirmedAt ? formatOrderTime(order.confirmedAt) : '—'}
                </div>
              </div>
              <div className={`p-2.5 rounded-xl border ${order?.packedAt ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-700 dark:text-emerald-400' : 'bg-muted border-border text-text-muted'}`}>
                <div className="text-[10px] font-black uppercase">3. Packed</div>
                <div className="text-[9px] font-mono mt-0.5 font-bold">
                  {order?.packedAt ? formatOrderTime(order.packedAt) : '—'}
                </div>
              </div>
              <div className={`p-2.5 rounded-xl border ${order?.shippedAt ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-700 dark:text-emerald-400' : 'bg-muted border-border text-text-muted'}`}>
                <div className="text-[10px] font-black uppercase">4. Dispatched</div>
                <div className="text-[9px] font-mono mt-0.5 font-bold">
                  {order?.shippedAt ? formatOrderTime(order.shippedAt) : '—'}
                </div>
              </div>
            </div>
          </div>

          {/* Customer & Address Details */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="p-3.5 bg-muted/20 border border-border/60 rounded-2xl space-y-1.5">
              <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                👤 Customer Details
              </span>
              <div className="font-extrabold text-sm text-text-primary">
                {order?.userName || 'No Name'}
              </div>
              <div className="text-xs text-text-muted">{order?.userEmail}</div>
              {(order?.userPhone || order?.address?.phone) && (
                <a
                  href={`tel:${order?.userPhone || order?.address?.phone}`}
                  className="inline-flex items-center gap-1 text-xs font-black text-primary hover:underline mt-1"
                >
                  📞 {order?.userPhone || order?.address?.phone}
                </a>
              )}
            </div>

            <div className="p-3.5 bg-muted/20 border border-border/60 rounded-2xl space-y-1.5">
              <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                🏠 Delivery Address
              </span>
              <div className="text-xs font-semibold text-text-primary leading-snug">
                {formatAddress(order?.address, false)}
              </div>
              {order?.address?.lat && order?.address?.lng && (
                <a
                  href={`https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-[11px] font-black text-emerald-600 hover:underline mt-1"
                >
                  📍 Open GPS Coordinates on Google Maps
                </a>
              )}
            </div>
          </div>

          {/* Staff Assignments */}
          <div className="grid grid-cols-3 gap-2 text-xs">
            <div className="p-2.5 bg-muted/30 border border-border/50 rounded-xl">
              <span className="text-[9px] font-extrabold uppercase text-text-secondary block">🛒 Picker</span>
              <span className="font-bold text-text-primary block mt-0.5">{order?.assignedPicker?.name || 'Unassigned'}</span>
            </div>
            <div className="p-2.5 bg-muted/30 border border-border/50 rounded-xl">
              <span className="text-[9px] font-extrabold uppercase text-text-secondary block">🍳 Chef</span>
              <span className="font-bold text-text-primary block mt-0.5">{order?.assignedChef?.name || 'Unassigned'}</span>
            </div>
            <div className="p-2.5 bg-muted/30 border border-border/50 rounded-xl">
              <span className="text-[9px] font-extrabold uppercase text-text-secondary block">🛵 Rider</span>
              <span className="font-bold text-text-primary block mt-0.5">{order?.deliveryUser?.name || 'Unassigned'}</span>
            </div>
          </div>

          {/* Restaurant Kitchen Share Box (Products Only - No Customer/Payment Details) */}
          <div className="p-4 bg-gradient-to-r from-orange-500/10 via-amber-500/5 to-orange-500/10 border border-orange-500/25 rounded-2xl space-y-3">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-orange-500/15 pb-2.5">
              <div className="flex items-center gap-2">
                <span className="text-xl">🍳</span>
                <div>
                  <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">
                    Share with Restaurant / Kitchen
                  </h4>
                  <p className="text-[10px] text-text-muted">
                    Safe kitchen slip: Sends only dishes & quantities (no customer phone/address/totals)
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-1.5 shrink-0">
                <button
                  type="button"
                  onClick={handleShareWhatsApp}
                  className="px-3 py-1.5 bg-[#25D366] hover:bg-[#20bd5a] text-white text-[11px] font-black rounded-xl transition-all shadow-xs active:scale-95 flex items-center gap-1.5 cursor-pointer"
                  title="Share products via WhatsApp with Restaurant"
                >
                  <MessageSquare className="h-3.5 w-3.5" />
                  <span>WhatsApp</span>
                </button>

                <button
                  type="button"
                  onClick={handleCopyKitchenDetails}
                  className="px-3 py-1.5 bg-card hover:bg-muted border border-border text-text-primary text-[11px] font-bold rounded-xl transition-all shadow-xs active:scale-95 flex items-center gap-1.5 cursor-pointer"
                  title="Copy kitchen text to clipboard"
                >
                  {copied ? <Check className="h-3.5 w-3.5 text-emerald-600" /> : <Copy className="h-3.5 w-3.5" />}
                  <span>{copied ? 'Copied!' : 'Copy'}</span>
                </button>
              </div>
            </div>

            {/* Quick Preview of What the Kitchen Sees */}
            <div className="bg-card/70 border border-border/50 rounded-xl p-3 text-[11px] font-mono space-y-1">
              <div className="text-text-secondary font-bold text-[10px] uppercase">
                Preview Kitchen Slip (Order #{order?.readableId || order?.id?.slice(0, 8)}):
              </div>
              <div className="text-text-primary font-semibold space-y-0.5 pt-1">
                {order?.items && order.items.length > 0 ? (
                  order.items.map((item, idx) => (
                    <div key={idx} className="flex justify-between items-center text-xs">
                      <span>{idx + 1}. {item.name} {item.selectedVariant ? `(${item.selectedVariant})` : ''}</span>
                      <span className="font-black text-orange-600 dark:text-orange-400">✖ {item.quantity}</span>
                    </div>
                  ))
                ) : (
                  <div className="text-text-muted italic">Click Quick View or wait for items to load...</div>
                )}
              </div>
            </div>
          </div>

          {/* Items List */}
          <div className="space-y-2">
            <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
              🛍️ Ordered Items ({order?.items?.length || 0})
            </span>
            <div className="divide-y divide-border/40 border border-border/60 rounded-2xl overflow-hidden min-h-[60px]">
              {isLoadingOrderItems ? (
                <div className="p-4 text-center text-xs font-bold text-text-muted flex items-center justify-center gap-2">
                  <Loader2 className="h-4 w-4 animate-spin text-primary" />
                  Fetching item details...
                </div>
              ) : !order?.items || order.items.length === 0 ? (
                <div className="p-4 text-center text-xs font-bold text-text-muted">
                  No items recorded for this order.
                </div>
              ) : (
                order.items.map((item: OrderItem) => (
                  <div key={item.id} className="p-3 flex items-center justify-between gap-3 bg-card hover:bg-muted/10">
                    <div className="flex items-center gap-3">
                      {item.imageUrl ? (
                        <img src={item.imageUrl} alt={item.name} className="w-10 h-10 object-cover rounded-xl border border-border/40" />
                      ) : (
                        <div className="w-10 h-10 rounded-xl bg-muted flex items-center justify-center text-sm font-bold">📦</div>
                      )}
                      <div>
                        <div className="font-bold text-xs text-text-primary">{item.name}</div>
                        {item.selectedVariant && (
                          <span className="text-[10px] text-text-muted font-medium block">Variant: {item.selectedVariant}</span>
                        )}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-black text-xs text-text-primary">
                        {item.quantity} x ₹{item.price} = ₹{item.quantity * item.price}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Payment Summary */}
          <div className="p-4 bg-emerald-500/5 border border-emerald-500/20 rounded-2xl flex items-center justify-between">
            <div>
              <span className="text-[10px] font-black uppercase tracking-wider text-emerald-700 dark:text-emerald-400 block">
                Payment ({order?.paymentMethod})
              </span>
              <span className={`text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded mt-1 inline-block ${
                order?.paymentStatus === 'PAID' ? 'bg-emerald-500/20 text-emerald-700 dark:text-emerald-300' : 'bg-amber-500/20 text-amber-700 dark:text-amber-300'
              }`}>
                {order?.paymentStatus}
              </span>
            </div>
            <div className="text-right">
              <span className="text-[10px] text-text-muted font-bold block uppercase">Grand Total</span>
              <span className="text-lg font-black text-emerald-700 dark:text-emerald-400">
                ₹{order?.total}
              </span>
            </div>
          </div>
        </div>

        {/* Modal Actions Footer */}
        <div className="p-4 bg-muted/40 border-t border-border flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleShareWhatsApp}
              className="px-3.5 py-2 bg-[#25D366] hover:bg-[#20bd5a] text-white text-xs font-black rounded-xl transition-all shadow-xs cursor-pointer flex items-center gap-1.5 active:scale-95"
            >
              <MessageSquare className="h-3.5 w-3.5" />
              <span>WhatsApp Kitchen Slip</span>
            </button>
            <button
              type="button"
              onClick={handleCopyKitchenDetails}
              className="px-3 py-2 border border-border bg-card hover:bg-muted text-xs font-bold rounded-xl transition-all shadow-xs cursor-pointer flex items-center gap-1.5 active:scale-95"
            >
              {copied ? <Check className="h-3.5 w-3.5 text-emerald-600" /> : <Copy className="h-3.5 w-3.5" />}
              <span>{copied ? 'Copied' : 'Copy List'}</span>
            </button>
          </div>

          <div className="flex items-center gap-2">
            <Link
              href={`/order/${order?.id}/track`}
              target="_blank"
              className="px-3.5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-black rounded-xl transition-all shadow-xs cursor-pointer flex items-center gap-1.5"
            >
              🗺️ Track Driver
            </Link>
            <button
              onClick={() => setSelectedOrderForTracking(null)}
              className="px-4 py-2 border border-border rounded-xl text-xs font-bold hover:bg-muted transition-all cursor-pointer"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
