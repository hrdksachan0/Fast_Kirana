'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Truck, RefreshCw, Clock, Wallet, CheckCircle2, Wifi, WifiOff, Sparkles } from 'lucide-react'
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
    <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/[0.07] border border-white/10 backdrop-blur-md">
      <Clock className="h-3 w-3 text-emerald-400" />
      <span className="text-[10px] font-mono font-semibold text-slate-300 tracking-wider">
        {time}
      </span>
    </div>
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
  // Time-aware greeting
  const [greeting, setGreeting] = useState('Hey')
  useEffect(() => {
    const hour = new Date().getHours()
    if (hour < 12) setGreeting('Good Morning')
    else if (hour < 17) setGreeting('Good Afternoon')
    else setGreeting('Good Evening')
  }, [])

  const tabs: Array<{ id: 'deliveries' | 'wallet' | 'history'; label: string; icon: any }> = [
    { id: 'deliveries', label: 'Deliveries', icon: Truck },
    { id: 'wallet', label: 'Cash Wallet', icon: Wallet },
    { id: 'history', label: 'History', icon: CheckCircle2 },
  ]

  return (
    <motion.div
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 220, damping: 24 }}
      className="relative overflow-hidden bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 border-b border-white/10 px-4 pt-4 pb-3 sm:rounded-b-3xl shadow-2xl"
    >
      {/* Ambient background glows */}
      <div className="absolute -top-12 -right-12 h-44 w-44 rounded-full bg-emerald-500/15 blur-3xl pointer-events-none" />
      <div className="absolute -bottom-10 -left-10 h-36 w-36 rounded-full bg-teal-500/10 blur-2xl pointer-events-none" />

      {/* Top Bar: Status & Live Clock & Refresh */}
      <div className="relative flex justify-between items-center pb-3 border-b border-white/[0.06]">
        {/* Status Pill */}
        <div className="flex items-center gap-2">
          {isOffline ? (
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-rose-500/15 border border-rose-500/30 text-rose-400 text-[10px] font-black uppercase tracking-wider animate-pulse">
              <WifiOff className="h-3 w-3" />
              <span>Offline Mode</span>
            </div>
          ) : (
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/25 text-emerald-400 text-[10px] font-bold tracking-wide shadow-xs">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
              </span>
              <span className="font-semibold text-slate-200">Online</span>
            </div>
          )}
        </div>

        {/* Clock & Refresh button */}
        <div className="flex items-center gap-2">
          <LiveClock />
          <button
            onClick={onRefresh}
            disabled={isRefreshing}
            aria-label="Refresh orders"
            className="h-8 w-8 min-h-[44px] min-w-[44px] rounded-full bg-white/[0.06] hover:bg-white/[0.12] border border-white/10 flex items-center justify-center text-slate-200 hover:text-white transition-all disabled:opacity-50 active:scale-90 cursor-pointer shadow-xs"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isRefreshing ? 'animate-spin text-emerald-400' : ''}`} />
          </button>
        </div>
      </div>

      {/* Rider Greeting & Identity */}
      <div className="relative pt-3 pb-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="relative">
            <div className="h-11 w-11 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 p-[1.5px] shadow-lg shadow-emerald-500/20">
              <div className="h-full w-full rounded-[14px] bg-slate-950 flex items-center justify-center">
                <Truck className="h-5 w-5 text-emerald-400" />
              </div>
            </div>
            <div className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full bg-emerald-500 border-2 border-slate-950 flex items-center justify-center">
              <Sparkles className="h-2 w-2 text-slate-950" />
            </div>
          </div>
          <div>
            <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-400 block leading-none">
              FastKirana Partner
            </span>
            <h1 className="text-base font-black text-white tracking-tight flex items-center gap-1.5 mt-0.5">
              {greeting}, <span className="text-emerald-300">{userName || 'Rider'}</span> 👋
            </h1>
          </div>
        </div>

        {/* Auto Refresh Progress Tag */}
        <div className="text-right">
          <span className="text-[9px] font-mono text-slate-400 block">
            Sync in <strong className="text-emerald-400 font-bold">{autoRefreshCountdown}s</strong>
          </span>
          <div className="mt-1 w-16 h-1 rounded-full bg-white/10 overflow-hidden ml-auto">
            <motion.div
              className="h-full bg-gradient-to-r from-emerald-500 to-teal-400 rounded-full"
              animate={{ width: `${((30 - autoRefreshCountdown) / 30) * 100}%` }}
              transition={{ duration: 0.5, ease: 'linear' }}
            />
          </div>
        </div>
      </div>

      {/* Offline sync queue notice if any */}
      {offlineQueueCount > 0 && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          className="mb-2.5 bg-amber-500/15 border border-amber-500/30 rounded-xl p-2.5 text-[10px] font-bold text-amber-200 flex items-center justify-between"
        >
          <span>⚠️ {offlineQueueCount} unsynced offline updates</span>
          <span className="animate-pulse text-amber-400 font-semibold">Auto-syncing...</span>
        </motion.div>
      )}

      {/* Modern Glassmorphic Pill Tab Navigation */}
      <div className="relative mt-1 bg-black/40 backdrop-blur-xl rounded-2xl p-1 border border-white/10 grid grid-cols-3 gap-1 shadow-inner">
        {tabs.map((tab) => {
          const Icon = tab.icon
          const isActive = activeTab === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`relative py-2.5 px-2 rounded-xl text-xs font-black tracking-wide transition-all duration-200 flex items-center justify-center gap-1.5 cursor-pointer z-10 select-none ${
                isActive
                  ? 'text-emerald-950 font-black'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-white/[0.04]'
              }`}
            >
              {isActive && (
                <motion.div
                  layoutId="activeRiderTabIndicator"
                  transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                  className="absolute inset-0 bg-gradient-to-r from-emerald-400 to-teal-300 rounded-xl shadow-md shadow-emerald-500/25 -z-10"
                />
              )}
              <Icon className={`h-3.5 w-3.5 shrink-0 ${isActive ? 'text-emerald-950' : 'text-slate-400'}`} />
              <span className="truncate">{tab.label}</span>
            </button>
          )
        })}
      </div>
    </motion.div>
  )
}
