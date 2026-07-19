'use client'

import { useEffect } from 'react'
import { AlertCircle, RefreshCw, Home, ShieldAlert } from 'lucide-react'
import Link from 'next/link'
import { triggerHaptic } from '@/lib/haptic'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    // Log the error to console or an analytics service
    console.error('FastKirana App Crash Error:', error)
  }, [error])

  const handleRetry = () => {
    triggerHaptic('medium')
    // Attempt to recover by trying to re-render the segment
    reset()
  }

  const handleHardReload = () => {
    triggerHaptic('warning')
    window.location.reload()
  }

  return (
    <div className="min-h-[75vh] flex flex-col items-center justify-center px-4 py-16 text-center select-none bg-background">
      
      {/* Ambient background glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[350px] h-[350px] rounded-full bg-primary/5 blur-[100px] pointer-events-none z-0" />

      <div className="relative z-10 max-w-md w-full space-y-6">
        {/* Warning Icon with pulse glow */}
        <div className="mx-auto h-16 w-16 rounded-full bg-rose-50 dark:bg-rose-950/20 border border-rose-100 dark:border-rose-900/40 flex items-center justify-center shadow-md animate-pulse">
          <ShieldAlert className="h-8 w-8 text-rose-500 stroke-[2.2]" />
        </div>

        {/* Heading & description */}
        <div className="space-y-2">
          <h1 className="text-xl sm:text-2xl font-black text-text-primary tracking-tight">
            Store Connection Refreshing
          </h1>
          <p className="text-xs font-bold text-text-secondary leading-relaxed px-4">
            Our cloud database was sleeping to save energy and is now waking up. 
            This can cause a temporary timeout when loading the screen.
          </p>
        </div>

        {/* Diagnostic info (collapsible in dev, hidden in prod) */}
        {process.env.NODE_ENV === 'development' && (
          <div className="p-3 bg-muted/50 rounded-xl text-[10px] text-rose-600 dark:text-rose-400 font-mono text-left max-h-[120px] overflow-y-auto border border-border">
            {error.message || 'Unknown exception occurred.'}
            {error.stack && <pre className="mt-1 text-[8.5px] opacity-75">{error.stack}</pre>}
          </div>
        )}

        {/* CTA Actions */}
        <div className="flex flex-col sm:flex-row gap-3 justify-center items-center px-4 pt-2">
          {/* Quick retry */}
          <button
            onClick={handleRetry}
            className="w-full sm:w-auto px-6 py-2.5 rounded-2xl bg-primary text-white hover:bg-primary/95 text-xs font-black tracking-wide shadow-md shadow-primary/10 transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-98"
          >
            <RefreshCw size={13} className="animate-spin-slow" />
            Quick Retry
          </button>

          {/* Hard reload */}
          <button
            onClick={handleHardReload}
            className="w-full sm:w-auto px-6 py-2.5 rounded-2xl bg-zinc-100 dark:bg-zinc-900 text-zinc-800 dark:text-zinc-200 border border-zinc-200/40 dark:border-zinc-800/40 hover:bg-zinc-200 dark:hover:bg-zinc-850 text-xs font-black tracking-wide transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-98"
          >
            Hard Reload
          </button>
        </div>

        {/* Return to Home link */}
        <div className="pt-2">
          <Link
            href="/"
            className="inline-flex items-center gap-1 text-[11px] font-extrabold text-zinc-500 hover:text-primary transition-colors"
          >
            <Home size={11} />
            Back to Homepage
          </Link>
        </div>
      </div>
    </div>
  )
}
