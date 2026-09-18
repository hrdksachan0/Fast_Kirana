'use client'

import React, { useRef, useEffect } from 'react'
import { motion } from 'framer-motion'
import { ShoppingBag, Package, TrendingUp, Zap, Ticket, Utensils, Users, ChevronRight } from 'lucide-react'

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
  const tabsContainerRef = useRef<HTMLDivElement>(null)
  const activeTabRef = useRef<HTMLButtonElement | null>(null)

  // Auto-scroll active tab into view smoothly
  useEffect(() => {
    if (activeTabRef.current) {
      activeTabRef.current.scrollIntoView({
        behavior: 'smooth',
        block: 'nearest',
        inline: 'center',
      })
    }
  }, [activeTab])

  return (
    <div className="space-y-4">
      {/* 6-Hub Operational Cluster Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2.5 sm:gap-3">
        {hubs.map((hub) => {
          const HubIcon = HUB_ICONS[hub.key] || Package
          const isActive = activeHub === hub.key
          
          // Calculate aggregate badge count for this hub
          const hubBadgeCount = tabConfig
            .filter((tab) => (hub.tabs as readonly string[]).includes(tab.key))
            .reduce((acc, curr) => acc + (curr.count || 0), 0)

          return (
            <button
              key={hub.key}
              type="button"
              onClick={() => {
                setActiveHub(hub.key)
                setActiveTab(hub.tabs[0])
              }}
              className={`group relative text-left p-3 sm:p-3.5 rounded-2xl border transition-all duration-300 cursor-pointer overflow-hidden select-none flex flex-col justify-between min-h-[90px] ${
                isActive
                  ? `bg-card ${hub.activeBorder} shadow-sm ring-2 ring-primary/20`
                  : 'bg-card/70 hover:bg-card border-border/70 hover:border-border shadow-2xs hover:shadow-xs'
              }`}
            >
              {/* Subtle top active indicator bar */}
              {isActive && (
                <div className="absolute top-0 left-0 right-0 h-1 bg-primary rounded-t-2xl" />
              )}

              {/* Dynamic decorative background glow */}
              <div
                className={`absolute right-0 bottom-0 -mr-4 -mb-4 h-14 w-14 rounded-full bg-gradient-to-br ${hub.color} blur-md opacity-40 transition-transform duration-500 ${
                  isActive ? 'scale-150 opacity-80' : 'scale-100 group-hover:scale-125'
                }`}
              />

              <div className="flex items-center justify-between relative z-10 w-full mb-1">
                <div
                  className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-xl transition-all ${
                    isActive
                      ? 'bg-primary text-primary-foreground shadow-xs'
                      : 'bg-muted text-text-secondary group-hover:text-text-primary'
                  }`}
                >
                  <HubIcon className="h-4 w-4" />
                </div>

                {hubBadgeCount > 0 && (
                  <span className="inline-flex items-center px-1.5 py-0.5 rounded-full text-[9px] font-black bg-primary/10 text-primary border border-primary/20">
                    {hubBadgeCount}
                  </span>
                )}
              </div>

              <div className="relative z-10">
                <h4 className={`text-[11.5px] font-black tracking-tight line-clamp-1 ${
                  isActive ? 'text-text-primary' : 'text-text-secondary group-hover:text-text-primary'
                }`}>
                  {hub.label}
                </h4>
                <p className="text-[9.5px] text-text-muted mt-0.5 line-clamp-1 font-medium hidden sm:block">
                  {hub.description}
                </p>
              </div>
            </button>
          )
        })}
      </div>

      {/* Sub-Tab Segmented Navigation inside active Hub */}
      <div className="relative">
        <div 
          ref={tabsContainerRef}
          className="flex border border-border/70 overflow-x-auto whitespace-nowrap scrollbar-none gap-1 p-1.5 bg-muted/40 rounded-2xl max-w-full sm:max-w-max relative scroll-smooth shadow-2xs"
        >
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
                  ref={isActive ? (el) => { activeTabRef.current = el } : undefined}
                  onClick={() => setActiveTab(tab.key)}
                  className={`relative flex items-center gap-1.5 px-3.5 py-2 text-xs font-black rounded-xl transition-all cursor-pointer select-none ${
                    isActive
                      ? 'text-primary'
                      : 'text-text-secondary hover:text-text-primary hover:bg-card/50'
                  }`}
                >
                  {isActive && (
                    <motion.div
                      layoutId="activeTabBackground"
                      className="absolute inset-0 bg-card shadow-sm border border-border/80 rounded-xl -z-10"
                      transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                    />
                  )}
                  <TabIcon className="h-3.5 w-3.5 z-10" />
                  <span className="z-10 tracking-tight">
                    {tab.label}
                  </span>
                  {tab.count !== undefined && tab.count > 0 && (
                    <span className={`z-10 text-[9.5px] font-black px-1.5 py-0.2 rounded-full border ${
                      isActive
                        ? 'bg-primary/15 text-primary border-primary/30'
                        : 'bg-muted text-text-secondary border-border/60'
                    }`}>
                      {tab.count}
                    </span>
                  )}
                </button>
              )
            })
          })()}
        </div>
      </div>
    </div>
  )
}

