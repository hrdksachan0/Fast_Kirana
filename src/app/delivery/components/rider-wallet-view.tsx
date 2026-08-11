'use client'

import { motion } from 'framer-motion'
import { formatPrice } from '@/lib/utils'

interface RiderWalletViewProps {
  walletInfo: {
    cashInHand: number
    cashLimit: number
    totalCollected: number
    totalDeposited: number
    isLocked: boolean
    isWarning: boolean
    remainingLimit: number
  } | null
  todayCodCollected: number
  todayDeliveries: number
}

export default function RiderWalletView({
  walletInfo,
  todayCodCollected,
  todayDeliveries,
}: RiderWalletViewProps) {
  if (!walletInfo) return null

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-4 pt-1"
    >
      {/* Wallet Cash Summary Card */}
      <div className={`p-5 rounded-3xl border shadow-lg space-y-4 transition-all ${
        walletInfo.isLocked
          ? 'bg-gradient-to-br from-rose-950 to-slate-950 border-rose-500/50 text-rose-200'
          : walletInfo.isWarning
          ? 'bg-gradient-to-br from-amber-950 to-slate-950 border-amber-500/50 text-amber-200'
          : 'bg-gradient-to-br from-slate-900 to-slate-950 border-slate-800 text-slate-200'
      }`}>
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[10px] font-black uppercase tracking-wider text-amber-400 block mb-1">
              💵 Cash in Hand (जेब में नकद)
            </span>
            <span className="text-3xl font-black text-white">{formatPrice(walletInfo.cashInHand)}</span>
          </div>
          <div className="text-right">
            <span className="text-[10px] font-bold text-slate-400 block">Maximum Limit</span>
            <span className="text-sm font-black text-white/90">{formatPrice(walletInfo.cashLimit)}</span>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="space-y-1.5">
          <div className="w-full h-3 bg-black/50 rounded-full overflow-hidden p-0.5 border border-white/10">
            <div
              className={`h-full rounded-full transition-all duration-500 ${
                walletInfo.isLocked
                  ? 'bg-rose-500 shadow-lg shadow-rose-500/50 animate-pulse'
                  : walletInfo.isWarning
                  ? 'bg-amber-400'
                  : 'bg-gradient-to-r from-emerald-500 to-teal-400'
              }`}
              style={{ width: `${Math.min(100, Math.round((walletInfo.cashInHand / walletInfo.cashLimit) * 100))}%` }}
            />
          </div>
          <div className="flex justify-between items-center text-[10px] font-bold text-slate-400">
            <span>Capacity Used</span>
            <span>{Math.round((walletInfo.cashInHand / walletInfo.cashLimit) * 100)}%</span>
          </div>
        </div>

        <div className="p-3 rounded-2xl bg-white/5 border border-white/10 text-xs font-semibold">
          {walletInfo.isLocked ? (
            <span className="text-rose-400 font-bold flex items-center gap-1.5">
              🚨 Limit Reached! Please deposit ₹{walletInfo.cashInHand} at FastKirana store counter to receive new COD orders.
            </span>
          ) : walletInfo.isWarning ? (
            <span className="text-amber-300 font-bold flex items-center gap-1.5">
              ⚠️ Approaching Limit! You can collect up to ₹{walletInfo.remainingLimit} more before deposit required.
            </span>
          ) : (
            <span className="text-emerald-400 font-bold flex items-center gap-1.5">
              ✅ Active & Eligible: Remaining COD capacity is ₹{walletInfo.remainingLimit}.
            </span>
          )}
        </div>
      </div>

      {/* COD Summary Stats */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-card border border-border p-4 rounded-2xl shadow-xs">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block">Today's COD Collected</span>
          <span className="text-xl font-black text-amber-600 dark:text-amber-400 mt-1 block">{formatPrice(todayCodCollected)}</span>
        </div>
        <div className="bg-card border border-border p-4 rounded-2xl shadow-xs">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block">Today's Deliveries</span>
          <span className="text-xl font-black text-emerald-600 dark:text-emerald-400 mt-1 block">{todayDeliveries} Orders</span>
        </div>
      </div>
    </motion.div>
  )
}
