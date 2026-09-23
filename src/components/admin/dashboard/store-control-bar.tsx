'use client'

import React, { useState } from 'react'
import {
  Clock,
  Settings,
  Store,
  MapPin,
  CheckCircle2,
  AlertCircle,
  PlusCircle,
  Volume2,
  VolumeX,
  PackagePlus,
  Radio,
  ChevronDown,
  Building,
  ShieldCheck,
  Power,
  Layers,
  Utensils
} from 'lucide-react'

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
  onOpenCreateOrder?: () => void
  onOpenInward?: () => void
  isChimeMuted?: boolean
  onToggleChime?: () => void
  userAssignedStoreId?: string | null
}

export function StoreControlBar({
  storeHubName = 'Store Hub',
  storesList = [],
  restaurantsList = [],
  selectedHubId,
  onSelectHub,
  onOpenHubManager,
  isSuperAdmin = false,
  groceryMartOpen,
  groceryAutoTiming = false,
  isTogglingStore = false,
  onToggleGroceryMart,
  onOpenSettings,
  onOpenCreateOrder,
  onOpenInward,
  isChimeMuted = false,
  onToggleChime,
  userAssignedStoreId,
}: StoreControlBarProps) {
  const currentStore = storesList.find((s) => s.id === selectedHubId)
  const fallbackFormatted = selectedHubId && selectedHubId !== 'all'
    ? selectedHubId.replace(/^hub-/, '').replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) + ' Hub'
    : storeHubName
  const displayStoreName = currentStore?.name || (storeHubName && storeHubName !== 'Ghatampur Central Hub' && storeHubName !== 'Store Hub' ? storeHubName : fallbackFormatted)
  const isBranchLocked = !isSuperAdmin && !!userAssignedStoreId

  return (
    <div className="flex flex-col gap-3">
      {/* Top Main Darkstore Operating Cockpit */}
      <div className="relative overflow-hidden rounded-3xl border border-border/80 bg-card p-4 sm:p-5 shadow-sm transition-all duration-300">
        {/* Subtle decorative background gradient */}
        <div className="pointer-events-none absolute -right-16 -top-16 h-48 w-48 rounded-full bg-primary/5 blur-3xl" />
        
        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4 relative z-10">
          
          {/* Left: Store Identity & Live Operational Status */}
          <div className="flex items-start sm:items-center gap-3.5 flex-1 min-w-0 w-full sm:w-auto">
            <div
              className={`relative h-13 w-13 rounded-2xl flex items-center justify-center font-black text-2xl shrink-0 transition-all duration-300 shadow-md ${
                groceryMartOpen
                  ? 'bg-emerald-500/10 text-emerald-600 border border-emerald-500/30 shadow-emerald-500/10'
                  : 'bg-rose-500/10 text-rose-600 border border-rose-500/30 shadow-rose-500/10'
              }`}
            >
              <Store className="w-6 h-6" />
              {/* Pulse indicator for live open status */}
              {groceryMartOpen && (
                <span className="absolute -top-1 -right-1 flex h-3.5 w-3.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                  <span className="relative inline-flex rounded-full h-3.5 w-3.5 bg-emerald-500 border-2 border-card" />
                </span>
              )}
            </div>

            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                {/* Store Hub Name */}
                <h2 className="text-base sm:text-lg font-black tracking-tight text-text-primary flex items-center gap-1.5">
                  <span>{displayStoreName}</span>
                </h2>

                {/* Store ID Tag */}
                {selectedHubId && selectedHubId !== 'all' && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg bg-muted text-text-secondary text-[10px] font-black uppercase tracking-wider border border-border/70 font-mono">
                    <MapPin className="w-2.5 h-2.5 text-primary" />
                    {selectedHubId}
                  </span>
                )}

                {/* Status Pill */}
                <span
                  className={`inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-wider px-2.5 py-0.5 rounded-full border shadow-2xs ${
                    groceryMartOpen
                      ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                      : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
                  }`}
                >
                  <span className={`w-1.5 h-1.5 rounded-full ${groceryMartOpen ? 'bg-emerald-500' : 'bg-rose-500'}`} />
                  {groceryMartOpen ? 'Store LIVE & Open' : 'Store Paused / Offline'}
                </span>

                {groceryAutoTiming && (
                  <span className="inline-flex items-center gap-1 text-[9.5px] font-bold text-amber-600 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded-full">
                    <Clock className="w-2.5 h-2.5" />
                    Auto Schedule
                  </span>
                )}
              </div>

              {/* Subtitle & Status Details */}
              <p className="text-xs text-text-secondary mt-0.5 font-medium flex items-center gap-1.5 line-clamp-1">
                {groceryMartOpen ? (
                  <span className="text-emerald-600 dark:text-emerald-400 font-semibold">
                    Accepting customer checkout, live delivery, and instant darkstore fulfillment.
                  </span>
                ) : (
                  <span className="text-rose-600 dark:text-rose-400 font-semibold">
                    Store is temporarily paused. Customers see &quot;Closed for delivery&quot; on app storefront.
                  </span>
                )}
              </p>
            </div>
          </div>

          {/* Right: Store Switcher (HQ) & Quick Operational Actions */}
          <div className="flex flex-wrap items-center gap-2 self-stretch lg:self-auto justify-start sm:justify-end w-full lg:w-auto pt-2 sm:pt-0 border-t sm:border-t-0 border-border/50">
            
            {/* SuperAdmin Multi-Hub Switcher */}
            {isSuperAdmin && storesList.length > 0 && (
              <div className="flex items-center gap-1.5 bg-muted/40 p-1 rounded-2xl border border-border/70">
                <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary pl-2 hidden sm:inline">
                  Hub:
                </span>
                <select
                  value={selectedHubId || storesList[0]?.id}
                  onChange={(e) => onSelectHub?.(e.target.value)}
                  className="bg-card border border-border/80 hover:border-primary text-text-primary text-xs font-black uppercase tracking-wider rounded-xl px-2.5 py-1.5 focus:outline-none focus:ring-2 focus:ring-primary/20 cursor-pointer shadow-2xs transition-all"
                  title="Switch between Darkstore Hubs"
                >
                  <option value="all" className="bg-card text-text-primary font-bold">
                    🌐 All Hubs ({storesList.length})
                  </option>
                  {storesList.map((store) => (
                    <option key={store.id} value={store.id} className="bg-card text-text-primary font-bold">
                      🏢 {store.name}
                    </option>
                  ))}
                </select>

                {onOpenHubManager && (
                  <button
                    type="button"
                    onClick={onOpenHubManager}
                    className="p-1.5 text-text-secondary hover:text-text-primary rounded-xl bg-card border border-border/80 hover:border-primary transition-colors cursor-pointer shadow-2xs"
                    title="Manage Darkstore Hubs & Assigned Staff"
                  >
                    <Settings className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            )}

            {/* Branch Admin Locked Hub Badge */}
            {!isSuperAdmin && userAssignedStoreId && (
              <div className="flex items-center gap-1.5 bg-muted/50 px-3 py-1.5 rounded-2xl border border-border/70">
                <span className="text-[11px] font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                  <span className="h-2 w-2 rounded-full bg-emerald-500 inline-block" />
                  🔒 {displayStoreName} (Hub Locked)
                </span>
              </div>
            )}

            {/* SuperAdmin Kitchen Quick Switcher */}
            {isSuperAdmin && restaurantsList && restaurantsList.length > 0 && (
              <select
                onChange={(e) => {
                  if (e.target.value) {
                    window.open(`/restaurant-kitchen?restaurantId=${encodeURIComponent(e.target.value)}`, '_blank')
                  }
                }}
                defaultValue=""
                className="bg-amber-500/10 border border-amber-500/30 hover:border-amber-500 text-amber-600 dark:text-amber-400 text-xs font-black uppercase tracking-wider rounded-xl px-2.5 py-2 focus:outline-none cursor-pointer shadow-2xs transition-all"
                title="Open Restaurant Kitchen Console"
              >
                <option value="" disabled className="bg-card text-text-primary font-bold">
                  🍽️ Kitchen Console ({restaurantsList.length})
                </option>
                {restaurantsList.map((rest) => (
                  <option key={rest.id} value={rest.id} className="bg-card text-text-primary font-bold">
                    🍽️ {rest.name}
                  </option>
                ))}
              </select>
            )}

            {/* Quick Action: New Manual / Phone Order */}
            {onOpenCreateOrder && (
              <button
                type="button"
                onClick={onOpenCreateOrder}
                className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-primary text-primary-foreground hover:bg-primary/90 text-xs font-black uppercase tracking-wider shadow-xs hover:shadow-md transition-all active:scale-[0.98] cursor-pointer shrink-0"
                title="Create Manual / Phone Order for Customer"
              >
                <PlusCircle className="w-3.5 h-3.5" />
                <span>+ New Order</span>
              </button>
            )}

            {/* Quick Action: Fast Inward GRN */}
            {onOpenInward && (
              <button
                type="button"
                onClick={onOpenInward}
                className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-muted hover:bg-muted/80 text-text-primary border border-border/80 text-xs font-black uppercase tracking-wider transition-all active:scale-[0.98] cursor-pointer shrink-0"
                title="Quick Inward GRN Scanner"
              >
                <PackagePlus className="w-3.5 h-3.5 text-emerald-600" />
                <span>Inward</span>
              </button>
            )}

            {/* Audio Chime Notification Toggle */}
            {onToggleChime && (
              <button
                type="button"
                onClick={onToggleChime}
                className={`p-2 rounded-xl border text-xs font-black transition-all cursor-pointer shadow-2xs shrink-0 ${
                  isChimeMuted
                    ? 'bg-rose-500/10 text-rose-600 border-rose-500/30'
                    : 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30'
                }`}
                title={isChimeMuted ? 'Unmute Live Order Sound Alerts' : 'Mute Live Order Sound Alerts'}
              >
                {isChimeMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
              </button>
            )}

            {/* 1-Click Store Open / Close Switch Button */}
            {onToggleGroceryMart && (
              <button
                type="button"
                onClick={onToggleGroceryMart}
                disabled={isTogglingStore}
                className={`inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-black uppercase tracking-wider border shadow-xs transition-all active:scale-[0.98] cursor-pointer disabled:opacity-50 shrink-0 ${
                  groceryMartOpen
                    ? 'bg-rose-500/10 text-rose-600 border-rose-500/30 hover:bg-rose-500/20'
                    : 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30 hover:bg-emerald-500/20'
                }`}
                title={groceryMartOpen ? 'Pause Store & Stop Incoming Orders' : 'Open Store & Accept Orders'}
              >
                <Power className="w-3.5 h-3.5" />
                <span>{isTogglingStore ? 'Updating...' : groceryMartOpen ? 'Pause Store' : 'Open Store'}</span>
              </button>
            )}

            {/* Store Timing & Settings Shortcut */}
            <button
              type="button"
              onClick={onOpenSettings}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-card hover:bg-muted/70 text-text-secondary hover:text-text-primary border border-border/80 text-xs font-black uppercase tracking-wider transition-all cursor-pointer shrink-0"
              title="Configure Store Operating Hours, Delivery Radius & Geofence"
            >
              <Clock className="w-3.5 h-3.5 text-primary" />
              <span>Timings</span>
            </button>

          </div>

        </div>
      </div>

      {/* Store Isolation Context Alert Banner */}
      <div className={`flex items-center justify-between px-4 py-2 rounded-2xl border text-xs font-medium ${
        isBranchLocked
          ? 'bg-amber-500/10 border-amber-500/20 text-amber-800 dark:text-amber-300'
          : 'bg-muted/50 border-border/60 text-text-secondary'
      }`}>
        <div className="flex items-center gap-2">
          {isBranchLocked ? (
            <ShieldCheck className="w-4 h-4 text-amber-600 shrink-0" />
          ) : (
            <Radio className="w-4 h-4 text-primary shrink-0 animate-pulse" />
          )}
          <span>
            {isBranchLocked ? (
              <>
                <strong>Locked Station:</strong> You are managing <strong>{displayStoreName}</strong> ({selectedHubId}). All orders, inventory, and settlements are strictly isolated to your branch.
              </>
            ) : (
              <>
                <strong>Active Store Scope:</strong> Displaying data for <strong>{displayStoreName}</strong> ({selectedHubId || 'All'}). Switching stores filters catalog, stock, and orders instantly.
              </>
            )}
          </span>
        </div>

        <button
          type="button"
          onClick={onOpenSettings}
          className="text-[11px] font-bold text-primary hover:underline shrink-0 ml-2 cursor-pointer"
        >
          View Store Config →
        </button>
      </div>
    </div>
  )
}

