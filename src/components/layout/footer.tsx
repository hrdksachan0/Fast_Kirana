'use client'

import { useUIStore } from '@/stores/ui-store'
import Link from 'next/link'
import { MapPin, Phone, Mail, Clock } from 'lucide-react'
import { Logo } from '@/components/layout/logo'
import { formatPhone } from '@/lib/utils'
import { usePathname } from 'next/navigation'

export function Footer() {
  const pathname = usePathname()
  const settings = useUIStore((s) => s.settings) || {}

  // Hide storefront footer on admin & kitchen/staff consoles
  if (
    pathname?.startsWith('/admin') ||
    pathname?.startsWith('/restaurant-kitchen') ||
    pathname?.startsWith('/cafe-kitchen') ||
    pathname?.startsWith('/picker') ||
    pathname?.startsWith('/delivery')
  ) {
    return null
  }
  const isLoaded = Object.keys(settings).length > 0

  const trustedText = isLoaded ? (settings.trusted_text || '✨ Trusted by 5,000+ families in your town') : null
  const contactPhone = settings.contact_phone || '+91 70544 70303'
  const contactEmail = settings.contact_email || 'help@fastminute.in'
  const contactTimings = settings.contact_timings || '6 AM - 12 AM'
  const contactAddress = settings.contact_address || 'NH34, Ghatampur, Kanpur Nagar'

  return (
    <footer className="relative bg-[#09090b] text-zinc-400 mt-0 overflow-hidden border-t border-zinc-900/60 pb-[100px] md:pb-12 select-none">
      
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
        <div className="grid grid-cols-2 gap-8 md:grid-cols-3 lg:grid-cols-5">
          
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
                href="https://instagram.com"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center h-8.5 w-8.5 rounded-full bg-white/5 border border-white/10 text-zinc-400 hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300 hover:scale-105"
                aria-label="Instagram"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.051C.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                </svg>
              </a>
              <a
                href="https://x.com"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center h-8.5 w-8.5 rounded-full bg-white/5 border border-white/10 text-zinc-400 hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300 hover:scale-105"
                aria-label="Twitter"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </a>
              <a
                href="https://facebook.com"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center h-8.5 w-8.5 rounded-full bg-white/5 border border-white/10 text-zinc-400 hover:bg-white/10 hover:border-white/20 hover:text-white transition-all duration-300 hover:scale-105"
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
              <li><Link href="/category/fruits-vegetables" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Fruits &amp; Vegetables</Link></li>
              <li><Link href="/category/dairy-breakfast" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Dairy &amp; Breakfast</Link></li>
              <li><Link href="/category/snacks-munchies" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Snacks</Link></li>
              <li><Link href="/category/beverages" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Beverages</Link></li>
            </ul>
          </div>

          {/* Account */}
          <div>
            <h4 className="text-[11.5px] font-bold mb-4.5 text-zinc-200 uppercase tracking-widest select-none">Account</h4>
            <ul className="space-y-3">
              <li><Link href="/account?tab=profile" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">My Profile</Link></li>
              <li><Link href="/account?tab=orders" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">My Orders</Link></li>
              <li><Link href="/account?tab=addresses" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Saved Addresses</Link></li>
              <li><Link href="/cart" prefetch={false} className="text-xs font-semibold text-zinc-400 hover:text-white hover:translate-x-0.5 transition-all duration-300 inline-block">Cart</Link></li>
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h4 className="text-[11.5px] font-bold mb-4.5 text-zinc-200 uppercase tracking-widest select-none">Contact</h4>
            <ul className="space-y-3">
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-400">
                <Phone size={13} className="shrink-0 text-zinc-500" /> 
                <span className="hover:text-white transition-colors cursor-pointer">{formatPhone(contactPhone)}</span>
              </li>
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-400">
                <Mail size={13} className="shrink-0 text-zinc-500" /> 
                <span className="hover:text-white transition-colors cursor-pointer">{contactEmail}</span>
              </li>
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-400">
                <Clock size={13} className="shrink-0 text-zinc-500" /> {contactTimings}
              </li>
              <li className="flex items-center gap-2.5 text-xs font-semibold text-zinc-400 leading-relaxed">
                <MapPin size={13} className="shrink-0 text-zinc-500" /> {contactAddress}
              </li>
            </ul>
          </div>

          {/* Download App */}
          <div className="col-span-2 md:col-span-1">
            <h4 className="text-[11.5px] font-bold mb-4.5 text-zinc-200 uppercase tracking-widest select-none">Download App</h4>
            <p className="text-xs text-zinc-500 mb-3.5 leading-relaxed">
              Experience ultra-fast grocery & food deliveries with live tracking on our mobile app.
            </p>
            <div className="flex flex-col sm:flex-row md:flex-col gap-2.5">
              <a
                href="https://play.google.com/store/apps/details?id=com.fastkirana.app"
                target="_blank"
                rel="noopener noreferrer"
                className="group flex items-center gap-3 px-3.5 py-2.5 rounded-xl bg-zinc-900/90 border border-zinc-700/80 hover:border-emerald-500/60 hover:bg-zinc-800/90 transition-all duration-300 shadow-sm hover:shadow-emerald-500/10 active:scale-[0.98]"
              >
                <svg className="w-6 h-6 shrink-0 transition-transform group-hover:scale-105" viewBox="0 0 24 24" fill="none">
                  <path d="M3.609 1.814L13.793 12 3.61 22.186c-.378-.44-.61-1.037-.61-1.706V3.52c0-.669.232-1.266.61-1.706z" fill="#00C1A6"/>
                  <path d="M17.18 8.613l-3.387 3.387L3.609 1.814C4.015 1.48 4.549 1.28 5.132 1.28c.556 0 1.07.183 1.486.495l10.562 6.838z" fill="#00D2FF"/>
                  <path d="M17.18 15.387l-10.562 6.838c-.416.312-.93.495-1.486.495-.583 0-1.117-.2-1.523-.534L13.793 12l3.387 3.387z" fill="#FF334B"/>
                  <path d="M21.22 11.233l-4.04-2.62-3.387 3.387 3.387 3.387 4.04-2.62c.732-.475 1.18-1.304 1.18-2.267 0-.963-.448-1.792-1.18-2.267z" fill="#FFBA00"/>
                </svg>
                <div className="flex flex-col text-left">
                  <span className="text-[10px] uppercase font-bold tracking-wider text-zinc-400 group-hover:text-zinc-300 transition-colors leading-none">
                    Get it on
                  </span>
                  <span className="text-[13px] font-bold text-white group-hover:text-emerald-400 transition-colors leading-tight mt-0.5">
                    Google Play
                  </span>
                </div>
              </a>

              <div
                className="flex items-center gap-3 px-3.5 py-2.5 rounded-xl bg-zinc-900/40 border border-zinc-800/80 text-zinc-500 cursor-not-allowed select-none opacity-80"
                title="iOS App Coming Soon"
              >
                <svg className="w-6 h-6 shrink-0 fill-current text-zinc-400" viewBox="0 0 24 24">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.42c.62-.75 1.04-1.8 0.92-2.85-.9.04-1.98.6-2.61 1.34-.55.63-.99 1.66-.86 2.69 1 .08 1.95-.49 2.55-1.18z"/>
                </svg>
                <div className="flex flex-col text-left">
                  <span className="text-[9px] uppercase font-bold tracking-wider text-zinc-500 leading-none">
                    Coming Soon on
                  </span>
                  <span className="text-[12.5px] font-bold text-zinc-300 leading-tight mt-0.5">
                    App Store
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer Bottom Rights */}
        <div className="mt-12 border-t border-white/[0.06] pt-6.5 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-[11px] font-medium text-zinc-600 dark:text-zinc-500 select-none">
            © {new Date().getFullYear()} FastMinute. All rights reserved.
          </p>
          <p className="text-[11px] font-medium text-zinc-600 dark:text-zinc-500 order-3 md:order-none select-none">
            We accept: UPI • Cards • COD • Wallets
          </p>
          <div className="flex flex-wrap items-center justify-center md:justify-end gap-x-4.5 gap-y-2">
            <Link href="/privacy-policy" className="text-[11px] font-medium text-zinc-500 hover:text-zinc-300 transition-colors">Privacy Policy</Link>
            <Link href="/terms" className="text-[11px] font-medium text-zinc-500 hover:text-zinc-300 transition-colors">Terms of Service</Link>
            <Link href="/refund-policy" className="text-[11px] font-medium text-zinc-500 hover:text-zinc-300 transition-colors">Refund Policy</Link>
            <Link href="/shipping-policy" className="text-[11px] font-medium text-zinc-500 hover:text-zinc-300 transition-colors">Shipping Policy</Link>
            <Link href="/contact" className="text-[11px] font-medium text-zinc-500 hover:text-zinc-300 transition-colors">Contact Us</Link>
          </div>
        </div>
      </div>
    </footer>
  )
}
