'use client'

import React, { useState, useMemo } from 'react'
import {
  IndianRupee,
  Truck,
  MapPin,
  QrCode,
  Package,
  Calculator,
  Sparkles,
  CheckCircle,
  AlertCircle,
  Clock,
  ShieldCheck,
  Zap,
  ArrowRight
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { getDeliveryRules } from '@/lib/distance'

interface FinanceSettingsSectionProps {
  deliveryFee: string
  setDeliveryFee: (v: string) => void
  minOrderValue: string
  setMinOrderValue: (v: string) => void
  groceryFreeDeliveryThreshold: string
  setGroceryFreeDeliveryThreshold: (v: string) => void
  deliveryRadius: string
  setDeliveryRadius: (v: string) => void

  // Distance tiers
  deliveryFeeTier1: string
  setDeliveryFeeTier1: (v: string) => void
  deliveryThresholdTier1: string
  setDeliveryThresholdTier1: (v: string) => void

  deliveryFeeTier2: string
  setDeliveryFeeTier2: (v: string) => void
  deliveryThresholdTier2: string
  setDeliveryThresholdTier2: (v: string) => void

  deliveryFeeTier3: string
  setDeliveryFeeTier3: (v: string) => void
  deliveryThresholdTier3: string
  setDeliveryThresholdTier3: (v: string) => void

  deliveryFeePerKmBeyond5km: string
  setDeliveryFeePerKmBeyond5km: (v: string) => void

  // Packaging / Misc
  miscFee: string
  setMiscFee: (v: string) => void
  miscFeeLabel: string
  setMiscFeeLabel: (v: string) => void

  // UPI VPA
  storeUpiVpa: string
  setStoreUpiVpa: (v: string) => void

  // Store metadata
  storeHubName?: string
  storeId?: string
}

export function FinanceSettingsSection({
  deliveryFee,
  setDeliveryFee,
  minOrderValue,
  setMinOrderValue,
  groceryFreeDeliveryThreshold,
  setGroceryFreeDeliveryThreshold,
  deliveryRadius,
  setDeliveryRadius,
  deliveryFeeTier1,
  setDeliveryFeeTier1,
  deliveryThresholdTier1,
  setDeliveryThresholdTier1,
  deliveryFeeTier2,
  setDeliveryFeeTier2,
  deliveryThresholdTier2,
  setDeliveryThresholdTier2,
  deliveryFeeTier3,
  setDeliveryFeeTier3,
  deliveryThresholdTier3,
  setDeliveryThresholdTier3,
  deliveryFeePerKmBeyond5km,
  setDeliveryFeePerKmBeyond5km,
  miscFee,
  setMiscFee,
  miscFeeLabel,
  setMiscFeeLabel,
  storeUpiVpa,
  setStoreUpiVpa,
  storeHubName,
  storeId,
}: FinanceSettingsSectionProps) {
  // Live Test Rate Simulator state
  const [testDistanceKm, setTestDistanceKm] = useState<string>('2.5')
  const [testCartValue, setTestCartValue] = useState<string>('150')

  // Calculate live simulator output
  const simulatedRules = useMemo(() => {
    const dist = parseFloat(testDistanceKm) || 0
    const cart = parseFloat(testCartValue) || 0
    const maxRad = parseFloat(deliveryRadius) || 5.0

    const mockSettings: Record<string, string> = {
      delivery_radius: deliveryRadius,
      delivery_fee: deliveryFee,
      delivery_fee_tier1: deliveryFeeTier1,
      delivery_threshold_tier1: deliveryThresholdTier1,
      delivery_fee_tier2: deliveryFeeTier2,
      delivery_threshold_tier2: deliveryThresholdTier2,
      delivery_fee_tier3: deliveryFeeTier3,
      delivery_threshold_tier3: deliveryThresholdTier3,
      delivery_fee_per_km_beyond_5km: deliveryFeePerKmBeyond5km,
      grocery_free_delivery_threshold: groceryFreeDeliveryThreshold,
      store_name: storeHubName || 'Store Hub',
    }

    const rules = getDeliveryRules(dist, {
      maxRadiusKm: maxRad,
      settings: mockSettings,
      storeName: storeHubName,
    })

    const isFree = rules.isServiceable && cart >= rules.freeDeliveryThreshold
    const finalDeliveryFee = isFree ? 0 : rules.deliveryFee
    const packFee = parseFloat(miscFee) || 0
    const totalPayable = cart + finalDeliveryFee + packFee

    return {
      rules,
      isFree,
      finalDeliveryFee,
      packFee,
      totalPayable,
      amountNeededForFreeDelivery: Math.max(0, rules.freeDeliveryThreshold - cart),
    }
  }, [
    testDistanceKm,
    testCartValue,
    deliveryRadius,
    deliveryFee,
    deliveryFeeTier1,
    deliveryThresholdTier1,
    deliveryFeeTier2,
    deliveryThresholdTier2,
    deliveryFeeTier3,
    deliveryThresholdTier3,
    deliveryFeePerKmBeyond5km,
    groceryFreeDeliveryThreshold,
    miscFee,
    storeHubName,
  ])

  return (
    <div className="space-y-6 animate-fade-in text-left">
      
      {/* ── SECTION 1: Distance-Based Delivery Fee Tiers ── */}
      <div className="bg-card border border-border/80 p-5 rounded-3xl shadow-xs space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-border/60 pb-3">
          <div>
            <h4 className="text-sm font-black text-text-primary flex items-center gap-2">
              <Truck className="w-4 h-4 text-primary" />
              <span>Distance-Based Delivery Slabs (दूरी के अनुसार डिलीवरी दरें)</span>
            </h4>
            <p className="text-xs text-text-secondary mt-0.5 font-medium">
              Configure tiered delivery fees and free delivery cart thresholds based on radial customer distance from <strong>{storeHubName || 'this Darkstore'}</strong>.
            </p>
          </div>
          <span className="text-[10px] font-mono font-black uppercase px-2.5 py-1 rounded-lg bg-primary/10 text-primary border border-primary/20 shrink-0 self-start sm:self-auto">
            Store: {storeId || 'Current Hub'}
          </span>
        </div>

        {/* 4 Distance Slabs Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3.5">
          
          {/* Zone 1: 0 - 2.0 km */}
          <div className="bg-emerald-500/5 border border-emerald-500/20 p-4 rounded-2xl space-y-3 relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <span>🟢 Zone 1</span>
                <span className="text-[10px] text-text-secondary font-normal">(0 - 2 km)</span>
              </span>
              <span className="text-[9.5px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-600">
                Local
              </span>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Delivery Fee (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryFeeTier1}
                  onChange={(e) => setDeliveryFeeTier1(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="25"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Free Delivery Above (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryThresholdTier1}
                  onChange={(e) => setDeliveryThresholdTier1(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="199"
                />
              </div>
            </div>
          </div>

          {/* Zone 2: 2.0 - 3.0 km */}
          <div className="bg-amber-500/5 border border-amber-500/20 p-4 rounded-2xl space-y-3 relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-amber-600 dark:text-amber-400 flex items-center gap-1">
                <span>🟡 Zone 2</span>
                <span className="text-[10px] text-text-secondary font-normal">(2 - 3 km)</span>
              </span>
              <span className="text-[9.5px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-600">
                Suburban
              </span>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Delivery Fee (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryFeeTier2}
                  onChange={(e) => setDeliveryFeeTier2(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="35"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Free Delivery Above (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryThresholdTier2}
                  onChange={(e) => setDeliveryThresholdTier2(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="299"
                />
              </div>
            </div>
          </div>

          {/* Zone 3: 3.0 - 5.0 km */}
          <div className="bg-indigo-500/5 border border-indigo-500/20 p-4 rounded-2xl space-y-3 relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-indigo-600 dark:text-indigo-400 flex items-center gap-1">
                <span>🔵 Zone 3</span>
                <span className="text-[10px] text-text-secondary font-normal">(3 - 5 km)</span>
              </span>
              <span className="text-[9.5px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded bg-indigo-500/10 text-indigo-600">
                Extended
              </span>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Delivery Fee (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryFeeTier3}
                  onChange={(e) => setDeliveryFeeTier3(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="50"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Free Delivery Above (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryThresholdTier3}
                  onChange={(e) => setDeliveryThresholdTier3(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="399"
                />
              </div>
            </div>
          </div>

          {/* Zone 4: Long Distance Beyond 5 km */}
          <div className="bg-purple-500/5 border border-purple-500/20 p-4 rounded-2xl space-y-3 relative overflow-hidden">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-purple-600 dark:text-purple-400 flex items-center gap-1">
                <span>🟣 Beyond 5 km</span>
                <span className="text-[10px] text-text-secondary font-normal">(&gt;5 km)</span>
              </span>
              <span className="text-[9.5px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded bg-purple-500/10 text-purple-600">
                Per-Km Extra
              </span>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Extra Charge / Km (₹/km) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={deliveryFeePerKmBeyond5km || '10'}
                  onChange={(e) => setDeliveryFeePerKmBeyond5km(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="10"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Max Service Radius (km) *
              </label>
              <div className="relative">
                <MapPin className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="number"
                  min="1"
                  max="30"
                  step="0.5"
                  required
                  value={deliveryRadius}
                  onChange={(e) => setDeliveryRadius(e.target.value)}
                  className="w-full bg-background border border-border pl-7 pr-3 py-1.5 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="5"
                />
              </div>
            </div>
          </div>

        </div>
      </div>

      {/* ── SECTION 2: Interactive Live Rate Simulator & Testing Widget ── */}
      <div className="bg-gradient-to-br from-primary/5 via-card to-card border-2 border-primary/20 p-5 rounded-3xl shadow-xs space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-black">
              <Calculator className="w-4 h-4" />
            </div>
            <div>
              <h4 className="text-xs sm:text-sm font-black text-text-primary flex items-center gap-1.5">
                <span>Interactive Delivery Rate Simulator</span>
                <span className="text-[9.5px] font-bold px-2 py-0.5 rounded-full bg-primary/10 text-primary uppercase">
                  Live Test
                </span>
              </h4>
              <p className="text-[11px] text-text-secondary">
                Test any customer distance & cart value to preview the exact delivery fee, zone, and checkout breakdown before saving.
              </p>
            </div>
          </div>
        </div>

        {/* Inputs & Live Breakdown */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
          
          {/* Inputs (5 cols) */}
          <div className="lg:col-span-5 grid grid-cols-2 gap-3 bg-muted/30 p-3.5 rounded-2xl border border-border/60">
            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Test Distance (km)
              </label>
              <input
                type="number"
                step="0.1"
                min="0.1"
                value={testDistanceKm}
                onChange={(e) => setTestDistanceKm(e.target.value)}
                className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                placeholder="2.5"
              />
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Test Cart Value (₹)
              </label>
              <input
                type="number"
                min="0"
                value={testCartValue}
                onChange={(e) => setTestCartValue(e.target.value)}
                className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                placeholder="150"
              />
            </div>
          </div>

          {/* Arrow (1 col) */}
          <div className="hidden lg:flex lg:col-span-1 justify-center text-text-muted">
            <ArrowRight className="w-5 h-5" />
          </div>

          {/* Results Display (6 cols) */}
          <div className="lg:col-span-6 bg-card border border-border/80 p-4 rounded-2xl shadow-2xs space-y-2.5">
            <div className="flex items-center justify-between border-b border-border/50 pb-2">
              <span className="text-xs font-bold text-text-secondary">
                Matched Zone:
              </span>
              <span className={`text-xs font-black px-2 py-0.5 rounded-lg ${
                simulatedRules.rules.isServiceable
                  ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                  : 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
              }`}>
                {simulatedRules.rules.zoneName}
              </span>
            </div>

            <div className="grid grid-cols-3 gap-2 text-center pt-1">
              <div className="p-2 rounded-xl bg-muted/40 border border-border/50">
                <p className="text-[9.5px] font-bold text-text-secondary">Delivery Fee</p>
                <p className={`text-sm font-black mt-0.5 ${simulatedRules.isFree ? 'text-emerald-600 line-through' : 'text-text-primary'}`}>
                  {formatPrice(simulatedRules.rules.deliveryFee)}
                </p>
                {simulatedRules.isFree && (
                  <span className="text-[9px] font-black text-emerald-600 uppercase">FREE 🎁</span>
                )}
              </div>

              <div className="p-2 rounded-xl bg-muted/40 border border-border/50">
                <p className="text-[9.5px] font-bold text-text-secondary">Packaging Fee</p>
                <p className="text-sm font-black text-text-primary mt-0.5">
                  {formatPrice(simulatedRules.packFee)}
                </p>
                <span className="text-[9px] text-text-muted font-bold truncate block">{miscFeeLabel || 'Eco-Pack'}</span>
              </div>

              <div className="p-2 rounded-xl bg-primary/10 border border-primary/20">
                <p className="text-[9.5px] font-bold text-primary">Customer Total</p>
                <p className="text-sm font-black text-primary mt-0.5">
                  {formatPrice(simulatedRules.totalPayable)}
                </p>
                <span className="text-[9px] text-primary/80 font-bold block">All-Inclusive</span>
              </div>
            </div>

            {simulatedRules.rules.isServiceable && !simulatedRules.isFree && (
              <p className="text-[10px] text-amber-600 dark:text-amber-400 font-semibold bg-amber-500/10 p-1.5 rounded-lg text-center">
                💡 Add {formatPrice(simulatedRules.amountNeededForFreeDelivery)} more items to unlock FREE delivery in this zone.
              </p>
            )}
          </div>

        </div>
      </div>

      {/* ── SECTION 3: Order Thresholds, Packaging & Doorstep UPI ── */}
      <div className="bg-card border border-border/80 p-5 rounded-3xl shadow-xs space-y-4">
        <h4 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5 border-b border-border/60 pb-2.5">
          <IndianRupee className="w-3.5 h-3.5 text-primary" />
          Order Thresholds, Packaging & Doorstep UPI
        </h4>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
          
          {/* ─ Left Column: Order Value Thresholds ─ */}
          <div className="space-y-3">
            {/* Minimum Order Value */}
            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Minimum Cart Value (₹) *
              </label>
              <div className="relative">
                <IndianRupee className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                <input
                  type="number"
                  min="0"
                  required
                  value={minOrderValue}
                  onChange={(e) => setMinOrderValue(e.target.value)}
                  className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                  placeholder="0"
                />
              </div>
              <p className="text-[9.5px] text-text-muted font-medium">
                Orders below this amount will not be allowed to proceed to checkout (0 = no minimum).
              </p>
            </div>
          </div>

          {/* ─ Right Column: Packaging & UPI ─ */}
          <div className="space-y-3">
            {/* Packaging / Misc Fee */}
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                  Packaging Fee (₹) *
                </label>
                <div className="relative">
                  <IndianRupee className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    required
                    value={miscFee}
                    onChange={(e) => setMiscFee(e.target.value)}
                    className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs font-black focus:outline-none focus:border-primary"
                    placeholder="0"
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                  Display Label *
                </label>
                <input
                  type="text"
                  required
                  value={miscFeeLabel}
                  onChange={(e) => setMiscFeeLabel(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs font-bold focus:outline-none focus:border-primary"
                  placeholder="Packaging Fee"
                />
              </div>
            </div>

            {/* Store UPI VPA */}
            <div className="space-y-1">
              <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
                Store UPI VPA / QR Handle (दुकान का UPI ID) *
              </label>
              <input
                type="text"
                required
                value={storeUpiVpa}
                onChange={(e) => setStoreUpiVpa(e.target.value)}
                className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs font-mono font-black text-emerald-600 dark:text-emerald-400 focus:outline-none focus:border-primary"
                placeholder="7054470303@paytm or fastkirana@upi"
              />
              <p className="text-[9.5px] text-text-muted font-medium">
                Generates the dynamic QR scanner for delivery riders at doorstep for customer payments.
              </p>
            </div>
          </div>

        </div>
      </div>

    </div>
  )
}
