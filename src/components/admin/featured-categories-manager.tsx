'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { ArrowDown, ArrowUp, Loader2, Plus, Save, Trash2, Upload } from 'lucide-react'
import {
  defaultFeaturedCategories,
  featuredBadges,
  featuredCategoriesSchema,
  featuredCategorySchema,
  featuredTints,
  isGroceryCategory,
  type CategorySource,
  type FeaturedCategoriesConfig,
  type FeaturedCategoryItem,
} from '@/lib/featured-categories'

const inputClass =
  'w-full min-h-11 rounded-lg border border-border bg-surface px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/25'
const buttonClass =
  'inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border border-border bg-surface px-3 text-sm font-semibold text-text-primary disabled:cursor-not-allowed disabled:opacity-40'
const previewTints: Record<string, string> = {
  mint: '#EFF8F0',
  cream: '#FFF8E7',
  peach: '#FFF1E7',
  sky: '#EEF5FC',
  rose: '#FFF0F3',
  lilac: '#F5F0FA',
  auto: '#F5F7F9',
}
function categoryArtwork(category: CategorySource) {
  if (category.imageUrl) return category.imageUrl
  const slug = `${category.slug} ${category.name}`.toLowerCase()
  const asset = /fruit|veg/.test(slug)
    ? 'fruits_vegetables'
    : /milk|dairy/.test(slug)
      ? 'dairy_breakfast'
      : /snack|munch/.test(slug)
        ? 'snacks_munchies'
        : /drink|beverage/.test(slug)
          ? 'beverages'
          : /atta|rice|dal/.test(slug)
            ? 'atta_rice_dal'
            : /personal|hygiene/.test(slug)
              ? 'personal_care'
              : /home|clean|household/.test(slug)
                ? 'household'
                : /bakery|biscuit/.test(slug)
                  ? 'bakery_biscuits'
                  : /ice.cream/.test(slug)
                    ? 'ice_cream'
                    : null
  return asset ? `/${asset}_category.webp` : null
}
type Props = {
  categories: CategorySource[]
  storeId: string | null
  onUpload: (file: File, onSuccess: (url: string) => void) => Promise<void>
}

