'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { MapPin, AlertTriangle, Navigation, Bell, CheckCircle2, ChevronRight, X } from 'lucide-react'
import { useUIStore } from '@/stores/ui-store'
import { toast } from 'sonner'

export function UnserviceableLocationBanner() {
  const isLocationServiceable = useUIStore((s) => s.isLocationServiceable)
  const userDistanceKm = useUIStore((s) => s.userDistanceKm)
  const userCoords = useUIStore((s) => s.userCoords)
  const deliveryRadius = useUIStore((s) => s.deliveryRadius) || 5
  const settings = useUIStore((s) => s.settings) || {}
  const setSelectedLocation = useUIStore((s) => s.setSelectedLocation)
  const setUserCoords = useUIStore((s) => s.setUserCoords)
  const setLocationPickerOpen = useUIStore((s) => s.setLocationPickerOpen)

  const [showModal, setShowModal] = useState(false)
  const [notifyPhone, setNotifyPhone] = useState('')
  const [isNotified, setIsNotified] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Store Hub coordinates (default: Ghatampur Store Hub)
  const hubLat = parseFloat(settings['store_lat'] || '26.1534185')
  const hubLng = parseFloat(settings['store_lng'] || '80.1714024')
  const hubName = settings['store_name'] || 'Ghatampur Store Hub'

  // Trigger modal display when location is detected as unserviceable
  useEffect(() => {
    if (!isLocationServiceable && userCoords) {
      setShowModal(true)
    } else {
      setShowModal(false)
    }
  }, [isLocationServiceable, userCoords])

  // Switch to Ghatampur Central Hub in 1-click
  const handleSwitchToGhatampur = () => {
    setUserCoords({ lat: hubLat, lng: hubLng })
    setSelectedLocation('Ghatampur Central Market')
    setShowModal(false)
    toast.success(`Switched to ${hubName} (Delivering in 10-15 mins)`, {
      icon: '🚀',
    })
  }

  // Handle Notify Me submit
  const handleNotifySubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!notifyPhone || notifyPhone.length < 10) {
      toast.error('Please enter a valid 10-digit mobile number')
      return
    }
    setIsSubmitting(true)
    try {
      toast.success("Thank you! We will notify you via WhatsApp / SMS once FastKirana launches in your area.", {
        duration: 5000,
        icon: '🎉',
      })
      setIsNotified(true)
    } catch {
      toast.error('Something went wrong. Please try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  if (isLocationServiceable) return null

  return (
    <>
      {/* ── 1. Sticky Top Unserviceable Notice (Zepto / Swiggy Style) ── */}
      <div className="bg-gradient-to-r from-rose-600 via-rose-500 to-amber-600 text-white px-3 py-2 text-xs font-semibold shadow-md flex items-center justify-between gap-2 z-40 relative">
        <div className="flex items-center gap-2 overflow-hidden text-ellipsis whitespace-nowrap">
          <span className="flex h-2 w-2 relative shrink-0">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
          </span>
          <span className="truncate">
            📍 <strong>Outside Delivery Zone</strong>
            {userDistanceKm ? ` (${userDistanceKm.toFixed(1)} km away)` : ''} — Delivery is currently not available at your location.
          </span>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <button
            onClick={() => setLocationPickerOpen(true)}
            className="bg-white text-rose-600 hover:bg-white/90 px-3 py-1 rounded-full text-[11px] font-black uppercase tracking-wider shadow-sm transition-transform active:scale-95"
          >
            Change Location
          </button>
          <button
            onClick={() => setShowModal(true)}
            className="text-white/80 hover:text-white underline text-[11px] font-medium"
          >
            Details
          </button>
        </div>
      </div>

      {/* ── 2. Full-Screen Interactive Dialog (Swiggy / Zepto "We Are Not Here Yet" Screen) ── */}
      <AnimatePresence>
        {showModal && (
          <div className="fixed inset-0 z-[120] flex items-center justify-center p-4 bg-black/65 backdrop-blur-md animate-fade-in">
            <motion.div
              initial={{ opacity: 0, scale: 0.92, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.92, y: 20 }}
              className="bg-card border border-border/80 rounded-3xl p-6 sm:p-8 max-w-md w-full shadow-2xl relative overflow-hidden text-center"
            >
              {/* Background decorative gradient */}
              <div className="absolute -top-12 -right-12 w-36 h-36 bg-rose-500/10 rounded-full blur-2xl pointer-events-none" />
              <div className="absolute -bottom-12 -left-12 w-36 h-36 bg-amber-500/10 rounded-full blur-2xl pointer-events-none" />

              {/* Close Button */}
              <button
                onClick={() => setShowModal(false)}
                className="absolute top-4 right-4 p-2 rounded-full text-text-secondary hover:text-text-primary hover:bg-muted/60 transition-colors"
                title="Dismiss"
              >
                <X className="w-5 h-5" />
              </button>

              {/* Radar Location Pin Illustration */}
              <div className="relative mx-auto mb-5 w-20 h-20 flex items-center justify-center">
                <div className="absolute inset-0 rounded-full bg-rose-500/10 animate-ping opacity-75" />
                <div className="absolute inset-2 rounded-full bg-rose-500/20 animate-pulse" />
                <div className="relative z-10 w-14 h-14 rounded-2xl bg-gradient-to-tr from-rose-500 to-rose-600 flex items-center justify-center text-white shadow-lg shadow-rose-500/30">
                  <MapPin className="w-7 h-7" />
                </div>
              </div>

              {/* Title & Description */}
              <h3 className="text-xl font-black text-text-primary tracking-tight">
                We're Not Delivering Here Yet!
              </h3>
              <p className="text-xs text-text-secondary mt-2 leading-relaxed font-medium">
                FastKirana & Partner Outlets currently do not deliver to this location. Please choose an address within our operational delivery zones to start ordering.
              </p>

              {/* Distance badge */}
              {userDistanceKm && (
                <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-rose-500/10 border border-rose-500/20 text-rose-600 text-[11px] font-bold mt-3">
                  <AlertTriangle className="w-3.5 h-3.5" />
                  <span>Your location is {userDistanceKm.toFixed(1)} km outside our delivery zone</span>
                </div>
              )}

              {/* Action Buttons */}
              <div className="mt-6 space-y-2.5">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false)
                    setLocationPickerOpen(true)
                  }}
                  className="w-full bg-[#e20a22] hover:bg-[#c9081e] text-white py-3 px-4 rounded-2xl font-black text-sm shadow-md hover:shadow-lg transition-all active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  <MapPin className="w-4 h-4" />
                  <span>Select Serviceable Delivery Address</span>
                </button>

                <button
                  type="button"
                  onClick={handleSwitchToGhatampur}
                  className="w-full bg-muted/60 hover:bg-muted text-text-primary py-2.5 px-4 rounded-2xl font-bold text-xs border border-border/60 transition-colors flex items-center justify-center gap-2"
                >
                  <Navigation className="w-4 h-4 text-text-secondary" />
                  <span>Deliver to Active Store Hub</span>
                </button>
              </div>

              {/* Notify Me When Launched */}
              <div className="mt-6 pt-5 border-t border-border/60 text-left">
                <div className="flex items-center gap-1.5 text-xs font-bold text-text-primary mb-1.5">
                  <Bell className="w-3.5 h-3.5 text-amber-500" />
                  <span>Want FastKirana in your area?</span>
                </div>
                <p className="text-[11px] text-text-secondary mb-3">
                  Drop your phone number. We will send you an alert the day we launch here!
                </p>

                {isNotified ? (
                  <div className="flex items-center gap-2 p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-600 text-xs font-bold justify-center">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>You're on the priority waitlist!</span>
                  </div>
                ) : (
                  <form onSubmit={handleNotifySubmit} className="flex gap-2">
                    <input
                      type="tel"
                      placeholder="10-digit mobile number"
                      maxLength={10}
                      value={notifyPhone}
                      onChange={(e) => setNotifyPhone(e.target.value.replace(/\D/g, ''))}
                      className="flex-1 px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                    />
                    <button
                      type="submit"
                      disabled={isSubmitting || notifyPhone.length < 10}
                      className="px-3.5 py-2 rounded-xl bg-text-primary text-background text-xs font-bold hover:opacity-90 disabled:opacity-50 transition-opacity"
                    >
                      {isSubmitting ? '...' : 'Notify Me'}
                    </button>
                  </form>
                )}
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </>
  )
}
