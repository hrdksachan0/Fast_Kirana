'use client'

import { useUIStore } from '@/stores/ui-store'
import { useCart } from '@/hooks/use-cart'
import { X, Plus, Minus, Check } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import React, { useMemo, useEffect, useState, Component, ErrorInfo, ReactNode } from 'react'
import { cn, isCafeProduct, getProductLimit, isProductStoreClosed } from '@/lib/utils'
import { ProductImage } from '@/components/product/product-image'
import { useLiveStock } from '@/components/providers/live-stock-provider'
import { Product } from '@/types'
import { toast } from 'sonner'

class DrawerErrorBoundary extends Component<{ onClose: () => void; children: ReactNode }, { hasError: boolean }> {
  state = { hasError: false }

  static getDerivedStateFromError() {
    return { hasError: true }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('VariantSelectorDrawer Error:', error, errorInfo)
    toast.error('Could not load product options. Please try again.')
    this.props.onClose()
  }

  render() {
    if (this.state.hasError) return null
    return this.props.children
  }
}

function isVegProduct(p: any): boolean {
  if (!p) return true
  const rawTags = Array.isArray(p.tags)
    ? p.tags
    : typeof p.tags === 'string'
    ? p.tags.split(',')
    : []
  const tags = rawTags
    .filter((t: any) => typeof t === 'string')
    .map((t: string) => t.trim().toLowerCase())

  if (
    tags.some((t: string) =>
      t.includes('non-veg') ||
      t.includes('nonveg') ||
      t === 'egg' ||
      t.includes('chicken') ||
      t.includes('mutton') ||
      t.includes('fish')
    )
  ) {
    return false
  }
  const nl = String(p.name || '').toLowerCase()
  if (nl.includes('chicken') || nl.includes('egg') || nl.includes('mutton') || nl.includes('fish')) {
    return false
  }
  return true
}

function VegNonVegBadge({ isVeg, size = 15 }: { isVeg: boolean; size?: number }) {
  const color = isVeg ? '#00875A' : '#DC2626'
  return (
    <div
      className="rounded-[3.5px] border-[1.4px] bg-white flex items-center justify-center shrink-0"
      style={{ width: size, height: size, borderColor: color }}
    >
      {isVeg ? (
        <div
          className="rounded-full"
          style={{ width: size * 0.45, height: size * 0.45, backgroundColor: color }}
        />
      ) : (
        <div
          className="w-0 h-0 border-l-[3.5px] border-l-transparent border-r-[3.5px] border-r-transparent border-b-[6px]"
          style={{ borderBottomColor: color }}
        />
      )}
    </div>
  )
}

interface GroceryVariantCardProps {
  variant: any
  product: Product
  cafeOpen: boolean
  groceryMartOpen: boolean
  restaurantOpen: boolean
}

