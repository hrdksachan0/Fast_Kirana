'use client'

import React, { useState, useEffect } from 'react'
import {
  Layers,
  ArrowUp,
  ArrowDown,
  Eye,
  EyeOff,
  Save,
  Loader2,
  RefreshCw,
  Sparkles,
  Smartphone,
  Check,
  AlertCircle,
} from 'lucide-react'
import {
  HomeLayoutConfig,
  HomeSectionConfig,
  DEFAULT_HOME_LAYOUT,
} from '@/lib/home-layout-config'

export function HomeLayoutTab() {
  const [config, setConfig] = useState<HomeLayoutConfig>(DEFAULT_HOME_LAYOUT)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  useEffect(() => {
    async function loadLayout() {
      try {
        setIsLoading(true)
        const res = await fetch('/api/admin/home-layout')
        if (res.ok) {
          const data = await res.json()
          if (data && Array.isArray(data.sections) && data.sections.length > 0) {
            setConfig(data)
          }
        }
      } catch (err) {
        console.error('Failed to load home layout', err)
      } finally {
        setIsLoading(false)
      }
    }
    loadLayout()
  }, [])

  useEffect(() => {
    if (statusMessage) {
      const timer = setTimeout(() => setStatusMessage(null), 4000)
      return () => clearTimeout(timer)
    }
  }, [statusMessage])

  const moveSection = (index: number, direction: 'up' | 'down') => {
    const newSections = [...config.sections]
    const targetIndex = direction === 'up' ? index - 1 : index + 1

    if (targetIndex < 0 || targetIndex >= newSections.length) return

    const temp = newSections[index]
    newSections[index] = newSections[targetIndex]
    newSections[targetIndex] = temp

    // Reassign sort orders
    const updated = newSections.map((sec, idx) => ({
      ...sec,
      sortOrder: idx + 1,
    }))

    setConfig({ sections: updated })
  }

  const toggleVisibility = (id: string) => {
    setConfig((prev) => ({
      sections: prev.sections.map((sec) =>
        sec.id === id ? { ...sec, enabled: !sec.enabled } : sec
      ),
    }))
  }

  const handleReset = () => {
    if (!confirm('Reset sections to default Blinkit-style sequence?')) return
    setConfig(DEFAULT_HOME_LAYOUT)
  }

  const handleSave = async () => {
    try {
      setIsSaving(true)
      setStatusMessage(null)

      const res = await fetch('/api/admin/home-layout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config),
      })

      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error || 'Failed to save layout')
      }

      setStatusMessage({
        type: 'success',
        text: 'Home Screen Layout updated! Mobile app updates instantly without APK build.',
      })
    } catch (err: any) {
      console.error('Save failed:', err)
      setStatusMessage({ type: 'error', text: err.message || 'Failed to save configuration.' })
    } finally {
      setIsSaving(false)
    }
  }

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center p-16 space-y-4">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
        <p className="text-sm font-semibold text-muted-foreground">Loading Home Screen Layout...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6 max-w-6xl mx-auto pb-16">
      {/* Top Action Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-card p-6 rounded-2xl border border-border shadow-xs">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="p-2 bg-amber-500/10 text-amber-600 rounded-xl">
              <Layers className="w-5 h-5" />
            </span>
            <h2 className="text-xl font-bold tracking-tight">Home Screen Sections Manager</h2>
            <span className="px-2.5 py-0.5 text-xs font-extrabold uppercase bg-emerald-500/10 text-emerald-600 rounded-full border border-emerald-500/20">
              Server-Driven UI
            </span>
          </div>
          <p className="text-sm text-muted-foreground">
            Blinkit-style instant reordering. Move sections up & down or hide them without building any APK.
          </p>
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          <button
            type="button"
            onClick={handleReset}
            className="flex items-center gap-2 px-3.5 py-2.5 rounded-xl text-xs font-bold border border-border bg-muted/60 text-muted-foreground hover:text-foreground transition-all"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            Reset Default
          </button>

          <button
            type="button"
            onClick={handleSave}
            disabled={isSaving}
            className="flex items-center gap-2 px-5 py-2.5 bg-primary text-primary-foreground font-bold text-sm rounded-xl shadow-sm hover:opacity-90 transition-all disabled:opacity-50"
          >
            {isSaving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            {isSaving ? 'Saving...' : 'Save Live Layout'}
          </button>
        </div>
      </div>

      {/* Status Alert Banner */}
      {statusMessage && (
        <div
          className={`p-4 rounded-xl text-sm font-semibold flex items-center justify-between border ${
            statusMessage.type === 'success'
              ? 'bg-emerald-50 text-emerald-800 border-emerald-200 dark:bg-emerald-950/30 dark:text-emerald-400 dark:border-emerald-800'
              : 'bg-rose-50 text-rose-800 border-rose-200 dark:bg-rose-950/30 dark:text-rose-400 dark:border-rose-800'
          }`}
        >
          <span>{statusMessage.text}</span>
          <button
            type="button"
            onClick={() => setStatusMessage(null)}
            className="text-xs underline hover:opacity-75"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Main Dual Grid: Reorder List Left + Mobile Live Preview Right */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        
        {/* Reorder List Column */}
        <div className="lg:col-span-7 space-y-3">
          <div className="text-xs font-bold uppercase tracking-wider text-muted-foreground px-1 flex items-center justify-between">
            <span>Arrange Sequence (Top to Bottom)</span>
            <span>Position</span>
          </div>

          {config.sections.map((section, idx) => {
            const isFirst = idx === 0
            const isLast = idx === config.sections.length - 1

            return (
              <div
                key={section.id}
                className={`p-4 rounded-2xl border transition-all flex items-center justify-between gap-4 ${
                  section.enabled
                    ? 'bg-card border-border shadow-xs hover:border-primary/40'
                    : 'bg-muted/40 border-border/60 opacity-60'
                }`}
              >
                {/* Left: Position Number & Info */}
                <div className="flex items-center gap-3.5 flex-1">
                  <div className="w-8 h-8 rounded-xl bg-primary/10 text-primary font-black text-xs flex items-center justify-center flex-shrink-0">
                    #{idx + 1}
                  </div>
                  <div>
                    <div className="font-bold text-sm text-foreground flex items-center gap-2">
                      <span>{section.label}</span>
                      {!section.enabled && (
                        <span className="text-[10px] font-bold bg-muted px-2 py-0.5 rounded text-muted-foreground">
                          Hidden
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-muted-foreground mt-0.5 line-clamp-1">
                      {section.description}
                    </div>
                  </div>
                </div>

                {/* Right: Actions (Up, Down, Toggle) */}
                <div className="flex items-center gap-1.5 flex-shrink-0">
                  {/* Up Button */}
                  <button
                    type="button"
                    onClick={() => moveSection(idx, 'up')}
                    disabled={isFirst}
                    title="Move Up"
                    className="p-2 rounded-xl border border-border bg-background hover:bg-muted text-foreground transition-all disabled:opacity-25 disabled:cursor-not-allowed"
                  >
                    <ArrowUp className="w-4 h-4" />
                  </button>

                  {/* Down Button */}
                  <button
                    type="button"
                    onClick={() => moveSection(idx, 'down')}
                    disabled={isLast}
                    title="Move Down"
                    className="p-2 rounded-xl border border-border bg-background hover:bg-muted text-foreground transition-all disabled:opacity-25 disabled:cursor-not-allowed"
                  >
                    <ArrowDown className="w-4 h-4" />
                  </button>

                  {/* Visibility Toggle */}
                  <button
                    type="button"
                    onClick={() => toggleVisibility(section.id)}
                    title={section.enabled ? 'Hide from App' : 'Show in App'}
                    className={`p-2 rounded-xl border transition-all ${
                      section.enabled
                        ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-600'
                        : 'border-border bg-muted text-muted-foreground'
                    }`}
                  >
                    {section.enabled ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            )
          })}
        </div>

        {/* Live Mobile Screen Simulator Right */}
        <div className="lg:col-span-5 bg-card border border-border rounded-2xl p-6 shadow-xs space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-border">
            <Smartphone className="w-4 h-4 text-primary" />
            <h3 className="text-sm font-bold">Live Phone Layout Preview</h3>
          </div>

          <p className="text-xs text-muted-foreground">
            This is how your mobile app will render sections from top to bottom:
          </p>

          <div className="bg-[#090D16] border-2 border-slate-700 rounded-3xl p-3 text-white space-y-2.5 shadow-xl max-w-xs mx-auto">
            {/* Top Search Bar */}
            <div className="bg-white rounded-xl p-2 text-slate-400 text-[11px] font-semibold flex items-center justify-between">
              <span>Search for &quot;milk&quot;...</span>
              <span className="text-red-500">🎙️</span>
            </div>

            {/* Dynamic Sections Stack in Phone */}
            <div className="space-y-2">
              {config.sections
                .filter((s) => s.enabled)
                .map((sec, i) => {
                  let bgColor = 'bg-slate-800'
                  let borderColor = 'border-slate-700'
                  if (sec.id === 'diwali_campaign') {
                    bgColor = 'bg-gradient-to-r from-red-950 to-amber-950'
                    borderColor = 'border-amber-500/40'
                  } else if (sec.id === 'bento_gifting' || sec.id === 'campaign_bento') {
                    bgColor = 'bg-gradient-to-r from-pink-950 to-rose-950'
                    borderColor = 'border-rose-500/40'
                  } else if (sec.id === 'bento_fresh_market') {
                    bgColor = 'bg-gradient-to-r from-emerald-950 to-teal-950'
                    borderColor = 'border-emerald-500/40'
                  } else if (sec.id === 'bento_seasonal') {
                    bgColor = 'bg-gradient-to-r from-sky-950 to-cyan-950'
                    borderColor = 'border-sky-500/40'
                  } else if (sec.id === 'bento_daily_restock') {
                    bgColor = 'bg-gradient-to-r from-amber-950 to-yellow-950'
                    borderColor = 'border-amber-500/40'
                  } else if (sec.id === 'bento_value_picks') {
                    bgColor = 'bg-gradient-to-r from-purple-950 to-violet-950'
                    borderColor = 'border-purple-500/40'
                  } else if (sec.id === 'top_categories') {
                    bgColor = 'bg-gradient-to-r from-blue-950 to-indigo-950'
                    borderColor = 'border-indigo-500/40'
                  } else if (sec.id === 'hero_banners') {
                    bgColor = 'bg-slate-800'
                    borderColor = 'border-slate-700'
                  }

                  return (
                    <div
                      key={sec.id}
                      className={`p-2.5 rounded-xl border ${bgColor} ${borderColor} flex items-center justify-between text-xs`}
                    >
                      <div className="font-extrabold text-[11px] line-clamp-1">{sec.label}</div>
                      <span className="text-[9px] font-black opacity-70 bg-black/40 px-1.5 py-0.5 rounded">
                        #{i + 1}
                      </span>
                    </div>
                  )
                })}
            </div>
          </div>
        </div>

      </div>
    </div>
  )
}
