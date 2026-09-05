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
        const list = Array.isArray(data) ? data : (data?.restaurants || [])
        if (list.length > 0) {
          setRestaurants(list)
          
          let searchParamRestId: string | null = null
          let searchParamTab: string | null = null
          if (typeof window !== 'undefined') {
            const params = new URLSearchParams(window.location.search)
            searchParamRestId = params.get('restaurantId')
            searchParamTab = params.get('tab')
          }

          if (searchParamTab && ['orders', 'analytics', 'catalog', 'sections', 'payouts', 'reviews', 'settings'].includes(searchParamTab)) {
            setActiveTab(searchParamTab as any)
          }

          const isPlatformAdmin = session?.user?.role === 'ADMIN'
          const userAssignedId = (session?.user as any)?.assignedRestaurantId
          const assignedId = isPlatformAdmin 
            ? (searchParamRestId || userAssignedId) 
            : (userAssignedId || searchParamRestId)

          const targetId = assignedId && list.some((r: any) => r.id === assignedId) ? assignedId : list[0].id
          setSelectedRestaurantId(targetId)
          const matched = list.find((r: any) => r.id === targetId)
          if (matched) {
            setRestaurantName(`${matched.name} Console`)
            setIsCafe(matched.slug === 'fastkirana-cafe' || matched.slug?.includes('cafe'))
          }
        }
      })
      .catch(console.error)
  }, [session])

  const handleRestaurantChange = (restId: string) => {
    if (session?.user?.role !== 'ADMIN') {
      toast.error('Restricted: You can only manage your own restaurant outlet.')
      return
    }
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
  const userAssignedId = (session?.user as any)?.assignedRestaurantId
  const effectiveRestId = (!isAdmin && userAssignedId)
    ? userAssignedId
    : (selectedRestaurantId || userAssignedId || restaurants[0]?.id || 'REST-101')
  const currentRestaurant = restaurants.find(r => r.id === effectiveRestId)

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
                        className="text-base sm:text-lg font-black tracking-tight text-text-primary bg-muted/40 hover:bg-muted/70 border border-border/80 rounded-xl px-2.5 py-1 pr-8 appearance-none cursor-pointer focus:outline-none focus:ring-2 focus:ring-red-500 transition-colors"
                      >
                        {restaurants.map((r) => (
                          <option key={r.id} value={r.id} className="bg-card text-text-primary font-bold">
                            {r.name}
                          </option>
                        ))}
                      </select>
                      <ChevronDown className="w-4 h-4 text-text-secondary absolute right-2 pointer-events-none" />
                    </div>
                  ) : (
                    <h1 className="text-base sm:text-lg font-black tracking-tight text-text-primary truncate">
                      {restaurantName}
                    </h1>
                  )}
                  <span className="text-[10px] font-mono font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20 px-2 py-0.5 rounded-full shrink-0">
                    Live Kitchen
                  </span>
                </div>
                <div className="flex items-center gap-2 text-xs text-text-secondary font-medium">
                  <span className="truncate">
                    Outlet ID: <span className="font-mono text-text-primary font-bold">{effectiveRestId}</span>
                  </span>
                  <span>•</span>
                  <div className="flex items-center gap-1.5 shrink-0">
                    <span className={`w-2 h-2 rounded-full ${restaurantOpen ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}`} />
                    <span className={`font-bold ${restaurantOpen ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-500'}`}>
                      {restaurantOpen ? 'Accepting Orders' : 'Store Paused'}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-wrap justify-end">
            <button
              onClick={() => setIsStockModalOpen(true)}
              className="px-3 py-1.5 sm:px-3.5 sm:py-2 rounded-xl text-xs font-black bg-amber-500/10 hover:bg-amber-500/20 text-amber-700 dark:text-amber-400 border border-amber-500/30 transition-all flex items-center gap-1.5 cursor-pointer active:scale-95"
            >
              <SlidersHorizontal className="w-3.5 h-3.5" />
              <span>Menu 86 / Stock</span>
            </button>

            <button
              onClick={() => setSoundEnabled(!soundEnabled)}
              className={`p-2 sm:p-2.5 rounded-xl border text-xs font-bold transition-all cursor-pointer ${
                soundEnabled 
                  ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30 hover:bg-emerald-500/20' 
                  : 'bg-muted text-text-secondary border-border hover:bg-muted/80'
              }`}
              title={soundEnabled ? 'Kitchen alarms active' : 'Kitchen alarms muted'}
            >
              {soundEnabled ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
            </button>

            <button
              onClick={toggleFullscreen}
              className="p-2 sm:p-2.5 rounded-xl bg-muted/60 hover:bg-muted border border-border/80 text-text-secondary transition-all cursor-pointer"
              title="Toggle Fullscreen"
            >
              {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
            </button>

            {isAdmin && (
              <button
                onClick={() => router.push('/admin')}
                className="px-3 py-1.5 sm:px-3.5 sm:py-2 rounded-xl text-xs font-black bg-zinc-900 text-white dark:bg-zinc-100 dark:text-zinc-900 hover:opacity-90 transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <ShieldCheck className="w-3.5 h-3.5" />
                <span>Admin HQ</span>
              </button>
            )}

            <button
              onClick={() => signOut({ callbackUrl: '/restaurant-login' })}
              className="p-2 sm:p-2.5 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 border border-rose-500/20 transition-all cursor-pointer"
              title="Sign Out"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Tabs Bar */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar border-b border-border/60">
          <button
            onClick={() => setActiveTab('orders')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'orders'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <ChefHat className="w-3.5 h-3.5" />
            Live Kitchen Queue
          </button>
          <button
            onClick={() => setActiveTab('analytics')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'analytics'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <BarChart3 className="w-3.5 h-3.5" />
            Sales & Analytics
          </button>
          <button
            onClick={() => setActiveTab('catalog')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'catalog'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <Utensils className="w-3.5 h-3.5" />
            Menu Catalog
          </button>
          <button
            onClick={() => setActiveTab('sections')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'sections'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            Menu Sections & Tabs
          </button>
          <button
            onClick={() => setActiveTab('payouts')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'payouts'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <IndianRupee className="w-3.5 h-3.5" />
            Settlements Ledger
          </button>
          <button
            onClick={() => setActiveTab('reviews')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'reviews'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <Star className="w-3.5 h-3.5" />
            Customer Ratings
          </button>
          <button
            onClick={() => setActiveTab('settings')}
            className={`px-4 py-2.5 rounded-xl text-xs font-black transition-all flex items-center gap-2 shrink-0 cursor-pointer ${
              activeTab === 'settings'
                ? 'bg-[#e20a22] text-white shadow-sm'
                : 'text-text-secondary hover:text-text-primary hover:bg-muted/60'
            }`}
          >
            <Settings className="w-3.5 h-3.5" />
            Settings
          </button>
        </div>

        {/* Console Container */}
        <div className="bg-card border border-border/60 rounded-2xl sm:rounded-3xl p-3 sm:p-6 shadow-xs">
          {activeTab === 'orders' && (
            <RestaurantOrdersConsole 
              key={`orders-${effectiveRestId}`}
              restaurantId={effectiveRestId} 
              restaurant={currentRestaurant}
            />
          )}
          {activeTab === 'analytics' && (
            <RestaurantSalesConsole 
              key={`analytics-${effectiveRestId}`}
              restaurantId={effectiveRestId}
            />
          )}
          {activeTab === 'catalog' && (
            <RestaurantCatalogManager 
              key={`catalog-${effectiveRestId}`}
              initialRestaurantId={effectiveRestId} 
            />
          )}
          {activeTab === 'sections' && (
            <RestaurantMenuSectionsEditor 
              key={`sections-${effectiveRestId}`}
              assignedRestaurantId={effectiveRestId} 
              isCafe={isCafe} 
            />
          )}
          {activeTab === 'payouts' && (
            <RestaurantPayoutsLedger 
              key={`payouts-${effectiveRestId}`}
              isAdmin={isAdmin} 
            />
          )}
          {activeTab === 'reviews' && (
            <RestaurantReviewsTab 
              key={`reviews-${effectiveRestId}`}
              restaurantId={effectiveRestId} 
            />
          )}
          {activeTab === 'settings' && (
            <RestaurantSettingsTab 
              key={`settings-${effectiveRestId}`}
              restaurantId={effectiveRestId} 
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
