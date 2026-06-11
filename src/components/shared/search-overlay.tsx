'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { AnimatePresence, motion } from 'framer-motion'
import { Search, X, TrendingUp, History, Loader2, Plus, Minus, Mic, MicOff } from 'lucide-react'
import { CATEGORIES } from '@/lib/constants'
import { useUIStore } from '@/stores/ui-store'
import { useCart } from '@/hooks/use-cart'
import { ProductImage } from '@/components/product/product-image'
import { isCafeProduct, cn } from '@/lib/utils'
import { Product } from '@/types'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'

interface SearchOverlayProps {
  open: boolean
  onClose: () => void
}

const TRENDING_SEARCHES = [
  'Amul Butter',
  'Maggi',
  'Coca-Cola',
  'Bread',
  'Eggs',
  'Rice',
  'Paneer',
  'Onion',
]

// Map category slugs to visual colors
const CATEGORY_COLORS: Record<string, { bg: string; gradient: string }> = {
  'fruits-vegetables': { bg: 'bg-emerald-50', gradient: 'from-emerald-100 to-emerald-50' },
  'dairy-breakfast': { bg: 'bg-blue-50', gradient: 'from-blue-100 to-blue-50' },
  'snacks-munchies': { bg: 'bg-amber-50', gradient: 'from-amber-100 to-amber-50' },
  'beverages': { bg: 'bg-purple-50', gradient: 'from-purple-100 to-purple-50' },
  'personal-care': { bg: 'bg-pink-50', gradient: 'from-pink-100 to-pink-50' },
  'household': { bg: 'bg-indigo-50', gradient: 'from-indigo-100 to-indigo-50' },
  'bakery-biscuits': { bg: 'bg-orange-50', gradient: 'from-orange-100 to-orange-50' },
  'atta-rice-dal': { bg: 'bg-yellow-50', gradient: 'from-yellow-100 to-yellow-50' },
}

