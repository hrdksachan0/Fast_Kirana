import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { IndianRupee, CheckCircle2, Split } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface CodPaymentModalProps {
  order: any
  onClose: () => void
  onSelectCash: (orderId: string) => void
  onSelectOnline: (orderId: string) => void
  onSelectCustomCash?: (orderId: string, cashAmount: number) => void
}

export default function CodPaymentModal({
  order,
  onClose,
  onSelectCash,
  onSelectOnline,
  onSelectCustomCash,
}: CodPaymentModalProps) {
  const [showSplitInput, setShowSplitInput] = useState(false)
  const [cashAmountInput, setCashAmountInput] = useState('')

  if (!order) return null

  const orderTotal = (order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0)
  const displayId = order.readableId || order.id.slice(0, 8)

  const parsedCash = parseFloat(cashAmountInput) || 0
  const onlineBalance = Math.max(0, orderTotal - parsedCash)

  const handleConfirmSplit = () => {
    if (onSelectCustomCash) {
      onSelectCustomCash(order.id, parsedCash)
    } else {
      onSelectCash(order.id)
    }
  }

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
      >
        <motion.div
          initial={{ scale: 0.95, y: 15 }}
          animate={{ scale: 1, y: 0 }}
          exit={{ scale: 0.95, y: 15 }}
          className="bg-card w-full max-w-sm rounded-3xl border border-border p-5 sm:p-6 shadow-2xl space-y-4"
        >
          <div className="text-center space-y-1.5">
            <div className="mx-auto h-12 w-12 rounded-2xl bg-gradient-to-br from-emerald-400 to-teal-600 text-white flex items-center justify-center shadow-md shadow-emerald-500/20">
              <IndianRupee className="h-6 w-6 stroke-[2.5]" />
            </div>
            <h3 className="text-lg font-black text-text-primary tracking-tight">Payment Collection</h3>
            <p className="text-xs text-text-secondary font-medium">
              Order <span className="font-mono font-black text-text-primary">#{displayId}</span> • Total to Collect:{' '}
              <span className="font-black text-text-primary text-sm">{formatPrice(orderTotal)}</span>
            </p>
          </div>

          {!showSplitInput ? (
            <div className="grid grid-cols-1 gap-3 pt-1">
              {/* Option 1: Cash Collected */}
              <button
                type="button"
                onClick={() => onSelectCash(order.id)}
                className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10 hover:border-amber-500/50 transition-all text-left cursor-pointer active:scale-98 shadow-xs group"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="h-11 w-11 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-2xl shrink-0">
                    💵
                  </div>
                  <div className="min-w-0">
                    <p className="text-amber-700 dark:text-amber-300 font-black text-xs">
                      100% Cash Collected (पूरा नकद मिला)
                    </p>
                    <p className="text-[10px] text-text-muted mt-0.5 font-semibold">
                      Full {formatPrice(orderTotal)} collected in cash
                    </p>
                  </div>
                </div>
                <span className="px-2.5 py-1 rounded-lg bg-amber-500/20 text-amber-700 dark:text-amber-300 text-[10px] font-black shrink-0">
                  Cash
                </span>
              </button>

              {/* Option 2: Online Payment Received */}
              <button
                type="button"
                onClick={() => onSelectOnline(order.id)}
                className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-emerald-500/30 bg-emerald-500/5 hover:bg-emerald-500/10 hover:border-emerald-500/50 transition-all text-left cursor-pointer active:scale-98 shadow-xs group"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="h-11 w-11 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-2xl shrink-0">
                    📱
                  </div>
                  <div className="min-w-0">
                    <p className="text-emerald-700 dark:text-emerald-300 font-black text-xs">
                      100% Online Received (पूरा ऑनलाइन मिला)
                    </p>
                    <p className="text-[10px] text-text-muted mt-0.5 font-semibold">
                      Full {formatPrice(orderTotal)} paid via UPI QR / Bank
                    </p>
                  </div>
                </div>
                <span className="px-2.5 py-1 rounded-lg bg-emerald-500 text-white text-[10px] font-black shrink-0 flex items-center gap-1 shadow-xs">
                  <CheckCircle2 className="h-3 w-3" />
                  UPI
                </span>
              </button>

              {/* Option 3: Split Payment */}
              <button
                type="button"
                onClick={() => setShowSplitInput(true)}
                className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-purple-500/30 bg-purple-500/5 hover:bg-purple-500/10 hover:border-purple-500/50 transition-all text-left cursor-pointer active:scale-98 shadow-xs group"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="h-11 w-11 rounded-xl bg-purple-500/15 border border-purple-500/30 flex items-center justify-center text-2xl shrink-0">
                    💸
                  </div>
                  <div className="min-w-0">
                    <p className="text-purple-700 dark:text-purple-300 font-black text-xs">
                      Partial / Split (कुछ कैश + कुछ ऑनलाइन)
                    </p>
                    <p className="text-[10px] text-text-muted mt-0.5 font-semibold">
                      Enter exact cash amount collected
                    </p>
                  </div>
                </div>
                <span className="px-2.5 py-1 rounded-lg bg-purple-500/20 text-purple-700 dark:text-purple-300 text-[10px] font-black shrink-0 flex items-center gap-1">
                  <Split className="h-3 w-3" />
                  Split
                </span>
              </button>
            </div>
          ) : (
            <div className="space-y-3.5 pt-1">
              <div className="p-3.5 rounded-2xl bg-purple-500/10 border border-purple-500/20 space-y-2">
                <label className="text-[11px] font-black uppercase text-purple-700 dark:text-purple-300 block">
                  Amount Collected in Cash (₹):
                </label>
                <input
                  type="number"
                  placeholder={`Max ${orderTotal}`}
                  value={cashAmountInput}
                  onChange={(e) => setCashAmountInput(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-background border border-border rounded-xl text-sm font-black outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20"
                />
                <div className="flex justify-between text-[11px] font-bold text-text-secondary pt-1">
                  <span>Cash Handed: <strong className="text-amber-600">{formatPrice(parsedCash)}</strong></span>
                  <span>UPI Balance: <strong className="text-emerald-600">{formatPrice(onlineBalance)}</strong></span>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setShowSplitInput(false)}
                  className="flex-1 py-2.5 rounded-xl border border-border text-xs font-bold text-text-secondary hover:bg-card-hover cursor-pointer"
                >
                  Back
                </button>
                <button
                  type="button"
                  onClick={handleConfirmSplit}
                  className="flex-1 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white text-xs font-black shadow-md cursor-pointer active:scale-95"
                >
                  Confirm Split
                </button>
              </div>
            </div>
          )}

          <button
            type="button"
            onClick={onClose}
            className="w-full text-center text-xs font-bold text-text-muted hover:text-text-primary transition-colors py-2 cursor-pointer"
          >
            Cancel
          </button>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
