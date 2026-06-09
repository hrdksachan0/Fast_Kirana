'use client'

import { useState, useMemo } from 'react'
import { Plus, Minus, Check, ChevronRight, Flame, ShoppingBag, X } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { Button } from '@/components/ui/button'
import { Product } from '@/types'
import { useUIStore } from '@/stores/ui-store'
import { ProductImage } from '@/components/product/product-image'
import { motion, AnimatePresence } from 'framer-motion'
import { ProductCard } from '@/components/product/product-card'
import Link from 'next/link'

interface CafeStorefrontProps {
  initialProducts: any[]
}

export function CafeStorefront({ initialProducts }: CafeStorefrontProps) {
  const { items: cartItems, addItem, updateQuantity, getItemQuantity } = useCart()
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  
  // Customization drawer state
  const [selectedGroup, setSelectedGroup] = useState<{
    id: string
    name: string
    description: string
    items: any[]
  } | null>(null)

  // Quick qty adjustment popover state (for cards that are customizable and already in the cart)
  const [activeQtyPopover, setActiveQtyPopover] = useState<string | null>(null)

  // Map products to categories
  const mappedProducts = useMemo(() => {
    return initialProducts.map(p => ({
      id: p.id,
      name: p.name,
      slug: p.slug,
      description: p.description,
      imageUrl: p.imageUrl,
      categoryId: p.categoryId,
      mrp: p.mrp,
      price: p.price,
      discount: p.discount,
      unit: p.unit,
      stock: p.stock,
      isAvailable: p.isAvailable,
      tags: p.tags || [],
      category: p.category ? {
        id: p.category.id,
        name: p.category.name,
        slug: p.category.slug,
        imageUrl: p.category.imageUrl,
        parentId: p.category.parentId,
        sortOrder: p.category.sortOrder,
      } : undefined
    }))
  }, [initialProducts])

  // Grouping config for Frankie Rolls
  const frankieGroupItems = useMemo(() => {
    return mappedProducts.filter(p => 
      p.tags?.some((t: string) => ['frankie-rolls', 'frankie rolls', 'frankie-roll', 'frankie roll', 'rolls', 'roll', 'kathi roll', 'kathi-roll'].includes(t.toLowerCase()))
    )
  }, [mappedProducts])

  // All other items, excluding the ones in the Frankie Rolls group
  const nonGroupedProducts = useMemo(() => {
    const frankieIds = new Set(frankieGroupItems.map(p => p.id))
    return mappedProducts.filter(p => !frankieIds.has(p.id))
  }, [mappedProducts, frankieGroupItems])

  // Compute total quantity of Frankie Rolls currently in the cart
  const totalFrankieQtyInCart = useMemo(() => {
    return frankieGroupItems.reduce((sum, item) => sum + getItemQuantity(item.id), 0)
  }, [frankieGroupItems, getItemQuantity])

  // Cafe categories grouping
  const hotBrews = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['hot-beverage', 'tea', 'coffee'].includes(t.toLowerCase())) || ['nescafe-classic', 'tata-tea-gold'].includes(p.slug))
  const hotBites = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['hot-bite', 'snacks'].includes(t.toLowerCase())) || ['maggi-noodles'].includes(p.slug))
  const chinese = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['chinese', 'chinese-cuisine', 'chinese cuisine'].includes(t.toLowerCase())))
  const italianPasta = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['italian-pasta', 'italian-pastas', 'italian pasta\'s', 'pasta'].includes(t.toLowerCase())))
  const bombayBites = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['bombay-bites', 'bombay bites', 'bombay-bite', 'bombay bite'].includes(t.toLowerCase())))
  const riceDishes = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['rice-dishes', 'rice dishes', 'rice-dish', 'rice dish', 'biryani', 'pulav'].includes(t.toLowerCase())))
  const shakes = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['shakes', 'shake', 'milkshake', 'milkshakes'].includes(t.toLowerCase())))
  const mocktails = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['mocktails', 'mocktail', 'coolers', 'cooler'].includes(t.toLowerCase())))
  const coldCoffee = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['cold-coffee', 'cold coffee', 'iced coffee', 'iced-coffee'].includes(t.toLowerCase())))
  const southIndian = nonGroupedProducts.filter(p => p.tags?.some((t: string) => ['south-indian', 'south indian'].includes(t.toLowerCase())))
  const bakery = nonGroupedProducts.filter(p => ['croissant-butter', 'muffin-chocolate', 'lays-classic-salted'].includes(p.slug) || p.category?.slug === 'bakery-biscuits')
  const chilled = nonGroupedProducts.filter(p => ['coca-cola', 'sprite', 'red-bull-energy'].includes(p.slug))

  // Catch-all: products in cafe category/tags that don't appear in any group above
  const groupedIds = new Set([
    ...hotBrews, ...hotBites, ...chinese, ...italianPasta, ...bombayBites,
    ...riceDishes, ...shakes, ...mocktails, ...coldCoffee,
    ...southIndian, ...bakery, ...chilled
  ].map(p => p.id))
  const moreItems = nonGroupedProducts.filter(p => !groupedIds.has(p.id))

  // Open Frankie customization drawer
  const openFrankieCustomizer = () => {
    setSelectedGroup({
      id: 'frankie-rolls',
      name: 'Frankie Rolls',
      description: 'Choose from our freshly prepared Veg, Paneer, Cheese, or Paneer Kathi Frankie Rolls wrapped in soft flaky paratha.',
      items: frankieGroupItems
    })
    setActiveQtyPopover(null)
  }

  // Handle main Frankie Roll card ADD click
  const handleMainFrankieAdd = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (totalFrankieQtyInCart > 0) {
      // Toggle the quick options list popover
      setActiveQtyPopover(activeQtyPopover === 'frankie-rolls' ? null : 'frankie-rolls')
    } else {
      openFrankieCustomizer()
    }
  }

  return (
    <div className="container mx-auto px-4 py-6 max-w-7xl space-y-6 md:space-y-10">
      {/* Breadcrumb */}
      <nav className="flex items-center gap-1.5 text-xs md:text-sm font-semibold">
        <Link href="/" className="text-text-muted hover:text-primary transition-colors">Home</Link>
        <ChevronRight size={14} className="text-text-muted" />
        <span className="font-bold text-rose-600">FastKirana Cafe ☕</span>
      </nav>

      {/* Hero Cafe Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-[#2c1810] via-[#1a0c07] to-[#0f0502] p-6 md:p-10 text-white shadow-[0_8px_32px_rgba(35,21,16,0.25)] border border-[#48281d] dark:border-[#22100a]">
        <div className="absolute -top-12 -right-12 w-64 h-64 rounded-full bg-amber-500/10 blur-[60px] pointer-events-none" />

        <div className="relative z-10 max-w-[60%] sm:max-w-md md:max-w-lg space-y-3">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-500/10 border border-amber-500/20 px-3 py-1 text-[10px] font-black tracking-wider uppercase text-amber-300">
            <Flame className="h-3 w-3 text-amber-400 fill-amber-400 animate-pulse-gentle" />
            Freshly Prepared & Hot
          </span>
          <h1 className="text-2xl md:text-4.5xl font-black leading-tight tracking-tight bg-gradient-to-r from-amber-200 via-orange-300 to-yellow-100 bg-clip-text text-transparent">
            FastKirana Cafe
          </h1>
          <p className="text-[10px] sm:text-xs md:text-sm text-white/80 leading-relaxed font-semibold">
            Steaming hot tea, fresh filter coffee, gourmet frankie rolls, cold shakes, and mocktails prepared fresh and delivered warm!
          </p>
          <div className="flex items-center gap-3 pt-1 text-[10px] md:text-xs font-bold text-white/90">
            <span className="flex items-center gap-1 bg-white/5 border border-white/10 px-2.5 py-1 rounded-lg">⚡ Fast Delivery</span>
            <span className="flex items-center gap-1 bg-white/5 border border-white/10 px-2.5 py-1 rounded-lg">🔥 Served Fresh</span>
          </div>
        </div>
        
        {/* Right side: Premium Cafe Specials Food Image */}
        <div className="absolute right-4 md:right-10 bottom-0 top-0 w-[35%] md:w-[40%] flex items-center justify-end select-none pointer-events-none">
          <img
            src="/cafe_banner.png"
            alt="Steaming Hot Tea & Café Specials"
            className="object-contain max-h-[120px] md:max-h-[190px] w-auto h-auto drop-shadow-[0_15px_30px_rgba(0,0,0,0.5)]"
          />
        </div>
      </div>

      {/* -------------------- Grouped Customisable Frankie Rolls Section -------------------- */}
      {frankieGroupItems.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🌯</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Gourmet Frankie Rolls</h2>
              <p className="text-xs text-text-secondary">Fresh rolls stuffed with spiced paneer, cheese, and veg patties</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 max-w-4xl">
            {/* The single Combined/Customizable Frankie Roll Card */}
            <div className="group relative flex flex-row sm:flex-col justify-between overflow-hidden rounded-2xl border border-rose-500/20 bg-card p-3 shadow-md transition-all duration-300 md:hover:shadow-lg md:hover:border-rose-500/40">
              <div className="absolute left-2 top-2 z-10 rounded-full bg-gradient-to-r from-rose-500 to-amber-500 px-2.5 py-0.5 text-[9px] font-black text-white shadow-sm uppercase tracking-wider select-none">
                Customizable
              </div>

              {/* Left Side (Mobile) / Top Side (Desktop): Image */}
              <div className="relative aspect-square w-24 sm:w-full overflow-hidden rounded-xl bg-muted/10 dark:bg-white/[0.02] flex items-center justify-center shrink-0">
                <img
                  src={frankieGroupItems[0]?.imageUrl || '/products/veg-frankie-roll.png'}
                  alt="Frankie Rolls"
                  className="h-full w-full object-contain p-1.5 transition-transform duration-300 md:group-hover:scale-105"
                />
              </div>

              {/* Right Side (Mobile) / Bottom Side (Desktop): Product Info & Action */}
              <div className="flex flex-col flex-grow pl-3 sm:pl-0 sm:pt-3 justify-between">
                <div>
                  <h3 className="text-sm sm:text-base font-extrabold text-text-primary group-hover:text-primary transition-colors">
                    Frankie Roll (Customizable)
                  </h3>
                  <p className="text-xs text-text-secondary line-clamp-2 mt-1">
                    Choose from Veg, Paneer, Cheese, Paneer Cheese, or Kathi Roll options.
                  </p>
                  <div className="flex items-center gap-1.5 mt-2">
                    <span className="text-xs font-semibold text-text-muted">Options:</span>
                    <span className="inline-block px-1.5 py-0.5 bg-muted rounded text-[10px] font-bold text-text-primary">Veg</span>
                    <span className="inline-block px-1.5 py-0.5 bg-muted rounded text-[10px] font-bold text-text-primary">Paneer</span>
                    <span className="inline-block px-1.5 py-0.5 bg-muted rounded text-[10px] font-bold text-text-primary">Cheese</span>
                  </div>
                </div>

                <div className="flex items-center justify-between mt-4 gap-2 pt-2 border-t border-border/40">
                  <div className="flex flex-col">
                    <span className="text-xs text-text-muted font-semibold">Starts at</span>
                    <span className="text-base font-black text-text-primary">₹59</span>
                  </div>

                  <div className="relative">
                    {/* Add / Qty button */}
                    {totalFrankieQtyInCart === 0 ? (
                      <Button
                        onClick={handleMainFrankieAdd}
                        disabled={!cafeOpen}
                        className="border border-[#2e7d32] bg-gradient-to-b from-white to-green-50/50 dark:from-zinc-900 dark:to-zinc-800 text-[#2e7d32] dark:text-emerald-400 text-xs font-black px-4 py-2 rounded-lg md:hover:bg-[#2e7d32] md:hover:text-white flex items-center gap-1 shadow-sm cursor-pointer"
                      >
                        ADD
                        <Plus className="h-3 w-3 stroke-[3]" />
                      </Button>
                    ) : (
                      <div className="flex items-center rounded-lg bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold shadow-sm overflow-hidden h-9">
                        <button
                          onClick={handleMainFrankieAdd}
                          className="px-3 flex h-full items-center justify-center hover:bg-black/10 transition-all text-xs font-black cursor-pointer gap-1"
                        >
                          <span>{totalFrankieQtyInCart} added</span>
                          <span className="text-[10px] text-emerald-200">(Customize)</span>
                        </button>
                      </div>
                    )}

                    {/* Quick quantity selector popover */}
                    <AnimatePresence>
                      {activeQtyPopover === 'frankie-rolls' && (
                        <>
                          {/* Overlay to close popover */}
                          <div 
                            className="fixed inset-0 z-30" 
                            onClick={() => setActiveQtyPopover(null)} 
                          />
                          <motion.div
                            initial={{ opacity: 0, y: 10, scale: 0.95 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: 10, scale: 0.95 }}
                            className="absolute bottom-11 right-0 z-40 w-64 bg-card border border-border rounded-xl p-3 shadow-xl space-y-2.5"
                          >
                            <h4 className="text-xs font-black text-text-primary border-b border-border/50 pb-1.5">
                              Customizations in Cart
                            </h4>
                            <div className="space-y-2 max-h-48 overflow-y-auto">
                              {frankieGroupItems.map(item => {
                                const qty = getItemQuantity(item.id)
                                if (qty === 0) return null
                                return (
                                  <div key={item.id} className="flex items-center justify-between text-xs">
                                    <span className="font-semibold text-text-primary truncate max-w-[120px]">{item.name.replace(" Frankie Roll", "").replace(" Roll", "")}</span>
                                    <div className="flex items-center gap-1.5 bg-muted rounded-md px-1.5 py-0.5 font-bold">
                                      <button 
                                        onClick={() => updateQuantity(item.id, item.name, qty - 1)}
                                        className="text-text-secondary hover:text-primary p-0.5"
                                      >
                                        <Minus className="h-3 w-3 stroke-[3]" />
                                      </button>
                                      <span className="w-3 text-center text-[10px]">{qty}</span>
                                      <button 
                                        onClick={() => updateQuantity(item.id, item.name, qty + 1)}
                                        className="text-text-secondary hover:text-primary p-0.5"
                                      >
                                        <Plus className="h-3 w-3 stroke-[3]" />
                                      </button>
                                    </div>
                                  </div>
                                )
                              })}
                            </div>
                            <Button 
                              onClick={openFrankieCustomizer}
                              className="w-full text-[10px] font-bold py-1.5 h-auto bg-primary/10 text-primary border border-primary/20 hover:bg-primary/20"
                            >
                              Add New Customization
                            </Button>
                          </motion.div>
                        </>
                      )}
                    </AnimatePresence>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      )}

      {/* -------------------- Other Standard Sections -------------------- */}

      {/* Steaming Hot Brews */}
      {hotBrews.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">☕</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Steaming Hot Brews</h2>
              <p className="text-xs text-text-secondary">Chai, coffee, and fresh brewing mixes</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {hotBrews.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Quick Bites & Snacks */}
      {hotBites.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥟</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Quick Bites & Snacks</h2>
              <p className="text-xs text-text-secondary">Samosas, Momos, and warm treats</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {hotBites.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Chinese Cuisine */}
      {chinese.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥡</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Chinese Cuisine</h2>
              <p className="text-xs text-text-secondary">Momos, noodles, fried dishes & sauces</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {chinese.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Italian Pasta's */}
      {italianPasta.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🍝</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Italian Pasta's</h2>
              <p className="text-xs text-text-secondary">Fresh penne tossed in aromatic red & white sauces</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {italianPasta.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Bombay Bites */}
      {bombayBites.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥪</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Bombay Bites</h2>
              <p className="text-xs text-text-secondary">Vada Pav, special Bombay Masala Toast, and street snacks</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {bombayBites.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Rice Dishes */}
      {riceDishes.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🍚</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Rice Dishes</h2>
              <p className="text-xs text-text-secondary">Flavourful biryani, fried rice, and combos</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {riceDishes.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Shakes */}
      {shakes.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥤</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Thick Shakes</h2>
              <p className="text-xs text-text-secondary">Creamy strawberry, chocolate, and Oreo shakes</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {shakes.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Mocktails */}
      {mocktails.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🍹</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Refreshing Mocktails</h2>
              <p className="text-xs text-text-secondary">Iced coolers, Virgin Mojito, and summer drinks</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {mocktails.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Cold Coffee */}
      {coldCoffee.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🧋</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Chilled Cold Coffee</h2>
              <p className="text-xs text-text-secondary">Classic cold brews, hazelnut cold coffee & iced sips</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {coldCoffee.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* South Indian */}
      {southIndian.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🍛</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">South Indian Favorites</h2>
              <p className="text-xs text-text-secondary">Dosa, Idli, Vada, Uttapam & more</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {southIndian.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Bakery & Desserts */}
      {bakery.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥐</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Bakery & Sweet Cravings</h2>
              <p className="text-xs text-text-secondary">Freshly baked croissants, muffins, and sweet nibbles</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {bakery.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Chilled Sodas */}
      {chilled.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🥤</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">Chilled Sips & Sodas</h2>
              <p className="text-xs text-text-secondary">Carbonated soft drinks and cold energy boosts</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {chilled.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* Catch-all More from Cafe */}
      {moreItems.length > 0 && (
        <section className="space-y-4">
          <div className="flex items-center gap-2 px-1">
            <span className="text-xl">🍽️</span>
            <div>
              <h2 className="text-lg md:text-xl font-extrabold text-text-primary tracking-tight">More from Cafe</h2>
              <p className="text-xs text-text-secondary">Additional cafe items and specials</p>
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
            {moreItems.map(p => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </section>
      )}

      {/* -------------------- Swiggy-style Drawer / Customization Bottom Sheet -------------------- */}
      <AnimatePresence>
        {selectedGroup && (
          <>
            {/* Backdrop dark overlay */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs cursor-pointer"
              onClick={() => setSelectedGroup(null)}
            />

            {/* Bottom Sheet Drawer */}
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 220 }}
              className="fixed bottom-0 left-0 right-0 z-50 max-h-[85vh] bg-background border-t border-border rounded-t-3xl shadow-2xl overflow-hidden flex flex-col mx-auto max-w-lg"
            >
              {/* Drawer Handle / Drag Indicator */}
              <div className="w-12 h-1.5 bg-muted/60 rounded-full mx-auto my-3 shrink-0" />

              {/* Drawer Header */}
              <div className="px-5 pb-3 border-b border-border/50 flex justify-between items-start gap-4">
                <div>
                  <h3 className="text-lg font-black text-text-primary flex items-center gap-2">
                    {selectedGroup.name}
                    <span className="text-xs px-2 py-0.5 bg-rose-500/10 text-rose-500 rounded-full font-bold">Customize</span>
                  </h3>
                  <p className="text-xs text-text-secondary mt-1">
                    {selectedGroup.description}
                  </p>
                </div>
                <button
                  onClick={() => setSelectedGroup(null)}
                  className="p-1 rounded-full bg-muted/60 text-text-secondary hover:text-text-primary hover:bg-muted"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>

              {/* Drawer Content: List of Options / Variants */}
              <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
                {selectedGroup.items.map((item) => {
                  const qty = getItemQuantity(item.id)
                  const savings = item.mrp - item.price

                  return (
                    <div
                      key={item.id}
                      className="flex items-center justify-between p-3 rounded-xl border border-border/60 hover:border-primary/20 bg-muted/20 hover:bg-muted/40 transition-all gap-4"
                    >
                      {/* Left: Info */}
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1.5">
                          {item.tags?.includes('popular') && (
                            <span className="text-[10px] font-black text-amber-500 flex items-center gap-0.5">
                              ⭐ Popular
                            </span>
                          )}
                          {item.discount > 0 && (
                            <span className="text-[9px] font-black text-rose-500 bg-rose-500/10 px-1.5 py-0.5 rounded">
                              {item.discount}% OFF
                            </span>
                          )}
                        </div>
                        <h4 className="text-sm font-black text-text-primary truncate mt-0.5">
                          {item.name}
                        </h4>
                        <p className="text-xs text-text-secondary truncate mt-0.5">
                          {item.unit}
                        </p>
                        
                        {/* Price & Savings */}
                        <div className="flex items-baseline gap-2 mt-1.5 leading-none">
                          <span className="text-sm font-black text-text-primary">
                            ₹{item.price}
                          </span>
                          {item.mrp > item.price && (
                            <span className="text-xs text-text-muted line-through font-bold">
                              ₹{item.mrp}
                            </span>
                          )}
                          {savings > 0 && (
                            <span className="text-[10px] font-black text-emerald-600 dark:text-emerald-400">
                              Save ₹{savings}
                            </span>
                          )}
                        </div>
                      </div>

                      {/* Right: Quantity Selector */}
                      <div className="shrink-0 flex items-center justify-center">
                        {qty === 0 ? (
                          <Button
                            onClick={() => addItem(item)}
                            disabled={item.stock <= 0 || !cafeOpen}
                            className="border border-[#2e7d32] bg-gradient-to-b from-white to-green-50/50 dark:from-zinc-900 dark:to-zinc-800 text-[#2e7d32] dark:text-emerald-400 text-xs font-black px-4 py-1.5 h-8 rounded-lg md:hover:bg-[#2e7d32] md:hover:text-white flex items-center gap-0.5 shadow-sm"
                          >
                            ADD
                            <Plus className="h-3 w-3 stroke-[3]" />
                          </Button>
                        ) : (
                          <div className="flex items-center rounded-lg bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold shadow-sm overflow-hidden h-8 w-24 justify-between">
                            <button
                              onClick={() => updateQuantity(item.id, item.name, qty - 1)}
                              className="w-8 flex h-full items-center justify-center hover:bg-black/10 transition-all cursor-pointer"
                            >
                              <Minus className="h-3 w-3 stroke-[3]" />
                            </button>
                            <span className="flex-1 text-center text-xs font-black select-none">
                              {qty}
                            </span>
                            <button
                              onClick={() => updateQuantity(item.id, item.name, qty + 1)}
                              disabled={qty >= item.stock}
                              className="w-8 flex h-full items-center justify-center hover:bg-black/10 transition-all disabled:opacity-50 cursor-pointer"
                            >
                              <Plus className="h-3 w-3 stroke-[3]" />
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>

              {/* Drawer Footer: Total cost & Done */}
              <div className="p-5 border-t border-border bg-muted/30 flex items-center justify-between gap-4 shrink-0">
                <div className="flex flex-col">
                  <span className="text-[10px] text-text-secondary font-semibold uppercase tracking-wider">Total Added</span>
                  <span className="text-lg font-black text-text-primary">
                    {totalFrankieQtyInCart} roll{totalFrankieQtyInCart !== 1 ? 's' : ''}
                  </span>
                </div>
                <Button
                  onClick={() => setSelectedGroup(null)}
                  className="bg-rose-600 hover:bg-rose-700 text-white font-black text-xs px-6 py-2.5 h-10 rounded-xl shadow-md cursor-pointer flex items-center gap-1.5"
                >
                  <ShoppingBag className="h-4 w-4" />
                  View Cart / Done
                </Button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  )
}
