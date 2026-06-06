'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useUIStore } from '@/stores/ui-store'
import { useCartStore } from '@/stores/cart-store'
import { formatPrice } from '@/lib/utils'
import { ProductCard } from '@/components/product/product-card'
import {
  Building2,
  Phone,
  ShieldCheck,
  Loader2,
  FileText,
  Search,
  ArrowRight,
  MapPin,
  ShoppingCart,
  Megaphone,
  Package,
  Salad,
  Milk,
  Cookie,
  CupSoda,
  Sparkles,
  Home,
  Croissant,
  Wheat
} from 'lucide-react'

const categoryIconMap: Record<string, React.ComponentType<any>> = {
  'fruits-vegetables': Salad,
  'dairy-breakfast': Milk,
  'snacks-munchies': Cookie,
  'beverages': CupSoda,
  'personal-care': Sparkles,
  'household': Home,
  'bakery-biscuits': Croissant,
  'atta-rice-dal': Wheat,
}
import { toast } from 'sonner'
import Link from 'next/link'

export default function WholesalePage() {
  const router = useRouter()
  
  // Zustand States
  const isB2BMode = useUIStore((s) => s.isB2BMode)
  const setB2BMode = useUIStore((s) => s.setB2BMode)
  const shopName = useUIStore((s) => s.shopName)
  const shopPhone = useUIStore((s) => s.shopPhone)
  const setShopDetails = useUIStore((s) => s.setShopDetails)
  const toggleCart = useUIStore((s) => s.toggleCart)
  const totalItems = useCartStore((s) => s.getTotalItems())

  // Registration Form State
  const [formShopName, setFormShopName] = useState('')
  const [formShopPhone, setFormShopPhone] = useState('')
  const [formGstin, setFormGstin] = useState('')
  const [formShopType, setFormShopType] = useState('Kirana Store')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Catalog States
  const [products, setProducts] = useState<any[]>([])
  const [categories, setCategories] = useState<any[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string>('')
  const [searchQuery, setSearchQuery] = useState('')
  const [isLoadingCatalog, setIsLoadingCatalog] = useState(false)

  // Check registration on mount
  const isRegistered = !!shopName && !!shopPhone

  // Auto-activate B2B mode when entering this page if registered
  useEffect(() => {
    if (isRegistered && !isB2BMode) {
      setB2BMode(true)
      toast.success(`🏢 B2B Mode activated for ${shopName}`)
    }
  }, [isRegistered, isB2BMode, shopName, setB2BMode])

  // Fetch catalog products and categories
  useEffect(() => {
    if (!isRegistered) return

    async function loadCatalog() {
      setIsLoadingCatalog(true)
      try {
        const [prodRes, catRes] = await Promise.all([
          fetch('/api/products?limit=100'),
          fetch('/api/categories'),
        ])
        
        if (prodRes.ok) {
          const data = await prodRes.json()
          setProducts(data.products || [])
        }
        if (catRes.ok) {
          const data = await catRes.json()
          setCategories(data || [])
        }
      } catch (err) {
        toast.error('Failed to load wholesale catalog')
      } finally {
        setIsLoadingCatalog(false)
      }
    }
    loadCatalog()
  }, [isRegistered])

  // Submit registration form
  const handleRegister = (e: React.FormEvent) => {
    e.preventDefault()
    if (!formShopName.trim() || !formShopPhone.trim()) {
      toast.error('Shop Name and Mobile Number are required!')
      return
    }

    if (formShopPhone.length < 10) {
      toast.error('Please enter a valid 10-digit mobile number!')
      return
    }

    setIsSubmitting(true)
    setTimeout(() => {
      setShopDetails(formShopName.trim(), formShopPhone.trim())
      setB2BMode(true)
      setIsSubmitting(false)
      toast.success('🎉 Shop registered successfully! Welcome to Wholesale!')
    }, 1200) // smooth mock loading
  }

  // Clear registration data (deregister)
  const handleResetShopDetails = () => {
    if (confirm('Are you sure you want to log out of this Wholesale account?')) {
      setShopDetails('', '')
      setB2BMode(false)
      router.push('/')
      toast.info('Wholesale account cleared.')
    }
  }

  const filteredProducts = products.filter((p) => {
    const matchesCategory = selectedCategory ? p.categoryId === selectedCategory : true
    const matchesSearch = searchQuery
      ? p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (p.description && p.description.toLowerCase().includes(searchQuery.toLowerCase()))
      : true
    return matchesCategory && matchesSearch
  })

  // 1. REGISTRATION FORM SCREEN
  if (!isRegistered) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center p-4 relative overflow-hidden text-white">
        {/* Glow Effects */}
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-primary/20 rounded-full blur-[120px] pointer-events-none" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-accent/15 rounded-full blur-[120px] pointer-events-none" />

        <div className="w-full max-w-md bg-slate-900/80 backdrop-blur-xl border border-slate-800 p-8 rounded-3xl shadow-2xl relative z-10 space-y-6">
          
          {/* Header */}
          <div className="text-center space-y-2">
            <div className="mx-auto h-14 w-14 rounded-2xl bg-gradient-to-tr from-primary to-accent flex items-center justify-center text-white shadow-lg shadow-primary/20">
              <Building2 className="h-6 w-6 text-white" />
            </div>
            <h1 className="text-2xl font-black tracking-tight text-white mt-3">Wholesale B2B Console</h1>
            <p className="text-xs text-slate-400">
              Enter your retail shop credentials to unlock flat 10% wholesaling discount and bulk deliveries.
            </p>
          </div>

          {/* Form */}
          <form onSubmit={handleRegister} className="space-y-4">
            
            <div className="space-y-1">
              <label htmlFor="shopName" className="text-[10px] font-black text-slate-400 uppercase tracking-wider block">
                Shop Name (Dukan ka Naam) *
              </label>
              <div className="relative">
                <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 h-4 w-4" />
                <input
                  id="shopName"
                  type="text"
                  required
                  placeholder="e.g. Sharma Grocery Store"
                  value={formShopName}
                  onChange={(e) => setFormShopName(e.target.value)}
                  className="w-full bg-slate-950/60 border border-slate-800 rounded-xl py-3 pl-10 pr-4 text-sm placeholder:text-slate-600 text-white focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary transition-all font-semibold"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label htmlFor="shopPhone" className="text-[10px] font-black text-slate-400 uppercase tracking-wider block">
                Contact Number *
              </label>
              <div className="relative">
                <Phone className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 h-4 w-4" />
                <input
                  id="shopPhone"
                  type="tel"
                  required
                  maxLength={10}
                  placeholder="e.g. 9876543210"
                  value={formShopPhone}
                  onChange={(e) => setFormShopPhone(e.target.value.replace(/\D/g, ''))}
                  className="w-full bg-slate-950/60 border border-slate-800 rounded-xl py-3 pl-10 pr-4 text-sm placeholder:text-slate-600 text-white focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary transition-all font-semibold"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label htmlFor="shopType" className="text-[10px] font-black text-slate-400 uppercase tracking-wider block">
                Business Type
              </label>
              <select
                id="shopType"
                value={formShopType}
                onChange={(e) => setFormShopType(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-sm text-white focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary transition-all font-semibold"
              >
                <option value="Kirana Store">Kirana / Retail Store</option>
                <option value="Cafe / Restaurant">Cafe / Restaurant</option>
                <option value="Canteen / Mess">Canteen / Mess</option>
                <option value="Reseller / Distributor">Reseller / Distributor</option>
              </select>
            </div>

            <div className="space-y-1">
              <label htmlFor="gstin" className="text-[10px] font-black text-slate-400 uppercase tracking-wider block">
                GSTIN Number (Optional)
              </label>
              <div className="relative">
                <FileText className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 h-4 w-4" />
                <input
                  id="gstin"
                  type="text"
                  maxLength={15}
                  placeholder="e.g. 07AAAAA1111A1Z1"
                  value={formGstin}
                  onChange={(e) => setFormGstin(e.target.value.toUpperCase())}
                  className="w-full bg-slate-950/60 border border-slate-800 rounded-xl py-3 pl-10 pr-4 text-sm placeholder:text-slate-600 text-white focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary transition-all font-semibold tracking-wide"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="w-full bg-primary hover:bg-primary-dark py-3.5 rounded-xl font-black text-sm text-white transition-all shadow-md active:scale-98 flex items-center justify-center gap-2 cursor-pointer mt-6"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin text-white" />
                  Verifying Business Account...
                </>
              ) : (
                <>
                  Enter Wholesale Portal
                  <ArrowRight className="h-4 w-4" />
                </>
              )}
            </button>
          </form>

          {/* Secure disclaimer */}
          <div className="flex items-center justify-center gap-1.5 text-[10px] font-semibold text-slate-500 border-t border-slate-800/80 pt-4">
            <ShieldCheck className="h-4 w-4 text-accent" />
            Verified B2B wholesale portal for town retail stores.
          </div>
        </div>

        {/* Back Link */}
        <Link href="/" className="mt-6 text-xs font-semibold text-slate-400 hover:text-white transition-colors">
          ← Back to Consumer Site (B2C)
        </Link>
      </div>
    )
  }

  // 2. WHOLESALE PORTAL SHOPPING VIEW
  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 animate-fade-in">
      
      {/* Wholesale Header Banner */}
      <div className="relative rounded-3xl bg-slate-950 overflow-hidden p-6 md:p-8 border border-slate-800 text-white flex flex-col md:flex-row md:items-center justify-between gap-6 shadow-xl">
        <div className="absolute top-0 right-0 w-96 h-96 bg-primary/10 rounded-full blur-[80px] pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-96 h-96 bg-accent/5 rounded-full blur-[80px] pointer-events-none" />
        
        <div className="space-y-2 relative z-10">
          <div className="flex items-center gap-2">
            <span className="bg-primary/20 border border-primary/40 text-primary text-[10px] font-black px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1">
              <Building2 className="h-3 w-3 shrink-0" />
              Wholesale Registered Partner
            </span>
            <span className="bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-[10px] font-black px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1">
              <ShieldCheck className="h-3 w-3 shrink-0" />
              Flat 10% VIP Off Active
            </span>
          </div>
          <h1 className="text-xl md:text-3xl font-black tracking-tight">{shopName}</h1>
          <p className="text-xs text-slate-400 font-semibold flex items-center gap-2.5">
            <span className="flex items-center gap-1"><Phone className="h-3 w-3 text-primary shrink-0" /> {shopPhone}</span>
            <span>|</span>
            <span className="flex items-center gap-1"><MapPin className="h-3 w-3 text-primary shrink-0" /> FastKirana Town Zone</span>
            <span>|</span>
            <span className="flex items-center gap-1"><Building2 className="h-3 w-3 text-primary shrink-0" /> Bulk orders portal</span>
          </p>
        </div>

        <div className="flex gap-3 relative z-10">
          <button
            onClick={toggleCart}
            className="flex items-center gap-2 px-5 py-3 bg-accent hover:bg-accent-dark text-white rounded-xl font-bold text-xs shadow-md transition-all active:scale-95 cursor-pointer"
          >
            <ShoppingCart className="h-4 w-4 shrink-0" /> Wholesale Cart ({totalItems})
          </button>
          <button
            onClick={handleResetShopDetails}
            className="px-5 py-3 border border-slate-800 hover:bg-slate-900 rounded-xl font-bold text-xs transition-colors cursor-pointer text-slate-300"
          >
            Log Out Account
          </button>
        </div>
      </div>

      {/* Promotion Bar */}
      <div className="bg-gradient-to-r from-blue-900/10 via-primary/5 to-blue-900/10 border border-primary/20 rounded-2xl p-4 flex flex-col sm:flex-row justify-between items-center gap-3 text-xs">
        <div className="flex items-center gap-2.5 font-bold text-text-primary">
          <Megaphone className="h-5 w-5 text-primary shrink-0" />
          <span>B2B wholesale terms: Minimum cart subtotal of ₹1,000 required to checkout. Free delivery & flat 10% wholesale discount applies to all products.</span>
        </div>
        <Link href="/checkout" className="flex items-center gap-1.5 px-4 py-2 bg-primary text-white font-extrabold text-[11px] rounded-lg hover:bg-primary-dark transition-all shrink-0">
          Complete Checkout
          <ArrowRight className="h-3 w-3" />
        </Link>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        
        {/* Categories Sidebar */}
        <div className="space-y-4">
          <h2 className="text-sm font-extrabold uppercase text-text-muted tracking-wider px-1">Wholesale Categories</h2>
          <div className="flex lg:flex-col gap-2 overflow-x-auto pb-2 lg:pb-0 scrollbar-none">
            <button
              onClick={() => setSelectedCategory('')}
              className={`px-4 py-2.5 text-xs font-black rounded-xl text-left transition-all whitespace-nowrap border cursor-pointer w-full shrink-0 flex items-center gap-2 ${
                selectedCategory === ''
                  ? 'bg-primary text-white border-primary shadow-sm'
                  : 'bg-card hover:bg-muted/50 border-border text-text-secondary'
              }`}
            >
              <Package className="h-4 w-4 shrink-0" />
              <span>View All Products</span>
            </button>
            {categories.map((cat) => {
              const Icon = categoryIconMap[cat.slug] || Package
              return (
                <button
                  key={cat.id}
                  onClick={() => setSelectedCategory(cat.id)}
                  className={`px-4 py-2.5 text-xs font-black rounded-xl text-left transition-all whitespace-nowrap border cursor-pointer w-full shrink-0 flex items-center gap-2 ${
                    selectedCategory === cat.id
                      ? 'bg-primary text-white border-primary shadow-sm'
                      : 'bg-card hover:bg-muted/50 border-border text-text-secondary'
                  }`}
                >
                  <Icon className="h-4 w-4 shrink-0" />
                  <span>{cat.name}</span>
                </button>
              )
            })}
          </div>
        </div>

        {/* Products Search & List */}
        <div className="lg:col-span-3 space-y-6">
          
          {/* Search bar */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted h-4 w-4" />
            <input
              type="text"
              placeholder="Search wholesale products by name..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full rounded-2xl border border-border bg-card py-3 pl-10 pr-4 text-xs font-semibold placeholder:text-text-muted focus:border-primary focus:outline-none transition-all shadow-sm"
            />
          </div>

          {isLoadingCatalog ? (
            <div className="flex flex-col items-center justify-center py-20 gap-2">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
              <p className="text-xs text-text-muted font-bold">Loading wholesale inventory catalog...</p>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="flex justify-between items-center px-1">
                <span className="text-[11px] font-black uppercase text-text-muted tracking-wider">
                  Wholesale Catalog ({filteredProducts.length} items)
                </span>
                {selectedCategory && (
                  <button
                    onClick={() => setSelectedCategory('')}
                    className="text-xs text-primary hover:underline font-bold"
                  >
                    Clear Filter
                  </button>
                )}
              </div>

              {filteredProducts.length === 0 ? (
                <div className="text-center py-20 border-2 border-dashed border-border rounded-3xl bg-muted/10">
                  <Package className="h-10 w-10 text-text-muted mx-auto" />
                  <h3 className="text-sm font-bold text-text-primary mt-2">No wholesale products found</h3>
                  <p className="text-xs text-text-muted mt-1">Try resetting your category filters or search query.</p>
                </div>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
                  {filteredProducts.map((p) => (
                    <ProductCard key={p.id} product={p} />
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
