'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Truck, RefreshCw, Clock } from 'lucide-react'
import { formatDate } from '@/lib/date-helpers'

function LiveClock() {
  const [time, setTime] = useState<string>('')
  useEffect(() => {
    const tick = () => setTime(formatDate(new Date(), 'hh:mm:ss a'))
    tick()
    const id = setInterval(tick, 1000)
    return () => clearInterval(id)
  }, [])
  if (!time) return null
  return (
    <span className="text-[10px] font-mono text-white/80 tracking-wider flex items-center gap-1">
      <Clock className="h-3 w-3" />
      {time}
    </span>
  )
}

interface DeliveryHeaderProps {
  userName?: string | null
  isOffline: boolean
  isRefreshing: boolean
  offlineQueueCount: number
  autoRefreshCountdown: number
  activeTab: 'deliveries' | 'wallet' | 'history'
  setActiveTab: (tab: 'deliveries' | 'wallet' | 'history') => void
  onRefresh: () => void
}

export default function DeliveryHeader({
  userName,
  isOffline,
  isRefreshing,
  offlineQueueCount,
  autoRefreshCountdown,
  activeTab,
  setActiveTab,
  onRefresh,
}: DeliveryHeaderProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 200, damping: 22 }}
      className="relative overflow-hidden bg-gradient-to-br from-emerald-500 to-teal-600 px-5 py-5 sm:rounded-b-3xl shadow-xl"
    >
      {/* Glassmorphism decorative circles */}
      <div className="absolute -top-8 -right-8 h-32 w-32 rounded-full bg-white/10 blur-2xl pointer-events-none" />
      <div className="absolute -bottom-6 -left-6 h-24 w-24 rounded-full bg-white/5 blur-xl pointer-events-none" />

      <div className="relative flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="h-11 w-11 rounded-2xl bg-white/20 backdrop-blur-md border border-white/30 flex items-center justify-center shadow-inner">
            <motion.div
              animate={{ x: [0, 3, 0] }}
              transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
            >
              <Truck className="h-5 w-5 text-white drop-shadow" />
            </motion.div>
          </div>
          <div>
            <h1 className="text-sm font-black text-white tracking-tight flex items-center gap-1.5">
              Rider Console
              {isOffline && (
                <span className="px-1.5 py-0.5 rounded bg-rose-500 text-white text-[8px] font-black uppercase tracking-wider animate-pulse">
                  Offline
                </span>
              )}
            </h1>
            <p className="text-[10px] text-white/70 mt-0.5">
              {userName || 'Delivery Boy'}
            </p>
          </div>
        </div>

        <div className="flex flex-col items-end gap-1.5">
          <LiveClock />
          <button
            onClick={onRefresh}
            disabled={isRefreshing}
            className="h-9 w-9 min-h-[44px] min-w-[44px] rounded-xl bg-white/15 backdrop-blur-md border border-white/20 flex items-center justify-center text-white hover:bg-white/25 transition-all disabled:opacity-50 active:scale-95 cursor-pointer"
          >
            <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {offlineQueueCount > 0 && (
        <div className="mt-3 bg-amber-500/25 border border-amber-500/40 rounded-xl p-2.5 text-[9px] font-bold text-amber-100 flex items-center justify-between animate-fade-in">
          <span>⚠️ {offlineQueueCount} unsynced offline updates</span>
          <span className="animate-pulse">Waiting for network...</span>
        </div>
      )}

      {/* Auto-refresh progress bar */}
      <div className="mt-3 h-0.5 rounded-full bg-white/10 overflow-hidden">
        <motion.div
          className="h-full bg-white/40 rounded-full"
          animate={{ width: `${((30 - autoRefreshCountdown) / 30) * 100}%` }}
          transition={{ duration: 0.5, ease: 'linear' }}
        />
      </div>
      <p className="text-[8px] text-white/40 mt-1 text-right font-mono">
        auto-refresh in {autoRefreshCountdown}s
      </p>

      {/* Rider Navigation Tabs */}
      <div className="flex bg-white/15 backdrop-blur-md rounded-2xl p-1 border border-white/20 mt-3 gap-1 shadow-inner">
        <button
          onClick={() => setActiveTab('deliveries')}
          className={`flex-1 py-2.5 px-3 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
            activeTab === 'deliveries'
              ? 'bg-white text-emerald-700 shadow-md scale-[1.01]'
              : 'text-white/85 hover:bg-white/10'
          }`}
        >
          <Truck className="h-3.5 w-3.5" />
          Deliveries
        </button>
        <button
          onClick={() => setActiveTab('wallet')}
          className={`flex-1 py-2.5 px-3 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
            activeTab === 'wallet'
              ? 'bg-white text-emerald-700 shadow-md scale-[1.01]'
              : 'text-white/85 hover:bg-white/10'
          }`}
        >
          <span className="font-bold">₹</span>
          Wallet & COD
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={`flex-1 py-2.5 px-3 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
            activeTab === 'history'
              ? 'bg-white text-emerald-700 shadow-md scale-[1.01]'
              : 'text-white/85 hover:bg-white/10'
          }`}
        >
          <Clock className="h-3.5 w-3.5" />
          History
        </button>
      </div>
    </motion.div>
  )
}
