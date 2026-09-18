'use client'

import React from 'react'
import { Clock, TrendingUp, Tag, Percent, Phone, Mail } from 'lucide-react'

interface RestaurantTimingScheduleProps {
  formData: any
  setFormData: React.Dispatch<React.SetStateAction<any>>
  handleChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => void
  isAdmin: boolean
}

const inputClass = "w-full px-3.5 py-2.5 text-sm font-semibold bg-background border border-border rounded-xl outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all placeholder:text-text-secondary/40"

export function RestaurantTimingSchedule({
  formData,
  setFormData,
  handleChange,
  isAdmin,
}: RestaurantTimingScheduleProps) {
  return (
    <div className="space-y-6">
      {/* 4. OPERATIONS & TIMING */}
      <div id="sec-hours" className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
        <div className="p-4 border-b border-border/60 bg-gradient-to-r from-amber-500/10 via-amber-500/5 to-amber-500/0 flex items-center gap-3">
          <div className="h-9 w-9 rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm flex items-center justify-center shadow-sm">
            <Clock className="h-4.5 w-4.5 text-text-primary" />
          </div>
          <div>
            <h2 className="font-black text-sm text-text-primary tracking-wide">Operations & Timings</h2>
            <p className="text-[10px] text-text-secondary font-medium">Operating hours & automated schedule</p>
          </div>
        </div>
        <div className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div className="space-y-1.5">
              <label htmlFor="openTime" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Opens At
              </label>
              <input
                id="openTime"
                name="openTime"
                type="time"
                value={formData.openTime}
                onChange={handleChange}
                className={inputClass}
              />
            </div>

            <div className="space-y-1.5">
              <label htmlFor="closeTime" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Closes At
              </label>
              <input
                id="closeTime"
                name="closeTime"
                type="time"
                value={formData.closeTime}
                onChange={handleChange}
                className={inputClass}
              />
            </div>
          </div>

          {/* Operating Hours Presets */}
          <div className="mt-4 pt-3 border-t border-border/40 flex flex-wrap items-center gap-1.5">
            <span className="text-[10px] font-bold text-text-secondary">Quick Timings:</span>
            <button
              type="button"
              onClick={() => setFormData((prev: any) => ({ ...prev, openTime: '09:00', closeTime: '22:00' }))}
              className="px-2.5 py-1 bg-muted hover:bg-muted/80 rounded-lg text-[10px] font-bold border border-border cursor-pointer transition-all active:scale-95"
            >
              ☀️ 09:00 AM - 10:00 PM
            </button>
            <button
              type="button"
              onClick={() => setFormData((prev: any) => ({ ...prev, openTime: '10:00', closeTime: '23:00' }))}
              className="px-2.5 py-1 bg-muted hover:bg-muted/80 rounded-lg text-[10px] font-bold border border-border cursor-pointer transition-all active:scale-95"
            >
              🌙 10:00 AM - 11:00 PM
            </button>
            <button
              type="button"
              onClick={() => setFormData((prev: any) => ({ ...prev, openTime: '00:00', closeTime: '23:59' }))}
              className="px-2.5 py-1 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-500/20 rounded-lg text-[10px] font-bold border border-emerald-500/20 cursor-pointer transition-all active:scale-95"
            >
              ⚡ 24 Hours Open
            </button>
          </div>

          {/* Visual Operating Hours Bar */}
          {formData.openTime && formData.closeTime && (
            <div className="mt-4 pt-4 border-t border-border/40">
              <p className="text-[10px] font-bold text-text-secondary uppercase tracking-wider mb-3">Operating Hours Visual</p>
              <div className="relative h-8 bg-muted/30 rounded-full border border-border overflow-hidden">
                {(() => {
                  const openParts = formData.openTime.split(':')
                  const closeParts = formData.closeTime.split(':')
                  const openHour = parseInt(openParts[0]) + parseInt(openParts[1]) / 60
                  const closeHour = parseInt(closeParts[0]) + parseInt(closeParts[1]) / 60
                  const left = (openHour / 24) * 100
                  const width = ((closeHour > openHour ? closeHour - openHour : 24 - openHour + closeHour) / 24) * 100
                  return (
                    <div
                      className="absolute h-full bg-gradient-to-r from-emerald-500/30 to-emerald-400/20 border-l-2 border-r-2 border-emerald-500 flex items-center justify-center"
                      style={{ left: `${left}%`, width: `${width}%` }}
                    >
                      <span className="text-[9px] font-black text-emerald-700 dark:text-emerald-400 whitespace-nowrap">
                        {formData.openTime} — {formData.closeTime}
                      </span>
                    </div>
                  )
                })()}
                {/* Hour markers */}
                <div className="absolute bottom-0 left-0 w-full flex justify-between px-1">
                  {[0, 6, 12, 18, 24].map(h => (
                    <span key={h} className="text-[7px] text-text-secondary/40 font-bold">{h === 24 ? '0' : h}h</span>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* 5. OFFERS & BUSINESS */}
      <div className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
        <div className="p-4 border-b border-border/60 bg-gradient-to-r from-rose-500/10 via-rose-500/5 to-rose-500/0 flex items-center gap-3">
          <div className="h-9 w-9 rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm flex items-center justify-center shadow-sm">
            <TrendingUp className="h-4.5 w-4.5 text-text-primary" />
          </div>
          <div>
            <h2 className="font-black text-sm text-text-primary tracking-wide">Business & Offers</h2>
            <p className="text-[10px] text-text-secondary font-medium">Commission, discount offers and ranking</p>
          </div>
        </div>
        <div className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div className="space-y-1.5">
              <label htmlFor="discountOffer" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Main Offer Text
              </label>
              <div className="relative">
                <Tag className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
                <input
                  id="discountOffer"
                  name="discountOffer"
                  value={formData.discountOffer}
                  onChange={handleChange}
                  placeholder="e.g. 40% OFF UPTO ₹200"
                  className={`${inputClass} pl-10`}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <label htmlFor="discountBadge" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Sub Offer Badge
              </label>
              <input
                id="discountBadge"
                name="discountBadge"
                value={formData.discountBadge}
                onChange={handleChange}
                placeholder="e.g. Free Delivery"
                className={inputClass}
              />
            </div>

            <div className="space-y-1.5">
              <label htmlFor="commissionRate" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Commission Rate
              </label>
              {isAdmin ? (
                <>
                  <div className="relative">
                    <Percent className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
                    <input
                      id="commissionRate"
                      name="commissionRate"
                      type="number"
                      step="0.01"
                      min="0"
                      max="1"
                      value={formData.commissionRate}
                      onChange={handleChange}
                      placeholder="e.g. 0.15 for 15%"
                      className={`${inputClass} pl-10`}
                    />
                  </div>
                  <p className="text-[9px] text-text-secondary mt-1">Managed strictly by Admin (Enter 0.15 for 15%)</p>
                </>
              ) : (
                <div className="px-3.5 py-2.5 bg-amber-500/10 border border-amber-500/20 rounded-xl flex items-center justify-between text-xs font-black">
                  <span className="flex items-center gap-1.5 text-amber-700 dark:text-amber-400">
                    🔒 {((parseFloat(formData.commissionRate) || 0.15) * 100).toFixed(0)}% Platform Commission
                  </span>
                  <span className="text-[10px] text-amber-600/80 font-semibold">Admin Managed</span>
                </div>
              )}
            </div>

            <div className="space-y-1.5">
              <label htmlFor="sortOrder" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Sort Order (Listing Position)
              </label>
              <input
                id="sortOrder"
                name="sortOrder"
                type="number"
                value={formData.sortOrder}
                onChange={handleChange}
                placeholder="0"
                className={inputClass}
              />
              <p className="text-[9px] text-text-secondary mt-1">Lower number = higher position in listing</p>
            </div>
          </div>

          {/* Owner Contact */}
          <div className="border-t border-border/40 pt-5 mt-5">
            <p className="text-[11px] font-bold uppercase tracking-wider text-text-secondary mb-4">Owner Direct Contact</p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div className="space-y-1.5">
                <label htmlFor="ownerPhone" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                  Owner Phone
                </label>
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
                  <input
                    id="ownerPhone"
                    name="ownerPhone"
                    value={formData.ownerPhone}
                    onChange={handleChange}
                    placeholder="+91 98765 43210"
                    className={`${inputClass} pl-10`}
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <label htmlFor="ownerEmail" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                  Owner Email
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
                  <input
                    id="ownerEmail"
                    name="ownerEmail"
                    type="email"
                    value={formData.ownerEmail}
                    onChange={handleChange}
                    placeholder="owner@restaurant.com"
                    className={`${inputClass} pl-10`}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
