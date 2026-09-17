'use client'

import Image from 'next/image'
import { Gift, Sparkles, CheckCircle2 } from 'lucide-react'
import { motion } from 'framer-motion'
import { formatPrice } from '@/lib/utils'

interface BogoCartGiftCardProps {
  giftItem: {
    id: string
    name: string
    price: number
    imageUrl?: string | null
    rewardVariant?: string
  }
  offerName?: string
}

export function BogoCartGiftCard({ giftItem, offerName = 'BOGO Offer' }: BogoCartGiftCardProps) {
  if (!giftItem) return null

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95, y: 10 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95, y: -10 }}
      className="relative rounded-2xl bg-gradient-to-r from-emerald-500/10 via-teal-500/5 to-amber-500/10 border border-emerald-500/30 dark:border-emerald-500/20 p-3.5 shadow-xs overflow-hidden"
    >
      {/* Glow pulse */}
      <div className="absolute -top-10 -right-10 w-24 h-24 bg-emerald-500/15 rounded-full blur-xl pointer-events-none" />

      {/* Header Badge */}
      <div className="flex items-center justify-between gap-2 mb-2.5">
        <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-600 text-white text-[9.5px] font-black uppercase tracking-wider shadow-xs">
          <Gift className="w-3 h-3 animate-bounce" />
          <span>100% Free BOGO Gift</span>
        </div>
        <span className="text-[10px] font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
          <Sparkles className="w-3 h-3" />
          <span>{offerName}</span>
        </span>
      </div>

      {/* Item Details Row */}
      <div className="flex items-center gap-3">
        <div className="relative w-12 h-12 rounded-xl overflow-hidden bg-background border border-border shrink-0">
          {giftItem.imageUrl ? (
            <Image
              src={giftItem.imageUrl}
              alt={giftItem.name}
              fill
              className="object-cover"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-xl bg-muted">
              🎁
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0">
          <h4 className="text-xs font-black text-text-primary truncate">
            {giftItem.name}
          </h4>
          {giftItem.rewardVariant && (
            <span className="text-[10px] font-semibold text-text-secondary block">
              Size: {giftItem.rewardVariant}
            </span>
          )}
          <div className="flex items-center gap-2 mt-0.5">
            <span className="text-[11px] font-bold line-through text-text-secondary/70">
              {formatPrice(giftItem.price)}
            </span>
            <span className="text-xs font-black text-emerald-600 dark:text-emerald-400">
              FREE
            </span>
          </div>
        </div>

        <div className="shrink-0 text-right">
          <span className="inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 text-[10px] font-black">
            <CheckCircle2 className="w-3 h-3" />
            <span>Saved {formatPrice(giftItem.price)}</span>
          </span>
        </div>
      </div>
    </motion.div>
  )
}
