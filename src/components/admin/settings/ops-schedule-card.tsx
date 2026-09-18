'use client'

import React from 'react'
import { Clock, Utensils, Shield, ShieldCheck, Truck, MapPin, Phone, Mail, Compass, Sparkles } from 'lucide-react'

interface OpsScheduleCardProps {
  // Grocery timings
  groceryAutoTiming: boolean
  setGroceryAutoTiming: (v: boolean) => void
  groceryOpenTime: string
  setGroceryOpenTime: (v: string) => void
  groceryCloseTime: string
  setGroceryCloseTime: (v: string) => void
  isGroceryCurrentlyOpen: boolean

  // Restaurant timings
  restaurantAutoTiming: boolean
  setRestaurantAutoTiming: (v: boolean) => void
  restaurantOpenTime: string
  setRestaurantOpenTime: (v: string) => void
  restaurantCloseTime: string
  setRestaurantCloseTime: (v: string) => void
  isRestaurantCurrentlyOpen: boolean
  setCafeAutoTiming: (v: boolean) => void
  setCafeOpenTime: (v: string) => void
  setCafeCloseTime: (v: string) => void

  // Admin order approval gate
  adminAutoApproveOrders: boolean
  setAdminAutoApproveOrders: (v: boolean) => void

  // Delivery & Location
  onlyCod: boolean
  setOnlyCod: (v: boolean) => void
  deliveryRadius: string
  setDeliveryRadius: (v: string) => void
  storeLat: string
  setStoreLat: (v: string) => void
  storeLng: string
  setStoreLng: (v: string) => void

  // Contacts & Address
  contactPhone: string
  setContactPhone: (v: string) => void
  contactEmail: string
  setContactEmail: (v: string) => void
  contactTimings: string
  setContactTimings: (v: string) => void
  contactAddress: string
  setContactAddress: (v: string) => void
  groceryPickupAddress: string
  setGroceryPickupAddress: (v: string) => void
}

