'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { MapPin, Phone, Mail, Clock } from 'lucide-react'
import { Logo } from '@/components/layout/logo'

export function Footer() {
  const [trustedText, setTrustedText] = useState('✨ Trusted by 5,000+ families in your town')

  useEffect(() => {
    fetch('/api/settings')
      .then((res) => res.json())
      .then((data) => {
        if (data.trusted_text) {
          setTrustedText(data.trusted_text)
        }
      })
      .catch((err) => console.error('Failed to load settings in footer:', err))
  }, [])

  return (
    <footer className="bg-text-primary text-white mt-2 md:mt-4 pb-[80px] md:pb-8">
      {/* Social proof strip */}
      <div className="bg-accent/10 border-b border-accent/20">
        <div className="mx-auto max-w-7xl px-4 py-3 text-center">
          <p className="text-sm font-bold text-accent">
            {trustedText}
          </p>
        </div>
      </div>

      <div className="mx-auto max-w-7xl px-4 py-8 md:py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <div className="mb-4">
              <Logo lightMode={true} />
            </div>
            <p className="text-sm text-gray-400 leading-relaxed">
              Groceries and daily essentials delivered instantly from our local dark stores. Fresh fruits, vegetables, dairy, and snacks at your doorstep in 10 minutes.
            </p>
            {/* Social media links */}
            <div className="flex items-center gap-3 mt-4">
              <a
                href="#"
                className="flex items-center justify-center h-9 w-9 rounded-full bg-white/10 text-gray-400 hover:bg-accent/20 hover:text-accent transition-all duration-200 hover:scale-110"
                aria-label="Instagram"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.051C.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
                </svg>
              </a>
              <a
                href="#"
                className="flex items-center justify-center h-9 w-9 rounded-full bg-white/10 text-gray-400 hover:bg-accent/20 hover:text-accent transition-all duration-200 hover:scale-110"
                aria-label="Twitter"
              >
                <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </a>
              <a
                href="#"
                className="flex items-center justify-center h-9 w-9 rounded-full bg-white/10 text-gray-400 hover:bg-accent/20 hover:text-accent transition-all duration-200 hover:scale-110"
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
            <h4 className="text-sm font-semibold mb-4 text-gray-300 uppercase tracking-wider">Shop</h4>
            <ul className="space-y-2.5">
              <li><Link href="/category/fruits-vegetables" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">Fruits & Vegetables</Link></li>
              <li><Link href="/category/dairy-breakfast" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">Dairy & Breakfast</Link></li>
              <li><Link href="/category/snacks-munchies" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">Snacks</Link></li>
              <li><Link href="/category/beverages" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">Beverages</Link></li>
            </ul>
          </div>

          {/* Account */}
          <div>
            <h4 className="text-sm font-semibold mb-4 text-gray-300 uppercase tracking-wider">Account</h4>
            <ul className="space-y-2.5">
              <li><Link href="/account?tab=profile" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">My Profile</Link></li>
              <li><Link href="/account?tab=orders" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">My Orders</Link></li>
              <li><Link href="/account?tab=addresses" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">Saved Addresses</Link></li>
              <li><Link href="/cart" className="text-sm text-gray-400 hover:text-white hover:translate-x-1 transition-all duration-200 inline-block">Cart</Link></li>
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h4 className="text-sm font-semibold mb-4 text-gray-300 uppercase tracking-wider">Contact</h4>
            <ul className="space-y-2.5">
              <li className="flex items-center gap-2 text-sm text-gray-400">
                <Phone size={14} className="shrink-0" /> +91 70544 70303
              </li>
              <li className="flex items-center gap-2 text-sm text-gray-400">
                <Mail size={14} className="shrink-0" /> help@fastkirana.com
              </li>
              <li className="flex items-center gap-2 text-sm text-gray-400">
                <Clock size={14} className="shrink-0" /> 6 AM - 12 AM
              </li>
              <li className="flex items-center gap-2 text-sm text-gray-400">
                <MapPin size={14} className="shrink-0" /> NH34, Ghatampur, Kanpur Nagar
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-10 border-t border-gray-700 pt-6 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-xs text-gray-500">
            © {new Date().getFullYear()} FastKirana. All rights reserved.
          </p>
          <p className="text-xs text-gray-500 order-3 md:order-none">
            We accept: UPI • Cards • COD • Wallets
          </p>
          <div className="flex items-center gap-4">
            <Link href="#" className="text-xs text-gray-500 hover:text-gray-300 hover:translate-x-1 transition-all duration-200 inline-block">Privacy Policy</Link>
            <Link href="#" className="text-xs text-gray-500 hover:text-gray-300 hover:translate-x-1 transition-all duration-200 inline-block">Terms of Service</Link>
            <Link href="#" className="text-xs text-gray-500 hover:text-gray-300 hover:translate-x-1 transition-all duration-200 inline-block">Refund Policy</Link>
          </div>
        </div>
      </div>
    </footer>
  )
}
