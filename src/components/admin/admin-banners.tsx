'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { 
  Image as ImageIcon, 
  Plus, 
  Trash2, 
  Edit2, 
  Check, 
  X, 
  Gift, 
  Sparkles, 
  Eye, 
  Loader2, 
  ArrowUp, 
  ArrowDown, 
  Power
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface PromoBanner {
  id: string
  title: string
  description: string
  code: string
  gradient: string
  type: string
  imageUrl?: string | null
  linkUrl?: string | null
  isActive: boolean
  sortOrder: number
}

// Predefined Gradient Options
const GRADIENT_PRESETS = [
  { name: 'Diwali Gold (Orange/Amber)', value: 'from-amber-600 via-orange-500 to-yellow-500' },
  { name: 'Holi Colors (Pink/Purple/Yellow)', value: 'from-pink-500 via-purple-500 to-yellow-400' },
  { name: 'Eid Emerald (Green/Teal)', value: 'from-emerald-600 via-teal-500 to-cyan-500' },
  { name: 'New Year Purple (Violet/Pink)', value: 'from-violet-600 via-fuchsia-600 to-pink-500' },
  { name: 'Store Red (Default Red/Orange)', value: 'from-primary via-rose-500 to-orange-400' },
  { name: 'Fresh Green (Mint/Emerald)', value: 'from-accent via-emerald-500 to-teal-400' },
  { name: 'Midnight Snacks (Blue/Amber)', value: 'from-discount via-orange-500 to-amber-400' },
  { name: 'Night Neon (Dark Indigo/Blue)', value: 'from-indigo-900 via-purple-800 to-blue-600' }
]

// Predefined Festival/Occasion Templates
const FESTIVAL_TEMPLATES = [
  {
    name: '📦 Fast Delivery (Ghatampur)',
    title: 'Fast Delivery in Ghatampur',
    description: 'Milk, Fruits, Vegetables, Snacks & more',
    code: '',
    gradient: 'from-rose-500 via-rose-500 to-orange-400',
    type: 'express-delivery',
    linkUrl: '/category/fruits-vegetables'
  },
  {
    name: '🥬 Farm Fresh Vegetables & Fruits',
    title: 'Farm Fresh Vegetables & Fruits',
    description: 'Directly sourced from local farms. Handpicked for premium quality.',
    code: 'SAVE20',
    gradient: 'from-emerald-600 via-emerald-500 to-teal-400',
    type: 'fresh',
    linkUrl: '/category/fruits-vegetables'
  },
  {
    name: '🥛 Super Savings (First Order)',
    title: 'Super Savings on First Order!',
    description: 'Get flat 50% off up to ₹100 on fruits, veggies, dairy, and snacks.',
    code: 'WELCOME50',
    gradient: 'from-rose-600 via-rose-500 to-orange-400',
    type: 'first-order',
    linkUrl: '/category/fruits-vegetables'
  },
  {
    name: '🪔 Diwali Special',
    title: 'Shubh Deepavali Festive Offer!',
    description: 'Celebrate Diwali with sweets, dry fruits, and diyas. Get flat ₹150 off on your purchase!',
    code: 'DIWALI150',
    gradient: 'from-amber-600 via-orange-500 to-yellow-500',
    type: 'festival'
  },
  {
    name: '🎨 Holi Splash',
    title: 'Holi Ke Rang, FastKirana Ke Sang!',
    description: 'Get natural herbal gulal, sweets, thandai, and pichkaris delivered in 10 minutes!',
    code: 'HOLI100',
    gradient: 'from-pink-500 via-purple-500 to-yellow-400',
    type: 'festival'
  },
  {
    name: '🌙 Eid Mubarak',
    title: 'Eid Mubarak Festive Delights!',
    description: 'Save 20% on fresh dates, sheer khurma ingredients, milk, and dry fruits today.',
    code: 'EIDSPECIAL',
    gradient: 'from-emerald-600 via-teal-500 to-cyan-500',
    type: 'festival'
  },
  {
    name: '🎉 New Year Celebration',
    title: 'Happy New Year 2027 Bash!',
    description: 'Fuel your party with sodas, chips, chocolates, and instant snacks. Flat ₹200 off!',
    code: 'NY2027',
    gradient: 'from-violet-600 via-fuchsia-600 to-pink-500',
    type: 'festival'
  }
]

