'use client'

import React from 'react'
import { WifiOff, RefreshCw, ShoppingBag } from 'lucide-react'
import Link from 'next/link'

export default function OfflinePage() {
  const handleReload = () => {
    if (typeof window !== 'undefined') {
      window.location.reload()
    }
  }

  return (
    <div className="min-h-[75vh] flex items-center justify-center px-4 py-12">
      <div className="max-w-md w-full text-center space-y-6 bg-card border border-border/60 rounded-3xl p-8 shadow-xl">
        <div className="mx-auto w-20 h-20 rounded-full bg-red-500/10 text-red-500 flex items-center justify-center animate-pulse">
          <WifiOff size={36} />
        </div>

        <div className="space-y-2">
          <h1 className="text-2xl font-black text-foreground tracking-tight">
            You&apos;re Offline
          </h1>
          <p className="text-sm text-text-secondary leading-relaxed">
            It looks like you lost your internet connection. FastKirana will automatically reconnect when your network is restored.
          </p>
        </div>

        <div className="pt-2 flex flex-col sm:flex-row gap-3 justify-center">
          <button
            onClick={handleReload}
            className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-2xl bg-primary text-primary-foreground font-black text-sm shadow-md hover:bg-primary/90 active:scale-95 transition-all cursor-pointer"
          >
            <RefreshCw size={16} />
            Try Again
          </button>

          <Link
            href="/"
            className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-2xl border border-border bg-card hover:bg-muted font-bold text-sm text-foreground transition-all"
          >
            <ShoppingBag size={16} />
            Cached Storefront
          </Link>
        </div>
      </div>
    </div>
  )
}
