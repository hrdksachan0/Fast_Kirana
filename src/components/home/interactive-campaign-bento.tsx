'use client'

import { useEffect, useMemo, useState } from 'react'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { motion, AnimatePresence } from 'framer-motion'
import { Check, Minus, Plus, Zap, EyeOff } from 'lucide-react'
import { cn } from '@/lib/utils'
import { apiUrl, catalogApiUrl } from '@/lib/api-url'
import { useCartStore } from '@/stores/cart-store'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'
import type { Product } from '@/types'
import {
  defaultCampaignBentoConfig,
  parseCampaignBentoConfig,
  resolveBentoSlotProduct,
  type BentoCardKey,
  type CampaignBentoConfig,
  type ResolvedBentoSlot,
} from '@/lib/campaign-bento-config'

export interface InteractiveCampaignBentoProps {
  /** Controlled config (used by Admin Live Preview) */
  config?: CampaignBentoConfig | null
  /** Initial server-rendered published config */
  initialConfig?: CampaignBentoConfig | null
  /** Live catalogue products passed from StorefrontClient or Admin */
  products?: Product[]
  /** Active dark store hub ID */
  storeId?: string | null
  /** When true, interactions stay isolated from the real shopping cart */
  previewMode?: boolean
  /** Optional filter to preview one specific card */
  focusedCard?: BentoCardKey | 'all'
}

const formatInr = (value: number) => `₹${Math.round(value).toLocaleString('en-IN')}`

