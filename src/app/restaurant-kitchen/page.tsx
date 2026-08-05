'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useSession, signOut } from 'next-auth/react'
import { Utensils, LogOut, Clock, ShieldCheck, Home, ChefHat, BarChart3, Settings, IndianRupee, SlidersHorizontal, Layers } from 'lucide-react'
import { RestaurantOrdersConsole } from '@/components/admin/restaurant-orders-console'
import { RestaurantSalesConsole } from '@/components/admin/restaurant-sales-console'
import { RestaurantPayoutsLedger } from '@/components/admin/restaurant-payouts-ledger'
import { RestaurantSettingsTab } from '@/components/admin/restaurant-settings-tab'
import { RestaurantCatalogManager } from '@/components/admin/restaurant-catalog-manager'
import { RestaurantMenuSectionsEditor } from '@/components/admin/restaurant-menu-sections-editor'
import { useUIStore } from '@/stores/ui-store'
import { formatDate } from '@/lib/date-helpers'

export default function RestaurantKitchenPage() {
  const { data: session, status } = useSession()
  const router = useRouter()
  const [currentTime, setCurrentTime] = useState(new Date())
  const { restaurantOpen } = useUIStore()
  const [activeTab, setActiveTab] = useState<'orders' | 'analytics' | 'catalog' | 'sections' | 'payouts' | 'settings'>('orders')
  const [restaurantName, setRestaurantName] = useState('Restaurant Console')

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
    if (assignedRestaurantId) {
      fetch(`/api/restaurants/${assignedRestaurantId}`)
        .then(res => res.json())
        .then(data => {
          if (data && data.name) {
            setRestaurantName(`${data.name} Console`)
            
            // Auto-redirect if they belong strictly to FastKirana Cafe and are not an ADMIN/OWNER
            if (session?.user?.role !== 'ADMIN' && session?.user?.role !== 'RESTAURANT_OWNER') {
              if (data.slug === 'fastkirana-cafe') {
                router.push('/cafe-kitchen')
              }
            }
          }
        })
        .catch(err => console.error(err))
    } else {
      setRestaurantName('Restaurant Console')
    }
  }, [session, router])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/restaurant-login?callbackUrl=/restaurant-kitchen')
    } else if (status === 'authenticated') {
      const role = session?.user?.role
      const email = session?.user?.email || ''
      const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
      const isAllowed = role === 'ADMIN' || role === 'RESTAURANT_OWNER' || (role === 'CHEF' && email.toLowerCase().startsWith('restaurant')) || !!assignedRestaurantId
      if (!isAllowed) {
        router.push('/')
      }
    }
  }, [status, session, router])

  if (status === 'loading') {
    return (
      <div className="flex h-screen w-screen items-center justify-center bg-zinc-50 dark:bg-zinc-950">
        <div className="text-center space-y-3">
          <Utensils className="h-8 w-8 text-red-600 animate-spin mx-auto" />
          <p className="text-xs text-text-secondary font-bold">Verifying kitchen credentials...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950/20 py-3 sm:py-6 px-3 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto space-y-4 sm:space-y-6">
        
        {/* Header Bar */}
        <div className="flex flex-row justify-between items-center gap-3 bg-card border border-border/70 rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 shadow-xs">
          <div className="flex items-center gap-2.5 sm:gap-3 min-w-0">
            <div className="h-10 w-10 sm:h-12 sm:w-12 rounded-xl sm:rounded-2xl bg-red-500/10 text-red-500 flex items-center justify-center shrink-0 border border-red-500/20">
              <Utensils className="h-5 w-5 sm:h-6 sm:w-6 animate-pulse-gentle" />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <h1 className="text-xs sm:text-lg font-black text-text-primary uppercase tracking-tight truncate">{restaurantName}</h1>
                <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[8px] sm:text-[9px] font-black uppercase tracking-wider shrink-0 ${
                  restaurantOpen
                    ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                    : 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                }`}>
                  <span className={`h-1.5 w-1.5 rounded-full ${restaurantOpen ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}`} />
                  {restaurantOpen ? 'OPEN' : 'CLOSED'}
                </span>
              </div>
              <p className="text-[9px] sm:text-xs text-text-secondary mt-0.5 flex items-center gap-1 font-medium truncate">
                <ShieldCheck className="h-3 w-3 sm:h-3.5 sm:w-3.5 text-emerald-500 shrink-0" />
                <span className="truncate">{session?.user?.email}</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 bg-muted/40 rounded-xl border border-border/40 text-[11px] font-mono font-bold text-text-secondary select-none shadow-inner">
              <Clock className="h-3.5 w-3.5 text-text-muted" />
              <span>{formatDate(currentTime, 'hh:mm:ss a')}</span>
            </div>

            <button
              onClick={() => router.push('/')}
              className="inline-flex items-center justify-center gap-1 sm:gap-1.5 px-3 sm:px-4 py-1.5 sm:py-2 bg-red-500/5 hover:bg-red-500/10 text-red-600 hover:text-red-700 text-[11px] sm:text-xs font-black rounded-xl transition-all cursor-pointer border border-red-500/10 hover:border-red-500/20 shadow-xs active:scale-95 shrink-0"
            >
              <Home className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
              <span>Home</span>
            </button>
          </div>
        </div>

        {/* Tab Navigation Segmented Controls */}
        <div className="flex items-center gap-1.5 sm:gap-2 overflow-x-auto pb-1 scrollbar-none border-b border-border/40">
          <button
            onClick={() => setActiveTab('orders')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'orders' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <ChefHat className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            Live Orders
          </button>
          <button
            onClick={() => setActiveTab('analytics')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'analytics' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <BarChart3 className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            Sales Report
          </button>
          <button
            onClick={() => setActiveTab('catalog')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'catalog' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <Settings className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            Menu Catalog
          </button>
          <button
            onClick={() => setActiveTab('sections')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'sections' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <Layers className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            Categories
          </button>
          <button
            onClick={() => setActiveTab('payouts')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'payouts' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <IndianRupee className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            Payouts
          </button>
          <button
            onClick={() => setActiveTab('settings')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'settings' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <SlidersHorizontal className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            Settings
          </button>
        </div>

        {/* Console Container */}
        <div className="bg-card border border-border/60 rounded-2xl sm:rounded-3xl p-3 sm:p-6 shadow-xs">
          {activeTab === 'orders' && <RestaurantOrdersConsole />}
          {activeTab === 'analytics' && <RestaurantSalesConsole />}
          {activeTab === 'catalog' && <RestaurantCatalogManager />}
          {activeTab === 'sections' && (
            <RestaurantMenuSectionsEditor 
              assignedRestaurantId={(session?.user as any)?.assignedRestaurantId || ''} 
              isCafe={false} 
            />
          )}
          {activeTab === 'payouts' && <RestaurantPayoutsLedger isAdmin={false} />}
          {activeTab === 'settings' && <RestaurantSettingsTab />}
        </div>

      </div>
    </div>
  )
}
