'use client'

import React from 'react'
import { motion } from 'framer-motion'
import {
  Printer,
  CheckCircle,
  Clock,
  Barcode,
  UtensilsCrossed,
  Check,
  RotateCcw,
} from 'lucide-react'

export interface OrderItem {
  id: string
  productId: string
  name: string
  price: number
  quantity: number
  imageUrl?: string
  product?: {
    slug: string
  }
  selectedVariant?: string | null
  notes?: string | null
}

export interface Order {
  id: string
  readableId?: number
  status: string
  total: number
  deliveryFee: number
  taxes: number
  miscFee: number
  discount: number
  createdAt: string | Date
  paymentMethod: string
  deliveryMethod: string
  user: {
    name: string
    phone: string | null
  }
  address: {
    houseNo: string
    street: string
    area: string
    city: string
    pincode: string
  }
  items: OrderItem[]
  shopName?: string | null
  restaurantId?: string | null
}

interface KdsActivePrepViewProps {
  activeOrder: Order
  pickedItemIds: Record<string, number>
  setActiveOrder: (order: Order | null) => void
  setPickedItemIds: React.Dispatch<React.SetStateAction<Record<string, number>>>
  printKOTReceipt: (order: Order) => void
  autoPackOrder: (orderId: string) => void
  scanInput: string
  setScanInput: (val: string) => void
  scanInputRef: React.RefObject<HTMLInputElement | null>
  handleScanSubmit: (e: React.FormEvent) => void
  handleManualPrepareOne: (itemId: string, maxQty: number) => void
  handleManualPrepareAll: (itemId: string, qty: number) => void
  handleResetItem: (itemId: string) => void
  formatElapsed: (createdAt: string | Date) => string
  getItemEmoji: (idx: number) => string
}

