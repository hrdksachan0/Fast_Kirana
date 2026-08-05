'use client'

import React from 'react'
import { motion } from 'framer-motion'
import { ShoppingBag, Package, TrendingUp, Zap, Ticket, Utensils, Users } from 'lucide-react'

const HUB_ICONS: Record<string, any> = {
  orders_hub: ShoppingBag,
  grocery: Package,
  food: Utensils,
  insights: TrendingUp,
  people: Users,
  ops: Zap,
  marketing: Ticket,
}

export interface HubNavTab {
  key: string
  label: string
  icon: any
  count?: number
}

export interface HubNavItem {
  key: string
  label: string
  description: string
  color: string
  activeBorder: string
  tabs: readonly string[]
}

export interface DashboardHubNavProps {
  activeHub: string
  setActiveHub: (hub: any) => void
  activeTab: string
  setActiveTab: (tab: any) => void
  hubs: readonly HubNavItem[]
  tabConfig: HubNavTab[]
}

export function DashboardHubNav({
  activeHub,
  setActiveHub,
  activeTab,
  setActiveTab,
  hubs,
  tabConfig,
}: DashboardHubNavProps) {
  return (
    <div className="space-y-4">
      {/* Consolidated Operational Hub Selection Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {hubs.map((hub) => {
          const HubIcon = HUB_ICONS[hub.key] || Package
          const isActive = activeHub === hub.key
          return (
            <button
              key={hub.key}
              type="button"
              onClick={() => {
                setActiveHub(hub.key)
                setActiveTab(hub.tabs[0])
              }}
              className={`relative text-left p-4 rounded-2xl border transition-all duration-300 cursor-pointer overflow-hidden select-none ${
                isActive
                  ? `bg-gradient-to-br ${hub.color} ${hub.activeBorder} shadow-md`
                  : 'bg-card hover:bg-muted/40 border-border/50 shadow-sm hover:shadow-md'
              }`}
            >
              {/* Dynamic decorative background glow */}
              <div
                className={`absolute right-0 bottom-0 -mr-6 -mb-6 h-16 w-16 rounded-full bg-gradient-to-br ${hub.color} blur-lg opacity-40 transition-transform duration-500 ${
                  isActive ? 'scale-150' : 'scale-100'
                }`}
              />

              <div className="flex items-center gap-3.5 relative z-10">
                <div
                  className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl transition-all ${
                    isActive ? 'bg-primary text-primary-foreground' : 'bg-muted text-text-secondary'
                  }`}
                >
                  <HubIcon className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="text-xs font-black text-text-primary">{hub.label}</h4>
                  <p className="text-[10px] text-text-secondary mt-0.5 line-clamp-1">{hub.description}</p>
                </div>
              </div>
            </button>
          )
        })}
      </div>

      {/* Sub-Tab Navigation inside active Hub */}
      <div className="flex border-b border-border/60 overflow-x-auto whitespace-nowrap scrollbar-none gap-1.5 p-1 bg-muted/30 rounded-xl max-w-max relative">
        {(() => {
          const activeHubData = hubs.find((h) => h.key === activeHub)
          const activeHubSubTabs = activeHubData
            ? tabConfig.filter((tab) => (activeHubData.tabs as readonly string[]).includes(tab.key))
            : []

          return activeHubSubTabs.map((tab) => {
            const TabIcon = tab.icon
            const isActive = activeTab === tab.key
            return (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`relative flex items-center gap-1.5 px-3 py-2 text-[11px] font-extrabold rounded-lg transition-all cursor-pointer select-none ${
                  isActive ? 'text-primary' : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                {isActive && (
                  <motion.div
                    layoutId="activeTabBackground"
                    className="absolute inset-0 bg-card shadow-sm border border-border/50 rounded-lg -z-10"
                    transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                  />
                )}
                <TabIcon className="h-3.5 w-3.5 z-10" />
                <span className="z-10">
                  {tab.label} {tab.count !== undefined ? `(${tab.count})` : ''}
                </span>
              </button>
            )
          })
        })()}
      </div>
    </div>
  )
}
