'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Smartphone,
  Clock,
  RefreshCw,
  ShoppingBag,
  Sparkles,
  User,
  Zap,
  ChevronRight,
  Tag,
} from 'lucide-react'
import { toast } from 'sonner'
import { formatOrderTime } from '@/lib/date-helpers'
import { PickerStatsCards } from '@/components/picker/picker-stats-cards'
import { Order, getSlaClass, timeAgo } from '@/hooks/picker/use-picker-types'
import { PickerPriceManagerModal } from './picker-price-manager-modal'

interface PickerQueueListProps {
  orders: Order[]
  currentTime: Date
  refreshProgress: number
  isRefreshing: boolean
  fetchOrders: (silent?: boolean) => Promise<void>
  pickedToday: number
  selectedOrderIds: string[]
  setSelectedOrderIds: (ids: string[]) => void
  userName?: string | null
  userId?: string | null
  handleStartPicking: (order: Order) => Promise<void>
  setActiveOrder: (order: Order | null) => void
  setPickedItemIds: React.Dispatch<React.SetStateAction<Record<string, number>>>
  updatingId: string | null
}

export function PickerQueueList({
  orders,
  currentTime,
  refreshProgress,
  isRefreshing,
  fetchOrders,
  pickedToday,
  selectedOrderIds,
  setSelectedOrderIds,
  userName,
  userId,
  handleStartPicking,
  setActiveOrder,
  setPickedItemIds,
  updatingId,
}: PickerQueueListProps) {
  const [isPricingModalOpen, setIsPricingModalOpen] = useState(false)
  const totalItemsToPick = orders.reduce((sum, ord) => {
    return sum + ord.items.reduce((s, itm) => s + itm.quantity, 0)
  }, 0)

  return (
    <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-6 max-w-lg space-y-4 sm:space-y-5 pb-24">
      {/* Picker Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 p-4 sm:p-5 text-white shadow-lg shadow-blue-500/20"
      >
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmZmZmYiIGZpbGwtb3BhY2l0eT0iMC4wNCI+PHBhdGggZD0iTTM2IDM0djZoNnYtNmgtNnptMC0xMHY2aDZ2LTZoLTZ6bTEwIDEwdjZoNnYtNmgtNnptLTIwIDB2Nmg2di02aC02em0xMC0xMHY2aDZ2LTZoLTZ6bS0xMCAwdjZoNnYtNmgtNnoiLz48L2c+PC9nPjwvc3ZnPg==')] opacity-50" />

        <div className="relative flex justify-between items-start">
          <div className="flex items-center gap-3">
            <div className="h-11 w-11 rounded-full bg-white/20 backdrop-blur-sm border border-white/30 flex items-center justify-center animate-pulse-gentle">
              <Smartphone className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm sm:text-base font-black tracking-tight">Picker Console</h1>
              <p className="text-[10px] sm:text-xs text-white/70 mt-0.5 font-medium">
                {userName || 'Picker'}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setIsPricingModalOpen(true)}
              className="h-10 px-3 sm:h-9 flex items-center gap-1.5 rounded-xl bg-white/20 hover:bg-white/30 backdrop-blur-sm border border-white/25 text-white text-xs font-black transition-all cursor-pointer shadow-sm"
              title="Edit Grocery Pricing & Catalog"
            >
              <Tag className="h-4 w-4" />
              <span className="hidden xs:inline">Pricing</span>
            </button>
            <div className="hidden sm:flex items-center gap-1 bg-white/10 backdrop-blur-sm rounded-lg px-2.5 py-1.5 border border-white/10">
              <Clock className="h-3 w-3 text-white/70" />
              <span className="text-[10px] font-mono font-bold text-white/90">
                {formatOrderTime(currentTime)}
              </span>
            </div>
            <button
              onClick={() => fetchOrders(true)}
              disabled={isRefreshing}
              className="h-10 w-10 sm:h-9 sm:w-9 flex items-center justify-center rounded-xl bg-white/15 backdrop-blur-sm border border-white/20 hover:bg-white/25 transition-all disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw className={`h-4 w-4 text-white ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        <div className="relative mt-3 h-0.5 bg-white/10 rounded-full overflow-hidden">
          <motion.div
            className="absolute inset-y-0 left-0 bg-white/40 rounded-full"
            animate={{ width: `${refreshProgress}%` }}
            transition={{ duration: 0.5, ease: 'linear' }}
          />
        </div>
      </motion.div>

      <PickerStatsCards
        queueCount={orders.length}
        totalItemsToPick={totalItemsToPick}
        pickedToday={pickedToday}
      />

      {/* Orders Queue Section */}
      <div className="space-y-3">
        <h2 className="text-xs font-black text-gray-700 uppercase tracking-wider flex items-center gap-1.5 px-1">
          <ShoppingBag className="h-4 w-4 text-blue-500" />
          Orders to Pick
        </h2>

        <AnimatePresence mode="popLayout">
          {orders.length === 0 ? (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0 }}
              className="bg-white border-2 border-dashed border-gray-200 p-8 sm:p-10 rounded-2xl text-center"
            >
              <Sparkles className="h-8 w-8 text-gray-300 mx-auto mb-3" />
              <p className="text-xs font-bold text-gray-400">All caught up! No orders pending.</p>
            </motion.div>
          ) : (
            orders.map((order) => {
              const isClaimedByOther = !!(
                order.status === 'CONFIRMED' &&
                order.assignedPickerId &&
                order.assignedPickerId !== userId
              )
              return (
                <motion.div
                  key={order.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, x: -50, scale: 0.95 }}
                  className="relative overflow-hidden bg-white border border-gray-200/80 rounded-2xl shadow-sm hover:shadow-md transition-shadow"
                >
                  <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-blue-500 to-indigo-600" />

                  <div className="p-4 sm:p-5 space-y-3 pl-5">
                    <div className="flex justify-between items-start">
                      <div className="flex items-center gap-2.5 min-w-0">
                        <input
                          type="checkbox"
                          checked={selectedOrderIds.includes(order.id)}
                          disabled={isClaimedByOther}
                          onChange={(e) => {
                            if (e.target.checked) {
                              if (selectedOrderIds.length >= 3) {
                                toast.error('Maximum of 3 orders can be picked together')
                                return
                              }
                              setSelectedOrderIds([...selectedOrderIds, order.id])
                            } else {
                              setSelectedOrderIds(
                                selectedOrderIds.filter((id) => id !== order.id)
                              )
                            }
                          }}
                          className="h-4.5 w-4.5 text-blue-600 border-gray-300 rounded focus:ring-blue-500 cursor-pointer shrink-0 disabled:opacity-40 disabled:cursor-not-allowed"
                        />
                        <div className="min-w-0">
                          <div className="flex items-center gap-1.5">
                            <User className="h-3.5 w-3.5 text-gray-400 shrink-0" />
                            <h3 className="text-sm font-extrabold text-gray-800 truncate">
                              {order.user.name}
                            </h3>
                          </div>
                          {(order.user.phone || order.address?.phone) && (
                            <div className="flex items-center gap-1.5 mt-0.5 text-xs text-gray-500">
                              <Smartphone className="h-3.5 w-3.5 text-gray-400 shrink-0" />
                              <a
                                href={`tel:${order.address?.phone || order.user.phone}`}
                                className="hover:underline font-mono font-bold"
                              >
                                {order.address?.phone || order.user.phone}
                              </a>
                            </div>
                          )}
                          <div className="flex items-center gap-2 mt-1">
                            <span className="text-[9px] font-mono font-bold text-gray-400">
                              #{order.readableId || order.id.slice(0, 8)}
                            </span>
                            {order.companionOrder && (
                              <span className="bg-rose-100 text-rose-600 text-[8px] px-1.5 py-0.5 rounded-full font-black uppercase">
                                ☕ cafe
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      <div className="flex flex-col items-end gap-1">
                        {isClaimedByOther ? (
                          <span className="bg-rose-50 text-rose-600 border border-rose-200 text-[9px] px-2 py-0.5 rounded-full font-black uppercase">
                            👤 Claimed by {order.assignedPicker?.name || 'Another Picker'}
                          </span>
                        ) : order.status === 'CONFIRMED' ? (
                          <span className="bg-amber-50 text-amber-600 border border-amber-200 text-[9px] px-2 py-0.5 rounded-full font-black uppercase">
                            👤 Claimed by Me
                          </span>
                        ) : (
                          <span className="bg-blue-50 text-blue-600 border border-blue-200 text-[9px] px-2 py-0.5 rounded-full font-black uppercase">
                            Ready
                          </span>
                        )}
                        <span
                          className={`text-[9px] flex items-center gap-0.5 ${getSlaClass(
                            order.createdAt,
                            order.status
                          )}`}
                        >
                          <Clock className="h-2.5 w-2.5" />
                          {timeAgo(order.createdAt)}
                        </span>
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <div className="bg-gray-50/80 rounded-xl border border-gray-100 overflow-hidden">
                        {order.items.map((item, i) => (
                          <div
                            key={item.id}
                            className={`flex justify-between items-center text-[11px] font-semibold text-gray-700 px-3 py-1.5 ${
                              i % 2 === 1 ? 'bg-gray-100/50' : ''
                            } ${
                              i !== order.items.length - 1 ? 'border-b border-gray-100/80' : ''
                            }`}
                          >
                            <span className="truncate mr-2">{item.name}</span>
                            <span className="text-gray-400 font-bold shrink-0">
                              ×{item.quantity}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="flex justify-between items-center pt-2.5 border-t border-gray-100">
                      <div>
                        <span className="text-[9px] font-bold text-gray-400 block uppercase tracking-wider">
                          Payment
                        </span>
                        <span className="text-xs font-extrabold text-gray-700">
                          {order.paymentMethod === 'COD' ? 'COD (Cash)' : 'Prepaid ✓'}
                        </span>
                      </div>

                      <motion.button
                        whileTap={!isClaimedByOther ? { scale: 0.95 } : {}}
                        onClick={() => {
                          if (isClaimedByOther) return
                          if (order.status === 'CONFIRMED') {
                            setActiveOrder(order)
                            const initialPicked: Record<string, number> = {}
                            order.items.forEach((item) => {
                              initialPicked[item.id] = 0
                            })
                            setPickedItemIds(initialPicked)
                          } else {
                            handleStartPicking(order)
                          }
                        }}
                        disabled={updatingId === order.id || isClaimedByOther}
                        className={`flex items-center gap-1.5 px-4 py-2.5 text-xs font-extrabold rounded-xl transition-all shadow-md min-h-[44px] cursor-pointer ${
                          isClaimedByOther
                            ? 'bg-slate-100 text-slate-400 border border-slate-200 cursor-not-allowed shadow-none'
                            : 'bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white shadow-blue-500/20'
                        }`}
                      >
                        <Zap className="h-3.5 w-3.5" />
                        <span>
                          {isClaimedByOther
                            ? 'Claimed'
                            : order.status === 'CONFIRMED'
                            ? 'Continue'
                            : 'Start'}
                        </span>
                        <ChevronRight className="h-3.5 w-3.5" />
                      </motion.button>
                    </div>
                  </div>
                </motion.div>
              )
            })
          )}
        </AnimatePresence>
      </div>

      {/* Dark Store Catalog & Price Manager Modal */}
      <PickerPriceManagerModal
        isOpen={isPricingModalOpen}
        onClose={() => setIsPricingModalOpen(false)}
      />
    </div>
  )
}
