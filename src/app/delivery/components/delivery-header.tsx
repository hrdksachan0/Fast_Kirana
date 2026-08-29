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
    <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/20 border border-white/30 backdrop-blur-md shadow-xs">
      <Clock className="h-3 w-3 text-white" />
      <span className="text-[10px] font-mono font-bold text-white tracking-wider">
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
      className="relative overflow-hidden bg-gradient-to-br from-emerald-500 via-emerald-600 to-teal-700 px-4 pt-4 pb-3 sm:rounded-b-3xl shadow-xl text-white"
    >
      {/* Decorative ambient glass bubbles */}
      <div className="absolute -top-12 -right-12 h-44 w-44 rounded-full bg-white/10 blur-2xl pointer-events-none" />
      <div className="absolute -bottom-10 -left-10 h-36 w-36 rounded-full bg-white/10 blur-xl pointer-events-none" />

      {/* Top Bar: Status & Live Clock & Refresh */}
      <div className="relative flex justify-between items-center pb-3 border-b border-white/20">
        {/* Status Pill */}
        <div className="flex items-center gap-2">
          {isOffline ? (
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-rose-600 text-white text-[10px] font-black uppercase tracking-wider animate-pulse shadow-sm">
              <WifiOff className="h-3 w-3" />
              <span>Offline Mode</span>
            </div>
          ) : (
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/20 border border-white/30 text-white text-[10px] font-bold tracking-wide shadow-xs backdrop-blur-md">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-200" />
              </span>
              <span className="font-bold">Online & Active</span>
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
            className="h-8 w-8 min-h-[44px] min-w-[44px] rounded-full bg-white/20 hover:bg-white/30 border border-white/30 flex items-center justify-center text-white transition-all disabled:opacity-50 active:scale-90 cursor-pointer shadow-xs"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Rider Greeting & Identity */}
      <div className="relative pt-3 pb-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="relative">
            <div className="h-11 w-11 rounded-2xl bg-white/20 backdrop-blur-md border border-white/30 flex items-center justify-center shadow-md">
              <Truck className="h-5 w-5 text-white" />
            </div>
            <div className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full bg-white text-emerald-600 flex items-center justify-center shadow-xs">
              <Sparkles className="h-2 w-2" />
            </div>
          </div>
          <div>
            <span className="text-[10px] font-extrabold uppercase tracking-wider text-emerald-100 block leading-none">
              FastKirana Partner
            </span>
            <h1 className="text-base font-black text-white tracking-tight flex items-center gap-1.5 mt-0.5">
              {greeting}, <span className="underline decoration-white/40">{userName || 'Rider'}</span> 👋
            </h1>
          </div>
        </div>

        {/* Auto Refresh Progress Tag */}
        <div className="text-right">
          <span className="text-[9px] font-mono text-emerald-100 font-bold block">
            Sync in <strong className="text-white font-extrabold">{autoRefreshCountdown}s</strong>
          </span>
          <div className="mt-1 w-16 h-1 rounded-full bg-black/20 overflow-hidden ml-auto">
            <motion.div
              className="h-full bg-white rounded-full"
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
          className="mb-2.5 bg-amber-500 text-amber-950 font-bold rounded-xl p-2.5 text-[10px] flex items-center justify-between shadow-sm"
        >
          <span>⚠️ {offlineQueueCount} unsynced offline updates</span>
          <span className="animate-pulse font-extrabold">Auto-syncing...</span>
        </motion.div>
      )}

      {/* Modern Light Clean Tab Navigation */}
      <div className="relative mt-1 bg-black/15 backdrop-blur-md rounded-2xl p-1 border border-white/20 grid grid-cols-3 gap-1 shadow-inner">
        {tabs.map((tab) => {
          const Icon = tab.icon
          const isActive = activeTab === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`relative py-2.5 px-2 rounded-xl text-xs font-black tracking-wide transition-all duration-200 flex items-center justify-center gap-1.5 cursor-pointer z-10 select-none ${
                isActive
                  ? 'text-emerald-800 font-black shadow-md'
                  : 'text-white/90 hover:text-white hover:bg-white/10'
              }`}
            >
              {isActive && (
                <motion.div
                  layoutId="activeRiderTabIndicator"
                  transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                  className="absolute inset-0 bg-white rounded-xl shadow-md -z-10"
                />
              )}
              <Icon className={`h-3.5 w-3.5 shrink-0 ${isActive ? 'text-emerald-700' : 'text-white'}`} />
              <span className="truncate">{tab.label}</span>
            </button>
          )
        })}
      </div>
    </motion.div>
  )
}