export function KdsActivePrepView({
  activeOrder,
  pickedItemIds,
  setActiveOrder,
  setPickedItemIds,
  printKOTReceipt,
  autoPackOrder,
  scanInput,
  setScanInput,
  scanInputRef,
  handleScanSubmit,
  handleManualPrepareOne,
  handleManualPrepareAll,
  handleResetItem,
  formatElapsed,
  getItemEmoji,
}: KdsActivePrepViewProps) {
  const toPickItems = activeOrder.items.filter(
    (item) => (pickedItemIds[item.id] || 0) < item.quantity
  )
  const pickedItems = activeOrder.items.filter(
    (item) => (pickedItemIds[item.id] || 0) === item.quantity
  )

  const totalQty = activeOrder.items.reduce((s, i) => s + i.quantity, 0)
  const preparedQty = activeOrder.items.reduce((s, i) => s + (pickedItemIds[i.id] || 0), 0)
  const progressPercent = totalQty > 0 ? Math.round((preparedQty / totalQty) * 100) : 0
  const circumference = 2 * Math.PI * 42
  const strokeDashoffset = circumference - (progressPercent / 100) * circumference

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="max-w-xl mx-auto space-y-6 pb-20"
    >
      {/* Active Prep Header */}
      <div className="relative overflow-hidden bg-gradient-to-r from-red-700 to-amber-700 p-5 rounded-3xl shadow-lg text-white">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                setActiveOrder(null)
                setPickedItemIds({})
              }}
              className="flex items-center gap-1.5 text-xs font-black text-white/95 hover:text-white bg-white/10 hover:bg-white/20 px-3.5 py-2 rounded-xl transition-all cursor-pointer"
            >
              ← Back
            </button>
            <button
              onClick={() => printKOTReceipt(activeOrder)}
              className="flex items-center gap-1.5 text-xs font-black bg-white text-red-700 hover:bg-zinc-100 px-3.5 py-2 rounded-xl transition-all cursor-pointer shadow-sm"
            >
              <Printer className="h-3.5 w-3.5 text-red-600" /> Print KOT
            </button>
            <button
              onClick={() => {
                const updated: Record<string, number> = {}
                activeOrder.items.forEach((item) => {
                  updated[item.id] = item.quantity
                })
                setPickedItemIds(updated)
                autoPackOrder(activeOrder.id)
              }}
              className="flex items-center gap-1.5 text-xs font-black bg-emerald-600 hover:bg-emerald-700 text-white px-3.5 py-2 rounded-xl transition-all cursor-pointer shadow-sm active:scale-95 border border-emerald-500/20"
            >
              <CheckCircle className="h-3.5 w-3.5" /> Mark Ready (Pack All)
            </button>
          </div>
          <div className="text-right">
            <p className="text-[10px] text-white/70 font-semibold uppercase tracking-wider">
              PREPARING RESTAURANT TICKET
            </p>
            <p className="text-xs font-mono font-bold">{activeOrder.id.slice(0, 12)}</p>
          </div>
        </div>
      </div>

      {/* Circle Progress */}
      <div className="bg-card border border-border/55 rounded-3xl p-5 flex items-center gap-6 shadow-sm">
        <div className="relative flex-shrink-0">
          <svg width="90" height="90" viewBox="0 0 96 96" className="-rotate-90">
            <circle
              cx="48"
              cy="48"
              r="42"
              fill="none"
              stroke="currentColor"
              className="text-border/40"
              strokeWidth="6"
            />
            <motion.circle
              cx="48"
              cy="48"
              r="42"
              fill="none"
              stroke="#dc2626"
              strokeWidth="6"
              strokeLinecap="round"
              strokeDasharray={circumference}
              initial={{ strokeDashoffset: circumference }}
              animate={{ strokeDashoffset }}
              transition={{ duration: 0.6, ease: 'easeOut' }}
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-lg font-black text-text-primary">{progressPercent}%</span>
            <span className="text-[9px] font-semibold text-text-muted">cooked</span>
          </div>
        </div>

        <div className="flex-1 space-y-2">
          <div>
            <p className="text-[10px] text-text-muted font-semibold uppercase">Customer</p>
            <p className="text-sm font-black text-text-primary truncate">{activeOrder.user.name}</p>
          </div>
          <div className="flex items-center gap-4">
            <div>
              <p className="text-[10px] text-text-muted font-semibold">Elapsed</p>
              <p className="text-xs font-bold text-red-500 flex items-center gap-1">
                <Clock className="h-3.5 w-3.5" />
                {formatElapsed(activeOrder.createdAt)}
              </p>
            </div>
            <div>
              <p className="text-[10px] text-text-muted font-semibold">Items cooked</p>
              <p className="text-xs font-bold text-text-primary">
                {preparedQty}/{totalQty}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Scan Barcode Form */}
      <div className="bg-card border border-border/55 p-5 rounded-3xl shadow-sm space-y-3">
        <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
          <Barcode className="h-4 w-4 text-red-500" />
          Kitchen Item Scanner
        </label>
        <form onSubmit={handleScanSubmit} className="flex gap-2">
          <input
            ref={scanInputRef}
            type="text"
            placeholder="Type product name (e.g. paneer, butter naan)"
            value={scanInput}
            onChange={(e) => setScanInput(e.target.value)}
            className="flex-1 bg-muted/40 border border-border px-4 py-2.5 rounded-xl text-xs focus:outline-none focus:border-red-400 font-semibold"
          />
          <button
            type="submit"
            className="bg-red-600 hover:bg-red-700 text-white text-xs font-bold px-4 py-2 rounded-xl transition-all cursor-pointer shadow-md"
          >
            Prepare
          </button>
        </form>
      </div>

      {/* Items Checklist */}
      <div className="space-y-3">
        <h3 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
          <UtensilsCrossed className="h-4 w-4 text-red-500" />
          Dishes to Cook ({toPickItems.length})
        </h3>

        <div className="space-y-3">
          {toPickItems.map((item, idx) => {
            const picked = pickedItemIds[item.id] || 0
            return (
              <div
                key={item.id}
                className="bg-card border border-border/50 rounded-2xl p-4 flex items-center justify-between gap-4"
              >
                <div className="flex items-center gap-3">
                  <span className="text-xl shrink-0">{getItemEmoji(idx)}</span>
                  <div>
                    <h4 className="text-xs font-extrabold text-text-primary">{item.name}</h4>
                    {item.notes && (
                      <p className="text-[10px] text-amber-500 font-black mt-0.5">
                        📝 Notes: {item.notes}
                      </p>
                    )}
                    <p className="text-[10px] text-text-secondary font-bold mt-0.5">
                      Target: {item.quantity} | Cooked:{' '}
                      <span className="text-red-500 font-black">{picked}</span>
                    </p>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleManualPrepareOne(item.id, item.quantity)}
                    className="bg-muted hover:bg-muted-hover text-text-secondary text-xs font-bold py-2 px-3.5 rounded-xl border cursor-pointer transition-all active:scale-95"
                  >
                    +1
                  </button>
                  <button
                    onClick={() => handleManualPrepareAll(item.id, item.quantity)}
                    className="bg-red-500/10 text-red-600 hover:bg-red-500/20 text-xs font-black py-2 px-4 rounded-xl border border-red-500/20 cursor-pointer transition-all active:scale-95 flex items-center gap-1"
                  >
                    <Check className="h-3.5 w-3.5 stroke-[3]" />
                    Ready
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Cooked Items */}
      {pickedItems.length > 0 && (
        <div className="space-y-3 opacity-60">
          <h3 className="text-xs font-black text-text-secondary uppercase tracking-wider">
            Completed Dishes ({pickedItems.length})
          </h3>
          <div className="space-y-2">
            {pickedItems.map((item) => (
              <div
                key={item.id}
                className="bg-muted/30 border border-border/40 rounded-2xl p-3 flex justify-between items-center"
              >
                <div className="flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-emerald-500" />
                  <span className="text-xs font-bold text-text-secondary line-through">
                    {item.name}
                  </span>
                </div>
                <button
                  onClick={() => handleResetItem(item.id)}
                  className="p-1 text-text-muted hover:text-text-primary rounded"
                >
                  <RotateCcw className="h-3.5 w-3.5" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </motion.div>
  )
}
