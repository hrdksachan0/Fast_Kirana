'use client'
import { catalogApiUrl } from '@/lib/api-url';

import { useState, useRef, useEffect, useCallback, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { AnimatePresence, motion } from 'framer-motion'
import { Search, X, TrendingUp, History, Loader2, Plus, Minus, Mic, MicOff, ArrowRight, ChevronRight } from 'lucide-react'
import { useUIStore } from '@/stores/ui-store'
import { useCart } from '@/hooks/use-cart'
import { ProductCard } from '@/components/product/product-card'
import { ProductImage } from '@/components/product/product-image'
import { isCafeProduct, cn, getProductLimit, isProductStoreClosed } from '@/lib/utils'
import { Product } from '@/types'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'
import { getOutletName } from '@/lib/constants'

interface SearchOverlayProps {
  open: boolean
  onClose: () => void
}

// ─── Typeahead Index Types ───
interface TypeaheadTerm {
  term: string
  category: string
  categorySlug: string
}

interface TypeaheadBrand {
  name: string
  imageUrl: string | null
  count: number
}

interface TypeaheadProduct {
  id: string
  name: string
  slug: string
  imageUrl: string
  price: number
  mrp: number
  discount: number
  unit: string
  stock: number
  isAvailable: boolean
  tags: string[]
  restaurantId: string | null
  variants: any
  categoryName: string
  categorySlug: string
}

interface TypeaheadIndex {
  terms: TypeaheadTerm[]
  brands: TypeaheadBrand[]
  categories: { name: string; slug: string; imageUrl: string | null }[]
  products: TypeaheadProduct[]
}

// ─── Singleton Typeahead Cache ───
let _typeaheadCache: TypeaheadIndex | null = null
let _typeaheadFetchPromise: Promise<TypeaheadIndex> | null = null
let _typeaheadFetchedAt = 0
const TYPEAHEAD_TTL = 5 * 60 * 1000 // 5 minutes

async function getTypeaheadIndex(storeId?: string): Promise<TypeaheadIndex> {
  const now = Date.now()
  if (_typeaheadCache && now - _typeaheadFetchedAt < TYPEAHEAD_TTL) {
    return _typeaheadCache
  }
  if (_typeaheadFetchPromise) return _typeaheadFetchPromise

  const storeParam = storeId ? `?storeId=${encodeURIComponent(storeId)}` : ''
  _typeaheadFetchPromise = fetch(`${catalogApiUrl()}/api/typeahead${storeParam}`)
    .then(res => res.json())
    .then(data => {
      _typeaheadCache = data as TypeaheadIndex
      _typeaheadFetchedAt = Date.now()
      _typeaheadFetchPromise = null
      return _typeaheadCache
    })
    .catch(err => {
      console.error('[Typeahead] Failed to load index:', err)
      _typeaheadFetchPromise = null
      return { terms: [], brands: [], categories: [], products: [] } as TypeaheadIndex
    })

  return _typeaheadFetchPromise
}

// ─── Map category slugs to visual colors ───
const CATEGORY_COLORS: Record<string, { bg: string; gradient: string }> = {
  'fruits-vegetables': { bg: 'bg-emerald-50', gradient: 'from-emerald-100 to-emerald-50' },
  'dairy-breakfast': { bg: 'bg-blue-50', gradient: 'from-blue-100 to-blue-50' },
  'snacks-munchies': { bg: 'bg-amber-50', gradient: 'from-amber-100 to-amber-50' },
  'beverages': { bg: 'bg-cyan-50', gradient: 'from-cyan-100 to-cyan-50' },
  'personal-care': { bg: 'bg-pink-50', gradient: 'from-pink-100 to-pink-50' },
  'household': { bg: 'bg-teal-50', gradient: 'from-teal-100 to-teal-50' },
  'bakery-biscuits': { bg: 'bg-orange-50', gradient: 'from-orange-100 to-orange-50' },
  'atta-rice-dal': { bg: 'bg-yellow-50', gradient: 'from-yellow-100 to-yellow-50' },
}

export function SearchOverlay({ open, onClose }: SearchOverlayProps) {
  const router = useRouter()
  const inputRef = useRef<HTMLInputElement>(null)
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState<number>(-1)
  const [loading, setLoading] = useState(false)
  const [recentSearches, setRecentSearches] = useState<string[]>([])
  const [isListening, setIsListening] = useState(false)
  const recognitionRef = useRef<any>(null)

  // Typeahead state
  const [typeaheadIndex, setTypeaheadIndex] = useState<TypeaheadIndex | null>(null)

  // Lock body scroll when search overlay is open
  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [open])

  const activeStoreId = useUIStore((s) => s.activeStoreId)
  const [trendingSearches, setTrendingSearches] = useState<string[]>([])

  // Load typeahead index on overlay open
  useEffect(() => {
    if (open) {
      getTypeaheadIndex(activeStoreId || undefined).then(setTypeaheadIndex)
    }
  }, [open, activeStoreId])

  useEffect(() => {
    // Fetch trending searches (products scoped to active store)
    const storeParam = activeStoreId ? `&storeId=${encodeURIComponent(activeStoreId)}` : ''
    fetch(`${catalogApiUrl()}/api/products?trending=true${storeParam}`)
      .then((res) => res.json())
      .then((data) => {
        if (data && Array.isArray(data.products)) {
          const words = data.products.map((p: any) => p.name.trim())
          if (words.length > 0) {
            setTrendingSearches(words)
          }
        }
      })
      .catch((err) => console.error('Failed to fetch trending searches:', err))
  }, [activeStoreId])

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
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
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
    }
  }, [open])

  // ─── BLINKIT-STYLE: Client-side instant typeahead matching ───
  const typeaheadResults = useMemo(() => {
    const cleanQuery = query.trim().toLowerCase()
    if (cleanQuery.length < 1 || !typeaheadIndex) return null

    const { terms, brands, products } = typeaheadIndex

    // 1. Text suggestions — prefix match on product names
    const textSuggestions: { term: string; category: string; type: 'product' | 'brand' | 'category' }[] = []
    const seenTerms = new Set<string>()

    // Brand matches first
    for (const brand of brands) {
      if (brand.name.toLowerCase().startsWith(cleanQuery) && !seenTerms.has(brand.name.toLowerCase())) {
        textSuggestions.push({ term: brand.name, category: `${brand.count} products`, type: 'brand' })
        seenTerms.add(brand.name.toLowerCase())
        if (textSuggestions.length >= 2) break
      }
    }

    // Product name matches
    for (const t of terms) {
      if (textSuggestions.length >= 6) break
      const tLower = t.term.toLowerCase()
      if (tLower.includes(cleanQuery) && !seenTerms.has(tLower)) {
        textSuggestions.push({ term: t.term, category: t.category, type: 'product' })
        seenTerms.add(tLower)
      }
    }

    // Category matches
    for (const cat of typeaheadIndex.categories) {
      if (textSuggestions.length >= 7) break
      if (cat.name.toLowerCase().includes(cleanQuery) && !seenTerms.has(cat.name.toLowerCase())) {
        textSuggestions.push({ term: cat.name, category: 'Category', type: 'category' })
        seenTerms.add(cat.name.toLowerCase())
      }
    }

    // 2. Product matches — for inline 3-per-row grid
    const matchedProducts = products.filter(p => {
      const pName = p.name.toLowerCase()
      const pTags = (p.tags || []).map(t => t.toLowerCase())
      return pName.includes(cleanQuery) || pTags.some(t => t.includes(cleanQuery))
    })

    // Sort: in-stock first, then by relevance (starts-with > contains)
    matchedProducts.sort((a, b) => {
      const aInStock = a.isAvailable && a.stock > 0 ? 1 : 0
      const bInStock = b.isAvailable && b.stock > 0 ? 1 : 0
      if (aInStock !== bInStock) return bInStock - aInStock

      const aStartsWith = a.name.toLowerCase().startsWith(cleanQuery) ? 1 : 0
      const bStartsWith = b.name.toLowerCase().startsWith(cleanQuery) ? 1 : 0
      if (aStartsWith !== bStartsWith) return bStartsWith - aStartsWith

      return 0
    })

    return {
      textSuggestions: textSuggestions.slice(0, 6),
      products: matchedProducts.slice(0, 12), // Max 12 products (4 rows of 3)
      totalMatches: matchedProducts.length,
    }
  }, [query, typeaheadIndex])

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (!open) return
      if (e.key === 'Escape') {
        onClose()
      } else if (e.key === 'Enter' && query.trim()) {
        e.preventDefault()
        handleSearch(query)
      }
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [open, onClose, query])

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

  const handleAddProduct = (e: React.MouseEvent, product: TypeaheadProduct | Product) => {
    e.preventDefault()
    e.stopPropagation()
    
    if (product.stock <= 0 || product.isAvailable === false) {
      toast.error(`${product.name} is currently out of stock`)
      return
    }
    
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
      isAvailable: product.isAvailable,
      category: { slug: (product as any).categorySlug || (product as any).category?.slug || '' },
      tags: product.tags || [],
      restaurantId: (product as any).restaurantId || (product as any).restaurant?.id,
      restaurantName: (product as any).restaurantName || (product as any).restaurant?.name,
      restaurant: (product as any).restaurant,
      menuSection: (product as any).menuSection || null,
    }
    
    addItem(cartProduct as any)
    saveSearchTerm(product.name)
  }

  // ─── Highlight matching text in suggestions ───
  const highlightMatch = (text: string, query: string) => {
    const idx = text.toLowerCase().indexOf(query.toLowerCase())
    if (idx === -1) return <span>{text}</span>
    return (
      <>
        <span>{text.slice(0, idx)}</span>
        <span className="font-black text-text-primary">{text.slice(idx, idx + query.length)}</span>
        <span>{text.slice(idx + query.length)}</span>
      </>
    )
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
            transition={{ type: 'spring', damping: 26, stiffness: 210 }}
            className="fixed inset-x-0 bottom-0 top-0 z-50 flex flex-col bg-white/95 dark:bg-zinc-950/95 backdrop-blur-xl md:inset-x-auto md:left-1/2 md:top-8 md:bottom-auto md:w-[640px] md:-translate-x-1/2 md:rounded-2xl md:max-h-[85vh] md:shadow-[0_20px_50px_rgba(0,0,0,0.15)] md:border md:border-zinc-200/80 md:dark:border-white/[0.06]"
          >
            {/* Top: Search bar */}
            <div className="flex items-center gap-3 p-4 border-b border-zinc-200/60 dark:border-white/[0.05]">
              <form onSubmit={handleSubmit} className="flex-1 relative">
                <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4.5 w-4.5 text-zinc-400 dark:text-zinc-500" />
                <input
                  ref={inputRef}
                  type="text"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Search for groceries, brands..."
                  className="w-full pl-10 pr-12 py-3 bg-zinc-50/60 dark:bg-white/[0.03] border border-zinc-200/80 dark:border-white/[0.08] rounded-xl text-sm text-text-primary placeholder:text-text-muted focus:outline-none focus:bg-white/80 focus:dark:bg-black/45 focus:border-primary/45 focus:ring-4 focus:ring-primary/5 transition-all font-bold shadow-inner"
                />
                <div className="absolute right-3.5 top-1/2 -translate-y-1/2 flex items-center gap-2">
                  {query.length > 0 ? (
                    <button
                      type="button"
                      onClick={() => setQuery('')}
                      className="h-7 w-7 rounded-lg flex items-center justify-center text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-900/60 hover:text-text-primary transition-all cursor-pointer"
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={toggleVoiceSearch}
                      className={cn(
                        "h-7 w-7 rounded-lg flex items-center justify-center transition-all cursor-pointer",
                        isListening
                          ? "bg-red-500/10 text-red-500 animate-pulse-gentle"
                          : "text-zinc-400 dark:text-zinc-500 hover:bg-zinc-100 dark:hover:bg-zinc-900/60 hover:text-text-primary"
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
                className="flex h-9 w-9 items-center justify-center rounded-full bg-zinc-150/70 dark:bg-zinc-900/80 hover:bg-zinc-200/80 dark:hover:bg-zinc-800 text-text-primary transition-colors flex-shrink-0 cursor-pointer"
                aria-label="Close search"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Content area */}
            <div className="flex-1 overflow-y-auto pb-36">
              {query.trim().length >= 1 && typeaheadResults ? (
                /* ─── BLINKIT-STYLE: Text Suggestions + Product Grid ─── */
                typeaheadResults.textSuggestions.length > 0 || typeaheadResults.products.length > 0 ? (
                  <div>
                    {/* Zone 1: Text Autocomplete Suggestions (Instant, Blinkit-style) */}
                    {typeaheadResults.textSuggestions.length > 0 && (
                      <div className="border-b border-zinc-100 dark:border-zinc-800">
                        {typeaheadResults.textSuggestions.map((suggestion, idx) => (
                          <button
                            key={`${suggestion.term}-${idx}`}
                            onClick={() => {
                              if (suggestion.type === 'category') {
                                const cat = typeaheadIndex?.categories.find(c => c.name === suggestion.term)
                                if (cat) {
                                  handleCategoryClick(cat.slug)
                                  return
                                }
                              }
                              setQuery(suggestion.term)
                              handleSearch(suggestion.term)
                            }}
                            className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-zinc-50 dark:hover:bg-zinc-900/40 active:bg-zinc-100 transition-colors cursor-pointer border-b border-zinc-50 dark:border-zinc-900 last:border-b-0"
                          >
                            {/* Icon */}
                            <div className="flex-shrink-0 w-8 h-8 rounded-lg bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center">
                              {suggestion.type === 'brand' ? (
                                <span className="text-sm">🏷️</span>
                              ) : suggestion.type === 'category' ? (
                                <span className="text-sm">📂</span>
                              ) : (
                                <Search className="h-3.5 w-3.5 text-zinc-400" />
                              )}
                            </div>

                            {/* Text */}
                            <div className="flex-1 min-w-0 text-left">
                              <p className="text-[13px] font-bold text-text-primary truncate leading-snug">
                                {highlightMatch(suggestion.term, query.trim())}
                              </p>
                              {suggestion.category && (
                                <p className="text-[10px] text-text-muted font-semibold truncate">
                                  {suggestion.type === 'brand' ? `${suggestion.category}` : suggestion.category}
                                </p>
                              )}
                            </div>

                            {/* Arrow */}
                            <ChevronRight className="h-3.5 w-3.5 text-zinc-300 dark:text-zinc-600 flex-shrink-0" />
                          </button>
                        ))}
                      </div>
                    )}

                    {/* Zone 2: Product Grid — 3 per row (Blinkit-style) */}
                    {typeaheadResults.products.length > 0 && (
                      <div className="p-3">
                        {/* Results header */}
                        <div className="flex items-center justify-between mb-2.5 px-1">
                          <p className="text-[11px] text-text-muted font-bold">
                            Showing {Math.min(typeaheadResults.products.length, 12)} of {typeaheadResults.totalMatches} items for &ldquo;{query.trim()}&rdquo;
                          </p>
                          {typeaheadResults.totalMatches > 12 && (
                            <button
                              onClick={() => handleSearch(query)}
                              className="text-[11px] font-black text-primary flex items-center gap-0.5 cursor-pointer"
                            >
                              View all <ArrowRight className="h-3 w-3" />
                            </button>
                          )}
                        </div>

                        {/* 3-per-row product grid */}
                        <div 
                          onClickCapture={(e) => {
                            const target = e.target as HTMLElement
                            const anchor = target.closest('a')
                            if (anchor && anchor.getAttribute('href')?.startsWith('/product/')) {
                              onClose()
                            }
                          }}
                          className="grid grid-cols-3 gap-2"
                        >
                          {typeaheadResults.products.map((product) => (
                            <ProductCard key={product.id} product={product as any} isCompact />
                          ))}
                        </div>

                        {/* View all results button */}
                        {typeaheadResults.totalMatches > 3 && (
                          <button
                            type="button"
                            onClick={() => handleSearch(query)}
                            className="w-full mt-3 py-2.5 px-4 rounded-xl border border-primary/25 bg-primary/5 hover:bg-primary/10 text-primary font-bold text-xs flex items-center justify-between transition-all duration-200 cursor-pointer shadow-xs active:scale-[0.99]"
                          >
                            <span>View all results for &ldquo;{query.trim()}&rdquo;</span>
                            <span className="flex items-center gap-1 text-[11px] font-black uppercase tracking-wider">
                              Full Search <ArrowRight className="h-3.5 w-3.5" />
                            </span>
                          </button>
                        )}
                      </div>
                    )}
                  </div>
                ) : (
                  /* No results */
                  <div className="p-4">
                    <div className="text-center py-8 px-4 rounded-2xl border border-border/60 bg-muted/20">
                      <span className="text-3xl">🔍</span>
                      <h4 className="text-sm font-bold text-text-primary mt-2">No matching products found</h4>
                      <p className="text-xs text-text-muted mt-1">Try searching for other terms or browse categories below</p>
                    </div>
                  </div>
                )
              ) : (
                /* ─── Empty State: History + Trending + Categories ─── */
                <div className="p-4 space-y-6">
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
                            className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full border border-zinc-200/80 dark:border-white/[0.08] bg-zinc-50/50 dark:bg-white/[0.03] text-xs font-semibold text-text-primary hover:bg-primary/5 hover:border-primary/35 hover:text-primary active:scale-95 transition-all duration-300 cursor-pointer shadow-xs"
                          >
                            <History className="h-3 w-3 text-zinc-400 dark:text-zinc-500" />
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
                      {trendingSearches.map((term) => (
                        <button
                          key={term}
                          onClick={() => handleTrendingClick(term)}
                          className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full border border-zinc-200/80 dark:border-white/[0.08] bg-zinc-50/50 dark:bg-white/[0.03] text-xs font-bold text-text-primary hover:bg-primary/5 hover:border-primary/35 hover:text-primary active:scale-95 transition-all duration-300 cursor-pointer shadow-xs"
                        >
                          <span className="text-xs">🔥</span>
                          <span>{term}</span>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Popular categories */}
                  {typeaheadIndex && typeaheadIndex.categories.length > 0 && (
                    <div>
                      <h3 className="text-sm font-bold text-text-primary mb-3">
                        Popular Categories
                      </h3>
                      <div
                        className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide"
                        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
                      >
                        {typeaheadIndex.categories.map((category) => {
                          const colors = CATEGORY_COLORS[category.slug] || {
                            bg: 'bg-zinc-50',
                            gradient: 'from-zinc-100 to-zinc-50',
                          }
                          const hasImage = category.imageUrl && (
                            category.imageUrl.startsWith('data:image/') ||
                            category.imageUrl.startsWith('/') ||
                            category.imageUrl.startsWith('http')
                          )
                          return (
                            <button
                              key={category.slug}
                              onClick={() => handleCategoryClick(category.slug)}
                              className="flex flex-col items-center gap-1.5 flex-shrink-0 group cursor-pointer"
                            >
                              <div
                                className={`flex items-center justify-center w-14 h-14 rounded-full bg-gradient-to-br ${colors.gradient} shadow-sm group-hover:scale-110 transition-transform duration-300 overflow-hidden relative`}
                              >
                                {hasImage ? (
                                  <img
                                    src={category.imageUrl!}
                                    alt={category.name}
                                    className="w-full h-full object-cover"
                                    loading="lazy"
                                  />
                                ) : (
                                  <span className="text-2xl" role="img" aria-label={category.name}>
                                    {category.imageUrl && category.imageUrl.length < 5 ? category.imageUrl : '🛒'}
                                  </span>
                                )}
                              </div>
                              <span className="text-[10px] font-bold text-text-primary group-hover:text-primary transition-colors text-center leading-tight w-16 line-clamp-2">
                                {category.name}
                              </span>
                            </button>
                          )
                        })}
                      </div>
                    </div>
                  )}

                  {/* Quick tips */}
                  <div className="rounded-xl bg-accent/5 border border-accent/10 p-3">
                    <p className="text-xs text-text-secondary">
                      💡 <span className="font-medium text-text-primary">Pro tip:</span>{' '}
                      Type a brand name or product to quickly find what you need. We deliver fast to your doorstep!
                    </p>
                  </div>
                </div>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