function GroceryVariantCard({
  variant,
  product,
  cafeOpen,
  groceryMartOpen,
  restaurantOpen,
}: GroceryVariantCardProps) {
  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const resolvedName = String(variant?.name || variant?.title || variant?.unit || 'Option')
  const resolvedId = `${product.id}_${resolvedName}`
  const quantity = getItemQuantity(resolvedId)

  const liveState = useLiveStock(resolvedId)
  const baseStock = variant?.stock !== undefined ? Number(variant.stock) : Number(product.stock ?? 10)
  const basePrice = Number(variant?.price) || Number(product.price) || 0
  const baseMrp = Number(variant?.mrp) || Number(product.mrp) || basePrice

  const resolvedStock = liveState !== null ? Number(liveState.stock) : baseStock
  const resolvedPrice = liveState !== null ? Number(liveState.price) : basePrice
  const resolvedMrp = liveState !== null ? Number(liveState.mrp) : baseMrp
  const resolvedIsAvailable = liveState !== null ? Boolean(liveState.isAvailable) : (product.isAvailable ?? true)

  const discount =
    resolvedMrp > resolvedPrice && resolvedMrp > 0
      ? Math.max(0, Math.round(((resolvedMrp - resolvedPrice) / resolvedMrp) * 100))
      : 0

  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const isStoreClosed = isProductStoreClosed(
    product,
    { groceryMartOpen, cafeOpen, restaurantOpen },
    categoryStatus
  )

  const cartProduct = useMemo(
    () => ({
      id: resolvedId,
      name: `${product.name} (${resolvedName})`,
      slug: product.slug,
      imageUrl: product.imageUrl,
      mrp: resolvedMrp,
      price: resolvedPrice,
      discount: discount,
      unit: resolvedName || product.unit,
      stock: resolvedStock,
      isAvailable: resolvedIsAvailable,
      category: product.category,
      tags: product.tags,
      restaurantId: (product as any).restaurantId || (product as any).restaurant?.id,
      restaurantName: (product as any).restaurantName || (product as any).restaurant?.name,
      restaurant: (product as any).restaurant,
    }),
    [product, resolvedName, resolvedId, resolvedMrp, resolvedPrice, discount, resolvedStock, resolvedIsAvailable]
  )

  const isVariantSoldOut =
    (typeof resolvedStock === 'number' ? resolvedStock : 0) <= 0 || resolvedIsAvailable === false

  const handleAdd = () => {
    if (isVariantSoldOut) {
      toast.error(`Sorry, ${cartProduct.name} is currently out of stock!`)
      return
    }
    addItem(cartProduct)
  }

  const handleIncrement = () => {
    if (isVariantSoldOut) {
      toast.error(`Sorry, ${cartProduct.name} is currently out of stock!`)
      return
    }
    updateQuantity(resolvedId, cartProduct.name, quantity + 1)
  }

  const handleDecrement = () => {
    updateQuantity(resolvedId, cartProduct.name, quantity - 1)
  }

  const isSelected = quantity > 0

  return (
    <div
      className={cn(
        'flex items-center justify-between p-3.5 sm:p-4 rounded-2xl transition-all duration-200 bg-white border',
        isSelected
          ? 'border-[#00875a] shadow-2xs'
          : 'border-zinc-200/90 hover:border-zinc-300 shadow-2xs'
      )}
    >
      {/* Left Column: Variant Name & Price Breakdown */}
      <div className="flex-1 min-w-0 pr-3 text-left">
        <span className="text-sm sm:text-[15px] font-extrabold text-zinc-900 truncate block">
          {variant.name}
        </span>
        <div className="flex items-center gap-1.5 mt-1 flex-wrap">
          <span className="text-base sm:text-[16px] font-black text-zinc-900">
            ₹{resolvedPrice}
          </span>
          {resolvedMrp > resolvedPrice && (
            <span className="text-xs text-zinc-400 line-through font-semibold">
              ₹{resolvedMrp}
            </span>
          )}
          {discount > 0 && (
            <span className="text-[11px] sm:text-xs font-black text-red-600">
              {discount}% OFF
            </span>
          )}
        </div>
      </div>

      {/* Right Column: Solid Green ADD Button or Stepper (Image 2 UI) */}
      <div className="relative h-9 w-24 shrink-0">
        {isVariantSoldOut ? (
          <div className="w-full h-full bg-zinc-100 text-zinc-400 text-xs font-bold rounded-xl border border-zinc-200 flex items-center justify-center select-none cursor-not-allowed">
            Sold Out
          </div>
        ) : isStoreClosed ? (
          <div className="w-full h-full bg-zinc-100 text-zinc-400 text-xs font-bold rounded-xl border border-zinc-200 flex items-center justify-center select-none cursor-not-allowed">
            Closed
          </div>
        ) : quantity === 0 ? (
          <button
            onClick={handleAdd}
            className="w-full h-full bg-[#00875a] hover:bg-[#00704a] text-white text-xs sm:text-[13px] font-black rounded-xl transition-all duration-150 flex items-center justify-center cursor-pointer shadow-xs active:scale-95"
          >
            ADD
          </button>
        ) : (
          <div className="flex h-full w-full items-center justify-between rounded-xl bg-[#00875a] text-white font-bold overflow-hidden shadow-xs">
            <button
              onClick={handleDecrement}
              className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all cursor-pointer"
              aria-label="Decrease quantity"
            >
              <Minus className="h-3.5 w-3.5 stroke-[3]" />
            </button>
            <span className="w-5 shrink-0 flex items-center justify-center text-xs sm:text-sm font-black select-none">
              {quantity}
            </span>
            <button
              onClick={handleIncrement}
              disabled={quantity >= resolvedStock || quantity >= getProductLimit(product)}
              className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all disabled:opacity-50 cursor-pointer"
              aria-label="Increase quantity"
            >
              <Plus className="h-3.5 w-3.5 stroke-[3]" />
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

export function VariantSelectorDrawer() {
  const activeProduct = useUIStore((s) => s.activeVariantProduct)
  const setActiveProduct = useUIStore((s) => s.setActiveVariantProduct)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}

  const { addItem, updateQuantity } = useCart()

  // Restaurant Food customization state
  const [selectedVariantIndex, setSelectedVariantIndex] = useState(0)
  const [foodQuantity, setFoodQuantity] = useState(1)
  const [selectedAddons, setSelectedAddons] = useState<Record<string, string[]>>({})

  const isOpen = activeProduct !== null
  const isFood = activeProduct ? isCafeProduct(activeProduct) : false

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
      setSelectedVariantIndex(0)
      setFoodQuantity(1)
      setSelectedAddons({})
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  const variantsList = useMemo(() => {
    if (!activeProduct || !activeProduct.variants) return []
    let list: any[] = []
    if (Array.isArray(activeProduct.variants)) {
      list = [...activeProduct.variants]
    } else if (typeof activeProduct.variants === 'string') {
      try {
        const parsed = JSON.parse(activeProduct.variants)
        if (Array.isArray(parsed)) list = parsed
      } catch {}
    }
    return list
      .filter((v) => v && typeof v === 'object')
      .map((v, i) => {
        const name = String(v.name || v.title || v.unit || `Option ${i + 1}`)
        const price = Number(v.price) || Number(activeProduct.price) || 0
        const mrp = Number(v.mrp) || Number(v.price) || Number(activeProduct.mrp) || price
        const stock = v.stock !== undefined ? Number(v.stock) : Number(activeProduct.stock ?? 10)
        return { ...v, name, price, mrp, stock }
      })
      .sort((a, b) => (Number(a.price) || 0) - (Number(b.price) || 0))
  }, [activeProduct])

  const addonGroups: { title: string; required: boolean; maxSelect: number; items: { name: string; price: number }[] }[] = useMemo(() => {
    if (!activeProduct || !(activeProduct as any).addons) return []
    let raw = (activeProduct as any).addons
    if (typeof raw === 'string') {
      try {
        raw = JSON.parse(raw)
      } catch {
        return []
      }
    }
    if (Array.isArray(raw)) {
      return raw.map((g: any) => ({
        title: String(g.title || ''),
        required: g.required === true,
        maxSelect: Number(g.maxSelect) || 5,
        items: Array.isArray(g.items)
          ? g.items.map((i: any) => ({
              name: String(i?.name || ''),
              price: Number(i?.price) || 0,
            }))
          : [],
      }))
    }
    return []
  }, [activeProduct])

  if (!isOpen || !activeProduct) return null

  const isStoreClosed = isProductStoreClosed(
    activeProduct,
    { groceryMartOpen, cafeOpen, restaurantOpen },
    categoryStatus
  )

  // Calculate addon total
  const selectedAddonList = useMemo(() => {
    const list: { name: string; price: number }[] = []
    addonGroups.forEach((g) => {
      const selected = selectedAddons[g.title] || []
      g.items.forEach((item) => {
        if (selected.includes(item.name)) {
          list.push(item)
        }
      })
    })
    return list
  }, [addonGroups, selectedAddons])

  const addonTotalPerUnit = selectedAddonList.reduce((sum, item) => sum + item.price, 0)

  // Handlers for Food customization flow
  const safeVariantIndex = Math.min(selectedVariantIndex, Math.max(0, variantsList.length - 1))
  const currentVariant = variantsList[safeVariantIndex] || variantsList[0] || {}
  const baseVariantPrice = Number(currentVariant.price) || Number(activeProduct.price) || 0
  const baseVariantMrp = Number(currentVariant.mrp) || Number(activeProduct.mrp) || baseVariantPrice
  const currentPrice = (baseVariantPrice + addonTotalPerUnit) * foodQuantity
  const currentMrp = (baseVariantMrp + addonTotalPerUnit) * foodQuantity
  const hasDiscount = currentMrp > currentPrice

  const handleAddFoodItem = () => {
    if (!currentVariant || isStoreClosed) return

    // Validate required addon groups
    for (const group of addonGroups) {
      if (group.required) {
        const selected = selectedAddons[group.title] || []
        if (selected.length === 0) {
          toast.error(`Please select an option for "${group.title}"`)
          return
        }
      }
    }

    const addonSuffix =
      selectedAddonList.length > 0
        ? ` + ${selectedAddonList.map((a) => a.name).join(', ')}`
        : ''
    const addonIdSuffix =
      selectedAddonList.length > 0
        ? `_addons_${selectedAddonList.map((a) => a.name.replace(/\s+/g, '-')).join('_')}`
        : ''

    const resolvedId = `${activeProduct.id}_${currentVariant.name || 'default'}${addonIdSuffix}`
    const finalUnitPrice = baseVariantPrice + addonTotalPerUnit
    const finalUnitMrp = baseVariantMrp + addonTotalPerUnit
    const discount =
      finalUnitMrp > finalUnitPrice
        ? Math.max(0, Math.round(((finalUnitMrp - finalUnitPrice) / finalUnitMrp) * 100))
        : 0

    const cartProduct = {
      id: resolvedId,
      name: `${activeProduct.name} (${currentVariant.name || 'Regular'})${addonSuffix}`,
      slug: activeProduct.slug,
      imageUrl: activeProduct.imageUrl,
      mrp: finalUnitMrp,
      price: finalUnitPrice,
      discount: discount,
      unit: currentVariant.name || activeProduct.unit,
      stock: currentVariant.stock ?? activeProduct.stock,
      isAvailable: activeProduct.isAvailable ?? true,
      category: activeProduct.category,
      tags: activeProduct.tags,
      restaurantId: (activeProduct as any).restaurantId || (activeProduct as any).restaurant?.id,
      restaurantName: (activeProduct as any).restaurantName || (activeProduct as any).restaurant?.name,
      restaurant: (activeProduct as any).restaurant,
      selectedAddons: selectedAddonList,
    }

    addItem(cartProduct)
    if (foodQuantity > 1) {
      updateQuantity(resolvedId, cartProduct.name, foodQuantity)
    }
    setActiveProduct(null)
  }

  const isVeg = isVegProduct(activeProduct)
  const minPrice = variantsList.length > 0 ? variantsList[0].price : activeProduct.price

  return (
    <DrawerErrorBoundary onClose={() => setActiveProduct(null)}>
      <AnimatePresence>
        <div className="fixed inset-0 z-50 flex items-end justify-center select-none">
          {/* Dark Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-xs cursor-pointer"
            onClick={() => setActiveProduct(null)}
          />

          {/* ========================================================================= */}
          {/* 1. RESTAURANT / FOOD CUSTOMIZATION MODAL (Swiggy / Image 1 UI)           */}
          {/* ========================================================================= */}
          {isFood ? (
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 26, stiffness: 240 }}
              className="gpu-accelerated relative w-full max-w-md flex flex-col max-h-[85dvh] md:max-h-[85vh] overflow-visible"
            >
              {/* Floating Dark Circular Close Button above sheet (Image 1) */}
              <button
                onClick={() => setActiveProduct(null)}
                className="self-center mb-2.5 w-9 h-9 rounded-full bg-[#2b2f38] hover:bg-[#3b3f48] text-white flex items-center justify-center shadow-lg transition-all cursor-pointer shrink-0 z-10"
                aria-label="Close"
              >
                <X className="w-5 h-5" />
              </button>

              {/* Modal Body Card */}
              <div className="w-full bg-[#f8f9fa] border-t border-zinc-200 rounded-t-3xl shadow-2xl flex flex-col flex-1 overflow-hidden">
                {/* Product Info Header */}
                <div className="bg-white p-4 border-b border-zinc-200 flex items-center gap-3 shrink-0">
                  <div className="h-12 w-12 rounded-xl bg-zinc-100 border border-zinc-200 p-1 flex items-center justify-center shrink-0 overflow-hidden">
                    <ProductImage
                      src={activeProduct.imageUrl}
                      alt={activeProduct.name || ''}
                      categorySlug={activeProduct.category?.slug}
                      className="h-full w-full object-contain"
                    />
                  </div>
                  <div className="flex-1 min-w-0 text-left">
                    <h3 className="text-base font-extrabold text-zinc-900 leading-tight truncate">
                      {activeProduct.name}
                    </h3>
                  </div>
                </div>

                {/* Scrollable Customization Content */}
                <div className="p-4 flex-1 overflow-y-auto space-y-3">
                  {variantsList.length > 0 && (
                    <>
                      <div className="text-left">
                        <h4 className="text-[15px] font-extrabold text-zinc-900">Choose Option</h4>
                        <p className="text-xs text-zinc-500 font-medium mt-0.5">Select any 1</p>
                      </div>

                      {/* Options Box (White Card with Radio Rows - Image 1) */}
                      <div className="bg-white rounded-2xl border border-zinc-200/90 shadow-2xs divide-y divide-zinc-100 overflow-hidden">
                    {variantsList.map((v, index) => {
                      const isSelected = index === safeVariantIndex
                      return (
                        <div
                          key={v.name || `variant-${index}`}
                          onClick={() => setSelectedVariantIndex(index)}
                          className="flex items-center justify-between p-3.5 sm:p-4 hover:bg-zinc-50/70 cursor-pointer transition-colors"
                        >
                        <div className="flex items-center gap-2.5 min-w-0 pr-2">
                          <VegNonVegBadge isVeg={isVeg} size={15} />
                          <span className="text-sm font-semibold text-zinc-900 truncate">
                            {v.name}
                          </span>
                        </div>

                        <div className="flex items-center gap-3 shrink-0">
                          {Number(v.price) > 0 && (
                            <span className="text-xs sm:text-sm font-semibold text-zinc-600">
                              ₹{v.price}
                            </span>
                          )}

                          {/* Radio Selector Circle (Image 1) */}
                          <div
                            className={cn(
                              'w-5 h-5 rounded-full border flex items-center justify-center transition-all',
                              isSelected
                                ? 'border-[#00875a] border-2'
                                : 'border-zinc-400 border-[1.5px]'
                            )}
                          >
                            {isSelected && (
                              <div className="w-2.5 h-2.5 rounded-full bg-[#00875a]" />
                            )}
                          </div>
                        </div>
                      </div>
                    )
                  })}
                </div>
                  </>
                )}

                {/* Add-on / Extras Groups */}
                {addonGroups.map((group) => {
                  const selected = selectedAddons[group.title] || []
                  const isRadio = group.maxSelect === 1

                  return (
                    <div key={group.title} className="space-y-2 pt-1">
                      <div className="text-left">
                        <h4 className="text-[15px] font-extrabold text-zinc-900">
                          {group.title}
                        </h4>
                        <p className="text-xs text-zinc-500 font-medium mt-0.5">
                          {isRadio
                            ? `Select any 1${group.required ? ' (Required)' : ''}`
                            : `Select upto ${group.maxSelect}${group.required ? ' (Required)' : ''}`}
                        </p>
                      </div>

                      <div className="bg-white rounded-2xl border border-zinc-200/90 shadow-2xs divide-y divide-zinc-100 overflow-hidden">
                        {group.items.map((item) => {
                          const isChecked = selected.includes(item.name)

                          const handleToggle = () => {
                            setSelectedAddons((prev) => {
                              const curr = prev[group.title] || []
                              if (isRadio) {
                                if (curr.includes(item.name)) {
                                  return { ...prev, [group.title]: [] }
                                }
                                return { ...prev, [group.title]: [item.name] }
                              } else {
                                if (curr.includes(item.name)) {
                                  return {
                                    ...prev,
                                    [group.title]: curr.filter((name) => name !== item.name),
                                  }
                                }
                                if (curr.length < group.maxSelect) {
                                  return { ...prev, [group.title]: [...curr, item.name] }
                                }
                                return prev
                              }
                            })
                          }

                          return (
                            <div
                              key={item.name}
                              onClick={handleToggle}
                              className="flex items-center justify-between p-3.5 sm:p-4 hover:bg-zinc-50/70 cursor-pointer transition-colors"
                            >
                              <span className="text-sm font-semibold text-zinc-900 truncate">
                                {item.name}
                              </span>

                              <div className="flex items-center gap-3 shrink-0">
                                {item.price > 0 ? (
                                  <span className="text-xs sm:text-sm font-semibold text-zinc-600">
                                    + ₹{item.price}
                                  </span>
                                ) : (
                                  <span className="text-xs font-bold text-emerald-600">
                                    Free
                                  </span>
                                )}

                                {isRadio ? (
                                  <div
                                    className={cn(
                                      'w-5 h-5 rounded-full border flex items-center justify-center transition-all',
                                      isChecked
                                        ? 'border-[#00875a] border-2'
                                        : 'border-zinc-400 border-[1.5px]'
                                    )}
                                  >
                                    {isChecked && (
                                      <div className="w-2.5 h-2.5 rounded-full bg-[#00875a]" />
                                    )}
                                  </div>
                                ) : (
                                  <div
                                    className={cn(
                                      'w-5 h-5 rounded-md border flex items-center justify-center transition-all',
                                      isChecked
                                        ? 'bg-[#00875a] border-[#00875a]'
                                        : 'border-zinc-400 border-[1.5px] bg-white'
                                    )}
                                  >
                                    {isChecked && (
                                      <Check className="w-3.5 h-3.5 text-white stroke-[3]" />
                                    )}
                                  </div>
                                )}
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    </div>
                  )
                })}
              </div>

              {/* Sticky Bottom Bar with Stepper & Add Item Button (Image 1) */}
              <div className="bg-white border-t border-zinc-200 p-4 shrink-0 flex items-center gap-3">
                {/* Stepper [- 1 +] */}
                <div className="h-11 px-1 rounded-xl border border-zinc-300 bg-white flex items-center shrink-0">
                  <button
                    onClick={() => setFoodQuantity(Math.max(1, foodQuantity - 1))}
                    disabled={foodQuantity <= 1}
                    className="w-8 h-full flex items-center justify-center text-[#00875a] disabled:text-zinc-300 hover:bg-zinc-50 rounded-lg transition-colors cursor-pointer"
                  >
                    <Minus className="w-4 h-4 stroke-[2.5]" />
                  </button>
                  <span className="w-6 text-center text-sm font-extrabold text-[#00875a]">
                    {foodQuantity}
                  </span>
                  <button
                    onClick={() => setFoodQuantity(foodQuantity + 1)}
                    className="w-8 h-full flex items-center justify-center text-[#00875a] hover:bg-zinc-50 rounded-lg transition-colors cursor-pointer"
                  >
                    <Plus className="w-4 h-4 stroke-[2.5]" />
                  </button>
                </div>

                {/* Add Item Button */}
                <button
                  onClick={handleAddFoodItem}
                  disabled={isStoreClosed}
                  className="flex-1 h-11 rounded-xl bg-[#00875a] hover:bg-[#00704a] text-white font-extrabold text-sm flex items-center justify-center gap-1.5 shadow-sm active:scale-[0.98] transition-all cursor-pointer disabled:opacity-50"
                >
                  <span>
                    {isStoreClosed ? 'Store Closed' : `Add Item | ₹${currentPrice}`}
                  </span>
                  {hasDiscount && !isStoreClosed && (
                    <span className="text-xs text-white/70 line-through font-normal">
                      ₹{currentMrp}
                    </span>
                  )}
                </button>
              </div>
            </div>
          </motion.div>
        ) : (
          /* ========================================================================= */
          /* 2. GROCERY PACK SIZE DRAWER (Zepto / Blinkit / Image 2 UI)               */
          /* ========================================================================= */
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 220 }}
            className="gpu-accelerated relative w-full max-w-md bg-white border-t border-zinc-200 rounded-t-3xl shadow-2xl flex flex-col max-h-[82dvh] md:max-h-[82vh] overflow-hidden"
          >
            {/* Header Drag Handle (Image 2) */}
            <div className="w-11 h-1.5 bg-zinc-300 rounded-full mx-auto my-2.5 shrink-0" />

            {/* Product Header (Image 2) */}
            <div className="px-4 py-2 flex items-center justify-between gap-3 border-b border-zinc-100 shrink-0">
              <div className="flex items-center gap-3 min-w-0">
                <div className="relative h-14 w-14 rounded-xl border border-zinc-200 bg-zinc-50 p-1 flex-shrink-0 flex items-center justify-center overflow-hidden">
                  <ProductImage
                    src={activeProduct.imageUrl}
                    alt={activeProduct.name}
                    categorySlug={activeProduct.category?.slug}
                    className="h-full w-full object-contain"
                  />
                </div>
                <div className="flex-1 min-w-0 text-left">
                  <h3 className="text-base font-extrabold text-zinc-900 leading-tight truncate">
                    {activeProduct.name}
                  </h3>
                  <span className="text-xs text-zinc-500 font-semibold block mt-0.5">
                    {variantsList.length > 0
                      ? `${variantsList.length} Options (from ₹${minPrice})`
                      : activeProduct.unit || 'Options available'}
                  </span>
                </div>
              </div>

              {/* Close Button 'X' (Image 2) */}
              <button
                onClick={() => setActiveProduct(null)}
                className="p-1.5 rounded-full text-zinc-400 hover:text-zinc-700 hover:bg-zinc-100 transition-colors cursor-pointer"
                aria-label="Close"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Section Header (Image 2: "SELECT OPTION / PACK SIZE") */}
            <div className="px-4 pt-3 pb-1 text-left">
              <span className="text-[11px] font-black uppercase tracking-wider text-slate-400">
                SELECT OPTION / PACK SIZE
              </span>
            </div>

            {/* Scrollable Variant Cards List (Image 2) */}
            <div className="px-4 py-2 pb-6 flex-1 overflow-y-auto space-y-2.5">
              {variantsList.map((v, index) => (
                <GroceryVariantCard
                  key={v.name || `variant-${index}`}
                  variant={v}
                  product={activeProduct}
                  cafeOpen={cafeOpen}
                  groceryMartOpen={groceryMartOpen}
                  restaurantOpen={restaurantOpen}
                />
              ))}
            </div>
          </motion.div>
        )}
      </div>
    </AnimatePresence>
  </DrawerErrorBoundary>
  )
}
