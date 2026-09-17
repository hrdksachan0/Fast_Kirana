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
    <div className="w-full my-3 sm:my-4">
      <div className="flex items-center gap-1.5 mb-2 px-1">
        <Sparkles className="w-3.5 h-3.5 text-amber-500 animate-pulse" />
        <h4 className="text-xs font-black uppercase tracking-wider text-text-primary">
          Deals &amp; Offers from {restaurantName}
        </h4>
      </div>

      <div className="flex items-center gap-3 overflow-x-auto pb-2 pt-0.5 no-scrollbar px-1">
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
              subtitle = 'Auto-applied when both added'
            } else if (offer.bogoType === 'CHEAPEST_FREE') {
              title = 'BUY ANY 2, CHEAPEST IS FREE'
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

          return (
            <div
              key={offer.id}
              className="relative shrink-0 flex items-center bg-gradient-to-r from-orange-500/10 via-amber-500/10 to-rose-500/5 dark:from-zinc-900 dark:to-zinc-800/90 border border-orange-500/30 dark:border-orange-500/20 rounded-2xl p-3 shadow-xs hover:shadow-md transition-all duration-300 min-w-[260px] sm:min-w-[300px] overflow-hidden select-none"
            >
              {/* Ticket Punch Notches (Swiggy / Movie Ticket cutout aesthetic) */}
              <div className="absolute -left-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-background border-r border-orange-500/30" />
              <div className="absolute -right-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-background border-l border-orange-500/30" />

              {/* Icon badge */}
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-orange-500 to-amber-500 text-white flex items-center justify-center shrink-0 shadow-sm ml-1.5 mr-3">
                {isBogo ? <Gift className="w-5 h-5" /> : <Tag className="w-5 h-5" />}
              </div>

              {/* Details */}
              <div className="flex-1 min-w-0 pr-2">
                <div className="flex items-center gap-1.5">
                  <span className="text-[9px] font-black uppercase tracking-widest px-1.5 py-0.5 rounded bg-orange-600 text-white shadow-xs">
                    {offer.code}
                  </span>
                  {offer.badgeText && (
                    <span className="text-[8.5px] font-bold text-amber-700 dark:text-amber-400 truncate">
                      {offer.badgeText}
                    </span>
                  )}
                </div>
                <h5 className="text-xs font-black text-text-primary tracking-tight mt-1 truncate">
                  {title}
                </h5>
                <p className="text-[10px] text-text-secondary font-medium truncate mt-0.5">
                  {subtitle}
                </p>
              </div>

              {/* 1-Tap Action Button */}
              <button
                type="button"
                onClick={() => handleApply(offer)}
                className={`px-3 py-1.5 rounded-xl text-[11px] font-black uppercase tracking-wider shrink-0 transition-all active:scale-95 shadow-xs mr-1.5 flex items-center gap-1 ${
                  isApplied
                    ? 'bg-emerald-600 text-white shadow-emerald-600/20'
                    : isCopied
                    ? 'bg-emerald-600 text-white'
                    : 'bg-orange-600 hover:bg-orange-700 text-white shadow-orange-600/20'
                }`}
              >
                {isApplied ? (
                  <>
                    <Check className="w-3.5 h-3.5" />
                    <span>Applied</span>
                  </>
                ) : isCopied ? (
                  <>
                    <Check className="w-3.5 h-3.5" />
                    <span>Copied</span>
                  </>
                ) : (
                  <>
                    <span>Apply</span>
                    <ArrowRight className="w-3 h-3" />
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
