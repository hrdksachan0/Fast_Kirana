'use client'

import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { useSession, signOut } from 'next-auth/react'
import { 
  Utensils, 
  LogOut, 
  Clock, 
  ShieldCheck, 
  Home, 
  ChefHat, 
  BarChart3, 
  Settings, 
  IndianRupee, 
  SlidersHorizontal, 
  Layers, 
  Star,
  Maximize2,
  Minimize2,
  Volume2,
  VolumeX,
  Store,
  ChevronDown,
  Sparkles
} from 'lucide-react'
import { toast } from 'sonner'
import { RestaurantOrdersConsole } from '@/components/admin/restaurant-orders-console'
import { RestaurantSalesConsole } from '@/components/admin/restaurant-sales-console'
import { RestaurantPayoutsLedger } from '@/components/admin/restaurant-payouts-ledger'
import { RestaurantSettingsTab } from '@/components/admin/restaurant-settings-tab'
import { RestaurantCatalogManager } from '@/components/admin/restaurant-catalog-manager'
import { RestaurantMenuSectionsEditor } from '@/components/admin/restaurant-menu-sections-editor'
import { RestaurantReviewsTab } from '@/components/admin/restaurant-reviews-tab'
import { MenuQuickStockModal } from '@/components/restaurant/menu-quick-stock-modal'
import { useUIStore } from '@/stores/ui-store'
import { formatDate } from '@/lib/date-helpers'
import { playKitchenAlarmChime, tryUnlockAudioContext, isAudioContextSuspended } from '@/lib/audio'

