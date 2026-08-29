'use client'

import { motion } from 'framer-motion'
import { formatPrice } from '@/lib/utils'
import { Store, AlertTriangle, ShieldAlert, CheckCircle2, Wallet, ArrowUpRight } from 'lucide-react'
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

  const ringStroke = walletInfo.isLocked
    ? '#f43f5e'
    : walletInfo.isWarning
    ? '#f59e0b'
    : '#10b981'

  const containerVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: { staggerChildren: 0.1 }
    }
  }

  const itemVariants = {
    hidden: { opacity: 0, y: 16 },
    show: { opacity: 1, y: 0, transition: { type: 'spring' as const, stiffness: 280, damping: 24 } }
  } as const

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="show"
      className="space-y-4 pt-1 pb-4"
    >
      {/* Hero Wallet Card */}
      <motion.div variants={itemVariants} className="relative overflow-hidden rounded-3xl bg-card p-5 sm:p-6 shadow-xl border border-border">
        {/* Subtle background glow */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 w-44 h-44 rounded-full bg-emerald-500/10 blur-2xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 -ml-16 -mb-16 w-44 h-44 rounded-full bg-teal-500/10 blur-2xl pointer-events-none" />
        
        {/* Main Content */}
        <div className="relative z-10 flex flex-col items-center mb-5">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-800 dark:text-amber-300 text-[11px] font-black uppercase tracking-wider mb-2">
            <Wallet className="h-3.5 w-3.5" />
            <span>Cash in Hand (जेब में नकद)</span>
          </div>
          <div className="text-4xl font-black text-text-primary tracking-tight mb-5">
            {formatPrice(walletInfo.cashInHand)}
          </div>
          
          {/* Circular Progress Gauge */}
          <div className="relative w-[120px] h-[120px] flex items-center justify-center">
            <svg className="w-full h-full -rotate-90 transform" viewBox="0 0 120 120">
              <circle
                className="text-muted"
                strokeWidth="9"
                stroke="currentColor"
                fill="transparent"
                r="52"
                cx="60"
                cy="60"
              />
              <motion.circle
                strokeWidth="9"
                strokeDasharray={circumference}
                initial={{ strokeDashoffset: circumference }}
                animate={{ strokeDashoffset: mounted ? strokeDashoffset : circumference }}
                transition={{ duration: 1.2, ease: "easeOut", delay: 0.1 }}
                strokeLinecap="round"
                stroke={ringStroke}
                fill="transparent"
                r="52"
                cx="60"
                cy="60"
              />
            </svg>
            <div className="absolute flex flex-col items-center justify-center">
              <span className="text-2xl font-black text-text-primary">{capacityPercent}%</span>
              <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider">Capacity</span>
            </div>
          </div>
        </div>

        {/* Limit Info Row */}
        <div className="relative z-10 grid grid-cols-3 gap-2 bg-secondary/40 border border-border/60 rounded-2xl p-3.5 mb-3.5">
          <div className="text-center">
            <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block mb-0.5">In Hand</span>
            <span className="text-xs sm:text-sm font-black text-text-primary">{formatPrice(walletInfo.cashInHand)}</span>
          </div>
          <div className="text-center border-l border-border/60">
            <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block mb-0.5">Max Limit</span>
            <span className="text-xs sm:text-sm font-black text-text-primary">{formatPrice(walletInfo.cashLimit)}</span>
          </div>
          <div className="text-center border-l border-border/60">
            <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block mb-0.5">Remaining</span>
            <span className="text-xs sm:text-sm font-black text-emerald-600 dark:text-emerald-400">{formatPrice(walletInfo.remainingLimit)}</span>
          </div>
        </div>

        {/* Status Notice Banner */}
        <div className={`relative z-10 p-3.5 rounded-2xl border ${
          walletInfo.isLocked
            ? 'bg-rose-500/10 border-rose-500/30 text-rose-700 dark:text-rose-300'
            : walletInfo.isWarning
            ? 'bg-amber-500/10 border-amber-500/30 text-amber-800 dark:text-amber-300'
            : 'bg-emerald-500/10 border-emerald-500/30 text-emerald-800 dark:text-emerald-300'
        }`}>
          <div className="flex items-start gap-2.5 text-xs font-bold leading-relaxed">
            {walletInfo.isLocked ? (
              <>
                <ShieldAlert className="w-4 h-4 text-rose-600 shrink-0 mt-0.5" />
                <p>🚨 <strong>Limit Reached!</strong> Deposit cash at counter to receive new COD orders.</p>
              </>
            ) : walletInfo.isWarning ? (
              <>
                <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                <p>⚠️ <strong>Approaching Limit!</strong> You can collect up to {formatPrice(walletInfo.remainingLimit)} more.</p>
              </>
            ) : (
              <>
                <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
                <p>✅ <strong>Active & Eligible:</strong> Full COD order capacity available.</p>
              </>
            )}
          </div>
        </div>
      </motion.div>

      {/* Stats Grid */}
      <motion.div variants={itemVariants} className="grid grid-cols-3 gap-2.5">
        <div className="bg-card border border-border rounded-2xl p-3.5 flex flex-col items-center text-center shadow-xs">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider mb-1 block">Today's COD</span>
          <span className="text-base font-black text-amber-600 dark:text-amber-400">{formatPrice(todayCodCollected)}</span>
        </div>
        <div className="bg-card border border-border rounded-2xl p-3.5 flex flex-col items-center text-center shadow-xs">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider mb-1 block">Deliveries</span>
          <span className="text-base font-black text-emerald-600 dark:text-emerald-400">{todayDeliveries} Orders</span>
        </div>
        <div className="bg-card border border-border rounded-2xl p-3.5 flex flex-col items-center text-center shadow-xs">
          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider mb-1 block">Deposited</span>
          <span className="text-base font-black text-blue-600 dark:text-blue-400">{formatPrice(walletInfo.totalDeposited)}</span>
        </div>
      </motion.div>

      {/* Deposit CTA */}
      {(walletInfo.isLocked || walletInfo.isWarning) && (
        <motion.div variants={itemVariants}>
          <div className="p-4 rounded-3xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-2xl bg-amber-500 text-white flex items-center justify-center shadow-sm shrink-0">
                <Store className="h-5 w-5" />
              </div>
              <div>
                <p className="text-xs font-black text-text-primary">Deposit at FastKirana Counter</p>
                <p className="text-[10px] text-text-secondary">Hand over collected cash to store manager</p>
              </div>
            </div>
          </div>
        </motion.div>
      )}
    </motion.div>
  )
}
