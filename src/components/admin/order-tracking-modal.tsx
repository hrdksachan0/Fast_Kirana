'use client'

import { useCallback, useState } from 'react'
import { 
  X, 
  Loader2, 
  Copy, 
  Check, 
  MessageSquare, 
  Phone, 
  MapPin, 
  Clock,
  Package,
  Navigation,
  ShoppingBag
} from 'lucide-react'
import { toast } from 'sonner'
import Link from 'next/link'
import { formatAddress, formatPrice } from '@/lib/utils'

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
  notes?: string
}

interface Order {
  id: string
  readableId?: string
  baseReadableId?: string
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
  notes?: string
  deliveryInstructions?: string
  items?: OrderItem[]
  miscFee?: number
  paymentMethod?: string
  paymentStatus?: string
  total: number
  isCombined?: boolean
  groceryStatus?: string | null
  groceryItems?: OrderItem[]
  restaurantStatus?: string | null
  restaurantName?: string | null
  restaurantItems?: OrderItem[]
  subOrders?: any[]
}

interface OrderTrackingModalProps {
  selectedOrderForTracking: Order | null
  isLoadingOrderItems: boolean
  setSelectedOrderForTracking: (o: any) => void
}

const STATUS_CONFIG: Record<string, { bg: string; text: string; dot: string }> = {
  DELIVERED: { bg: 'bg-emerald-500/12', text: 'text-emerald-600 dark:text-emerald-400', dot: 'bg-emerald-500' },
  SHIPPED: { bg: 'bg-indigo-500/12', text: 'text-indigo-600 dark:text-indigo-400', dot: 'bg-indigo-500' },
  PACKED: { bg: 'bg-violet-500/12', text: 'text-violet-600 dark:text-violet-400', dot: 'bg-violet-500' },
  CONFIRMED: { bg: 'bg-blue-500/12', text: 'text-blue-600 dark:text-blue-400', dot: 'bg-blue-500' },
  CANCELLED: { bg: 'bg-rose-500/12', text: 'text-rose-600 dark:text-rose-400', dot: 'bg-rose-500' },
  PENDING: { bg: 'bg-amber-500/12', text: 'text-amber-600 dark:text-amber-400', dot: 'bg-amber-500' },
}