export function SearchOverlay({ open, onClose }: SearchOverlayProps) {
  const router = useRouter()
  const inputRef = useRef<HTMLInputElement>(null)
  const [query, setQuery] = useState('')
  const [suggestions, setSuggestions] = useState<Product[]>([])
  const [loading, setLoading] = useState(false)
  const [recentSearches, setRecentSearches] = useState<string[]>([])
  const [isListening, setIsListening] = useState(false)
  const recognitionRef = useRef<any>(null)

  const toggleVoiceSearch = () => {
    if (isListening) {
      if (recognitionRef.current) {
        recognitionRef.current.stop()
      }
      setIsListening(false)
      return
    }

    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    if (!SpeechRecognition) {
      toast.error('Voice search is not supported on this browser.')
      return
    }

    const recognition = new SpeechRecognition()
    recognitionRef.current = recognition
    recognition.continuous = false
    recognition.lang = 'en-IN'
    recognition.interimResults = false

    recognition.onstart = () => {
      setIsListening(true)
      triggerHaptic('light')
      toast.info('Listening... Speak now!', { id: 'voice-search-status' })
    }

    recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error)
      setIsListening(false)
      triggerHaptic('warning')
      toast.error('Voice search error. Please try again.', { id: 'voice-search-status' })
    }

    recognition.onend = () => {
      setIsListening(false)
    }

    recognition.onresult = (event: any) => {
      const resultText = event.results[0][0].transcript
      setQuery(resultText)
      triggerHaptic('medium')
      saveSearchTerm(resultText)
      toast.success(`Searching for: "${resultText}"`, { id: 'voice-search-status' })
      handleSearch(resultText)
    }

    recognition.start()
  }

  // Cleanup mic on overlay close
  useEffect(() => {
    if (!open && recognitionRef.current) {
      recognitionRef.current.stop()
      setIsListening(false)
    }
  }, [open])

  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const setActiveVariantProduct = useUIStore((s) => s.setActiveVariantProduct)

  const { getItemQuantity, addItem, updateQuantity } = useCart()

  // Load recent searches from localStorage
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('recent_searches')
      if (saved) {
        try {
          setRecentSearches(JSON.parse(saved))
        } catch {
          // ignore
        }
      }
    }
  }, [open])

  // Helper to save a search term
  const saveSearchTerm = useCallback((term: string) => {
    if (!term.trim()) return
    const cleanTerm = term.trim()
    setRecentSearches((prev) => {
      const updated = [cleanTerm, ...prev.filter((t) => t !== cleanTerm)].slice(0, 5)
      localStorage.setItem('recent_searches', JSON.stringify(updated))
      return updated
    })
  }, [])

  // Clear all recent searches
  const clearRecentSearches = () => {
    setRecentSearches([])
    localStorage.removeItem('recent_searches')
  }

  // Auto-focus on open
  useEffect(() => {
    if (open && inputRef.current) {
      const timer = setTimeout(() => {
        inputRef.current?.focus()
      }, 100)
      return () => clearTimeout(timer)
    }
  }, [open])

  // Clear query on close
  useEffect(() => {
    if (!open) {
      setQuery('')
      setSuggestions([])
    }
  }, [open])

  // Fetch suggestions with debounce
  useEffect(() => {
    if (query.trim().length < 2) {
      setSuggestions([])
      return
    }

    const handler = setTimeout(async () => {
      setLoading(true)
      try {
        const res = await fetch(`/api/products?search=${encodeURIComponent(query)}&limit=5`)
        if (res.ok) {
          const data = await res.json()
          setSuggestions(data.products || [])
        }
      } catch (err) {
        console.error('Failed to fetch search suggestions:', err)
      } finally {
        setLoading(false)
      }
    }, 300)

    return () => clearTimeout(handler)
  }, [query])

  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open) {
        onClose()
      }
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [open, onClose])

  const handleSearch = useCallback(
    (searchQuery: string) => {
      if (searchQuery.trim()) {
        saveSearchTerm(searchQuery)
        router.push(`/search?q=${encodeURIComponent(searchQuery.trim())}`)
        onClose()
      }
    },
    [router, onClose, saveSearchTerm]
  )

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    handleSearch(query)
  }

  const handleTrendingClick = (term: string) => {
    setQuery(term)
    handleSearch(term)
  }

  const handleCategoryClick = (slug: string) => {
    router.push(`/category/${slug}`)
    onClose()
  }

  const handleAddProduct = (e: React.MouseEvent, product: Product) => {
    e.preventDefault()
    e.stopPropagation()
    
    const cartProduct = {
      id: product.id,
      name: product.name,
      slug: product.slug,
      imageUrl: product.imageUrl,
      mrp: product.mrp,
      price: product.price,
      discount: product.discount,
      unit: product.unit,
      stock: product.stock,
      category: product.category,
    }
    
    addItem(cartProduct)
    saveSearchTerm(product.name)

  }

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Dark backdrop with blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm"
            onClick={onClose}
          />

          {/* Overlay content panel */}
          <motion.div
            initial={{ opacity: 0, y: '100%' }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: '100%' }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
            className="fixed inset-x-0 bottom-0 top-0 z-50 flex flex-col bg-background md:inset-x-auto md:left-1/2 md:top-8 md:bottom-auto md:w-[640px] md:-translate-x-1/2 md:rounded-2xl md:max-h-[85vh] md:shadow-elevated md:border md:border-border"
          >
            {/* Top: Search bar */}
            <div className="flex items-center gap-3 p-4 border-b border-border">
              <form onSubmit={handleSubmit} className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-text-muted" />
                <input
                  ref={inputRef}
                  type="text"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Search for groceries, brands..."
                  className="w-full pl-10 pr-12 py-3 bg-muted/50 border border-border rounded-xl text-sm text-text-primary placeholder:text-text-muted focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary/30 transition-all font-semibold"
                />
                <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                  {loading ? (
                    <Loader2 className="h-4 w-4 animate-spin text-primary" />
                  ) : (
                    <button
                      type="button"
                      onClick={toggleVoiceSearch}
                      className={cn(
                        "h-7 w-7 rounded-lg flex items-center justify-center transition-all cursor-pointer",
                        isListening
                          ? "bg-red-500/10 text-red-500 animate-pulse-gentle"
                          : "text-text-muted hover:bg-muted-foreground/10 hover:text-text-primary"
                      )}
                      title="Voice Search"
                    >
                      {isListening ? <MicOff className="h-4 w-4" /> : <Mic className="h-4 w-4" />}
                    </button>
                  )}
                </div>
              </form>
              <button
                onClick={onClose}
                className="flex h-10 w-10 items-center justify-center rounded-full bg-muted hover:bg-muted/80 text-text-primary transition-colors flex-shrink-0 cursor-pointer"
                aria-label="Close search"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Content area */}
            <div className="flex-1 overflow-y-auto p-4 space-y-6">
              {query.trim().length >= 2 ? (
                /* Dynamic Matches */
                suggestions.length > 0 ? (
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <h3 className="text-xs font-black uppercase tracking-wider text-text-muted">
                        Quick Matches
                      </h3>
                      {loading && <Loader2 className="h-4 w-4 animate-spin text-primary" />}
                    </div>
                    <div className="divide-y divide-border/40 overflow-hidden rounded-2xl border border-border/60 bg-card/60 shadow-sm glass">
                      {suggestions.map((product) => {
                        const quantity = getItemQuantity(product.id)
                        const isCafe = isCafeProduct(product)
                        const isStoreClosed = isCafe ? !cafeOpen : !groceryMartOpen

                        return (
                          <div
                            key={product.id}
                            className="flex items-center justify-between p-3 transition-colors hover:bg-muted/40"
                          >
                            {/* Left: Thumbnail Image & Info Clickable */}
                            <button
                              onClick={() => {
                                saveSearchTerm(product.name)
                                router.push(`/product/${product.slug}`)
                                onClose()
                              }}
                              className="flex flex-1 items-center gap-3 text-left min-w-0 mr-4 cursor-pointer"
                            >
                              <div className="relative h-12 w-12 rounded-xl border border-border/40 bg-muted/30 p-1 flex-shrink-0 flex items-center justify-center overflow-hidden">
                                <ProductImage
                                  src={product.imageUrl}
                                  alt={product.name}
                                  categorySlug={product.category?.slug}
                                  className="h-full w-full object-contain"
                                />
                              </div>
                              <div className="min-w-0 flex-1">
                                <h4 className="text-xs sm:text-sm font-extrabold text-text-primary truncate leading-snug">
                                  {product.name}
                                </h4>
                                <span className="text-[10px] text-text-muted font-bold block">
                                  {product.unit}
                                </span>
                                
                                {/* Pricing */}
                                <div className="flex items-center gap-1.5 mt-0.5 flex-wrap">
                                  <span className="text-xs sm:text-sm font-black text-text-primary">
                                    ₹{product.price}
                                  </span>
                                  {product.mrp > product.price && (
                                    <>
                                      <span className="text-[10px] text-text-muted line-through font-bold">
                                        ₹{product.mrp}
                                      </span>
                                      <span className="bg-[#fff1ed] text-[#ff6f3b] text-[8px] font-black px-1.5 py-0.5 rounded">
                                        {product.discount}% OFF
                                      </span>
                                    </>
                                  )}
                                </div>
                              </div>
                            </button>

                            {/* Right: Inline Quick ADD button */}
                            <div className="relative h-8 w-16 sm:w-20 flex-shrink-0">
                              {product.variants && Array.isArray(product.variants) && product.variants.length > 0 ? (
                                <button
                                  onClick={(e) => {
                                    e.preventDefault()
                                    e.stopPropagation()
                                    setActiveVariantProduct(product)
                                  }}
                                  className="w-full h-full border border-[#2e7d32] bg-white text-[#2e7d32] hover:bg-[#2e7d32] hover:text-white text-[10px] sm:text-xs font-black rounded-lg transition-all flex items-center justify-center cursor-pointer shadow-sm animate-pulse-gentle"
                                >
                                  Options
                                </button>
                              ) : quantity === 0 ? (
                                <button
                                  onClick={(e) => handleAddProduct(e, product)}
                                  disabled={product.stock <= 0 || isStoreClosed}
                                  className="w-full h-full border border-[#2e7d32] bg-white text-[#2e7d32] hover:bg-[#2e7d32] hover:text-white text-[10px] sm:text-xs font-black rounded-lg transition-all flex items-center justify-center gap-0.5 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                  {product.stock <= 0 ? 'Out' : isStoreClosed ? 'Closed' : '+ ADD'}
                                </button>
                              ) : (
                                <div className="flex h-full w-full items-center justify-between rounded-lg bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold overflow-hidden shadow-sm">
                                  <button
                                    onClick={() => updateQuantity(product.id, product.name, quantity - 1)}
                                    className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all cursor-pointer"
                                    aria-label="Decrease quantity"
                                  >
                                    <Minus className="h-3 w-3 stroke-[3]" />
                                  </button>
                                  <span className="w-5 sm:w-6 shrink-0 flex items-center justify-center text-[10px] sm:text-xs font-black select-none">
                                    {quantity}
                                  </span>
                                  <button
                                    onClick={() => updateQuantity(product.id, product.name, quantity + 1)}
                                    disabled={quantity >= product.stock || isStoreClosed}
                                    className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all disabled:opacity-50 cursor-pointer"
                                    aria-label="Increase quantity"
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
                  </div>
                ) : (
                  !loading && (
                    <div className="text-center py-8 px-4 rounded-2xl border border-border/60 bg-muted/20">
                      <span className="text-3xl">🔍</span>
                      <h4 className="text-sm font-bold text-text-primary mt-2">No matching products found</h4>
                      <p className="text-xs text-text-muted mt-1">Try searching for other terms or browse categories below</p>
                    </div>
                  )
                )
              ) : (
                /* History and Suggestions */
                <>
                  {/* Recent Searches */}
                  {recentSearches.length > 0 && (
                    <div>
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                          <History className="h-4 w-4 text-text-muted" />
                          <h3 className="text-sm font-bold text-text-primary">
                            Recent Searches
                          </h3>
                        </div>
                        <button
                          onClick={clearRecentSearches}
                          className="text-[11px] font-bold text-text-muted hover:text-primary transition-colors cursor-pointer"
                        >
                          Clear All
                        </button>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {recentSearches.map((term) => (
                          <button
                            key={term}
                            onClick={() => {
                              setQuery(term)
                              handleSearch(term)
                            }}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-border bg-card text-xs font-semibold text-text-primary hover:bg-primary/5 hover:border-primary/30 hover:text-primary active:scale-95 transition-all duration-200 cursor-pointer"
                          >
                            <History className="h-3 w-3 text-text-muted" />
                            <span>{term}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Trending searches */}
                  <div>
                    <div className="flex items-center gap-2 mb-3">
                      <TrendingUp className="h-4 w-4 text-primary" />
                      <h3 className="text-sm font-bold text-text-primary">
                        Trending Searches
                      </h3>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {TRENDING_SEARCHES.map((term) => (
                        <button
                          key={term}
                          onClick={() => handleTrendingClick(term)}
                          className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full border border-border bg-card text-xs font-medium text-text-primary hover:bg-primary/5 hover:border-primary/30 hover:text-primary active:scale-95 transition-all duration-200 cursor-pointer"
                        >
                          <span className="text-xs">🔥</span>
                          <span>{term}</span>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Popular categories */}
                  <div>
                    <h3 className="text-sm font-bold text-text-primary mb-3">
                      Popular Categories
                    </h3>
                    <div
                      className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide"
                      style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
                    >
                      {CATEGORIES.map((category) => {
                        const colors = CATEGORY_COLORS[category.slug] || {
                          bg: 'bg-zinc-50',
                          gradient: 'from-zinc-100 to-zinc-50',
                        }
                        return (
                          <button
                            key={category.slug}
                            onClick={() => handleCategoryClick(category.slug)}
                            className="flex flex-col items-center gap-1.5 flex-shrink-0 group cursor-pointer"
                          >
                            <div
                              className={`flex items-center justify-center w-14 h-14 rounded-full bg-gradient-to-br ${colors.gradient} shadow-sm group-hover:scale-110 transition-transform duration-300`}
                            >
                              <span className="text-2xl" role="img" aria-label={category.name}>
                                {category.emoji}
                              </span>
                            </div>
                            <span className="text-[10px] font-bold text-text-primary group-hover:text-primary transition-colors text-center leading-tight w-16 line-clamp-2">
                              {category.name}
                            </span>
                          </button>
                        )
                      })}
                    </div>
                  </div>
                </>
              )}

              {/* Quick tips */}
              <div className="rounded-xl bg-accent/5 border border-accent/10 p-3">
                <p className="text-xs text-text-secondary">
                  💡 <span className="font-medium text-text-primary">Pro tip:</span>{' '}
                  Type a brand name or product to quickly find what you need. We deliver fast to your doorstep!
                </p>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
