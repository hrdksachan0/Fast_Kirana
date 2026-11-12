'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import {
  CheckCircle2,
  Eye,
  Monitor,
  Plus,
  RotateCcw,
  Save,
  Search,
  Smartphone,
  Sparkles,
  Trash2,
  Upload,
  Wand2,
  X,
  AlertTriangle,
  Clock,
} from 'lucide-react'
import type { Product } from '@/types'
import { apiUrl } from '@/lib/api-url'
import { cn } from '@/lib/utils'
import {
  autoLinkBentoConfigProducts,
  campaignBentoConfigSchema,
  collectBentoSlotItems,
  defaultCampaignBentoConfig,
  isBentoCardVisible,
  resolveBentoSlotProduct,
  type BentoCardKey,
  type BentoSlotItem,
  type BentoTimeSlot,
  type CampaignBentoConfig,
} from '@/lib/campaign-bento-config'
import { campaignImageSchema } from '@/lib/campaign-config'
import { navratriAsset } from '@/components/home/navratri/data'
import { InteractiveCampaignBento } from '@/components/home/interactive-campaign-bento'

interface CampaignBentoEditorProps {
  storeId?: string
  onUpload: (file: File, callback: (url: string) => void) => Promise<void>
  authHeaders?: Record<string, string>
  /** Optional preloaded products from parent; editor still fetches full store grocery catalogue when omitted */
  catalogueProducts?: Product[]
}

const inputClass =
  'w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-900 focus:border-primary focus:outline-none'
const buttonClass =
  'inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-800 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50 cursor-pointer'

const CARD_META: { key: BentoCardKey; num: string; label: string; accent: string }[] = [
  { key: 'freshMarket', num: '01', label: 'Fresh Market', accent: 'bg-emerald-50 border-emerald-200 text-emerald-800' },
  { key: 'dailyRestock', num: '02', label: 'Daily Restock', accent: 'bg-sky-50 border-sky-200 text-sky-800' },
  { key: 'valuePicks', num: '03', label: 'Value Picks', accent: 'bg-amber-50 border-amber-200 text-amber-900' },
  { key: 'giftingBoutique', num: '04', label: 'Gifting Boutique', accent: 'bg-rose-50 border-rose-200 text-rose-800' },
  { key: 'movieNight', num: '05', label: 'Movie Night', accent: 'bg-purple-50 border-purple-200 text-purple-900' },
  { key: 'breakfastClub', num: '06', label: 'Breakfast Club', accent: 'bg-orange-50 border-orange-200 text-orange-900' },
]

function BentoImageInput({
  label,
  value,
  onChange,
  onUpload,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  onUpload: (file: File, callback: (url: string) => void) => Promise<void>
}) {
  const [uploading, setUploading] = useState(false)
  const valid = campaignImageSchema.safeParse(value).success

  return (
    <div className="space-y-1.5">
      <label className="block text-xs font-semibold text-slate-700">{label}</label>
      <div className="flex items-center gap-2">
        <input
          type="text"
          className={inputClass}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="/navratri/daily-vegetables.svg or https://..."
        />
        <label className={`${buttonClass} shrink-0`}>
          <Upload size={14} />
          {uploading ? 'Uploading…' : 'Upload'}
          <input
            type="file"
            className="sr-only"
            accept="image/png,image/jpeg,image/webp,image/svg+xml,image/avif"
            disabled={uploading}
            onChange={async (event) => {
              const file = event.target.files?.[0]
              if (!file) return
              setUploading(true)
              try {
                await onUpload(file, (url) => onChange(url))
              } finally {
                setUploading(false)
                event.target.value = ''
              }
            }}
          />
        </label>
      </div>
      {valid && value && (
        <div className="flex items-center gap-2">
          <img
            src={navratriAsset(value)}
            alt={label}
            className="h-10 w-10 rounded-lg border border-slate-200 bg-slate-50 object-contain"
          />
          <span className="text-[11px] text-slate-500 truncate max-w-[260px]">{value}</span>
        </div>
      )}
    </div>
  )
}

