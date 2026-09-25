'use client'

import { useState, useEffect, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { 
  Save, Loader2, ArrowLeft, Eye, EyeOff,
  UserCheck, UserPlus, ShieldCheck, Activity, Check, Search, X
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { compressImageClient } from '@/lib/image-compression'
import { RestaurantGeneralInfo } from '@/components/admin/restaurant/restaurant-general-info'
import { RestaurantLocationPicker } from '@/components/admin/restaurant/restaurant-location-picker'
import { RestaurantTimingSchedule } from '@/components/admin/restaurant/restaurant-timing-schedule'

interface RestaurantFormProps {
  restaurant?: any
  isAdmin?: boolean
  onSaved?: (updatedRestaurant: any) => void
}

// Helper SectionCard component outside parent to prevent re-creation on render
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

// Helper InputField component outside parent to prevent re-creation on render
const InputField = ({ label, id, required, children }: { label: string; id: string; required?: boolean; children: React.ReactNode }) => (
  <div className="space-y-1.5">
    <label htmlFor={id} className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
      {label} {required && <span className="text-rose-500">*</span>}
    </label>
    {children}
  </div>
)

const inputClass = "w-full px-3.5 py-2.5 text-sm font-semibold bg-background border border-border rounded-xl outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all placeholder:text-text-secondary/40"

export function RestaurantForm({ restaurant, isAdmin = true, onSaved }: RestaurantFormProps) {
  const router = useRouter()
  const { data: session } = useSession()
  const sessionUserId = session?.user?.id || ''
  const sessionUserRole = session?.user?.role || ''
  const sessionUserEmail = session?.user?.email || ''
  const sessionUserPhone = (session?.user as any)?.phone || ''

  const isEditing = !!restaurant
  const [isSubmitting, setIsSubmitting] = useState(false)
  
  // Assignable users for outlet head selection
  const [assignableUsers, setAssignableUsers] = useState<any[]>([])
  const [loadingUsers, setLoadingUsers] = useState(false)
  const [userSearchQuery, setUserSearchQuery] = useState('')
  const [showStaffOnly, setShowStaffOnly] = useState(true)
  const [headPassword, setHeadPassword] = useState('')
  const [showPasswordText, setShowPasswordText] = useState(true)
  const [mapType, setMapType] = useState<'m' | 'k'>('m') // 'm' = Roadmap, 'k' = Satellite
  const [mapZoom, setMapZoom] = useState<number>(18)
  const [pasteInput, setPasteInput] = useState('')

  // Dark Stores / Hub Territories
  const [darkStores, setDarkStores] = useState<any[]>([])
  const sessionAssignedStoreId = session?.user?.assignedStoreId
  const [selectedStoreHubId, setSelectedStoreHubId] = useState<string>(() => sessionAssignedStoreId || '')

  const handleExtractFromGoogleMaps = (rawText: string) => {
    const text = rawText.trim()
    if (!text) {
      toast.error('Please paste a Google Maps link or coordinates first')
      return
    }

    // 1. Google Maps Place URL with exact pin coordinates: !3d26.1468042!4d80.1773979
    const place3dMatch = text.match(/!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)/)
    if (place3dMatch) {
      const lat = place3dMatch[1]
      const lng = place3dMatch[2]
      setFormData(prev => ({ ...prev, lat, lng }))
      toast.success(`Exact Place coordinates extracted: ${lat}, ${lng} 📍`)
      return
    }

    // 2. Direct coordinates: "26.1558, 80.1685" or "26.1558,80.1685"
    const directMatch = text.match(/(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)/)
    if (directMatch) {
      const lat = directMatch[1]
      const lng = directMatch[2]
      setFormData(prev => ({ ...prev, lat, lng }))
      toast.success(`Google Maps coordinates applied: ${lat}, ${lng} 📍`)
      return
    }

    // Google Maps URL pattern: /@26.1558,80.1685,17z
    const urlAtMatch = text.match(/@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)/)
    if (urlAtMatch) {
      const lat = urlAtMatch[1]
      const lng = urlAtMatch[2]
      setFormData(prev => ({ ...prev, lat, lng }))
      toast.success(`Coordinates extracted from link: ${lat}, ${lng} 📍`)
      return
    }

    // Google Maps query URL: ?q=26.1558,80.1685
    const urlQMatch = text.match(/[?&]q=(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)/)
    if (urlQMatch) {
      const lat = urlQMatch[1]
      const lng = urlQMatch[2]
      setFormData(prev => ({ ...prev, lat, lng }))
      toast.success(`Coordinates extracted from link: ${lat}, ${lng} 📍`)
      return
    }

    toast.error('Could not extract coordinates. Please enter Lat/Lng directly.')
  }

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

  // Sync ownerUserId state when restaurant prop changes
  useEffect(() => {
    if (restaurant?.staff && restaurant.staff.length > 0) {
      const owner = restaurant.staff.find((s: any) => s.role === 'RESTAURANT_OWNER') || restaurant.staff[0]
      if (owner?.id) {
        setOwnerUserId(owner.id)
      }
    }
  }, [restaurant])

  // Fetch assignable users if isAdmin & sync ownerUserId
  useEffect(() => {
    if (isAdmin) {
      setLoadingUsers(true)
      fetch('/api/admin/users/assignable')
        .then(res => res.json())
        .then(data => {
          if (Array.isArray(data)) {
            setAssignableUsers(data)
            if (restaurant?.id) {
              const assignedUser = data.find((u: any) => u.assignedRestaurantId === restaurant.id)
              if (assignedUser) {
                setOwnerUserId(assignedUser.id)
              }
            }
          }
        })
        .catch(console.error)
        .finally(() => setLoadingUsers(false))

      fetch('/api/admin/stores')
        .then(res => res.json())
        .then(stores => {
          if (Array.isArray(stores)) {
            setDarkStores(stores)
            if (!restaurant) {
              const targetStore = (sessionAssignedStoreId ? stores.find(s => s.id === sessionAssignedStoreId) : null) || stores[0]
              if (targetStore) {
                setSelectedStoreHubId(targetStore.id)
                const clean = targetStore.name.replace(/\s*(central\s*hub|dark\s*store|hub|store)\s*/gi, '').trim()
                setFormData(prev => ({ ...prev, city: prev.city || clean }))
              }
              const rCity = String(restaurant.city || '').toLowerCase()
              const matched = stores.find(s => {
                const sName = String(s.name || '').toLowerCase()
                return sName.includes(rCity) || rCity.includes(sName.replace(/central|hub|dark\s*store/gi, '').trim())
              })
              if (matched) {
                setSelectedStoreHubId(matched.id)
              }
            }
          }
        })
        .catch(console.error)
    }
  }, [isAdmin, restaurant?.id, sessionAssignedStoreId])

  // Image File Upload states
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [uploadingBanner, setUploadingBanner] = useState(false)

  const handleFileUpload = async (file: File, type: 'logoUrl' | 'bannerUrl') => {
    if (!file) return
    if (type === 'logoUrl') setUploadingLogo(true)
    else setUploadingBanner(true)

    try {
      const compressedFile = await compressImageClient(file)
      const data = new FormData()
      data.append('file', compressedFile)
      const res = await fetch('/api/upload', {
        method: 'POST',
        headers: {
          ...(session?.user?.id ? { 'x-user-id': session.user.id, 'x-user-role': session.user.role } : {})
        },
        body: data
      })
      if (!res.ok) {
        if (res.status === 413) throw new Error('Photo too large (max 4.5MB)')
        if (res.status === 401) throw new Error('Unauthorized: Please log in again')
        const jsonErr = await res.json().catch(() => ({}))
        throw new Error(jsonErr.error || res.statusText || 'Upload failed')
      }
      const json = await res.json()
      if (json.url) {
        setFormData(prev => ({ ...prev, [type]: json.url }))
        toast.success(`${type === 'logoUrl' ? 'Logo' : 'Banner'} uploaded successfully!`)
      }
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Failed to upload image')
    } finally {
      if (type === 'logoUrl') setUploadingLogo(false)
      else setUploadingBanner(false)
    }
  }

  // Cuisine tag input
  const [tagInput, setTagInput] = useState('')

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
      const parseNum = (v: any) => {
        if (v === null || v === undefined || v === '') return null
        const n = parseFloat(String(v))
        return isNaN(n) ? null : n
      }

      const parseNumDefault = (v: any, def: number) => {
        if (v === null || v === undefined || v === '') return def
        const n = parseFloat(String(v))
        return isNaN(n) ? def : n
      }

      const payload = {
        name: formData.name,
        slug: formData.slug,
        description: formData.description,
        logoUrl: formData.logoUrl,
        bannerUrl: formData.bannerUrl,
        address: formData.address,
        city: formData.city,
        cuisineTags: formData.cuisineTags,
        deliveryTime: formData.deliveryTime,
        distance: formData.distance,
        isVeg: !!formData.isVeg,
        isPureVeg: !!formData.isPureVeg,
        isOpen: !!formData.isOpen,
        openTime: formData.openTime,
        closeTime: formData.closeTime,
        discountOffer: formData.discountOffer,
        discountBadge: formData.discountBadge,
        ownerPhone: formData.ownerPhone,
        ownerEmail: formData.ownerEmail,
        isActive: !!formData.isActive,
        ownerUserId: ownerUserId || undefined,
        commissionRate: parseNumDefault(formData.commissionRate, 0.15),
        sortOrder: Math.round(parseNumDefault(formData.sortOrder, 0)),
        rating: parseNumDefault(formData.rating, 4.0),
        lat: parseNum(formData.lat),
        lng: parseNum(formData.lng),
        storeId: selectedStoreHubId || undefined,
      }

      const url = isEditing ? `/api/restaurants/${restaurant.id}` : '/api/restaurants'
      const method = isEditing ? 'PATCH' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 
          'Content-Type': 'application/json',
          ...(sessionUserId ? { 
            'x-user-id': sessionUserId, 
            'x-user-role': sessionUserRole,
            ...(sessionUserEmail ? { 'x-user-email': sessionUserEmail } : {}),
            ...(sessionUserPhone ? { 'x-user-phone': sessionUserPhone } : {}),
          } : {})
        },
        body: JSON.stringify(payload)
      })

      const responseData = await res.json().catch(() => ({}))

      if (!res.ok) {
        throw new Error(responseData.error || responseData.detail || responseData.message || 'Failed to save restaurant')
      }

      toast.success(isEditing ? 'Outlet profile updated successfully! 🎉' : 'New Outlet created and Head assigned successfully! 🎉')
      if (onSaved) {
        onSaved(responseData)
      } else {
        router.refresh()
        if (isAdmin) {
          router.push('/admin/restaurants')
        }
      }
    } catch (error: any) {
      toast.error(error.message || 'Failed to save restaurant details')
      console.error('Restaurant save error:', error)
    } finally {
      setIsSubmitting(false)
    }
  }


  
  const mapUrl = formData.lat && formData.lng 
    ? `https://maps.google.com/maps?q=${formData.lat},${formData.lng}&z=15&output=embed`
    : null

  const currentOwner = assignableUsers.find(u => u.id === ownerUserId) || (restaurant?.staff ? restaurant.staff.find((s: any) => s.id === ownerUserId) : null)

  const staffUsersCount = useMemo(() => {
    return assignableUsers.filter((u: any) => u.role !== 'USER' || !!u.assignedRestaurantId || u.id === ownerUserId).length
  }, [assignableUsers, ownerUserId])

  const filteredAssignableUsers = useMemo(() => {
    return assignableUsers.filter((u: any) => {
      // Always retain the currently assigned outlet head so they are never filtered out during edit
      if (u.id === ownerUserId) return true

      if (showStaffOnly) {
        const isStaffOrPartner = u.role !== 'USER' || !!u.assignedRestaurantId
        if (!isStaffOrPartner) return false
      }
      if (userSearchQuery.trim()) {
        const q = userSearchQuery.toLowerCase().trim()
        const matchName = (u.name || '').toLowerCase().includes(q)
        const matchEmail = (u.email || '').toLowerCase().includes(q)
        const matchPhone = (u.phone || '').toLowerCase().includes(q)
        return matchName || matchEmail || matchPhone
      }
      return true
    })
  }, [assignableUsers, showStaffOnly, userSearchQuery, ownerUserId])

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
            <button
              type="button"
              onClick={() => setFormData(prev => ({ ...prev, isActive: !prev.isActive }))}
              title="Click to toggle Active status"
              className={cn(
                "flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-black border transition-all cursor-pointer shadow-sm select-none",
                formData.isActive
                  ? "bg-emerald-500/15 text-emerald-600 border-emerald-500/30 hover:bg-emerald-500/25"
                  : "bg-rose-500/15 text-rose-600 border-rose-500/30 hover:bg-rose-500/25"
              )}
            >
              {formData.isActive ? (
                <><Eye className="h-3.5 w-3.5" /> Live on App: Active (Click to toggle)</>
              ) : (
                <><EyeOff className="h-3.5 w-3.5" /> Live on App: Inactive (Click to toggle)</>
              )}
            </button>
          </div>
        </div>
      )}

      {/* Mobile Quick-Nav Section Strip */}
      <div className="relative z-10 bg-card py-2 -mx-2 px-2 sm:mx-0 sm:px-0 border-b border-border/60 overflow-x-auto scrollbar-none flex items-center gap-1.5 mb-2">
        {[
          ...(isAdmin ? [{ id: 'sec-head', label: '👑 Outlet Head' }] : []),
          { id: 'sec-status', label: '⚡ Status' },
          { id: 'sec-profile', label: '🏪 Profile' },
          { id: 'sec-branding', label: '🖼️ Images' },
          { id: 'sec-hours', label: '⏰ Hours' },
          { id: 'sec-location', label: '📍 Location' },
        ].map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={(e) => {
              e.preventDefault()
              const el = document.getElementById(tab.id)
              if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' })
              }
            }}
            className="px-3 py-1.5 rounded-xl bg-muted/70 hover:bg-amber-500 hover:text-white text-[11px] font-black text-text-secondary shrink-0 transition-all cursor-pointer border border-border/40 active:scale-95 shadow-2xs"
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* ======================================================== */}
      {/* 👑 OUTLET HEAD / OWNER ASSIGNMENT (Admin Mode Only)     */}
      {/* ======================================================== */}
      {isAdmin && (
        <div id="sec-head">
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

            {/* Staff Filter Toggle & Customer Search Bar */}
            <div className="flex flex-col sm:flex-row gap-2.5 justify-between items-stretch sm:items-center bg-muted/30 p-2 rounded-2xl border border-border/50">
              {/* Staff vs All Customers Toggle */}
              <div className="flex bg-background p-1 rounded-xl border border-border/50 shrink-0 shadow-2xs">
                <button
                  type="button"
                  onClick={() => setShowStaffOnly(true)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-black transition-all cursor-pointer ${
                    showStaffOnly
                      ? "bg-amber-600 text-white shadow-xs"
                      : "text-text-secondary hover:text-text-primary"
                  }`}
                >
                  👔 Staff & Partners ({staffUsersCount})
                </button>
                <button
                  type="button"
                  onClick={() => setShowStaffOnly(false)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-black transition-all cursor-pointer ${
                    !showStaffOnly
                      ? "bg-amber-600 text-white shadow-xs"
                      : "text-text-secondary hover:text-text-primary"
                  }`}
                >
                  👥 All Customers ({assignableUsers.length})
                </button>
              </div>

              {/* Account Search Input */}
              <div className="relative flex-1 min-w-[200px]">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted" />
                <input
                  type="text"
                  placeholder="Search account by name, phone or email..."
                  value={userSearchQuery}
                  onChange={(e) => setUserSearchQuery(e.target.value)}
                  className="w-full pl-9 pr-8 py-1.5 text-xs font-semibold bg-background border border-border rounded-xl outline-none focus:border-amber-500 transition-all placeholder:text-text-secondary/40"
                />
                {userSearchQuery && (
                  <button
                    type="button"
                    onClick={() => setUserSearchQuery('')}
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-primary p-0.5"
                  >
                    <X className="h-3.5 w-3.5" />
                  </button>
                )}
              </div>
            </div>

            <div className="space-y-1.5">
              <div className="flex justify-between items-center">
                <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                  Select Account to Assign as Outlet Head
                </label>
                <span className="text-[10px] font-bold text-amber-600 dark:text-amber-400">
                  {filteredAssignableUsers.length} accounts found
                </span>
              </div>
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
                  {filteredAssignableUsers.map((u: any) => (
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

            {/* Direct Controlled Password Management for Outlet Head */}
            {currentOwner && (
              <div className="pt-3 border-t border-amber-500/20 space-y-2">
                <label className="text-[11px] font-bold uppercase tracking-wider text-amber-700 dark:text-amber-400 flex items-center gap-1.5">
                  🔑 Outlet Head Password (No OTP Required for Login)
                </label>
                <div className="flex items-center gap-2">
                  <div className="relative flex-1">
                    <input
                      type={showPasswordText ? "text" : "password"}
                      placeholder="Set new password for this Head..."
                      value={headPassword}
                      onChange={(e) => setHeadPassword(e.target.value)}
                      className="w-full px-3.5 py-2.5 text-xs font-mono font-semibold bg-background border border-amber-500/30 rounded-xl outline-none focus:border-amber-500 pr-9"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPasswordText(!showPasswordText)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-primary p-0.5"
                    >
                      {showPasswordText ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                    </button>
                  </div>
                  <button
                    type="button"
                    onClick={async () => {
                      if (!headPassword || headPassword.length < 6) {
                        toast.error('Password must be at least 6 characters')
                        return
                      }
                      try {
                        const res = await fetch('/api/admin/users', {
                          method: 'POST',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify({ userId: currentOwner.id, password: headPassword })
                        })
                        if (!res.ok) throw new Error('Failed to update password')
                        toast.success(`Password set for ${currentOwner.name || 'Head'}! They can now login with Email/Phone & Password without OTP. 🎉`)
                        setHeadPassword('')
                      } catch (err: any) {
                        toast.error(err.message || 'Error setting password')
                      }
                    }}
                    className="px-4 py-2.5 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-xs font-black transition-all cursor-pointer shrink-0 shadow-sm active:scale-95"
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
        </div>
      )}

      {/* ======================================================== */}
      {/* 🔴/🟢 STORE STATUS (OPEN / CLOSED TOGGLE)              */}
      {/* ======================================================== */}
      <div id="sec-status">
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
      </div>

      {/* ============================== */}
      {/* 1-2. BASIC INFO + IMAGES       */}
      {/* ============================== */}
      <RestaurantGeneralInfo
        formData={formData}
        setFormData={setFormData}
        handleChange={handleChange}
        tagInput={tagInput}
        setTagInput={setTagInput}
        handleAddTag={handleAddTag}
        handleRemoveTag={handleRemoveTag}
        handleTagKeyDown={handleTagKeyDown}
        handleFileUpload={handleFileUpload}
        uploadingLogo={uploadingLogo}
        uploadingBanner={uploadingBanner}
      />

      {/* ============================== */}
      {/* 3. LOCATION & MAP              */}
      {/* ============================== */}
      <RestaurantLocationPicker
        formData={formData}
        setFormData={setFormData}
        handleChange={handleChange}
        darkStores={darkStores}
        selectedStoreHubId={selectedStoreHubId}
        setSelectedStoreHubId={setSelectedStoreHubId}
        pasteInput={pasteInput}
        setPasteInput={setPasteInput}
        handleExtractFromGoogleMaps={handleExtractFromGoogleMaps}
        mapType={mapType}
        setMapType={setMapType}
        mapZoom={mapZoom}
        setMapZoom={setMapZoom}
      />

      {/* ============================== */}
      {/* 4-5. TIMINGS + BUSINESS        */}
      {/* ============================== */}
      <RestaurantTimingSchedule
        formData={formData}
        setFormData={setFormData}
        handleChange={handleChange}
        isAdmin={isAdmin}
      />

      {/* STICKY FLOATING ACTION BAR */}
      <div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-40 max-w-2xl w-[94%] bg-card/95 backdrop-blur-md border border-border/80 shadow-2xl rounded-2xl p-2.5 sm:p-3 flex items-center justify-between gap-3 transition-all">
        <div className="flex items-center gap-2.5 min-w-0">
          <div className="h-9 w-9 rounded-xl overflow-hidden bg-muted border border-border/60 shrink-0 flex items-center justify-center font-bold text-xs">
            {formData.logoUrl ? (
              <img src={formData.logoUrl} alt="" className="w-full h-full object-cover" />
            ) : (
              <span>🏪</span>
            )}
          </div>
          <div className="min-w-0 hidden sm:block">
            <p className="text-xs font-black text-text-primary truncate">{formData.name || 'Untitled Outlet'}</p>
            <p className="text-[10px] text-text-secondary font-medium truncate">
              {formData.isOpen ? '🟢 Store Live' : '🌙 Store Closed'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 shrink-0 w-full sm:w-auto justify-end">
          <button
            type="button"
            onClick={() => onSaved ? onSaved(null) : router.push('/admin/restaurants')}
            disabled={isSubmitting}
            className="px-3.5 py-2 border border-border rounded-xl text-xs font-bold hover:bg-muted transition-all cursor-pointer text-text-secondary active:scale-95"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="flex items-center justify-center gap-2 px-5 py-2.5 bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-white rounded-xl text-xs font-black transition-all shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer active:scale-95"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                <span>Saving...</span>
              </>
            ) : (
              <>
                <Save className="h-4 w-4" />
                <span>{isEditing ? 'Save Profile' : 'Create Outlet'}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </form>
  )
}
