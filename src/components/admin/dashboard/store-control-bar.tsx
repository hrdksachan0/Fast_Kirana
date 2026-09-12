'use client'

import { Clock, Settings } from 'lucide-react'

interface StoreControlBarProps {
  storeHubName?: string
  storesList?: any[]
  restaurantsList?: any[]
  selectedHubId?: string
  onSelectHub?: (hubId: string) => void
  onOpenHubManager?: () => void
  isSuperAdmin?: boolean
  groceryMartOpen: boolean
  groceryAutoTiming?: boolean
  isTogglingStore?: boolean
  onToggleGroceryMart?: () => void
  onOpenSettings: () => void
}

export function StoreControlBar({
  storeHubName = 'Ghatampur Central Hub',
  storesList = [],
  restaurantsList = [],
  selectedHubId,
  onSelectHub,
  onOpenHubManager,
  isSuperAdmin = false,
  groceryMartOpen,
  groceryAutoTiming,
  isTogglingStore,
  onToggleGroceryMart,
  onOpenSettings,
}: StoreControlBarProps) {
  return (
    <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-card border border-border/80 p-4 sm:p-5 rounded-3xl shadow-sm">
      <div className="flex items-center gap-3.5 flex-1 min-w-0">
        <div
          className={`h-12 w-12 rounded-2xl flex items-center justify-center font-black text-xl shadow-md transition-all shrink-0 ${
            groceryMartOpen
              ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 shadow-emerald-500/10'
              : 'bg-rose-500/10 text-rose-600 border border-rose-500/20 shadow-rose-500/10'
          }`}
        >
          🏪
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            {/* Store Hub Switcher for SuperAdmin ONLY */}
            {isSuperAdmin && storesList.length > 1 ? (
              <div className="flex items-center gap-1.5">
                <span className="text-[11px] font-black uppercase tracking-wider text-text-secondary">
                  Darkstore:
                </span>
                <select
                  value={selectedHubId || storesList[0]?.id}
                  onChange={(e) => onSelectHub?.(e.target.value)}
                  className="bg-primary/10 border-2 border-primary/30 hover:border-primary text-primary text-xs font-black uppercase tracking-wider rounded-xl px-2.5 py-1 focus:outline-none cursor-pointer shadow-xs transition-all"
                  title="Switch between Darkstore Hubs"
                >
                  <option value="all" className="bg-card text-text-primary font-bold">
                    🌐 All Hubs ({storesList.length})
                  </option>
                  {storesList.map((store) => (
                    <option key={store.id} value={store.id} className="bg-card text-text-primary font-bold">
                      🏢 {store.name} ({store.id})
                    </option>
                  ))}
                </select>
                {onOpenHubManager && (
                  <button
                    type="button"
                    onClick={onOpenHubManager}
                    className="text-[10px] font-black uppercase tracking-wider text-text-secondary hover:text-text-primary px-2 py-1 rounded-lg bg-muted/60 border border-border transition-colors cursor-pointer"
                    title="Manage Hubs & Staff"
                  >
                    ⚙️ Hubs
                  </button>
                )}
              </div>
            ) : (
              <span className="text-xs font-black uppercase tracking-wider text-text-secondary">
                Store Operations • {storeHubName}
              </span>
            )}

            {/* Restaurant Quick Switcher ONLY for SuperAdmin */}
            {isSuperAdmin && restaurantsList && restaurantsList.length > 0 && (
              <div className="flex items-center gap-1.5">
                <span className="text-[11px] font-black uppercase tracking-wider text-text-secondary">
                  Restaurant:
                </span>
                <select
                  onChange={(e) => {
                    if (e.target.value) {
                      window.open(`/restaurant-kitchen?restaurantId=${encodeURIComponent(e.target.value)}`, '_blank')
                    }
                  }}
                  defaultValue=""
                  className="bg-amber-500/10 border-2 border-amber-500/30 hover:border-amber-500 text-amber-600 dark:text-amber-400 text-xs font-black uppercase tracking-wider rounded-xl px-2.5 py-1 focus:outline-none cursor-pointer shadow-xs transition-all"
                  title="Switch to Restaurant Kitchen Console"
                >
                  <option value="" disabled className="bg-card text-text-primary font-bold">
                    🍽️ Open Kitchen ({restaurantsList.length})
                  </option>
                  {restaurantsList.map((rest) => (
                    <option key={rest.id} value={rest.id} className="bg-card text-text-primary font-bold">
                      🍽️ {rest.name} ({rest.id})
                    </option>
                  ))}
                </select>
              </div>
            )}

            <span
              className={`text-[10px] font-black uppercase tracking-wider px-2.5 py-0.5 rounded-full border ${
                groceryMartOpen
                  ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                  : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
              }`}
            >
              {groceryMartOpen ? '● Grocery Mart OPEN' : '○ Grocery Mart CLOSED'}
            </span>
          </div>
          <p className="text-xs text-text-secondary mt-0.5 font-medium truncate">
            {groceryMartOpen
              ? `[${storeHubName}] is online and accepting checkout & doorstep orders.`
              : `[${storeHubName}] is temporarily closed. Checkout is paused for customers.`}
          </p>
        </div>
      </div>

      {/* Store Timing Shortcut Button (Single control managed via Settings) */}
      <div className="flex items-center gap-2 self-stretch sm:self-auto">
        <button
          type="button"
          onClick={onOpenSettings}
          className="px-4 py-2.5 rounded-xl bg-primary/10 hover:bg-primary/20 text-primary border border-primary/30 text-xs font-black uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer shadow-xs active:scale-95 shrink-0"
          title="Configure automated store operating hours & timings"
        >
          <Clock className="w-4 h-4 text-primary" />
          <span>Store Timings & Settings</span>
        </button>
      </div>
    </div>
  )
}
