'use client'

import { useUIStore } from '@/stores/ui-store'
import Link from 'next/link'
import { MapPin, Phone, Mail, Clock } from 'lucide-react'
import { Logo } from '@/components/layout/logo'
import { formatPhone } from '@/lib/utils'

export function Footer() {
  const settings = useUIStore((s) => s.settings) || {}
  const isLoaded = Object.keys(settings).length > 0

  const trustedText = isLoaded ? (settings.trusted_text || '✨ Trusted by 5,000+ families in your town') : null
  const contactPhone = settings.contact_phone || '+91 70544 70303'
  const contactEmail = settings.contact_email || 'help@fastkirana.com'
  const contactTimings = settings.contact_timings || '6 AM - 12 AM'
  const contactAddress = settings.contact_address || 'NH34, Ghatampur, Kanpur Nagar'

  return (
    <footer className="relative bg-[#09090b] text-zinc-400 mt-0 overflow-hidden border-t border-zinc-900/60 pb-[80px] md:pb-12 select-none">
      
      {/* Apple Liquid Display Ambient Bottom Glow */}
      <div className="absolute -bottom-20 left-1/2 -translate-x-1/2 w-[700px] h-[350px] rounded-full bg-gradient-to-t from-rose-500/10 via-orange-500/[0.03] to-transparent blur-[120px] pointer-events-none select-none z-0" />

      {/* Social Proof Glass Strip */}
      <div className="relative z-10 bg-white/[0.02] border-b border-white/[0.05] backdrop-blur-md">
        <div className="mx-auto max-w-7xl px-4 py-3.5 text-center">
          <p className="text-xs md:text-sm font-semibold tracking-wide text-zinc-300 min-h-[20px] flex items-center justify-center">
            {trustedText === null ? (
              <span className="inline-block h-4 w-52 animate-pulse bg-white/10 rounded-md" />
            ) : (
              trustedText
            )}
          </p>
        </div>
      </div>

      <div className="relative z-10 mx-auto max-w-7xl px-6 py-12 md:py-16">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          
          {/* Brand & Socials */}
          <div className="col-span-2 md:col-span-1 space-y-4">
            <div>
              <Logo lightMode={true} />
            </div>
            <p className="text-xs md:text-[13px] text-zinc-500 leading-relaxed font-medium">
              Groceries and daily essentials delivered instantly from local dark stores. Fresh fruits, vegetables, dairy, and kitchen specials at your door.
            </p>
            {/* Social Links */}
            <div className="flex items-center gap-3 pt-2">
              <a
                href="#"
                className="flex items-center justify-center h-8.5 w-8.5 rounded-full bg-white/5 border border-white/10 text-zinc-450 hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300 hover:scale-105"
                aria-label="Instagram"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.051C.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                </svg>
              </a>
              <a
                href="#"
                className="flex items-center justify-center h-8.5 w-8.5 rounded-full bg-white/5 border border-white/10 text-zinc-450 hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300 hover:scale-105"
                aria-label="Twitter"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </a>
              <a
                href="#"
                className="flex items-center justify-center h-8.5 w-8.5 rounded-full bg-white/5 border border-white/10 text-zinc-450 hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300 hover:scale-105"
                aria-label="Facebook"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M9 8h-3v4h3v12h5v-12h3.642l.358-4h-4v-1.667c0-.955.192-1.333 1.115-1.333h2.885v-5h-3.808c-3.596 0-5.192 1.583-5.192 4.615v3.385z" />
                </svg>
              </a>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h4 className="text-[11.5px] font-bold mb-4.5 text-zinc-200 uppercase tracking-widest select-none">Shop</h4>
            <ul className="space-y-3">
              <li><Link href="/category/fruits-vegetables" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Fruits &amp; Vegetables</Link></li>
              <li><Link href="/category/dairy-breakfast" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Dairy &amp; Breakfast</Link></li>
              <li><Link href="/category/snacks-munchies" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Snacks</Link></li>
              <li><Link href="/category/beverages" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Beverages</Link></li>
            </ul>
          </div>

          {/* Account */}
          <div>
            <h4 className="text-[11.5px] font-bold mb-4.5 text-zinc-200 uppercase tracking-widest select-none">Account</h4>
            <ul className="space-y-3">
              <li><Link href="/account?tab=profile" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">My Profile</Link></li>
              <li><Link href="/account?tab=orders" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">My Orders</Link></li>
              <li><Link href="/account?tab=addresses" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Saved Addresses</Link></li>
              <li><Link href="/cart" className="text-xs font-semibold text-zinc-450 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Cart</Link></li>
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h4 className="text-[11.5px] font-bold mb-4.5 text-zinc-200 uppercase tracking-widest select-none">Contact</h4>
            <ul className="space-y-3">
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-450">
                <Phone size={13} className="shrink-0 text-zinc-500" /> 
                <span className="hover:text-white transition-colors cursor-pointer">{formatPhone(contactPhone)}</span>
              </li>
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-450">
                <Mail size={13} className="shrink-0 text-zinc-500" /> 
                <span className="hover:text-white transition-colors cursor-pointer">{contactEmail}</span>
              </li>
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-450">
                <Clock size={13} className="shrink-0 text-zinc-500" /> {contactTimings}
              </li>
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-450 leading-relaxed">
                <MapPin size={13} className="shrink-0 text-zinc-500" /> {contactAddress}
              </li>
            </ul>
          </div>
        </div>

        {/* Footer Bottom Rights */}
        <div className="mt-12 border-t border-white/[0.06] pt-6.5 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-[11px] font-medium text-zinc-600 dark:text-zinc-550 select-none">
            © {new Date().getFullYear()} FastKirana. All rights reserved.
          </p>
          <p className="text-[11px] font-medium text-zinc-650 dark:text-zinc-550 order-3 md:order-none select-none">
            We accept: UPI • Cards • COD • Wallets
          </p>
          <div className="flex items-center gap-4.5">
            <Link href="/privacy-policy" className="text-[11px] font-medium text-zinc-600 dark:text-zinc-500 hover:text-zinc-350 transition-colors">Privacy Policy</Link>
            <Link href="#" className="text-[11px] font-medium text-zinc-600 dark:text-zinc-500 hover:text-zinc-350 transition-colors">Terms of Service</Link>
            <Link href="#" className="text-[11px] font-medium text-zinc-600 dark:text-zinc-500 hover:text-zinc-350 transition-colors">Refund Policy</Link>
          </div>
        </div>
      </div>
    </footer>
  )
}
