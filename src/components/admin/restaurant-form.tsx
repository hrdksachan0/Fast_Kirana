'use client'

import { useState, useRef, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { 
  Save, Loader2, Image as ImageIcon, Store, MapPin, Clock, Tag, 
  Star, X, Plus, Phone, Mail, ExternalLink, Upload, Utensils,
  TrendingUp, Percent, ArrowLeft, Eye, EyeOff, Leaf,
  UserCheck, UserPlus, ShieldCheck, User, Activity, Check
} from 'lucide-react'

interface RestaurantFormProps {
  restaurant?: any
  isAdmin?: boolean
  onSaved?: (updatedRestaurant: any) => void
}

export function RestaurantForm({ restaurant, isAdmin = true, onSaved }: RestaurantFormProps) {
  const router = useRouter()
  const isEditing = !!restaurant
  const [isSubmitting, setIsSubmitting] = useState(false)
  
  // Assignable users for outlet head selection
  const [assignableUsers, setAssignableUsers] = useState<any[]>([])
  const [loadingUsers, setLoadingUsers] = useState(false)
  const [ownerUserId, setOwnerUserId] = useState<string>(() => {
    if (restaurant?.staff && restaurant.staff.length > 0) {
      const owner = restaurant.staff.find((s: any) => s.role === 'RESTAURANT_OWNER') || restaurant.staff[0]
      return owner?.id || ''
    }
    return ''
  })

  const [formData, setFormData] = useState({
    name: restaurant?.name || '',
    slug: restaurant?.slug || '',
    description: restaurant?.description || '',
    logoUrl: restaurant?.logoUrl || '',
    bannerUrl: restaurant?.bannerUrl || '',
    address: restaurant?.address || '',
    city: restaurant?.city || '',
    cuisineTags: restaurant?.cuisineTags || [] as string[],
    deliveryTime: restaurant?.deliveryTime || '',
    distance: restaurant?.distance || '',
    rating: restaurant?.rating ?? 4.0,
    isVeg: restaurant?.isVeg ?? false,
    isPureVeg: restaurant?.isPureVeg ?? false,
    isOpen: restaurant?.isOpen ?? true,
    openTime: restaurant?.openTime || '',
    closeTime: restaurant?.closeTime || '',
    commissionRate: restaurant?.commissionRate?.toString() || '0.15',
    discountOffer: restaurant?.discountOffer || '',
    discountBadge: restaurant?.discountBadge || '',
    ownerPhone: restaurant?.ownerPhone || '',
    ownerEmail: restaurant?.ownerEmail || '',
    sortOrder: restaurant?.sortOrder?.toString() || '0',
    isActive: restaurant?.isActive ?? true,
    lat: restaurant?.lat?.toString() || '',
    lng: restaurant?.lng?.toString() || '',
  })

  // Fetch assignable users if isAdmin
  useEffect(() => {
    if (isAdmin) {
      setLoadingUsers(true)
      fetch('/api/admin/users/assignable')
        .then(res => res.json())
        .then(data => {
          if (Array.isArray(data)) {
            setAssignableUsers(data)
          }
        })
        .catch(console.error)
        .finally(() => setLoadingUsers(false))
    }
  }, [isAdmin])

  // Cuisine tag input
  const [tagInput, setTagInput] = useState('')
  const tagInputRef = useRef<HTMLInputElement>(null)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target as HTMLInputElement

    if (type === 'checkbox') {
      const checked = (e.target as HTMLInputElement).checked
      setFormData(prev => ({ ...prev, [name]: checked }))
    } else {
      setFormData(prev => ({ ...prev, [name]: value }))

      // Auto-generate slug from name if creating new
      if (name === 'name' && !isEditing) {
        setFormData(prev => ({
          ...prev,
          slug: value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '')
        }))
      }
    }
  }

  const handleAddTag = () => {
    const tag = tagInput.trim()
    if (tag && !formData.cuisineTags.includes(tag)) {
      setFormData(prev => ({ ...prev, cuisineTags: [...prev.cuisineTags, tag] }))
      setTagInput('')
      tagInputRef.current?.focus()
    }
  }

  const handleRemoveTag = (tagToRemove: string) => {
    setFormData(prev => ({
      ...prev,
      cuisineTags: prev.cuisineTags.filter((t: string) => t !== tagToRemove)
    }))
  }

  const handleTagKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault()
      handleAddTag()
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)

    try {
      const payload = {
        ...formData,
        ownerUserId: ownerUserId || undefined,
        commissionRate: parseFloat(formData.commissionRate) || 0,
        sortOrder: parseInt(formData.sortOrder) || 0,
        rating: parseFloat(String(formData.rating)) || 4.0,
        lat: formData.lat ? parseFloat(formData.lat) : null,
        lng: formData.lng ? parseFloat(formData.lng) : null,
      }

      const url = isEditing ? `/api/restaurants/${restaurant.id}` : '/api/restaurants'
      const method = isEditing ? 'PATCH' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || errorData.message || 'Failed to save restaurant')
      }

      const savedData = await res.json()

      toast.success(isEditing ? 'Outlet profile updated successfully! 🎉' : 'New Outlet created and Head assigned successfully! 🎉')
      if (onSaved) {
        onSaved(savedData)
      } else {
        router.refresh()
        if (isAdmin) {
          router.push('/admin/restaurants')
        }
      }
    } catch (error: any) {
      toast.error(error.message || 'An error occurred')
      console.error(error)
    } finally {
      setIsSubmitting(false)
    }
  }

  // Section card component
  const SectionCard = ({ 
    icon: Icon, title, subtitle, accentColor, children 
  }: { 
    icon: any; title: string; subtitle: string; accentColor: string; children: React.ReactNode 
  }) => (
    <div className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
      <div className={`p-4 border-b border-border/60 bg-gradient-to-r ${accentColor} flex items-center gap-3`}>
        <div className="h-9 w-9 rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm flex items-center justify-center shadow-sm">
          <Icon className="h-4.5 w-4.5 text-text-primary" />
        </div>
        <div>
          <h2 className="font-black text-sm text-text-primary tracking-wide">{title}</h2>
          <p className="text-[10px] text-text-secondary font-medium">{subtitle}</p>
        </div>
      </div>
      <div className="p-6">
        {children}
      </div>
    </div>
  )

  const InputField = ({ label, id, required, children }: { label: string; id: string; required?: boolean; children: React.ReactNode }) => (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
        {label} {required && <span className="text-rose-500">*</span>}
      </label>
      {children}
    </div>
  )

  const inputClass = "w-full px-3.5 py-2.5 text-sm font-semibold bg-background border border-border rounded-xl outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all placeholder:text-text-secondary/40"
  
  const mapUrl = formData.lat && formData.lng 
    ? `https://maps.google.com/maps?q=${formData.lat},${formData.lng}&z=15&output=embed`
    : null

  const currentOwner = assignableUsers.find(u => u.id === ownerUserId) || (restaurant?.staff ? restaurant.staff.find((s: any) => s.id === ownerUserId) : null)

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-24">
      
      {/* Back button & page title */}
      {isAdmin && (
        <div className="flex items-center justify-between">
          <button
            type="button"
            onClick={() => router.push('/admin/restaurants')}
            className="flex items-center gap-2 text-xs font-bold text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Restaurants
          </button>
          <div className="flex items-center gap-2">
            {formData.isActive ? (
              <span className="flex items-center gap-1.5 px-3 py-1 bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 rounded-full text-[10px] font-black">
                <Eye className="h-3 w-3" /> Active
              </span>
            ) : (
              <span className="flex items-center gap-1.5 px-3 py-1 bg-rose-500/10 text-rose-600 border border-rose-500/20 rounded-full text-[10px] font-black">
                <EyeOff className="h-3 w-3" /> Inactive
              </span>
            )}
          </div>
        </div>
      )}

      {/* ======================================================== */}
      {/* 👑 OUTLET HEAD / OWNER ASSIGNMENT (Admin Mode Only)     */}
      {/* ======================================================== */}
      {isAdmin && (
        <SectionCard
          icon={UserCheck}
          title="Outlet Head / Console Owner"
          subtitle="Assign a registered customer account as the primary Head/Manager of this kitchen console"
          accentColor="from-amber-500/10 via-amber-500/5 to-amber-500/0"
        >
          <div className="space-y-4">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-4 bg-amber-500/5 border border-amber-500/20 rounded-2xl">
              <div className="flex items-center gap-3">
                <div className="h-11 w-11 rounded-2xl bg-amber-500/15 text-amber-600 dark:text-amber-400 flex items-center justify-center font-black shrink-0">
                  {currentOwner ? (
                    currentOwner.name ? currentOwner.name.charAt(0).toUpperCase() : 'U'
                  ) : (
                    <UserPlus className="h-5 w-5" />
                  )}
                </div>
                <div>
                  <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">
                    {currentOwner ? currentOwner.name : 'No Head Assigned Yet'}
                  </h4>
                  <p className="text-[11px] text-text-secondary">
                    {currentOwner ? (
                      <>
                        <span className="font-mono text-amber-600 dark:text-amber-400 font-bold">{currentOwner.email}</span>
                        {currentOwner.phone && ` · ${currentOwner.phone}`}
                      </>
                    ) : (
                      'Select a customer/user account to make them the Head of this Outlet'
                    )}
                  </p>
                </div>
              </div>

              {currentOwner && (
                <span className="inline-flex items-center gap-1 px-3 py-1 bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 rounded-full text-[10px] font-black shrink-0">
                  <ShieldCheck className="h-3 w-3" /> Console Access Active
                </span>
              )}
            </div>

            <div className="space-y-1.5">
              <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Select Account to Assign as Outlet Head
              </label>
              <div className="relative">
                <select
                  value={ownerUserId}
                  onChange={(e) => {
                    setOwnerUserId(e.target.value)
                    const u = assignableUsers.find(user => user.id === e.target.value)
                    if (u) {
                      if (u.phone && !formData.ownerPhone) {
                        setFormData(prev => ({ ...prev, ownerPhone: u.phone }))
                      }
                      if (u.email && !formData.ownerEmail) {
                        setFormData(prev => ({ ...prev, ownerEmail: u.email }))
                      }
                    }
                  }}
                  className={inputClass}
                  disabled={loadingUsers}
                >
                  <option value="">-- Select Customer / Partner User Account --</option>
                  {assignableUsers.map((u: any) => (
                    <option key={u.id} value={u.id}>
                      {u.name} ({u.email || u.phone || 'No Contact'}) — Role: {u.role} {u.assignedRestaurantId ? ' (Assigned)' : ''}
                    </option>
                  ))}
                </select>
                {loadingUsers && (
                  <div className="absolute right-3 top-1/2 -translate-y-1/2">
                    <Loader2 className="h-4 w-4 animate-spin text-primary" />
                  </div>
                )}
              </div>
              <p className="text-[10px] text-text-secondary">
                Assigning an account gives this user full login access to the kitchen console (`/restaurant-kitchen` or `/cafe-kitchen`).
              </p>
            </div>

            {/* Direct Password Management for Outlet Head */}
            {currentOwner && (
              <div className="pt-3 border-t border-amber-500/20 space-y-2">
                <label className="text-[11px] font-bold uppercase tracking-wider text-amber-700 dark:text-amber-400 flex items-center gap-1.5">
                  🔑 Outlet Head Password (No OTP Required for Login)
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    placeholder="Set new password for this Head..."
                    value={tagInputRef.current?.dataset.headPassword || ''}
                    id="headPasswordInput"
                    className="flex-1 px-3.5 py-2 text-xs font-mono font-semibold bg-background border border-amber-500/30 rounded-xl outline-none focus:border-amber-500"
                  />
                  <button
                    type="button"
                    onClick={async () => {
                      const inputEl = document.getElementById('headPasswordInput') as HTMLInputElement
                      const newPass = inputEl?.value
                      if (!newPass || newPass.length < 6) {
                        toast.error('Password must be at least 6 characters')
                        return
                      }
                      try {
                        const res = await fetch('/api/admin/users', {
                          method: 'POST',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify({ userId: currentOwner.id, password: newPass })
                        })
                        if (!res.ok) throw new Error('Failed to update password')
                        toast.success(`Password set for ${currentOwner.name || 'Head'}! They can now login with Email/Phone & Password without OTP. 🎉`)
                        if (inputEl) inputEl.value = ''
                      } catch (err: any) {
                        toast.error(err.message || 'Error setting password')
                      }
                    }}
                    className="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-xs font-black transition-all cursor-pointer shrink-0 shadow-sm"
                  >
                    Save Password
                  </button>
                </div>
                <p className="text-[10px] text-amber-600/80 dark:text-amber-400/80">
                  ⚡ Once password is set, the Outlet Head can log in directly using their Email or Phone number + Password without needing OTP every time!
                </p>
              </div>
            )}
          </div>
        </SectionCard>
      )}

      {/* ======================================================== */}
      {/* 🔴/🟢 STORE STATUS (OPEN / CLOSED TOGGLE)              */}
      {/* ======================================================== */}
      <SectionCard
        icon={Activity}
        title="Store Live Status"
        subtitle="Turn your store ON/OFF manually to accept or pause new customer orders"
        accentColor={formData.isOpen ? "from-emerald-500/10 via-emerald-500/5 to-emerald-500/0" : "from-rose-500/10 via-rose-500/5 to-rose-500/0"}
      >
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-2xl border transition-all">
          <div className="flex items-center gap-3.5">
            <div className={`h-12 w-12 rounded-2xl flex items-center justify-center font-black text-xl shrink-0 ${
              formData.isOpen 
                ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400' 
                : 'bg-rose-500/15 text-rose-600 dark:text-rose-400'
            }`}>
              {formData.isOpen ? '🟢' : '🌙'}
            </div>
            <div>
              <h4 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-2">
                {formData.isOpen ? 'Store is OPEN & Accepting Orders' : 'Store is CLOSED / Paused'}
              </h4>
              <p className="text-[11px] text-text-secondary mt-0.5">
                {formData.isOpen 
                  ? 'Customers can browse menu items and place new orders on the app.' 
                  : 'Customers will see your store as "Closed" and cannot place orders right now.'
                }
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={() => setFormData(prev => ({ ...prev, isOpen: !prev.isOpen }))}
            className={`px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider transition-all shadow-sm cursor-pointer flex items-center gap-2 shrink-0 ${
              formData.isOpen
                ? 'bg-rose-600 hover:bg-rose-700 text-white shadow-rose-500/20'
                : 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-emerald-500/20'
            }`}
          >
            {formData.isOpen ? (
              <>
                <X className="h-4 w-4" /> Pause / Close Store
              </>
            ) : (
              <>
                <Check className="h-4 w-4" /> Open Store Now
              </>
            )}
          </button>
        </div>
      </SectionCard>

      {/* ============================== */}
      {/* 1. BASIC INFORMATION — Emerald */}
      {/* ============================== */}
      <SectionCard
        icon={Store}
        title="Basic Information"
        subtitle="Restaurant identity and core details"
        accentColor="from-emerald-500/5 to-emerald-500/0"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <InputField label="Restaurant Name" id="name" required>
            <input
              id="name"
              name="name"
              value={formData.name}
              onChange={handleChange}
              required
              placeholder="e.g. Wedson Restaurant"
              className={inputClass}
            />
          </InputField>

          <InputField label="URL Slug" id="slug" required>
            <input
              id="slug"
              name="slug"
              value={formData.slug}
              onChange={handleChange}
              required
              placeholder="wedson-restaurant"
              className={`${inputClass} font-mono text-xs`}
            />
          </InputField>

          <div className="md:col-span-2 space-y-1.5">
            <label htmlFor="description" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Description
            </label>
            <textarea
              id="description"
              name="description"
              value={formData.description}
              onChange={handleChange}
              rows={3}
              className={`${inputClass} min-h-[80px] resize-none`}
              placeholder="A premium dining experience with authentic North Indian flavors..."
            />
          </div>

          {/* Cuisine Tags — Interactive Chips */}
          <div className="md:col-span-2 space-y-2">
            <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Cuisine Tags
            </label>
            <div className="flex flex-wrap gap-2 p-3 bg-background border border-border rounded-xl min-h-[44px]">
              {formData.cuisineTags.map((tag: string) => (
                <span
                  key={tag}
                  className="inline-flex items-center gap-1 px-2.5 py-1 bg-primary/10 text-primary border border-primary/20 rounded-lg text-xs font-bold animate-fade-in"
                >
                  {tag}
                  <button
                    type="button"
                    onClick={() => handleRemoveTag(tag)}
                    className="hover:text-rose-500 transition-colors cursor-pointer"
                  >
                    <X className="h-3 w-3" />
                  </button>
                </span>
              ))}
              <input
                ref={tagInputRef}
                type="text"
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyDown={handleTagKeyDown}
                placeholder={formData.cuisineTags.length === 0 ? "Type tag and press Enter..." : "Add more..."}
                className="flex-1 min-w-[120px] bg-transparent text-sm font-semibold outline-none placeholder:text-text-secondary/40"
              />
              {tagInput.trim() && (
                <button
                  type="button"
                  onClick={handleAddTag}
                  className="flex items-center gap-1 px-2 py-1 bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 rounded-lg text-[10px] font-black hover:bg-emerald-500/20 transition-all cursor-pointer"
                >
                  <Plus className="h-3 w-3" /> Add
                </button>
              )}
            </div>
          </div>

          {/* Rating Slider */}
          <div className="space-y-3">
            <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Rating
            </label>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1">
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    type="button"
                    onClick={() => setFormData(prev => ({ ...prev, rating: star }))}
                    className="cursor-pointer transition-transform hover:scale-110"
                  >
                    <Star
                      className={`h-6 w-6 transition-colors ${
                        star <= Math.round(formData.rating)
                          ? 'fill-amber-400 text-amber-400'
                          : 'fill-muted text-muted-foreground/30'
                      }`}
                    />
                  </button>
                ))}
              </div>
              <input
                type="number"
                name="rating"
                min="1"
                max="5"
                step="0.1"
                value={formData.rating}
                onChange={handleChange}
                className="w-20 px-3 py-2 text-sm font-black bg-background border border-border rounded-xl outline-none focus:border-amber-500 text-center"
              />
              <span className="text-xs font-bold text-amber-600 bg-amber-500/10 px-2 py-1 rounded-lg border border-amber-500/20">
                {formData.rating} ★
              </span>
            </div>
          </div>

          {/* Toggles */}
          <div className="space-y-3">
            <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Dietary & Visibility
            </label>
            <div className="flex flex-wrap gap-3">
              <label className="flex items-center gap-2 px-3 py-2 bg-background border border-border rounded-xl cursor-pointer hover:bg-muted/30 transition-all select-none">
                <input
                  type="checkbox"
                  name="isActive"
                  checked={formData.isActive}
                  onChange={handleChange}
                  className="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary accent-primary"
                />
                <Eye className="h-3.5 w-3.5 text-emerald-600" />
                <span className="text-xs font-bold">Active</span>
              </label>
              <label className="flex items-center gap-2 px-3 py-2 bg-background border border-border rounded-xl cursor-pointer hover:bg-muted/30 transition-all select-none">
                <input
                  type="checkbox"
                  name="isPureVeg"
                  checked={formData.isPureVeg}
                  onChange={handleChange}
                  className="w-4 h-4 rounded border-gray-300 text-green-600 focus:ring-green-600 accent-green-600"
                />
                <Leaf className="h-3.5 w-3.5 text-green-600" />
                <span className="text-xs font-bold">Pure Veg</span>
              </label>
              <label className="flex items-center gap-2 px-3 py-2 bg-background border border-border rounded-xl cursor-pointer hover:bg-muted/30 transition-all select-none">
                <input
                  type="checkbox"
                  name="isOpen"
                  checked={formData.isOpen}
                  onChange={handleChange}
                  className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-600 accent-blue-600"
                />
                <Clock className="h-3.5 w-3.5 text-blue-600" />
                <span className="text-xs font-bold">Open Now</span>
              </label>
            </div>
          </div>
        </div>
      </SectionCard>

      {/* ============================== */}
      {/* 2. IMAGES — Violet            */}
      {/* ============================== */}
      <SectionCard
        icon={ImageIcon}
        title="Images & Branding"
        subtitle="Logo, banner and visual identity"
        accentColor="from-violet-500/5 to-violet-500/0"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Logo */}
          <div className="space-y-3">
            <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Restaurant Logo
            </label>
            <div className="flex items-start gap-4">
              <div className="h-24 w-24 rounded-2xl border-2 border-dashed border-border bg-muted/20 flex items-center justify-center overflow-hidden shrink-0 relative group">
                {formData.logoUrl ? (
                  <>
                    <img
                      src={formData.logoUrl}
                      alt="Logo preview"
                      className="w-full h-full object-cover"
                      onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
                    />
                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                      <Upload className="h-5 w-5 text-white" />
                    </div>
                  </>
                ) : (
                  <div className="text-center">
                    <Upload className="h-6 w-6 text-text-secondary/40 mx-auto" />
                    <span className="text-[8px] text-text-secondary/40 font-bold block mt-1">LOGO</span>
                  </div>
                )}
              </div>
              <div className="flex-1 space-y-2">
                <input
                  id="logoUrl"
                  name="logoUrl"
                  value={formData.logoUrl}
                  onChange={handleChange}
                  placeholder="Paste logo image URL..."
                  className={inputClass}
                />
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="text-[9px] text-text-secondary font-bold">Quick Presets:</span>
                  <button
                    type="button"
                    onClick={() => setFormData(prev => ({ ...prev, logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80' }))}
                    className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                  >
                    Dining Logo
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormData(prev => ({ ...prev, logoUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80' }))}
                    className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                  >
                    Cafe Logo
                  </button>
                  {formData.logoUrl && (
                    <button
                      type="button"
                      onClick={() => setFormData(prev => ({ ...prev, logoUrl: '' }))}
                      className="px-2 py-0.5 text-[9px] font-bold bg-rose-500/10 text-rose-600 hover:bg-rose-500/20 rounded border border-rose-500/20 cursor-pointer ml-auto"
                    >
                      Clear
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Banner */}
          <div className="space-y-3">
            <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Cover Banner
            </label>
            <div className="space-y-3">
              <div className="h-32 w-full rounded-2xl border-2 border-dashed border-border bg-muted/20 flex items-center justify-center overflow-hidden relative group">
                {formData.bannerUrl ? (
                  <>
                    <img
                      src={formData.bannerUrl}
                      alt="Banner preview"
                      className="w-full h-full object-cover"
                      onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
                    />
                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                      <Upload className="h-6 w-6 text-white" />
                    </div>
                  </>
                ) : (
                  <div className="text-center">
                    <ImageIcon className="h-8 w-8 text-text-secondary/30 mx-auto" />
                    <span className="text-[9px] text-text-secondary/40 font-bold block mt-1">COVER BANNER</span>
                  </div>
                )}
              </div>
              <input
                id="bannerUrl"
                name="bannerUrl"
                value={formData.bannerUrl}
                onChange={handleChange}
                placeholder="Paste banner image URL..."
                className={inputClass}
              />
              <div className="flex flex-wrap items-center gap-1.5">
                <span className="text-[9px] text-text-secondary font-bold">Quick Presets:</span>
                <button
                  type="button"
                  onClick={() => setFormData(prev => ({ ...prev, bannerUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80' }))}
                  className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                >
                  Food Feast Banner
                </button>
                <button
                  type="button"
                  onClick={() => setFormData(prev => ({ ...prev, bannerUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80' }))}
                  className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                >
                  Coffee & Bakery
                </button>
                {formData.bannerUrl && (
                  <button
                    type="button"
                    onClick={() => setFormData(prev => ({ ...prev, bannerUrl: '' }))}
                    className="px-2 py-0.5 text-[9px] font-bold bg-rose-500/10 text-rose-600 hover:bg-rose-500/20 rounded border border-rose-500/20 cursor-pointer ml-auto"
                  >
                    Clear
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      </SectionCard>

      {/* ============================== */}
      {/* 3. LOCATION & MAP — Blue       */}
      {/* ============================== */}
      <SectionCard
        icon={MapPin}
        title="Location & Contact"
        subtitle="Address, map coordinates and owner details"
        accentColor="from-blue-500/5 to-blue-500/0"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div className="md:col-span-2">
            <InputField label="Full Address" id="address">
              <input
                id="address"
                name="address"
                value={formData.address}
                onChange={handleChange}
                placeholder="e.g. 123 Main St, Near Market, Lucknow"
                className={inputClass}
              />
            </InputField>
          </div>

          <InputField label="City" id="city">
            <input
              id="city"
              name="city"
              value={formData.city}
              onChange={handleChange}
              placeholder="e.g. Lucknow"
              className={inputClass}
            />
          </InputField>

          {/* Lat/Lng */}
          <InputField label="Latitude" id="lat">
            <input
              id="lat"
              name="lat"
              type="number"
              step="any"
              value={formData.lat}
              onChange={handleChange}
              placeholder="e.g. 26.8467"
              className={inputClass}
            />
          </InputField>

          <InputField label="Longitude" id="lng">
            <input
              id="lng"
              name="lng"
              type="number"
              step="any"
              value={formData.lng}
              onChange={handleChange}
              placeholder="e.g. 80.9462"
              className={inputClass}
            />
          </InputField>

          {/* Map Preview */}
          <div className="md:col-span-2 space-y-2">
            <div className="flex items-center justify-between">
              <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                📍 Map Preview
              </label>
              {formData.lat && formData.lng && (
                <a
                  href={`https://www.google.com/maps?q=${formData.lat},${formData.lng}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-1 text-[10px] font-bold text-blue-600 hover:text-blue-700 transition-colors"
                >
                  <ExternalLink className="h-3 w-3" />
                  Open in Google Maps
                </a>
              )}
            </div>
            <div className="h-56 w-full rounded-2xl border border-border overflow-hidden bg-muted/20 relative">
              {mapUrl ? (
                <iframe
                  src={mapUrl}
                  width="100%"
                  height="100%"
                  style={{ border: 0 }}
                  allowFullScreen
                  loading="lazy"
                  referrerPolicy="no-referrer-when-downgrade"
                  className="rounded-2xl"
                />
              ) : (
                <div className="absolute inset-0 flex flex-col items-center justify-center text-text-secondary/40">
                  <MapPin className="h-10 w-10 mb-2" />
                  <p className="text-xs font-bold">Enter latitude & longitude to see map preview</p>
                  <p className="text-[10px]">Tip: Get coordinates from Google Maps</p>
                </div>
              )}
            </div>
          </div>

          {/* Divider */}
          <div className="md:col-span-2 border-t border-border/40 pt-5">
            <p className="text-[11px] font-bold uppercase tracking-wider text-text-secondary mb-4">Owner Contact</p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <InputField label="Owner Phone" id="ownerPhone">
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
                  <input
                    id="ownerPhone"
                    name="ownerPhone"
                    value={formData.ownerPhone}
                    onChange={handleChange}
                    placeholder="+91 98765 43210"
                    className={`${inputClass} pl-10`}
                  />
                </div>
              </InputField>

              <InputField label="Owner Email" id="ownerEmail">
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
                  <input
                    id="ownerEmail"
                    name="ownerEmail"
                    type="email"
                    value={formData.ownerEmail}
                    onChange={handleChange}
                    placeholder="owner@restaurant.com"
                    className={`${inputClass} pl-10`}
                  />
                </div>
              </InputField>
            </div>
          </div>
        </div>
      </SectionCard>

      {/* ============================== */}
      {/* 4. OPERATIONS & TIMING — Amber */}
      {/* ============================== */}
      <SectionCard
        icon={Clock}
        title="Operations & Timings"
        subtitle="Delivery schedule and operating hours"
        accentColor="from-amber-500/5 to-amber-500/0"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">

          <InputField label="Opens At" id="openTime">
            <input
              id="openTime"
              name="openTime"
              type="time"
              value={formData.openTime}
              onChange={handleChange}
              className={inputClass}
            />
          </InputField>

          <InputField label="Closes At" id="closeTime">
            <input
              id="closeTime"
              name="closeTime"
              type="time"
              value={formData.closeTime}
              onChange={handleChange}
              className={inputClass}
            />
          </InputField>
        </div>

        {/* Visual Operating Hours Bar */}
        {formData.openTime && formData.closeTime && (
          <div className="mt-5 pt-5 border-t border-border/40">
            <p className="text-[10px] font-bold text-text-secondary uppercase tracking-wider mb-3">Operating Hours Visual</p>
            <div className="relative h-8 bg-muted/30 rounded-full border border-border overflow-hidden">
              {(() => {
                const openParts = formData.openTime.split(':')
                const closeParts = formData.closeTime.split(':')
                const openHour = parseInt(openParts[0]) + parseInt(openParts[1]) / 60
                const closeHour = parseInt(closeParts[0]) + parseInt(closeParts[1]) / 60
                const left = (openHour / 24) * 100
                const width = ((closeHour > openHour ? closeHour - openHour : 24 - openHour + closeHour) / 24) * 100
                return (
                  <div
                    className="absolute h-full bg-gradient-to-r from-emerald-500/30 to-emerald-400/20 border-l-2 border-r-2 border-emerald-500 flex items-center justify-center"
                    style={{ left: `${left}%`, width: `${width}%` }}
                  >
                    <span className="text-[9px] font-black text-emerald-700 dark:text-emerald-400 whitespace-nowrap">
                      {formData.openTime} — {formData.closeTime}
                    </span>
                  </div>
                )
              })()}
              {/* Hour markers */}
              <div className="absolute bottom-0 left-0 w-full flex justify-between px-1">
                {[0, 6, 12, 18, 24].map(h => (
                  <span key={h} className="text-[7px] text-text-secondary/40 font-bold">{h === 24 ? '0' : h}h</span>
                ))}
              </div>
            </div>
          </div>
        )}
      </SectionCard>

      {/* ============================== */}
      {/* 5. OFFERS & BUSINESS — Rose    */}
      {/* ============================== */}
      <SectionCard
        icon={TrendingUp}
        title="Business & Offers"
        subtitle="Commission, discount offers and ranking"
        accentColor="from-rose-500/5 to-rose-500/0"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <InputField label="Main Offer Text" id="discountOffer">
            <div className="relative">
              <Tag className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
              <input
                id="discountOffer"
                name="discountOffer"
                value={formData.discountOffer}
                onChange={handleChange}
                placeholder="e.g. 40% OFF UPTO ₹200"
                className={`${inputClass} pl-10`}
              />
            </div>
          </InputField>

          <InputField label="Sub Offer Badge" id="discountBadge">
            <input
              id="discountBadge"
              name="discountBadge"
              value={formData.discountBadge}
              onChange={handleChange}
              placeholder="e.g. Free Delivery"
              className={inputClass}
            />
          </InputField>

          <InputField label="Commission Rate" id="commissionRate">
            <div className="relative">
              <Percent className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary/40" />
              <input
                id="commissionRate"
                name="commissionRate"
                type="number"
                step="0.01"
                min="0"
                max="1"
                value={formData.commissionRate}
                onChange={handleChange}
                placeholder="e.g. 0.15 for 15%"
                className={`${inputClass} pl-10`}
              />
            </div>
            <p className="text-[9px] text-text-secondary mt-1">Enter 0.15 for 15% commission</p>
          </InputField>

          <InputField label="Sort Order (Listing Position)" id="sortOrder">
            <input
              id="sortOrder"
              name="sortOrder"
              type="number"
              value={formData.sortOrder}
              onChange={handleChange}
              placeholder="0"
              className={inputClass}
            />
            <p className="text-[9px] text-text-secondary mt-1">Lower number = higher position in listing</p>
          </InputField>
        </div>
      </SectionCard>

      {/* ============================== */}
      {/* STICKY SAVE BAR               */}
      {/* ============================== */}
      <div className="fixed bottom-0 left-0 right-0 z-50 bg-card/80 backdrop-blur-xl border-t border-border shadow-2xl">
        <div className="mx-auto max-w-5xl flex items-center justify-between px-6 py-3.5">
          <div className="flex items-center gap-3">
            {formData.logoUrl && (
              <img src={formData.logoUrl} alt="" className="h-9 w-9 rounded-xl object-cover border border-border" />
            )}
            <div>
              <p className="text-sm font-black text-text-primary">{formData.name || 'Untitled Restaurant'}</p>
              <p className="text-[10px] text-text-secondary font-medium">
                {formData.cuisineTags.length > 0 ? formData.cuisineTags.slice(0, 3).join(' · ') : 'No cuisine tags'}
                {formData.cuisineTags.length > 3 && ` +${formData.cuisineTags.length - 3} more`}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push('/admin/restaurants')}
              disabled={isSubmitting}
              className="px-5 py-2.5 border border-border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex items-center gap-2 px-6 py-2.5 bg-[#e20a22] hover:bg-[#c9081e] text-white rounded-xl text-xs font-black transition-all shadow-lg hover:shadow-xl disabled:opacity-50 cursor-pointer min-w-[160px] justify-center"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <Save className="h-4 w-4" />
                  {isEditing ? 'Update Restaurant' : 'Create Restaurant'}
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </form>
  )
}