function BentoSlotEditor({
  slot,
  indexLabel,
  products,
  onChange,
  onRemove,
  canRemove,
  showBadgeField = false,
  showPerUnitField = false,
  showCheckedDefault = false,
}: {
  slot: BentoSlotItem
  indexLabel: string
  products: Product[]
  onChange: (patch: Partial<BentoSlotItem>) => void
  onRemove?: () => void
  canRemove?: boolean
  showBadgeField?: boolean
  showPerUnitField?: boolean
  showCheckedDefault?: boolean
}) {
  const [pickerOpen, setPickerOpen] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')

  const resolved = useMemo(() => resolveBentoSlotProduct(slot, products), [slot, products])
  const groceryProducts = useMemo(
    () => products.filter((p) => !p.restaurantId),
    [products]
  )

  const filteredProducts = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()
    const list = q
      ? groceryProducts.filter((p) =>
          `${p.name} ${p.unit} ${p.category?.name ?? ''} ${p.slug} ${p.id}`
            .toLowerCase()
            .includes(q)
        )
      : groceryProducts
    return list.slice(0, 40)
  }, [groceryProducts, searchQuery])

  return (
    <div className="rounded-xl border border-slate-200 bg-slate-50/70 p-3 space-y-2.5">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-xs font-bold text-slate-800">{indexLabel}</span>
          {resolved.isExplicitLink ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-bold text-emerald-800">
              <CheckCircle2 className="h-3 w-3" /> Real Product Linked
            </span>
          ) : resolved.isLinked ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-sky-100 px-2 py-0.5 text-[10px] font-bold text-sky-800">
              <Sparkles className="h-3 w-3" /> Auto-Matched Real Product
            </span>
          ) : (
            <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-800">
              <AlertTriangle className="h-3 w-3" /> Unlinked Fallback
            </span>
          )}
        </div>

        {onRemove && (
          <button
            type="button"
            disabled={!canRemove}
            onClick={onRemove}
            className="text-slate-400 hover:text-rose-600 disabled:opacity-30 cursor-pointer p-1"
            title="Remove item slot"
          >
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        )}
      </div>

      {/* Currently Resolved / Linked Product Card */}
      <div className="flex items-center justify-between gap-3 rounded-lg border border-slate-200 bg-white p-2">
        <div className="flex items-center gap-2.5 min-w-0">
          <img
            src={resolved.imageUrl}
            alt={resolved.name}
            className="h-10 w-10 rounded-lg border border-slate-100 bg-slate-50 object-contain shrink-0"
          />
          <div className="min-w-0">
            <p className="text-xs font-bold text-slate-900 truncate">{resolved.name}</p>
            <p className="text-[11px] text-slate-500">
              {resolved.unit} • <strong className="text-slate-900">₹{resolved.price}</strong>
              {resolved.mrp > resolved.price && (
                <span className="ml-1 line-through text-slate-400">₹{resolved.mrp}</span>
              )}
              {resolved.product && (
                <span
                  className={cn(
                    'ml-2 font-semibold',
                    resolved.inStock ? 'text-emerald-700' : 'text-rose-600'
                  )}
                >
                  {resolved.inStock ? `Stock: ${resolved.product.stock}` : 'Out of stock'}
                </span>
              )}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          {slot.productId && (
            <button
              type="button"
              onClick={() => onChange({ productId: null })}
              className="rounded-md border border-slate-200 px-2 py-1 text-[11px] font-semibold text-slate-600 hover:bg-slate-100 cursor-pointer"
              title="Unlink explicit product"
            >
              Unlink
            </button>
          )}
          <button
            type="button"
            onClick={() => setPickerOpen((v) => !v)}
            className={cn(
              'rounded-md px-2.5 py-1 text-[11px] font-bold cursor-pointer transition-colors',
              pickerOpen
                ? 'bg-slate-900 text-white'
                : 'bg-primary/10 text-primary hover:bg-primary/20'
            )}
          >
            {pickerOpen ? 'Close Picker' : slot.productId ? 'Change Product' : 'Pick Real Product'}
          </button>
        </div>
      </div>

      {/* Inline Searchable Real Product Picker */}
      {pickerOpen && (
        <div className="rounded-xl border border-slate-300 bg-white p-2.5 shadow-sm space-y-2">
          <div className="relative">
            <Search className="absolute left-2.5 top-2 h-3.5 w-3.5 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search store grocery products (e.g. Amul Milk, Atta, Tomato, Lays)..."
              className="w-full rounded-lg border border-slate-200 pl-8 pr-7 py-1.5 text-xs focus:border-primary focus:outline-none"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-2 top-2 text-slate-400 hover:text-slate-700 cursor-pointer"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
          </div>

          <div className="max-h-48 overflow-y-auto divide-y divide-slate-100">
            {filteredProducts.length === 0 ? (
              <p className="py-4 text-center text-xs text-slate-500">
                No matching grocery products found in this store.
              </p>
            ) : (
              filteredProducts.map((product) => {
                const isSelected = slot.productId === product.id
                const isInStock = product.isAvailable && product.stock > 0
                return (
                  <button
                    key={product.id}
                    type="button"
                    onClick={() => {
                      onChange({
                        productId: product.id,
                        fallbackName: product.name,
                        fallbackUnit: product.unit,
                        fallbackPrice: product.price,
                        fallbackMrp: product.mrp,
                        fallbackImage: product.imageUrl || slot.fallbackImage,
                      })
                      setPickerOpen(false)
                    }}
                    className={cn(
                      'w-full flex items-center justify-between gap-2 p-1.5 text-left hover:bg-slate-50 rounded-md cursor-pointer',
                      isSelected && 'bg-emerald-50/80'
                    )}
                  >
                    <div className="flex items-center gap-2 min-w-0">
                      <img
                        src={product.imageUrl || '/navratri/daily-vegetables.svg'}
                        alt={product.name}
                        className="h-8 w-8 rounded border border-slate-100 bg-white object-contain shrink-0"
                      />
                      <div className="min-w-0">
                        <p className="text-xs font-semibold text-slate-900 truncate">{product.name}</p>
                        <p className="text-[10px] text-slate-500 truncate">
                          {product.unit} {product.category?.name ? `· ${product.category.name}` : ''}
                        </p>
                      </div>
                    </div>
                    <div className="text-right shrink-0">
                      <p className="text-xs font-bold text-slate-900">₹{product.price}</p>
                      <p
                        className={cn(
                          'text-[10px] font-semibold',
                          isInStock ? 'text-emerald-700' : 'text-rose-600'
                        )}
                      >
                        {isInStock ? `${product.stock} in stock` : 'Out of stock'}
                      </p>
                    </div>
                  </button>
                )
              })
            )}
          </div>
        </div>
      )}

      {/* Optional Display Overrides */}
      <div className="grid gap-2 sm:grid-cols-2">
        <div>
          <label className="block text-[11px] font-semibold text-slate-600 mb-0.5">
            Display title override (optional)
          </label>
          <input
            type="text"
            className={inputClass}
            value={slot.customTitle ?? ''}
            placeholder={resolved.product ? resolved.product.name : slot.fallbackName}
            onChange={(e) => onChange({ customTitle: e.target.value || null })}
          />
        </div>

        {showBadgeField && (
          <div>
            <label className="block text-[11px] font-semibold text-slate-600 mb-0.5">
              Corner badge (optional)
            </label>
            <input
              type="text"
              className={inputClass}
              value={slot.badge ?? ''}
              placeholder="e.g. Better value"
              onChange={(e) => onChange({ badge: e.target.value || null })}
            />
          </div>
        )}

        {showPerUnitField && (
          <div>
            <label className="block text-[11px] font-semibold text-slate-600 mb-0.5">
              Unit rate label (auto if blank)
            </label>
            <input
              type="text"
              className={inputClass}
              value={slot.perUnitLabel ?? ''}
              placeholder={resolved.perUnitLabel ?? 'e.g. ₹50/kg'}
              onChange={(e) => onChange({ perUnitLabel: e.target.value || null })}
            />
          </div>
        )}

        {showCheckedDefault && (
          <label className="flex items-center gap-2 text-xs font-semibold text-slate-700 pt-4 cursor-pointer">
            <input
              type="checkbox"
              checked={slot.checkedByDefault !== false}
              onChange={(e) => onChange({ checkedByDefault: e.target.checked })}
            />
            Checked by default on card
          </label>
        )}
      </div>
    </div>
  )
}

