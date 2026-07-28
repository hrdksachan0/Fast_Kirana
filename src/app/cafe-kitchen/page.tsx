'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useSession, signOut } from 'next-auth/react'
import { Coffee, LogOut, Clock, ShieldCheck, Home, ChefHat, BarChart3, Settings, IndianRupee, SlidersHorizontal, Layers } from 'lucide-react'
import { CafeOrdersConsole } from '@/components/admin/cafe-orders-console'
import { CafeSalesConsole } from '@/components/admin/cafe-sales-console'
import { RestaurantPayoutsLedger } from '@/components/admin/restaurant-payouts-ledger'
import { RestaurantSettingsTab } from '@/components/admin/restaurant-settings-tab'
import { RestaurantCatalogManager } from '@/components/admin/restaurant-catalog-manager'
import { RestaurantMenuSectionsEditor } from '@/components/admin/restaurant-menu-sections-editor'
import { useUIStore } from '@/stores/ui-store'

export default function CafeKitchenPage() {
  const { data: session, status } = useSession()
  const router = useRouter()
  const [currentTime, setCurrentTime] = useState(new Date())
  const { cafeOpen } = useUIStore()
  const [activeTab, setActiveTab] = useState<'orders' | 'analytics' | 'catalog' | 'sections' | 'payouts' | 'settings'>('orders')
  const [restaurantName, setRestaurantName] = useState('FastKirana Cafe Console')

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
            
            // Auto-redirect if they belong to a standard Restaurant and are not an ADMIN
            if (session?.user?.role !== 'ADMIN') {
              const isAssignedCafe = data.slug?.includes('cafe') || data.cuisineTags?.some((t: string) => t.toLowerCase().includes('cafe'))
              if (!isAssignedCafe) {
                router.push('/restaurant-kitchen')
              }
            }
          }
        })
        .catch(err => console.error(err))
    } else {
      setRestaurantName('FastKirana Cafe Console')
    }
  }, [session, router])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/cafe-login?callbackUrl=/cafe-kitchen')
    } else if (status === 'authenticated') {
      const role = session?.user?.role
      const email = session?.user?.email || ''
      const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
      const isAllowed = role === 'ADMIN' || role === 'RESTAURANT_OWNER' || (role === 'CHEF' && !email.toLowerCase().startsWith('restaurant')) || !!assignedRestaurantId
      if (!isAllowed) {
        router.push('/')
      }
    }
  }, [status, session, router])

  if (status === 'loading') {
    return (
      <div className="flex h-screen w-screen items-center justify-center bg-zinc-50 dark:bg-zinc-950">
        <div className="text-center space-y-3">
          <Coffee className="h-8 w-8 text-orange-655 animate-spin mx-auto" />
          <p className="text-xs text-text-secondary font-bold">Verifying cafe credentials...</p>
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
            <div className="h-12 w-12 rounded-2xl bg-orange-500/10 text-orange-600 flex items-center justify-center shadow-inner border border-orange-500/20">
              <Coffee className="h-6 w-6 animate-pulse-gentle" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base sm:text-lg font-black text-text-primary uppercase tracking-tight font-sans">{restaurantName}</h1>
                <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider ${
                  cafeOpen
                    ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20'
                    : 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                }`}>
                  <span className={`h-1.5 w-1.5 rounded-full ${cafeOpen ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}`} />
                  {cafeOpen ? 'OPEN' : 'CLOSED'}
                </span>
              </div>
              <p className="text-[10px] sm:text-xs text-text-secondary mt-0.5 flex items-center gap-1 font-medium">
                <ShieldCheck className="h-3.5 w-3.5 text-emerald-500" />
                Logged in as: <span className="font-bold text-text-primary">{session?.user?.email}</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5 shrink-0">
            <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 bg-muted/40 rounded-xl border border-border/40 text-[11px] font-mono font-bold text-text-secondary select-none shadow-inner">
              <Clock className="h-3.5 w-3.5 text-text-muted" />
              <span>{currentTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
            </div>

            <button
              onClick={() => router.push('/')}
              className="inline-flex items-center justify-center gap-1.5 px-4 py-2 bg-orange-500/5 hover:bg-orange-500/10 text-orange-600 hover:text-orange-700 text-xs font-black rounded-xl transition-all cursor-pointer border border-orange-500/10 hover:border-orange-500/20 shadow-xs"
            >
              <Home className="h-4 w-4" />
              Go Home
            </button>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="flex border-b border-border/40 gap-4 overflow-x-auto pb-1 scrollbar-none">
          <button
            onClick={() => setActiveTab('orders')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer whitespace-nowrap ${
              activeTab === 'orders' 
                ? 'border-orange-600 text-orange-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <ChefHat className="h-4 w-4" />
            Live Orders
          </button>
          <button
            onClick={() => setActiveTab('analytics')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer whitespace-nowrap ${
              activeTab === 'analytics' 
                ? 'border-orange-600 text-orange-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <BarChart3 className="h-4 w-4" />
            Sales Analytics
          </button>
          <button
            onClick={() => setActiveTab('catalog')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer whitespace-nowrap ${
              activeTab === 'catalog' 
                ? 'border-orange-600 text-orange-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <Settings className="h-4 w-4" />
            Menu Catalog
          </button>
          <button
            onClick={() => setActiveTab('sections')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer whitespace-nowrap ${
              activeTab === 'sections' 
                ? 'border-orange-600 text-orange-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <Layers className="h-4 w-4" />
            Menu Categories
          </button>
          <button
            onClick={() => setActiveTab('payouts')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer whitespace-nowrap ${
              activeTab === 'payouts' 
                ? 'border-orange-600 text-orange-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <IndianRupee className="h-4 w-4" />
            Payout Ledger
          </button>
          <button
            onClick={() => setActiveTab('settings')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer whitespace-nowrap ${
              activeTab === 'settings' 
                ? 'border-orange-600 text-orange-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <SlidersHorizontal className="h-4 w-4" />
            Outlet Settings
          </button>
        </div>

        {/* Console Container */}
        <div className="bg-card border border-border rounded-3xl p-6 shadow-sm">
          {activeTab === 'orders' && <CafeOrdersConsole />}
          {activeTab === 'analytics' && <CafeSalesConsole />}
          {activeTab === 'catalog' && <RestaurantCatalogManager />}
          {activeTab === 'sections' && (
            <RestaurantMenuSectionsEditor 
              assignedRestaurantId={(session?.user as any)?.assignedRestaurantId || ''} 
              isCafe={true} 
            />
          )}
          {activeTab === 'payouts' && <RestaurantPayoutsLedger isAdmin={false} type="CAFE" />}
          {activeTab === 'settings' && <RestaurantSettingsTab />}
        </div>

      </div>
    </div>
  )
}
