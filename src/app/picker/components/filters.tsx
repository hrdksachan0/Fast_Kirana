'use client'

import React from 'react'
import { Search } from 'lucide-react'

export interface PickerFiltersProps {
  statusFilter: string
  setStatusFilter: (status: string) => void
  searchQuery: string
  setSearchQuery: (query: string) => void
  pendingCount: number
  confirmedCount: number
  packedCount: number
  allCount: number
}

export function PickerFilters({
  statusFilter,
  setStatusFilter,
  searchQuery,
  setSearchQuery,
  pendingCount,
  confirmedCount,
  packedCount,
  allCount,
}: PickerFiltersProps) {
  const tabs = [
    { id: 'PENDING', label: `Placed (${pendingCount})`, color: 'bg-amber-500' },
    { id: 'CONFIRMED', label: `Confirmed (${confirmedCount})`, color: 'bg-blue-500' },
    { id: 'PACKED', label: `Packed (${packedCount})`, color: 'bg-emerald-500' },
    { id: 'ALL', label: `All (${allCount})`, color: 'bg-muted' },
  ]

  return (
    <div className="space-y-3">
      {/* Status Tabs */}
      <div className="flex border-b border-border/40 overflow-x-auto whitespace-nowrap scrollbar-none gap-2 pb-1">
        {tabs.map((tab) => {
          const selected = statusFilter === tab.id
          return (
            <button
              key={tab.id}
              onClick={() => setStatusFilter(tab.id)}
              className={`px-3.5 py-1.5 text-xs font-black rounded-xl transition-all flex items-center gap-1.5 cursor-pointer ${
                selected
                  ? 'bg-primary text-white shadow-xs scale-102'
                  : 'bg-muted/40 text-text-secondary hover:bg-muted'
              }`}
            >
              <span className={`h-2 w-2 rounded-full ${tab.color}`} />
              <span>{tab.label}</span>
            </button>
          )
        })}
      </div>

      {/* Search Input */}
      <div className="relative">
        <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
        <input
          type="text"
          placeholder="Search by Order ID or Customer Name..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full pl-9 pr-4 py-2 text-xs rounded-xl border border-border bg-card focus:outline-none focus:border-primary font-bold shadow-2xs"
        />
      </div>
    </div>
  )
}
