'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useSession, signOut } from 'next-auth/react'
import { Utensils, LogOut, Clock, ShieldCheck, Home } from 'lucide-react'
import { AdminRestaurantConsole } from '@/components/admin/admin-restaurant-console'
import { useUIStore } from '@/stores/ui-store'

export default function RestaurantKitchenPage() {
  const { data: session, status } = useSession()
  const router = useRouter()
  const [currentTime, setCurrentTime] = useState(new Date())
  const { restaurantOpen } = useUIStore()

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/login?callbackUrl=/restaurant-kitchen')
    } else if (status === 'authenticated') {
      const role = session?.user?.role
      const email = session?.user?.email || ''
      const isAllowed = role === 'ADMIN' || (role === 'CHEF' && email.startsWith('restaurant'))
      if (!isAllowed) {
        router.push('/')
      }
    }
  }, [status, session, router])

  if (status === 'loading') {
    return (
      <div className="flex h-screen w-screen items-center justify-center bg-zinc-50 dark:bg-zinc-950">
        <div className="text-center space-y-3">
          <Utensils className="h-8 w-8 text-primary animate-spin mx-auto" />
          <p className="text-xs text-text-secondary font-bold">Verifying kitchen credentials...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950/20 py-6 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto space-y-6">
        
        {/* Header Bar */}
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-card border border-border rounded-3xl p-5 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="h-12 w-12 rounded-2xl bg-red-500/10 text-red-500 flex items-center justify-center shadow-inner">
              <Utensils className="h-6 w-6 animate-pulse-gentle" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base sm:text-lg font-black text-text-primary">Wedson Restaurant Console</h1>
                <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider ${
                  restaurantOpen
                    ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                    : 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                }`}>
                  <span className={`h-1.5 w-1.5 rounded-full ${restaurantOpen ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}`} />
                  {restaurantOpen ? 'OPEN' : 'CLOSED'}
                </span>
              </div>
              <p className="text-[10px] sm:text-xs text-text-secondary mt-0.5 flex items-center gap-1 font-medium">
                <ShieldCheck className="h-3.5 w-3.5 text-emerald-500" />
                Logged in as: <span className="font-bold text-text-primary">{session?.user?.email}</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 w-full md:w-auto">
            {/* Real-time Clock */}
            <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 bg-muted/40 rounded-xl border border-border/40 text-[11px] font-mono font-bold text-text-secondary select-none shadow-inner">
              <Clock className="h-3.5 w-3.5 text-text-muted" />
              <span>{currentTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
            </div>

            <button
              onClick={() => router.push('/')}
              className="flex-1 sm:flex-none inline-flex items-center justify-center gap-1.5 px-4.5 py-2.5 bg-card border border-border hover:bg-muted/40 text-text-secondary hover:text-text-primary text-xs font-black rounded-xl transition-all cursor-pointer"
            >
              <Home className="h-4 w-4" />
              Go Home
            </button>

            <button
              onClick={() => signOut({ callbackUrl: '/login' })}
              className="flex-1 sm:flex-none inline-flex items-center justify-center gap-1.5 px-4.5 py-2.5 bg-rose-500 text-white hover:bg-rose-600 text-xs font-black rounded-xl transition-all cursor-pointer shadow-sm shadow-rose-500/15"
            >
              <LogOut className="h-4 w-4" />
              Logout
            </button>
          </div>
        </div>

        {/* Console Container */}
        <div className="bg-card border border-border rounded-3xl p-6 shadow-sm">
          <AdminRestaurantConsole />
        </div>

      </div>
    </div>
  )
}
