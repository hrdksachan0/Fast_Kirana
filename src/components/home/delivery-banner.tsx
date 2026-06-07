'use client'

import { Truck, Sparkles, ShieldCheck, Store } from 'lucide-react'

export function DeliveryBanner() {
  return (
    <section className="py-3 md:py-6 my-1 md:my-2 px-1">
      {/* Value Props Card */}
      <div className="glass rounded-2xl border border-primary/10 shadow-card overflow-hidden">
        {/* Tagline */}
        <div className="bg-gradient-to-r from-primary/5 via-accent/5 to-primary/5 px-6 py-2.5 border-b border-border/40">
          <div className="flex items-center justify-center gap-1.5 md:gap-2 text-[10px] md:text-sm font-bold text-text-primary tracking-wide">
            <Store className="h-4 w-4 text-primary animate-pulse-gentle shrink-0" />
            <span>From Your Town&apos;s Dark Store — Packed &amp; Delivered by <span className="text-primary">FastKirana</span></span>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 md:gap-4 p-4 md:p-6">
          {/* Instant Delivery */}
          <div className="group/item flex items-start gap-4 cursor-default">
            <div className="flex h-10 w-10 md:h-14 md:w-14 flex-shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-primary/15 to-primary/5 text-primary transition-transform duration-300 group-hover/item:scale-110 group-hover/item:-translate-y-0.5">
              <Truck className="h-5 w-5 md:h-7 md:w-7 animate-float" />
            </div>
            <div>
              <h3 className="text-xs md:text-base font-bold text-text-primary">Fast Instant Delivery</h3>
              <p className="hidden md:block text-xs text-text-secondary mt-0.5 leading-relaxed">
                Our network of local dark stores delivers your groceries fresh to your doorstep with our fast delivery service.
              </p>
            </div>
          </div>

          {/* Free Shipping */}
          <div className="group/item flex items-start gap-4 border-t border-border/60 pt-4 md:border-t-0 md:pt-0 md:border-x md:px-4 border-border/60 cursor-default">
            <div className="flex h-10 w-10 md:h-14 md:w-14 flex-shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-accent/15 to-accent/5 text-accent transition-transform duration-300 group-hover/item:scale-110 group-hover/item:-translate-y-0.5">
              <Sparkles className="h-5 w-5 md:h-7 md:w-7 animate-float" style={{ animationDelay: '0.5s' }} />
            </div>
            <div>
              <h3 className="text-xs md:text-base font-bold text-text-primary">Free Shipping</h3>
              <p className="hidden md:block text-xs text-text-secondary mt-0.5 leading-relaxed">
                Order your daily essentials and get free contactless delivery for cart values above ₹199.
              </p>
            </div>
          </div>

          {/* Freshness */}
          <div className="group/item flex items-start gap-4 border-t border-border/60 pt-4 md:border-t-0 md:pt-0 cursor-default">
            <div className="flex h-10 w-10 md:h-14 md:w-14 flex-shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-discount/15 to-discount/5 text-discount transition-transform duration-300 group-hover/item:scale-110 group-hover/item:-translate-y-0.5">
              <ShieldCheck className="h-5 w-5 md:h-7 md:w-7 animate-float" style={{ animationDelay: '1s' }} />
            </div>
            <div>
              <h3 className="text-xs md:text-base font-bold text-text-primary">Super Fresh Guarantee</h3>
              <p className="hidden md:block text-xs text-text-secondary mt-0.5 leading-relaxed">
                Handpicked vegetables and fruits sourced daily. If you are not satisfied, return at the door.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
