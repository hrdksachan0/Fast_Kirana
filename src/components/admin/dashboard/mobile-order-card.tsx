'use client'

import React from 'react'
import { Loader2, MessageSquare, Share2, Printer, FileText } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface MobileOrderCardProps {
  order: any
  updatingOrderId: string | null
  updatingPaymentId: string | null
  syncingOrderId: string | null
  onOpenOrderModal: (order: any) => void
  onUpdateOrderStatus: (orderId: string, status: string) => void
  onTogglePaymentStatus: (order: any, e?: React.MouseEvent) => void
  onSyncCashfreePayment: (order: any, e?: React.MouseEvent) => void
  onConvertToCOD: (order: any, e?: React.MouseEvent) => void
  onSendWhatsAppReminder: (order: any, e?: React.MouseEvent) => void
  onStatusSelectChange: (order: any, newStatus: string) => void
  onCancelOrder: (order: any) => void
  onRefundOrder: (order: any) => void
  onSendKOT: (order: any) => void
  onShareKitchen: (order: any) => void
  onPrintInvoice: (order: any) => void
  sendingKotIds: Set<string>
  printedKotIds: Set<string>
  fifoRank?: number | null
}

export function MobileOrderCard({
  order: o,
  updatingOrderId,
  updatingPaymentId,
  syncingOrderId,
  onOpenOrderModal,
  onUpdateOrderStatus,
  onTogglePaymentStatus,
  onSyncCashfreePayment,
  onConvertToCOD,
  onSendWhatsAppReminder,
  onStatusSelectChange,
  onCancelOrder,
  onRefundOrder,
  onSendKOT,
  onShareKitchen,
  onPrintInvoice,
  sendingKotIds,
  printedKotIds,
  fifoRank,
}: MobileOrderCardProps) {
  const isRest = o.restaurantId || o.orderType === 'RESTAURANT' || o.isCombined
  const isKotPrinted = printedKotIds.has(o.id) || o.subOrders?.some((s: any) => printedKotIds.has(s.id))
  const isSending = sendingKotIds.has(o.id) || o.subOrders?.some((s: any) => sendingKotIds.has(s.id))
  const isUpdating = updatingOrderId === o.id

  // Status color map
  const statusStyles: Record<string, string> = {
    ADMIN_PENDING: 'bg-violet-500/15 text-violet-700 dark:text-violet-300 border-violet-500/30',
    PENDING: 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30',
    CONFIRMED: 'bg-blue-500/15 text-blue-700 dark:text-blue-300 border-blue-500/30',
    PACKED: 'bg-indigo-500/15 text-indigo-700 dark:text-indigo-300 border-indigo-500/30',
    SHIPPED: 'bg-sky-500/15 text-sky-700 dark:text-sky-300 border-sky-500/30',
    DELIVERED: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30',
    CANCELLED: 'bg-rose-500/15 text-rose-700 dark:text-rose-300 border-rose-500/30',
  }

  // Quick next-step action button
  const nextAction: Record<string, { label: string; nextStatus: string; bg: string }> = {
    ADMIN_PENDING: { label: '🛡️ Approve', nextStatus: 'PENDING', bg: 'bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white' },
    PENDING: { label: '✓ Confirm', nextStatus: 'CONFIRMED', bg: 'bg-emerald-600 hover:bg-emerald-700 text-white' },
    CONFIRMED: { label: '✓ Pack', nextStatus: 'PACKED', bg: 'bg-amber-500 hover:bg-amber-600 text-white' },
    PACKED: { label: '✓ Ship', nextStatus: 'SHIPPED', bg: 'bg-indigo-600 hover:bg-indigo-700 text-white' },
    SHIPPED: { label: '✓ Deliver', nextStatus: 'DELIVERED', bg: 'bg-emerald-600 hover:bg-emerald-700 text-white' },
  }

  const action = nextAction[o.status]

  return (
    <div
      className="bg-card border border-border/70 rounded-2xl p-3.5 shadow-sm active:shadow-md transition-all space-y-2.5"
      onClick={() => onOpenOrderModal(o)}
    >
      {/* ── Top Row: Order ID, Badges, Total, Items Count ── */}
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5 flex-wrap">
            <span className="font-mono font-black text-sm text-text-primary tracking-tight">
              #{o.readableId || o.id.slice(0, 8)}
            </span>
            {fifoRank && fifoRank <= 3 && (
              <span className={`text-[8.5px] font-black px-1.5 py-0.5 rounded-full ${
                fifoRank === 1 
                  ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-500/30' 
                  : 'bg-zinc-100 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-400'
              }`}>
                👑 #{fifoRank}
              </span>
            )}
            {o.isCombined && (
              <span className="text-[8px] font-black px-1.5 py-0.5 rounded bg-purple-500/15 text-purple-700 dark:text-purple-300 border border-purple-500/25">
                COMBO
              </span>
            )}
            {o.isB2B && (
              <span className="text-[8px] font-black px-1.5 py-0.5 rounded bg-blue-500/15 text-blue-700 dark:text-blue-300 border border-blue-500/25">
                B2B
              </span>
            )}
          </div>
          <div className="text-[11px] font-bold text-text-secondary truncate mt-0.5">
            {o.userName || 'Customer'}
            {(o.userPhone || o.address?.phone) && (
              <span className="font-mono text-text-muted font-normal ml-1">
                ({o.userPhone || o.address?.phone})
              </span>
            )}
          </div>
        </div>

        {/* Total Price + Item count */}
        <div className="text-right shrink-0">
          <div className="font-black text-base text-text-primary tabular-nums">
            {formatPrice(o.total)}
          </div>
          {o.refundAmount > 0 && (
            <div className="text-[9px] font-bold text-rose-600">
              -₹{o.refundAmount} Ref
            </div>
          )}
          <span className="text-[9.5px] text-text-muted font-semibold">
            {o.items?.length || 0} items
          </span>
        </div>
      </div>

      {/* ── Middle Row: Store Tag + Payment Status (with interactive toggle) ── */}
      <div className="flex items-center justify-between gap-2 pt-1 border-t border-border/40" onClick={(e) => e.stopPropagation()}>
        <span className={`text-[9px] font-black px-2 py-0.5 rounded-md border truncate max-w-[55%] ${
          isRest 
            ? 'bg-purple-500/15 text-purple-700 dark:text-purple-300 border-purple-500/25' 
            : 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/25'
        }`}>
          {isRest ? `🍽️ ${((o as any).restaurantName || o.shopName || 'Restaurant').toUpperCase()}` : '🛒 DARK STORE'}
        </span>

        {/* Payment Badge Button (Tap to toggle) */}
        <button
          type="button"
          onClick={(e) => onTogglePaymentStatus(o, e)}
          disabled={updatingPaymentId === o.id}
          className="shrink-0 transition-transform active:scale-95 cursor-pointer"
          title="Tap to toggle payment status"
        >
          {o.paymentStatus === 'PAID' ? (
            o.paymentMethod === 'COD' ? (
              <span className="inline-flex items-center gap-1 text-[9px] font-black uppercase text-amber-700 dark:text-amber-300 bg-amber-500/15 border border-amber-500/30 px-2 py-0.5 rounded-full shadow-2xs">
                <span className="h-1.5 w-1.5 rounded-full bg-amber-500" />
                💵 CASH PAID ✅
              </span>
            ) : (
              <span className="inline-flex items-center gap-1 text-[9px] font-black uppercase text-emerald-600 dark:text-emerald-400 bg-emerald-500/15 border border-emerald-500/30 px-2 py-0.5 rounded-full shadow-2xs">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                📱 ONLINE / UPI ✅
              </span>
            )
          ) : (
            <span className="inline-flex items-center gap-1 text-[9px] font-black uppercase text-rose-700 dark:text-rose-300 bg-rose-500/15 border border-rose-500/30 px-2 py-0.5 rounded-full shadow-2xs">
              ⏳ {o.paymentMethod || 'COD'} (UNPAID)
            </span>
          )}
        </button>
      </div>

      {/* ── Rider Pickup Details Banner ── */}
      {(o.deliveryUser || o.deliveryBoyName || ((o.status === 'SHIPPED' || o.status === 'DELIVERED') && o.deliveryUserId)) && (
        <div className="flex items-center justify-between gap-2 px-2.5 py-1.5 bg-emerald-500/10 border border-emerald-500/25 rounded-xl text-[10.5px]" onClick={(e) => e.stopPropagation()}>
          <div className="flex items-center gap-1.5 min-w-0">
            <span className="text-xs">🛵</span>
            <span className="font-extrabold text-emerald-800 dark:text-emerald-300 truncate">
              {o.deliveryUser?.name || o.deliveryBoyName || 'FastKirana Rider'}
            </span>
            {(o.deliveryUser?.phone || o.deliveryBoyPhone) && (
              <span className="text-[10px] text-text-muted font-mono font-semibold">
                ({o.deliveryUser?.phone || o.deliveryBoyPhone})
              </span>
            )}
          </div>
          {(o.deliveryUser?.phone || o.deliveryBoyPhone) && (
            <div className="flex items-center gap-1 shrink-0">
              <a
                href={`tel:${o.deliveryUser?.phone || o.deliveryBoyPhone}`}
                className="px-2 py-0.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-lg text-[9.5px] flex items-center gap-0.5 shadow-2xs"
                title="Call Rider"
              >
                📞 Call
              </a>
            </div>
          )}
        </div>
      )}

      {/* ── Status Selector Dropdown (Full Control Toggle) ── */}
      <div className="flex items-center gap-2 pt-0.5" onClick={(e) => e.stopPropagation()}>
        <span className="text-[10px] font-black uppercase text-text-muted shrink-0">Status:</span>
        <select
          value={o.status}
          onChange={(e) => onStatusSelectChange(o, e.target.value)}
          disabled={isUpdating}
          className="flex-1 bg-zinc-100 dark:bg-zinc-800 px-2.5 py-1.5 rounded-xl border border-border text-[11px] font-extrabold text-text-primary focus:outline-none cursor-pointer shadow-2xs"
        >
          <option value="ADMIN_PENDING">🛡️ Needs Approval</option>
          <option value="PENDING">⏳ Placed / Pending</option>
          <option value="CONFIRMED">✅ Confirmed</option>
          <option value="PACKED">📦 Packed</option>
          <option value="SHIPPED">🛵 On the Way / Shipped</option>
          <option value="DELIVERED">🎉 Delivered</option>
          <option value="CANCELLED">❌ Cancelled</option>
        </select>
      </div>

      {/* ── Bottom Row: Primary Action & Quick Function Buttons ── */}
      <div className="flex items-center gap-1.5 flex-wrap pt-1 border-t border-border/40" onClick={(e) => e.stopPropagation()}>
        {/* Step Forward Action Button */}
        {action && (
          <button
            type="button"
            onClick={() => onUpdateOrderStatus(o.id, action.nextStatus)}
            disabled={isUpdating}
            className={`flex-1 min-w-[90px] py-1.5 px-2 text-[10px] font-black rounded-xl transition-all active:scale-95 shadow-xs cursor-pointer text-center ${action.bg}`}
          >
            {isUpdating ? <Loader2 className="h-3.5 w-3.5 animate-spin mx-auto" /> : action.label}
          </button>
        )}

        {/* Reject Button (Only for ADMIN_PENDING) */}
        {o.status === 'ADMIN_PENDING' && (
          <button
            type="button"
            onClick={() => onCancelOrder(o)}
            disabled={isUpdating}
            className="py-1.5 px-2 text-[9.5px] font-black rounded-xl bg-rose-500/10 text-rose-600 border border-rose-500/30 active:scale-95 cursor-pointer"
          >
            ✕ Reject
          </button>
        )}

        {/* Verify Online via Cashfree (if unpaid) */}
        {o.paymentStatus !== 'PAID' && (
          <button
            type="button"
            onClick={(e) => onSyncCashfreePayment(o, e)}
            disabled={syncingOrderId === o.id}
            className="py-1.5 px-2 text-[9.5px] font-black rounded-xl bg-blue-500/15 hover:bg-blue-500/25 text-blue-700 dark:text-blue-300 border border-blue-500/30 active:scale-95 cursor-pointer shadow-2xs"
            title="Fetch & verify live payment directly from Cashfree"
          >
            {syncingOrderId === o.id ? (
              <Loader2 className="h-3 w-3 animate-spin inline" />
            ) : (
              '⚡ Verify Cashfree'
            )}
          </button>
        )}

        {/* Convert to COD (if online unpaid) */}
        {o.paymentStatus !== 'PAID' && o.paymentMethod !== 'COD' && (
          <button
            type="button"
            onClick={(e) => onConvertToCOD(o, e)}
            disabled={updatingPaymentId === o.id}
            className="py-1.5 px-2 text-[9px] font-black rounded-xl bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/30 active:scale-95 cursor-pointer"
            title="Convert to Cash on Delivery"
          >
            💵 COD
          </button>
        )}

        {/* WhatsApp Link (if unpaid) */}
        {o.paymentStatus !== 'PAID' && (
          <button
            type="button"
            onClick={(e) => onSendWhatsAppReminder(o, e)}
            className="py-1.5 px-2 text-[9px] font-black rounded-xl bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 active:scale-95 cursor-pointer inline-flex items-center gap-1"
            title="Send WhatsApp payment link"
          >
            <MessageSquare className="h-3 w-3" />
            <span>WA Link</span>
          </button>
        )}

        {/* View Details Button */}
        <button
          type="button"
          onClick={() => onOpenOrderModal(o)}
          className="py-1.5 px-2.5 text-[10px] font-black rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-[#e20a22] dark:text-red-400 border border-red-500/20 active:scale-95 cursor-pointer"
        >
          👁️ View
        </button>

        {/* KOT Print (Restaurants / Kitchen) */}
        {isRest && (
          <button
            type="button"
            disabled={isSending}
            onClick={() => onSendKOT(o)}
            className={`py-1.5 px-2 text-[9.5px] font-black rounded-xl border active:scale-95 cursor-pointer inline-flex items-center gap-1 ${
              isSending
                ? 'bg-amber-500/15 text-amber-700 border-amber-500/30 animate-pulse'
                : isKotPrinted
                ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30'
                : 'bg-orange-500/10 text-orange-600 dark:text-orange-400 border-orange-500/25'
            }`}
            title="Send or reprint KOT command"
          >
            <Printer className="h-3 w-3" />
            <span>{isSending ? '⏳ Sending' : isKotPrinted ? '🖨️ KOT ✓' : '🖨️ KOT'}</span>
          </button>
        )}

        {/* Share Slip (WhatsApp to Kitchen) */}
        <button
          type="button"
          onClick={() => onShareKitchen(o)}
          className="py-1.5 px-2 text-[9.5px] font-black rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 border border-emerald-500/25 active:scale-95 cursor-pointer inline-flex items-center gap-1"
          title="Share slip on WhatsApp"
        >
          <Share2 className="h-3 w-3" />
          <span>Share</span>
        </button>

        {/* Invoice Print */}
        <button
          type="button"
          onClick={() => onPrintInvoice(o)}
          className="py-1.5 px-2 text-[9.5px] font-black rounded-xl bg-blue-500/10 hover:bg-blue-500/20 text-blue-600 dark:text-blue-400 border border-blue-500/25 active:scale-95 cursor-pointer inline-flex items-center gap-1"
          title="Customer Invoice"
        >
          <FileText className="h-3 w-3" />
          <span>Bill</span>
        </button>

        {/* Refund Button */}
        <button
          type="button"
          onClick={() => onRefundOrder(o)}
          className="py-1.5 px-2 text-[9.5px] font-black rounded-xl bg-zinc-500/10 hover:bg-zinc-500/20 text-text-secondary border border-border active:scale-95 cursor-pointer ml-auto"
          title="Record Refund"
        >
          ↩️ Refund
        </button>
      </div>
    </div>
  )
}
