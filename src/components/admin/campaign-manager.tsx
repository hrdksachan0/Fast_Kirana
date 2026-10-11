'use client'

import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { ArrowDown, ArrowUp, Loader2, Plus, Save, Trash2, Upload } from 'lucide-react'
import { apiUrl } from '@/lib/api-url'
import { campaignImageSchema, campaignSchema, type CampaignConfig } from '@/lib/campaign-config'
import {
  campaignLayouts,
  campaignTemplateGroups,
  campaignTemplates,
  createCampaignFromTemplate,
} from '@/lib/campaign-templates'
import { navratriAsset, navratriData } from '@/components/home/navratri/data'
import { NavratriSection } from '@/components/home/navratri/navratri-section'
import { NavratriSearch } from '@/components/home/navratri/navratri-search'
import type { Product } from '@/types'

type Collection = 'headers' | 'products' | 'categories' | 'tabs' | 'destinations'
const colourLabels: Record<keyof CampaignConfig['appearance'], string> = {
  background: 'Section background',
  card: 'Card background',
  text: 'Primary text',
  smallText: 'Small text',
  headerText: 'Header text',
  headerOutline: 'Header outline',
  underline: 'Selected tab underline',
  tabSurface: 'Tab artwork background',
}
const timingLabels: Record<keyof CampaignConfig['timings'], string> = {
  headerMs: 'Header interval',
  productMs: 'Product interval',
  searchMs: 'Search suggestion interval',
  crossfadeMs: 'Fade duration',
}
const inputClass =
  'w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-text-primary outline-none focus:border-primary focus:ring-2 focus:ring-primary/15'
const buttonClass =
  'inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-border bg-surface px-3 py-2 text-sm font-semibold text-text-primary disabled:cursor-not-allowed disabled:opacity-50'

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="text-text-secondary flex min-w-0 flex-col gap-1.5 text-xs font-semibold">
      <span>{label}</span>
      {children}
    </label>
  )
}
function TextField({
  label,
  value,
  onChange,
  type = 'text',
}: {
  label: string
  value: string | number
  onChange: (value: string) => void
  type?: string
}) {
  return (
    <Field label={label}>
      <input
        aria-label={label}
        className={inputClass}
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </Field>
  )
}
function DelimitedField({
  label,
  values,
  delimiter,
  onChange,
}: {
  label: string
  values: string[]
  delimiter: ',' | '\n'
  onChange: (values: string[]) => void
}) {
  const joiner = delimiter === ',' ? ', ' : '\n'
  const [raw, setRaw] = useState(() => values.join(joiner))
  const emitted = useRef<string[] | null>(null)
  useEffect(() => {
    if (values !== emitted.current) setRaw(values.join(joiner))
    emitted.current = null
  }, [values, joiner])
  const parse = (value: string) =>
    value
      .split(delimiter)
      .map((item) => item.trim())
      .filter(Boolean)
  const edit = (value: string) => {
    setRaw(value)
    const parsed = parse(value)
    emitted.current = parsed
    onChange(parsed)
  }
  return (
    <Field label={label}>
      {delimiter === '\n' ? (
        <textarea
          aria-label={label}
          className={inputClass}
          rows={5}
          value={raw}
          onChange={(event) => edit(event.target.value)}
          onBlur={() => setRaw(parse(raw).join(joiner))}
        />
      ) : (
        <input
          aria-label={label}
          className={inputClass}
          value={raw}
          onChange={(event) => edit(event.target.value)}
          onBlur={() => setRaw(parse(raw).join(joiner))}
        />
      )}
    </Field>
  )
}
function Section({
  title,
  children,
  open = false,
}: {
  title: string
  children: ReactNode
  open?: boolean
}) {
  return (
    <details open={open} className="border-border bg-surface rounded-xl border">
      <summary className="text-text-primary cursor-pointer px-4 py-3 text-sm font-bold">
        {title}
      </summary>
      <div className="border-border space-y-4 border-t p-4">{children}</div>
    </details>
  )
}
function RowActions({
  title,
  index,
  count,
  onMove,
  onRemove,
}: {
  title: string
  index: number
  count: number
  onMove: (direction: number) => void
  onRemove?: () => void
}) {
  return (
    <div className="flex items-center gap-1">
      <span className="mr-auto text-sm font-bold">{title}</span>
      <button
        type="button"
        className={buttonClass}
        aria-label={`Move ${title} up`}
        disabled={index === 0}
        onClick={() => onMove(-1)}
      >
        <ArrowUp size={15} />
      </button>
      <button
        type="button"
        className={buttonClass}
        aria-label={`Move ${title} down`}
        disabled={index === count - 1}
        onClick={() => onMove(1)}
      >
        <ArrowDown size={15} />
      </button>
      {onRemove && (
        <button
          type="button"
          className={buttonClass}
          aria-label={`Remove ${title}`}
          disabled={count <= 1}
          onClick={onRemove}
        >
          <Trash2 size={15} />
        </button>
      )}
    </div>
  )
}
function ImageField({
  label,
  value,
  onChange,
  onUpload,
}: {
  label: string
  value: string | null
  onChange: (value: string | null) => void
  onUpload: (file: File, callback: (url: string) => void) => Promise<void>
}) {
  const [uploading, setUploading] = useState(false)
  const [failed, setFailed] = useState(false)
  const valid = value && campaignImageSchema.safeParse(value).success
  return (
    <div className="space-y-2">
      <TextField
        label={label}
        value={value ?? ''}
        onChange={(value) => {
          setFailed(false)
          onChange(value || null)
        }}
      />
      <div className="flex items-center gap-3">
        {valid && !failed && (
          <img
            src={navratriAsset(value)}
            alt="Image preview"
            width={56}
            height={56}
            className="h-14 w-14 rounded-lg bg-orange-50 object-contain"
            onError={() => setFailed(true)}
          />
        )}
        {failed && (
          <span className="text-xs text-red-700">
            Couldn’t load image. Check the URL or upload a file.
          </span>
        )}
        <label className={`${buttonClass} cursor-pointer`}>
          <Upload size={15} />
          {uploading ? 'Uploading…' : 'Upload image'}
          <input
            type="file"
            aria-label={`Upload ${label}`}
            className="sr-only"
            accept="image/png,image/jpeg,image/webp,image/svg+xml,image/avif"
            disabled={uploading}
            onChange={async (event) => {
              const file = event.target.files?.[0]
              if (!file) return
              setUploading(true)
              try {
                await onUpload(file, (url) => {
                  setFailed(false)
                  onChange(url)
                })
              } finally {
                setUploading(false)
                event.target.value = ''
              }
            }}
          />
        </label>
      </div>
    </div>
  )
}

