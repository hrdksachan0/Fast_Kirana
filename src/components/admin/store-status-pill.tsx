'use client'

import React, { useState, useEffect } from 'react'
import {
  Power,
  Clock,
  AlertTriangle,
  CheckCircle2,
  X,
  Timer,
  ShieldAlert,
  Flame,
  CloudRain,
  Users,
  Wrench,
  HelpCircle,
} from 'lucide-react'
import { toast } from 'sonner'

export interface StoreStatusPillProps {
  storeId?: string
  storeName?: string
  isOpen: boolean
  pauseUntil?: string | null
  closeReason?: string | null
  onStatusUpdated?: () => void
  disabled?: boolean
}

const PRESET_REASONS = [
  { id: 'HIGH_ORDER_SURGE', label: 'High Order Rush / Surge Backlog', icon: Flame },
  { id: 'HEAVY_RAIN', label: 'Heavy Rain / Bad Weather', icon: CloudRain },
  { id: 'RIDER_SHORTAGE', label: 'Delivery Riders Unavailable', icon: Users },
  { id: 'TECHNICAL_MAINTENANCE', label: 'Power Cut / System Maintenance', icon: Wrench },
  { id: 'STOCK_AUDIT', label: 'Stock Counting & Inward In Progress', icon: Timer },
  { id: 'OTHER', label: 'Other Operational Reason', icon: HelpCircle },
]

