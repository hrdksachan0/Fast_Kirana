'use client'

import { Check } from 'lucide-react'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'
import { getLast10Digits } from '@/lib/phone'

interface OrderForSomeoneCardProps {
  orderForSomeone: boolean
  setOrderForSomeone: (val: boolean) => void
  recipientName: string
  setRecipientName: (val: string) => void
  recipientPhone: string
  setRecipientPhone: (val: string) => void
}

export function OrderForSomeoneCard({
  orderForSomeone,
  setOrderForSomeone,
  recipientName,
  setRecipientName,
  recipientPhone,
  setRecipientPhone,
}: OrderForSomeoneCardProps) {
  return (
    <div
      id="order-for-someone-section"
      className="rounded-2xl border border-border/80 bg-card p-3 sm:p-3.5 shadow-xs space-y-2.5 transition-all"
    >
      <div
        role="button"
        tabIndex={0}
        onClick={() => {
          triggerHaptic('light')
          setOrderForSomeone(!orderForSomeone)
        }}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            setOrderForSomeone(!orderForSomeone)
          }
        }}
        className="flex items-center justify-between cursor-pointer select-none"
      >
        <div className="flex items-center gap-3 min-w-0">
          <div
            className={cn(
              'h-8 w-8 rounded-xl flex items-center justify-center text-base shrink-0 transition-colors',
              orderForSomeone
                ? 'bg-amber-500 text-white shadow-xs'
                : 'bg-amber-500/10 text-amber-600 dark:text-amber-400'
            )}
          >
            🎁
          </div>
          <div className="min-w-0">
            <div className="text-xs sm:text-sm font-black text-text-primary truncate">
              Order for someone else?
            </div>
            <p className="text-[11px] text-text-muted truncate mt-0.5">
              Send this order to family or friends
            </p>
          </div>
        </div>

        {/* Switch Pill */}
        <div
          className={cn(
            'w-10 h-5.5 rounded-full p-0.5 transition-colors duration-200 flex items-center shrink-0 ml-2',
            orderForSomeone ? 'bg-primary' : 'bg-muted-foreground/25'
          )}
        >
          <div
            className={cn(
              'w-4.5 h-4.5 rounded-full bg-white shadow-xs transform transition-transform duration-200 flex items-center justify-center text-[9px]',
              orderForSomeone ? 'translate-x-4.5 text-primary' : 'translate-x-0'
            )}
          >
            {orderForSomeone && <Check className="h-2.5 w-2.5 stroke-[3]" />}
          </div>
        </div>
      </div>

      {/* Collapsible Details Inputs */}
      {orderForSomeone && (
        <div className="pt-2 border-t border-border/40 space-y-2.5 animate-in fade-in slide-in-from-top-2 duration-200">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            <div>
              <Label
                htmlFor="recipient-name"
                className="text-[10px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between"
              >
                <span>Receiver&apos;s Name</span>
                <span className="text-red-500 font-bold">*</span>
              </Label>
              <Input
                id="recipient-name"
                type="text"
                required
                placeholder="e.g. Rahul Sharma"
                value={recipientName}
                onChange={(e) => setRecipientName(e.target.value)}
                className="mt-1 h-9 text-xs font-medium rounded-xl border-border bg-background"
              />
            </div>
            <div>
              <Label
                htmlFor="recipient-phone"
                className="text-[10px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between"
              >
                <span>Receiver&apos;s Phone</span>
                <span className="text-text-muted font-normal text-[9px]">Optional</span>
              </Label>
              <Input
                id="recipient-phone"
                type="tel"
                maxLength={10}
                placeholder="10-digit mobile number"
                value={recipientPhone}
                onChange={(e) => setRecipientPhone(getLast10Digits(e.target.value))}
                className="mt-1 h-9 text-xs font-medium rounded-xl border-border bg-background"
              />
            </div>
          </div>

          <div className="p-2 rounded-xl bg-amber-500/10 border border-amber-500/20 text-[11px] font-medium text-amber-800 dark:text-amber-300 flex items-center gap-2">
            <span className="text-sm shrink-0">📞</span>
            <span>Delivery rider will call this number directly upon arrival.</span>
          </div>
        </div>
      )}
    </div>
  )
}