export function FeaturedCategoriesManager({ categories, storeId, onUpload }: Props) {
  // Re-mount on scope change so no late request or upload can edit another store.
  return (
    <ScopedFeaturedCategoriesManager
      key={storeId ?? 'global'}
      categories={categories}
      storeId={storeId}
      onUpload={onUpload}
    />
  )
}
function ScopedFeaturedCategoriesManager({ categories, storeId, onUpload }: Props) {
  const [config, setConfig] = useState<FeaturedCategoriesConfig | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [inherited, setInherited] = useState(false)
  const [reload, setReload] = useState(0)
  const [toAdd, setToAdd] = useState('')
  const [needsDefaults, setNeedsDefaults] = useState(false)
  const mounted = useRef(false)
  const edited = useRef(false)
  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])
  const eligible = useMemo(() => categories.filter(isGroceryCategory), [categories])
  const byId = new Map(categories.map((category) => [category.id, category]))
  const options = eligible.filter(
    (category) => !config?.items.some((item) => item.categoryId === category.id)
  )
  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    setError('')
    setNotice('')
    edited.current = false
    const query = storeId ? `?storeId=${encodeURIComponent(storeId)}` : ''
    fetch(`/api/admin/featured-categories${query}`, {
      cache: 'no-store',
      signal: controller.signal,
    })
      .then(async (response) => {
        const body = await response.json()
        if (!response.ok)
          throw new Error(body.error || body.detail || 'Unable to load featured categories')
        if (controller.signal.aborted) return
        const parsed = body.config == null ? null : featuredCategoriesSchema.safeParse(body.config)
        if (parsed && !parsed.success)
          throw new Error('Saved categories could not be loaded safely. Try again.')
        setNeedsDefaults(body.config == null)
        setConfig(parsed?.success ? parsed.data : defaultFeaturedCategories([]))
        setInherited(Boolean(body.inherited))
      })
      .catch((reason) => {
        if (!controller.signal.aborted)
          setError(reason.message || 'Unable to load featured categories')
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false)
      })
    return () => controller.abort()
  }, [storeId, reload])
  useEffect(() => {
    if (needsDefaults && !edited.current && !loading)
      setConfig(defaultFeaturedCategories(categories))
  }, [categories, needsDefaults, loading])
  const busy = loading || saving || uploading !== null
  function edit(change: (current: FeaturedCategoriesConfig) => FeaturedCategoriesConfig) {
    edited.current = true
    setNeedsDefaults(false)
    setNotice('')
    setError('')
    setConfig((current) => (current ? change(current) : current))
  }
  function update(id: string, change: Partial<FeaturedCategoryItem>) {
    edit((current) => ({
      ...current,
      items: current.items.map((item) => (item.categoryId === id ? { ...item, ...change } : item)),
    }))
  }
  function move(index: number, offset: number) {
    edit((current) => {
      const items = [...current.items]
      ;[items[index], items[index + offset]] = [items[index + offset], items[index]]
      return { ...current, items }
    })
  }
  async function upload(id: string, file?: File) {
    if (!file) return
    if (
      !['image/png', 'image/jpeg', 'image/webp', 'image/avif', 'image/svg+xml'].includes(
        file.type
      ) ||
      file.size > 5 * 1024 * 1024
    ) {
      setError('Choose a PNG, JPG, WebP, AVIF or SVG image under 5 MB.')
      return
    }
    setUploading(id)
    setError('')
    let completed = false
    try {
      await onUpload(file, (url) => {
        if (!mounted.current) return
        const parsed = featuredCategorySchema.shape.image.safeParse(url)
        if (!parsed.success) {
          setError('The uploaded image needs a valid HTTPS URL.')
          return
        }
        completed = true
        update(id, { image: url })
      })
      if (mounted.current && !completed)
        setError('Image upload failed. Try again or paste an HTTPS image URL.')
    } catch {
      if (mounted.current) setError('Image upload failed. Try again or paste an HTTPS image URL.')
    } finally {
      if (mounted.current) setUploading(null)
    }
  }
  async function save() {
    const parsed = featuredCategoriesSchema.safeParse(config)
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message || 'Check your category settings.')
      return
    }
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const response = await fetch('/api/admin/featured-categories', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ storeId, config: parsed.data }),
      })
      const body = await response.json()
      if (!response.ok)
        throw new Error(body.error || body.detail || 'Unable to save featured categories')
      if (mounted.current) {
        setConfig(parsed.data)
        setInherited(false)
        setNotice('Saved. The app picks this up on its next settings refresh.')
        edited.current = false
      }
    } catch (reason) {
      if (mounted.current)
        setError(reason instanceof Error ? reason.message : 'Unable to save featured categories')
    } finally {
      if (mounted.current) setSaving(false)
    }
  }
  return (
    <section
      aria-label="Featured categories editor"
      className="border-border bg-surface mb-6 rounded-xl border p-4 sm:p-6"
    >
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-text-primary text-xl font-bold">Featured categories</h2>
          <p className="text-text-secondary mt-1 max-w-xl text-sm">
            Choose up to six shortcuts for the Flutter home screen. Explore Categories still shows
            the full catalogue.
          </p>
        </div>
        <button
          className={`${buttonClass} border-primary! bg-primary! text-white!`}
          disabled={busy || !config}
          onClick={save}
        >
          {saving ? (
            <Loader2 size={16} className="animate-spin motion-reduce:animate-none" />
          ) : (
            <Save size={16} />
          )}
          Save categories
        </button>
      </div>
      {loading && (
        <p role="status" className="text-text-secondary mt-4 text-sm">
          Loading category settings…
        </p>
      )}
      {error && (
        <div role="alert" className="mt-4 text-sm text-red-700">
          {error}
          {!config && !loading && (
            <button
              onClick={() => setReload((value) => value + 1)}
              className={`${buttonClass} ml-3`}
            >
              Retry
            </button>
          )}
        </div>
      )}
      {notice && (
        <p role="status" className="mt-4 text-sm text-green-800">
          {notice}
        </p>
      )}
      {!loading && config && (
        <fieldset disabled={busy} className="mt-5 min-w-0 space-y-5 disabled:opacity-70">
          {inherited && (
            <p className="text-text-secondary text-sm">
              Using global defaults. Saving creates this store’s own selection.
            </p>
          )}
          <div className="grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end">
            <label className="text-text-primary text-sm font-medium">
              Section heading
              <input
                aria-label="Section heading"
                className={`${inputClass} mt-1.5`}
                maxLength={80}
                value={config.title}
                onChange={(event) => edit((current) => ({ ...current, title: event.target.value }))}
              />
            </label>
            <label className="text-text-primary flex min-h-11 items-center gap-2 text-sm font-medium">
              <input
                type="checkbox"
                checked={config.enabled}
                onChange={(event) =>
                  edit((current) => ({ ...current, enabled: event.target.checked }))
                }
                className="accent-primary size-4"
              />
              Show section in app
            </label>
          </div>
          <div aria-label="App preview" className="border-border border-y py-4">
            <p className="text-text-secondary mb-2 text-xs font-semibold">APP PREVIEW</p>
            {!config.enabled ? (
              <p className="text-text-secondary text-sm">Section hidden in app</p>
            ) : (
              <>
                <p className="text-text-primary mb-3 text-lg font-bold">{config.title}</p>
                <div className="flex gap-3 overflow-x-auto pb-2">
                  {config.items
                    .filter(
                      (item) =>
                        item.enabled &&
                        byId.has(item.categoryId) &&
                        byId.get(item.categoryId)?._count?.products !== 0
                    )
                    .map((item) => {
                      const category = byId.get(item.categoryId)!
                      const source =
                        item.image &&
                        featuredCategorySchema.shape.image.safeParse(item.image).success
                          ? item.image
                          : categoryArtwork(category)
                      return (
                        <figure
                          key={item.categoryId}
                          className="w-36 shrink-0 rounded-xl border border-black/10 p-2.5"
                          style={{ background: previewTints[item.tint] }}
                        >
                          <div className="flex h-28 items-center justify-center overflow-hidden rounded-lg">
                            {source ? (
                              <img
                                key={source}
                                src={source}
                                alt=""
                                className={`size-full ${item.imageFit === 'contain' ? 'object-contain' : 'object-cover'}`}
                                onError={(event) => {
                                  event.currentTarget.style.visibility = 'hidden'
                                }}
                              />
                            ) : (
                              <span className="text-3xl font-bold">{category.name[0]}</span>
                            )}
                          </div>
                          <figcaption className="text-text-primary mt-2.5 text-sm leading-snug font-bold">
                            {item.label || category.name}
                          </figcaption>
                          {item.badge && (
                            <p className="text-text-secondary mt-2 text-xs font-medium">
                              {item.badge}
                            </p>
                          )}
                        </figure>
                      )
                    })}
                </div>
              </>
            )}
          </div>
          <p className="text-text-secondary text-xs">
            Badges describe the selection. Order counts, discounts and delivery times aren’t added
            automatically.
          </p>
          <ol className="divide-border divide-y">
            {config.items.map((item, index) => {
              const category = byId.get(item.categoryId)
              return (
                <li
                  key={item.categoryId}
                  className="py-5 first:pt-0"
                  data-testid={`featured-item-${item.categoryId}`}
                >
                  <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                    <div className="min-w-0">
                      <p className="text-text-primary font-semibold">
                        {index + 1}. {category?.name ?? 'Category unavailable'}
                      </p>
                      {!category && (
                        <p className="text-xs text-red-700">
                          Remove this entry or wait for the catalogue to load before saving.
                        </p>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <label className="mr-2 flex min-h-11 items-center gap-2 text-sm">
                        <input
                          aria-label={`Show ${category?.name ?? item.categoryId}`}
                          type="checkbox"
                          checked={item.enabled}
                          onChange={(event) =>
                            update(item.categoryId, { enabled: event.target.checked })
                          }
                          className="accent-primary size-4"
                        />
                        Show
                      </label>
                      <button
                        type="button"
                        aria-label={`Move ${category?.name ?? item.categoryId} up`}
                        className={buttonClass}
                        disabled={index === 0}
                        onClick={() => move(index, -1)}
                      >
                        <ArrowUp size={16} />
                      </button>
                      <button
                        type="button"
                        aria-label={`Move ${category?.name ?? item.categoryId} down`}
                        className={buttonClass}
                        disabled={index === config.items.length - 1}
                        onClick={() => move(index, 1)}
                      >
                        <ArrowDown size={16} />
                      </button>
                      <button
                        type="button"
                        aria-label={`Remove ${category?.name ?? item.categoryId}`}
                        className={buttonClass}
                        onClick={() =>
                          edit((current) => ({
                            ...current,
                            items: current.items.filter(
                              (value) => value.categoryId !== item.categoryId
                            ),
                          }))
                        }
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>
                  <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                    <label className="text-text-secondary text-sm">
                      Display name
                      <input
                        aria-label={`Display name ${index + 1}`}
                        className={`${inputClass} mt-1.5`}
                        value={item.label}
                        maxLength={60}
                        placeholder={category?.name || 'Use category name'}
                        onChange={(event) => update(item.categoryId, { label: event.target.value })}
                      />
                    </label>
                    <label className="text-text-secondary text-sm">
                      Badge
                      <select
                        aria-label={`Badge ${index + 1}`}
                        className={`${inputClass} mt-1.5`}
                        value={item.badge}
                        onChange={(event) =>
                          update(item.categoryId, {
                            badge: event.target.value as FeaturedCategoryItem['badge'],
                          })
                        }
                      >
                        {featuredBadges.map((value) => (
                          <option key={value} value={value}>
                            {value || 'None'}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="text-text-secondary text-sm">
                      Background
                      <select
                        aria-label={`Background ${index + 1}`}
                        className={`${inputClass} mt-1.5`}
                        value={item.tint}
                        onChange={(event) =>
                          update(item.categoryId, {
                            tint: event.target.value as FeaturedCategoryItem['tint'],
                          })
                        }
                      >
                        {featuredTints.map((value) => (
                          <option key={value} value={value}>
                            {value === 'auto'
                              ? 'Match category'
                              : value[0].toUpperCase() + value.slice(1)}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="text-text-secondary text-sm md:col-span-2">
                      Image URL
                      <input
                        aria-label={`Image URL ${index + 1}`}
                        className={`${inputClass} mt-1.5`}
                        value={item.image ?? ''}
                        placeholder="Use category image, or paste HTTPS URL"
                        onChange={(event) =>
                          update(item.categoryId, { image: event.target.value || null })
                        }
                      />
                    </label>
                    <label className="text-text-secondary text-sm">
                      Image fit
                      <select
                        aria-label={`Image fit ${index + 1}`}
                        className={`${inputClass} mt-1.5`}
                        value={item.imageFit}
                        onChange={(event) =>
                          update(item.categoryId, {
                            imageFit: event.target.value as FeaturedCategoryItem['imageFit'],
                          })
                        }
                      >
                        <option value="cover">Fill (photos)</option>
                        <option value="contain">Fit (cutouts)</option>
                      </select>
                    </label>
                  </div>
                  <label className={`${buttonClass} mt-3 cursor-pointer`}>
                    <Upload size={16} />
                    {uploading === item.categoryId ? 'Uploading…' : 'Upload artwork'}
                    <input
                      aria-label={`Upload artwork ${index + 1}`}
                      type="file"
                      className="sr-only"
                      accept="image/png,image/jpeg,image/webp,image/avif,image/svg+xml"
                      onChange={(event) => {
                        void upload(item.categoryId, event.target.files?.[0])
                        event.target.value = ''
                      }}
                    />
                  </label>
                </li>
              )
            })}
          </ol>
          {config.items.length === 0 && (
            <p className="text-text-secondary text-sm">
              No categories selected. This section stays hidden until you add one.
            </p>
          )}
          <div className="flex flex-wrap gap-3">
            <select
              aria-label="Category to add"
              className={`${inputClass} max-w-sm`}
              value={toAdd}
              onChange={(event) => setToAdd(event.target.value)}
              disabled={config.items.length >= 6}
            >
              <option value="">Choose a category</option>
              {options.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.name}
                </option>
              ))}
            </select>
            <button
              type="button"
              className={buttonClass}
              disabled={
                !toAdd ||
                config.items.length >= 6 ||
                !options.some((category) => category.id === toAdd)
              }
              onClick={() => {
                edit((current) => ({
                  ...current,
                  items: [...current.items, featuredCategorySchema.parse({ categoryId: toAdd })],
                }))
                setToAdd('')
              }}
            >
              <Plus size={16} />
              Add category
            </button>
          </div>
          <p className="text-text-secondary text-xs">
            {config.items.length}/6 selected. Empty and unavailable categories are hidden in the
            app.
          </p>
        </fieldset>
      )}
    </section>
  )
}