export default function OrderTrackingModal({
  selectedOrderForTracking,
  isLoadingOrderItems,
  setSelectedOrderForTracking,
}: OrderTrackingModalProps) {
  const [copied, setCopied] = useState(false)
  const order = selectedOrderForTracking

  const isPickup = (
    (order?.deliveryMethod || '').toUpperCase() === 'SELF_PICKUP' || 
    (order?.deliveryMethod || '').toUpperCase() === 'PICKUP' || 
    order?.isSelfPickup === true
  )

  const generateRestaurantKOTText = (o: Order | null) => {
    if (!o) return ''
    const pickupMode = (
      (o.deliveryMethod || '').toUpperCase() === 'SELF_PICKUP' || 
      (o.deliveryMethod || '').toUpperCase() === 'PICKUP' || 
      o.isSelfPickup === true
    )
    
    // For combined orders, prefer restaurant sub-order token e.g. 600981-R
    const restSub = o.subOrders?.find(s => s.type === 'RESTAURANT')
    const orderId = restSub?.readableId || o.readableId || o.id?.slice(0, 8) || 'Order'
    const outletName = restSub?.shopName || (o.restaurantId ? (o.restaurantName || o.shopName) : null) || 'Restaurant'
    const orderTime = o.createdAt ? new Date(o.createdAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : ''
    
    let text = `🍽️ *FASTKIRANA KITCHEN ORDER*\n`
    text += `━━━━━━━━━━━━━━━━━━━━━\n`
    text += `🆔 *Order Token:* #${orderId}\n`
    text += `⏰ *Order Time:* ${orderTime}\n`
    text += `📦 *Type:* ${pickupMode ? '🛍️ Self Pickup (Customer Takeaway)' : '🛵 Doorstep Delivery (Rider Pickup)'}\n`
    if (outletName) {
      text += `🏪 *Outlet:* ${outletName}\n`
    }
    const hasPremium = Boolean(
      o.notes?.toLowerCase().includes('premium') ||
      o.notes?.toLowerCase().includes('thermal') ||
      o.notes?.toLowerCase().includes('packaging') ||
      o.deliveryInstructions?.toLowerCase().includes('premium') ||
      (o.miscFee !== undefined && o.miscFee >= 15) ||
      (o as any).packagingOption === 'PREMIUM' ||
      (o as any).isPremiumPackaging === true
    )
    if (hasPremium) {
      text += `✨ *PACK IN PREMIUM THERMAL PACKAGING*\n`
    }
    text += `━━━━━━━━━━━━━━━━━━━━━\n`
    text += `📋 *ITEMS TO PREPARE:*\n\n`
    
    // If combined order, only include food dishes for the restaurant kitchen slip
    const targetItems = (o.restaurantItems && o.restaurantItems.length > 0)
      ? o.restaurantItems
      : (restSub?.items && restSub.items.length > 0)
      ? restSub.items
      : (o.items || [])

    if (targetItems && targetItems.length > 0) {
      targetItems.forEach((item: OrderItem, index: number) => {
        let displayName = item.name || ''
        if (item.selectedVariant) {
          const varClean = item.selectedVariant.replace(/[()]/g, '').trim().toLowerCase()
          const nameClean = displayName.toLowerCase()
          if (!nameClean.includes(varClean)) {
            displayName += ` (${item.selectedVariant.replace(/[()]/g, '').trim()})`
          }
        }
        text += `${index + 1}. *${displayName}*  ➜  *Qty: ${item.quantity}*\n`
        if (item.notes && item.notes.trim()) {
          text += `   ↳ _Item Note: ${item.notes.trim()}_\n`
        }
      })
    } else {
      text += `(No items listed)\n`
    }

    const totalQty = targetItems?.reduce((sum: number, item: OrderItem) => sum + (item.quantity || 1), 0) || 0
    text += `\n🔢 *Total Items to Pack:* ${totalQty} items\n`
    text += `━━━━━━━━━━━━━━━━━━━━━\n`

    // Customer Notes / Special Instructions (Sanitize automated packaging fee string)
    let customerNote = (o.notes || o.deliveryInstructions || '').trim()
    if (customerNote.toLowerCase().includes('premium thermal packaging')) {
      customerNote = customerNote.replace(/✨?\s*Premium Thermal Packaging Requested(\s*\(\+₹\d+\))?/gi, '').trim()
    }
    if (customerNote) {
      text += `📝 *Customer Cooking/Delivery Note:*\n"${customerNote}"\n`
      text += `━━━━━━━━━━━━━━━━━━━━━\n`
    }

    text += `👨‍🍳 *Chef Note:* Kripya fresh prepare karein aur safely pack karein.`
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
    toast.success('Kitchen order details copied!')
    setTimeout(() => setCopied(false), 2000)
  }

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setSelectedOrderForTracking(null)
    }
  }, [setSelectedOrderForTracking])

  if (!order) return null

  const customerPhone = order.userPhone || order.address?.phone
  const totalItemCount = order.items?.reduce((sum, item) => sum + (item.quantity || 1), 0) || 0
  const statusStyle = STATUS_CONFIG[order.status] || STATUS_CONFIG.PENDING
  const hasPremiumPackaging = Boolean(
    order.notes?.toLowerCase().includes('premium') ||
    order.notes?.toLowerCase().includes('thermal') ||
    order.notes?.toLowerCase().includes('packaging') ||
    order.deliveryInstructions?.toLowerCase().includes('premium') ||
    (order.miscFee !== undefined && order.miscFee >= 15) ||
    (order as any).packagingOption === 'PREMIUM' ||
    (order as any).isPremiumPackaging === true
  )
  const orderTime = order.createdAt 
    ? new Date(order.createdAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
    : ''
  const orderDate = order.createdAt
    ? new Date(order.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
    : ''

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm overflow-y-auto"
      role="dialog"
      aria-modal="true"
      aria-labelledby="order-tracking-title"
      onKeyDown={handleKeyDown}
      onClick={(e) => { if (e.target === e.currentTarget) setSelectedOrderForTracking(null) }}
    >
      <div 
        className="bg-card w-full max-w-[480px] sm:rounded-2xl rounded-t-2xl overflow-hidden shadow-2xl my-auto animate-in fade-in slide-in-from-bottom-4 sm:slide-in-from-bottom-0 sm:zoom-in-95 duration-300"
        style={{ boxShadow: '0 25px 60px -12px rgba(0,0,0,0.35)' }}
      >
        
        {/* ─── Compact Premium Header ─── */}
        <div className="relative px-5 pt-5 pb-4">
          {/* Close */}
          <button
            onClick={() => setSelectedOrderForTracking(null)}
            className="absolute top-4 right-4 h-7 w-7 rounded-full flex items-center justify-center bg-black/5 dark:bg-white/8 hover:bg-black/10 dark:hover:bg-white/15 text-text-secondary hover:text-text-primary transition-all cursor-pointer z-10"
            aria-label="Close"
          >
            <X className="h-3.5 w-3.5" strokeWidth={2.5} />
          </button>

          {/* Order ID & Status */}
          <div className="flex items-center gap-2.5 mb-3">
            <h3 id="order-tracking-title" className="text-[22px] font-black text-text-primary tracking-tight leading-none">
              #{order.readableId || order.id?.slice(0, 8)}
            </h3>
            <span className={`inline-flex items-center gap-1.5 text-[10px] font-extrabold uppercase px-2 py-[3px] rounded-full ${statusStyle.bg} ${statusStyle.text}`}>
              <span className={`h-1.5 w-1.5 rounded-full ${statusStyle.dot} ${order.status !== 'DELIVERED' && order.status !== 'CANCELLED' ? 'animate-pulse' : ''}`} />
              {order.status}
            </span>
          </div>

          {/* Meta Row: Tags + Time */}
          <div className="flex flex-wrap items-center gap-1.5">
            {order.shopName && (
              <span className="text-[10px] font-bold px-2 py-[3px] rounded-md bg-rose-500/8 text-rose-600 dark:text-rose-400">
                🍽️ {order.shopName}
              </span>
            )}
            <span className={`text-[10px] font-bold px-2 py-[3px] rounded-md ${
              isPickup 
                ? 'bg-violet-500/10 text-violet-600 dark:text-violet-400' 
                : 'bg-sky-500/8 text-sky-600 dark:text-sky-400'
            }`}>
              {isPickup ? '🛍️ Pickup' : '🛵 Delivery'}
            </span>
            {hasPremiumPackaging && (
              <span className="text-[10px] font-black px-2 py-[3px] rounded-md bg-gradient-to-r from-amber-500/20 to-yellow-500/20 text-amber-700 dark:text-amber-300 border border-amber-500/40 shadow-2xs">
                ✨ Premium Packaging (+₹15)
              </span>
            )}
            <span className="text-[10px] text-text-muted font-medium ml-auto tabular-nums">
              <Clock className="h-3 w-3 inline -mt-px mr-0.5 opacity-50" />
              {orderTime} · {orderDate}
            </span>
          </div>
        </div>

        {/* ─── Subtle Divider ─── */}
        <div className="h-px bg-border/60 mx-5" />

        {/* ─── Scrollable Content ─── */}
        <div className="px-5 py-4 space-y-3.5 max-h-[65vh] overflow-y-auto overscroll-contain">
          
          {/* ── Customer Row ── */}
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="h-9 w-9 rounded-full bg-gradient-to-br from-blue-500/15 to-indigo-500/15 flex items-center justify-center shrink-0">
                <span className="text-sm font-black text-blue-600 dark:text-blue-400">
                  {(order.userName || 'C')[0].toUpperCase()}
                </span>
              </div>
              <div className="min-w-0">
                <div className="font-bold text-sm text-text-primary truncate">
                  {order.userName || 'Walk-in Customer'}
                </div>
                <div className="text-[10px] text-text-muted truncate">{order.userEmail || ''}</div>
              </div>
            </div>

            {customerPhone && (
              <a
                href={`tel:${customerPhone}`}
                className="h-9 w-9 rounded-full bg-emerald-500/10 hover:bg-emerald-500/20 flex items-center justify-center text-emerald-600 transition-colors cursor-pointer shrink-0 group"
                title={customerPhone}
              >
                <Phone className="h-4 w-4 group-hover:scale-110 transition-transform" strokeWidth={2} />
              </a>
            )}
          </div>

          {/* ── Recipient Details Badge if ordered for someone else ── */}
          {order.notes?.includes('Order for:') && (
            <div className="p-3 bg-gradient-to-r from-amber-500/10 to-orange-500/10 border border-amber-500/25 rounded-xl flex items-center justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <span className="text-base shrink-0">🎁</span>
                <div className="min-w-0">
                  <div className="text-[10px] font-black uppercase text-amber-700 dark:text-amber-400 tracking-wider">
                    Ordering For Other Person
                  </div>
                  <div className="text-xs font-bold text-text-primary truncate">
                    {order.notes.split('|')[0].replace('🎁 Order for:', '').trim()}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ── Delivery Address ── */}
          {!isPickup && (
            <div className="flex items-start gap-2.5 p-3 bg-muted/40 rounded-xl">
              <MapPin className="h-4 w-4 text-text-secondary mt-0.5 shrink-0" strokeWidth={1.8} />
              <div className="flex-1 min-w-0">
                <div className="text-xs font-semibold text-text-primary leading-snug">
                  {formatAddress(order.address, false)}
                </div>
                {order.address?.lat && order.address?.lng && (
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-[10px] font-bold text-primary hover:underline mt-1"
                  >
                    <Navigation className="h-2.5 w-2.5" />
                    Open in Maps
                  </a>
                )}
              </div>
            </div>
          )}
          {isPickup && (
            <div className="flex items-center gap-2.5 p-3 bg-violet-500/6 rounded-xl">
              <ShoppingBag className="h-4 w-4 text-violet-500 shrink-0" strokeWidth={1.8} />
              <span className="text-xs font-semibold text-violet-700 dark:text-violet-300">
                Counter Pickup · No rider needed
              </span>
            </div>
          )}

          {/* ── Premium Thermal Packaging Card Banner ── */}
          {hasPremiumPackaging && (
            <div className="p-3 bg-gradient-to-r from-amber-500/15 via-yellow-500/10 to-amber-500/15 border border-amber-500/40 rounded-xl flex items-center justify-between gap-2 shadow-2xs">
              <div className="flex items-center gap-2.5">
                <span className="text-lg">✨</span>
                <div>
                  <div className="text-xs font-black text-amber-900 dark:text-amber-200 uppercase tracking-wide">
                    Premium Thermal Packaging (+₹15)
                  </div>
                  <div className="text-[10px] font-semibold text-amber-800/80 dark:text-amber-300/80 mt-0.5">
                    Insulated hot/cold foil packaging requested for kitchen &amp; delivery
                  </div>
                </div>
              </div>
              <span className="text-[10px] font-black uppercase px-2 py-1 bg-amber-500 text-white rounded-lg shadow-2xs shrink-0">
                Thermal Pack
              </span>
            </div>
          )}

          {/* ── Customer Note (if any) ── */}
          {(order.notes || order.deliveryInstructions) && (
            <div className="p-3 bg-amber-500/8 rounded-xl border border-amber-500/15">
              <div className="text-[9px] font-black uppercase tracking-widest text-amber-600 dark:text-amber-400 mb-1">
                📝 Customer Note
              </div>
              <p className="text-xs font-medium text-text-primary leading-relaxed italic">
                &quot;{order.notes || order.deliveryInstructions}&quot;
              </p>
            </div>
          )}

          {/* ── Items List ── */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Items ({order.items?.length || 0})
              </span>
              <span className="text-[10px] font-bold text-text-muted tabular-nums">
                {totalItemCount} units
              </span>
            </div>

            <div className="rounded-xl border border-border/60 overflow-hidden">
              {isLoadingOrderItems ? (
                <div className="p-6 text-center text-xs font-medium text-text-muted flex flex-col items-center gap-2">
                  <Loader2 className="h-5 w-5 animate-spin text-primary" />
                  Loading items…
                </div>
              ) : !order.items || order.items.length === 0 ? (
                <div className="p-6 text-center text-xs text-text-muted">
                  No items available
                </div>
              ) : (
                <div className="divide-y divide-border/40">
                  {order.isCombined && order.subOrders && order.subOrders.length > 1 ? (
                    order.subOrders.map((sub: any, subIdx: number) => {
                      const isRest = sub.type === 'RESTAURANT' || !!sub.restaurantId
                      // Strictly match items belonging to this specific sub-order
                      let subItems: OrderItem[] = []
                      if (sub.items && Array.isArray(sub.items) && sub.items.length > 0) {
                        // If sub.items is populated, only keep items whose orderId matches this sub (or all if not tagged)
                        const filtered = sub.items.filter((item: any) => !item.orderId || item.orderId === sub.id)
                        subItems = filtered.length > 0 ? filtered : sub.items
                      }
                      if ((!subItems || subItems.length === 0) && order.items) {
                        subItems = order.items.filter((item: any) => item.orderId === sub.id)
                      }
                      // If still empty or no sub-order items, skip this group
                      if (!subItems || subItems.length === 0) return null
                      return (
                        <div key={sub.id || subIdx} className="space-y-0">
                          <div className="bg-muted/60 px-3 py-1.5 text-[10px] font-black uppercase tracking-wider flex items-center justify-between text-text-secondary border-b border-border/40">
                            <span>{isRest ? `🍽️ ${sub.shopName || 'Restaurant'}` : `🥘 ${sub.shopName || 'FastKirana Dark Store'}`}</span>
                            <span className="font-mono text-text-muted">#{sub.readableId || sub.id?.slice(0, 8)}</span>
                          </div>
                          <div className="divide-y divide-border/30">
                            {subItems.map((item: OrderItem, idx: number) => (
                              <div key={item.id || idx} className="p-3 flex items-center gap-3 hover:bg-muted/20 transition-colors">
                                {item.imageUrl ? (
                                  <img src={item.imageUrl} alt={item.name} className="w-9 h-9 object-cover rounded-lg border border-border/30 shrink-0" />
                                ) : (
                                  <div className="w-9 h-9 rounded-lg bg-muted/60 flex items-center justify-center shrink-0">
                                    <Package className="h-4 w-4 text-text-muted" strokeWidth={1.5} />
                                  </div>
                                )}
                                <div className="flex-1 min-w-0">
                                  <div className="font-semibold text-xs text-text-primary leading-tight truncate">{item.name}</div>
                                  <div className="flex items-center gap-1.5 mt-0.5">
                                    {item.selectedVariant && (
                                      <span className="text-[10px] text-text-muted font-medium">{item.selectedVariant}</span>
                                    )}
                                    {item.notes && (
                                      <span className="text-[9px] bg-amber-500/12 text-amber-700 dark:text-amber-300 px-1.5 py-px rounded font-medium">
                                        📝 {item.notes}
                                      </span>
                                    )}
                                  </div>
                                </div>
                                <div className="text-right shrink-0 pl-2">
                                  <div className="text-xs font-black text-text-primary tabular-nums">
                                    {formatPrice(item.quantity * item.price)}
                                  </div>
                                  <div className="text-[10px] text-text-muted font-medium tabular-nums">
                                    {item.quantity} × {formatPrice(item.price)}
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      )
                    })
                  ) : (
                    order.items.map((item: OrderItem, idx: number) => (
                      <div key={item.id || idx} className="p-3 flex items-center gap-3 hover:bg-muted/20 transition-colors">
                        {item.imageUrl ? (
                          <img 
                            src={item.imageUrl} 
                            alt={item.name} 
                            className="w-10 h-10 object-cover rounded-lg border border-border/30 shrink-0" 
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-lg bg-muted/60 flex items-center justify-center shrink-0">
                            <Package className="h-4 w-4 text-text-muted" strokeWidth={1.5} />
                          </div>
                        )}

                        <div className="flex-1 min-w-0">
                          <div className="font-semibold text-xs text-text-primary leading-tight truncate">
                            {item.name}
                          </div>
                          <div className="flex items-center gap-1.5 mt-0.5">
                            {item.selectedVariant && (
                              <span className="text-[10px] text-text-muted font-medium">
                                {item.selectedVariant}
                              </span>
                            )}
                            {item.notes && (
                              <span className="text-[9px] bg-amber-500/12 text-amber-700 dark:text-amber-300 px-1.5 py-px rounded font-medium">
                                📝 {item.notes}
                              </span>
                            )}
                          </div>
                        </div>

                        <div className="text-right shrink-0 pl-2">
                          <div className="text-xs font-black text-text-primary tabular-nums">
                            {formatPrice(item.quantity * item.price)}
                          </div>
                          <div className="text-[10px] text-text-muted font-medium tabular-nums">
                            {item.quantity} × {formatPrice(item.price)}
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              )}
            </div>
          </div>

          {/* ── Payment Summary Bar ── */}
          <div className="flex items-center justify-between p-3.5 bg-muted/30 rounded-xl">
            <div className="flex items-center gap-2">
              <div className={`h-2 w-2 rounded-full ${order.paymentStatus === 'PAID' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
              <div>
                <span className="text-[10px] font-bold text-text-secondary block leading-tight">
                  {order.paymentMethod || 'COD'}
                </span>
                <span className={`text-[10px] font-extrabold uppercase ${
                  order.paymentStatus === 'PAID' ? 'text-emerald-600' : 'text-amber-600'
                }`}>
                  {order.paymentStatus || 'PENDING'}
                </span>
              </div>
            </div>
            <div className="text-right">
              <span className="text-[10px] text-text-muted font-medium block">Total</span>
              <span className="text-lg font-black text-text-primary tabular-nums tracking-tight">
                {formatPrice(order.total)}
              </span>
            </div>
          </div>
        </div>

        {/* ─── Footer Action Bar ─── */}
        <div className="px-5 py-3.5 border-t border-border/60 bg-muted/20 flex items-center gap-2">
          {/* WhatsApp Kitchen CTA */}
          <button
            type="button"
            onClick={handleShareWhatsApp}
            className="flex-1 h-10 bg-[#25D366] hover:bg-[#1fba59] text-white text-xs font-black rounded-xl transition-all shadow-sm hover:shadow-md cursor-pointer flex items-center justify-center gap-2 active:scale-[0.97]"
          >
            <MessageSquare className="h-4 w-4" strokeWidth={2.2} />
            Kitchen Slip
          </button>

          {/* Copy */}
          <button
            type="button"
            onClick={handleCopyKitchenDetails}
            className="h-10 w-10 bg-card hover:bg-muted border border-border/80 rounded-xl transition-all cursor-pointer flex items-center justify-center active:scale-[0.93] shrink-0"
            title="Copy kitchen list"
          >
            {copied ? <Check className="h-4 w-4 text-emerald-500" strokeWidth={2.5} /> : <Copy className="h-4 w-4 text-text-secondary" strokeWidth={1.8} />}
          </button>

          {/* Track / Map */}
          {!isPickup && (
            <Link
              href={`/order/${order.id}/track`}
              target="_blank"
              className="h-10 px-4 bg-text-primary text-card text-xs font-black rounded-xl transition-all shadow-sm hover:opacity-90 cursor-pointer flex items-center gap-1.5 active:scale-[0.97] shrink-0"
            >
              <Navigation className="h-3.5 w-3.5" strokeWidth={2} />
              <span>Track</span>
            </Link>
          )}
        </div>

      </div>
    </div>
  )
}
