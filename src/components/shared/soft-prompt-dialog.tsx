'use client'

import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { usePushNotification } from '@/hooks/use-push-notification'
import { Bell, ShieldCheck, Sparkles, X } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'

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
          <div className="h-14 w-14 bg-primary/10 dark:bg-zinc-800/80 border border-primary/20 rounded-2xl flex items-center justify-center text-primary relative mb-4">
            <Bell className="h-7 w-7 stroke-[2] animate-bounce-subtle" />
            <span className="absolute -top-1 -right-1 flex h-3.5 w-3.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
              <span className="relative inline-flex rounded-full h-3.5 w-3.5 bg-accent"></span>
            </span>
          </div>

          <DialogTitle className="text-lg font-black text-text-primary tracking-tight flex items-center gap-1.5 justify-center">
            Enable Notifications
            <Sparkles className="h-4 w-4 text-amber-500 fill-amber-500/20" />
          </DialogTitle>
          <DialogDescription className="text-xs text-text-secondary mt-1 max-w-[320px]">
            Stay connected with the updates you care about. We promise zero spam, ever.
          </DialogDescription>
        </DialogHeader>

        {/* Premium Value Props Grid */}
        <div className="my-6 space-y-3.5">
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
