'use client'

import React from 'react'
import { Loader2 } from 'lucide-react'
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

  const statusLabels: Record<string, string> = {
    ADMIN_PENDING: '🛡️ Approval',
    PENDING: '⏳ Placed',
    CONFIRMED: '✅ Confirmed',
    PACKED: '📦 Packed',
    SHIPPED: '🚛 Shipped',
    DELIVERED: '✅ Delivered',
    CANCELLED: '❌ Cancelled',
  }

  // Next action button
  const nextAction: Record<string, { label: string; nextStatus: string; bg: string }> = {
    ADMIN_PENDING: { label: '🛡️ Approve', nextStatus: 'PENDING', bg: 'bg-gradient-to-r from-emerald-600 to-teal-600 text-white' },
    PENDING: { label: '✓ Confirm', nextStatus: 'CONFIRMED', bg: 'bg-emerald-600 text-white' },
    CONFIRMED: { label: '✓ Pack', nextStatus: 'PACKED', bg: 'bg-amber-500 text-white' },
    PACKED: { label: '✓ Ship', nextStatus: 'SHIPPED', bg: 'bg-indigo-600 text-white' },
    SHIPPED: { label: '✓ Deliver', nextStatus: 'DELIVERED', bg: 'bg-emerald-600 text-white' },
  }

  const action = nextAction[o.status]

  return (
    <div
      className="bg-card border border-border/60 rounded-2xl p-3 shadow-sm active:shadow-md transition-shadow"
      onClick={() => onOpenOrderModal(o)}
    >
      {/* Row 1: Order ID + Amount + Status */}
      <div className="flex items-start justify-between gap-2 mb-2">
        <div className="min-w-0">
          <div className="flex items-center gap-1.5 flex-wrap">
            <span className="font-mono font-black text-[13px] text-text-primary">
              #{o.readableId || o.id.slice(0, 8)}
            </span>
            {fifoRank && fifoRank <= 3 && (
              <span className={`text-[8px] font-black px-1 py-0.5 rounded ${fifoRank === 1 ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400' : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400'}`}>
                #{fifoRank}
              </span>
            )}
            {o.isB2B && <span className="text-[8px] font-black px-1 py-0.5 rounded bg-blue-500/15 text-blue-700">B2B</span>}
          </div>
          <div className="text-[10px] font-bold text-text-secondary mt-0.5">
            {o.userName || 'Customer'} {o.userPhone || o.address?.phone ? `· ${o.userPhone || o.address?.phone}` : ''}
          </div>
        </div>
        <div className="text-right shrink-0">
          <div className="font-black text-sm text-text-primary">{formatPrice(o.total)}</div>
          <span className={`inline-block text-[8px] font-black uppercase px-1.5 py-0.5 rounded-full border mt-0.5 ${statusStyles[o.status] || 'bg-muted text-text-secondary border-border'}`}>
            {statusLabels[o.status] || o.status}
          </span>
        </div>
      </div>

      {/* Row 2: Store + Payment */}
      <div className="flex items-center justify-between gap-2 mb-2">
        <span className={`text-[8.5px] font-black px-1.5 py-0.5 rounded-md border truncate max-w-[55%] ${
          isRest 
            ? 'bg-purple-500/15 text-purple-700 dark:text-purple-300 border-purple-500/25' 
            : 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/25'
        }`}>
          {isRest ? `🍽️ ${((o as any).restaurantName || o.shopName || 'Restaurant').toUpperCase()}` : '🛒 FASTKIRANA'}
          {isRest && (isKotPrinted ? ' ✓' : ' ⏳')}
        </span>

        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); onTogglePaymentStatus(o, e) }}
          disabled={updatingPaymentId === o.id}
          className="shrink-0"
        >
          {o.paymentStatus === 'PAID' ? (
            o.paymentMethod === 'COD' ? (
              <span className="text-[8px] font-black uppercase text-amber-700 dark:text-amber-300 bg-amber-500/15 border border-amber-500/30 px-1.5 py-0.5 rounded-full">
                💵 CASH ✅
              </span>
            ) : (
              <span className="text-[8px] font-black uppercase text-emerald-600 dark:text-emerald-400 bg-emerald-500/15 border border-emerald-500/30 px-1.5 py-0.5 rounded-full">
                📱 UPI ✅
              </span>
            )
          ) : (
            <span className="text-[8px] font-black uppercase text-rose-700 dark:text-rose-300 bg-rose-500/15 border border-rose-500/30 px-1.5 py-0.5 rounded-full">
              ⏳ UNPAID
            </span>
          )}
        </button>
      </div>

      {/* Row 3: Action buttons */}
      <div className="flex items-center gap-1.5 flex-wrap" onClick={(e) => e.stopPropagation()}>
        {/* Primary action */}
        {action && (
          <button
            onClick={() => onUpdateOrderStatus(o.id, action.nextStatus)}
            disabled={isUpdating}
            className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all active:scale-95 shadow-xs cursor-pointer ${action.bg}`}
          >
            {isUpdating ? <Loader2 className="h-3 w-3 animate-spin" /> : action.label}
          </button>
        )}

        {/* Reject (only for ADMIN_PENDING) */}
        {o.status === 'ADMIN_PENDING' && (
          <button
            onClick={() => onCancelOrder(o)}
            disabled={isUpdating}
            className="px-2 py-1 text-[9px] font-black rounded-md bg-rose-500/10 text-rose-600 border border-rose-500/30 active:scale-95"
          >
            ✕ Reject
          </button>
        )}

        {/* Verify Cashfree (unpaid only) */}
        {o.paymentStatus !== 'PAID' && (
          <button
            onClick={(e) => onSyncCashfreePayment(o, e)}
            disabled={syncingOrderId === o.id}
            className="px-2 py-1 text-[9px] font-black rounded-md bg-blue-500/15 text-blue-700 dark:text-blue-300 border border-blue-500/30 active:scale-95"
          >
            {syncingOrderId === o.id ? <Loader2 className="h-3 w-3 animate-spin inline" /> : '⚡ Verify'}
          </button>
        )}

        {/* View */}
        <button
          onClick={() => onOpenOrderModal(o)}
          className="px-2 py-1 text-[9px] font-black rounded-md bg-rose-500/10 text-rose-600 border border-rose-500/20 active:scale-95"
        >
          👁️ View
        </button>

        {/* KOT (restaurant only) */}
        {isRest && (
          <button
            disabled={isSending}
            onClick={() => onSendKOT(o)}
            className={`px-2 py-1 text-[9px] font-black rounded-md border active:scale-95 ${
              isSending ? 'bg-amber-500/15 text-amber-700 border-amber-500/30 animate-pulse'
                : isKotPrinted ? 'bg-emerald-500/15 text-emerald-700 border-emerald-500/30'
                : 'bg-orange-500/10 text-orange-600 border-orange-500/25'
            }`}
          >
            {isSending ? '⏳' : isKotPrinted ? '🖨️✓' : '🖨️ KOT'}
          </button>
        )}
      </div>
    </div>
  )
}
