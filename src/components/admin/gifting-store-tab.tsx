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
  Package,
  Search,
  X,
  Tag,
  DollarSign,
  Boxes,
} from 'lucide-react'
import {
  GiftingStoreConfig,
  GiftingOccasion,
  GiftingHamper,
  DEFAULT_GIFTING_CONFIG,
} from '@/lib/gifting-store-config'

interface ProductSimple {
  id: string
  name: string
  price: number
  mrp: number
  imageUrl?: string | null
  category?: { name: string } | null
  unit?: string | null
}

export function GiftingStoreTab() {
  const [config, setConfig] = useState<GiftingStoreConfig>(DEFAULT_GIFTING_CONFIG)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [uploadingField, setUploadingField] = useState<string | null>(null)
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  // Catalog products for linking
  const [catalogProducts, setCatalogProducts] = useState<ProductSimple[]>([])
  const [isLoadingProducts, setIsLoadingProducts] = useState(false)

  // Product Selection Modal state
  const [pickerTarget, setPickerTarget] = useState<
    | { type: 'occasion'; id: string; name: string; selectedIds: string[] }
    | { type: 'hamper'; id: string; name: string; selectedIds: string[] }
    | null
  >(null)
  const [pickerSearch, setPickerSearch] = useState('')

  const bannerFileRef = useRef<HTMLInputElement>(null)

  // Fetch current config & catalog
  useEffect(() => {
    async function loadInitialData() {
      try {
        setIsLoading(true)
        const [configRes, productsRes] = await Promise.all([
          fetch('/api/admin/gifting-store'),
          fetch('/api/products?limit=250&excludeRestaurant=true'),
        ])

        if (configRes.ok) {
          const data = await configRes.json()
          if (data && data.occasions) {
            setConfig({
              ...DEFAULT_GIFTING_CONFIG,
              ...data,
              hampers: Array.isArray(data.hampers) ? data.hampers : [],
            })
          }
        }

        if (productsRes.ok) {
          const prodData = await productsRes.json()
          if (Array.isArray(prodData?.products)) {
            setCatalogProducts(prodData.products)
          }
        }
      } catch (err) {
        console.error('Failed to load gifting store config or catalog', err)
      } finally {
        setIsLoading(false)
      }
    }
    loadInitialData()
  }, [])

  // Auto-clear status message after 4s
  useEffect(() => {
    if (statusMessage) {
      const timer = setTimeout(() => setStatusMessage(null), 4000)
      return () => clearTimeout(timer)
    }
  }, [statusMessage])

  // Direct Image Upload via /api/upload to Supabase CDN
  const handleFileUpload = async (
    file: File,
    target: 'banner' | { type: 'occasion'; id: string } | { type: 'hamper'; id: string }
  ) => {
    try {
      const targetKey =
        typeof target === 'string'
          ? target
          : `${target.type}_${target.id}`
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
      } else if (target.type === 'occasion') {
        setConfig((prev) => ({
          ...prev,
          occasions: prev.occasions.map((occ) =>
            occ.id === target.id ? { ...occ, imageUrl: data.url } : occ
          ),
        }))
      } else if (target.type === 'hamper') {
        setConfig((prev) => ({
          ...prev,
          hampers: prev.hampers.map((hamp) =>
            hamp.id === target.id ? { ...hamp, imageUrl: data.url } : hamp
          ),
        }))
      }

      setStatusMessage({ type: 'success', text: 'Photo uploaded successfully to Supabase CDN!' })
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

      setStatusMessage({ type: 'success', text: 'Gifting Store updated successfully! Mobile app & web are live in sync.' })
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
      productIds: [],
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

  // Add a new Hamper
  const handleAddHamper = () => {
    const newId = `hamp_${Date.now()}`
    const newHamper: GiftingHamper = {
      id: newId,
      name: 'New Curated Hamper',
      tagline: 'Special Celebration Duo',
      price: 499,
      mrp: 649,
      badge: '✨ ROYAL CHOICE',
      imageUrl: '',
      bundledProductIds: [],
      isActive: true,
      sortOrder: config.hampers.length + 1,
    }
    setConfig((prev) => ({
      ...prev,
      hampers: [...prev.hampers, newHamper],
    }))
  }

  // Remove Hamper
  const handleDeleteHamper = (id: string) => {
    if (!confirm('Are you sure you want to delete this custom hamper?')) return
    setConfig((prev) => ({
      ...prev,
      hampers: prev.hampers.filter((h) => h.id !== id),
    }))
  }

  // Toggle product in picker
  const toggleProductInPicker = (productId: string) => {
    if (!pickerTarget) return
    const isSelected = pickerTarget.selectedIds.includes(productId)
    const nextIds = isSelected
      ? pickerTarget.selectedIds.filter((id) => id !== productId)
      : [...pickerTarget.selectedIds, productId]

    setPickerTarget({ ...pickerTarget, selectedIds: nextIds })

    if (pickerTarget.type === 'occasion') {
      setConfig((prev) => ({
        ...prev,
        occasions: prev.occasions.map((occ) =>
          occ.id === pickerTarget.id ? { ...occ, productIds: nextIds } : occ
        ),
      }))
    } else if (pickerTarget.type === 'hamper') {
      setConfig((prev) => ({
        ...prev,
        hampers: prev.hampers.map((hamp) =>
          hamp.id === pickerTarget.id ? { ...hamp, bundledProductIds: nextIds } : hamp
        ),
      }))
    }
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

  const filteredPickerProducts = catalogProducts.filter((p) => {
    if (!pickerSearch.trim()) return true
    const q = pickerSearch.toLowerCase()
    return (
      p.name.toLowerCase().includes(q) ||
      (p.category?.name ?? '').toLowerCase().includes(q)
    )
  })

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
            <h2 className="text-xl font-bold tracking-tight">Gifting & Hamper Manager</h2>
            <span className="px-2.5 py-0.5 text-xs font-extrabold uppercase bg-emerald-500/10 text-emerald-600 rounded-full border border-emerald-500/20">
              Live Sync
            </span>
          </div>
          <p className="text-sm text-muted-foreground">
            Full admin control over Occasions, Real Product Tagging (Ghatampur Hub), and Custom 1-Tap Gift Hampers.
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
          </div>

          {/* Right: Banner Image Uploader & Live Preview */}
          <div className="space-y-3">
            <label className="text-xs font-bold text-muted-foreground uppercase tracking-wider block">
              Hero Banner Image (Optional Custom Art)
            </label>

            <div
              className="relative w-full h-48 rounded-2xl p-6 text-white flex flex-col justify-between overflow-hidden shadow-md"
              style={{
                background: `linear-gradient(135deg, ${config.gradientStart}, ${config.gradientEnd})`,
              }}
            >
              {config.bannerImageUrl && (
                <img
                  src={config.bannerImageUrl}
                  alt="Banner Art"
                  className="absolute right-3 bottom-0 max-h-40 object-contain drop-shadow-xl z-0"
                />
              )}

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
                <span>🎁 {config.hampers.length} Custom Hampers Live</span>
              </div>
            </div>

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
          </div>
        </div>
      </div>

      {/* ── CARD 2: OCCASION VISUAL CHIPS & PRODUCT TAGGING ──────── */}
      <div className="bg-card rounded-2xl border border-border p-6 shadow-xs space-y-6">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pb-3 border-b border-border">
          <div className="flex items-center gap-2">
            <Layers className="w-5 h-5 text-primary" />
            <div>
              <h3 className="text-base font-bold">Occasion Categories ({config.occasions.length})</h3>
              <p className="text-xs text-muted-foreground">
                In cards par photo upload karein (Seasonal packshot style) aur Ghatampur Hub se specific real products link karein.
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
            const linkedCount = occ.productIds?.length || 0

            return (
              <div
                key={occ.id}
                className={`p-4 rounded-2xl border transition-all space-y-3.5 ${
                  occ.isActive
                    ? 'bg-card border-border shadow-xs'
                    : 'bg-muted/40 border-dashed border-border opacity-70'
                }`}
              >
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

                {/* Circular Packshot Photo Upload Box (Seasonal Switch-Up style) */}
                <div className="relative border border-dashed border-border rounded-xl p-3 bg-muted/20 flex items-center gap-3">
                  <div className="w-14 h-14 rounded-full bg-background border-2 border-primary/20 flex items-center justify-center overflow-hidden shrink-0 shadow-2xs">
                    {occ.imageUrl ? (
                      <img src={occ.imageUrl} alt={occ.title} className="w-full h-full object-cover" />
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
                      className="flex items-center gap-1.5 px-3 py-1 bg-primary/10 text-primary hover:bg-primary/20 text-xs font-bold rounded-lg transition-all"
                    >
                      {isUploading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Upload className="w-3 h-3" />}
                      {occ.imageUrl ? 'Change Packshot' : 'Upload Packshot'}
                    </button>

                    {occ.imageUrl && (
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
                    )}
                  </div>
                </div>

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

                {/* Product Linking Button */}
                <div className="pt-1 border-t border-border/60">
                  <button
                    type="button"
                    onClick={() =>
                      setPickerTarget({
                        type: 'occasion',
                        id: occ.id,
                        name: occ.title || occ.label,
                        selectedIds: occ.productIds || [],
                      })
                    }
                    className="w-full flex items-center justify-between px-3 py-2 bg-secondary/80 hover:bg-secondary rounded-xl text-xs font-bold transition-all"
                  >
                    <span className="flex items-center gap-1.5 text-secondary-foreground">
                      <Package className="w-3.5 h-3.5 text-primary" />
                      Link Catalog Products
                    </span>
                    <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary font-black text-[11px]">
                      {linkedCount} linked
                    </span>
                  </button>
                  <p className="text-[10px] text-muted-foreground mt-1 px-1">
                    {linkedCount > 0
                      ? `Only these ${linkedCount} real products will show in this tab.`
                      : 'No products linked yet (falls back to category tags).'}
                  </p>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* ── CARD 3: CURATED 1-TAP HAMPERS CREATOR ────────────────── */}
      <div className="bg-card rounded-2xl border border-border p-6 shadow-xs space-y-6">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 pb-3 border-b border-border">
          <div className="flex items-center gap-2">
            <Boxes className="w-5 h-5 text-primary" />
            <div>
              <h3 className="text-base font-bold">Curated 1-Tap Hampers ({config.hampers.length})</h3>
              <p className="text-xs text-muted-foreground">
                Aapke dwara banaye gaye real hampers. Har hamper me real products link honge taaki live stock count ho sake.
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={handleAddHamper}
            className="flex items-center gap-1.5 px-3.5 py-2 bg-pink-500 text-white hover:bg-pink-600 text-xs font-bold rounded-xl shadow-xs transition-all"
          >
            <Plus className="w-3.5 h-3.5" />
            + Create New Hamper
          </button>
        </div>

        {config.hampers.length === 0 ? (
          <div className="p-8 rounded-2xl border-2 border-dashed border-border text-center space-y-2">
            <Boxes className="w-8 h-8 text-muted-foreground mx-auto opacity-50" />
            <h4 className="text-sm font-bold text-foreground">No Custom Hampers Yet</h4>
            <p className="text-xs text-muted-foreground max-w-md mx-auto">
              Mobile app me zero fake hampers dikhenge. Click &quot;+ Create New Hamper&quot; to build your first real gift hamper (e.g. Mithai + Chocolates combo).
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {config.hampers.map((hamper, idx) => {
              const isUploading = uploadingField === `hamper_${hamper.id}`
              const fileInputRef = React.createRef<HTMLInputElement>()
              const bundleCount = hamper.bundledProductIds?.length || 0

              return (
                <div
                  key={hamper.id}
                  className={`p-4 rounded-2xl border transition-all space-y-3.5 ${
                    hamper.isActive
                      ? 'bg-card border-border shadow-xs'
                      : 'bg-muted/40 border-dashed border-border opacity-70'
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="px-2 py-0.5 rounded-md bg-pink-500/10 text-pink-700 font-extrabold text-[10px]">
                      HAMPER #{idx + 1}
                    </span>

                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        onClick={() =>
                          setConfig((prev) => ({
                            ...prev,
                            hampers: prev.hampers.map((h) =>
                              h.id === hamper.id ? { ...h, isActive: !h.isActive } : h
                            ),
                          }))
                        }
                        title={hamper.isActive ? 'Hide Hamper' : 'Show Hamper'}
                        className={`p-1.5 rounded-lg text-xs font-bold transition-all ${
                          hamper.isActive ? 'text-emerald-600 hover:bg-emerald-50' : 'text-muted-foreground hover:bg-muted'
                        }`}
                      >
                        {hamper.isActive ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                      </button>

                      <button
                        type="button"
                        onClick={() => handleDeleteHamper(hamper.id)}
                        className="p-1.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded-lg transition-all"
                        title="Delete Hamper"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Hamper Photo Upload */}
                  <div className="relative border border-dashed border-border rounded-xl p-3 bg-muted/20 flex items-center gap-3">
                    <div className="w-16 h-16 rounded-xl bg-background border border-border flex items-center justify-center overflow-hidden shrink-0 shadow-2xs">
                      {hamper.imageUrl ? (
                        <img src={hamper.imageUrl} alt={hamper.name} className="w-full h-full object-cover" />
                      ) : (
                        <span className="text-2xl">🎁</span>
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
                          if (file) handleFileUpload(file, { type: 'hamper', id: hamper.id })
                        }}
                      />

                      <button
                        type="button"
                        onClick={() => fileInputRef.current?.click()}
                        disabled={isUploading}
                        className="flex items-center gap-1.5 px-3 py-1 bg-primary/10 text-primary hover:bg-primary/20 text-xs font-bold rounded-lg transition-all"
                      >
                        {isUploading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Upload className="w-3 h-3" />}
                        {hamper.imageUrl ? 'Change Photo' : 'Upload Photo'}
                      </button>

                      <p className="text-[10px] text-muted-foreground truncate">Real photography (Supabase CDN)</p>
                    </div>
                  </div>

                  {/* Hamper Name & Tagline */}
                  <div className="space-y-2">
                    <div>
                      <label className="text-[11px] font-bold text-muted-foreground block mb-0.5">
                        Hamper Title
                      </label>
                      <input
                        type="text"
                        value={hamper.name}
                        onChange={(e) =>
                          setConfig((prev) => ({
                            ...prev,
                            hampers: prev.hampers.map((h) =>
                              h.id === hamper.id ? { ...h, name: e.target.value } : h
                            ),
                          }))
                        }
                        placeholder="e.g. Ghatampur Royal Mithai Box"
                        className="w-full px-3 py-1.5 rounded-lg border border-border bg-background text-xs font-bold focus:ring-1 focus:ring-primary outline-hidden"
                      />
                    </div>

                    <div>
                      <label className="text-[11px] font-bold text-muted-foreground block mb-0.5">
                        Tagline Subtitle
                      </label>
                      <input
                        type="text"
                        value={hamper.tagline}
                        onChange={(e) =>
                          setConfig((prev) => ({
                            ...prev,
                            hampers: prev.hampers.map((h) =>
                              h.id === hamper.id ? { ...h, tagline: e.target.value } : h
                            ),
                          }))
                        }
                        placeholder="e.g. Kaju Katli + Belgian Truffle Cake"
                        className="w-full px-3 py-1.5 rounded-lg border border-border bg-background text-xs font-medium focus:ring-1 focus:ring-primary outline-hidden"
                      />
                    </div>
                  </div>

                  {/* Pricing & Badge */}
                  <div className="grid grid-cols-3 gap-2">
                    <div>
                      <label className="text-[11px] font-bold text-muted-foreground block mb-0.5">Price (₹)</label>
                      <input
                        type="number"
                        min="0"
                        value={hamper.price}
                        onChange={(e) =>
                          setConfig((prev) => ({
                            ...prev,
                            hampers: prev.hampers.map((h) =>
                              h.id === hamper.id ? { ...h, price: parseFloat(e.target.value) || 0 } : h
                            ),
                          }))
                        }
                        className="w-full px-2.5 py-1.5 rounded-lg border border-border bg-background text-xs font-black focus:ring-1 focus:ring-primary outline-hidden"
                      />
                    </div>

                    <div>
                      <label className="text-[11px] font-bold text-muted-foreground block mb-0.5">MRP (₹)</label>
                      <input
                        type="number"
                        min="0"
                        value={hamper.mrp}
                        onChange={(e) =>
                          setConfig((prev) => ({
                            ...prev,
                            hampers: prev.hampers.map((h) =>
                              h.id === hamper.id ? { ...h, mrp: parseFloat(e.target.value) || 0 } : h
                            ),
                          }))
                        }
                        className="w-full px-2.5 py-1.5 rounded-lg border border-border bg-background text-xs font-semibold focus:ring-1 focus:ring-primary outline-hidden"
                      />
                    </div>

                    <div>
                      <label className="text-[11px] font-bold text-muted-foreground block mb-0.5">Badge</label>
                      <input
                        type="text"
                        value={hamper.badge}
                        onChange={(e) =>
                          setConfig((prev) => ({
                            ...prev,
                            hampers: prev.hampers.map((h) =>
                              h.id === hamper.id ? { ...h, badge: e.target.value } : h
                            ),
                          }))
                        }
                        placeholder="✨ ROYAL"
                        className="w-full px-2.5 py-1.5 rounded-lg border border-border bg-background text-xs font-bold focus:ring-1 focus:ring-primary outline-hidden"
                      />
                    </div>
                  </div>

                  {/* Bundled Product Linker */}
                  <div className="pt-1 border-t border-border/60">
                    <button
                      type="button"
                      onClick={() =>
                        setPickerTarget({
                          type: 'hamper',
                          id: hamper.id,
                          name: hamper.name,
                          selectedIds: hamper.bundledProductIds || [],
                        })
                      }
                      className="w-full flex items-center justify-between px-3 py-2 bg-pink-500/10 hover:bg-pink-500/20 text-pink-700 rounded-xl text-xs font-bold transition-all"
                    >
                      <span className="flex items-center gap-1.5">
                        <Boxes className="w-3.5 h-3.5" />
                        Bundle Products
                      </span>
                      <span className="px-2 py-0.5 rounded-full bg-pink-500 text-white font-black text-[10px]">
                        {bundleCount} items
                      </span>
                    </button>
                    <p className="text-[10px] text-muted-foreground mt-1 px-1">
                      {bundleCount > 0
                        ? `${bundleCount} real items will be added to cart and stock-checked.`
                        : '⚠️ Link at least 1 real product for accurate stock tracking.'}
                    </p>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* ── MODAL: PRODUCT LINKER DRAWER ─────────────────────────── */}
      {pickerTarget && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-card w-full max-w-2xl rounded-2xl border border-border shadow-2xl flex flex-col max-h-[85vh] overflow-hidden animate-in fade-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="p-4 sm:p-5 border-b border-border flex items-center justify-between gap-3 bg-muted/30">
              <div>
                <span className="text-[10px] font-extrabold uppercase tracking-wider text-primary">
                  {pickerTarget.type === 'occasion' ? 'Occasion Product Linker' : 'Hamper Bundle Creator'}
                </span>
                <h3 className="text-base font-bold text-foreground">
                  Link Products for &ldquo;{pickerTarget.name}&rdquo;
                </h3>
              </div>

              <button
                type="button"
                onClick={() => setPickerTarget(null)}
                className="p-2 text-muted-foreground hover:text-foreground hover:bg-muted rounded-xl transition-all"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Search Box */}
            <div className="p-4 border-b border-border bg-background">
              <div className="relative">
                <Search className="w-4 h-4 text-muted-foreground absolute left-3 top-3" />
                <input
                  type="text"
                  value={pickerSearch}
                  onChange={(e) => setPickerSearch(e.target.value)}
                  placeholder="Search catalog products (name, category, price)..."
                  className="w-full pl-9 pr-4 py-2 rounded-xl border border-border bg-muted/20 text-xs font-semibold focus:ring-2 focus:ring-primary/20 outline-hidden"
                />
              </div>
              <div className="flex items-center justify-between text-[11px] text-muted-foreground mt-2 px-1">
                <span>Showing {filteredPickerProducts.length} products</span>
                <span className="font-bold text-primary">{pickerTarget.selectedIds.length} currently selected</span>
              </div>
            </div>

            {/* Product List */}
            <div className="p-4 overflow-y-auto divide-y divide-border/60 flex-1">
              {filteredPickerProducts.length === 0 ? (
                <div className="py-12 text-center text-muted-foreground text-xs">
                  No products matched your search.
                </div>
              ) : (
                filteredPickerProducts.map((p) => {
                  const isChecked = pickerTarget.selectedIds.includes(p.id)

                  return (
                    <div
                      key={p.id}
                      onClick={() => toggleProductInPicker(p.id)}
                      className={`py-2.5 px-3 rounded-xl flex items-center justify-between gap-3 cursor-pointer transition-all ${
                        isChecked ? 'bg-primary/5 hover:bg-primary/10' : 'hover:bg-muted/40'
                      }`}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <div
                          className={`w-5 h-5 rounded-md border flex items-center justify-center shrink-0 transition-all ${
                            isChecked
                              ? 'bg-primary border-primary text-primary-foreground'
                              : 'border-muted-foreground/40 bg-background'
                          }`}
                        >
                          {isChecked && <Check className="w-3.5 h-3.5" />}
                        </div>

                        {p.imageUrl ? (
                          <img
                            src={p.imageUrl}
                            alt={p.name}
                            className="w-10 h-10 object-contain rounded-lg border border-border bg-white p-0.5 shrink-0"
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-lg bg-muted flex items-center justify-center text-xs shrink-0">
                            📦
                          </div>
                        )}

                        <div className="min-w-0">
                          <p className="text-xs font-bold text-foreground truncate">{p.name}</p>
                          <p className="text-[10px] text-muted-foreground">
                            {p.category?.name || 'General'} {p.unit ? `• ${p.unit}` : ''}
                          </p>
                        </div>
                      </div>

                      <div className="text-right shrink-0">
                        <span className="text-xs font-black text-foreground">₹{Math.round(p.price)}</span>
                        {p.mrp > p.price && (
                          <span className="text-[10px] text-muted-foreground line-through block">
                            ₹{Math.round(p.mrp)}
                          </span>
                        )}
                      </div>
                    </div>
                  )
                })
              )}
            </div>

            {/* Modal Footer */}
            <div className="p-4 border-t border-border bg-muted/20 flex items-center justify-between">
              <span className="text-xs font-bold text-muted-foreground">
                {pickerTarget.selectedIds.length} items will be linked.
              </span>
              <button
                type="button"
                onClick={() => setPickerTarget(null)}
                className="px-5 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl shadow-xs hover:opacity-90 transition-all"
              >
                Done / Keep Changes
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