export function InteractiveCampaignBento({
  config: controlledConfig,
  initialConfig = null,
  products: propProducts,
  storeId,
  previewMode = false,
  focusedCard = 'all',
}: InteractiveCampaignBentoProps) {
  const router = useRouter()
  const addItem = useCartStore((s) => s.addItem)
  const updateQuantity = useCartStore((s) => s.updateQuantity)
  const cartItems = useCartStore((s) => s.items)

  const [fetchedConfig, setFetchedConfig] = useState<CampaignBentoConfig | null>(initialConfig)
  const [linkedProducts, setLinkedProducts] = useState<Product[]>([])
  const [fallbackCatalog, setFallbackCatalog] = useState<Product[]>([])

  // Fetch published bento config & explicitly linked real products when not controlled
  useEffect(() => {
    if (controlledConfig !== undefined) return
    const controller = new AbortController()
    const query = storeId ? `?storeId=${encodeURIComponent(storeId)}` : ''

    fetch(`${apiUrl()}/api/campaign-bento${query}`, {
      signal: controller.signal,
      cache: 'no-store',
    })
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (!data || controller.signal.aborted) return
        if (data.campaign) {
          setFetchedConfig(parseCampaignBentoConfig(data.campaign))
        }
        if (Array.isArray(data.linkedProducts)) {
          setLinkedProducts(data.linkedProducts)
        }
      })
      .catch(() => {})

    return () => controller.abort()
  }, [controlledConfig, storeId])

  // If rendered standalone (e.g. /campaign-bento without products prop), fetch grocery catalogue once
  useEffect(() => {
    if (propProducts !== undefined) return
    const controller = new AbortController()
    const query = new URLSearchParams({ limit: '250', excludeRestaurant: 'true' })
    if (storeId) query.set('storeId', storeId)

    fetch(`${catalogApiUrl()}/api/products?${query.toString()}`, {
      signal: controller.signal,
    })
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (controller.signal.aborted) return
        if (Array.isArray(data?.products)) {
          setFallbackCatalog(data.products)
        }
      })
      .catch(() => {})

    return () => controller.abort()
  }, [propProducts, storeId])

  const activeConfig = useMemo(() => {
    if (controlledConfig !== undefined && controlledConfig !== null) return controlledConfig
    if (fetchedConfig) return fetchedConfig
    if (initialConfig) return initialConfig
    return defaultCampaignBentoConfig
  }, [controlledConfig, fetchedConfig, initialConfig])

  // Merge caller products with server-hydrated linked products (caller catalogue wins if present)
  const mergedProducts = useMemo(() => {
    const map = new Map<string, Product>()
    for (const p of linkedProducts) map.set(p.id, p)
    for (const p of fallbackCatalog) map.set(p.id, p)
    for (const p of propProducts ?? []) map.set(p.id, p)
    return Array.from(map.values())
  }, [linkedProducts, fallbackCatalog, propProducts])

  // Card 01 State
  const [activeFreshPill, setActiveFreshPill] = useState<string>(
    activeConfig.freshMarket.tabs[0]?.id ?? 'sabzi'
  )
  const [previewQuantities, setPreviewQuantities] = useState<Record<string, number>>({})

  useEffect(() => {
    const tabs = activeConfig.freshMarket.tabs
    if (tabs.length > 0 && !tabs.some((t) => t.id === activeFreshPill)) {
      setActiveFreshPill(tabs[0].id)
    }
  }, [activeConfig.freshMarket.tabs, activeFreshPill])

  // Card 03 State
  const [valueCardAdded, setValueCardAdded] = useState<string | null>(null)

  // Card 04 State
  const [activeOccasion, setActiveOccasion] = useState<string>(
    activeConfig.giftingBoutique.occasions[0]?.id ?? 'birthday'
  )

  // Card 06 State
  const [breakfastChecks, setBreakfastChecks] = useState<Record<string, boolean>>(() => {
    const initial: Record<string, boolean> = {}
    for (const item of activeConfig.breakfastClub.items) {
      initial[item.id] = item.checkedByDefault !== false
    }
    return initial
  })

  useEffect(() => {
    setBreakfastChecks((prev) => {
      const next = { ...prev }
      for (const item of activeConfig.breakfastClub.items) {
        if (next[item.id] === undefined) {
          next[item.id] = item.checkedByDefault !== false
        }
      }
      return next
    })
  }, [activeConfig.breakfastClub.items])

  const getCartQty = (resolved: ResolvedBentoSlot) => {
    if (previewMode) return previewQuantities[resolved.slotId] ?? 0
    if (!resolved.product) return 0
    return cartItems.find((i) => i.product.id === resolved.product!.id)?.quantity ?? 0
  }

  const handleAddResolved = (resolved: ResolvedBentoSlot, quantity = 1) => {
    triggerHaptic('success')
    if (previewMode) {
      setPreviewQuantities((prev) => ({
        ...prev,
        [resolved.slotId]: (prev[resolved.slotId] ?? 0) + quantity,
      }))
      toast.info(
        `Preview: ${resolved.name} (${resolved.unit}) • ${formatInr(resolved.price)}${
          resolved.product ? '' : ' [Demo fallback]'
        }`
      )
      return true
    }

    if (!resolved.product) {
      toast.info(`Searching store catalogue for "${resolved.name}"…`)
      router.push(`/search?q=${encodeURIComponent(resolved.name)}`)
      return false
    }

    if (!resolved.inStock) {
      toast.error(`${resolved.name} is currently out of stock at this store`)
      return false
    }

    for (let i = 0; i < quantity; i++) {
      addItem(resolved.product, storeId ?? undefined)
    }
    toast.success(`${resolved.name} (${resolved.unit}) added to basket!`)
    return true
  }

  const handleDecrementResolved = (resolved: ResolvedBentoSlot) => {
    triggerHaptic('selection')
    if (previewMode) {
      setPreviewQuantities((prev) => ({
        ...prev,
        [resolved.slotId]: Math.max(0, (prev[resolved.slotId] ?? 0) - 1),
      }))
      return
    }
    if (!resolved.product) return
    const current = getCartQty(resolved)
    if (current > 0) {
      updateQuantity(resolved.product.id, current - 1)
    }
  }

  // Hide entire section on live storefront when disabled by Admin
  if (!activeConfig.enabled && !previewMode) {
    return null
  }

  const cardVariants = {
    hidden: { opacity: 0, y: 16 },
    visible: {
      opacity: 1,
      y: 0,
      transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] as const },
    },
  }

  const currentFreshTab =
    activeConfig.freshMarket.tabs.find((t) => t.id === activeFreshPill) ??
    activeConfig.freshMarket.tabs[0]

  const breakfastResolved = activeConfig.breakfastClub.items.map((slot) => ({
    slot,
    resolved: resolveBentoSlotProduct(slot, mergedProducts),
  }))

  const selectedBreakfast = breakfastResolved.filter(
    ({ slot, resolved }) => Boolean(breakfastChecks[slot.id]) && (previewMode || resolved.inStock)
  )
  const breakfastTotal = selectedBreakfast.reduce((sum, { resolved }) => sum + resolved.price, 0)
  const breakfastCount = selectedBreakfast.length

  const shouldRenderCard = (key: BentoCardKey, cardEnabled: boolean) => {
    if (focusedCard !== 'all' && focusedCard !== key) return false
    if (!cardEnabled && !previewMode) return false
    return true
  }

  const gridClass =
    focusedCard !== 'all'
      ? 'grid grid-cols-1 max-w-md mx-auto gap-6'
      : 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-7'

  return (
    <section
      className={cn(
        'relative w-full mx-auto',
        previewMode ? 'py-2 px-1' : 'py-8 px-3 sm:px-6 lg:px-8 max-w-7xl'
      )}
    >
      {previewMode && !activeConfig.enabled && (
        <div className="mb-3 flex items-center gap-2 rounded-xl border border-amber-300 bg-amber-50 px-3 py-2 text-xs font-bold text-amber-800">
          <EyeOff className="h-4 w-4 shrink-0" />
          <span>6-Card Bento section is currently hidden on the live storefront.</span>
        </div>
      )}

      <motion.div
        initial={previewMode ? false : 'hidden'}
        whileInView="visible"
        viewport={{ once: true }}
        className={cn(gridClass, previewMode && !activeConfig.enabled && 'opacity-70')}
      >
        {/* ======================================================== */}
        {/* 01: FRESH MARKET                                         */}
        {/* ======================================================== */}
        {shouldRenderCard('freshMarket', activeConfig.freshMarket.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.freshMarket.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>01</span>
              {!activeConfig.freshMarket.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[22px] bg-[#F0F7F2] border border-[#DCFCE7] p-5 flex flex-col justify-between shadow-[0_2px_12px_rgba(21,128,61,0.04)] h-full"
            >
              <div>
                <div className="flex items-center gap-1 text-[#15803D] font-extrabold text-sm tracking-tight mb-2">
                  <Zap className="w-4 h-4 fill-[#15803D]" />
                  <span>FastMinute</span>
                </div>

                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-xl font-extrabold text-[#0F172A] tracking-tight leading-tight">
                      {activeConfig.freshMarket.title}
                    </h3>
                    <p className="text-xs text-slate-500 mt-0.5 font-medium">
                      {activeConfig.freshMarket.subtitle}
                    </p>
                  </div>
                  <div className="w-14 h-11 relative flex-shrink-0">
                    <Image
                      src={activeConfig.freshMarket.headerImage}
                      alt={activeConfig.freshMarket.title}
                      fill
                      unoptimized
                      className="object-contain"
                    />
                  </div>
                </div>

                {/* Filter Pills */}
                <div className="flex items-center gap-2 mt-3.5 overflow-x-auto no-scrollbar">
                  {activeConfig.freshMarket.tabs.map((tab) => {
                    const isActive = currentFreshTab?.id === tab.id
                    return (
                      <button
                        key={tab.id}
                        type="button"
                        onClick={() => setActiveFreshPill(tab.id)}
                        className={cn(
                          'px-3.5 py-1.5 rounded-full text-xs font-bold transition-all flex items-center gap-1 cursor-pointer select-none whitespace-nowrap',
                          isActive
                            ? 'bg-[#15803D] text-white shadow-xs'
                            : 'bg-white text-slate-700 hover:bg-white/80 border border-slate-200'
                        )}
                      >
                        <span className="text-xs">{tab.icon}</span>
                        <span>{tab.label}</span>
                      </button>
                    )
                  })}
                </div>

                {/* 2-Item Product Cards */}
                <AnimatePresence mode="wait">
                  <motion.div
                    key={currentFreshTab?.id}
                    initial={{ opacity: 0, y: 6 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -6 }}
                    transition={{ duration: 0.18 }}
                    className="grid grid-cols-2 gap-3 mt-4"
                  >
                    {(currentFreshTab?.items ?? []).map((slot) => {
                      const resolved = resolveBentoSlotProduct(slot, mergedProducts)
                      const qty = getCartQty(resolved)
                      return (
                        <div
                          key={slot.id}
                          className="bg-white rounded-2xl p-3 flex flex-col justify-between border border-slate-200/80 shadow-[0_2px_8px_rgba(0,0,0,0.03)]"
                        >
                          <div className="w-full h-20 relative mb-1.5 flex items-center justify-center p-1">
                            <Image
                              src={resolved.imageUrl}
                              alt={resolved.name}
                              fill
                              unoptimized
                              className="object-contain hover:scale-105 transition-transform"
                            />
                          </div>
                          <div>
                            <h4 className="text-xs font-bold text-[#0F172A] leading-snug truncate">
                              {resolved.name}
                            </h4>
                            <div className="flex items-center justify-between text-xs text-slate-500 mt-0.5">
                              <span className="text-[11px] font-medium truncate max-w-[64px]">
                                {resolved.unit}
                              </span>
                              <div className="flex items-baseline gap-1">
                                {resolved.mrp > resolved.price && (
                                  <span className="text-[10px] text-slate-400 line-through tabular-nums">
                                    {formatInr(resolved.mrp)}
                                  </span>
                                )}
                                <span className="text-sm font-extrabold text-[#0F172A] tabular-nums">
                                  {formatInr(resolved.price)}
                                </span>
                              </div>
                            </div>
                          </div>
                          <button
                            type="button"
                            disabled={!previewMode && resolved.isLinked && !resolved.inStock}
                            onClick={() => handleAddResolved(resolved)}
                            className="mt-2.5 w-full py-1.5 rounded-lg bg-[#15803D] hover:bg-[#166534] active:bg-[#14532D] disabled:bg-slate-200 disabled:text-slate-500 text-white text-xs font-extrabold uppercase tracking-wider transition-colors cursor-pointer"
                          >
                            {!previewMode && resolved.isLinked && !resolved.inStock
                              ? 'Out of stock'
                              : qty > 0
                                ? `ADD (${qty})`
                                : 'ADD'}
                          </button>
                        </div>
                      )
                    })}
                  </motion.div>
                </AnimatePresence>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 02: DAILY RESTOCK                                        */}
        {/* ======================================================== */}
        {shouldRenderCard('dailyRestock', activeConfig.dailyRestock.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.dailyRestock.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>02</span>
              {!activeConfig.dailyRestock.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[22px] bg-[#F4F9FD] border border-[#E0F2FE] p-5 flex flex-col justify-between shadow-[0_2px_12px_rgba(2,132,199,0.04)] h-full"
            >
              <div>
                <div className="flex items-start justify-between">
                  <div>
                    <div className="flex items-center gap-1 text-[#15803D] font-extrabold text-sm tracking-tight mb-2">
                      <Zap className="w-4 h-4 fill-[#15803D]" />
                      <span>FastMinute</span>
                    </div>
                    <h3 className="text-xl font-extrabold text-[#0F172A] tracking-tight leading-tight">
                      {activeConfig.dailyRestock.title}
                    </h3>
                    <p className="text-xs text-slate-500 mt-0.5 font-medium">
                      {activeConfig.dailyRestock.subtitle}
                    </p>
                  </div>
                  <div className="w-11 h-11 rounded-full bg-[#E0F2FE] text-[#0284C7] flex items-center justify-center p-2 flex-shrink-0">
                    <Image
                      src={activeConfig.dailyRestock.headerImage}
                      alt={activeConfig.dailyRestock.title}
                      width={28}
                      height={28}
                      unoptimized
                    />
                  </div>
                </div>

                {/* Stepper Rows */}
                <div className="mt-4 space-y-2.5">
                  {activeConfig.dailyRestock.items.map((slot) => {
                    const resolved = resolveBentoSlotProduct(slot, mergedProducts)
                    const qty = getCartQty(resolved)
                    const outOfStock = !previewMode && resolved.isLinked && !resolved.inStock
                    return (
                      <div
                        key={slot.id}
                        className="bg-white rounded-xl p-2.5 flex items-center justify-between border border-slate-100 shadow-2xs gap-2"
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          <div className="w-10 h-10 relative flex-shrink-0">
                            <Image
                              src={resolved.imageUrl}
                              alt={resolved.name}
                              fill
                              unoptimized
                              className="object-contain"
                            />
                          </div>
                          <div className="min-w-0">
                            <h4 className="text-xs font-bold text-[#0F172A] leading-snug truncate">
                              {resolved.name}
                            </h4>
                            <p className="text-[11px] text-slate-500 truncate">{resolved.unit}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-3 shrink-0">
                          <span className="text-sm font-extrabold text-[#0F172A] tabular-nums">
                            {formatInr(resolved.price)}
                          </span>
                          {outOfStock ? (
                            <span className="text-[10px] font-bold text-rose-600 bg-rose-50 px-2 py-1 rounded-md">
                              No stock
                            </span>
                          ) : (
                            <div className="flex items-center border border-sky-200 rounded-lg bg-[#F0F9FF] overflow-hidden">
                              <button
                                type="button"
                                aria-label={`Decrease ${resolved.name}`}
                                disabled={qty <= 0}
                                onClick={() => handleDecrementResolved(resolved)}
                                className="w-6 h-6 flex items-center justify-center text-[#0284C7] hover:bg-sky-200 disabled:opacity-40 text-xs font-bold cursor-pointer"
                              >
                                <Minus className="w-3 h-3" />
                              </button>
                              <span className="w-6 text-center text-xs font-extrabold text-slate-800 tabular-nums">
                                {qty}
                              </span>
                              <button
                                type="button"
                                aria-label={`Increase ${resolved.name}`}
                                onClick={() => handleAddResolved(resolved)}
                                className="w-6 h-6 flex items-center justify-center text-[#0284C7] hover:bg-sky-200 text-xs font-bold cursor-pointer"
                              >
                                <Plus className="w-3 h-3" />
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 03: VALUE PICKS                                          */}
        {/* ======================================================== */}
        {shouldRenderCard('valuePicks', activeConfig.valuePicks.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.valuePicks.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>03</span>
              {!activeConfig.valuePicks.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[22px] bg-[#FEFCE8] border border-[#FEF08A] p-5 flex flex-col justify-between shadow-[0_2px_12px_rgba(202,138,4,0.04)] h-full"
            >
              <div>
                <div className="flex items-center gap-1 text-[#15803D] font-extrabold text-sm tracking-tight mb-2">
                  <Zap className="w-4 h-4 fill-[#15803D]" />
                  <span>FastMinute</span>
                </div>

                <div className="p-3 rounded-xl bg-[#FDE047] shadow-xs">
                  <h3 className="text-xl font-black text-[#0F172A] leading-tight">
                    {activeConfig.valuePicks.title}
                  </h3>
                  <p className="text-xs text-[#713F12] font-semibold mt-0.5">
                    {activeConfig.valuePicks.subtitle}
                  </p>
                </div>

                <div className="grid grid-cols-2 gap-3 mt-3.5">
                  {activeConfig.valuePicks.items.map((slot) => {
                    const resolved = resolveBentoSlotProduct(slot, mergedProducts)
                    const outOfStock = !previewMode && resolved.isLinked && !resolved.inStock
                    return (
                      <div
                        key={slot.id}
                        className={cn(
                          'bg-white rounded-2xl p-3 flex flex-col justify-between border shadow-2xs relative overflow-hidden',
                          resolved.badge ? 'border-[#BBF7D0]' : 'border-slate-200'
                        )}
                      >
                        {resolved.badge && (
                          <div className="absolute top-0 right-0 z-10 bg-[#15803D] text-white text-[9px] font-extrabold uppercase px-2 py-0.5 rounded-bl-lg tracking-wider text-center leading-tight max-w-[74px]">
                            {resolved.badge}
                          </div>
                        )}
                        <div className="w-full h-22 relative mb-1 flex items-center justify-center">
                          <Image
                            src={resolved.imageUrl}
                            alt={resolved.name}
                            fill
                            unoptimized
                            className="object-contain"
                          />
                        </div>
                        <div>
                          <h4 className="text-sm font-extrabold text-[#0F172A] leading-snug truncate">
                            {resolved.name}
                          </h4>
                          <p className="text-xs text-slate-500 font-medium truncate">
                            {resolved.unit}
                          </p>
                          <div className="mt-1 flex items-baseline justify-between gap-1">
                            <span className="text-base font-black text-[#0F172A] tabular-nums">
                              {formatInr(resolved.price)}
                            </span>
                            {resolved.perUnitLabel && (
                              <span
                                className={cn(
                                  'text-[11px] font-semibold tabular-nums truncate',
                                  resolved.badge ? 'text-[#15803D] font-bold' : 'text-slate-400'
                                )}
                              >
                                {resolved.perUnitLabel}
                              </span>
                            )}
                          </div>
                        </div>
                        <button
                          type="button"
                          disabled={outOfStock}
                          onClick={() => {
                            if (handleAddResolved(resolved)) {
                              setValueCardAdded(slot.id)
                              setTimeout(() => setValueCardAdded(null), 1800)
                            }
                          }}
                          className="mt-2.5 w-full py-1.5 rounded-lg bg-[#15803D] hover:bg-[#166534] disabled:bg-slate-200 disabled:text-slate-500 text-white text-xs font-extrabold uppercase tracking-wider transition-colors cursor-pointer"
                        >
                          {outOfStock
                            ? 'Out of stock'
                            : valueCardAdded === slot.id
                              ? 'ADDED'
                              : 'ADD'}
                        </button>
                      </div>
                    )
                  })}
                </div>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 04: GIFTING BOUTIQUE                                     */}
        {/* ======================================================== */}
        {shouldRenderCard('giftingBoutique', activeConfig.giftingBoutique.enabled) && (
          <div
            className={cn('flex flex-col', !activeConfig.giftingBoutique.enabled && 'opacity-60')}
          >
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>04</span>
              {!activeConfig.giftingBoutique.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            {(() => {
              const hero = resolveBentoSlotProduct(
                activeConfig.giftingBoutique.heroItem,
                mergedProducts
              )
              const mini = resolveBentoSlotProduct(
                activeConfig.giftingBoutique.miniItem,
                mergedProducts
              )
              return (
                <motion.div
                  variants={cardVariants}
                  className="rounded-[22px] bg-[#FDF2F4] border border-[#FCE7F3] p-5 flex flex-col justify-between shadow-[0_2px_12px_rgba(225,29,72,0.04)] h-full"
                >
                  <div>
                    <div className="flex items-center gap-1 text-[#15803D] font-extrabold text-sm tracking-tight mb-2">
                      <Zap className="w-4 h-4 fill-[#15803D]" />
                      <span>FastMinute</span>
                    </div>

                    <h3 className="text-xl font-extrabold text-[#831843] tracking-tight leading-tight">
                      {activeConfig.giftingBoutique.title}
                    </h3>
                    <p className="text-xs text-[#9D174D] mt-0.5 font-medium">
                      {activeConfig.giftingBoutique.subtitle}
                    </p>

                    <div className="grid grid-cols-12 gap-3 mt-3.5">
                      <div className="col-span-5 relative h-48 rounded-2xl overflow-hidden bg-white/70">
                        <Image
                          src={hero.imageUrl}
                          alt={hero.name}
                          fill
                          unoptimized
                          className="object-cover"
                        />
                      </div>

                      <div className="col-span-7 flex flex-col justify-between">
                        <div>
                          <h4 className="text-sm font-extrabold text-[#0F172A] leading-snug line-clamp-2">
                            {hero.name}
                          </h4>
                          <p className="text-xs text-slate-500">{hero.unit}</p>
                          <div className="mt-1 flex items-center justify-between gap-2">
                            <span className="text-base font-black text-[#0F172A] tabular-nums">
                              {formatInr(hero.price)}
                            </span>
                            <button
                              type="button"
                              disabled={!previewMode && hero.isLinked && !hero.inStock}
                              onClick={() => handleAddResolved(hero)}
                              className="px-3.5 py-1 rounded-full bg-[#15803D] hover:bg-[#166534] disabled:bg-slate-300 text-white text-xs font-extrabold cursor-pointer"
                            >
                              {!previewMode && hero.isLinked && !hero.inStock ? 'OUT' : 'ADD'}
                            </button>
                          </div>
                        </div>

                        <div className="my-2">
                          <p className="text-[10px] font-semibold text-slate-500 mb-1">Occasion</p>
                          <div className="flex flex-wrap gap-1.5">
                            {activeConfig.giftingBoutique.occasions.map((occ) => (
                              <button
                                key={occ.id}
                                type="button"
                                onClick={() => setActiveOccasion(occ.id)}
                                className={cn(
                                  'px-2.5 py-1 rounded-full text-[11px] font-bold transition-all cursor-pointer select-none',
                                  activeOccasion === occ.id
                                    ? 'bg-[#FCE7F3] border border-[#F43F5E] text-[#9F1239]'
                                    : 'bg-white border border-slate-200 text-slate-700'
                                )}
                              >
                                {occ.icon} {occ.label}
                              </button>
                            ))}
                          </div>
                        </div>

                        <div className="bg-white rounded-xl p-2 border border-[#FCE7F3] flex items-center justify-between shadow-2xs gap-1.5">
                          <div className="flex items-center gap-2 min-w-0">
                            <div className="w-8 h-8 relative flex-shrink-0">
                              <Image
                                src={mini.imageUrl}
                                alt={mini.name}
                                fill
                                unoptimized
                                className="object-contain"
                              />
                            </div>
                            <div className="min-w-0">
                              <h5 className="text-[11px] font-bold text-[#0F172A] leading-tight truncate max-w-[85px]">
                                {mini.name}
                              </h5>
                              <p className="text-[10px] text-slate-500 truncate">{mini.unit}</p>
                            </div>
                          </div>
                          <div className="flex items-center gap-1.5 shrink-0">
                            <span className="text-xs font-black text-[#0F172A] tabular-nums">
                              {formatInr(mini.price)}
                            </span>
                            <button
                              type="button"
                              disabled={!previewMode && mini.isLinked && !mini.inStock}
                              onClick={() => handleAddResolved(mini)}
                              className="px-2 py-0.5 rounded-full bg-[#15803D] hover:bg-[#166534] disabled:bg-slate-300 text-white text-[10px] font-bold cursor-pointer"
                            >
                              {!previewMode && mini.isLinked && !mini.inStock ? 'OUT' : 'ADD'}
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </motion.div>
              )
            })()}
          </div>
        )}

        {/* ======================================================== */}
        {/* 05: MOVIE NIGHT                                          */}
        {/* ======================================================== */}
        {shouldRenderCard('movieNight', activeConfig.movieNight.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.movieNight.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>05</span>
              {!activeConfig.movieNight.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[22px] bg-[#251640] border border-[#382458] p-5 flex flex-col justify-between shadow-[0_4px_20px_rgba(0,0,0,0.3)] h-full text-white"
            >
              <div>
                <div className="flex items-center gap-1 text-white font-extrabold text-sm tracking-tight mb-2">
                  <Zap className="w-4 h-4 fill-white" />
                  <span>FastMinute</span>
                </div>

                <h3 className="text-xl font-extrabold text-white tracking-tight leading-tight">
                  {activeConfig.movieNight.title}
                </h3>
                <p className="text-xs text-[#DDD6FE] mt-0.5 font-medium">
                  {activeConfig.movieNight.subtitle}
                </p>

                <div className="w-full h-36 my-3 rounded-xl relative overflow-hidden">
                  <Image
                    src={activeConfig.movieNight.heroImage}
                    alt={activeConfig.movieNight.title}
                    fill
                    unoptimized
                    className="object-cover"
                  />
                </div>

                <div className="grid grid-cols-3 gap-2 bg-[#351B4D] p-2.5 rounded-xl border border-[#4C2A6D]">
                  {activeConfig.movieNight.items.map((slot, index) => {
                    const resolved = resolveBentoSlotProduct(slot, mergedProducts)
                    const outOfStock = !previewMode && resolved.isLinked && !resolved.inStock
                    const qty = getCartQty(resolved)
                    return (
                      <div
                        key={slot.id}
                        className={cn(
                          'flex flex-col justify-between min-w-0',
                          index === 1 && activeConfig.movieNight.items.length === 3
                            ? 'border-x border-[#4C2A6D] px-2'
                            : ''
                        )}
                      >
                        <div>
                          <h5 className="text-xs font-bold text-white truncate">{resolved.name}</h5>
                          <p className="text-[10px] text-[#C4B5FD] truncate">{resolved.unit}</p>
                        </div>
                        <div className="mt-2 flex items-center justify-between gap-1">
                          <span className="text-sm font-black text-white tabular-nums">
                            {formatInr(resolved.price)}
                          </span>
                          <button
                            type="button"
                            disabled={outOfStock}
                            aria-label={`Add ${resolved.name}`}
                            onClick={() => handleAddResolved(resolved)}
                            className="w-6 h-6 rounded-md bg-[#15803D] hover:bg-[#166534] disabled:bg-slate-600 text-white flex items-center justify-center text-xs font-black cursor-pointer shrink-0"
                          >
                            {qty > 0 ? qty : '+'}
                          </button>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 06: BREAKFAST CLUB                                       */}
        {/* ======================================================== */}
        {shouldRenderCard('breakfastClub', activeConfig.breakfastClub.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.breakfastClub.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>06</span>
              {!activeConfig.breakfastClub.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[22px] bg-[#FBF9F6] border border-[#E2E8F0] p-5 flex flex-col justify-between shadow-[0_2px_12px_rgba(0,0,0,0.03)] h-full"
            >
              <div>
                <div className="flex items-center gap-1 text-[#15803D] font-extrabold text-sm tracking-tight mb-2">
                  <Zap className="w-4 h-4 fill-[#15803D]" />
                  <span>FastMinute</span>
                </div>

                <h3 className="text-xl font-extrabold text-[#0F172A] tracking-tight leading-tight">
                  {activeConfig.breakfastClub.title}
                </h3>
                <p className="text-xs text-slate-500 mt-0.5 font-medium">
                  {activeConfig.breakfastClub.subtitle}
                </p>

                <div className="grid grid-cols-12 gap-3 mt-3.5">
                  <div className="col-span-5 relative h-40 rounded-xl overflow-hidden bg-white">
                    <Image
                      src={activeConfig.breakfastClub.heroImage}
                      alt={activeConfig.breakfastClub.title}
                      fill
                      unoptimized
                      className="object-cover"
                    />
                  </div>

                  <div className="col-span-7 space-y-2">
                    {breakfastResolved.map(({ slot, resolved }) => {
                      const isChecked = Boolean(breakfastChecks[slot.id])
                      const outOfStock = !previewMode && resolved.isLinked && !resolved.inStock
                      return (
                        <div
                          key={slot.id}
                          onClick={() => {
                            if (outOfStock) return
                            setBreakfastChecks((prev) => ({
                              ...prev,
                              [slot.id]: !prev[slot.id],
                            }))
                          }}
                          className={cn(
                            'flex items-center justify-between p-1.5 rounded-lg border border-slate-100 bg-white shadow-2xs select-none gap-1',
                            outOfStock ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'
                          )}
                        >
                          <div className="flex items-center gap-2 min-w-0">
                            <div
                              className={cn(
                                'w-4 h-4 rounded flex items-center justify-center text-[10px] font-bold transition-all shrink-0',
                                isChecked && !outOfStock
                                  ? 'bg-[#15803D] text-white'
                                  : 'border border-slate-300 bg-white'
                              )}
                            >
                              {isChecked && !outOfStock && <Check className="w-3 h-3 stroke-[3]" />}
                            </div>
                            <div className="w-6 h-6 relative flex-shrink-0">
                              <Image
                                src={resolved.imageUrl}
                                alt={resolved.name}
                                fill
                                unoptimized
                                className="object-contain"
                              />
                            </div>
                            <div className="min-w-0">
                              <p className="text-xs font-bold text-[#0F172A] leading-tight truncate">
                                {resolved.name}
                              </p>
                              <p className="text-[10px] text-slate-500 leading-none truncate">
                                {outOfStock ? 'Out of stock' : resolved.unit}
                              </p>
                            </div>
                          </div>
                          <span className="text-xs font-extrabold text-[#0F172A] tabular-nums shrink-0">
                            {formatInr(resolved.price)}
                          </span>
                        </div>
                      )
                    })}
                  </div>
                </div>

                <button
                  type="button"
                  disabled={breakfastCount === 0}
                  onClick={() => {
                    let addedReal = 0
                    for (const { resolved } of selectedBreakfast) {
                      if (previewMode) {
                        addedReal += 1
                      } else if (resolved.product && resolved.inStock) {
                        addItem(resolved.product, storeId ?? undefined)
                        addedReal += 1
                      }
                    }
                    triggerHaptic('success')
                    if (previewMode) {
                      toast.info(
                        `Preview: Would add ${breakfastCount} breakfast items (${formatInr(breakfastTotal)})`
                      )
                    } else if (addedReal > 0) {
                      toast.success(`🥞 Added ${addedReal} breakfast items to basket!`)
                    } else if (selectedBreakfast[0]) {
                      handleAddResolved(selectedBreakfast[0].resolved)
                    }
                  }}
                  className="mt-3.5 w-full py-2.5 rounded-xl bg-[#15803D] hover:bg-[#166534] disabled:bg-slate-300 text-white text-xs font-extrabold uppercase tracking-wider transition-all cursor-pointer flex items-center justify-center gap-1.5"
                >
                  <span>Add {breakfastCount} items</span>
                  <span>•</span>
                  <span className="tabular-nums">{formatInr(breakfastTotal)}</span>
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </motion.div>
    </section>
  )
}
