'use client'

import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { Tag, Sparkles, Gift, Check, ArrowRight } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'
import { useCartStore } from '@/stores/cart-store'

interface OfferItem {
  id: string
  code: string
  discountType: string
  bogoType?: string
  badgeText?: string
  value: number
  minOrder: number
  maxDiscount?: number
  triggerVariant?: string
  rewardVariant?: string
}

interface RestaurantOffersCarouselProps {
  restaurantId: string
  restaurantName: string
}

export function RestaurantOffersCarousel({ restaurantId, restaurantName }: RestaurantOffersCarouselProps) {
  const [offers, setOffers] = useState<OfferItem[]>([])
  const [copiedCode, setCopiedCode] = useState<string | null>(null)
  const appliedCouponCode = useCartStore((s) => s.appliedCouponCode)
  const setAppliedCouponCode = useCartStore((s) => s.setAppliedCouponCode)

  useEffect(() => {
    if (!restaurantId) return
    fetch(`/api/coupons?restaurantId=${encodeURIComponent(restaurantId)}`)
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data)) {
          setOffers(data)
        }
      })
      .catch((err) => console.warn('Failed to load restaurant offers:', err))
  }, [restaurantId])

  if (offers.length === 0) return null

  const handleApply = (offer: OfferItem) => {
    triggerHaptic('success')
    setCopiedCode(offer.code)
    navigator.clipboard?.writeText(offer.code)

    if (setAppliedCouponCode) {
      setAppliedCouponCode(offer.code)
      toast.success(`🎉 Offer "${offer.code}" applied to your order!`, {
        icon: '🏷️',
      })
    } else {
      toast.success(`Coupon code ${offer.code} copied! Apply it at checkout.`, {
        icon: '📋',
      })
    }

    setTimeout(() => setCopiedCode(null), 3000)
  }

  return (
    <div className="w-full my-1.5 sm:my-2">
      <div className="flex items-center justify-between mb-1.5 px-0.5">
        <div className="flex items-center gap-1.5 text-[10.5px] font-extrabold uppercase tracking-wide text-zinc-600 dark:text-zinc-400">
          <Sparkles className="w-3 h-3 text-amber-500" />
          <span>Deals &amp; Offers</span>
        </div>
        {offers.length > 1 && (
          <span className="text-[10px] text-zinc-400 font-bold">{offers.length} available</span>
        )}
      </div>

      <div className="flex items-center gap-2 overflow-x-auto pb-1 pt-0.5 no-scrollbar px-0.5">
        {offers.map((offer) => {
          const isApplied = appliedCouponCode?.toUpperCase() === offer.code.toUpperCase()
          const isBogo = offer.discountType === 'BOGO'
          const isCopied = copiedCode === offer.code

          // Dynamic Offer Title
          let title = `${offer.value}% OFF`
          let subtitle = offer.minOrder > 0 ? `Above ₹${offer.minOrder}` : 'No minimum order'

          if (isBogo) {
            if (offer.bogoType === 'BUY_LARGE_GET_SMALL') {
              title = `BUY ${offer.triggerVariant?.toUpperCase() || 'LARGE'} GET ${offer.rewardVariant?.toUpperCase() || 'SMALL'} FREE`
              subtitle = 'Auto-applied when both in cart'
            } else if (offer.bogoType === 'CHEAPEST_FREE') {
              title = 'BUY 2, CHEAPEST IS FREE'
              subtitle = 'Lowest priced item 100% free'
            } else {
              title = 'BUY 1 GET 1 FREE'
              subtitle = 'On eligible items'
            }
          } else if (offer.discountType === 'FLAT') {
            title = `FLAT ₹${offer.value} OFF`
          } else if (offer.discountType === 'FREE_DELIVERY') {
            title = 'FREE DELIVERY'
            subtitle = offer.minOrder > 0 ? `On orders above ₹${offer.minOrder}` : 'No minimum bill'
          }

          if (offer.maxDiscount && !isBogo) {
            subtitle = `Up to ₹${offer.maxDiscount} • ${subtitle}`
          }

          // Avoid repeating the title inside badgeText
          const showBadgeText = offer.badgeText && offer.badgeText.toLowerCase() !== title.toLowerCase()

          return (
            <div
              key={offer.id}
              className={`relative shrink-0 flex items-center bg-gradient-to-r from-orange-500/10 via-amber-500/5 to-transparent dark:from-zinc-900 dark:to-zinc-850 border rounded-xl py-2 px-3 shadow-2xs transition-all duration-200 ${
                isApplied
                  ? 'border-emerald-500/40 bg-emerald-500/5'
                  : 'border-orange-500/25 hover:border-orange-500/40'
              } ${offers.length === 1 ? 'w-full' : 'min-w-[240px] max-w-[300px]'}`}
            >
              {/* Compact Icon badge */}
              <div className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 mr-2.5 ${
                isApplied
                  ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400'
                  : 'bg-orange-500/15 text-orange-600 dark:text-orange-400'
              }`}>
                {isBogo ? <Gift className="w-3.5 h-3.5" /> : <Tag className="w-3.5 h-3.5" />}
              </div>

              {/* Details */}
              <div className="flex-1 min-w-0 pr-2">
                <div className="flex items-center gap-1.5 leading-none">
                  <span className="text-[9px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded bg-orange-600/15 text-orange-700 dark:text-orange-300 border border-orange-500/20">
                    {offer.code}
                  </span>
                  {showBadgeText && (
                    <span className="text-[9px] font-bold text-amber-700 dark:text-amber-400 truncate">
                      {offer.badgeText}
                    </span>
                  )}
                </div>
                <h5 className="text-[11px] font-black text-text-primary tracking-tight mt-1 truncate leading-tight">
                  {title}
                </h5>
                <p className="text-[9.5px] text-text-secondary font-medium truncate mt-0.5 leading-tight">
                  {subtitle}
                </p>
              </div>

              {/* Compact 1-Tap Action Button */}
              <button
                type="button"
                onClick={() => handleApply(offer)}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider shrink-0 transition-all active:scale-95 flex items-center gap-1 cursor-pointer ${
                  isApplied
                    ? 'bg-emerald-600/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30'
                    : isCopied
                    ? 'bg-emerald-600 text-white'
                    : 'bg-orange-600 hover:bg-orange-700 text-white shadow-xs'
                }`}
              >
                {isApplied ? (
                  <>
                    <Check className="w-3 h-3" />
                    <span>Applied</span>
                  </>
                ) : isCopied ? (
                  <>
                    <Check className="w-3 h-3" />
                    <span>Copied</span>
                  </>
                ) : (
                  <>
                    <span>Apply</span>
                    <ArrowRight className="w-2.5 h-2.5" />
                  </>
                )}
              </button>
            </div>
          )
        })}
      </div>
    </div>
  )
}
