import Link from 'next/link'
import { UtensilsCrossed, Home, ArrowRight } from 'lucide-react'

export default function RestaurantNotFound() {
  return (
    <div className="min-h-[75vh] flex flex-col items-center justify-center px-4 py-16 text-center select-none bg-background">
      <div className="relative z-10 max-w-md w-full space-y-6">
        <div className="mx-auto h-16 w-16 rounded-full bg-rose-50 dark:bg-rose-950/30 border border-rose-200 dark:border-rose-900/40 flex items-center justify-center shadow-md">
          <UtensilsCrossed className="h-8 w-8 text-rose-500 stroke-[2]" />
        </div>

        <div className="space-y-2">
          <h1 className="text-xl sm:text-2xl font-black text-text-primary tracking-tight">
            Restaurant Not Found
          </h1>
          <p className="text-xs font-bold text-text-secondary leading-relaxed px-4">
            We couldn't find the restaurant you were looking for. It may have moved or is temporarily unavailable.
          </p>
        </div>

        <div className="flex flex-col sm:flex-row gap-3 justify-center items-center px-4 pt-2">
          <Link
            href="/food"
            className="w-full sm:w-auto px-6 py-2.5 rounded-2xl bg-primary text-white hover:bg-primary/95 text-xs font-black tracking-wide shadow-md shadow-primary/10 transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-98"
          >
            Browse All Restaurants
            <ArrowRight size={13} />
          </Link>

          <Link
            href="/"
            className="w-full sm:w-auto px-6 py-2.5 rounded-2xl bg-zinc-100 dark:bg-zinc-900 text-zinc-800 dark:text-zinc-200 border border-zinc-200/40 dark:border-zinc-800/40 hover:bg-zinc-200 dark:hover:bg-zinc-850 text-xs font-black tracking-wide transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-98"
          >
            <Home size={13} />
            Back to Home
          </Link>
        </div>
      </div>
    </div>
  )
}
