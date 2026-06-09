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

// Veg Icon matching Swiggy/Indian restaurant standards
const VegIcon = () => (
  <span className="inline-flex items-center justify-center border-2 border-emerald-600 p-[2px] h-3.5 w-3.5 shrink-0 rounded-[3px] bg-white" title="Veg">
    <span className="h-1.5 w-1.5 rounded-full bg-emerald-600"></span>
  </span>
)

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

  // Swiggy drawer selection states
  const [selectedItem, setSelectedItem] = useState<any>(null)
  const [qtyToConfirm, setQtyToConfirm] = useState<number>(1)

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

  const groupedIds = new Set([
    ...hotBrews, ...hotBites, ...chinese, ...italianPasta, ...bombayBites,
    ...riceDishes, ...shakes, ...mocktails, ...coldCoffee,
    ...southIndian, ...bakery, ...chilled
  ].map(p => p.id))
  const moreItems = nonGroupedProducts.filter(p => !groupedIds.has(p.id))

  // Open Frankie customization drawer
  const openFrankieCustomizer = () => {
    if (frankieGroupItems.length > 0) {
      setSelectedItem(frankieGroupItems[0]) // Default to Veg Frankie
      setQtyToConfirm(1)
      setSelectedGroup({
        id: 'frankie-rolls',
        name: 'Customize Frankie Roll',
        description: 'Choose your favorite roll variant below. Prepared fresh with soft paratha bread.',
        items: frankieGroupItems
      })
    }
  }

  // Handle adding the customized selection to cart
  const handleAddToCartConfirm = () => {
    if (!selectedItem) return
    const currentQtyInCart = getItemQuantity(selectedItem.id)
    updateQuantity(selectedItem.id, selectedItem.name, currentQtyInCart + qtyToConfirm)
    setSelectedGroup(null)
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
            {/* The single Combined/Customizable Frankie Roll Card - Swiggy Style */}
            <div className="group relative flex flex-row sm:flex-col justify-between overflow-hidden rounded-2xl border border-rose-500/20 bg-card p-3 shadow-md transition-all duration-300 md:hover:shadow-lg md:hover:border-rose-500/40">
              <div className="absolute left-2 top-2 z-10 rounded-full bg-gradient-to-r from-rose-500 to-amber-500 px-2.5 py-0.5 text-[9px] font-black text-white shadow-sm uppercase tracking-wider select-none">
                Customizable
              </div>

              {/* Image */}
              <div className="relative aspect-square w-24 sm:w-full overflow-hidden rounded-xl bg-muted/10 dark:bg-white/[0.02] flex items-center justify-center shrink-0">
                <img
                  src={frankieGroupItems[0]?.imageUrl || '/products/veg-frankie-roll.png'}
                  alt="Frankie Rolls"
                  className="h-full w-full object-contain p-1.5 transition-transform duration-300 md:group-hover:scale-105"
                />
              </div>

              {/* Product Info & Action */}
              <div className="flex flex-col flex-grow pl-3 sm:pl-0 sm:pt-3 justify-between">
                <div>
                  <div className="flex items-center gap-1.5">
                    <VegIcon />
                    <h3 className="text-sm sm:text-base font-extrabold text-text-primary group-hover:text-primary transition-colors">
                      Frankie Roll
                    </h3>
                  </div>
                  <p className="text-xs text-text-secondary line-clamp-2 mt-1">
                    Choose your flavor! Freshly prepared rolls loaded with Paneer, Cheese, Veggies & tangy mint sauces.
                  </p>
                  <div className="flex items-center gap-1.5 mt-2 flex-wrap">
                    <span className="inline-block px-1.5 py-0.5 bg-muted rounded text-[9px] font-bold text-text-muted">Veg</span>
                    <span className="inline-block px-1.5 py-0.5 bg-muted rounded text-[9px] font-bold text-text-muted">Paneer</span>
                    <span className="inline-block px-1.5 py-0.5 bg-muted rounded text-[9px] font-bold text-text-muted">Cheese</span>
                  </div>
                </div>

                <div className="flex items-center justify-between mt-4 gap-2 pt-2 border-t border-border/40">
                  <div className="flex flex-col">
                    <span className="text-[10px] text-text-muted font-bold uppercase">Price</span>
                    <span className="text-sm sm:text-base font-black text-text-primary">From ₹59</span>
                  </div>

                  <div>
                    {totalFrankieQtyInCart === 0 ? (
                      <Button
                        onClick={openFrankieCustomizer}
                        disabled={!cafeOpen}
                        className="border border-[#2e7d32] bg-gradient-to-b from-white to-green-50/50 dark:from-zinc-900 dark:to-zinc-800 text-[#2e7d32] dark:text-emerald-400 text-xs font-black px-4 py-2 rounded-lg md:hover:bg-[#2e7d32] md:hover:text-white flex items-center gap-0.5 shadow-sm cursor-pointer"
                      >
                        ADD
                        <Plus className="h-3 w-3 stroke-[3]" />
                      </Button>
                    ) : (
                      <Button
                        onClick={openFrankieCustomizer}
                        className="bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white text-xs font-black px-3 py-2 rounded-lg flex items-center gap-1.5 shadow-sm cursor-pointer"
                      >
                        <span>{totalFrankieQtyInCart} in Cart</span>
                        <span className="text-[10px] text-emerald-200 bg-black/10 px-1 py-0.5 rounded">ADD +</span>
                      </Button>
                    )}
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
              className="fixed bottom-0 left-0 right-0 z-50 max-h-[80vh] bg-background border-t border-border rounded-t-3xl shadow-2xl overflow-hidden flex flex-col mx-auto max-w-lg"
            >
              {/* Drawer Handle */}
              <div className="w-12 h-1.5 bg-muted/60 rounded-full mx-auto my-3 shrink-0" />

              {/* Drawer Header */}
              <div className="px-5 pb-3 border-b border-border/50 flex justify-between items-start gap-4">
                <div>
                  <h3 className="text-lg font-black text-text-primary flex items-center gap-2">
                    {selectedGroup.name}
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

              {/* Option List: Swiggy style Radio Select */}
              <div className="flex-1 overflow-y-auto px-5 py-4">
                <div className="mb-4">
                  <span className="text-xs font-black uppercase text-text-muted tracking-wider">Choose Variant</span>
                  <span className="text-[10px] text-rose-500 font-bold ml-2">(Required)</span>
                </div>
                
                <div className="space-y-2.5">
                  {selectedGroup.items.map((item) => {
                    const isSelected = selectedItem?.id === item.id
                    const savings = item.mrp - item.price
                    
                    return (
                      <div
                        key={item.id}
                        onClick={() => setSelectedItem(item)}
                        className={`flex items-center justify-between p-3.5 rounded-xl border transition-all cursor-pointer ${
                          isSelected 
                            ? 'border-emerald-600 bg-emerald-500/5 dark:bg-emerald-500/[0.02]' 
                            : 'border-border/60 bg-muted/20 hover:border-border'
                        }`}
                      >
                        {/* Radio Option Labels */}
                        <div className="flex items-start gap-3 min-w-0 flex-1">
                          {/* Custom Swiggy style radio circle */}
                          <div className={`mt-0.5 h-4 w-4 rounded-full border flex items-center justify-center shrink-0 ${
                            isSelected ? 'border-emerald-600 text-emerald-600' : 'border-text-muted'
                          }`}>
                            {isSelected && <div className="h-2 w-2 rounded-full bg-emerald-600" />}
                          </div>

                          <div className="min-w-0">
                            <div className="flex items-center gap-1.5">
                              <VegIcon />
                              <h4 className="text-sm font-black text-text-primary truncate">
                                {item.name}
                              </h4>
                            </div>
                            <p className="text-[11px] text-text-secondary mt-0.5">
                              {item.unit} • {item.description}
                            </p>
                            
                            {/* Price */}
                            <div className="flex items-baseline gap-2 mt-1 leading-none">
                              <span className="text-xs font-black text-text-primary">
                                ₹{item.price}
                              </span>
                              {item.mrp > item.price && (
                                <span className="text-[10px] text-text-muted line-through font-bold">
                                  ₹{item.mrp}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>

                        {/* Discount Badge */}
                        {item.discount > 0 && (
                          <span className="shrink-0 text-[8.5px] font-black text-rose-600 bg-rose-500/10 px-1.5 py-0.5 rounded">
                            {item.discount}% OFF
                          </span>
                        )}
                      </div>
                    )
                  })}
                </div>
              </div>

              {/* Drawer Footer: Swiggy style Add Button and Qty selector */}
              <div className="p-5 border-t border-border bg-muted/30 flex items-center justify-between gap-4 shrink-0">
                {/* Quantity selector inside drawer footer */}
                <div className="flex items-center rounded-xl bg-gradient-to-b from-white to-muted dark:from-zinc-900 dark:to-zinc-800 border border-border shadow-sm overflow-hidden h-10 w-28 justify-between shrink-0">
                  <button
                    onClick={() => setQtyToConfirm(prev => Math.max(1, prev - 1))}
                    className="w-9 flex h-full items-center justify-center hover:bg-black/5 active:scale-90 transition-all text-text-primary cursor-pointer"
                  >
                    <Minus className="h-3.5 w-3.5 stroke-[3]" />
                  </button>
                  <span className="flex-1 text-center text-sm font-black select-none text-text-primary">
                    {qtyToConfirm}
                  </span>
                  <button
                    onClick={() => setQtyToConfirm(prev => prev + 1)}
                    disabled={selectedItem && qtyToConfirm >= selectedItem.stock}
                    className="w-9 flex h-full items-center justify-center hover:bg-black/5 active:scale-90 transition-all text-text-primary cursor-pointer disabled:opacity-50"
                  >
                    <Plus className="h-3.5 w-3.5 stroke-[3]" />
                  </button>
                </div>

                {/* Add to Cart button */}
                <Button
                  onClick={handleAddToCartConfirm}
                  disabled={!selectedItem || selectedItem.stock <= 0 || !cafeOpen}
                  className="flex-1 bg-rose-600 hover:bg-rose-700 text-white font-black text-xs h-10 rounded-xl shadow-md cursor-pointer flex items-center justify-center gap-1.5"
                >
                  <ShoppingBag className="h-4 w-4" />
                  Add to Cart • ₹{selectedItem ? (selectedItem.price * qtyToConfirm) : 0}
                </Button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  )
}