export function OpsScheduleCard({
  groceryAutoTiming,
  setGroceryAutoTiming,
  groceryOpenTime,
  setGroceryOpenTime,
  groceryCloseTime,
  setGroceryCloseTime,
  isGroceryCurrentlyOpen,
  restaurantAutoTiming,
  setRestaurantAutoTiming,
  restaurantOpenTime,
  setRestaurantOpenTime,
  restaurantCloseTime,
  setRestaurantCloseTime,
  isRestaurantCurrentlyOpen,
  setCafeAutoTiming,
  setCafeOpenTime,
  setCafeCloseTime,
  adminAutoApproveOrders,
  setAdminAutoApproveOrders,
  onlyCod,
  setOnlyCod,
  deliveryRadius,
  setDeliveryRadius,
  storeLat,
  setStoreLat,
  storeLng,
  setStoreLng,
  contactPhone,
  setContactPhone,
  contactEmail,
  setContactEmail,
  contactTimings,
  setContactTimings,
  contactAddress,
  setContactAddress,
  groceryPickupAddress,
  setGroceryPickupAddress,
}: OpsScheduleCardProps) {
  return (
    <div className="w-full space-y-6 animate-fade-in text-left">
      {/* ── SECTION 1: Automated Store Timings (Side-by-side) ── */}
      <div className="w-full">
        <h4 className="text-xs font-black text-text-primary uppercase tracking-wider mb-3 flex items-center gap-1.5">
          <Clock className="h-4 w-4 text-primary" />
          Automated Operating Schedules
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
          {/* Grocery Mart Schedule Card */}
          <div className="w-full min-w-0 bg-muted/20 p-4 sm:p-5 rounded-2xl border border-border/60 space-y-3.5">
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5 truncate">
                  🏪 Grocery Mart Schedule
                </label>
                <p className="text-[11px] text-text-secondary mt-0.5 font-medium truncate">
                  Store timings ke hisaab se rozana automatic ON/OFF.
                </p>
              </div>
              <span
                className={`text-[11px] font-black px-2.5 py-1 rounded-full border shrink-0 ${
                  isGroceryCurrentlyOpen
                    ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                    : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
                }`}
              >
                {isGroceryCurrentlyOpen ? '● OPEN' : '○ CLOSED'}
              </span>
            </div>

            <div className="bg-primary/5 border border-primary/20 rounded-xl p-3 flex items-start gap-2.5">
              <Sparkles className="h-4 w-4 text-primary shrink-0 mt-0.5" />
              <div className="text-xs min-w-0">
                <p className="font-bold text-text-primary">
                  {groceryAutoTiming ? 'Auto-Schedule Active (Roj Automatic On/Off)' : 'Manual Override Active'}
                </p>
                <p className="text-[11px] text-text-secondary mt-0.5 leading-relaxed">
                  {groceryAutoTiming
                    ? `Store subah ${groceryOpenTime || '07:00'} baje apne aap khulega aur raat ${groceryCloseTime || '22:00'} baje band hoga. Roj manually ON karne ki zaroorat nahi hai.`
                    : 'Auto-timing off hai. Store manual switch par chal raha hai.'}
                </p>
              </div>
            </div>

            <div className="pt-2 border-t border-border/40 space-y-3">
              <div className="flex items-center justify-between">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
                  <Clock className="h-3 w-3" /> Operating Hours
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer text-[10px] font-bold text-text-secondary select-none">
                  <input
                    type="checkbox"
                    checked={groceryAutoTiming}
                    onChange={(e) => setGroceryAutoTiming(e.target.checked)}
                    className="rounded border-border text-primary focus:ring-primary h-3.5 w-3.5 cursor-pointer"
                  />
                  <span>Auto-timing apply</span>
                </label>
              </div>

              <div className="grid grid-cols-2 gap-2.5">
                <div className="space-y-1">
                  <span className="text-[10px] font-bold text-text-muted block">Open Time (Subah)</span>
                  <input
                    type="time"
                    value={groceryOpenTime}
                    onChange={(e) => setGroceryOpenTime(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
                  />
                </div>
                <div className="space-y-1">
                  <span className="text-[10px] font-bold text-text-muted block">Close Time (Raat)</span>
                  <input
                    type="time"
                    value={groceryCloseTime}
                    onChange={(e) => setGroceryCloseTime(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Restaurant & Cafe Schedule Card */}
          <div className="w-full min-w-0 bg-muted/20 p-4 sm:p-5 rounded-2xl border border-border/60 space-y-3.5">
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5 truncate">
                  <Utensils className="h-3.5 w-3.5 text-orange-500" /> Restaurant & Cafe Schedule
                </label>
                <p className="text-[11px] text-text-secondary mt-0.5 font-medium truncate">
                  Outlets subah timely automatic ON honge aur raat ko OFF.
                </p>
              </div>
              <span
                className={`text-[11px] font-black px-2.5 py-1 rounded-full border shrink-0 ${
                  isRestaurantCurrentlyOpen
                    ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                    : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
                }`}
              >
                {isRestaurantCurrentlyOpen ? '● OPEN' : '○ CLOSED'}
              </span>
            </div>

            <div className="bg-orange-500/5 border border-orange-500/20 rounded-xl p-3 flex items-start gap-2.5">
              <Sparkles className="h-4 w-4 text-orange-500 shrink-0 mt-0.5" />
              <div className="text-xs min-w-0">
                <p className="font-bold text-text-primary">
                  {restaurantAutoTiming ? 'Auto-Schedule Active (Roj Timely On/Off)' : 'Manual Override Active'}
                </p>
                <p className="text-[11px] text-text-secondary mt-0.5 leading-relaxed">
                  {restaurantAutoTiming
                    ? `Restaurants subah ${restaurantOpenTime || '10:00'} baje automatically open honge aur raat ${restaurantCloseTime || '22:00'} baje band honge. Roj subah manually ON karne ki zaroorat nahi hai.`
                    : 'Auto-timing off hai. Outlets manual switch par chal rahe hain.'}
                </p>
              </div>
            </div>

            <div className="pt-2 border-t border-border/40 space-y-3">
              <div className="flex items-center justify-between">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
                  <Clock className="h-3 w-3" /> Operating Hours
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer text-[10px] font-bold text-text-secondary select-none">
                  <input
                    type="checkbox"
                    checked={restaurantAutoTiming}
                    onChange={(e) => {
                      const checked = e.target.checked
                      setRestaurantAutoTiming(checked)
                      setCafeAutoTiming(checked)
                    }}
                    className="rounded border-border text-primary focus:ring-primary h-3.5 w-3.5 cursor-pointer"
                  />
                  <span>Auto-timing apply</span>
                </label>
              </div>

              <div className="grid grid-cols-2 gap-2.5">
                <div className="space-y-1">
                  <span className="text-[10px] font-bold text-text-muted block">Open Time (Subah)</span>
                  <input
                    type="time"
                    value={restaurantOpenTime}
                    onChange={(e) => {
                      setRestaurantOpenTime(e.target.value)
                      setCafeOpenTime(e.target.value)
                    }}
                    className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
                  />
                </div>
                <div className="space-y-1">
                  <span className="text-[10px] font-bold text-text-muted block">Close Time (Raat)</span>
                  <input
                    type="time"
                    value={restaurantCloseTime}
                    onChange={(e) => {
                      setRestaurantCloseTime(e.target.value)
                      setCafeCloseTime(e.target.value)
                    }}
                    className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ── SECTION 2: Admin Order Approval Gate (Full Width Standalone Card) ── */}
      <div className="w-full bg-muted/20 p-4 sm:p-5 rounded-2xl border border-border/60 space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div className="min-w-0">
            <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
              <Shield className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
              Admin Order Approval Gate
            </label>
            <p className="text-[11px] text-text-secondary font-medium mt-0.5">
              {adminAutoApproveOrders
                ? 'Orders direct kitchen/rider consoles pe chale jayenge bina admin approval ke.'
                : 'Har naya order pehle "Awaiting Approval" me aayega aur admin ke phone par loud alarm bajega. Admin ke approve karne ke baad hi kitchen/delivery ko order dikhega.'}
            </p>
          </div>
          <span
            className={`text-[10px] font-black px-2.5 py-1 rounded-md border shrink-0 ${
              adminAutoApproveOrders
                ? 'bg-amber-500/10 text-amber-600 border-amber-500/30'
                : 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30'
            }`}
          >
            {adminAutoApproveOrders ? '⚡ AUTO-APPROVE' : '🛡️ MANUAL REVIEW'}
          </span>
        </div>

        <div className="pt-1">
          <select
            value={adminAutoApproveOrders ? 'true' : 'false'}
            onChange={(e) => setAdminAutoApproveOrders(e.target.value === 'true')}
            className="w-full bg-background border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer shadow-xs text-text-primary"
          >
            <option value="false">🛡️ Manual Approval Required (Recommended — Rings Admin Alarm)</option>
            <option value="true">⚡ Auto-Approve Orders (Skip Approval Gate)</option>
          </select>
        </div>
      </div>

      {/* ── SECTION 3: Operations & Geofencing Parameters ── */}
      <div className="w-full bg-muted/20 p-4 sm:p-5 rounded-2xl border border-border/60 space-y-4">
        <h4 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
          <Truck className="h-4 w-4 text-primary" />
          Delivery & Geofence Settings
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
          {/* Cash on Delivery Only */}
          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Only Cash on Delivery</label>
            <select
              value={onlyCod ? 'true' : 'false'}
              onChange={(e) => setOnlyCod(e.target.value === 'true')}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer shadow-xs"
            >
              <option value="false">🔴 Off (All Payments Enabled)</option>
              <option value="true">🟢 On (COD/COP Only)</option>
            </select>
          </div>

          {/* Delivery Radius */}
          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Delivery Radius (km) *</label>
            <input
              type="number"
              required
              min="1"
              max="100"
              placeholder="e.g. 5"
              value={deliveryRadius}
              onChange={(e) => setDeliveryRadius(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>

          {/* Store Latitude */}
          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
              <Compass className="h-3 w-3" /> Store Latitude (GPS) *
            </label>
            <input
              type="text"
              required
              placeholder="e.g. 26.1534185"
              value={storeLat}
              onChange={(e) => setStoreLat(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>

          {/* Store Longitude */}
          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
              <Compass className="h-3 w-3" /> Store Longitude (GPS) *
            </label>
            <input
              type="text"
              required
              placeholder="e.g. 80.1714024"
              value={storeLng}
              onChange={(e) => setStoreLng(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>
        </div>
      </div>

      {/* ── SECTION 4: Contact Details & Fulfillment Addresses ── */}
      <div className="w-full bg-muted/20 p-4 sm:p-5 rounded-2xl border border-border/60 space-y-4">
        <h4 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
          <MapPin className="h-4 w-4 text-primary" />
          Store Contact & Pickup Addresses
        </h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
              <Phone className="h-3 w-3" /> Contact Phone *
            </label>
            <input
              type="text"
              required
              value={contactPhone}
              onChange={(e) => setContactPhone(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
              <Mail className="h-3 w-3" /> Contact Email *
            </label>
            <input
              type="email"
              required
              value={contactEmail}
              onChange={(e) => setContactEmail(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1">
              <Clock className="h-3 w-3" /> Contact Timings *
            </label>
            <input
              type="text"
              required
              value={contactTimings}
              onChange={(e) => setContactTimings(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Fulfillment Address *</label>
            <textarea
              required
              rows={2}
              value={contactAddress}
              onChange={(e) => setContactAddress(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Grocery Pickup Address *</label>
            <textarea
              required
              rows={2}
              value={groceryPickupAddress}
              onChange={(e) => setGroceryPickupAddress(e.target.value)}
              className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
            />
          </div>
        </div>
      </div>
    </div>
  )
}
