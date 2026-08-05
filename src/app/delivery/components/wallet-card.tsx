'use client'

import React from 'react'
import { Wallet, ShieldAlert, ArrowUpRight } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

export interface DeliveryWalletCardProps {
  collectedCod: number
  codLimit: number
  deliveredCountToday: number
  earningsToday: number
}

export function DeliveryWalletCard({
  collectedCod,
  codLimit,
  deliveredCountToday,
  earningsToday,
}: DeliveryWalletCardProps) {
  const codPercentage = Math.min(100, Math.round((collectedCod / codLimit) * 100))
  const isNearLimit = codPercentage >= 80

  return (
    <div className="bg-card border border-border/60 rounded-2xl p-4 shadow-xs space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
            <Wallet className="h-4 w-4" />
          </div>
          <div>
            <h3 className="text-xs font-black text-text-primary">COD Cash Wallet</h3>
            <p className="text-[10px] text-text-secondary">Cash collected to be deposited</p>
          </div>
        </div>
        <div className="text-right">
          <p className="text-sm font-black text-text-primary">{formatPrice(collectedCod)}</p>
          <p className="text-[10px] text-text-muted">Limit: {formatPrice(codLimit)}</p>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="space-y-1">
        <div className="h-2 w-full rounded-full bg-muted overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-300 ${
              isNearLimit ? 'bg-rose-500 animate-pulse' : 'bg-emerald-500'
            }`}
            style={{ width: `${codPercentage}%` }}
          />
        </div>
        <div className="flex justify-between text-[10px] font-bold text-text-secondary">
          <span>{codPercentage}% Used</span>
          <span>{formatPrice(codLimit - collectedCod)} Remaining</span>
        </div>
      </div>

      {isNearLimit && (
        <div className="p-2.5 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-600 dark:text-rose-400 text-xs font-bold flex items-center gap-2">
          <ShieldAlert className="h-4 w-4 shrink-0" />
          <span>⚠️ COD threshold near limit. Please deposit cash at darkstore counter!</span>
        </div>
      )}

      {/* Stats row */}
      <div className="grid grid-cols-2 gap-2 pt-1 border-t border-border/40 text-center">
        <div className="p-2 rounded-xl bg-muted/20">
          <p className="text-[10px] text-text-secondary font-bold">Today Completed</p>
          <p className="text-xs font-black text-text-primary">{deliveredCountToday} Orders</p>
        </div>
        <div className="p-2 rounded-xl bg-muted/20">
          <p className="text-[10px] text-text-secondary font-bold">Est. Earnings</p>
          <p className="text-xs font-black text-emerald-600 dark:text-emerald-400">
            {formatPrice(earningsToday)}
          </p>
        </div>
      </div>
    </div>
  )
}