export function StoreStatusPill({
  storeId = 'hub-209206',
  storeName = 'Store Hub',
  isOpen,
  pauseUntil,
  closeReason,
  onStatusUpdated,
  disabled = false,
}: StoreStatusPillProps) {
  const [modalOpen, setModalOpen] = useState(false)
  const [selectedDuration, setSelectedDuration] = useState<number | 'TODAY'>(30)
  const [selectedReason, setSelectedReason] = useState('HIGH_ORDER_SURGE')
  const [customReason, setCustomReason] = useState('')
  const [loading, setLoading] = useState(false)

  // Calculate remaining pause time
  const [timeLeftStr, setTimeLeftStr] = useState<string | null>(null)
  const isPaused = !isOpen && !!pauseUntil && new Date(pauseUntil).getTime() > Date.now()

  useEffect(() => {
    if (!pauseUntil) {
      setTimeLeftStr(null)
      return
    }

    const updateTimer = () => {
      const remainingMs = new Date(pauseUntil).getTime() - Date.now()
      if (remainingMs <= 0) {
        setTimeLeftStr(null)
      } else {
        const mins = Math.floor(remainingMs / 60000)
        const secs = Math.floor((remainingMs % 60000) / 1000)
        setTimeLeftStr(`${mins}m ${secs}s`)
      }
    }

    updateTimer()
    const interval = setInterval(updateTimer, 1000)
    return () => clearInterval(interval)
  }, [pauseUntil])

  const handleToggle = async (action: 'RESUME' | 'PAUSE' | 'CLOSE_TODAY') => {
    setLoading(true)
    try {
      const res = await fetch('/api/admin/serviceability/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          targetType: 'HUB',
          targetId: storeId,
          action,
          pauseMinutes: action === 'PAUSE' ? selectedDuration : undefined,
          reason: selectedReason,
          customReasonText: selectedReason === 'OTHER' ? customReason : undefined,
        }),
      })

      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to update store status')
      }

      toast.success(data.message || 'Store status updated successfully!')
      setModalOpen(false)
      onStatusUpdated?.()
    } catch (err: any) {
      toast.error(err.message || 'Failed to update store status')
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      {/* ── Status Trigger Pill ── */}
      <button
        type="button"
        disabled={disabled}
        onClick={() => {
          if (isOpen) {
            setModalOpen(true)
          } else {
            handleToggle('RESUME')
          }
        }}
        className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-2xl border font-black text-xs uppercase tracking-wider transition-all duration-200 shadow-2xs hover:shadow-sm cursor-pointer disabled:opacity-50 ${
          isOpen
            ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30 hover:bg-emerald-500/20 dark:text-emerald-400'
            : isPaused
            ? 'bg-amber-500/10 text-amber-600 border-amber-500/30 hover:bg-amber-500/20 dark:text-amber-400 animate-pulse'
            : 'bg-rose-500/10 text-rose-600 border-rose-500/30 hover:bg-rose-500/20 dark:text-rose-400'
        }`}
        title={
          isOpen
            ? 'Store is ONLINE. Click to pause or close.'
            : isPaused
            ? `Store is PAUSED (${timeLeftStr || 'Busy Mode'}). Click to resume.`
            : 'Store is CLOSED. Click to resume immediately.'
        }
      >
        <span
          className={`w-2 h-2 rounded-full shrink-0 ${
            isOpen ? 'bg-emerald-500' : isPaused ? 'bg-amber-500' : 'bg-rose-500'
          }`}
        />
        <span>
          {isOpen
            ? '🟢 ONLINE'
            : isPaused
            ? `🟡 PAUSED (${timeLeftStr || 'Busy'})`
            : '🔴 CLOSED'}
        </span>
        <Power className="w-3.5 h-3.5 ml-0.5 opacity-70" />
      </button>

      {/* ── Zepto/Swiggy Standard Serviceability Modal ── */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-in fade-in duration-150">
          <div className="relative w-full max-w-lg rounded-3xl bg-card border border-border shadow-2xl p-6 overflow-hidden">
            
            {/* Header */}
            <div className="flex items-start justify-between gap-3 pb-4 border-b border-border/70">
              <div className="flex items-center gap-3">
                <div className="p-3 rounded-2xl bg-amber-500/10 text-amber-600 border border-amber-500/20">
                  <ShieldAlert className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="text-base font-black text-text-primary">
                    Manage Serviceability: {storeName}
                  </h3>
                  <p className="text-xs text-text-secondary font-medium mt-0.5">
                    Select a pause timer or reason to temporarily halt incoming customer orders.
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setModalOpen(false)}
                className="p-1.5 rounded-xl text-text-secondary hover:text-text-primary hover:bg-muted transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Pause Duration Options (Zepto Busy Mode) */}
            <div className="py-4 space-y-3">
              <label className="text-xs font-black uppercase tracking-wider text-text-secondary">
                ⏱️ 1. Choose Pause Duration
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {[
                  { value: 15, label: '15 Mins', desc: 'Quick rush' },
                  { value: 30, label: '30 Mins', desc: 'Restocking' },
                  { value: 60, label: '1 Hour', desc: 'Shift break' },
                  { value: 'TODAY', label: 'Full Day', desc: 'Manual open' },
                ].map((item) => (
                  <button
                    key={String(item.value)}
                    type="button"
                    onClick={() => setSelectedDuration(item.value as any)}
                    className={`flex flex-col items-center justify-center p-3 rounded-2xl border text-center transition-all cursor-pointer ${
                      selectedDuration === item.value
                        ? 'bg-primary/10 border-primary text-primary font-black shadow-xs'
                        : 'bg-muted/40 border-border/70 text-text-primary hover:bg-muted/80'
                    }`}
                  >
                    <span className="text-sm font-black">{item.label}</span>
                    <span className="text-[10px] text-text-secondary font-medium">{item.desc}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Mandatory Reason Selector */}
            <div className="space-y-2 pb-4">
              <label className="text-xs font-black uppercase tracking-wider text-text-secondary">
                📋 2. Select Reason (Audited)
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {PRESET_REASONS.map((r) => {
                  const Icon = r.icon
                  const isSelected = selectedReason === r.id
                  return (
                    <button
                      key={r.id}
                      type="button"
                      onClick={() => setSelectedReason(r.id)}
                      className={`flex items-center gap-2 p-2.5 rounded-xl border text-left text-xs transition-all cursor-pointer ${
                        isSelected
                          ? 'bg-amber-500/10 border-amber-500/40 text-amber-700 dark:text-amber-300 font-bold'
                          : 'bg-muted/30 border-border/60 text-text-secondary hover:text-text-primary hover:bg-muted/60'
                      }`}
                    >
                      <Icon className={`w-4 h-4 shrink-0 ${isSelected ? 'text-amber-600' : 'text-text-secondary'}`} />
                      <span className="line-clamp-1">{r.label}</span>
                    </button>
                  )
                })}
              </div>

              {selectedReason === 'OTHER' && (
                <input
                  type="text"
                  placeholder="Type specific reason for audit log..."
                  value={customReason}
                  onChange={(e) => setCustomReason(e.target.value)}
                  className="w-full mt-2 px-3 py-2 text-xs rounded-xl border border-border bg-card text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                />
              )}
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col sm:flex-row items-center justify-end gap-2 pt-4 border-t border-border/70">
              <button
                type="button"
                onClick={() => setModalOpen(false)}
                className="w-full sm:w-auto px-4 py-2.5 rounded-xl text-xs font-bold text-text-secondary hover:bg-muted transition-colors cursor-pointer"
              >
                Cancel
              </button>

              <button
                type="button"
                disabled={loading}
                onClick={() => {
                  if (selectedDuration === 'TODAY') {
                    handleToggle('CLOSE_TODAY')
                  } else {
                    handleToggle('PAUSE')
                  }
                }}
                className="w-full sm:w-auto px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider bg-rose-600 text-white hover:bg-rose-700 shadow-md transition-all cursor-pointer disabled:opacity-50 flex items-center justify-center gap-2"
              >
                <Power className="w-4 h-4" />
                <span>
                  {loading
                    ? 'Updating...'
                    : selectedDuration === 'TODAY'
                    ? 'Close Store For Today'
                    : `Pause Store (${selectedDuration}m)`}
                </span>
              </button>
            </div>

          </div>
        </div>
      )}
    </>
  )
}
