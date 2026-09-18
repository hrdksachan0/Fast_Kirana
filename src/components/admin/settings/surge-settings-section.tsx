'use client'

import React from 'react'
import { CloudRain, Zap, ShieldCheck } from 'lucide-react'

interface SurgeSettingsSectionProps {
  surgeActive: boolean
  surgeFee: string
  surgeReason: string
  currentWeatherCondition: string
  currentWeatherTemp: string
  currentActiveOrders: string
  currentActiveRiders: string
  surgeMode: 'AUTO' | 'MANUAL_ON' | 'MANUAL_OFF'
  setSurgeMode: (v: 'AUTO' | 'MANUAL_ON' | 'MANUAL_OFF') => void
  surgeRainAmount: string
  setSurgeRainAmount: (v: string) => void
  surgeDemandAmount: string
  setSurgeDemandAmount: (v: string) => void
  surgeMaxCap: string
  setSurgeMaxCap: (v: string) => void
  surgeManualAmount: string
  setSurgeManualAmount: (v: string) => void
  surgeDemandThreshold: string
  setSurgeDemandThreshold: (v: string) => void
}

export function SurgeSettingsSection({
  surgeActive,
  surgeFee,
  surgeReason,
  currentWeatherCondition,
  currentWeatherTemp,
  currentActiveOrders,
  currentActiveRiders,
  surgeMode,
  setSurgeMode,
  surgeRainAmount,
  setSurgeRainAmount,
  surgeDemandAmount,
  setSurgeDemandAmount,
  surgeMaxCap,
  setSurgeMaxCap,
  surgeManualAmount,
  setSurgeManualAmount,
  surgeDemandThreshold,
  setSurgeDemandThreshold,
}: SurgeSettingsSectionProps) {
  return (
    <div className="space-y-6">
      {/* Live Realtime Telemetry Card */}
      <div className="bg-gradient-to-br from-card to-muted/30 border border-border/80 p-5 rounded-2xl shadow-sm space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-500">
              <CloudRain className="h-4 w-4" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-text-primary">Live Surge & Weather Telemetry</h4>
              <p className="text-[10px] text-text-secondary">Real-time status based on Ghatampur coordinates & active rider fleet</p>
            </div>
          </div>
          <span
            className={`px-2.5 py-1 rounded-full text-[10px] font-black border ${
              surgeActive
                ? 'bg-amber-500/10 text-amber-500 border-amber-500/30 animate-pulse'
                : 'bg-emerald-500/10 text-emerald-500 border-emerald-500/30'
            }`}
          >
            {surgeActive ? `⚡ Surge Active: +₹${surgeFee}` : '🟢 Standard Rates (₹0 Surge)'}
          </span>
        </div>

        {surgeActive && surgeReason && (
          <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl text-xs font-medium text-amber-600 flex items-center gap-2">
            <Zap className="h-4 w-4 shrink-0" />
            <span>
              <strong>Reason:</strong> {surgeReason}
            </span>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
          <div className="bg-muted/40 p-3 rounded-xl border border-border/60">
            <span className="text-[9px] font-black uppercase tracking-wider text-text-muted">Live Weather Condition</span>
            <div className="flex items-center justify-between mt-1">
              <span className="text-xs font-bold text-text-primary">{currentWeatherCondition}</span>
              <span className="text-xs font-black text-blue-500">{currentWeatherTemp}°C</span>
            </div>
            <p className="text-[10px] text-text-secondary mt-1">Ghatampur (26.1534° N, 80.1714° E)</p>
          </div>

          <div className="bg-muted/40 p-3 rounded-xl border border-border/60">
            <span className="text-[9px] font-black uppercase tracking-wider text-text-muted">Live Delivery Rush Load</span>
            <div className="flex items-center justify-between mt-1">
              <span className="text-xs font-bold text-text-primary">{currentActiveOrders} Active Orders</span>
              <span className="text-xs font-black text-accent">{currentActiveRiders} Active Riders</span>
            </div>
            <p className="text-[10px] text-text-secondary mt-1">
              Fleet ratio:{' '}
              {Number(currentActiveRiders) > 0
                ? (Number(currentActiveOrders) / Number(currentActiveRiders)).toFixed(1)
                : currentActiveOrders}{' '}
              orders / rider
            </p>
          </div>
        </div>
      </div>

      {/* Master Mode Selector */}
      <div className="space-y-3">
        <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
          <ShieldCheck className="h-3.5 w-3.5 text-primary" /> Master Surge Control Mode
        </label>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <button
            type="button"
            onClick={() => setSurgeMode('AUTO')}
            className={`p-4 rounded-xl border text-left transition-all cursor-pointer ${
              surgeMode === 'AUTO'
                ? 'bg-primary/5 border-primary shadow-sm ring-1 ring-primary/30'
                : 'bg-card border-border hover:border-border/80'
            }`}
          >
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs font-black text-text-primary">🤖 Automatic (Recommended)</span>
              {surgeMode === 'AUTO' && <span className="w-2 h-2 rounded-full bg-primary animate-ping" />}
            </div>
            <p className="text-[10px] text-text-secondary leading-relaxed">
              Evaluates live rain weather and rush ratio automatically. Capped strictly at maximum ceiling.
            </p>
          </button>

          <button
            type="button"
            onClick={() => setSurgeMode('MANUAL_ON')}
            className={`p-4 rounded-xl border text-left transition-all cursor-pointer ${
              surgeMode === 'MANUAL_ON'
                ? 'bg-amber-500/5 border-amber-500 shadow-sm ring-1 ring-amber-500/30'
                : 'bg-card border-border hover:border-border/80'
            }`}
          >
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs font-black text-amber-500">⚡ Force ON (Manual)</span>
              {surgeMode === 'MANUAL_ON' && <span className="w-2 h-2 rounded-full bg-amber-500" />}
            </div>
            <p className="text-[10px] text-text-secondary leading-relaxed">
              Forces surge pricing on all checkouts right now, regardless of weather or rush.
            </p>
          </button>

          <button
            type="button"
            onClick={() => setSurgeMode('MANUAL_OFF')}
            className={`p-4 rounded-xl border text-left transition-all cursor-pointer ${
              surgeMode === 'MANUAL_OFF'
                ? 'bg-emerald-500/5 border-emerald-500 shadow-sm ring-1 ring-emerald-500/30'
                : 'bg-card border-border hover:border-border/80'
            }`}
          >
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs font-black text-emerald-500">🛑 Force OFF (Strict Disabled)</span>
              {surgeMode === 'MANUAL_OFF' && <span className="w-2 h-2 rounded-full bg-emerald-500" />}
            </div>
            <p className="text-[10px] text-text-secondary leading-relaxed">
              Strictly guarantees ₹0 surge fee. Protects customers from any extra fees.
            </p>
          </button>
        </div>
      </div>

      {/* Safety Cap and Surge Parameters Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="space-y-1.5">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            🌧️ Rain Surge Fee (₹)
          </label>
          <input
            type="number"
            min="0"
            max="100"
            value={surgeRainAmount}
            onChange={(e) => setSurgeRainAmount(e.target.value)}
            placeholder="20"
            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
          />
          <p className="text-[9px] text-text-secondary">Added automatically when rain/thunderstorm is detected in Ghatampur</p>
        </div>

        <div className="space-y-1.5">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            🔥 Demand Rush Surge Fee (₹)
          </label>
          <input
            type="number"
            min="0"
            max="100"
            value={surgeDemandAmount}
            onChange={(e) => setSurgeDemandAmount(e.target.value)}
            placeholder="15"
            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
          />
          <p className="text-[9px] text-text-secondary">Added when active orders exceed active delivery boys threshold</p>
        </div>

        <div className="space-y-1.5">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            🛡️ Strict Max Safety Cap Ceiling (₹) *
          </label>
          <input
            type="number"
            min="0"
            max="100"
            value={surgeMaxCap}
            onChange={(e) => setSurgeMaxCap(e.target.value)}
            placeholder="25"
            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium font-bold text-accent"
          />
          <p className="text-[9px] text-text-secondary font-bold">
            Hard safety limit: Total surge fee will NEVER exceed this amount under any condition.
          </p>
        </div>

        <div className="space-y-1.5">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            ⚡ Manual Mode Fixed Fee (₹)
          </label>
          <input
            type="number"
            min="0"
            max="100"
            value={surgeManualAmount}
            onChange={(e) => setSurgeManualAmount(e.target.value)}
            placeholder="20"
            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
          />
          <p className="text-[9px] text-text-secondary">Fee used when Master Mode is set to 'Force ON (Manual)'</p>
        </div>

        <div className="space-y-1.5 md:col-span-2">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            📊 Demand Ratio Trigger (Orders per Delivery Boy)
          </label>
          <input
            type="number"
            step="0.5"
            min="1.0"
            max="10.0"
            value={surgeDemandThreshold}
            onChange={(e) => setSurgeDemandThreshold(e.target.value)}
            placeholder="3.0"
            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
          />
          <p className="text-[9px] text-text-secondary">
            Example: 3.0 means if there are more than 3 pending orders per active rider, demand surge triggers.
          </p>
        </div>
      </div>
    </div>
  )
}