interface AdminBannersProps {
  categories?: any[]
  products?: any[]
}

export function AdminBanners({ categories = [], products = [] }: AdminBannersProps) {
  const [banners, setBanners] = useState<PromoBanner[]>([])
  const [loading, setLoading] = useState(true)
  
  // Form States
  const [editingId, setEditingId] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [code, setCode] = useState('')
  const [gradient, setGradient] = useState(GRADIENT_PRESETS[4].value)
  const [type, setType] = useState('festival')
  const [imageUrl, setImageUrl] = useState('')
  const [linkUrl, setLinkUrl] = useState('')
  const [linkType, setLinkType] = useState<'none' | 'category' | 'product' | 'custom'>('none')
  const [selectedCategory, setSelectedCategory] = useState('')
  const [selectedProduct, setSelectedProduct] = useState('')
  const [customLinkUrl, setCustomLinkUrl] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [sortOrder, setSortOrder] = useState('0')
  const [submitting, setSubmitting] = useState(false)

  // Cloudinary Settings and upload states
  const [settingsMap, setSettingsMap] = useState<Record<string, string>>({})
  const [isUploading, setIsUploading] = useState(false)

  // Load settings on Mount
  useEffect(() => {
    async function fetchSettings() {
      try {
        const res = await fetch('/api/settings')
        if (res.ok) {
          const data = await res.json()
          setSettingsMap(data)
        }
      } catch (err) {
        console.error('Failed to load settings:', err)
      }
    }
    fetchSettings()
  }, [])

  // Load Banners on Mount
  const fetchBanners = async () => {
    try {
      setLoading(true)
      const res = await fetch('/api/admin/banners')
      if (!res.ok) throw new Error('Failed to load banners')
      const data = await res.json()
      setBanners(data || [])
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Could not load promo banners')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchBanners()
  }, [])

  // Handle Cloudinary direct upload
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    const cloudName = settingsMap['cloudinary_cloud_name']
    const uploadPreset = settingsMap['cloudinary_upload_preset']

    if (!cloudName || !uploadPreset) {
      toast.error('Cloudinary not configured! Go to the "Store Settings" tab to set Cloudinary Cloud Name and Preset first.')
      return
    }

    setIsUploading(true)
    const formData = new FormData()
    formData.append('file', file)
    formData.append('upload_preset', uploadPreset)

    try {
      const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
        method: 'POST',
        body: formData,
      })

      if (res.ok) {
        const data = await res.json()
        setImageUrl(data.secure_url)
        toast.success('Banner image uploaded to Cloudinary successfully!')
      } else {
        const errData = await res.json()
        toast.error(`Cloudinary upload failed: ${errData.error?.message || 'Check credentials'}`)
      }
    } catch (err) {
      console.error(err)
      toast.error('Could not connect to Cloudinary.')
    } finally {
      setIsUploading(false)
      e.target.value = ''
    }
  }

  // Apply a Template
  const handleApplyTemplate = (tpl: any) => {
    setTitle(tpl.title)
    setDescription(tpl.description)
    setCode(tpl.code || '')
    setGradient(tpl.gradient)
    setType(tpl.type)
    setImageUrl('')
    
    const link = tpl.linkUrl || ''
    setLinkUrl(link)
    if (!link) {
      setLinkType('none')
      setSelectedCategory('')
      setSelectedProduct('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/category/')) {
      setLinkType('category')
      const slug = link.replace('/category/', '')
      setSelectedCategory(slug)
      setSelectedProduct('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/product/')) {
      setLinkType('product')
      const slug = link.replace('/product/', '')
      setSelectedCategory('')
      setSelectedProduct(slug)
      setCustomLinkUrl('')
    } else {
      setLinkType('custom')
      setSelectedCategory('')
      setSelectedProduct('')
      setCustomLinkUrl(link)
    }

    toast.success(`${tpl.name} template applied! Customize below if needed.`)
  }

  // Clear Form
  const resetForm = () => {
    setEditingId(null)
    setTitle('')
    setDescription('')
    setCode('')
    setGradient(GRADIENT_PRESETS[4].value)
    setType('festival')
    setImageUrl('')
    setLinkUrl('')
    setLinkType('none')
    setSelectedCategory('')
    setSelectedProduct('')
    setCustomLinkUrl('')
    setIsActive(true)
    setSortOrder('0')
  }

  // Populate Edit Fields
  const handleEditClick = (b: PromoBanner) => {
    setEditingId(b.id)
    setTitle(b.title)
    setDescription(b.description)
    setCode(b.code || '')
    setGradient(b.gradient)
    setType(b.type)
    setImageUrl(b.imageUrl || '')
    setLinkUrl(b.linkUrl || '')
    
    const link = b.linkUrl || ''
    if (!link) {
      setLinkType('none')
      setSelectedCategory('')
      setSelectedProduct('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/category/')) {
      setLinkType('category')
      const slug = link.replace('/category/', '')
      setSelectedCategory(slug)
      setSelectedProduct('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/product/')) {
      setLinkType('product')
      const slug = link.replace('/product/', '')
      setSelectedCategory('')
      setSelectedProduct(slug)
      setCustomLinkUrl('')
    } else {
      setLinkType('custom')
      setSelectedCategory('')
      setSelectedProduct('')
      setCustomLinkUrl(link)
    }

    setIsActive(b.isActive)
    setSortOrder(String(b.sortOrder))
    
    // Scroll form into view
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Submit banner (Create or Edit)
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!title.trim() || !description.trim()) {
      toast.error('Please fill in title and description')
      return
    }

    try {
      setSubmitting(true)

      let computedLinkUrl: string | null = null
      if (linkType === 'category') {
        computedLinkUrl = selectedCategory ? `/category/${selectedCategory}` : null
      } else if (linkType === 'product') {
        computedLinkUrl = selectedProduct ? `/product/${selectedProduct}` : null
      } else if (linkType === 'custom') {
        computedLinkUrl = customLinkUrl.trim() || null
      }

      const payload = {
        id: editingId || undefined,
        title: title.trim(),
        description: description.trim(),
        code: code.trim().toUpperCase(),
        gradient,
        type,
        imageUrl: imageUrl.trim() || null,
        linkUrl: computedLinkUrl,
        isActive,
        sortOrder: parseInt(sortOrder, 10) || 0
      }

      const method = editingId ? 'PUT' : 'POST'
      const res = await fetch('/api/admin/banners', {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to save banner')
      }

      toast.success(editingId ? 'Banner updated successfully!' : 'New Banner created successfully!')
      resetForm()
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error saving banner details')
    } finally {
      setSubmitting(false)
    }
  }

  // Toggle banner Active state directly
  const handleToggleActive = async (b: PromoBanner) => {
    try {
      const res = await fetch('/api/admin/banners', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: b.id, isActive: !b.isActive })
      })

      if (!res.ok) throw new Error('Failed to update active state')
      
      toast.success(`Banner ${!b.isActive ? 'activated' : 'deactivated'} successfully!`)
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error toggling active state')
    }
  }

  // Change order priority
  const handleOrderChange = async (b: PromoBanner, direction: 'up' | 'down') => {
    const delta = direction === 'up' ? -1 : 1
    try {
      const res = await fetch('/api/admin/banners', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: b.id, sortOrder: b.sortOrder + delta })
      })

      if (!res.ok) throw new Error('Failed to update ordering priority')
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error changing banner order')
    }
  }

  // Delete banner
  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this promo banner?')) return

    try {
      const res = await fetch(`/api/admin/banners?id=${id}`, {
        method: 'DELETE'
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to delete banner')
      }

      toast.success('Promo banner deleted successfully')
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error deleting banner')
    }
  }

  return (
    <motion.div 
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -15 }}
      transition={{ duration: 0.35, ease: 'easeOut' }}
      className="grid grid-cols-1 lg:grid-cols-3 gap-6"
    >
      {/* Creation and Edit Panel */}
      <div className="lg:col-span-2 space-y-6">
        
        {/* Templates Presets */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex items-center gap-1.5">
            <Sparkles className="h-5 w-5 text-accent animate-pulse-slow" />
            <h3 className="text-sm font-bold text-text-primary">Apply Festival Templates</h3>
          </div>
          <p className="text-[11px] text-text-secondary leading-relaxed">
            Auto-fill values with pre-configured settings for major Indian holidays and events.
          </p>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
            {FESTIVAL_TEMPLATES.map((tpl) => (
              <button
                key={tpl.name}
                type="button"
                onClick={() => handleApplyTemplate(tpl)}
                className="py-2.5 px-3 border border-border/80 text-[10px] font-black rounded-xl bg-muted/20 hover:bg-accent/10 hover:border-accent hover:text-accent transition-all text-center leading-normal cursor-pointer active:scale-95 shadow-sm"
              >
                {tpl.name}
              </button>
            ))}
          </div>
        </div>

        {/* Input Form */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          <div>
            <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
              <ImageIcon className="h-5 w-5 text-accent" />
              {editingId ? 'Edit Promo Banner' : 'Create Custom Banner'}
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Configure banners shown in the top slider on the FastKirana homepage.
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              
              {/* Banner Title */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Banner Title *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Diwali Dhamaka Sale!"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                />
              </div>

              {/* Promo Coupon Code */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Coupon Code (Optional)</label>
                <div className="relative">
                  <Gift className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                  <input
                    type="text"
                    placeholder="e.g. DIWALI100 (Leave blank for no coupon)"
                    value={code}
                    onChange={(e) => setCode(e.target.value.toUpperCase())}
                    className="w-full bg-muted/40 border border-border pl-9 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-mono font-bold text-primary"
                  />
                </div>
              </div>

              {/* Banner Description */}
              <div className="md:col-span-2 space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Description / Subtitle *</label>
                <textarea
                  rows={2}
                  required
                  placeholder="Explain the offer (e.g. Get up to 40% discount on sweets, colors and diyas.)"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                />
              </div>

              {/* Background Gradient */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Background Gradient Theme</label>
                <select
                  value={gradient}
                  onChange={(e) => setGradient(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                >
                  {GRADIENT_PRESETS.map((g) => (
                    <option key={g.name} value={g.value}>
                      {g.name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Visual Badge Type */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Visual Badge Icon Type</label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                >
                  <option value="festival">🌸 Festival/Holiday (Diyas / Floral)</option>
                  <option value="first-order">🥛 Milk & Fruits Essentials</option>
                  <option value="fresh">🥬 Farm Fresh (Leafy Greens)</option>
                  <option value="snacks">🥤 Cold Drinks & Snacks</option>
                  <option value="express-delivery">🚚 Ghatampur Express Layout (Light Pink)</option>
                  <option value="custom">📦 Generic Delivery Box</option>
                </select>
              </div>

              {/* Link Type Selector */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Banner Click Link Type</label>
                <select
                  value={linkType}
                  onChange={(e) => {
                    const val = e.target.value as any
                    setLinkType(val)
                    if (val === 'category' && !selectedCategory && categories.length > 0) {
                      setSelectedCategory(categories[0].slug)
                    }
                    if (val === 'product' && !selectedProduct && products.length > 0) {
                      setSelectedProduct(products[0].slug)
                    }
                  }}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                >
                  <option value="none">No Link (Unlinked)</option>
                  <option value="category">Link to Category</option>
                  <option value="product">Link to Product</option>
                  <option value="custom">Custom Redirect URL</option>
                </select>
              </div>

              {/* Conditional Link Target Selector */}
              {linkType === 'category' && (
                <div className="space-y-1">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Select Target Category</label>
                  <select
                    value={selectedCategory}
                    onChange={(e) => setSelectedCategory(e.target.value)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                  >
                    <option value="">-- Choose Category --</option>
                    {categories.map((cat: any) => (
                      <option key={cat.id} value={cat.slug}>
                        {cat.name} ({cat.slug})
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {linkType === 'product' && (
                <div className="space-y-1">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Select Target Product</label>
                  <select
                    value={selectedProduct}
                    onChange={(e) => setSelectedProduct(e.target.value)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                  >
                    <option value="">-- Choose Product --</option>
                    {products.map((prod: any) => (
                      <option key={prod.id} value={prod.slug}>
                        {prod.name} ({prod.category?.name || 'Grocery'})
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {linkType === 'custom' && (
                <div className="space-y-1">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Custom Click URL</label>
                  <input
                    type="text"
                    placeholder="e.g. /category/fruits-vegetables or /product/maggi"
                    value={customLinkUrl}
                    onChange={(e) => setCustomLinkUrl(e.target.value)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              )}

              {/* Sorting Weight */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Ordering Weight (sortOrder)</label>
                <input
                  type="number"
                  value={sortOrder}
                  onChange={(e) => setSortOrder(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                />
              </div>
              {/* Custom Banner Image */}
              <div className="md:col-span-2 space-y-2 border-t border-border/40 pt-4">
                <div className="flex justify-between items-center">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary block">
                    Custom Banner Graphic (Optional)
                  </label>
                  {imageUrl && (
                    <button
                      type="button"
                      onClick={() => setImageUrl('')}
                      className="text-[10px] text-danger hover:underline font-bold"
                    >
                      Clear Image
                    </button>
                  )}
                </div>
                
                <div className="bg-accent/5 border border-accent/15 p-3 rounded-xl">
                  <p className="text-[11px] text-accent font-bold leading-normal">
                    🎨 **Design your banner:** You can design a banner graphic (the optimal size for the storefront slider is **1200 x 400 pixels** or a **3:1 aspect ratio**). Please upload a file matching these dimensions.
                  </p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
                  {/* File Upload option */}
                  <div className="flex items-center justify-center w-full">
                    <label
                      htmlFor="banner-image-file"
                      className="flex flex-col items-center justify-center w-full h-24 border-2 border-dashed border-border hover:border-accent rounded-xl cursor-pointer bg-muted/10 hover:bg-accent/5 transition-all"
                    >
                      <div className="flex flex-col items-center justify-center py-4">
                        {isUploading ? (
                          <>
                            <Loader2 className="w-6 h-6 text-accent animate-spin mb-1" />
                            <p className="text-[11px] text-text-secondary font-bold">Uploading...</p>
                          </>
                        ) : (
                          <>
                            <ImageIcon className="w-6 h-6 text-text-muted mb-1" />
                            <p className="text-[11px] text-text-secondary font-semibold">
                              Click to upload image file
                            </p>
                          </>
                        )}
                      </div>
                    </label>
                    <input
                      id="banner-image-file"
                      type="file"
                      accept="image/*"
                      disabled={isUploading}
                      onChange={handleImageUpload}
                      className="sr-only"
                    />
                  </div>

                  {/* Paste URL option */}
                  <div className="space-y-1">
                    <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Or Paste Image URL</label>
                    <input
                      type="url"
                      placeholder="https://res.cloudinary.com/.../image.jpg"
                      value={imageUrl}
                      onChange={(e) => setImageUrl(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                  </div>
                </div>

                {imageUrl && (
                  <div className="relative aspect-[3/1] w-full overflow-hidden rounded-xl border border-border bg-muted/20 mt-2">
                    <img
                      src={imageUrl}
                      alt="Uploaded Banner Preview"
                      className="object-cover w-full h-full"
                    />
                  </div>
                )}
              </div>

              {/* Active Toggle Option */}
              <div className="flex items-center gap-3 pt-5">
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <span>Publish immediately (Active)</span>
                </label>
              </div>

            </div>

            {/* Action buttons */}
            <div className="pt-4 border-t border-border/40 flex justify-end gap-2">
              {editingId && (
                <button
                  type="button"
                  onClick={resetForm}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
                >
                  Cancel Edit
                </button>
              )}
              <button
                type="submit"
                disabled={submitting}
                className="h-10 px-6 rounded-xl bg-accent hover:bg-accent-dark text-white font-black text-xs transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60 cursor-pointer shadow active:scale-98"
              >
                {submitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Saving Banner to DB...
                  </>
                ) : (
                  <>
                    <Plus className="h-4 w-4" />
                    {editingId ? 'Save Changes' : 'Create Homepage Banner'}
                  </>
                )}
              </button>
            </div>
          </form>
        </div>

      </div>

      {/* Live Preview and Active Banners Sidebar */}
      <div className="space-y-6">
        
        {/* Dynamic Visual Live Preview Card */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex items-center gap-1.5">
            <Eye className="h-5 w-5 text-accent" />
            <h3 className="text-sm font-bold text-text-primary">Live Storefront Preview</h3>
          </div>
          
          <div className="relative w-full overflow-hidden rounded-xl h-[120px] shadow-sm select-none">
            {imageUrl ? (
              <img
                src={imageUrl}
                alt={title || "Custom Graphic Banner"}
                className="w-full h-full object-cover"
              />
            ) : type === 'express-delivery' ? (
              <div className="absolute inset-0 flex items-center justify-between p-4 bg-[#fdf0f1] text-[#2d2d2d]">
                <div className="text-left space-y-0.5">
                  <span className="text-[8px] font-black text-[#e20a22] uppercase tracking-wider block">Fast Delivery in</span>
                  <h4 className="text-sm font-black text-[#e20a22] tracking-tight leading-tight">{title || 'Ghatampur'}</h4>
                  <p className="text-[9px] text-[#4d4d4d] font-bold line-clamp-1">{description || 'Milk, Fruits, Vegetables, Snacks & more'}</p>
                </div>
                <div className="text-2xl pr-2">🛍️</div>
              </div>
            ) : (
              <div className={`absolute inset-0 flex flex-col justify-center p-4 text-white bg-gradient-to-br ${gradient}`}>
                <div className="space-y-1">
                  {code.trim() && (
                    <span className="inline-flex items-center gap-1 bg-white/15 border border-white/20 px-2 py-0.5 rounded-full text-[9px] font-extrabold tracking-wide max-w-max">
                      <Gift className="h-2.5 w-2.5" />
                      Use Code: {code}
                    </span>
                  )}
                  <h4 className="text-sm font-black tracking-tight leading-tight line-clamp-1">
                    {title || 'Festive Sale Banner'}
                  </h4>
                  <p className="text-[10px] text-white/80 font-medium line-clamp-2 leading-relaxed">
                    {description || 'Offer details will appear here as you type...'}
                  </p>
                </div>
                <div className="absolute right-3 bottom-3 text-2xl opacity-40">
                  {type === 'festival' && '🪔'}
                  {type === 'first-order' && '🥛'}
                  {type === 'fresh' && '🥬'}
                  {type === 'snacks' && '🥤'}
                  {type === 'custom' && '📦'}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Database Active Banners List */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col">
          <div className="border-b border-border/60 pb-3 mb-4">
            <h4 className="text-sm font-bold text-text-primary">Currently Registered Banners</h4>
            <p className="text-[10px] text-text-muted">Admins can toggle active state or delete.</p>
          </div>

          {loading ? (
            <div className="py-12 flex items-center justify-center">
              <Loader2 className="h-6 w-6 animate-spin text-accent" />
            </div>
          ) : banners.length === 0 ? (
            <div className="py-12 text-center text-xs text-text-secondary">
              No banners registered in database yet.
            </div>
          ) : (
            <div className="space-y-3 max-h-[400px] overflow-y-auto pr-1">
              <AnimatePresence initial={false}>
                {banners.map((b) => (
                  <motion.div
                    key={b.id}
                    layout
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    className={`p-3 border rounded-xl flex items-center justify-between gap-3 ${
                      b.isActive ? 'bg-card border-border' : 'bg-muted/10 border-border-light opacity-60'
                    }`}
                  >
                    <div className="min-w-0 flex-1 space-y-1">
                      <div className="flex items-center gap-1.5">
                        <span className={`inline-block h-2 w-2 rounded-full ${b.isActive ? 'bg-accent' : 'bg-text-muted'}`} />
                        <strong className="text-xs text-text-primary block font-black truncate">{b.title}</strong>
                      </div>
                      <div className="flex flex-wrap items-center gap-1.5 pt-0.5">
                        {b.code && (
                          <span className="text-[9px] font-bold text-text-secondary bg-muted/40 border px-1.5 py-0.5 rounded font-mono">
                            Code: {b.code}
                          </span>
                        )}
                        {b.linkUrl && (
                          <span className="text-[9px] font-bold text-accent bg-accent/5 border border-accent/10 px-1.5 py-0.5 rounded font-mono">
                            Link: {b.linkUrl}
                          </span>
                        )}
                      </div>
                      <span className="text-[10px] text-text-muted block truncate">{b.description}</span>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      {/* Priority change buttons */}
                      <div className="flex flex-col gap-0.5">
                        <button
                          onClick={() => handleOrderChange(b, 'up')}
                          className="p-0.5 hover:bg-muted text-text-secondary rounded"
                          title="Move Up"
                        >
                          <ArrowUp className="h-3 w-3" />
                        </button>
                        <button
                          onClick={() => handleOrderChange(b, 'down')}
                          className="p-0.5 hover:bg-muted text-text-secondary rounded"
                          title="Move Down"
                        >
                          <ArrowDown className="h-3 w-3" />
                        </button>
                      </div>

                      {/* Active toggle */}
                      <button
                        onClick={() => handleToggleActive(b)}
                        className={`p-1.5 rounded-lg border transition-colors cursor-pointer ${
                          b.isActive 
                            ? 'bg-accent/10 border-accent/20 text-accent hover:bg-accent/20' 
                            : 'bg-muted/40 border-border text-text-secondary hover:bg-muted'
                        }`}
                        title={b.isActive ? 'Deactivate Banner' : 'Activate Banner'}
                      >
                        <Power className="h-3.5 w-3.5" />
                      </button>

                      {/* Edit */}
                      <button
                        onClick={() => handleEditClick(b)}
                        className="p-1.5 border border-border hover:bg-muted text-text-secondary hover:text-text-primary rounded-lg transition-colors cursor-pointer"
                        title="Edit Banner"
                      >
                        <Edit2 className="h-3.5 w-3.5" />
                      </button>

                      {/* Delete */}
                      <button
                        onClick={() => handleDelete(b.id)}
                        className="p-1.5 border border-danger/20 bg-danger/5 hover:bg-danger/10 text-danger rounded-lg transition-colors cursor-pointer"
                        title="Delete Banner"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          )}
        </div>

      </div>
    </motion.div>
  )
}
