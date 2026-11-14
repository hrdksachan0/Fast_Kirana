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

  // Card 01 State (Seasonal Switch-Up)
  const [selectedSeasonalTab, setSelectedSeasonalTab] = useState<string>(
    activeConfig.seasonalSwitchUp?.tabs[0]?.id ?? 'body-lotions'
  )

  // Card 02 State (bloom / Fresh Market)
  const [activeFreshPill, setActiveFreshPill] = useState<string>(
    activeConfig.freshMarket.tabs[0]?.id ?? 'sabzi'
  )
  const [previewQuantities, setPreviewQuantities] = useState<Record<string, number>>({})

  useEffect(() => {
    const sTabs = activeConfig.seasonalSwitchUp?.tabs ?? []
    if (sTabs.length > 0 && !sTabs.some((t) => t.id === selectedSeasonalTab)) {
      setSelectedSeasonalTab(sTabs[0].id)
    }
  }, [activeConfig.seasonalSwitchUp?.tabs, selectedSeasonalTab])

  useEffect(() => {
    const tabs = activeConfig.freshMarket.tabs
    if (tabs.length > 0 && !tabs.some((t) => t.id === activeFreshPill)) {
      setActiveFreshPill(tabs[0].id)
    }
  }, [activeConfig.freshMarket.tabs, activeFreshPill])

  // Card 03 State (Value Picks)
  const [valueActivePairIdx, setValueActivePairIdx] = useState<number>(0)

  // Card 04 State (Gifting Boutique)
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

  // Hide entire section on live storefront (6-Card Bento hidden from web app)
  if (!previewMode) {
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

  const shouldRenderCard = (key: BentoCardKey, cardEnabled: boolean) => {
    if (focusedCard !== 'all' && focusedCard !== key) return false
    if (!cardEnabled && !previewMode) return false
    return true
  }

  // Active Value Picks Pairs (matching Flutter 1kg vs 5kg comparison layout)
  const valuePairs = [
    {
      id: 'atta',
      left: {
        name: 'Whole wheat atta',
        packLabel: '1 kg',
        price: 60,
        unitPriceLabel: '₹60 / kg',
        imageUrl: '/navratri/ref-atta-1kg.png',
        isBetterValue: false,
      },
      right: {
        name: 'Whole wheat atta',
        packLabel: '5 kg',
        price: 250,
        unitPriceLabel: '₹50 / kg',
        imageUrl: '/navratri/ref-atta-5kg.png',
        isBetterValue: true,
      },
      savingLabel: 'Save ₹50 when you pick the 5 kg pack',
    },
  ]
  const currentPair = valuePairs[valueActivePairIdx] ?? valuePairs[0]

  const gridClass =
    focusedCard !== 'all'
      ? 'grid grid-cols-1 max-w-md mx-auto gap-6'
      : 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 gap-6 sm:gap-7'

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
          <span>4-Card Bento section is currently hidden on the live storefront.</span>
        </div>
      )}

      <motion.div
        initial={previewMode ? false : 'hidden'}
        whileInView="visible"
        viewport={{ once: true }}
        className={cn(gridClass, previewMode && !activeConfig.enabled && 'opacity-70')}
      >
        {/* ======================================================== */}
        {/* 01: THE SEASONAL SWITCH-UP (Zepto Wavy Beauty Zone)     */}
        {/* ======================================================== */}
        {shouldRenderCard('seasonalSwitchUp', activeConfig.seasonalSwitchUp?.enabled ?? true) && (
          <div
            className={cn(
              'flex flex-col',
              !(activeConfig.seasonalSwitchUp?.enabled ?? true) && 'opacity-60'
            )}
          >
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>{activeConfig.seasonalSwitchUp?.badge || '01'}</span>
              {!(activeConfig.seasonalSwitchUp?.enabled ?? true) && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>

            <motion.div
              variants={cardVariants}
              className="rounded-[24px] bg-gradient-to-b from-[#D6EEFF] via-[#E9F5FF] to-[#F7FBFF] border-[1.2px] border-[#C0E2FD] overflow-hidden flex flex-col justify-between shadow-[0_4px_18px_rgba(2,132,199,0.06)]"
            >
              <div>
                {/* Wavy Scalloped Top Edge Bar */}
                <div className="h-2.5 w-full bg-[#BFDBFE]/60 overflow-hidden relative">
                  <svg
                    viewBox="0 0 100 10"
                    preserveAspectRatio="none"
                    className="w-full h-full fill-[#D6EEFF]"
                  >
                    <path d="M0,10 Q2.5,0 5,10 Q7.5,0 10,10 Q12.5,0 15,10 Q17.5,0 20,10 Q22.5,0 25,10 Q27.5,0 30,10 Q32.5,0 35,10 Q37.5,0 40,10 Q42.5,0 45,10 Q47.5,0 50,10 Q52.5,0 55,10 Q57.5,0 60,10 Q62.5,0 65,10 Q67.5,0 70,10 Q72.5,0 75,10 Q77.5,0 80,10 Q82.5,0 85,10 Q87.5,0 90,10 Q92.5,0 95,10 Q97.5,0 100,10 L100,0 L0,0 Z" />
                  </svg>
                </div>

                {/* Header Title & Co-Sponsor Subtitle */}
                <div className="pt-2 pb-1 text-center px-4">
                  <h3 className="text-lg font-black text-[#1E3A8A] tracking-tight">
                    {activeConfig.seasonalSwitchUp?.title || 'The Seasonal Switch-Up'}
                  </h3>
                  <div className="flex items-center justify-center gap-1.5 mt-1 text-[9px] font-extrabold text-[#1E40AF]">
                    <span>❄️</span>
                    <span className="w-4 h-[1.2px] bg-gradient-to-r from-transparent to-[#60A5FA]" />
                    <span>POWERED BY</span>
                    <span className="rounded-full bg-[#0060A9] px-1.5 py-0.5 text-white font-black text-[9px]">
                      Cetaphil
                    </span>
                    <span className="font-black text-[#1E3A8A]">DOT & KEY</span>
                    <span className="w-4 h-[1.2px] bg-gradient-to-l from-transparent to-[#60A5FA]" />
                    <span>❄️</span>
                  </div>
                </div>

                {/* Liquid Beauty Sub-Category Connected Tabs */}
                <div className="flex items-center gap-1.5 px-3 pt-3 overflow-x-auto no-scrollbar">
                  {(activeConfig.seasonalSwitchUp?.tabs ?? []).map((tab) => {
                    const isSelected = (selectedSeasonalTab || 'body-lotions') === tab.id
                    return (
                      <button
                        key={tab.id}
                        type="button"
                        onClick={() => setSelectedSeasonalTab(tab.id)}
                        className={cn(
                          'px-3 py-2 rounded-t-xl text-[11px] font-extrabold transition-all flex flex-col items-center gap-0.5 cursor-pointer shrink-0 border-t border-x',
                          isSelected
                            ? 'bg-[#EAF5FF] text-[#0284C7] border-[#93C5FD] shadow-xs translate-y-[1px]'
                            : 'bg-white/70 text-slate-600 border-transparent hover:bg-white'
                        )}
                      >
                        <span className="text-base">{tab.icon}</span>
                        <span className="whitespace-nowrap">{tab.label}</span>
                      </button>
                    )
                  })}
                </div>

                {/* Connected Horizontal Product Cards */}
                <div className="bg-[#EAF5FF] border-t border-[#93C5FD] p-3">
                  <div className="grid grid-cols-2 gap-2.5">
                    {(() => {
                      const curTab =
                        activeConfig.seasonalSwitchUp?.tabs.find(
                          (t) => t.id === selectedSeasonalTab
                        ) ?? activeConfig.seasonalSwitchUp?.tabs[0]
                      const items = curTab?.items ?? []

                      if (items.length === 0) {
                        return (
                          <div className="col-span-2 text-center py-5 text-xs font-semibold text-slate-500 bg-white/70 rounded-xl border border-sky-100">
                            ✨ Real beauty products for {curTab?.label || 'this tab'} will appear from live Ghatampur stock.
                          </div>
                        )
                      }

                      return items.slice(0, 2).map((slot) => {
                        const resolved = resolveBentoSlotProduct(slot, mergedProducts)
                        const qty = getCartQty(resolved)
                        return (
                          <div
                            key={slot.id}
                            className="bg-white rounded-2xl p-2.5 flex flex-col justify-between border border-sky-100 shadow-2xs"
                          >
                            <div className="w-full h-20 relative mb-1.5 flex items-center justify-center p-1">
                              <Image
                                src={resolved.imageUrl}
                                alt={resolved.name}
                                fill
                                unoptimized
                                className="object-contain"
                              />
                            </div>
                            <div>
                              <h4 className="text-[11px] font-extrabold text-[#0F172A] leading-tight truncate">
                                {resolved.name}
                              </h4>
                              <p className="text-[10px] text-slate-500">{resolved.unit}</p>
                              <div className="flex items-center justify-between mt-1.5">
                                <span className="text-xs font-black text-[#0F172A]">
                                  {formatInr(resolved.price)}
                                </span>
                                <button
                                  type="button"
                                  onClick={() => handleAddResolved(resolved)}
                                  className="px-2.5 py-1 rounded-md bg-[#0284C7] hover:bg-[#0369A1] text-white text-[10px] font-extrabold uppercase cursor-pointer"
                                >
                                  {qty > 0 ? `ADD (${qty})` : 'ADD'}
                                </button>
                              </div>
                            </div>
                          </div>
                        )
                      })
                    })()}
                  </div>
                </div>
              </div>

              {/* See All Footer */}
              <div className="p-3 bg-[#EAF5FF]">
                <button
                  type="button"
                  onClick={() => toast.info('Navigates to Beauty & Personal Care category')}
                  className="w-full py-2 rounded-xl bg-white hover:bg-slate-50 border border-sky-200 text-[#0284C7] text-xs font-extrabold flex items-center justify-center gap-1 cursor-pointer"
                >
                  <span>See All</span>
                  <span>▸</span>
                </button>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 02: BLOOM / FRESH MARKET (Fruit Skyline & Floating +)     */}
        {/* ======================================================== */}
        {shouldRenderCard('freshMarket', activeConfig.freshMarket.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.freshMarket.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>{activeConfig.freshMarket.badge || '02'}</span>
              {!activeConfig.freshMarket.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[24px] bg-gradient-to-b from-[#E2EFFF] via-[#EFF6FF] to-[#F4F9FF] border-[1.2px] border-[#CFE4FD] overflow-hidden flex flex-col justify-between shadow-[0_4px_18px_rgba(2,132,199,0.06)]"
            >
              <div>
                {/* Panoramic Fruit Skyline Header with Cloud "bloom" */}
                <div className="relative w-full h-24 overflow-hidden bg-gradient-to-r from-sky-400 to-sky-200">
                  <Image
                    src={activeConfig.freshMarket.headerImage || '/navratri/bloom-panoramic-header.svg'}
                    alt="bloom fresh market"
                    fill
                    unoptimized
                    className="object-cover"
                  />
                  <div className="absolute inset-0 flex items-center justify-center">
                    <span className="font-black text-3xl text-white tracking-tight drop-shadow-[0_2px_4px_rgba(2,132,199,0.4)]">
                      {activeConfig.freshMarket.title || 'bloom'}
                    </span>
                  </div>
                </div>

                {/* Filter Pills: Sabzi | Fruits | Herbs */}
                <div className="flex items-center gap-2 px-3 pt-3 overflow-x-auto no-scrollbar">
                  {activeConfig.freshMarket.tabs.map((tab) => {
                    const isActive = currentFreshTab?.id === tab.id
                    return (
                      <button
                        key={tab.id}
                        type="button"
                        onClick={() => setActiveFreshPill(tab.id)}
                        className={cn(
                          'px-3 py-1 rounded-full text-xs font-bold transition-all flex items-center gap-1 cursor-pointer select-none whitespace-nowrap',
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

                {/* Produce Product Cards with "select >" Bronze Badge & Floating Pink '+' */}
                <div className="p-3">
                  <div className="grid grid-cols-2 gap-2.5">
                    {(currentFreshTab?.items ?? []).slice(0, 2).map((slot) => {
                      const resolved = resolveBentoSlotProduct(slot, mergedProducts)
                      const qty = getCartQty(resolved)
                      const discountAmount =
                        resolved.mrp > resolved.price ? Math.round(resolved.mrp - resolved.price) : 0

                      return (
                        <div
                          key={slot.id}
                          className="bg-white rounded-2xl p-2.5 flex flex-col justify-between border border-slate-200/90 shadow-2xs relative"
                        >
                          <div className="w-full h-24 relative mb-1.5 flex items-center justify-center bg-[#F8FAFC] rounded-xl p-1">
                            {/* "select >" Bronze Pill */}
                            <span className="absolute top-1.5 left-1.5 rounded bg-[#78350F] px-1.5 py-0.5 text-[8.5px] font-black text-white">
                              select &gt;
                            </span>
                            <Image
                              src={resolved.imageUrl}
                              alt={resolved.name}
                              fill
                              unoptimized
                              className="object-contain p-2"
                            />
                            {/* Signature Floating Pink '+' Button */}
                            <button
                              type="button"
                              onClick={() => handleAddResolved(resolved)}
                              className="absolute -bottom-2 -right-1 h-7 w-7 rounded-lg bg-white border border-[#DB2777] text-[#DB2777] hover:bg-pink-50 flex items-center justify-center font-black text-sm shadow-xs cursor-pointer"
                            >
                              {qty > 0 ? qty : '+'}
                            </button>
                          </div>

                          <div className="pt-1">
                            <div className="flex items-center gap-1">
                              <span className="rounded bg-[#16A34A] px-1.5 py-0.5 text-[10px] font-black text-white">
                                {formatInr(resolved.price)}
                              </span>
                              {resolved.mrp > resolved.price && (
                                <span className="text-[10px] text-slate-400 line-through">
                                  {formatInr(resolved.mrp)}
                                </span>
                              )}
                            </div>
                            {discountAmount > 0 && (
                              <p className="text-[9px] font-black text-[#16A34A] mt-0.5">
                                ₹{discountAmount} OFF
                              </p>
                            )}
                            <h4 className="text-[11px] font-extrabold text-[#0F172A] leading-tight truncate mt-1">
                              {resolved.name}
                            </h4>
                            <p className="text-[10px] text-slate-500">{resolved.unit}</p>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              </div>

              {/* See All Footer */}
              <div className="p-3 pt-0">
                <button
                  type="button"
                  onClick={() => toast.info('Navigates to Fruits & Vegetables category')}
                  className="w-full py-2 rounded-xl bg-white hover:bg-slate-50 border border-slate-200 text-slate-900 text-xs font-extrabold flex items-center justify-center gap-1 cursor-pointer shadow-xs"
                >
                  <span>See All</span>
                  <span>▸</span>
                </button>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 03: VALUE PICKS (1kg vs 5kg Comparison Card)             */}
        {/* ======================================================== */}
        {shouldRenderCard('valuePicks', activeConfig.valuePicks.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.valuePicks.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>{activeConfig.valuePicks.badge || '03'}</span>
              {!activeConfig.valuePicks.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[27px] bg-[#F9EFB6] border border-[#F0E3A2] p-4 flex flex-col justify-between shadow-[0_4px_16px_rgba(202,138,4,0.06)]"
            >
              <div>
                {/* Eyebrow & See All */}
                <div className="flex items-center justify-between mb-1 text-[9px] font-black tracking-wider text-[#8C7D3D]">
                  <span className="flex items-center gap-1">
                    <span>✨</span>
                    <span>THE EVERYDAY EDIT</span>
                  </span>
                  <span className="rounded-full bg-white/70 px-2 py-0.5 text-[#29422F]">
                    See all 10 ↗
                  </span>
                </div>

                {/* Title & "PICK SMART EVERY DAY" Rotating Badge */}
                <div className="flex items-center justify-between gap-2 mt-1">
                  <div>
                    <h3 className="text-2xl font-black text-[#29422F] tracking-tight font-serif">
                      Value <span className="italic font-normal">Picks</span>
                    </h3>
                    <p className="text-[11px] text-[#8A8054] font-medium">
                      Stock up on good. Spend a little less.
                    </p>
                  </div>
                  <div className="w-12 h-12 rounded-full bg-[#365B38] text-[#FFF6C7] flex flex-col items-center justify-center text-[6px] font-black tracking-tight shrink-0 shadow-xs rotate-6">
                    <span>🛍️</span>
                    <span>PICK SMART</span>
                    <span>EVERY DAY</span>
                  </div>
                </div>

                {/* Dual Pack Comparison (Standard vs Better Value Saver) */}
                <div className="grid grid-cols-2 gap-2.5 mt-3">
                  {/* Left: Standard Pack */}
                  <div className="bg-[#FFFFFA] rounded-2xl p-2.5 border border-[#E9E7D6] flex flex-col justify-between">
                    <span className="text-[9px] font-bold text-[#89917C] uppercase tracking-wide">
                      THE DAILY PICK
                    </span>
                    <div className="w-full h-20 relative my-1 bg-[#F7F7EF] rounded-xl flex items-center justify-center p-1">
                      <Image
                        src={currentPair.left.imageUrl}
                        alt={currentPair.left.name}
                        fill
                        unoptimized
                        className="object-contain p-1"
                      />
                      <span className="absolute bottom-1 left-1 rounded bg-white/95 px-1.5 py-0.5 text-[9px] font-bold text-[#687359]">
                        {currentPair.left.packLabel}
                      </span>
                    </div>
                    <div>
                      <h5 className="text-[11px] font-bold text-[#29422F] truncate">
                        {currentPair.left.name}
                      </h5>
                      <p className="text-base font-extrabold text-[#29422F] leading-tight">
                        ₹{currentPair.left.price}
                      </p>
                      <p className="text-[9.5px] text-[#89917C]">{currentPair.left.unitPriceLabel}</p>
                      <button
                        type="button"
                        onClick={() => toast.success(`Added ${currentPair.left.name} (${currentPair.left.packLabel})`)}
                        className="w-full mt-2 py-1 rounded-lg border border-[#365B38] text-[#365B38] hover:bg-[#365B38] hover:text-white text-[11px] font-extrabold transition-colors cursor-pointer"
                      >
                        ADD +
                      </button>
                    </div>
                  </div>

                  {/* Right: Value Pack (Better Value) */}
                  <div className="bg-[#FFFFFA] rounded-2xl p-2.5 border-[1.4px] border-[#BECAA7] flex flex-col justify-between shadow-xs">
                    <span className="text-[9px] font-black text-[#365B38] uppercase tracking-wide flex items-center gap-1 bg-[#ECF3E5] px-1.5 py-0.5 rounded">
                      <span>✨</span> BETTER VALUE
                    </span>
                    <div className="w-full h-20 relative my-1 bg-[#F3F6ED] rounded-xl flex items-center justify-center p-1">
                      <Image
                        src={currentPair.right.imageUrl}
                        alt={currentPair.right.name}
                        fill
                        unoptimized
                        className="object-contain p-1"
                      />
                      <span className="absolute bottom-1 left-1 rounded bg-white/95 px-1.5 py-0.5 text-[9px] font-bold text-[#687359]">
                        {currentPair.right.packLabel}
                      </span>
                    </div>
                    <div>
                      <h5 className="text-[11px] font-bold text-[#29422F] truncate">
                        {currentPair.right.name}
                      </h5>
                      <p className="text-base font-black text-[#29422F] leading-tight">
                        ₹{currentPair.right.price}
                      </p>
                      <p className="text-[9.5px] font-bold text-[#5E8250]">{currentPair.right.unitPriceLabel}</p>
                      <button
                        type="button"
                        onClick={() => toast.success(`Added ${currentPair.right.name} (${currentPair.right.packLabel}) - Better Value!`)}
                        className="w-full mt-2 py-1 rounded-lg bg-[#365B38] hover:bg-[#2A472C] text-white text-[11px] font-extrabold shadow-xs transition-colors cursor-pointer"
                      >
                        ADD +
                      </button>
                    </div>
                  </div>
                </div>

                {/* Saving Ribbon */}
                <div className="mt-3 flex items-center justify-center gap-1.5 text-center text-[10px] font-bold text-[#758040] bg-white/60 py-1 px-2 rounded-full border border-[#E9DFA8]">
                  <span>🛡️</span>
                  <span>{currentPair.savingLabel}</span>
                </div>
              </div>
            </motion.div>
          </div>
        )}

        {/* ======================================================== */}
        {/* 04: GIFTING BOUTIQUE (224px Luxury Hero Card)           */}
        {/* ======================================================== */}
        {shouldRenderCard('giftingBoutique', activeConfig.giftingBoutique.enabled) && (
          <div className={cn('flex flex-col', !activeConfig.giftingBoutique.enabled && 'opacity-60')}>
            <span className="text-sm font-extrabold text-slate-500 mb-1 pl-1 flex items-center gap-2">
              <span>{activeConfig.giftingBoutique.badge || '04'}</span>
              {!activeConfig.giftingBoutique.enabled && (
                <span className="text-[10px] rounded bg-slate-200 px-1.5 py-0.5 text-slate-600">
                  Hidden
                </span>
              )}
            </span>
            <motion.div
              variants={cardVariants}
              className="rounded-[24px] bg-gradient-to-br from-[#FDECEF] to-[#F9D8E0] border-[1.2px] border-[#EFC6D0] h-[224px] relative overflow-hidden shadow-[0_6px_20px_rgba(136,19,55,0.07)] cursor-pointer group"
              onClick={() => toast.info('Navigates to Gifting Boutique / Send Gift')}
            >
              {/* Full-bleed HD Gifting Boutique Hero Artwork */}
              <div className="absolute inset-0">
                <Image
                  src="/navratri/gifting-boutique-hero-hd.jpg"
                  alt="Gifting Boutique"
                  fill
                  unoptimized
                  className="object-cover object-right"
                />
              </div>

              {/* Left-Side Editorial Content */}
              <div className="relative h-full flex flex-col justify-between p-5 z-10 max-w-[62%]">
                <div>
                  <span className="rounded-full bg-[#6B1728] px-3 py-1 text-[10px] font-bold tracking-wide text-white">
                    GIFTING BOUTIQUE
                  </span>
                  <h3 className="text-2xl font-bold text-[#52101F] tracking-tight leading-tight mt-2.5 font-serif">
                    Little things,<br />big feelings.
                  </h3>
                  <p className="text-[11px] text-[#7D4856] font-medium mt-1 leading-snug">
                    Flowers, cakes &amp;<br />thoughtful surprises.
                  </p>
                </div>

                <div>
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-[#6B1728] px-4 py-2 text-xs font-bold text-white shadow-md group-hover:scale-105 transition-transform">
                    <span>Explore Gifts</span>
                    <span>→</span>
                  </span>
                </div>
              </div>
            </motion.div>
          </div>
        )}

      </motion.div>
    </section>
  )
}