export function CampaignManager({
  storeId,
  onUpload,
  authHeaders = {},
}: {
  storeId?: string
  onUpload: (file: File, callback: (url: string) => void) => Promise<void>
  authHeaders?: Record<string, string>
}) {
  const [draft, setDraft] = useState<CampaignConfig>(() => structuredClone(navratriData))
  const [published, setPublished] = useState<CampaignConfig | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadFailed, setLoadFailed] = useState(false)
  const [saving, setSaving] = useState(false)
  const [feedback, setFeedback] = useState('')
  const [dirty, setDirty] = useState(false)
  const [attempted, setAttempted] = useState(false)
  const [playPreview, setPlayPreview] = useState(false)
  const [templateId, setTemplateId] = useState('navratri')
  const [confirmTemplate, setConfirmTemplate] = useState(false)
  const [previewRevision, setPreviewRevision] = useState(0)
  const [reload, setReload] = useState(0)
  const [catalogue, setCatalogue] = useState<{ scope?: string; products: Product[] }>({
    products: [],
  })
  const [catalogueLoading, setCatalogueLoading] = useState(true)
  const [catalogueError, setCatalogueError] = useState(false)
  const [catalogueReload, setCatalogueReload] = useState(0)
  const saveVersion = useRef(0)
  const valid = useMemo(() => campaignSchema.safeParse(draft), [draft])
  const scope = storeId && storeId !== 'all' ? storeId : undefined
  const headerKey = JSON.stringify(authHeaders)
  const products = catalogue.scope === scope ? catalogue.products : []
  useEffect(() => {
    const controller = new AbortController()
    setCatalogueLoading(true)
    setCatalogueError(false)
    setCatalogue({ scope, products: [] })
    const query = new URLSearchParams({ limit: '1000', type: 'grocery' })
    if (scope) query.set('storeId', scope)
    fetch(`${apiUrl()}/api/admin/products?${query}`, {
      signal: controller.signal,
      cache: 'no-store',
      headers: JSON.parse(headerKey),
    })
      .then(async (response) => {
        if (!response.ok) throw new Error('Catalogue unavailable')
        const body = await response.json()
        const rows = Array.isArray(body) ? body : body.products
        if (!Array.isArray(rows)) throw new Error('Catalogue unavailable')
        if (!controller.signal.aborted) setCatalogue({ scope, products: rows })
      })
      .catch(() => {
        if (!controller.signal.aborted) setCatalogueError(true)
      })
      .finally(() => {
        if (!controller.signal.aborted) setCatalogueLoading(false)
      })
    return () => controller.abort()
  }, [scope, headerKey, catalogueReload])
  useEffect(() => {
    const controller = new AbortController()
    saveVersion.current += 1
    setSaving(false)
    setLoading(true)
    setLoadFailed(false)
    setFeedback('')
    setAttempted(false)
    setDirty(false)
    setConfirmTemplate(false)
    setTemplateId('navratri')
    setPlayPreview(false)
    const query = scope ? `?storeId=${encodeURIComponent(scope)}` : ''
    fetch(`${apiUrl()}/api/admin/campaign${query}`, {
      signal: controller.signal,
      cache: 'no-store',
      headers: JSON.parse(headerKey),
    })
      .then(async (response) => {
        const body = await response.json()
        if (!response.ok) throw new Error(body.error || body.detail || 'Unable to load campaign')
        return body
      })
      .then((body) => {
        if (controller.signal.aborted) return
        const saved = body.draft ?? body.published ?? navratriData
        setDraft(campaignSchema.parse(saved))
        setPreviewRevision((value) => value + 1)
        setPublished(body.published ? campaignSchema.parse(body.published) : null)
      })
      .catch((error) => {
        if (!controller.signal.aborted) {
          setLoadFailed(true)
          setFeedback(error.message || 'Unable to load campaign')
        }
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false)
      })
    return () => {
      controller.abort()
      saveVersion.current += 1
    }
  }, [scope, headerKey, reload])
  const change = (update: (value: CampaignConfig) => CampaignConfig) => {
    setDraft(update)
    setDirty(true)
    setFeedback('')
    setConfirmTemplate(false)
  }
  const chosenTemplate =
    campaignTemplates.find((entry) => entry.id === templateId) ?? campaignTemplates[0]
  const loadTemplate = () => {
    change(() => createCampaignFromTemplate(chosenTemplate.id))
    setAttempted(false)
    setPlayPreview(false)
    setPreviewRevision((value) => value + 1)
    setFeedback(
      `${chosenTemplate.name} template loaded. Edit it, then save a draft or publish when ready.`
    )
  }
  const patchRow = <Key extends Collection>(
    key: Key,
    index: number,
    patch: Partial<CampaignConfig[Key][number]>
  ) =>
    change((previous) => ({
      ...previous,
      [key]: previous[key].map((item, i) => (i === index ? { ...item, ...patch } : item)),
    }))
  const move = <Key extends Collection>(key: Key, index: number, direction: number) =>
    change((previous) => {
      const rows = [...previous[key]]
      ;[rows[index], rows[index + direction]] = [rows[index + direction], rows[index]]
      return { ...previous, [key]: rows }
    })
  const remove = (key: Collection, index: number) =>
    change((previous) => ({ ...previous, [key]: previous[key].filter((_, i) => i !== index) }))
  const uniqueId = (prefix: string) => `${prefix}-${crypto.randomUUID().slice(0, 8)}`
  const queryFor = (destinationId: string) =>
    draft.destinations.find((item) => item.id === destinationId)?.query ?? ''
  const setQuery = (destinationId: string, query: string) =>
    change((previous) => ({
      ...previous,
      destinations: previous.destinations.map((item) =>
        item.id === destinationId ? { ...item, query } : item
      ),
    }))
  const save = async (action: 'save-draft' | 'publish' | 'disable') => {
    setAttempted(true)
    if (!valid.success) {
      setFeedback('Fix the highlighted configuration errors before saving.')
      return
    }
    const version = ++saveVersion.current
    setSaving(true)
    setFeedback('')
    try {
      const response = await fetch(`${apiUrl()}/api/admin/campaign`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', ...authHeaders },
        body: JSON.stringify({ action, storeId: scope, campaign: valid.data }),
      })
      const body = await response.json()
      if (version !== saveVersion.current) return
      if (!response.ok) throw new Error(body.error || body.detail || 'Could not save campaign')
      if (action === 'publish') setPublished(valid.data)
      if (action === 'disable')
        setPublished((previous) => ({ ...(previous ?? valid.data), enabled: false }))
      if (action !== 'disable') setDirty(false)
      setFeedback(
        action === 'save-draft'
          ? 'Draft saved. Customers still see the published campaign.'
          : action === 'publish'
            ? 'Campaign published. Both apps will load this configuration.'
            : 'Campaign hidden. Your draft is retained.'
      )
    } catch (error) {
      if (version === saveVersion.current)
        setFeedback(error instanceof Error ? error.message : 'Could not save campaign')
    } finally {
      if (version === saveVersion.current) setSaving(false)
    }
  }
  const disableActions = loading || loadFailed || saving
  const preview = valid.success ? valid.data : navratriData
  return (
    <div className="space-y-5" data-testid="campaign-manager">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-text-primary text-xl font-bold">Campaign Manager</h2>
          <p className="text-text-secondary mt-1 text-sm">
            Edit one reusable shopping section for {scope ? 'this store' : 'all stores'}. Preview
            changes before publishing.
          </p>
          <p className="text-text-secondary mt-2 text-xs">
            {published?.enabled
              ? 'Published campaign is visible'
              : published
                ? 'Published campaign is hidden'
                : 'Using the bundled Navratri template'}
            {dirty ? ' · Unsaved changes' : ''}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className={buttonClass}
            disabled={disableActions}
            onClick={() => save('save-draft')}
          >
            <Save size={15} />
            Save Draft
          </button>
          <button
            type="button"
            className={`${buttonClass} border-primary! bg-primary! text-white!`}
            disabled={disableActions}
            onClick={() => save('publish')}
          >
            Publish
          </button>
          <button
            type="button"
            className={buttonClass}
            disabled={disableActions}
            onClick={() => save('disable')}
          >
            Hide Campaign
          </button>
        </div>
      </div>
      {loading && (
        <p role="status" className="flex items-center gap-2 text-sm">
          <Loader2 className="h-4 w-4 animate-spin" />
          Loading saved campaign…
        </p>
      )}
      {feedback && (
        <div role={loadFailed ? 'alert' : 'status'} className="bg-surface rounded-lg p-3 text-sm">
          {feedback}
          {loadFailed && (
            <button
              type="button"
              className={`${buttonClass} ml-3`}
              onClick={() => setReload((value) => value + 1)}
            >
              Retry
            </button>
          )}
        </div>
      )}
      {attempted && !valid.success && (
        <ul
          role="alert"
          className="list-inside list-disc rounded-lg bg-red-50 p-3 text-sm text-red-800"
        >
          {valid.error.issues.map((issue, i) => (
            <li key={i}>
              {issue.path.join(' → ')}: {issue.message}
            </li>
          ))}
        </ul>
      )}
      <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_420px]">
        <fieldset disabled={loading || loadFailed || saving} className="min-w-0 space-y-3">
          <Section title="Start with a campaign template" open>
            <div className="grid items-center gap-4 sm:grid-cols-[112px_minmax(0,1fr)]">
              <div
                className="flex h-28 items-center justify-center rounded-xl p-2"
                style={{ background: chosenTemplate.config.appearance.background }}
              >
                <img
                  src={navratriAsset(chosenTemplate.thumbnail)}
                  alt=""
                  className="h-full w-full object-contain"
                />
              </div>
              <div className="min-w-0 space-y-2">
                <Field label="Campaign template">
                  <select
                    aria-label="Campaign template"
                    className={inputClass}
                    value={templateId}
                    onChange={(event) => {
                      setTemplateId(event.target.value)
                      setConfirmTemplate(false)
                    }}
                  >
                    {campaignTemplateGroups.map((group) => (
                      <optgroup key={group} label={group}>
                        {campaignTemplates
                          .filter((entry) => entry.type === group)
                          .map((entry) => (
                            <option key={entry.id} value={entry.id}>
                              {entry.name}
                            </option>
                          ))}
                      </optgroup>
                    ))}
                  </select>
                </Field>
                <p className="text-text-secondary text-xs leading-relaxed">
                  {chosenTemplate.description}
                </p>
                <p className="text-text-secondary text-xs">
                  {
                    campaignLayouts.find((layout) => layout.id === chosenTemplate.config.layout)
                      ?.name
                  }{' '}
                  · Editable demo content
                </p>
                <button
                  type="button"
                  className={buttonClass}
                  onClick={() => (dirty ? setConfirmTemplate(true) : loadTemplate())}
                >
                  Load template
                </button>
              </div>
            </div>
            {confirmTemplate && (
              <div role="alert" className="border-border space-y-3 border-t pt-3">
                <p className="text-text-primary text-sm">
                  Loading {chosenTemplate.name} will replace your unsaved edits. The published
                  campaign will stay as it is.
                </p>
                <div className="flex flex-wrap gap-2">
                  <button type="button" className={buttonClass} onClick={loadTemplate}>
                    Replace current draft
                  </button>
                  <button
                    type="button"
                    className={buttonClass}
                    onClick={() => setConfirmTemplate(false)}
                  >
                    Cancel template change
                  </button>
                </div>
              </div>
            )}
            <p className="text-text-secondary text-xs">
              Loading a template only changes this editor. Save a draft to keep it, or publish to
              show it to customers.
            </p>
          </Section>
          <Section title="Campaign & labels" open>
            <Field label="Campaign layout">
              <select
                aria-label="Campaign layout"
                className={inputClass}
                value={draft.layout}
                onChange={(event) =>
                  change((previous) => ({
                    ...previous,
                    layout: event.target.value as CampaignConfig['layout'],
                  }))
                }
              >
                {campaignLayouts.map((layout) => (
                  <option key={layout.id} value={layout.id}>
                    {layout.name}
                  </option>
                ))}
              </select>
            </Field>
            <p className="text-text-secondary text-xs">
              {campaignLayouts.find((layout) => layout.id === draft.layout)?.description}
            </p>
            <div className="flex flex-wrap gap-5">
              {(['enabled', 'autoplay', 'demo'] as const).map((key) => (
                <label key={key} className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={draft[key]}
                    onChange={(event) =>
                      change((previous) => ({ ...previous, [key]: event.target.checked }))
                    }
                  />
                  {key === 'enabled'
                    ? 'Show campaign'
                    : key === 'autoplay'
                      ? 'Autoplay animations'
                      : 'Demo campaign (illustrative prices)'}
                </label>
              ))}
            </div>
            <p className="text-text-secondary text-xs">
              For a live campaign, link every promotional slot to a catalogue product. Its price,
              stock, name and image come from that store’s catalogue.
            </p>
            <div className="grid gap-3 sm:grid-cols-2">
              {Object.entries(draft.labels).map(([key, value]) => (
                <TextField
                  key={key}
                  label={
                    {
                      sectionLabel: 'Campaign name',
                      specialsHeading: 'Tall card heading',
                      curvedTabLabel: 'Curved tab label',
                      loadingText: 'Loading message',
                      emptyText: 'Empty collection message',
                      demoLabel: 'Demo price label',
                      resultsDemoLabel: 'Demo collection label',
                    }[key] ?? key
                  }
                  value={value}
                  onChange={(value) =>
                    change((previous) => ({
                      ...previous,
                      labels: { ...previous.labels, [key]: value },
                    }))
                  }
                />
              ))}
            </div>
          </Section>
          <Section title="Header slides">
            {draft.headers.map((slide, index) => (
              <div key={slide.id} className="border-border space-y-3 border-b pb-4 last:border-0">
                <RowActions
                  title={`Slide ${index + 1}`}
                  index={index}
                  count={draft.headers.length}
                  onMove={(direction) => move('headers', index, direction)}
                  onRemove={() => remove('headers', index)}
                />
                <div className="grid gap-3 sm:grid-cols-2">
                  <TextField
                    label={`Slide ${index + 1} title`}
                    value={slide.title}
                    onChange={(title) => patchRow('headers', index, { title })}
                  />
                  <Field label="Slide style">
                    <select
                      className={inputClass}
                      value={slide.kind}
                      onChange={(event) =>
                        patchRow('headers', index, {
                          kind: event.target.value as typeof slide.kind,
                        })
                      }
                    >
                      <option value="illustration">Illustration with title</option>
                      <option value="title">Large festival title</option>
                      <option value="brand">Brand promotion</option>
                    </select>
                  </Field>
                  <TextField
                    label="Header top line"
                    value={slide.eyebrow}
                    onChange={(eyebrow) => patchRow('headers', index, { eyebrow })}
                  />
                  <TextField
                    label="Header subtitle"
                    value={slide.subtitle}
                    onChange={(subtitle) => patchRow('headers', index, { subtitle })}
                  />
                </div>
                <ImageField
                  label={`Slide ${index + 1} image`}
                  value={slide.image}
                  onChange={(image) => patchRow('headers', index, { image })}
                  onUpload={onUpload}
                />
              </div>
            ))}
            <button
              type="button"
              className={buttonClass}
              disabled={draft.headers.length >= 8}
              onClick={() =>
                change((previous) => ({
                  ...previous,
                  headers: [
                    ...previous.headers,
                    {
                      id: uniqueId('slide'),
                      kind: 'title',
                      eyebrow: '',
                      title: 'Celebrate with FastKirana',
                      subtitle: '',
                      image: null,
                    },
                  ],
                }))
              }
            >
              <Plus size={15} />
              Add slide
            </button>
          </Section>
          <Section title="Rotating product card">
            {catalogueLoading && (
              <p role="status" className="text-text-secondary text-xs">
                Loading this store’s catalogue…
              </p>
            )}
            {catalogueError && (
              <p className="text-xs text-red-700">
                Couldn’t load this store’s catalogue.{' '}
                <button
                  type="button"
                  className={buttonClass}
                  onClick={() => setCatalogueReload((value) => value + 1)}
                >
                  Retry catalogue
                </button>
              </p>
            )}
            {draft.products.map((slot, index) => (
              <div key={slot.id} className="border-border space-y-3 border-b pb-4 last:border-0">
                <RowActions
                  title={`Product ${index + 1}`}
                  index={index}
                  count={draft.products.length}
                  onMove={(direction) => move('products', index, direction)}
                  onRemove={() => remove('products', index)}
                />
                <Field label={`Product ${index + 1} catalogue link`}>
                  <select
                    className={inputClass}
                    disabled={catalogueLoading || catalogueError}
                    value={slot.productId ?? ''}
                    onChange={(event) => {
                      const item = products.find((product) => product.id === event.target.value)
                      patchRow(
                        'products',
                        index,
                        item
                          ? {
                              productId: item.id,
                              name: item.name,
                              image: item.imageUrl || slot.image,
                              price: item.price,
                              originalPrice: Math.max(item.mrp, item.price),
                            }
                          : { productId: undefined }
                      )
                    }}
                  >
                    <option value="">Manual demo product</option>
                    {slot.productId &&
                      !products.some((product) => product.id === slot.productId) && (
                        <option value={slot.productId}>
                          Linked product not loaded ({slot.productId})
                        </option>
                      )}
                    {products
                      .filter((product) => !product.restaurantId)
                      .map((item) => (
                        <option key={item.id} value={item.id}>
                          {item.name}
                        </option>
                      ))}
                  </select>
                </Field>
                <div className="grid gap-3 sm:grid-cols-2">
                  <TextField
                    label="Product name"
                    value={slot.name}
                    onChange={(name) => patchRow('products', index, { name })}
                  />
                  <Field label="Card category">
                    <select
                      className={inputClass}
                      value={slot.categoryId}
                      onChange={(event) =>
                        patchRow('products', index, { categoryId: event.target.value })
                      }
                    >
                      {draft.categories.map((category) => (
                        <option key={category.id} value={category.id}>
                          {category.label}
                        </option>
                      ))}
                    </select>
                  </Field>
                  <TextField
                    label="Original price (demo)"
                    type="number"
                    value={slot.originalPrice}
                    onChange={(value) =>
                      patchRow('products', index, { originalPrice: Number(value) })
                    }
                  />
                  <TextField
                    label="Sale price (demo)"
                    type="number"
                    value={slot.price}
                    onChange={(value) => patchRow('products', index, { price: Number(value) })}
                  />
                  <TextField
                    label="Product search phrase"
                    value={queryFor(slot.destinationId)}
                    onChange={(value) => setQuery(slot.destinationId, value)}
                  />
                </div>
                <ImageField
                  label={`Product ${index + 1} image`}
                  value={slot.image}
                  onChange={(image) => patchRow('products', index, { image: image ?? '' })}
                  onUpload={onUpload}
                />
              </div>
            ))}
            <button
              type="button"
              className={buttonClass}
              disabled={draft.products.length >= 12}
              onClick={() =>
                change((previous) => {
                  const productId = uniqueId('promo'),
                    destinationId = uniqueId('search')
                  return {
                    ...previous,
                    products: [
                      ...previous.products,
                      {
                        id: productId,
                        name: 'New product',
                        image: 'fastkirana-basket.svg',
                        price: 0,
                        originalPrice: 0,
                        currency: 'INR',
                        categoryId: previous.categories[0].id,
                        destinationId,
                      },
                    ],
                    destinations: [
                      ...previous.destinations,
                      { id: destinationId, kind: 'search', query: '' },
                    ],
                  }
                })
              }
            >
              <Plus size={15} />
              Add product
            </button>
          </Section>
          <Section title="Four category cards">
            <p className="text-text-secondary text-xs">
              This template keeps the tall-left card and four category cards. Replace each card’s
              content and search destination here.
            </p>
            {draft.categories.map((category, index) => (
              <div
                key={category.id}
                className="border-border space-y-3 border-b pb-4 last:border-0"
              >
                <RowActions
                  title={`Card ${index + 1}`}
                  index={index}
                  count={4}
                  onMove={(direction) => move('categories', index, direction)}
                />
                <TextField
                  label={`Card ${index + 1} heading`}
                  value={category.label}
                  onChange={(label) => patchRow('categories', index, { label })}
                />
                <TextField
                  label="Category search phrase"
                  value={queryFor(category.destinationId)}
                  onChange={(value) => setQuery(category.destinationId, value)}
                />
                <DelimitedField
                  label="Category keywords (comma separated)"
                  values={category.keywords}
                  delimiter=","
                  onChange={(keywords) => patchRow('categories', index, { keywords })}
                />
                <ImageField
                  label={`Card ${index + 1} image`}
                  value={category.image}
                  onChange={(image) => patchRow('categories', index, { image: image ?? '' })}
                  onUpload={onUpload}
                />
              </div>
            ))}
          </Section>
          <Section title="Collection tabs & product filters">
            {draft.tabs.map((tab, index) => (
              <div key={tab.id} className="border-border space-y-3 border-b pb-4 last:border-0">
                <RowActions
                  title={`Tab ${index + 1}`}
                  index={index}
                  count={draft.tabs.length}
                  onMove={(direction) => move('tabs', index, direction)}
                  onRemove={() => remove('tabs', index)}
                />
                <TextField
                  label={`Tab ${index + 1} label`}
                  value={tab.label}
                  onChange={(label) => patchRow('tabs', index, { label })}
                />
                <DelimitedField
                  label="Product filter keywords (comma separated fallback)"
                  values={tab.keywords}
                  delimiter=","
                  onChange={(keywords) => patchRow('tabs', index, { keywords })}
                />
                {/* Specific Products (ID-wise) Selector */}
                <div className="space-y-2 rounded-xl border border-border/80 bg-muted/20 p-3">
                  <div className="flex items-center justify-between">
                    <label className="text-xs font-bold text-text-primary">
                      📌 Pinned Products for Tab {index + 1} (ID-wise)
                    </label>
                    <span className="text-[10px] text-text-secondary">
                      {((tab as any).productIds || []).length} selected
                    </span>
                  </div>
                  
                  {/* Dropdown to add a product */}
                  <div className="flex gap-2">
                    <select
                      className={inputClass}
                      disabled={catalogueLoading || catalogueError}
                      defaultValue=""
                      onChange={(e) => {
                        const pid = e.target.value
                        if (!pid) return
                        const currentList: string[] = (tab as any).productIds || []
                        if (!currentList.includes(pid)) {
                          patchRow('tabs', index, { productIds: [...currentList, pid] })
                        }
                        e.target.value = ""
                      }}
                    >
                      <option value="">+ Add product from catalogue (ID-wise)...</option>
                      {products
                        .filter((p) => !p.restaurantId && !((tab as any).productIds || []).includes(p.id))
                        .map((p) => (
                          <option key={p.id} value={p.id}>
                            {p.name} {p.price ? `(₹${p.price})` : ''}
                          </option>
                        ))}
                    </select>
                  </div>

                  {/* List of currently selected products with removal */}
                  {((tab as any).productIds || []).length > 0 && (
                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {((tab as any).productIds as string[]).map((pid) => {
                        const prod = products.find((p) => p.id === pid)
                        const prodName = prod ? prod.name : `Product ID: ${pid}`
                        return (
                          <span
                            key={pid}
                            className="inline-flex items-center gap-1 rounded-lg border border-primary/30 bg-primary/10 px-2 py-1 text-xs font-semibold text-primary"
                          >
                            <span className="max-w-[180px] truncate">{prodName}</span>
                            <button
                              type="button"
                              onClick={() => {
                                const updated = ((tab as any).productIds as string[]).filter((id) => id !== pid)
                                patchRow('tabs', index, { productIds: updated })
                              }}
                              className="ml-0.5 text-text-secondary hover:text-red-500 font-bold cursor-pointer"
                              title="Remove product"
                            >
                              ✕
                            </button>
                          </span>
                        )
                      })}
                    </div>
                  )}
                  <p className="text-[10px] text-text-secondary leading-normal">
                    Aapke chune gaye products customer ko sabse pehle exact order me dikhenge.
                  </p>
                </div>
                <ImageField
                  label={`Tab ${index + 1} image`}
                  value={tab.image}
                  onChange={(image) => patchRow('tabs', index, { image: image ?? '' })}
                  onUpload={onUpload}
                />
              </div>
            ))}
            <button
              type="button"
              className={buttonClass}
              disabled={draft.tabs.length >= 8}
              onClick={() =>
                change((previous) => ({
                  ...previous,
                  tabs: [
                    ...previous.tabs,
                    {
                      id: uniqueId('collection'),
                      label: 'New collection',
                      image: 'top-picks.svg',
                      keywords: [],
                      productIds: [],
                    },
                  ],
                }))
              }
            >
              <Plus size={15} />
              Add collection
            </button>
          </Section>
          <Section title="Colours, artwork & motion">
            <div className="grid gap-3 sm:grid-cols-2">
              {Object.entries(draft.appearance).map(([key, value]) => (
                <Field key={key} label={`${colourLabels[key as keyof typeof colourLabels]} colour`}>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      aria-label={`${colourLabels[key as keyof typeof colourLabels]} colour picker`}
                      value={value}
                      onChange={(event) =>
                        change((previous) => ({
                          ...previous,
                          appearance: { ...previous.appearance, [key]: event.target.value },
                        }))
                      }
                    />
                    <input
                      className={inputClass}
                      aria-label={`${key} hex colour`}
                      value={value}
                      onChange={(event) =>
                        change((previous) => ({
                          ...previous,
                          appearance: { ...previous.appearance, [key]: event.target.value },
                        }))
                      }
                    />
                  </div>
                </Field>
              ))}
              {Object.entries(draft.timings).map(([key, value]) => (
                <TextField
                  key={key}
                  label={`${timingLabels[key as keyof typeof timingLabels]} (milliseconds)`}
                  value={value}
                  type="number"
                  onChange={(value) =>
                    change((previous) => ({
                      ...previous,
                      timings: { ...previous.timings, [key]: Number(value) },
                    }))
                  }
                />
              ))}
            </div>
            <ImageField
              label="String lights / decoration image (leave blank to hide)"
              value={draft.decorationImage}
              onChange={(decorationImage) =>
                change((previous) => ({ ...previous, decorationImage }))
              }
              onUpload={onUpload}
            />
          </Section>
          <Section title="Search suggestions">
            <TextField
              label="Fixed search prefix"
              value={draft.searchPrefix}
              onChange={(searchPrefix) => change((previous) => ({ ...previous, searchPrefix }))}
            />
            <DelimitedField
              label="Suggestions (one per line)"
              values={draft.searchSuggestions}
              delimiter={'\n'}
              onChange={(searchSuggestions) =>
                change((previous) => ({ ...previous, searchSuggestions }))
              }
            />
          </Section>
        </fieldset>
        <aside className="border-border min-w-0 rounded-xl border bg-white p-3 xl:sticky xl:top-24">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-sm font-bold text-slate-800">Mobile preview</h3>
            <button
              type="button"
              className={buttonClass}
              onClick={() => setPlayPreview((value) => !value)}
            >
              {playPreview ? 'Pause preview' : 'Play preview'}
            </button>
          </div>
          {!valid.success && (
            <p className="mb-3 text-xs text-red-700">
              Preview shows the template until configuration errors are fixed.
            </p>
          )}
          <div inert data-testid="campaign-preview">
            <div className="mb-3">
              <NavratriSearch
                key={`search-${previewRevision}-${preview.layout}`}
                data={{ ...preview, autoplay: playPreview && preview.autoplay }}
                onSearch={() => {}}
              />
            </div>
            <NavratriSection
              key={`section-${previewRevision}-${preview.layout}`}
              data={{ ...preview, autoplay: playPreview && preview.autoplay }}
              products={products}
              storeId={scope}
              loading={catalogueLoading}
            />
          </div>
          <p className="mt-3 text-xs text-slate-600">
            Drafts are private until you publish. Cart and navigation are disabled in this preview.
          </p>
        </aside>
      </div>
    </div>
  )
}
