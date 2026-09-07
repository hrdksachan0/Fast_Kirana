'use client'

import { RefreshCw, ToggleLeft, ToggleRight, Settings } from 'lucide-react'

interface StoreControlBarProps {
  storeHubName?: string
  groceryMartOpen: boolean
  groceryAutoTiming: boolean
  isTogglingStore: boolean
  onToggleGroceryMart: () => void
  onOpenSettings: () => void
}

export function StoreControlBar({
  storeHubName = 'Ghatampur Central Hub',
  groceryMartOpen,
  groceryAutoTiming,
  isTogglingStore,
  onToggleGroceryMart,
  onOpenSettings,
}: StoreControlBarProps) {
  return (
    <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-card border border-border/80 p-4 sm:p-5 rounded-3xl shadow-sm">
      <div className="flex items-center gap-3.5">
        <div
          className={`h-12 w-12 rounded-2xl flex items-center justify-center font-black text-xl shadow-md transition-all ${
            groceryMartOpen
              ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 shadow-emerald-500/10'
              : 'bg-rose-500/10 text-rose-600 border border-rose-500/20 shadow-rose-500/10'
          }`}
        >
          🏪
        </div>
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-black uppercase tracking-wider text-text-secondary">
              Store Operations • {storeHubName}
            </span>
            <span
              className={`text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full border ${
                groceryMartOpen
                  ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                  : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
              }`}
            >
              {groceryMartOpen ? '● Grocery Mart OPEN' : '○ Grocery Mart CLOSED'}
            </span>
            {groceryAutoTiming && (
              <span className="text-[10px] font-bold text-amber-600 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded-full">
                ⏰ Auto-Schedule Active
              </span>
            )}
          </div>
          <p className="text-xs text-text-secondary mt-0.5 font-medium">
            {groceryMartOpen
              ? 'Grocery store is online and accepting checkout & doorstep orders.'
              : 'Grocery store is temporarily closed. Checkout is paused for customers.'}
          </p>
        </div>
      </div>

      {/* 1-Click Operating Toggles */}
      <div className="flex items-center gap-2 self-stretch sm:self-auto">
        <button
          type="button"
          disabled={isTogglingStore}
          onClick={onToggleGroceryMart}
          className={`flex-1 sm:flex-initial px-4 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer shadow-sm active:scale-95 disabled:opacity-50 ${
            groceryMartOpen
              ? 'bg-rose-600 hover:bg-rose-700 text-white'
              : 'bg-emerald-600 hover:bg-emerald-700 text-white'
          }`}
        >
          {isTogglingStore ? (
            <RefreshCw className="w-3.5 h-3.5 animate-spin" />
          ) : groceryMartOpen ? (
            <>
              <ToggleLeft className="w-4 h-4" />
              <span>Close Grocery Mart</span>
            </>
          ) : (
            <>
              <ToggleRight className="w-4 h-4" />
              <span>Open Grocery Mart</span>
            </>
          )}
        </button>

        <button
          type="button"
          onClick={onOpenSettings}
          className="px-3.5 py-2.5 rounded-xl bg-muted hover:bg-muted/80 text-text-primary text-xs font-bold transition-all border border-border flex items-center gap-1.5 cursor-pointer shrink-0"
          title="Configure store operating hours and delivery timings"
        >
          <Settings className="w-3.5 h-3.5" />
          <span>Store Settings</span>
        </button>
      </div>
    </div>
  )
}
