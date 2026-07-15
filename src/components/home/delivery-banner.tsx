'use client'

import { Truck, Sparkles, ShieldCheck, Store } from 'lucide-react'

export function DeliveryBanner() {
  return (
    <section className="py-4 md:py-6 mt-1 md:mt-2 mb-0 px-1">
      {/* Floating Tagline Pill */}
      <div className="flex justify-center mb-5">
        <span className="inline-flex items-center gap-2 px-4.5 py-1.5 rounded-full text-[10px] md:text-xs font-semibold bg-white/95 dark:bg-zinc-900/65 border border-zinc-200/60 dark:border-zinc-800/50 shadow-2xs backdrop-blur-md text-text-primary tracking-wide">
          <Store className="h-3.5 w-3.5 text-primary shrink-0" />
          <span>From Your Town&apos;s Dark Store — Packed &amp; Delivered by <span className="text-primary font-bold">FastKirana</span></span>
        </span>
      </div>

      {/* 3 Columns Grid of Premium Micro-Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6">
        {/* Instant Delivery */}
        <div className="group flex items-center md:items-start gap-4 p-4 rounded-2xl bg-white/60 dark:bg-zinc-950/45 border border-zinc-200/50 dark:border-zinc-800/40 shadow-2xs hover:border-primary/20 dark:hover:border-primary/20 hover:bg-white/80 dark:hover:bg-zinc-900/30 transition-all duration-300">
          <div className="flex h-11 w-11 md:h-12 md:w-12 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-primary/10 to-primary/5 text-primary border border-primary/10 shadow-3xs">
            <Truck className="h-5.5 w-5.5 text-primary" />
          </div>
          <div className="text-left">
            <h3 className="text-xs md:text-sm font-bold text-text-primary">Fast Instant Delivery</h3>
            <p className="text-[10px] md:text-xs text-text-secondary mt-0.5 leading-relaxed font-medium">
              Delivered fresh from local dark stores to your doorstep within 3 km.
            </p>
          </div>
        </div>

        {/* Free Shipping */}
        <div className="group flex items-center md:items-start gap-4 p-4 rounded-2xl bg-white/60 dark:bg-zinc-950/45 border border-zinc-200/50 dark:border-zinc-800/40 shadow-2xs hover:border-accent/20 dark:hover:border-accent/20 hover:bg-white/80 dark:hover:bg-zinc-900/30 transition-all duration-300">
          <div className="flex h-11 w-11 md:h-12 md:w-12 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-accent/10 to-accent/5 text-accent border border-accent/10 shadow-3xs">
            <Sparkles className="h-5.5 w-5.5 text-accent" />
          </div>
          <div className="text-left">
            <h3 className="text-xs md:text-sm font-bold text-text-primary">Smart Shipping Rates</h3>
            <div className="text-[10px] md:text-xs text-text-secondary mt-1 leading-relaxed font-medium space-y-0.5">
              <div>📍 0 to 2 km: FREE delivery above ₹199 (else ₹25)</div>
              <div>📍 2 to 3 km: FREE delivery above ₹249 (else ₹35)</div>
              <div className="text-[9px] font-black text-primary uppercase pt-0.5">⚡ Min. Order Value is just ₹20!</div>
            </div>
          </div>
        </div>

        {/* Freshness */}
        <div className="group flex items-center md:items-start gap-4 p-4 rounded-2xl bg-white/60 dark:bg-zinc-950/45 border border-zinc-200/50 dark:border-zinc-800/40 shadow-2xs hover:border-discount/20 dark:hover:border-discount/20 hover:bg-white/80 dark:hover:bg-zinc-900/30 transition-all duration-300">
          <div className="flex h-11 w-11 md:h-12 md:w-12 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-discount/10 to-discount/5 text-discount border border-discount/10 shadow-3xs">
            <ShieldCheck className="h-5.5 w-5.5 text-discount" />
          </div>
          <div className="text-left">
            <h3 className="text-xs md:text-sm font-bold text-text-primary">Super Fresh Guarantee</h3>
            <p className="text-[10px] md:text-xs text-text-secondary mt-0.5 leading-relaxed font-medium">
              Handpicked farm-fresh products. Satisfied or return at your door.
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}
