'use client'

import { Bell, X, ShieldAlert, Sparkles } from 'lucide-react'
import { useSession } from 'next-auth/react'
import { usePushNotification } from '@/hooks/use-push-notification'
import { triggerHaptic } from '@/lib/haptic'

export function PushNotificationConsent() {
  const { status } = useSession()
  const {
    isSupported,
    isIOS,
    permission,
    isSubscribed,
    isLoading,
    showPrompt,
    subscribe,
    dismiss,
  } = usePushNotification()

  const handleSubscribe = async () => {
    triggerHaptic('light')
    await subscribe()
  }

  const handleDismiss = () => {
    triggerHaptic('light')
    dismiss()
  }

  if (status !== 'authenticated') return null

  if (!isSupported) {
    if (isIOS && showPrompt) {
      return (
        <div className="fixed top-[104px] left-4 right-4 z-50 sm:top-[88px] sm:right-6 sm:left-auto sm:w-[420px] overflow-hidden bg-amber-500/5 border border-amber-500/20 p-4 rounded-2xl shadow-elevated flex items-start justify-between gap-3 animate-slide-down">
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

  if (!showPrompt || isSubscribed) return null

  // If permission is denied, show an instruction box to enable in settings
  if (permission === 'denied') {
    return (
      <div className="fixed top-[104px] left-4 right-4 z-50 sm:top-[88px] sm:right-6 sm:left-auto sm:w-[420px] bg-rose-50 dark:bg-rose-950/10 border border-rose-500/20 p-4 rounded-2xl flex items-start justify-between gap-3 animate-fade-in shadow-elevated">
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
    <div className="fixed top-[104px] left-4 right-4 z-50 sm:top-[88px] sm:right-6 sm:left-auto sm:w-[420px] overflow-hidden bg-gradient-to-r from-primary/5 via-violet-500/[0.03] to-accent/5 dark:from-zinc-900/60 dark:to-zinc-950/60 border border-primary/20 dark:border-zinc-800/80 p-4 rounded-2xl shadow-elevated flex flex-col sm:flex-row sm:items-center justify-between gap-4 animate-slide-down">
      
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
