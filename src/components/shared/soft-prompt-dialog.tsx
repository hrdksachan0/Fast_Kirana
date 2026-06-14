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
      <DialogContent showCloseButton={false} className="sm:max-w-md border border-primary/20 bg-gradient-to-b from-card to-background rounded-2xl shadow-elevated overflow-hidden p-6 gap-0">
        
        {/* Top visual brand bar */}
        <div className="absolute top-0 inset-x-0 h-1.5 bg-gradient-to-r from-primary via-violet-500 to-accent" />
        
        <DialogHeader className="pt-2 flex flex-col items-center text-center">
          {/* Logo + brand badge */}
          <div className="h-16 w-16 rounded-2xl overflow-hidden shadow-lg border-2 border-primary/20 mb-4 relative">
            <Image
              src="/icons/icon-192.png"
              alt="FastKirana"
              fill
              className="object-cover"
            />
          </div>

          <DialogTitle className="text-lg font-black text-text-primary tracking-tight flex items-center gap-1.5 justify-center">
            Enable Notifications
            <Sparkles className="h-4 w-4 text-amber-500 fill-amber-500/20" />
          </DialogTitle>
          <DialogDescription className="text-xs text-text-secondary mt-1 max-w-[320px]">
            Stay connected with the updates you care about. We promise zero spam, ever.
          </DialogDescription>
        </DialogHeader>

        {/* Notification preview strip — Swiggy/Blinkit style */}
        <div className="my-5 rounded-xl border border-border bg-muted/30 p-3 space-y-2.5">
          <p className="text-[9px] font-bold text-text-muted uppercase tracking-widest px-0.5 mb-1">Preview — What you'll get</p>
          
          {/* Preview notification 1 */}
          <div className="flex items-start gap-2.5 px-1">
            <div className="h-7 w-7 rounded-md overflow-hidden shadow-sm shrink-0 border border-border">
              <Image
                src="/icons/icon-192.png"
                alt="FastKirana"
                width={28}
                height={28}
                className="object-cover"
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className="text-[9px] font-extrabold text-text-primary uppercase tracking-wide">FastKirana</span>
                <span className="text-[8px] text-text-muted">• 2m</span>
              </div>
              <p className="text-[10px] font-bold text-text-primary leading-tight">🚴 Rider is on the way!</p>
              <p className="text-[9px] text-text-muted font-semibold mt-0.5">Your order has been picked up. Arriving in ~8 mins.</p>
            </div>
          </div>

          {/* Preview notification 2 */}
          <div className="flex items-start gap-2.5 px-1 opacity-60">
            <div className="h-7 w-7 rounded-md overflow-hidden shadow-sm shrink-0 border border-border">
              <Image
                src="/icons/icon-192.png"
                alt="FastKirana"
                width={28}
                height={28}
                className="object-cover"
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className="text-[9px] font-extrabold text-text-primary uppercase tracking-wide">FastKirana</span>
                <span className="text-[8px] text-text-muted">• 5m</span>
              </div>
              <p className="text-[10px] font-bold text-text-primary leading-tight">⚡ Flash Deal ending in 3 mins!</p>
              <p className="text-[9px] text-text-muted font-semibold mt-0.5">Tata Salt 1kg @ ₹18 — 60% off, only 4 left.</p>
            </div>
          </div>
        </div>

        {/* Value props */}
        <div className="space-y-3 mb-5">
          <div className="flex items-start gap-3 p-2.5 rounded-xl hover:bg-muted/40 transition-colors">
            <div className="h-7 w-7 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center shrink-0">
              <span className="text-sm font-bold">🚴</span>
            </div>
            <div>
              <h5 className="text-[11px] font-black text-text-primary">Live Delivery Tracking</h5>
              <p className="text-[10px] text-text-muted mt-0.5 leading-relaxed font-semibold">
                Get real-time updates when your rider departs and is minutes away.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3 p-2.5 rounded-xl hover:bg-muted/40 transition-colors">
            <div className="h-7 w-7 rounded-lg bg-amber-500/10 text-amber-600 flex items-center justify-center shrink-0">
              <span className="text-sm font-bold">⚡</span>
            </div>
            <div>
              <h5 className="text-[11px] font-black text-text-primary">10-Minute Flash Deals</h5>
              <p className="text-[10px] text-text-muted mt-0.5 leading-relaxed font-semibold">
                Receive instant alerts for limited-stock bargains before they end.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3 p-2.5 rounded-xl hover:bg-muted/40 transition-colors">
            <div className="h-7 w-7 rounded-lg bg-violet-500/10 text-violet-600 flex items-center justify-center shrink-0">
              <span className="text-sm font-bold">🔔</span>
            </div>
            <div>
              <h5 className="text-[11px] font-black text-text-primary">Back in Stock Alerts</h5>
              <p className="text-[10px] text-text-muted mt-0.5 leading-relaxed font-semibold">
                Be notified the second your favorite items are restocked at the store.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-1.5 text-[9px] text-text-muted justify-center mb-5 font-bold">
          <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
          <span>Secure Web Standard • Opt out anytime in browser settings</span>
        </div>

        <DialogFooter className="flex flex-col sm:flex-row gap-2 -mx-6 -mb-6 p-6 border-t bg-muted/30">
          <Button
            variant="outline"
            onClick={handleDismiss}
            disabled={isLoading}
            className="flex-1 font-extrabold text-[11px] h-10 rounded-xl cursor-pointer"
          >
            Maybe Later
          </Button>
          <Button
            onClick={handleAllow}
            disabled={isLoading}
            className="flex-1 font-black text-[11px] h-10 rounded-xl bg-primary text-white hover:bg-primary/95 transition-all shadow-md active:scale-98 cursor-pointer flex items-center justify-center gap-1.5"
          >
            {isLoading ? (
              <span className="h-3.5 w-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                <Bell size={12} className="stroke-[2.5]" />
                Allow Notifications
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
