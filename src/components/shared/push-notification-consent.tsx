'use client'

import { useState, useEffect } from 'react'
import { Bell, Check, X, ShieldAlert, Sparkles } from 'lucide-react'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

function urlBase64ToUint8Array(base64String: string) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

export function PushNotificationConsent() {
  const [isSupported, setIsSupported] = useState(true)
  const [permission, setPermission] = useState<NotificationPermission>('default')
  const [isSubscribed, setIsSubscribed] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [showPrompt, setShowPrompt] = useState(true)
  const [isIOS, setIsIOS] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return

    const supported = 'serviceWorker' in navigator && 'PushManager' in window
    setIsSupported(supported)
    
    const ios = /iPad|iPhone|iPod/.test(navigator.userAgent)
    setIsIOS(ios)

    if (supported && 'Notification' in window) {
      setPermission(Notification.permission)
      
      // Check if already subscribed in service worker
      navigator.serviceWorker.ready.then((registration) => {
        registration.pushManager.getSubscription().then((subscription) => {
          setIsSubscribed(!!subscription)
        })
      }).catch(err => console.log('Service worker not ready yet:', err))
    }

    // Check if user dismissed the prompt in this session
    const dismissed = localStorage.getItem('push-prompt-dismissed') === 'true'
    if (dismissed) {
      setShowPrompt(false)
    }
  }, [])

  const handleSubscribe = async () => {
    if (!isSupported) return
    setIsLoading(true)

    try {
      // 1. Request permission
      const result = await Notification.requestPermission()
      setPermission(result)

      if (result !== 'granted') {
        toast.error('Permission denied. Please allow notifications in your browser URL bar or settings.')
        throw new Error('Notification permission denied')
      }

      // 2. Register push subscription
      const registration = await navigator.serviceWorker.ready
      const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY

      if (!vapidPublicKey) {
        toast.error('VAPID public key not configured in environment variables.')
        throw new Error('VAPID public key not configured in frontend')
      }

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      })

      // 3. Send subscription to server
      const res = await fetch('/api/push/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subscription }),
      })

      if (!res.ok) {
        throw new Error('Failed to save subscription on server')
      }

      setIsSubscribed(true)
      toast.success('🎉 You have successfully subscribed to live updates!')
    } catch (error: any) {
      console.error('Push subscription error:', error)
      toast.error(`Failed to enable notifications: ${error.message || error}`)
    } finally {
      setIsLoading(false)
    }
  }

  const handleDismiss = () => {
    setShowPrompt(false)
    localStorage.setItem('push-prompt-dismissed', 'true')
  }

  if (!isSupported) {
    if (isIOS && showPrompt) {
      return (
        <div className="relative overflow-hidden bg-amber-500/5 border border-amber-500/20 p-4 rounded-2xl shadow-sm flex items-start justify-between gap-3 animate-card-enter md:hidden">
          <div className="flex gap-3">
            <div className="h-10 w-10 bg-amber-500/10 rounded-xl flex items-center justify-center text-amber-600 shrink-0">
              <Bell className="h-5 w-5 stroke-[2] animate-bounce-subtle" />
            </div>
            <div>
              <h4 className="text-xs font-black text-amber-800 dark:text-amber-400 flex items-center gap-1">
                iPhone Web Push Instructions
                <Sparkles className="h-3.5 w-3.5 text-amber-500 fill-amber-500/20" />
              </h4>
              <p className="text-[10px] font-bold text-amber-600/80 mt-0.5 leading-relaxed">
                To receive live updates on iPhone, open this site in **Safari**, tap the **Share** button, select **"Add to Home Screen"**, and launch the app from your Home Screen.
              </p>
            </div>
          </div>
          <button
            onClick={handleDismiss}
            className="text-amber-600/40 hover:text-amber-600 transition-colors h-7 w-7 rounded-lg hover:bg-amber-500/5 flex items-center justify-center shrink-0 cursor-pointer"
            aria-label="Dismiss banner"
          >
            <X size={14} />
          </button>
        </div>
      )
    }
    return null
  }

  if (!showPrompt) return null

  // If already subscribed, show a premium status badge
  if (isSubscribed) {
    return (
      <div className="bg-[#f0fbf4] dark:bg-emerald-950/20 border border-emerald-500/20 dark:border-emerald-500/10 p-4 rounded-2xl flex items-center justify-between gap-4 animate-fade-in shadow-sm md:hidden">
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 bg-emerald-500/10 dark:bg-emerald-500/20 rounded-xl flex items-center justify-center text-emerald-600 shrink-0">
            <Check className="h-5 w-5 stroke-[2.5]" />
          </div>
          <div>
            <h4 className="text-xs font-black text-emerald-800 dark:text-emerald-400">Live Updates Enabled</h4>
            <p className="text-[10px] font-bold text-emerald-600/80 dark:text-emerald-500/80 mt-0.5">
              You will receive push notifications on status changes, even if you close the app.
            </p>
          </div>
        </div>
        <button
          onClick={handleDismiss}
          className="text-emerald-600/40 hover:text-emerald-600 transition-colors h-7 w-7 rounded-lg hover:bg-emerald-500/5 flex items-center justify-center shrink-0 cursor-pointer"
          aria-label="Dismiss banner"
        >
          <X size={14} />
        </button>
      </div>
    )
  }

  // If permission is denied, show a instruction box to enable in settings
  if (permission === 'denied') {
    return (
      <div className="bg-rose-50 dark:bg-rose-950/10 border border-rose-500/20 p-4 rounded-2xl flex items-start justify-between gap-3 animate-fade-in md:hidden">
        <div className="flex gap-3">
          <div className="h-10 w-10 bg-rose-500/10 rounded-xl flex items-center justify-center text-rose-600 shrink-0">
            <ShieldAlert className="h-5 w-5" />
          </div>
          <div>
            <h4 className="text-xs font-black text-rose-800 dark:text-rose-400">Notifications Blocked</h4>
            <p className="text-[10px] font-bold text-rose-600/80 dark:text-rose-500/80 mt-0.5 leading-relaxed">
              Please enable notification permissions for this website in your browser settings to receive live order updates.
            </p>
          </div>
        </div>
        <button
          onClick={handleDismiss}
          className="text-rose-600/40 hover:text-rose-600 transition-colors h-7 w-7 rounded-lg hover:bg-rose-500/5 flex items-center justify-center shrink-0 cursor-pointer"
          aria-label="Dismiss banner"
        >
          <X size={14} />
        </button>
      </div>
    )
  }

  return (
    <div className="relative overflow-hidden bg-gradient-to-r from-primary/5 via-violet-500/[0.03] to-accent/5 dark:from-zinc-900/60 dark:to-zinc-950/60 border border-primary/20 dark:border-zinc-800/80 p-4 rounded-2xl shadow-elevated flex flex-col sm:flex-row sm:items-center justify-between gap-4 animate-card-enter md:hidden">
      
      {/* Decorative sparkles for premium SaaS look */}
      <div className="absolute top-[-20%] right-[-5%] w-[120px] h-[120px] rounded-full bg-primary/5 blur-[30px] pointer-events-none" />

      <div className="flex items-start gap-3">
        {/* Animated Bell Icon */}
        <div className="h-10 w-10 bg-primary/10 dark:bg-zinc-800/80 border border-primary/20 rounded-xl flex items-center justify-center text-primary shrink-0 relative">
          <Bell className="h-5 w-5 stroke-[2] animate-bounce-subtle" />
          <span className="absolute -top-1 -right-1 flex h-2.5 w-2.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-accent"></span>
          </span>
        </div>

        <div>
          <h4 className="text-xs font-black text-text-primary tracking-tight flex items-center gap-1">
            Stay Updated in Real-Time
            <Sparkles className="h-3.5 w-3.5 text-amber-500 fill-amber-500/20" />
          </h4>
          <p className="text-[10px] font-bold text-text-secondary mt-0.5 leading-relaxed">
            Get instant push notifications when your order is Confirmed, Packed, and Out for Delivery.
          </p>
        </div>
      </div>

      <div className="flex items-center gap-2.5 shrink-0 self-end sm:self-center">
        <button
          onClick={handleSubscribe}
          disabled={isLoading}
          className="h-8 px-4 rounded-xl bg-primary hover:bg-primary/95 text-white font-extrabold text-[10px] flex items-center gap-1.5 transition-all shadow-md hover:shadow-lg disabled:opacity-75 disabled:cursor-not-allowed cursor-pointer"
        >
          {isLoading ? (
            <span className="h-3 w-3 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <Bell size={11} className="stroke-[2.5]" />
          )}
          Enable Notifications
        </button>

        <button
          onClick={handleDismiss}
          className="h-8 w-8 rounded-xl border border-border bg-card hover:bg-muted/30 flex items-center justify-center text-text-secondary transition-colors cursor-pointer"
          aria-label="No thanks"
        >
          <X size={13} />
        </button>
      </div>
    </div>
  )
}
