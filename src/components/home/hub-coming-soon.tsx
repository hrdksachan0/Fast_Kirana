'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { 
  Rocket, 
  MapPin, 
  Bell, 
  CheckCircle2, 
  Sparkles, 
  Navigation, 
  Clock, 
  Store, 
  ShoppingBag,
  ArrowRight
} from 'lucide-react'
import { useUIStore } from '@/stores/ui-store'
import { toast } from 'sonner'

interface HubComingSoonProps {
  hubName?: string
  city?: string
}

export function HubComingSoon({ hubName, city }: HubComingSoonProps) {
  const setLocationPickerOpen = useUIStore((s) => s.setLocationPickerOpen)
  const setSelectedLocation = useUIStore((s) => s.setSelectedLocation)
  const setUserCoords = useUIStore((s) => s.setUserCoords)
  const selectedLocation = useUIStore((s) => s.selectedLocation)
  const availableHubs = useUIStore((s) => s.availableHubs)

  const [phone, setPhone] = useState('')
  const [isNotified, setIsNotified] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const activeCityName = city || hubName || selectedLocation.split(',')[0] || 'your area'

  // Handle WhatsApp / SMS alert submission
  const handleNotify = (e: React.FormEvent) => {
    e.preventDefault()
    const clean = phone.replace(/\D/g, '')
    if (clean.length < 10) {
      toast.error('Please enter a valid 10-digit phone number')
      return
    }

    setIsSubmitting(true)
    setTimeout(() => {
      setIsSubmitting(false)
      setIsNotified(true)
      toast.success(`🎉 You're on the priority list! We'll notify ${clean} as soon as we go live in ${activeCityName}.`, {
        duration: 5000,
      })
    }, 600)
  }

  // Switch to primary active hub
  const handleSwitchToActiveHub = () => {
    const activeHub = availableHubs.find((h) => h.isActive) || availableHubs[0]
    if (activeHub) {
      setUserCoords({ lat: activeHub.latitude, lng: activeHub.longitude })
      setSelectedLocation(`${activeHub.city || activeHub.name} Central`)
      toast.success(`Switched to ${activeHub.name}!`)
    }
  }

  return (
    <div className="w-full max-w-2xl mx-auto px-4 py-12 text-center animate-fade-in">
      <div className="relative bg-white dark:bg-zinc-900/90 rounded-3xl p-6 sm:p-10 border border-border/80 shadow-xl overflow-hidden backdrop-blur-md">
        {/* Glow gradients */}
        <div className="absolute -top-20 -right-20 w-48 h-48 bg-primary/10 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute -bottom-20 -left-20 w-48 h-48 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />

        {/* Animated Rocket & Radar Icon */}
        <div className="relative mx-auto mb-6 w-24 h-24 flex items-center justify-center">
          <div className="absolute inset-0 rounded-full bg-primary/15 animate-ping opacity-75" />
          <div className="absolute inset-2 rounded-full bg-primary/20 animate-pulse" />
          <div className="relative z-10 w-16 h-16 rounded-2xl bg-gradient-to-tr from-primary via-rose-500 to-amber-500 flex items-center justify-center text-white shadow-xl shadow-primary/30">
            <Rocket className="w-8 h-8 transition-transform duration-500 hover:scale-110" />
          </div>
        </div>

        {/* Badge */}
        <div className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-600 dark:text-amber-400 text-xs font-black uppercase tracking-wider mb-3">
          <Sparkles className="w-3.5 h-3.5" />
          <span>Wait! We Are Coming Soon</span>
        </div>

        {/* Main Title */}
        <h2 className="text-2xl sm:text-3xl font-black text-text-primary tracking-tight">
          Launching in <span className="text-primary underline decoration-wavy decoration-primary/40">{activeCityName}</span> Soon!
        </h2>

        {/* Subtitle */}
        <p className="text-sm text-text-secondary mt-3 leading-relaxed max-w-lg mx-auto font-medium">
          FastKirana is setting up operations, local dark stores, and partner kitchens in this area. We are preparing to bring lightning-fast 10-minute grocery & food deliveries to your doorstep!
        </p>

        {/* Feature Highlights Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 my-6 text-left">
          <div className="p-3.5 rounded-2xl bg-muted/40 border border-border/50">
            <Clock className="w-4 h-4 text-primary mb-1.5" />
            <div className="text-xs font-black text-text-primary">10-15 Min Delivery</div>
            <div className="text-[11px] text-text-secondary mt-0.5">Ultra-fast local doorstep delivery</div>
          </div>
          <div className="p-3.5 rounded-2xl bg-muted/40 border border-border/50">
            <ShoppingBag className="w-4 h-4 text-emerald-600 mb-1.5" />
            <div className="text-xs font-black text-text-primary">Fresh Daily Staples</div>
            <div className="text-[11px] text-text-secondary mt-0.5">Milk, veggies, fruits & snacks</div>
          </div>
          <div className="p-3.5 rounded-2xl bg-muted/40 border border-border/50">
            <Store className="w-4 h-4 text-amber-500 mb-1.5" />
            <div className="text-xs font-black text-text-primary">Partner Kitchens</div>
            <div className="text-[11px] text-text-secondary mt-0.5">Hot meals & delicious combos</div>
          </div>
        </div>

        {/* Priority Notification Form */}
        <div className="bg-muted/50 rounded-2xl p-4 sm:p-5 border border-border/70 text-left">
          <div className="flex items-center gap-2 text-xs font-bold text-text-primary mb-1">
            <Bell className="w-4 h-4 text-amber-500 shrink-0" />
            <span>Get Notified on Launch Day via WhatsApp / SMS</span>
          </div>
          <p className="text-[11px] text-text-secondary mb-3">
            Be the first to order and get an exclusive ₹100 launch voucher!
          </p>

          {isNotified ? (
            <div className="flex items-center gap-2 p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-600 dark:text-emerald-400 text-xs font-bold justify-center">
              <CheckCircle2 className="w-4 h-4" />
              <span>You are on the VIP Launch list for {activeCityName}!</span>
            </div>
          ) : (
            <form onSubmit={handleNotify} className="flex flex-col sm:flex-row gap-2">
              <input
                type="tel"
                placeholder="Enter 10-digit mobile number"
                maxLength={10}
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                className="flex-1 px-3.5 py-2.5 text-xs sm:text-sm rounded-xl border border-border bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20 font-medium"
              />
              <button
                type="submit"
                disabled={isSubmitting || phone.length < 10}
                className="bg-primary hover:bg-primary/90 text-primary-foreground px-5 py-2.5 rounded-xl font-black text-xs sm:text-sm transition-all shadow-md active:scale-95 disabled:opacity-50 flex items-center justify-center gap-1.5 shrink-0"
              >
                <span>Notify Me</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </form>
          )}
        </div>

        {/* Quick Action Navigation Buttons */}
        <div className="mt-6 flex flex-col sm:flex-row items-center justify-center gap-3">
          <button
            type="button"
            onClick={() => setLocationPickerOpen(true)}
            className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-muted hover:bg-muted/80 text-text-primary text-xs font-bold border border-border flex items-center justify-center gap-2 transition-colors"
          >
            <MapPin className="w-3.5 h-3.5 text-primary" />
            <span>Change Delivery Location</span>
          </button>

          <button
            type="button"
            onClick={handleSwitchToActiveHub}
            className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 text-xs font-bold border border-emerald-500/30 flex items-center justify-center gap-2 transition-colors"
          >
            <Navigation className="w-3.5 h-3.5" />
            <span>Switch to Active Hub (Ghatampur)</span>
          </button>
        </div>
      </div>
    </div>
  )
}
