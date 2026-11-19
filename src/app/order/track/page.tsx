import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Search, Truck, Gift } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function OrderTrackFallbackPage({
  searchParams,
}: {
  searchParams: Promise<{ id?: string; phone?: string }>
}) {
  const session = await auth()
  const { id: queryId, phone: queryPhone } = await searchParams

  if (queryId) {
    redirect(`/order/${encodeURIComponent(queryId)}/track`)
  }

  // If user is logged in, look up their most recent active order
  if (session?.user?.id) {
    const recentOrders: any[] = await prisma.$queryRaw`
      SELECT id FROM orders 
      WHERE "userId" = ${session.user.id} 
        AND status::text NOT IN ('CANCELLED', 'DELIVERED')
      ORDER BY "createdAt" DESC 
      LIMIT 1
    `
    if (recentOrders.length > 0 && recentOrders[0].id) {
      redirect(`/order/${recentOrders[0].id}/track`)
    }
  }

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 flex flex-col items-center justify-center p-4">
      <div className="max-w-md w-full bg-white dark:bg-zinc-900 rounded-3xl p-6 shadow-xl border border-zinc-200/80 dark:border-zinc-800 text-center space-y-6">
        <div className="w-16 h-16 rounded-2xl bg-rose-50 dark:bg-rose-950/40 text-rose-600 flex items-center justify-center mx-auto shadow-sm">
          <Truck className="w-8 h-8" />
        </div>

        <div>
          <h1 className="text-xl font-black text-zinc-900 dark:text-white">Track Your Live Delivery</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-1.5 leading-relaxed">
            Enter your Order ID (e.g. #4193) or registered phone number to view real-time GPS tracking.
          </p>
        </div>

        <form action="/order/track" method="GET" className="space-y-3">
          <div className="relative">
            <input
              type="text"
              name="id"
              placeholder="Enter Order ID (e.g. 4193)"
              className="w-full h-12 pl-4 pr-11 rounded-2xl bg-zinc-100 dark:bg-zinc-800 text-sm font-bold text-zinc-900 dark:text-white placeholder:text-zinc-400 border border-transparent focus:border-rose-500 focus:outline-none transition-all"
              required
            />
            <button
              type="submit"
              className="absolute right-2 top-2 h-8 w-8 rounded-xl bg-rose-600 text-white flex items-center justify-center hover:bg-rose-700 transition-colors cursor-pointer"
            >
              <Search className="w-4 h-4" />
            </button>
          </div>
        </form>

        <div className="pt-2 border-t border-zinc-100 dark:border-zinc-800 flex items-center justify-between text-xs text-zinc-500">
          <Link href="/" className="inline-flex items-center gap-1.5 font-bold text-rose-600 hover:underline">
            <ArrowLeft className="w-3.5 h-3.5" /> Back to Store
          </Link>
          <span className="inline-flex items-center gap-1 font-semibold text-zinc-400">
            <Gift className="w-3.5 h-3.5 text-rose-500" /> Surprise Gift Safe
          </span>
        </div>
      </div>
    </div>
  )
}
