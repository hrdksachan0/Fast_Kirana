'use client'

import { motion } from 'framer-motion'
import { formatPrice } from '@/lib/utils'
import { Store, AlertTriangle, ShieldAlert, CheckCircle2 } from 'lucide-react'
import { useEffect, useState } from 'react'

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
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!walletInfo) return null

  const capacityPercent = Math.min(100, Math.max(0, Math.round((walletInfo.cashInHand / walletInfo.cashLimit) * 100)))
  const circumference = 2 * Math.PI * 52 // r=52
  const strokeDashoffset = circumference - (capacityPercent / 100) * circumference

  const ringColor = walletInfo.isLocked
    ? 'text-rose-500'
    : walletInfo.isWarning
    ? 'text-amber-500'
    : 'text-emerald-500'

  const containerVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: { staggerChildren: 0.1 }
    }
  }

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0, transition: { type: 'spring' as const, stiffness: 300, damping: 24 } }
  } as const

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="show"
      className="space-y-5 pt-1"
    >
      {/* Hero Wallet Card */}
      <motion.div variants={itemVariants} className="relative overflow-hidden rounded-3xl bg-slate-950 p-6 shadow-2xl border border-white/[0.06]">
        {/* Decorative Orbs */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 w-48 h-48 rounded-full bg-emerald-500/10 blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 -ml-16 -mb-16 w-48 h-48 rounded-full bg-teal-500/10 blur-3xl pointer-events-none" />
        
        {/* Main Content */}
        <div className="relative z-10 flex flex-col items-center mb-6">
          <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-2 block">
            💵 Cash in Hand (जेब में नकद)
          </div>
          <div className="text-4xl font-black text-white tracking-tight drop-shadow-[0_0_15px_rgba(16,185,129,0.2)] mb-6">
            {formatPrice(walletInfo.cashInHand)}
          </div>
          
          {/* Circular Progress */}
          <div className="relative w-[120px] h-[120px] flex items-center justify-center">
            <svg className="w-full h-full -rotate-90 transform" viewBox="0 0 120 120">
              <circle
                className="text-white/[0.05]"
                strokeWidth="8"
                stroke="currentColor"
                fill="transparent"
                r="52"
                cx="60"
                cy="60"
              />
              <motion.circle
                className={`${ringColor} ${walletInfo.isLocked ? 'animate-pulse drop-shadow-[0_0_10px_rgba(244,63,94,0.5)]' : 'drop-shadow-[0_0_10px_rgba(16,185,129,0.3)]'}`}
                strokeWidth="8"
                strokeDasharray={circumference}
                initial={{ strokeDashoffset: circumference }}
                animate={{ strokeDashoffset: mounted ? strokeDashoffset : circumference }}
                transition={{ duration: 1.5, ease: "easeOut", delay: 0.2 }}
                strokeLinecap="round"
                stroke="currentColor"
                fill="transparent"
                r="52"
                cx="60"
                cy="60"
              />
            </svg>
            <div className="absolute flex flex-col items-center justify-center">
              <span className="text-2xl font-black text-white">{capacityPercent}%</span>
              <span className="text-[10px] font-medium text-slate-400">Capacity</span>
            </div>
          </div>
        </div>

        {/* Limit Info Row */}
        <div className="relative z-10 grid grid-cols-3 gap-2 bg-white/[0.03] border border-white/[0.06] rounded-2xl p-4 mb-4">
          <div className="text-center">
            <span className="text-[10px] font-semibold text-slate-400 block mb-1">In Hand</span>
            <span className="text-sm font-bold text-white">{formatPrice(walletInfo.cashInHand)}</span>
          </div>
          <div className="text-center border-l border-white/[0.06]">
            <span className="text-[10px] font-semibold text-slate-400 block mb-1">Limit</span>
            <span className="text-sm font-bold text-white">{formatPrice(walletInfo.cashLimit)}</span>
          </div>
          <div className="text-center border-l border-white/[0.06]">
            <span className="text-[10px] font-semibold text-slate-400 block mb-1">Remaining</span>
            <span className="text-sm font-bold text-emerald-400">{formatPrice(walletInfo.remainingLimit)}</span>
          </div>
        </div>

        {/* Status Banner */}
        <div className={`relative z-10 p-4 rounded-2xl border ${
          walletInfo.isLocked
            ? 'bg-rose-500/10 border-rose-500/20 text-rose-200'
            : walletInfo.isWarning
            ? 'bg-amber-500/10 border-amber-500/20 text-amber-200'
            : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-200'
        }`}>
          <div className="flex items-start gap-3 text-sm font-medium">
            {walletInfo.isLocked ? (
              <>
                <ShieldAlert className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
                <p>🚨 <strong className="text-rose-300">Limit Reached!</strong> Please deposit at store to receive new COD orders.</p>
              </>
            ) : walletInfo.isWarning ? (
              <>
                <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
                <p>⚠️ <strong className="text-amber-300">Approaching Limit!</strong> You can collect up to {formatPrice(walletInfo.remainingLimit)} more.</p>
              </>
            ) : (
              <>
                <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
                <p>✅ <strong className="text-emerald-300">Active & Eligible</strong> for COD orders.</p>
              </>
            )}
          </div>
        </div>
      </motion.div>

      {/* Stats Grid */}
      <motion.div variants={itemVariants} className="grid grid-cols-3 gap-3">
        <div className="bg-card border border-border rounded-2xl p-4 flex flex-col items-center text-center shadow-sm">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider mb-2 block line-clamp-1">Today's COD</span>
          <span className="text-lg font-black text-amber-600 dark:text-amber-400">{formatPrice(todayCodCollected)}</span>
        </div>
        <div className="bg-card border border-border rounded-2xl p-4 flex flex-col items-center text-center shadow-sm">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider mb-2 block line-clamp-1">Deliveries</span>
          <span className="text-lg font-black text-emerald-600 dark:text-emerald-400">{todayDeliveries}</span>
        </div>
        <div className="bg-card border border-border rounded-2xl p-4 flex flex-col items-center text-center shadow-sm">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider mb-2 block line-clamp-1">Deposited</span>
          <span className="text-lg font-black text-blue-600 dark:text-blue-400">{formatPrice(walletInfo.totalDeposited)}</span>
        </div>
      </motion.div>

      {/* Deposit CTA */}
      {(walletInfo.isLocked || walletInfo.isWarning) && (
        <motion.div variants={itemVariants}>
          <button className="w-full min-h-[52px] rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-500 text-white font-bold text-sm shadow-lg shadow-emerald-500/20 active:scale-[0.98] transition-all flex items-center justify-center gap-2">
            <Store className="w-5 h-5" />
            Deposit Cash at Store
          </button>
        </motion.div>
      )}
    </motion.div>
  )
}
