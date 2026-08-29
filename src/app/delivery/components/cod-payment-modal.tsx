import { useState, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { IndianRupee, CheckCircle2, ArrowLeftRight, Wallet, AlertTriangle, ChevronRight } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface CodPaymentModalProps {
  order: any
  onClose: () => void
  onSelectCash: (orderId: string) => void
  onSelectOnline: (orderId: string) => void
  onSelectCustomCash?: (orderId: string, cashAmount: number) => void
  walletInfo?: {
    cashInHand: number
    cashLimit: number
    remainingLimit: number
    isWarning: boolean
    isLocked: boolean
  } | null
}

type ModalStep = 'choose' | 'cash-calc'

export default function CodPaymentModal({
  order,
  onClose,
  onSelectCash,
  onSelectOnline,
  onSelectCustomCash,
  walletInfo,
}: CodPaymentModalProps) {
  const [step, setStep] = useState<ModalStep>('choose')
  const [cashReceivedInput, setCashReceivedInput] = useState('')
  const [hasSplitOnline, setHasSplitOnline] = useState(false)
  const [cashPortionInput, setCashPortionInput] = useState('')

  if (!order) return null

  const orderTotal = (order.total || 0) + (order.companionOrder ? (order.companionOrder.total || 0) : 0)
  const displayId = order.readableId || order.id.slice(0, 8)

  // ── Cash Calculator Logic ──
  const cashReceived = parseFloat(cashReceivedInput) || 0
  const changeToGive = Math.max(0, cashReceived - orderTotal)
  const netCashInHand = hasSplitOnline
    ? (parseFloat(cashPortionInput) || 0)
    : Math.min(cashReceived, orderTotal)
  const onlinePortion = hasSplitOnline
    ? Math.max(0, orderTotal - (parseFloat(cashPortionInput) || 0))
    : 0

  // ── Smart Quick-select Denominations ──
  const quickPresets = useMemo(() => {
    const presets: { label: string; value: number; color: string }[] = []
    // Exact amount
    presets.push({ label: `₹${orderTotal} exact`, value: orderTotal, color: 'amber' })

    // Round up to nearest 10, 50, 100, 500
    const roundUps = [10, 50, 100, 500]
    const seen = new Set<number>([orderTotal])
    for (const r of roundUps) {
      const rounded = Math.ceil(orderTotal / r) * r
      if (!seen.has(rounded) && rounded <= orderTotal + 700) {
        seen.add(rounded)
        presets.push({ label: `₹${rounded}`, value: rounded, color: 'slate' })
      }
    }
    // Common large notes
    for (const note of [500, 1000, 2000]) {
      if (!seen.has(note) && note > orderTotal && note <= orderTotal + 1500) {
        seen.add(note)
        presets.push({ label: `₹${note} note`, value: note, color: 'slate' })
      }
    }
    return presets.slice(0, 6)
  }, [orderTotal])

  // ── Split Quick Presets ──
  const splitPresets = useMemo(() => {
    const presets: { label: string; value: number }[] = []
    const steps = [100, 200, 300, 500]
    for (const s of steps) {
      if (s < orderTotal) {
        presets.push({ label: `₹${s} cash`, value: s })
      }
    }
    return presets.slice(0, 4)
  }, [orderTotal])

  // ── Wallet Limit Check ──
  const wouldExceedLimit = walletInfo
    ? (walletInfo.cashInHand + netCashInHand) > walletInfo.cashLimit
    : false
  const afterCashInHand = walletInfo
    ? walletInfo.cashInHand + netCashInHand
    : null

  // ── Confirm Handler ──
  const handleConfirm = () => {
    if (hasSplitOnline) {
      // Split payment: cash portion goes to rider wallet
      const cashPortion = parseFloat(cashPortionInput) || 0
      if (onSelectCustomCash) {
        onSelectCustomCash(order.id, cashPortion)
      } else {
        onSelectCash(order.id)
      }
    } else {
      // Full cash: net = orderTotal
      onSelectCash(order.id)
    }
  }

  const isConfirmDisabled = step === 'cash-calc' && (
    hasSplitOnline
      ? (parseFloat(cashPortionInput) || 0) <= 0 || (parseFloat(cashPortionInput) || 0) > orderTotal
      : cashReceived <= 0 || cashReceived < orderTotal
  )

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center"
      >
        <motion.div
          initial={{ y: 40, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 40, opacity: 0 }}
          transition={{ type: 'spring', damping: 28, stiffness: 300 }}
          className="bg-card w-full max-w-sm rounded-t-3xl sm:rounded-3xl border border-border p-5 sm:p-6 shadow-2xl space-y-4 max-h-[92vh] overflow-y-auto"
        >
          {/* ── Header ── */}
          <div className="text-center space-y-1.5">
            <div className="mx-auto h-12 w-12 rounded-2xl bg-gradient-to-br from-emerald-400 to-teal-600 text-white flex items-center justify-center shadow-md shadow-emerald-500/20">
              <IndianRupee className="h-6 w-6 stroke-[2.5]" />
            </div>
            <h3 className="text-lg font-black text-text-primary tracking-tight">
              Payment Collection
            </h3>
            <p className="text-xs text-text-secondary font-medium">
              Order <span className="font-mono font-black text-text-primary">#{displayId}</span> • Collect:{' '}
              <span className="font-black text-text-primary text-sm">{formatPrice(orderTotal)}</span>
            </p>
          </div>

          {/* ── Wallet Limit Bar (if available) ── */}
          {walletInfo && step === 'choose' && (
            <div className={`flex items-center gap-2.5 p-3 rounded-2xl text-[11px] font-bold border ${
              walletInfo.isLocked
                ? 'bg-rose-500/10 border-rose-500/30 text-rose-600 dark:text-rose-400'
                : walletInfo.isWarning
                ? 'bg-amber-500/10 border-amber-500/30 text-amber-600 dark:text-amber-400'
                : 'bg-slate-500/5 border-border text-text-secondary'
            }`}>
              <Wallet className="h-4 w-4 shrink-0" />
              <div className="min-w-0">
                <span>Jeb mein: <strong>{formatPrice(walletInfo.cashInHand)}</strong></span>
                <span className="mx-1.5 opacity-40">|</span>
                <span>Limit: <strong>{formatPrice(walletInfo.cashLimit)}</strong></span>
                {walletInfo.isLocked && (
                  <span className="block text-[10px] mt-0.5">🚨 Cash limit full! Pehle deposit karo</span>
                )}
              </div>
            </div>
          )}

          {/* ═══════════════════════════════════════════ */}
          {/* STEP 1: Choose — Cash liya ya Online mila? */}
          {/* ═══════════════════════════════════════════ */}
          {step === 'choose' && (
            <div className="grid grid-cols-1 gap-3 pt-1">
              {/* Option 1: Cash Liya */}
              <button
                type="button"
                onClick={() => {
                  setCashReceivedInput(String(orderTotal))
                  setStep('cash-calc')
                }}
                className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10 hover:border-amber-500/50 transition-all text-left cursor-pointer active:scale-[0.98] shadow-xs group"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="h-12 w-12 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-2xl shrink-0">
                    💵
                  </div>
                  <div className="min-w-0">
                    <p className="text-amber-700 dark:text-amber-300 font-black text-sm">
                      Cash Liya (कैश लिया)
                    </p>
                    <p className="text-[11px] text-text-muted mt-0.5 font-semibold">
                      Customer ne cash diya — poora ya kuch
                    </p>
                  </div>
                </div>
                <ChevronRight className="h-5 w-5 text-amber-500/60 group-hover:text-amber-500 transition-colors shrink-0" />
              </button>

              {/* Option 2: Online Mila */}
              <button
                type="button"
                onClick={() => onSelectOnline(order.id)}
                className="flex items-center justify-between gap-3 w-full p-4 rounded-2xl border-2 border-emerald-500/30 bg-emerald-500/5 hover:bg-emerald-500/10 hover:border-emerald-500/50 transition-all text-left cursor-pointer active:scale-[0.98] shadow-xs group"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="h-12 w-12 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-2xl shrink-0">
                    📱
                  </div>
                  <div className="min-w-0">
                    <p className="text-emerald-700 dark:text-emerald-300 font-black text-sm">
                      Online Mila (ऑनलाइन मिला)
                    </p>
                    <p className="text-[11px] text-text-muted mt-0.5 font-semibold">
                      Poora GPay / PhonePe / UPI se aaya
                    </p>
                  </div>
                </div>
                <span className="px-2.5 py-1 rounded-lg bg-emerald-500 text-white text-[10px] font-black shrink-0 flex items-center gap-1 shadow-xs">
                  <CheckCircle2 className="h-3 w-3" />
                  UPI
                </span>
              </button>
            </div>
          )}

          {/* ═══════════════════════════════════════════ */}
          {/* STEP 2: Cash Calculator                    */}
          {/* ═══════════════════════════════════════════ */}
          {step === 'cash-calc' && (
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              className="space-y-4 pt-1"
            >
              {!hasSplitOnline ? (
                /* ── Full Cash Flow ── */
                <div className="space-y-3">
                  <div className="p-4 rounded-2xl bg-amber-500/8 border border-amber-500/20 space-y-3">
                    <label className="text-[11px] font-black uppercase text-amber-700 dark:text-amber-300 block tracking-wide">
                      Customer ne kitna diya? (₹)
                    </label>
                    <input
                      type="number"
                      inputMode="numeric"
                      placeholder={`e.g. ${orderTotal}, ${Math.ceil(orderTotal / 10) * 10}`}
                      value={cashReceivedInput}
                      onChange={(e) => setCashReceivedInput(e.target.value)}
                      autoFocus
                      className="w-full px-4 py-3.5 bg-background border-2 border-amber-500/30 rounded-xl text-lg font-black outline-none focus:border-amber-500 focus:ring-2 focus:ring-amber-500/20 text-center tabular-nums"
                    />

                    {/* Quick Presets */}
                    <div className="flex flex-wrap gap-1.5">
                      {quickPresets.map((preset) => (
                        <button
                          key={preset.value}
                          type="button"
                          onClick={() => setCashReceivedInput(String(preset.value))}
                          className={`px-3 py-1.5 text-[11px] font-bold rounded-xl border transition-all cursor-pointer active:scale-95 ${
                            cashReceived === preset.value
                              ? 'bg-amber-500 text-white border-amber-500 shadow-md'
                              : 'bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/20 hover:bg-amber-500/20'
                          }`}
                        >
                          {preset.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* ── Calculation Summary ── */}
                  {cashReceived > 0 && (
                    <motion.div
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="p-4 rounded-2xl bg-slate-500/5 border border-border space-y-2"
                    >
                      <div className="flex justify-between items-center text-xs font-bold">
                        <span className="text-text-secondary flex items-center gap-1.5">
                          💵 Cash Received
                        </span>
                        <span className="text-text-primary font-black text-sm">{formatPrice(cashReceived)}</span>
                      </div>
                      {changeToGive > 0 && (
                        <div className="flex justify-between items-center text-xs font-bold">
                          <span className="text-rose-600 dark:text-rose-400 flex items-center gap-1.5">
                            <ArrowLeftRight className="h-3.5 w-3.5" />
                            Change wapas do
                          </span>
                          <span className="text-rose-600 dark:text-rose-400 font-black text-sm">-{formatPrice(changeToGive)}</span>
                        </div>
                      )}
                      <div className="border-t border-border pt-2 flex justify-between items-center text-xs font-bold">
                        <span className="text-amber-700 dark:text-amber-400 flex items-center gap-1.5">
                          💰 Jeb mein rahega (Net Cash)
                        </span>
                        <span className="text-amber-700 dark:text-amber-400 font-black text-sm">{formatPrice(netCashInHand)}</span>
                      </div>

                      {/* Wallet impact */}
                      {afterCashInHand !== null && (
                        <div className={`flex justify-between items-center text-[10px] font-bold pt-1 ${
                          wouldExceedLimit ? 'text-rose-500' : 'text-text-muted'
                        }`}>
                          <span className="flex items-center gap-1">
                            <Wallet className="h-3 w-3" />
                            Wallet after this
                          </span>
                          <span>{formatPrice(afterCashInHand)} / {formatPrice(walletInfo!.cashLimit)}</span>
                        </div>
                      )}
                      {wouldExceedLimit && (
                        <div className="flex items-center gap-1.5 text-[10px] font-bold text-rose-500 bg-rose-500/10 p-2 rounded-xl border border-rose-500/20">
                          <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
                          <span>⚠️ Limit cross ho jayegi! Online lena better hai</span>
                        </div>
                      )}
                    </motion.div>
                  )}

                  {/* ── Split Toggle ── */}
                  <button
                    type="button"
                    onClick={() => {
                      setHasSplitOnline(true)
                      setCashPortionInput('')
                    }}
                    className="w-full text-center text-[11px] font-bold text-purple-600 dark:text-purple-400 hover:text-purple-700 transition-colors py-2 cursor-pointer flex items-center justify-center gap-1.5"
                  >
                    <ArrowLeftRight className="h-3.5 w-3.5" />
                    Kuch cash + kuch online mila? (Split)
                  </button>
                </div>
              ) : (
                /* ── Split Flow ── */
                <div className="space-y-3">
                  <div className="p-4 rounded-2xl bg-purple-500/8 border border-purple-500/20 space-y-3">
                    <label className="text-[11px] font-black uppercase text-purple-700 dark:text-purple-300 block tracking-wide">
                      Cash mein kitna liya? (₹)
                    </label>
                    <input
                      type="number"
                      inputMode="numeric"
                      placeholder="e.g. 200, 300"
                      value={cashPortionInput}
                      onChange={(e) => setCashPortionInput(e.target.value)}
                      autoFocus
                      className="w-full px-4 py-3.5 bg-background border-2 border-purple-500/30 rounded-xl text-lg font-black outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 text-center tabular-nums"
                    />

                    {/* Split Quick Presets */}
                    <div className="flex flex-wrap gap-1.5">
                      {splitPresets.map((preset) => (
                        <button
                          key={preset.value}
                          type="button"
                          onClick={() => setCashPortionInput(String(preset.value))}
                          className={`px-3 py-1.5 text-[11px] font-bold rounded-xl border transition-all cursor-pointer active:scale-95 ${
                            (parseFloat(cashPortionInput) || 0) === preset.value
                              ? 'bg-purple-500 text-white border-purple-500 shadow-md'
                              : 'bg-purple-500/10 text-purple-700 dark:text-purple-300 border-purple-500/20 hover:bg-purple-500/20'
                          }`}
                        >
                          {preset.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* ── Split Summary ── */}
                  {(parseFloat(cashPortionInput) || 0) > 0 && (
                    <motion.div
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="p-4 rounded-2xl bg-slate-500/5 border border-border space-y-2"
                    >
                      <div className="flex justify-between items-center text-xs font-bold">
                        <span className="text-amber-600 dark:text-amber-400 flex items-center gap-1.5">
                          💵 Cash Collected
                        </span>
                        <span className="text-amber-600 dark:text-amber-400 font-black text-sm">{formatPrice(parseFloat(cashPortionInput) || 0)}</span>
                      </div>
                      <div className="flex justify-between items-center text-xs font-bold">
                        <span className="text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5">
                          📱 Online Received
                        </span>
                        <span className="text-emerald-600 dark:text-emerald-400 font-black text-sm">{formatPrice(onlinePortion)}</span>
                      </div>
                      <div className="border-t border-border pt-2 flex justify-between items-center text-xs font-bold">
                        <span className="text-text-primary">
                          Total
                        </span>
                        <span className="text-text-primary font-black text-sm">
                          {formatPrice((parseFloat(cashPortionInput) || 0) + onlinePortion)}
                          {(parseFloat(cashPortionInput) || 0) + onlinePortion !== orderTotal && (
                            <span className="text-rose-500 text-[10px] ml-1">
                              (≠ {formatPrice(orderTotal)})
                            </span>
                          )}
                        </span>
                      </div>

                      {/* Wallet impact */}
                      {walletInfo && (
                        <div className={`flex justify-between items-center text-[10px] font-bold pt-1 ${
                          (walletInfo.cashInHand + (parseFloat(cashPortionInput) || 0)) > walletInfo.cashLimit ? 'text-rose-500' : 'text-text-muted'
                        }`}>
                          <span className="flex items-center gap-1">
                            <Wallet className="h-3 w-3" />
                            Wallet after this
                          </span>
                          <span>{formatPrice(walletInfo.cashInHand + (parseFloat(cashPortionInput) || 0))} / {formatPrice(walletInfo.cashLimit)}</span>
                        </div>
                      )}
                    </motion.div>
                  )}

                  {/* Back to full cash */}
                  <button
                    type="button"
                    onClick={() => {
                      setHasSplitOnline(false)
                      setCashPortionInput('')
                    }}
                    className="w-full text-center text-[11px] font-bold text-text-muted hover:text-text-primary transition-colors py-1 cursor-pointer"
                  >
                    ← Poora cash mein liya (no split)
                  </button>
                </div>
              )}

              {/* ── Action Buttons ── */}
              <div className="flex items-center gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => {
                    setStep('choose')
                    setHasSplitOnline(false)
                    setCashReceivedInput('')
                    setCashPortionInput('')
                  }}
                  className="flex-1 py-3 rounded-xl border border-border text-xs font-bold text-text-secondary hover:bg-card-hover cursor-pointer"
                >
                  ← Back
                </button>
                <button
                  type="button"
                  onClick={handleConfirm}
                  disabled={isConfirmDisabled}
                  className="flex-[2] py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 disabled:opacity-40 disabled:cursor-not-allowed text-white text-xs font-black shadow-lg shadow-emerald-600/25 cursor-pointer active:scale-[0.97] transition-all flex items-center justify-center gap-1.5"
                >
                  <CheckCircle2 className="h-4 w-4" />
                  Confirm ✅
                </button>
              </div>
            </motion.div>
          )}

          {/* ── Cancel ── */}
          {step === 'choose' && (
            <button
              type="button"
              onClick={onClose}
              className="w-full text-center text-xs font-bold text-text-muted hover:text-text-primary transition-colors py-2 cursor-pointer"
            >
              Cancel
            </button>
          )}
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
