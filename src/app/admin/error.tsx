'use client'

import { useEffect } from 'react'
import { RotateCw, ShieldAlert, ArrowLeft } from 'lucide-react'
import Link from 'next/link'

export default function AdminError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error('Admin Console Error:', error)
  }, [error])

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 flex flex-col items-center justify-center p-4">
      <div className="max-w-md w-full bg-card border border-border/70 rounded-3xl p-6 sm:p-8 text-center shadow-lg space-y-5">
        <div className="h-14 w-14 rounded-2xl bg-rose-500/10 text-rose-500 border border-rose-500/20 flex items-center justify-center mx-auto">
          <ShieldAlert className="w-7 h-7" />
        </div>

        <div className="space-y-2">
          <h2 className="text-xl font-black text-text-primary tracking-tight">
            Admin Console Hiccup
          </h2>
          <p className="text-xs text-text-secondary leading-relaxed font-medium">
            An unexpected error occurred while rendering the admin dashboard. Tap below to refresh data.
          </p>
        </div>

        {process.env.NODE_ENV === 'development' && error?.message && (
          <div className="p-3 bg-muted/60 rounded-xl text-[11px] font-mono text-rose-500 text-left overflow-x-auto border border-border">
            {error.message}
          </div>
        )}

        <div className="flex flex-col sm:flex-row items-center gap-3 pt-2">
          <button
            onClick={() => reset()}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-red-600 hover:bg-red-700 text-white rounded-xl text-xs font-black transition-all cursor-pointer shadow-md active:scale-95"
          >
            <RotateCw className="w-4 h-4" />
            Reload Admin View
          </button>
          <Link
            href="/"
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-muted hover:bg-muted/80 text-text-primary rounded-xl text-xs font-bold transition-all border border-border"
          >
            <ArrowLeft className="w-4 h-4" />
            Return Home
          </Link>
        </div>
      </div>
    </div>
  )
}
