'use client'

import React from 'react'
import { RefreshCw, ListChecks, Zap } from 'lucide-react'

export interface PickerActionsBarProps {
  isRefreshing: boolean
  onRefresh: () => void
  batchMode: boolean
  setBatchMode: (mode: boolean) => void
  totalCount: number
}

export function PickerActionsBar({
  isRefreshing,
  onRefresh,
  batchMode,
  setBatchMode,
  totalCount,
}: PickerActionsBarProps) {
  return (
    <div className="flex items-center justify-between bg-card p-3 rounded-2xl border border-border/60 shadow-xs">
      <div className="flex items-center gap-2">
        <div className="p-2 rounded-xl bg-amber-500/10 text-amber-600 dark:text-amber-400">
          <Zap className="h-4 w-4" />
        </div>
        <div>
          <h3 className="text-xs font-black text-text-primary">Picker Dispatch Console</h3>
          <p className="text-[10px] text-text-secondary">{totalCount} orders assigned to queue</p>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={() => setBatchMode(!batchMode)}
          className={`px-3 py-1.5 text-xs font-black rounded-xl transition-all border flex items-center gap-1.5 cursor-pointer ${
            batchMode
              ? 'bg-purple-600 text-white border-purple-600 shadow-xs'
              : 'bg-muted/40 border-border text-text-secondary hover:bg-muted'
          }`}
        >
          <ListChecks className="h-3.5 w-3.5" />
          <span>{batchMode ? 'Batch Mode ON' : 'Batch Mode'}</span>
        </button>

        <button
          onClick={onRefresh}
          disabled={isRefreshing}
          className="p-2 rounded-xl bg-muted/40 border border-border text-text-secondary hover:text-text-primary transition-all disabled:opacity-50 cursor-pointer"
          title="Refresh Queue"
        >
          <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
        </button>
      </div>
    </div>
  )
}