export function CampaignBentoEditor({
  storeId,
  onUpload,
  authHeaders = {},
  catalogueProducts,
}: CampaignBentoEditorProps) {
  const [draft, setDraft] = useState<CampaignBentoConfig>(() =>
    structuredClone(defaultCampaignBentoConfig)
  )
  const [published, setPublished] = useState<CampaignBentoConfig | null>(null)
  const [selectedCard, setSelectedCard] = useState<BentoCardKey>('freshMarket')
  const [selectedFreshTabId, setSelectedFreshTabId] = useState<string>('sabzi')
  const [previewModeView, setPreviewModeView] = useState<'all-desktop' | 'all-mobile' | 'single'>(
    'single'
  )

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [dirty, setDirty] = useState(false)
  const [feedback, setFeedback] = useState('')
  const [products, setProducts] = useState<Product[]>(catalogueProducts ?? [])
  const [catalogueLoading, setCatalogueLoading] = useState(!catalogueProducts?.length)
  const saveVersion = useRef(0)

  const scope = storeId && storeId !== 'all' ? storeId : undefined
  const headerKey = JSON.stringify(authHeaders)

  useEffect(() => {
    if (catalogueProducts && catalogueProducts.length > 0) {
      setProducts(catalogueProducts)
      setCatalogueLoading(false)
    }
  }, [catalogueProducts])

  // Load store grocery products for real product picker
  useEffect(() => {
    const controller = new AbortController()
    setCatalogueLoading(true)
    const query = new URLSearchParams({ limit: '1000', type: 'grocery' })
    if (scope) query.set('storeId', scope)

    fetch(`${apiUrl()}/api/admin/products?${query.toString()}`, {
      signal: controller.signal,
      cache: 'no-store',
      headers: JSON.parse(headerKey),
    })
      .then(async (res) => {
        if (!res.ok) throw new Error('Catalogue unavailable')
        const body = await res.json()
        const rows = Array.isArray(body) ? body : body.products
        if (Array.isArray(rows) && !controller.signal.aborted) {
          setProducts(rows)
        }
      })
      .catch(() => {})
      .finally(() => {
        if (!controller.signal.aborted) setCatalogueLoading(false)
      })

    return () => controller.abort()
  }, [scope, headerKey])

  // Load saved Bento draft & published state from DB
  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    setFeedback('')
    setDirty(false)
    const query = scope ? `?storeId=${encodeURIComponent(scope)}` : ''

    fetch(`${apiUrl()}/api/admin/campaign-bento${query}`, {
      signal: controller.signal,
      cache: 'no-store',
      headers: JSON.parse(headerKey),
    })
      .then(async (res) => {
        const body = await res.json()
        if (!res.ok) throw new Error(body.error || 'Failed to load 6-Card Bento config')
        return body
      })
      .then((body) => {
        if (controller.signal.aborted) return
        const saved = body.draft ?? body.published ?? defaultCampaignBentoConfig
        const parsed = campaignBentoConfigSchema.safeParse(saved)
        setDraft(parsed.success ? parsed.data : structuredClone(defaultCampaignBentoConfig))
        const parsedPub = body.published ? campaignBentoConfigSchema.safeParse(body.published) : null
        setPublished(parsedPub?.success ? parsedPub.data : null)
      })
      .catch((err) => {
        if (!controller.signal.aborted) {
          setFeedback(err instanceof Error ? err.message : 'Unable to load saved config')
        }
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false)
      })

    return () => controller.abort()
  }, [scope, headerKey])

  const updateDraft = (updater: (prev: CampaignBentoConfig) => CampaignBentoConfig) => {
    setDirty(true)
    setFeedback('')
    setDraft((prev) => updater(prev))
  }

  const slotCoverage = useMemo(() => {
    const slots = collectBentoSlotItems(draft)
    const resolved = slots.map((s) => resolveBentoSlotProduct(s, products))
    return {
      total: slots.length,
      linked: resolved.filter((r) => r.isLinked).length,
      explicit: resolved.filter((r) => r.isExplicitLink).length,
    }
  }, [draft, products])

  const cardCoverage = (key: BentoCardKey) => {
    let items: BentoSlotItem[] = []
    if (key === 'freshMarket') items = draft.freshMarket.tabs.flatMap((t) => t.items)
    else if (key === 'dailyRestock') items = draft.dailyRestock.items
    else if (key === 'valuePicks') items = draft.valuePicks.items
    else if (key === 'giftingBoutique')
      items = [draft.giftingBoutique.heroItem, draft.giftingBoutique.miniItem]
    else if (key === 'movieNight') items = draft.movieNight.items
    else if (key === 'breakfastClub') items = draft.breakfastClub.items
    const linked = items.filter((s) => resolveBentoSlotProduct(s, products).isLinked).length
    return { linked, total: items.length }
  }

  const handleAutoMatchAll = () => {
    if (products.length === 0) {
      setFeedback('Catalogue is still loading or has no grocery products.')
      return
    }
    const { config, matchedCount, totalSlots } = autoLinkBentoConfigProducts(draft, products, {
      overwriteExisting: false,
    })
    setDraft(config)
    setDirty(true)
    setFeedback(
      `Auto-matched ${matchedCount} of ${totalSlots} card slots to real products in this store!`
    )
  }

  const saveAction = async (action: 'save-draft' | 'publish' | 'disable' | 'reset') => {
    const validated = campaignBentoConfigSchema.safeParse(draft)
    if (!validated.success && action !== 'reset') {
      setFeedback('Please check card inputs before saving.')
      return
    }
    const version = ++saveVersion.current
    setSaving(true)
    setFeedback('')
    try {
      const res = await fetch(`${apiUrl()}/api/admin/campaign-bento`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', ...authHeaders },
        body: JSON.stringify({
          action,
          storeId: scope,
          campaign: action === 'reset' ? defaultCampaignBentoConfig : draft,
        }),
      })
      const body = await res.json()
      if (version !== saveVersion.current) return
      if (!res.ok) throw new Error(body.error || 'Could not save 6-Card Bento config')

      if (action === 'reset') {
        const fresh = structuredClone(defaultCampaignBentoConfig)
        setDraft(fresh)
        setPublished(fresh)
        setDirty(false)
        setFeedback('Reset to default 6-Card Bento configuration.')
      } else if (action === 'publish') {
        setPublished(validated.success ? validated.data : draft)
        setDirty(false)
        setFeedback('6-Card Bento published! Storefront now shows these live cards & products.')
      } else if (action === 'disable') {
        setPublished((prev) => ({ ...(prev ?? draft), enabled: false }))
        setDraft((prev) => ({ ...prev, enabled: false }))
        setFeedback('6-Card Bento hidden from the storefront. Your draft is preserved.')
      } else {
        setDirty(false)
        setFeedback('Draft saved cleanly. Click "Publish Live" to push to customers.')
      }
    } catch (err) {
      if (version === saveVersion.current) {
        setFeedback(err instanceof Error ? err.message : 'Save failed')
      }
    } finally {
      if (version === saveVersion.current) setSaving(false)
    }
  }

  const newSlotTemplate = (prefix: string): BentoSlotItem => ({
    id: `${prefix}-${Math.random().toString(36).slice(2, 7)}`,
    productId: null,
    keywords: [],
    fallbackName: 'New Item',
    fallbackUnit: '1 pack',
    fallbackPrice: 50,
    fallbackMrp: 60,
    fallbackImage: '/navratri/daily-vegetables.svg',
  })

  const currentFreshTab =
    draft.freshMarket.tabs.find((t) => t.id === selectedFreshTabId) ?? draft.freshMarket.tabs[0]

  const currentCardItems = useMemo(() => {
    if (selectedCard === 'freshMarket') {
      return draft.freshMarket.tabs.flatMap((t) => t.items)
    }
    if (selectedCard === 'dailyRestock') return draft.dailyRestock.items
    if (selectedCard === 'valuePicks') return draft.valuePicks.items
    if (selectedCard === 'giftingBoutique') {
      return [draft.giftingBoutique.heroItem, draft.giftingBoutique.miniItem]
    }
    if (selectedCard === 'movieNight') return draft.movieNight.items
    if (selectedCard === 'breakfastClub') return draft.breakfastClub.items
    return []
  }, [draft, selectedCard])

  const cardVisibilityStatus = useMemo(() => {
    const card = draft[selectedCard]
    let inStock = 0
    for (const item of currentCardItems) {
      const res = resolveBentoSlotProduct(item, products)
      if (res.inStock) inStock += 1
    }
    return isBentoCardVisible(card, {
      inStockCount: inStock,
      currentStoreId: storeId || 'hub-209206',
    })
  }, [draft, selectedCard, currentCardItems, products, storeId])

  return (
    <div className="space-y-5" data-testid="campaign-bento-editor">
      {/* Header Toolbar */}
      <div className="flex flex-wrap items-start justify-between gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-2xs">
        <div>
          <h2 className="text-lg font-extrabold text-slate-900 flex items-center gap-2">
            <span>6-Card Interactive Bento Hub</span>
            <span className="rounded-full bg-emerald-100 px-2.5 py-0.5 text-[11px] font-bold text-emerald-800">
              {slotCoverage.linked}/{slotCoverage.total} Real Products Active
            </span>
          </h2>
          <p className="text-xs text-slate-500 mt-1">
            Edit all 6 homepage cards ({scope ? `Store: ${scope}` : 'Global Storefront'}), link real
            catalogue products, and inspect Live Preview before publishing.
          </p>
          <p className="text-xs font-semibold text-slate-600 mt-1.5">
            {published?.enabled === true
              ? 'Published 6-Card Bento is LIVE'
              : published?.enabled === false
                ? 'Published 6-Card Bento is HIDDEN'
                : 'Using smart default config with auto-matched products'}
            {dirty ? ' · Unsaved changes' : ''}
            {catalogueLoading ? ' · Loading store catalogue…' : ''}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className={buttonClass}
            disabled={loading || saving || catalogueLoading}
            onClick={handleAutoMatchAll}
          >
            <Wand2 className="h-3.5 w-3.5 text-emerald-600" />
            Auto-Match Products
          </button>
          <button
            type="button"
            className={buttonClass}
            disabled={loading || saving}
            onClick={() => saveAction('reset')}
          >
            <RotateCcw className="h-3.5 w-3.5" />
            Reset Default
          </button>
          <button
            type="button"
            className={buttonClass}
            disabled={loading || saving}
            onClick={() => saveAction('save-draft')}
          >
            <Save className="h-3.5 w-3.5" />
            Save Draft
          </button>
          <button
            type="button"
            className={buttonClass}
            disabled={loading || saving}
            onClick={() => saveAction('disable')}
          >
            Hide Section
          </button>
          <button
            type="button"
            className="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3.5 py-1.5 text-xs font-bold text-white hover:opacity-95 disabled:opacity-50 cursor-pointer"
            disabled={loading || saving}
            onClick={() => saveAction('publish')}
          >
            <Eye className="h-3.5 w-3.5" />
            {saving ? 'Publishing…' : 'Publish Live'}
          </button>
        </div>
      </div>

      {feedback && (
        <div
          role="status"
          className="rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-xs font-semibold text-slate-800 shadow-2xs"
        >
          {feedback}
        </div>
      )}

      {/* Card 01-06 Navigation Strip */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-2">
          {CARD_META.map((card) => {
            const cov = cardCoverage(card.key)
            const isSelected = selectedCard === card.key
            const isEnabled = draft[card.key].enabled
            return (
              <button
                key={card.key}
                type="button"
                onClick={() => setSelectedCard(card.key)}
                className={cn(
                  'flex items-center gap-2 rounded-xl border px-3 py-2 text-xs font-bold transition-all cursor-pointer',
                  isSelected
                    ? 'border-slate-900 bg-slate-900 text-white shadow-sm'
                    : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50',
                  !isEnabled && 'opacity-60'
                )}
              >
                <span className="opacity-70">{card.num}</span>
                <span>{card.label}</span>
                {draft[card.key].scheduleEnabled && (
                  <span className="text-[10px]" title="Automated schedule enabled">⏱</span>
                )}
                {typeof draft[card.key].sortOrder === 'number' && draft[card.key].sortOrder > 0 && (
                  <span className="text-[9px] opacity-70">#{draft[card.key].sortOrder}</span>
                )}
                <span
                  className={cn(
                    'rounded-full px-1.5 py-0.5 text-[10px]',
                    isSelected
                      ? 'bg-white/20 text-white'
                      : cov.linked === cov.total
                        ? 'bg-emerald-100 text-emerald-800'
                        : 'bg-amber-100 text-amber-800'
                  )}
                >
                  {cov.linked}/{cov.total}
                </span>
              </button>
            )
          })}
        </div>

        <label className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-bold text-slate-800 cursor-pointer">
          <input
            type="checkbox"
            checked={draft.enabled}
            onChange={(e) => updateDraft((prev) => ({ ...prev, enabled: e.target.checked }))}
          />
          Show Section on Storefront
        </label>
      </div>

      {/* Main Split: Left Editor, Right Live Admin Preview */}
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.05fr)_minmax(380px,0.95fr)] items-start">
        {/* LEFT: Card Configurator */}
        <div className="rounded-2xl border border-slate-200 bg-white p-4 space-y-4 shadow-2xs">
          {/* Selected Card Header Controls */}
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">
                {CARD_META.find((c) => c.key === selectedCard)?.num}{' '}
                {CARD_META.find((c) => c.key === selectedCard)?.label}
              </h3>
              <p className="text-xs text-slate-500">
                Customize copy, artwork, and linked store products for this card.
              </p>
            </div>
            <label className="inline-flex items-center gap-2 text-xs font-bold text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={draft[selectedCard].enabled}
                onChange={(e) =>
                  updateDraft((prev) => ({
                    ...prev,
                    [selectedCard]: { ...prev[selectedCard], enabled: e.target.checked },
                  }))
                }
              />
              Card Visible
            </label>
          </div>

          {/* Shared Title, Subtitle & Corner Badge */}
          <div className="grid gap-3 sm:grid-cols-3">
            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">Card Title</label>
              <input
                type="text"
                className={inputClass}
                value={draft[selectedCard].title}
                onChange={(e) =>
                  updateDraft((prev) => ({
                    ...prev,
                    [selectedCard]: { ...prev[selectedCard], title: e.target.value },
                  }))
                }
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">
                Card Subtitle
              </label>
              <input
                type="text"
                className={inputClass}
                value={draft[selectedCard].subtitle}
                onChange={(e) =>
                  updateDraft((prev) => ({
                    ...prev,
                    [selectedCard]: { ...prev[selectedCard], subtitle: e.target.value },
                  }))
                }
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">
                Corner Badge Text
              </label>
              <input
                type="text"
                className={inputClass}
                value={draft[selectedCard].badge ?? ''}
                placeholder="e.g. 01, BEST VALUE, FRESH"
                onChange={(e) =>
                  updateDraft((prev) => ({
                    ...prev,
                    [selectedCard]: { ...prev[selectedCard], badge: e.target.value },
                  }))
                }
              />
            </div>
          </div>

          {/* Visual Theme & Color Design Studio */}
          <div className="rounded-xl border border-indigo-100 bg-indigo-50/40 p-3 space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                <Sparkles className="h-3.5 w-3.5 text-indigo-600" />
                Visual Design & Theme Palette
              </span>
              <div className="flex items-center gap-1.5">
                {[
                  { name: 'Emerald', bg: '#E2EFFF', border: '#CFE4FD', accent: '#15803D', text: '#0F172A' },
                  { name: 'Sky Blue', bg: '#F4F9FD', border: '#E0F2FE', accent: '#0284C7', text: '#0F172A' },
                  { name: 'Honey', bg: '#FEFCE8', border: '#FEF08A', accent: '#D97706', text: '#78350F' },
                  { name: 'Wine', bg: '#FDF2F4', border: '#FCE7F3', accent: '#BE185D', text: '#831843' },
                  { name: 'Dark', bg: '#251640', border: '#382458', accent: '#8B5CF6', text: '#FFFFFF' },
                  { name: 'Sunrise', bg: '#FFF8F0', border: '#FEE6D1', accent: '#EA580C', text: '#9A3412' },
                ].map((preset) => (
                  <button
                    key={preset.name}
                    type="button"
                    title={`Apply ${preset.name} theme`}
                    onClick={() =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: {
                          ...prev[selectedCard],
                          backgroundColor: preset.bg,
                          borderColor: preset.border,
                          accentColor: preset.accent,
                          textColor: preset.text,
                        },
                      }))
                    }
                    className="flex items-center gap-1 rounded-full border border-slate-300 bg-white px-2 py-0.5 text-[10px] font-bold text-slate-700 hover:bg-slate-100 cursor-pointer shadow-xs"
                  >
                    <span className="h-2 w-2 rounded-full border border-black/10" style={{ backgroundColor: preset.bg }} />
                    {preset.name}
                  </button>
                ))}
              </div>
            </div>

            <div className="grid gap-3 grid-cols-2 sm:grid-cols-4 pt-1">
              {/* Background Color */}
              <div>
                <label className="block text-[10px] font-semibold text-slate-700 mb-1">
                  Card Background
                </label>
                <div className="flex items-center gap-1.5">
                  <input
                    type="color"
                    className="h-7 w-7 rounded border border-slate-300 p-0 cursor-pointer shrink-0"
                    value={draft[selectedCard].backgroundColor || '#F8FAFC'}
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], backgroundColor: e.target.value },
                      }))
                    }
                  />
                  <input
                    type="text"
                    className="w-full text-xs font-mono rounded border border-slate-300 px-2 py-1 bg-white uppercase"
                    value={draft[selectedCard].backgroundColor ?? ''}
                    placeholder="#E2EFFF"
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], backgroundColor: e.target.value },
                      }))
                    }
                  />
                </div>
              </div>

              {/* Border Color */}
              <div>
                <label className="block text-[10px] font-semibold text-slate-700 mb-1">
                  Card Border
                </label>
                <div className="flex items-center gap-1.5">
                  <input
                    type="color"
                    className="h-7 w-7 rounded border border-slate-300 p-0 cursor-pointer shrink-0"
                    value={draft[selectedCard].borderColor || '#E2E8F0'}
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], borderColor: e.target.value },
                      }))
                    }
                  />
                  <input
                    type="text"
                    className="w-full text-xs font-mono rounded border border-slate-300 px-2 py-1 bg-white uppercase"
                    value={draft[selectedCard].borderColor ?? ''}
                    placeholder="#CFE4FD"
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], borderColor: e.target.value },
                      }))
                    }
                  />
                </div>
              </div>

              {/* Accent Color */}
              <div>
                <label className="block text-[10px] font-semibold text-slate-700 mb-1">
                  Accent / CTA Color
                </label>
                <div className="flex items-center gap-1.5">
                  <input
                    type="color"
                    className="h-7 w-7 rounded border border-slate-300 p-0 cursor-pointer shrink-0"
                    value={draft[selectedCard].accentColor || '#15803D'}
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], accentColor: e.target.value },
                      }))
                    }
                  />
                  <input
                    type="text"
                    className="w-full text-xs font-mono rounded border border-slate-300 px-2 py-1 bg-white uppercase"
                    value={draft[selectedCard].accentColor ?? ''}
                    placeholder="#15803D"
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], accentColor: e.target.value },
                      }))
                    }
                  />
                </div>
              </div>

              {/* Text Color */}
              <div>
                <label className="block text-[10px] font-semibold text-slate-700 mb-1">
                  Primary Text Color
                </label>
                <div className="flex items-center gap-1.5">
                  <input
                    type="color"
                    className="h-7 w-7 rounded border border-slate-300 p-0 cursor-pointer shrink-0"
                    value={draft[selectedCard].textColor || '#0F172A'}
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], textColor: e.target.value },
                      }))
                    }
                  />
                  <input
                    type="text"
                    className="w-full text-xs font-mono rounded border border-slate-300 px-2 py-1 bg-white uppercase"
                    value={draft[selectedCard].textColor ?? ''}
                    placeholder="#0F172A"
                    onChange={(e) =>
                      updateDraft((prev) => ({
                        ...prev,
                        [selectedCard]: { ...prev[selectedCard], textColor: e.target.value },
                      }))
                    }
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Visibility Rules, Scheduling & Thresholds */}
          <div className="rounded-xl border border-slate-200 bg-slate-50/70 p-3 space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                <Clock className="h-3.5 w-3.5 text-slate-500" />
                Visibility Rules, Automated Schedule & Inventory Thresholds
              </span>
              <span
                className={cn(
                  'rounded-full px-2 py-0.5 text-[10px] font-bold',
                  cardVisibilityStatus.isVisible
                    ? 'bg-emerald-100 text-emerald-800'
                    : 'bg-rose-100 text-rose-800'
                )}
              >
                {cardVisibilityStatus.isVisible
                  ? '🟢 Live on Storefront'
                  : `⚪ Auto-Hidden: ${cardVisibilityStatus.reason}`}
              </span>
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              {/* Display Sequence */}
              <div>
                <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                  Display Sequence / Rank
                </label>
                <input
                  type="number"
                  min="0"
                  max="99"
                  className={inputClass}
                  value={draft[selectedCard].sortOrder ?? 0}
                  onChange={(e) =>
                    updateDraft((prev) => ({
                      ...prev,
                      [selectedCard]: {
                        ...prev[selectedCard],
                        sortOrder: parseInt(e.target.value, 10) || 0,
                      },
                    }))
                  }
                />
              </div>

              {/* Min in-stock items */}
              <div>
                <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                  Min In-Stock Items
                </label>
                <input
                  type="number"
                  min="0"
                  max="10"
                  className={inputClass}
                  value={draft[selectedCard].minInStockItems ?? 1}
                  onChange={(e) =>
                    updateDraft((prev) => ({
                      ...prev,
                      [selectedCard]: {
                        ...prev[selectedCard],
                        minInStockItems: parseInt(e.target.value, 10) || 0,
                      },
                    }))
                  }
                />
                <span className="text-[10px] text-slate-500">Auto-hide if stock drops below</span>
              </div>

              {/* Target Darkstore */}
              <div>
                <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                  Target Darkstore / Hub
                </label>
                <select
                  className={inputClass}
                  value={
                    draft[selectedCard].targetHubs?.includes('hub-209206') &&
                    !draft[selectedCard].targetHubs?.includes('all')
                      ? 'hub-209206'
                      : 'all'
                  }
                  onChange={(e) =>
                    updateDraft((prev) => ({
                      ...prev,
                      [selectedCard]: {
                        ...prev[selectedCard],
                        targetHubs: e.target.value === 'all' ? ['all'] : [e.target.value],
                      },
                    }))
                  }
                >
                  <option value="all">All Hubs (Global)</option>
                  <option value="hub-209206">Ghatampur Hub Only (hub-209206)</option>
                </select>
              </div>
            </div>

            {/* Automated Schedule & Dayparting */}
            <div className="pt-2 border-t border-slate-200/80 space-y-2">
              <label className="inline-flex items-center gap-2 text-xs font-semibold text-slate-800 cursor-pointer">
                <input
                  type="checkbox"
                  checked={draft[selectedCard].scheduleEnabled ?? false}
                  onChange={(e) =>
                    updateDraft((prev) => ({
                      ...prev,
                      [selectedCard]: {
                        ...prev[selectedCard],
                        scheduleEnabled: e.target.checked,
                      },
                    }))
                  }
                />
                Enable Date & Time Window (Auto-show / Auto-hide)
              </label>

              {draft[selectedCard].scheduleEnabled && (
                <div className="grid gap-2 sm:grid-cols-3 pt-1">
                  <div>
                    <label className="block text-[10px] font-medium text-slate-600 mb-0.5">
                      Start Date & Time (IST)
                    </label>
                    <input
                      type="datetime-local"
                      className={inputClass}
                      value={draft[selectedCard].startDate?.slice(0, 16) ?? ''}
                      onChange={(e) =>
                        updateDraft((prev) => ({
                          ...prev,
                          [selectedCard]: {
                            ...prev[selectedCard],
                            startDate: e.target.value ? new Date(e.target.value).toISOString() : null,
                          },
                        }))
                      }
                    />
                  </div>
                  <div>
                    <label className="block text-[10px] font-medium text-slate-600 mb-0.5">
                      End Date & Time (IST)
                    </label>
                    <input
                      type="datetime-local"
                      className={inputClass}
                      value={draft[selectedCard].endDate?.slice(0, 16) ?? ''}
                      onChange={(e) =>
                        updateDraft((prev) => ({
                          ...prev,
                          [selectedCard]: {
                            ...prev[selectedCard],
                            endDate: e.target.value ? new Date(e.target.value).toISOString() : null,
                          },
                        }))
                      }
                    />
                  </div>
                  <div>
                    <label className="block text-[10px] font-medium text-slate-600 mb-0.5">
                      Dayparting / Slot
                    </label>
                    <select
                      className={inputClass}
                      value={draft[selectedCard].timeSlot ?? 'ALL_DAY'}
                      onChange={(e) =>
                        updateDraft((prev) => ({
                          ...prev,
                          [selectedCard]: {
                            ...prev[selectedCard],
                            timeSlot: e.target.value as BentoTimeSlot,
                          },
                        }))
                      }
                    >
                      <option value="ALL_DAY">24/7 (All Day)</option>
                      <option value="MORNING">Morning (06:00 - 11:30 AM)</option>
                      <option value="AFTERNOON">Afternoon (11:30 AM - 05:00 PM)</option>
                      <option value="EVENING">Evening (05:00 - 10:00 PM)</option>
                      <option value="NIGHT">Night (10:00 PM - 06:00 AM)</option>
                    </select>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* 01 FRESH MARKET */}
          {selectedCard === 'freshMarket' && (
            <div className="space-y-4">
              <BentoImageInput
                label="Header basket artwork"
                value={draft.freshMarket.headerImage}
                onChange={(headerImage) =>
                  updateDraft((prev) => ({
                    ...prev,
                    freshMarket: { ...prev.freshMarket, headerImage },
                  }))
                }
                onUpload={onUpload}
              />

              <div className="space-y-3 border-t border-slate-100 pt-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                    Category Pills & Product Slots
                  </span>
                  <div className="flex flex-wrap gap-1.5">
                    {draft.freshMarket.tabs.map((tab) => (
                      <button
                        key={tab.id}
                        type="button"
                        onClick={() => setSelectedFreshTabId(tab.id)}
                        className={cn(
                          'rounded-full px-3 py-1 text-xs font-bold cursor-pointer',
                          currentFreshTab.id === tab.id
                            ? 'bg-emerald-700 text-white'
                            : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                        )}
                      >
                        {tab.icon} {tab.label}
                      </button>
                    ))}
                  </div>
                </div>

                {currentFreshTab && (
                  <div className="space-y-3">
                    <div className="grid gap-2 sm:grid-cols-2">
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-600 mb-0.5">
                          Pill Label
                        </label>
                        <input
                          type="text"
                          className={inputClass}
                          value={currentFreshTab.label}
                          onChange={(e) =>
                            updateDraft((prev) => ({
                              ...prev,
                              freshMarket: {
                                ...prev.freshMarket,
                                tabs: prev.freshMarket.tabs.map((t) =>
                                  t.id === currentFreshTab.id ? { ...t, label: e.target.value } : t
                                ),
                              },
                            }))
                          }
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-600 mb-0.5">
                          Pill Emoji / Icon
                        </label>
                        <input
                          type="text"
                          className={inputClass}
                          value={currentFreshTab.icon}
                          onChange={(e) =>
                            updateDraft((prev) => ({
                              ...prev,
                              freshMarket: {
                                ...prev.freshMarket,
                                tabs: prev.freshMarket.tabs.map((t) =>
                                  t.id === currentFreshTab.id ? { ...t, icon: e.target.value } : t
                                ),
                              },
                            }))
                          }
                        />
                      </div>
                    </div>

                    {currentFreshTab.items.map((slot, idx) => (
                      <BentoSlotEditor
                        key={slot.id}
                        slot={slot}
                        indexLabel={`${currentFreshTab.label} Product #${idx + 1}`}
                        products={products}
                        canRemove={currentFreshTab.items.length > 1}
                        onRemove={() =>
                          updateDraft((prev) => ({
                            ...prev,
                            freshMarket: {
                              ...prev.freshMarket,
                              tabs: prev.freshMarket.tabs.map((t) =>
                                t.id === currentFreshTab.id
                                  ? { ...t, items: t.items.filter((_, i) => i !== idx) }
                                  : t
                              ),
                            },
                          }))
                        }
                        onChange={(patch) =>
                          updateDraft((prev) => ({
                            ...prev,
                            freshMarket: {
                              ...prev.freshMarket,
                              tabs: prev.freshMarket.tabs.map((t) =>
                                t.id === currentFreshTab.id
                                  ? {
                                      ...t,
                                      items: t.items.map((it, i) =>
                                        i === idx ? { ...it, ...patch } : it
                                      ),
                                    }
                                  : t
                              ),
                            },
                          }))
                        }
                      />
                    ))}

                    {currentFreshTab.items.length < 4 && (
                      <button
                        type="button"
                        className={buttonClass}
                        onClick={() =>
                          updateDraft((prev) => ({
                            ...prev,
                            freshMarket: {
                              ...prev.freshMarket,
                              tabs: prev.freshMarket.tabs.map((t) =>
                                t.id === currentFreshTab.id
                                  ? {
                                      ...t,
                                      items: [...t.items, newSlotTemplate(currentFreshTab.id)],
                                    }
                                  : t
                              ),
                            },
                          }))
                        }
                      >
                        <Plus className="h-3.5 w-3.5" /> Add Product to {currentFreshTab.label}
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 02 DAILY RESTOCK */}
          {selectedCard === 'dailyRestock' && (
            <div className="space-y-4">
              <BentoImageInput
                label="Header icon / illustration"
                value={draft.dailyRestock.headerImage}
                onChange={(headerImage) =>
                  updateDraft((prev) => ({
                    ...prev,
                    dailyRestock: { ...prev.dailyRestock, headerImage },
                  }))
                }
                onUpload={onUpload}
              />
              <div className="space-y-3 border-t border-slate-100 pt-3">
                {draft.dailyRestock.items.map((slot, idx) => (
                  <BentoSlotEditor
                    key={slot.id}
                    slot={slot}
                    indexLabel={`Stepper Row #${idx + 1}`}
                    products={products}
                    canRemove={draft.dailyRestock.items.length > 1}
                    onRemove={() =>
                      updateDraft((prev) => ({
                        ...prev,
                        dailyRestock: {
                          ...prev.dailyRestock,
                          items: prev.dailyRestock.items.filter((_, i) => i !== idx),
                        },
                      }))
                    }
                    onChange={(patch) =>
                      updateDraft((prev) => ({
                        ...prev,
                        dailyRestock: {
                          ...prev.dailyRestock,
                          items: prev.dailyRestock.items.map((it, i) =>
                            i === idx ? { ...it, ...patch } : it
                          ),
                        },
                      }))
                    }
                  />
                ))}
                {draft.dailyRestock.items.length < 6 && (
                  <button
                    type="button"
                    className={buttonClass}
                    onClick={() =>
                      updateDraft((prev) => ({
                        ...prev,
                        dailyRestock: {
                          ...prev.dailyRestock,
                          items: [...prev.dailyRestock.items, newSlotTemplate('restock')],
                        },
                      }))
                    }
                  >
                    <Plus className="h-3.5 w-3.5" /> Add Restock Item
                  </button>
                )}
              </div>
            </div>
          )}

          {/* 03 VALUE PICKS */}
          {selectedCard === 'valuePicks' && (
            <div className="space-y-3 border-t border-slate-100 pt-3">
              {draft.valuePicks.items.map((slot, idx) => (
                <BentoSlotEditor
                  key={slot.id}
                  slot={slot}
                  indexLabel={`Pack Option #${idx + 1}`}
                  products={products}
                  showBadgeField
                  showPerUnitField
                  onChange={(patch) =>
                    updateDraft((prev) => ({
                      ...prev,
                      valuePicks: {
                        ...prev.valuePicks,
                        items: prev.valuePicks.items.map((it, i) =>
                          i === idx ? { ...it, ...patch } : it
                        ),
                      },
                    }))
                  }
                />
              ))}
            </div>
          )}

          {/* 04 GIFTING BOUTIQUE */}
          {selectedCard === 'giftingBoutique' && (
            <div className="space-y-4 border-t border-slate-100 pt-3">
              <BentoSlotEditor
                slot={draft.giftingBoutique.heroItem}
                indexLabel="Featured Hero Gift (Left Photo)"
                products={products}
                onChange={(patch) =>
                  updateDraft((prev) => ({
                    ...prev,
                    giftingBoutique: {
                      ...prev.giftingBoutique,
                      heroItem: { ...prev.giftingBoutique.heroItem, ...patch },
                    },
                  }))
                }
              />

              <BentoSlotEditor
                slot={draft.giftingBoutique.miniItem}
                indexLabel="Mini Add-On Gift (Bottom Right)"
                products={products}
                onChange={(patch) =>
                  updateDraft((prev) => ({
                    ...prev,
                    giftingBoutique: {
                      ...prev.giftingBoutique,
                      miniItem: { ...prev.giftingBoutique.miniItem, ...patch },
                    },
                  }))
                }
              />

              <div className="space-y-2 rounded-xl border border-slate-200 bg-slate-50 p-3">
                <p className="text-xs font-bold text-slate-700">Occasion Chips</p>
                {draft.giftingBoutique.occasions.map((occ, idx) => (
                  <div key={occ.id} className="flex items-center gap-2">
                    <input
                      type="text"
                      className="w-16 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-center"
                      value={occ.icon}
                      onChange={(e) =>
                        updateDraft((prev) => ({
                          ...prev,
                          giftingBoutique: {
                            ...prev.giftingBoutique,
                            occasions: prev.giftingBoutique.occasions.map((o, i) =>
                              i === idx ? { ...o, icon: e.target.value } : o
                            ),
                          },
                        }))
                      }
                    />
                    <input
                      type="text"
                      className={inputClass}
                      value={occ.label}
                      onChange={(e) =>
                        updateDraft((prev) => ({
                          ...prev,
                          giftingBoutique: {
                            ...prev.giftingBoutique,
                            occasions: prev.giftingBoutique.occasions.map((o, i) =>
                              i === idx ? { ...o, label: e.target.value } : o
                            ),
                          },
                        }))
                      }
                    />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 05 MOVIE NIGHT */}
          {selectedCard === 'movieNight' && (
            <div className="space-y-4">
              <BentoImageInput
                label="Cinema scene banner image"
                value={draft.movieNight.heroImage}
                onChange={(heroImage) =>
                  updateDraft((prev) => ({
                    ...prev,
                    movieNight: { ...prev.movieNight, heroImage },
                  }))
                }
                onUpload={onUpload}
              />
              <div className="space-y-3 border-t border-slate-100 pt-3">
                {draft.movieNight.items.map((slot, idx) => (
                  <BentoSlotEditor
                    key={slot.id}
                    slot={slot}
                    indexLabel={`Snack Slot #${idx + 1}`}
                    products={products}
                    onChange={(patch) =>
                      updateDraft((prev) => ({
                        ...prev,
                        movieNight: {
                          ...prev.movieNight,
                          items: prev.movieNight.items.map((it, i) =>
                            i === idx ? { ...it, ...patch } : it
                          ),
                        },
                      }))
                    }
                  />
                ))}
              </div>
            </div>
          )}

          {/* 06 BREAKFAST CLUB */}
          {selectedCard === 'breakfastClub' && (
            <div className="space-y-4">
              <BentoImageInput
                label="Side breakfast photo"
                value={draft.breakfastClub.heroImage}
                onChange={(heroImage) =>
                  updateDraft((prev) => ({
                    ...prev,
                    breakfastClub: { ...prev.breakfastClub, heroImage },
                  }))
                }
                onUpload={onUpload}
              />
              <div className="space-y-3 border-t border-slate-100 pt-3">
                {draft.breakfastClub.items.map((slot, idx) => (
                  <BentoSlotEditor
                    key={slot.id}
                    slot={slot}
                    indexLabel={`Checklist Item #${idx + 1}`}
                    products={products}
                    showCheckedDefault
                    canRemove={draft.breakfastClub.items.length > 1}
                    onRemove={() =>
                      updateDraft((prev) => ({
                        ...prev,
                        breakfastClub: {
                          ...prev.breakfastClub,
                          items: prev.breakfastClub.items.filter((_, i) => i !== idx),
                        },
                      }))
                    }
                    onChange={(patch) =>
                      updateDraft((prev) => ({
                        ...prev,
                        breakfastClub: {
                          ...prev.breakfastClub,
                          items: prev.breakfastClub.items.map((it, i) =>
                            i === idx ? { ...it, ...patch } : it
                          ),
                        },
                      }))
                    }
                  />
                ))}
                {draft.breakfastClub.items.length < 5 && (
                  <button
                    type="button"
                    className={buttonClass}
                    onClick={() =>
                      updateDraft((prev) => ({
                        ...prev,
                        breakfastClub: {
                          ...prev.breakfastClub,
                          items: [...prev.breakfastClub.items, newSlotTemplate('breakfast')],
                        },
                      }))
                    }
                  >
                    <Plus className="h-3.5 w-3.5" /> Add Breakfast Item
                  </button>
                )}
              </div>
            </div>
          )}
        </div>

        {/* RIGHT: Interactive Live Admin Preview */}
        <aside className="rounded-2xl border border-slate-200 bg-white p-4 shadow-2xs xl:sticky xl:top-20 space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-3">
            <div>
              <h3 className="text-sm font-extrabold text-slate-900 flex items-center gap-1.5">
                <Eye className="h-4 w-4 text-primary" />
                Live Admin Preview
              </h3>
              <p className="text-[11px] text-slate-500">
                Interactive preview with live store prices & stock.
              </p>
            </div>
            <div className="flex items-center gap-1 rounded-lg bg-slate-100 p-1">
              <button
                type="button"
                onClick={() => setPreviewModeView('single')}
                className={cn(
                  'rounded-md px-2 py-1 text-[11px] font-bold cursor-pointer',
                  previewModeView === 'single'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600'
                )}
              >
                Selected Card
              </button>
              <button
                type="button"
                onClick={() => setPreviewModeView('all-mobile')}
                className={cn(
                  'inline-flex items-center gap-1 rounded-md px-2 py-1 text-[11px] font-bold cursor-pointer',
                  previewModeView === 'all-mobile'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600'
                )}
              >
                <Smartphone className="h-3 w-3" /> Mobile (6)
              </button>
              <button
                type="button"
                onClick={() => setPreviewModeView('all-desktop')}
                className={cn(
                  'inline-flex items-center gap-1 rounded-md px-2 py-1 text-[11px] font-bold cursor-pointer',
                  previewModeView === 'all-desktop'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600'
                )}
              >
                <Monitor className="h-3 w-3" /> All 6 Grid
              </button>
            </div>
          </div>

          <div
            className={cn(
              'rounded-xl bg-[#FDFBF7] border border-slate-100 p-2 overflow-y-auto',
              previewModeView === 'all-mobile'
                ? 'max-w-[400px] mx-auto max-h-[75vh]'
                : 'max-h-[78vh]'
            )}
            data-testid="campaign-bento-preview"
          >
            <InteractiveCampaignBento
              config={draft}
              products={products}
              storeId={scope}
              previewMode
              focusedCard={previewModeView === 'single' ? selectedCard : 'all'}
            />
          </div>

          <p className="text-[11px] text-slate-500">
            Changes update immediately in Preview. Real customer cart is isolated while in Admin
            Preview mode.
          </p>
        </aside>
      </div>
    </div>
  )
}