export default function RestaurantKitchenPage() {
  const { data: session, status } = useSession()
  const router = useRouter()
  const [currentTime, setCurrentTime] = useState(new Date())
  const { restaurantOpen } = useUIStore()
  const [activeTab, setActiveTab] = useState<'orders' | 'analytics' | 'catalog' | 'sections' | 'payouts' | 'reviews' | 'settings'>('orders')
  
  // Restaurant Multi-Store Selector
  const [restaurants, setRestaurants] = useState<any[]>([])
  const [selectedRestaurantId, setSelectedRestaurantId] = useState<string>('')
  const [restaurantName, setRestaurantName] = useState('Restaurant Console')
  const [isCafe, setIsCafe] = useState(false)
  
  // Quick 86 Stock Modal
  const [isStockModalOpen, setIsStockModalOpen] = useState(false)
  
  // Fullscreen Mode
  const [isFullscreen, setIsFullscreen] = useState(false)
  
  // Audio state
  const [soundEnabled, setSoundEnabled] = useState(true)
  const [audioBlocked, setAudioBlocked] = useState(false)

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    // Check sound preference
    const storedSound = localStorage.getItem('kitchen_sound_enabled')
    if (storedSound !== null) {
      setSoundEnabled(storedSound === 'true')
    }
    if (isAudioContextSuspended()) {
      setAudioBlocked(true)
    }
  }, [])

  // Fetch available restaurants for selection
  useEffect(() => {
    fetch('/api/restaurants')
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (data?.restaurants && Array.isArray(data.restaurants)) {
          setRestaurants(data.restaurants)
          const assignedId = (session?.user as any)?.assignedRestaurantId
          if (assignedId) {
            setSelectedRestaurantId(assignedId)
            const matched = data.restaurants.find((r: any) => r.id === assignedId)
            if (matched) {
              setRestaurantName(`${matched.name} Console`)
              setIsCafe(matched.slug === 'fastkirana-cafe' || matched.slug?.includes('cafe'))
            }
          } else if (data.restaurants.length > 0) {
            const first = data.restaurants[0]
            setSelectedRestaurantId(first.id)
            setRestaurantName(`${first.name} Console`)
            setIsCafe(first.slug === 'fastkirana-cafe' || first.slug?.includes('cafe'))
          }
        }
      })
      .catch(console.error)
  }, [session])

  const handleRestaurantChange = (restId: string) => {
    setSelectedRestaurantId(restId)
    const found = restaurants.find(r => r.id === restId)
    if (found) {
      setRestaurantName(`${found.name} Console`)
      setIsCafe(found.slug === 'fastkirana-cafe' || found.slug?.includes('cafe'))
      toast.success(`Switched to ${found.name}`)
    }
  }

  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().then(() => setIsFullscreen(true)).catch(() => {})
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false)).catch(() => {})
    }
  }

  const handleUnblockAudio = async () => {
    const unlocked = await tryUnlockAudioContext()
    if (unlocked) {
      setAudioBlocked(false)
      playKitchenAlarmChime()
      toast.success('Audio alarm enabled! 🔔')
    }
  }

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

  const isAdmin = session?.user?.role === 'ADMIN'

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950/20 py-3 sm:py-6 px-3 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto space-y-4 sm:space-y-6">
        
        {/* Browser Audio Unblock Alert */}
        {audioBlocked && (
          <button
            onClick={handleUnblockAudio}
            className="w-full text-center text-xs font-black text-rose-600 bg-rose-500/10 hover:bg-rose-500/15 border border-rose-500/20 py-3 px-4 rounded-2xl transition-all flex items-center justify-center gap-2 cursor-pointer animate-pulse shadow-inner"
          >
            <span>🔊</span> Click here to enable Live Kitchen Sound Alerts & Alarms
          </button>
        )}

        {/* Header Bar */}
        <div className="flex flex-col md:flex-row justify-between md:items-center gap-3.5 bg-card border border-border/70 rounded-2xl sm:rounded-3xl p-3.5 sm:p-5 shadow-xs">
          <div className="flex items-center justify-between md:justify-start gap-3 min-w-0">
            <div className="flex items-center gap-3 min-w-0">
              <div className="h-10 w-10 sm:h-12 sm:w-12 rounded-xl sm:rounded-2xl bg-red-500/10 text-red-500 flex items-center justify-center shrink-0 border border-red-500/20 shadow-inner">
                <Utensils className="h-5 w-5 sm:h-6 sm:w-6 animate-pulse-gentle" />
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  {isAdmin && restaurants.length > 1 ? (
                    <div className="relative inline-flex items-center">
                      <select
                        value={selectedRestaurantId}
                        onChange={(e) => handleRestaurantChange(e.target.value)}
                        className="appearance-none bg-muted/60 border border-border/80 font-black text-xs sm:text-base text-text-primary uppercase tracking-tight py-1 pl-2.5 pr-8 rounded-xl cursor-pointer focus:outline-none focus:border-red-500"
                      >
                        {restaurants.map(r => (
                          <option key={r.id} value={r.id} className="bg-card text-text-primary">
                            {r.name} Console
                          </option>
                        ))}
                      </select>
                      <ChevronDown className="absolute right-2 pointer-events-none h-3.5 w-3.5 text-text-muted" />
                    </div>
                  ) : (
                    <h1 className="text-xs sm:text-lg font-black text-text-primary uppercase tracking-tight truncate">{restaurantName}</h1>
                  )}

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
          </div>

          {/* Action Header Buttons */}
          <div className="flex items-center justify-between md:justify-end gap-2 shrink-0 border-t md:border-t-0 border-border/40 pt-2.5 md:pt-0">
            {/* Quick 86 Stock Drawer Trigger */}
            <button
              onClick={() => setIsStockModalOpen(true)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 text-[11px] sm:text-xs font-black rounded-xl transition-all cursor-pointer border border-rose-500/25 active:scale-95 shadow-xs"
              title="Quick 86 Out of Stock toggle"
            >
              <Utensils className="h-3.5 w-3.5" />
              <span>Quick 86 Stock</span>
            </button>

            {/* Fullscreen Mode */}
            <button
              onClick={toggleFullscreen}
              className="p-2 bg-muted/50 hover:bg-muted text-text-secondary hover:text-text-primary rounded-xl transition-all cursor-pointer border border-border/50 hidden sm:inline-flex"
              title={isFullscreen ? 'Exit Fullscreen' : 'Fullscreen KDS Mode'}
            >
              {isFullscreen ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
            </button>

            {/* Live Clock */}
            <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 bg-muted/40 rounded-xl border border-border/40 text-[11px] font-mono font-bold text-text-secondary select-none shadow-inner">
              <Clock className="h-3.5 w-3.5 text-text-muted" />
              <span>{formatDate(currentTime, 'hh:mm:ss a')}</span>
            </div>

            {/* Home button */}
            <button
              onClick={() => router.push('/')}
              className="inline-flex items-center justify-center gap-1 sm:gap-1.5 px-3 sm:px-4 py-1.5 sm:py-2 bg-red-500/5 hover:bg-red-500/10 text-red-600 hover:text-red-700 text-[11px] sm:text-xs font-black rounded-xl transition-all cursor-pointer border border-red-500/10 hover:border-red-500/20 shadow-xs active:scale-95 shrink-0"
            >
              <Home className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
              <span>Home</span>
            </button>

            {/* Logout */}
            <button
              onClick={() => signOut({ callbackUrl: '/restaurant-login' })}
              className="p-2 bg-muted/40 hover:bg-rose-500/10 text-text-secondary hover:text-rose-600 rounded-xl transition-all cursor-pointer border border-border/40"
              title="Logout"
            >
              <LogOut className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
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
            onClick={() => setActiveTab('reviews')}
            className={`flex items-center gap-1.5 px-3.5 sm:px-4 py-2 sm:py-2.5 text-[11px] sm:text-xs font-black uppercase tracking-wider rounded-xl transition-all cursor-pointer whitespace-nowrap active:scale-95 shrink-0 ${
              activeTab === 'reviews' 
                ? 'bg-red-600 text-white shadow-xs' 
                : 'bg-card hover:bg-muted border border-border/60 text-text-secondary'
            }`}
          >
            <Star className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-amber-400 fill-amber-400" />
            Reviews & Ratings
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
              assignedRestaurantId={selectedRestaurantId || (session?.user as any)?.assignedRestaurantId || ''} 
              isCafe={isCafe} 
            />
          )}
          {activeTab === 'payouts' && <RestaurantPayoutsLedger isAdmin={isAdmin} />}
          {activeTab === 'reviews' && (
            <RestaurantReviewsTab 
              restaurantId={selectedRestaurantId || (session?.user as any)?.assignedRestaurantId} 
            />
          )}
          {activeTab === 'settings' && (
            <RestaurantSettingsTab 
              restaurantId={selectedRestaurantId || (session?.user as any)?.assignedRestaurantId} 
            />
          )}
        </div>

      </div>

      {/* Quick 86 Stock-Out Modal */}
      <MenuQuickStockModal
        isOpen={isStockModalOpen}
        onClose={() => setIsStockModalOpen(false)}
        restaurantId={selectedRestaurantId}
      />
    </div>
  )
}
