'use client'

import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { usePushNotification } from '@/hooks/use-push-notification'
import { Bell, ShieldCheck, Sparkles, X } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import Image from 'next/image'

export function SoftPromptDialog() {
  const { showSoftPrompt, setShowSoftPrompt, confirmSubscribe, dismiss, isLoading } = usePushNotification()

  const handleAllow = async () => {
    triggerHaptic('light')
    await confirmSubscribe()
  }

  const handleDismiss = () => {
    triggerHaptic('light')
    setShowSoftPrompt(false)
  }

  return (
    <Dialog open={showSoftPrompt} onOpenChange={setShowSoftPrompt}>
      <DialogContent showCloseButton={false} className="sm:max-w-md border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 rounded-2xl shadow-elevated overflow-hidden p-5 gap-0">
        
        <DialogHeader className="pt-1 flex flex-col items-center text-center">
          {/* Logo + brand badge (Ultra Premium glowing Bell badge) */}
          <div className="h-12 w-12 rounded-full bg-primary flex items-center justify-center shadow-md shadow-primary/20 mb-3 shrink-0">
            <Bell size={20} className="text-white fill-white/10 stroke-[2.5]" />
          </div>

          <DialogTitle className="text-sm font-black text-text-primary tracking-tight flex items-center gap-1.5 justify-center">
            Enable Alerts
            <Sparkles className="h-3.5 w-3.5 text-amber-500 fill-amber-500/20" />
          </DialogTitle>
          <DialogDescription className="text-[11px] font-bold text-text-secondary mt-1 max-w-[280px]">
            Stay connected with real-time order tracking. We promise zero spam, ever.
          </DialogDescription>
        </DialogHeader>

        {/* Notification preview strip — iOS/Notification Center Card Style */}
        <div className="my-3.5 rounded-2xl border border-zinc-150 dark:border-zinc-800/80 bg-zinc-50 dark:bg-zinc-900/30 p-3.5 space-y-2.5">
          <p className="text-[8px] font-bold text-text-muted uppercase tracking-widest px-0.5 mb-0.5">Preview — What you'll get</p>
          
          {/* Preview notification 1 */}
          <div className="bg-white dark:bg-zinc-900 shadow-[0_2px_8px_rgba(0,0,0,0.03)] border border-zinc-100 dark:border-zinc-800/80 rounded-xl p-2.5 flex items-start gap-2.5">
            <div className="h-7 w-7 rounded-lg overflow-hidden shrink-0 border border-zinc-100 dark:border-zinc-800">
              <Image
                src="/icons/icon-192.png"
                alt="FastKirana"
                width={28}
                height={28}
                className="object-cover"
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between">
                <span className="text-[9px] font-extrabold text-text-primary uppercase tracking-wide">FastKirana</span>
                <span className="text-[7.5px] text-text-muted">now</span>
              </div>
              <p className="text-[10px] font-black text-text-primary mt-0.5">🚴 Rider is on the way!</p>
              <p className="text-[8.5px] text-text-secondary mt-0.5 font-semibold leading-tight">Your order has been picked up. Arriving in ~8 mins.</p>
            </div>
          </div>

          {/* Preview notification 2 */}
          <div className="bg-white dark:bg-zinc-900 shadow-[0_2px_8px_rgba(0,0,0,0.03)] border border-zinc-100 dark:border-zinc-800/80 rounded-xl p-2.5 flex items-start gap-2.5 opacity-60">
            <div className="h-7 w-7 rounded-lg overflow-hidden shrink-0 border border-zinc-100 dark:border-zinc-800">
              <Image
                src="/icons/icon-192.png"
                alt="FastKirana"
                width={28}
                height={28}
                className="object-cover"
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between">
                <span className="text-[9px] font-extrabold text-text-primary uppercase tracking-wide">FastKirana</span>
                <span className="text-[7.5px] text-text-muted">5m ago</span>
              </div>
              <p className="text-[10px] font-black text-text-primary mt-0.5">⚡ Flash Deal ending in 3 mins!</p>
              <p className="text-[8.5px] text-text-secondary mt-0.5 font-semibold leading-tight">Tata Salt 1kg @ ₹18 — 60% off, only 4 left.</p>
            </div>
          </div>
        </div>

        {/* Value props */}
        <div className="space-y-2.5 mb-3.5">
          <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-zinc-50 dark:hover:bg-zinc-900/40 transition-colors">
            <div className="h-7 w-7 rounded-lg bg-zinc-100 dark:bg-zinc-900 text-zinc-750 dark:text-zinc-300 flex items-center justify-center shrink-0 border border-zinc-200/40 dark:border-zinc-800/40">
              <span className="text-xs font-bold leading-none">🚴</span>
            </div>
            <div className="min-w-0">
              <h5 className="text-[10.5px] font-black text-text-primary leading-tight">Live Delivery Tracking</h5>
              <p className="text-[9px] text-text-muted mt-0.5 leading-none font-semibold">
                Get real-time updates when your rider departs.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-zinc-50 dark:hover:bg-zinc-900/40 transition-colors">
            <div className="h-7 w-7 rounded-lg bg-zinc-100 dark:bg-zinc-900 text-zinc-750 dark:text-zinc-300 flex items-center justify-center shrink-0 border border-zinc-200/40 dark:border-zinc-800/40">
              <span className="text-xs font-bold leading-none">⚡</span>
            </div>
            <div className="min-w-0">
              <h5 className="text-[10.5px] font-black text-text-primary leading-tight">10-Minute Flash Deals</h5>
              <p className="text-[9px] text-text-muted mt-0.5 leading-none font-semibold">
                Receive instant alerts for limited-stock bargains.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-zinc-50 dark:hover:bg-zinc-900/40 transition-colors">
            <div className="h-7 w-7 rounded-lg bg-zinc-100 dark:bg-zinc-900 text-zinc-750 dark:text-zinc-300 flex items-center justify-center shrink-0 border border-zinc-200/40 dark:border-zinc-800/40">
              <span className="text-xs font-bold leading-none">🔔</span>
            </div>
            <div className="min-w-0">
              <h5 className="text-[10.5px] font-black text-text-primary leading-tight">Back in Stock Alerts</h5>
              <p className="text-[9px] text-text-muted mt-0.5 leading-none font-semibold">
                Be notified the second your items are restocked.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-1.5 text-[8.5px] text-text-muted justify-center mb-4 font-bold">
          <ShieldCheck className="h-3 w-3 text-emerald-600" />
          <span>Secure Web Standard • Opt out anytime</span>
        </div>

        <DialogFooter className="flex flex-row gap-2.5 -mx-5 -mb-5 p-4 border-t border-zinc-100 dark:border-zinc-900/60 bg-zinc-50/50 dark:bg-zinc-900/20">
          <Button
            variant="outline"
            onClick={handleDismiss}
            disabled={isLoading}
            className="flex-1 font-bold text-[11px] h-9.5 rounded-xl bg-zinc-100 hover:bg-zinc-200 text-zinc-750 dark:bg-zinc-900 dark:hover:bg-zinc-850 dark:text-zinc-350 transition-colors cursor-pointer border-none"
          >
            Maybe Later
          </Button>
          <Button
            onClick={handleAllow}
            disabled={isLoading}
            className="flex-1 font-black text-[11px] h-9.5 rounded-xl bg-primary text-white hover:bg-primary/95 transition-all shadow-md shadow-primary/10 active:scale-98 cursor-pointer flex items-center justify-center gap-1.5"
          >
            {isLoading ? (
              <span className="h-3 w-3 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                <Bell size={11} className="stroke-[2.5]" />
                Allow
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
