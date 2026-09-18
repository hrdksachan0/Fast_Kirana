'use client'

import { useEffect } from 'react'
import { RotateCcw, Home } from 'lucide-react'
import { reportClientError } from '@/lib/telemetry'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error('FastKirana root global error caught:', error)
    reportClientError(error, {
      severity: 'CRITICAL',
      metadata: { digest: error?.digest, fatal: true },
    })
  }, [error])

  return (
    <html lang="en">
      <body className="min-h-screen bg-zinc-950 text-white flex items-center justify-center p-4 font-sans antialiased">
        <div className="max-w-md w-full text-center p-6 sm:p-8 bg-zinc-900/90 rounded-[28px] border border-zinc-800 shadow-2xl space-y-6">
          <div className="w-16 h-16 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center mx-auto text-2xl font-black shadow-inner">
            ⚡
          </div>
          
          <div className="space-y-2">
            <h2 className="text-xl font-black text-white tracking-tight">Something went wrong</h2>
            <p className="text-xs sm:text-sm text-zinc-400 leading-relaxed font-medium">
              We encountered a temporary interface hiccup. Your cart items and orders are completely safe.
            </p>
          </div>

          <div className="flex items-center justify-center gap-3 pt-2">
            <button
              type="button"
              onClick={() => reset()}
              className="flex-1 h-11 rounded-xl bg-[#00875a] hover:bg-[#00704a] text-white text-xs sm:text-sm font-extrabold flex items-center justify-center gap-2 transition-all cursor-pointer shadow-md active:scale-95"
            >
              <RotateCcw className="w-4 h-4 stroke-[2.5]" />
              <span>Try Again</span>
            </button>
            <button
              type="button"
              onClick={() => {
                if (typeof window !== 'undefined') {
                  window.location.href = '/'
                }
              }}
              className="flex-1 h-11 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs sm:text-sm font-bold flex items-center justify-center gap-2 transition-all cursor-pointer border border-zinc-700 active:scale-95"
            >
              <Home className="w-4 h-4" />
              <span>Go Home</span>
            </button>
          </div>
        </div>
      </body>
    </html>
  )
}
