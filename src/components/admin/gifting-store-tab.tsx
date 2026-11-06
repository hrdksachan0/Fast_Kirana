'use client'

import React, { useState, useEffect, useRef } from 'react'
import {
  Gift,
  Upload,
  Trash2,
  Plus,
  Check,
  Loader2,
  Sparkles,
  Image as ImageIcon,
  Layers,
  Save,
  RefreshCw,
  Eye,
  EyeOff,
  Palette,
} from 'lucide-react'
import { GiftingStoreConfig, GiftingOccasion, DEFAULT_GIFTING_CONFIG } from '@/lib/gifting-store-config'

export function GiftingStoreTab() {
  const [config, setConfig] = useState<GiftingStoreConfig>(DEFAULT_GIFTING_CONFIG)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [uploadingField, setUploadingField] = useState<string | null>(null)
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  const bannerFileRef = useRef<HTMLInputElement>(null)

  // Fetch current config
  useEffect(() => {
    async function fetchConfig() {
      try {
        setIsLoading(true)
        const res = await fetch('/api/admin/gifting-store')
        if (res.ok) {
          const data = await res.json()
          if (data && data.occasions) {
            setConfig(data)
          }
        }
      } catch (err) {
        console.error('Failed to load gifting store config', err)
      } finally {
        setIsLoading(false)
      }
    }
    fetchConfig()
  }, [])

  // Auto-clear status message after 4s
  useEffect(() => {
    if (statusMessage) {
      const timer = setTimeout(() => setStatusMessage(null), 4000)
      return () => clearTimeout(timer)
    }
  }, [statusMessage])

  // Direct Image Upload via /api/upload
  const handleFileUpload = async (file: File, target: 'banner' | { type: 'occasion'; id: string }) => {
    try {
      const targetKey = typeof target === 'string' ? target : `occasion_${target.id}`
      setUploadingField(targetKey)

      const formData = new FormData()
      formData.append('file', file)

      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      })

      const data = await res.json()
      if (!res.ok || !data.url) {
        throw new Error(data.error || 'Upload failed')
      }

      if (target === 'banner') {
        setConfig((prev) => ({ ...prev, bannerImageUrl: data.url }))
      } else {
        setConfig((prev) => ({
          ...prev,
          occasions: prev.occasions.map((occ) =>
            occ.id === target.id ? { ...occ, imageUrl: data.url } : occ
          ),
        }))
      }

      setStatusMessage({ type: 'success', text: 'Image uploaded successfully to Supabase!' })
    } catch (err: any) {
      console.error('Image upload failed:', err)
      setStatusMessage({ type: 'error', text: err.message || 'Image upload failed. Please try again.' })
    } finally {
      setUploadingField(null)
    }
  }

  // Save Config to Server
  const handleSave = async () => {
    try {
      setIsSaving(true)
      setStatusMessage(null)

      const res = await fetch('/api/admin/gifting-store', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config),
      })

      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to save')
      }

      setStatusMessage({ type: 'success', text: 'Gifting Store updated successfully! Mobile app is live in sync.' })
    } catch (err: any) {
      console.error('Save failed:', err)
      setStatusMessage({ type: 'error', text: err.message || 'Failed to save configuration.' })
    } finally {
      setIsSaving(false)
    }
  }

  // Add a new Occasion
  const handleAddOccasion = () => {
    const newId = `occ_${Date.now()}`
    const newOccasion: GiftingOccasion = {
      id: newId,
      label: 'New Occasion',
      title: 'Curated Gifts',
      imageUrl: '',
      emoji: '🎁',
      tags: ['gift'],
      isActive: true,
      sortOrder: config.occasions.length + 1,
    }
    setConfig((prev) => ({
      ...prev,
      occasions: [...prev.occasions, newOccasion],
    }))
  }

  // Remove Occasion
  const handleDeleteOccasion = (id: string) => {
    if (!confirm('Are you sure you want to remove this occasion from the Gifting Store?')) return
    setConfig((prev) => ({
      ...prev,
      occasions: prev.occasions.filter((occ) => occ.id !== id),
    }))
  }

  // Presets for gradient theme
  const THEME_PRESETS = [
    { label: 'Rose Gold', start: '#E89E90', end: '#CD7564' },
    { label: 'Royal Crimson', start: '#BE123C', end: '#881337' },
    { label: 'Festive Amber', start: '#F59E0B', end: '#D97706' },
    { label: 'Luxury Velvet', start: '#7C3AED', end: '#4C1D95' },
    { label: 'Emerald Glow', start: '#059669', end: '#065F46' },
    { label: 'Midnight Slate', start: '#1E293B', end: '#0F172A' },
  ]

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center p-16 space-y-4">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
        <p className="text-sm font-semibold text-muted-foreground">Loading Gifting Store Configuration...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6 max-w-6xl mx-auto pb-16">
      {/* Top Action Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-card p-6 rounded-2xl border border-border shadow-xs">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="p-2 bg-pink-500/10 text-pink-600 rounded-xl">
              <Gift className="w-5 h-5" />
            </span>
            <h2 className="text-xl font-bold tracking-tight">Gifting Store Manager</h2>
            <span className="px-2.5 py-0.5 text-xs font-extrabold uppercase bg-emerald-500/10 text-emerald-600 rounded-full border border-emerald-500/20">
              Live Sync
            </span>
          </div>
          <p className="text-sm text-muted-foreground">
            Customize the mobile app Gifting Store: upload high-res photography, customize the hero banner, and curate festive occasions.
          </p>
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          {/* Master Enable/Disable Toggle */}
          <button
            type="button"
            onClick={() => setConfig((prev) => ({ ...prev, enabled: !prev.enabled }))}
            className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold border transition-all ${
              config.enabled
                ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30'
                : 'bg-muted text-muted-foreground border-border'
            }`}
          >
            {config.enabled ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
            {config.enabled ? 'Store Visible' : 'Store Hidden'}
          </button>

          <button
            type="button"
            onClick={handleSave}
            disabled={isSaving}
            className="flex items-center gap-2 px-5 py-2.5 bg-primary text-primary-foreground font-bold text-sm rounded-xl shadow-sm hover:opacity-90 transition-all disabled:opacity-50"
          >
            {isSaving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            {isSaving ? 'Saving...' : 'Save Changes'}
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

      {/* ── CARD 1: HERO BANNER & THEME ───────────────────────────── */}
      <div className="bg-card rounded-2xl border border-border p-6 shadow-xs space-y-6">
        <div className="flex items-center gap-2 pb-3 border-b border-border">
          <Palette className="w-5 h-5 text-primary" />
          <h3 className="text-base font-bold">Hero Banner & Visual Theme</h3>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Form Inputs */}
          <div className="space-y-4">
            <div>
              <label className="text-xs font-bold text-muted-foreground uppercase tracking-wider block mb-1.5">
                Banner Headline Title
              </label>
              <input
                type="text"
                value={config.bannerTitle}
                onChange={(e) => setConfig((prev) => ({ ...prev, bannerTitle: e.target.value }))}
                placeholder="e.g. Gifting Store / Diwali Gifting Specials"
                className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-background text-sm font-semibold focus:ring-2 focus:ring-primary/20 focus:border-primary outline-hidden"
              />
            </div>

            <div>
              <label className="text-xs font-bold text-muted-foreground uppercase tracking-wider block mb-1.5">
                Banner Tagline Subtitle
              </label>
              <input
                type="text"
                value={config.bannerSubtitle}
                onChange={(e) => setConfig((prev) => ({ ...prev, bannerSubtitle: e.target.value }))}
                placeholder="e.g. Curated with Love by FastMinute"
                className="w-full px-3.5 py-2.5 rounded-xl border border-border bg-background text-sm font-semibold focus:ring-2 focus:ring-primary/20 focus:border-primary outline-hidden"
              />
            </div>

            {/* Gradient Preset Selector */}
            <div>
              <label className="text-xs font-bold text-muted-foreground uppercase tracking-wider block mb-1.5">
                Gradient Theme Presets
              </label>
              <div className="flex flex-wrap gap-2">
                {THEME_PRESETS.map((preset) => (
                  <button
                    key={preset.label}
                    type="button"
                    onClick={() =>
                      setConfig((prev) => ({
                        ...prev,
                        gradientStart: preset.start,
                        gradientEnd: preset.end,
                      }))
                    }
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border transition-all ${
                      config.gradientStart === preset.start
                        ? 'border-primary shadow-xs ring-1 ring-primary'
                        : 'border-border hover:border-foreground/30'
                    }`}
                  >
                    <span
                      className="w-3.5 h-3.5 rounded-full border border-white/20"
                      style={{ background: `linear-gradient(135deg, ${preset.start}, ${preset.end})` }}
                    />
                    {preset.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Custom Hex Codes */}
            <div className="grid grid-cols-2 gap-3 pt-2">
              <div>
                <label className="text-xs font-bold text-muted-foreground block mb-1">Gradient Start Hex</label>
                <div className="flex items-center gap-2">
                  <input
                    type="color"
                    value={config.gradientStart}
                    onChange={(e) => setConfig((prev) => ({ ...prev, gradientStart: e.target.value }))}
                    className="w-9 h-9 rounded-lg border border-border p-0.5 cursor-pointer"
                  />
                  <input
                    type="text"
                    value={config.gradientStart}
                    onChange={(e) => setConfig((prev) => ({ ...prev, gradientStart: e.target.value }))}
                    className="w-full px-3 py-1.5 rounded-lg border border-border bg-background text-xs font-mono font-bold"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-bold text-muted-foreground block mb-1">Gradient End Hex</label>
                <div className="flex items-center gap-2">
                  <input
                    type="color"
                    value={config.gradientEnd}
                    onChange={(e) => setConfig((prev) => ({ ...prev, gradientEnd: e.target.value }))}
                    className="w-9 h-9 rounded-lg border border-border p-0.5 cursor-pointer"
                  />
                  <input
                    type="text"
                    value={config.gradientEnd}
                    onChange={(e) => setConfig((prev) => ({ ...prev, gradientEnd: e.target.value }))}
                    className="w-full px-3 py-1.5 rounded-lg border border-border bg-background text-xs font-mono font-bold"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Right: Banner Image Uploader & Live Preview */}
          <div className="space-y-3">
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wider block">
              Hero Banner Image (Optional Custom Art)
            </label>

            {/* Live Banner Preview Box */}
            <div
              className="relative w-full h-48 rounded-2xl p-6 text-white flex flex-col justify-between overflow-hidden shadow-md"
              style={{
                background: `linear-gradient(135deg, ${config.gradientStart}, ${config.gradientEnd})`,
              }}
            >
              {/* Background Art if Uploaded */}
              {config.bannerImageUrl && (
                <img
                  src={config.bannerImageUrl}
                  alt="Banner Art"
                  className="absolute right-3 bottom-0 max-h-40 object-contain drop-shadow-xl z-0"
                />
              )}

              {/* Text Preview */}
              <div className="relative z-10 space-y-1">
                <span className="text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 bg-black/20 rounded-md">
                  FastMinute Luxury
                </span>
                <h4 className="text-2xl font-black tracking-tight drop-shadow-sm">
                  {config.bannerTitle || 'Gifting Store'}
                </h4>
                <p className="text-xs text-white/90 font-medium">
                  {config.bannerSubtitle || 'Curated with Love'}
                </p>
              </div>

              <div className="relative z-10 flex items-center justify-between text-[11px] font-semibold text-white/80">
                <span>⚡ Ghatampur Instant Delivery</span>
                <span>🎁 Curated Hampers</span>
              </div>
            </div>

            {/* Upload & Action Buttons */}
            <div className="flex items-center gap-2 pt-1">
              <input
                ref={bannerFileRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0]
                  if (file) handleFileUpload(file, 'banner')
                }}
              />

              <button
                type="button"
                onClick={() => bannerFileRef.current?.click()}
                disabled={uploadingField === 'banner'}
                className="flex items-center gap-2 px-4 py-2 bg-secondary text-secondary-foreground text-xs font-bold rounded-xl border border-border hover:bg-secondary/80 transition-all"
              >
                {uploadingField === 'banner' ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Upload className="w-3.5 h-3.5" />
                )}
                {config.bannerImageUrl ? 'Change Banner Art' : 'Upload Banner Image'}
              </button>

              {config.bannerImageUrl && (
                <button
                  type="button"
                  onClick={() => setConfig((prev) => ({ ...prev, bannerImageUrl: '' }))}
                  className="px-3 py-2 text-xs font-bold text-destructive hover:bg-destructive/10 rounded-xl transition-all"
                >
                  Remove Custom Image
                </button>
              )}
            </div>
            <p className="text-[11px] text-muted-foreground">
              Images are automatically converted to optimized WebP (&lt;80 KB) and stored on Supabase CDN.
            </p>
          </div>
        </div>
      </div>

      {/* ── CARD 2: OCCASIONS & CATEGORIES MANAGER ────────────────── */}
      <div className="bg-card rounded-2xl border border-border p-6 shadow-xs space-y-6">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pb-3 border-b border-border">
          <div className="flex items-center gap-2">
            <Layers className="w-5 h-5 text-primary" />
            <div>
              <h3 className="text-base font-bold">Occasion Cards ({config.occasions.length})</h3>
              <p className="text-xs text-muted-foreground">
                In cards par aap apni photo upload kar sakte hain, title edit kar sakte hain aur naye occasions jod sakte hain.
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={handleAddOccasion}
            className="flex items-center gap-1.5 px-3.5 py-2 bg-primary/10 text-primary border border-primary/20 hover:bg-primary/20 text-xs font-bold rounded-xl transition-all"
          >
            <Plus className="w-3.5 h-3.5" />
            + Add New Occasion
          </button>
        </div>

        {/* Occasions Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {config.occasions.map((occ, idx) => {
            const isUploading = uploadingField === `occasion_${occ.id}`
            const fileInputRef = React.createRef<HTMLInputElement>()

            return (
              <div
                key={occ.id}
                className={`p-4 rounded-2xl border transition-all space-y-3.5 ${
                  occ.isActive
                    ? 'bg-card border-border shadow-xs'
                    : 'bg-muted/40 border-dashed border-border opacity-70'
                }`}
              >
                {/* Occasion Card Header */}
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="w-6 h-6 rounded-full bg-primary/10 text-primary text-xs font-black flex items-center justify-center">
                      {idx + 1}
                    </span>
                    <input
                      type="text"
                      value={occ.label}
                      onChange={(e) =>
                        setConfig((prev) => ({
                          ...prev,
                          occasions: prev.occasions.map((o) =>
                            o.id === occ.id ? { ...o, label: e.target.value } : o
                          ),
                        }))
                      }
                      className="font-bold text-sm bg-transparent border-b border-transparent hover:border-border focus:border-primary outline-hidden"
                      placeholder="e.g. Birthday"
                    />
                  </div>

                  <div className="flex items-center gap-1">
                    {/* Active Toggle */}
                    <button
                      type="button"
                      onClick={() =>
                        setConfig((prev) => ({
                          ...prev,
                          occasions: prev.occasions.map((o) =>
                            o.id === occ.id ? { ...o, isActive: !o.isActive } : o
                          ),
                        }))
                      }
                      title={occ.isActive ? 'Hide Occasion' : 'Show Occasion'}
                      className={`p-1.5 rounded-lg text-xs font-bold transition-all ${
                        occ.isActive ? 'text-emerald-600 hover:bg-emerald-50' : 'text-muted-foreground hover:bg-muted'
                      }`}
                    >
                      {occ.isActive ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                    </button>

                    {/* Delete */}
                    <button
                      type="button"
                      onClick={() => handleDeleteOccasion(occ.id)}
                      className="p-1.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-lg transition-all"
                      title="Delete Occasion"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>

                {/* Image Upload Box */}
                <div className="relative border border-dashed border-border rounded-xl p-3 bg-muted/20 flex items-center gap-3">
                  <div className="w-16 h-16 rounded-xl bg-background border border-border flex items-center justify-center overflow-hidden shrink-0 shadow-2xs">
                    {occ.imageUrl ? (
                      <img src={occ.imageUrl} alt={occ.title} className="w-full h-full object-contain p-1" />
                    ) : (
                      <span className="text-2xl">{occ.emoji || '🎁'}</span>
                    )}
                  </div>

                  <div className="flex-1 min-w-0 space-y-1">
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={(e) => {
                        const file = e.target.files?.[0]
                        if (file) handleFileUpload(file, { type: 'occasion', id: occ.id })
                      }}
                    />

                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={isUploading}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 text-primary hover:bg-primary/20 text-xs font-bold rounded-lg transition-all"
                    >
                      {isUploading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Upload className="w-3 h-3" />}
                      {occ.imageUrl ? 'Change Photo' : 'Upload Image'}
                    </button>

                    {occ.imageUrl ? (
                      <button
                        type="button"
                        onClick={() =>
                          setConfig((prev) => ({
                            ...prev,
                            occasions: prev.occasions.map((o) =>
                              o.id === occ.id ? { ...o, imageUrl: '' } : o
                            ),
                          }))
                        }
                        className="text-[10px] text-destructive hover:underline block"
                      >
                        Reset to Emoji
                      </button>
                    ) : (
                      <p className="text-[10px] text-muted-foreground truncate">No image uploaded (showing emoji)</p>
                    )}
                  </div>
                </div>

                {/* Subtitle / Title Input */}
                <div>
                  <label className="text-[11px] font-bold text-muted-foreground block mb-1">
                    Display Card Title
                  </label>
                  <input
                    type="text"
                    value={occ.title}
                    onChange={(e) =>
                      setConfig((prev) => ({
                        ...prev,
                        occasions: prev.occasions.map((o) =>
                          o.id === occ.id ? { ...o, title: e.target.value } : o
                        ),
                      }))
                    }
                    placeholder="e.g. Birthday Specials"
                    className="w-full px-3 py-1.5 rounded-lg border border-border bg-background text-xs font-semibold focus:ring-1 focus:ring-primary outline-hidden"
                  />
                </div>

                {/* Emoji & Tags */}
                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <label className="text-[11px] font-bold text-muted-foreground block mb-1">Emoji</label>
                    <input
                      type="text"
                      value={occ.emoji}
                      onChange={(e) =>
                        setConfig((prev) => ({
                          ...prev,
                          occasions: prev.occasions.map((o) =>
                            o.id === occ.id ? { ...o, emoji: e.target.value } : o
                          ),
                        }))
                      }
                      className="w-full px-2.5 py-1.5 rounded-lg border border-border bg-background text-xs font-bold text-center focus:ring-1 focus:ring-primary outline-hidden"
                    />
                  </div>

                  <div className="col-span-2">
                    <label className="text-[11px] font-bold text-muted-foreground block mb-1">
                      Filter Tags (comma separated)
                    </label>
                    <input
                      type="text"
                      value={occ.tags.join(', ')}
                      onChange={(e) =>
                        setConfig((prev) => ({
                          ...prev,
                          occasions: prev.occasions.map((o) =>
                            o.id === occ.id
                              ? {
                                  ...o,
                                  tags: e.target.value
                                    .split(',')
                                    .map((t) => t.trim().toLowerCase())
                                    .filter(Boolean),
                                }
                              : o
                          ),
                        }))
                      }
                      placeholder="cake, gift, chocolate"
                      className="w-full px-3 py-1.5 rounded-lg border border-border bg-background text-xs font-medium focus:ring-1 focus:ring-primary outline-hidden"
                    />
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
