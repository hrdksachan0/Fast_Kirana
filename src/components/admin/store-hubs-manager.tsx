'use client'

import React, { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { 
  Building2, 
  MapPin, 
  Store, 
  Utensils, 
  Plus, 
  X, 
  Check, 
  Loader2, 
  ChevronRight, 
  Layers, 
  Package, 
  Settings, 
  Radio, 
  ExternalLink,
  ShieldCheck,
  AlertCircle,
  Clock,
  Sparkles,
  Phone,
  Hash
} from 'lucide-react'
import { toast } from 'sonner'
import Link from 'next/link'

export interface StoreHub {
  id: string
  name: string
  latitude: number
  longitude: number
  deliveryPolygon?: any
  isActive: boolean
  surgeCharge: number
  deliveryRadiusKm?: number
  groceryOpen: boolean
  _count?: { staffMembers?: number }
  manager?: { id: string; name: string; phone: string; email: string } | null
}

export interface StoreHubsManagerProps {
  isOpen: boolean
  onClose: () => void
  stores: StoreHub[]
  restaurants: any[]
  selectedHubId: string
  onSelectHub: (hubId: string) => void
  onRefresh: () => void
  isHubAdmin?: boolean
  assignedStoreId?: string | null
}

export function StoreHubsManager({
  isOpen,
  onClose,
  stores,
  restaurants,
  selectedHubId,
  onSelectHub,
  onRefresh,
  isHubAdmin = false,
  assignedStoreId = null
}: StoreHubsManagerProps) {
  const [activeTab, setActiveTab] = useState<'hierarchy' | 'new-hub' | 'new-outlet'>('hierarchy')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // New Store Hub Form State
  const [newHubName, setNewHubName] = useState('')
  const [newHubPincode, setNewHubPincode] = useState('')
  const [newHubCustomId, setNewHubCustomId] = useState('')
  const [newHubLat, setNewHubLat] = useState('26.1534')
  const [newHubLng, setNewHubLng] = useState('80.1714')
  const [newHubRadius, setNewHubRadius] = useState('5.0')
  const [newHubSurge, setNewHubSurge] = useState('0')
  const [seedInventory, setSeedInventory] = useState(true)
  const [newHubManagerPhone, setNewHubManagerPhone] = useState('')
  const [editingManagerStoreId, setEditingManagerStoreId] = useState<string | null>(null)
  const [editManagerPhoneInput, setEditManagerPhoneInput] = useState('')

  const cleanPincodeInput = newHubPincode.replace(/\D/g, '')
  const computedHubId = newHubCustomId.trim() || (cleanPincodeInput.length === 6 ? `hub-${cleanPincodeInput}` : (newHubName.trim() ? `hub-${newHubName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}` : 'hub-[pincode]'))

  // New Restaurant Outlet Form State
  const [newOutletName, setNewOutletName] = useState('')
  const [newOutletSlug, setNewOutletSlug] = useState('')
  const [newOutletCity, setNewOutletCity] = useState('Ghatampur')
  const [newOutletPhone, setNewOutletPhone] = useState('')
  const [newOutletCommission, setNewOutletCommission] = useState('15')
  const [newOutletRadius, setNewOutletRadius] = useState('5.0')

  // Handle Hub Creation
  const handleCreateHub = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newHubName.trim()) {
      toast.error('Store Hub Name is required')
      return
    }

    setIsSubmitting(true)
    try {
      const res = await fetch('/api/admin/stores', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: newHubName.trim(),
          pincode: newHubPincode.trim(),
          id: newHubCustomId.trim() || undefined,
          latitude: parseFloat(newHubLat),
          longitude: parseFloat(newHubLng),
          deliveryRadiusKm: parseFloat(newHubRadius),
          surgeCharge: parseFloat(newHubSurge),
          groceryOpen: true,
          isActive: true,
          seedInventory,
          managerPhone: newHubManagerPhone.trim() || undefined
        })
      })

      const data = await res.json()
      if (res.ok) {
        toast.success(`Store Hub "${newHubName}" (${data.id || computedHubId}) created successfully!`)
        setNewHubName('')
        setNewHubPincode('')
        setNewHubCustomId('')
        setNewHubManagerPhone('')
        setActiveTab('hierarchy')
        onRefresh()
      } else {
        toast.error(data.error || 'Failed to create Store Hub')
      }
    } catch (err: any) {
      toast.error(err.message || 'Error creating store hub')
    } finally {
      setIsSubmitting(false)
    }
  }

  // Quick reassign manager phone
  const handleUpdateManagerPhone = async (storeId: string) => {
    if (!editManagerPhoneInput.trim()) {
      toast.error('Please enter a phone number')
      return
    }
    setIsSubmitting(true)
    try {
      const res = await fetch('/api/admin/stores', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: storeId,
          managerPhone: editManagerPhoneInput.trim()
        })
      })
      if (res.ok) {
        toast.success('Store Hub Manager assigned successfully!')
        setEditingManagerStoreId(null)
        setEditManagerPhoneInput('')
        onRefresh()
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to update manager')
      }
    } catch (err: any) {
      toast.error(err.message || 'Error updating manager')
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle Restaurant Outlet Creation
  const handleCreateOutlet = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newOutletName.trim()) {
      toast.error('Restaurant name is required')
      return
    }

    const slug = newOutletSlug.trim() || newOutletName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
    const phone = newOutletPhone.trim().replace(/\D/g, '')

    setIsSubmitting(true)
    try {
      const res = await fetch('/api/restaurants', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: newOutletName.trim(),
          slug,
          city: (isHubAdmin ? (activeStore?.name || 'Ghatampur') : newOutletCity).trim(),
          ownerPhone: phone ? `+91${phone.slice(-10)}` : undefined,
          commissionRate: parseFloat(newOutletCommission) || 15,
          deliveryRadiusKm: parseFloat(newOutletRadius) || 5.0,
          isOpen: true,
          isActive: true
        })
      })

      const data = await res.json()
      if (res.ok) {
        toast.success(`Restaurant Outlet "${newOutletName}" (${data.id}) created successfully!`)
        setNewOutletName('')
        setNewOutletSlug('')
        setNewOutletPhone('')
        setActiveTab('hierarchy')
        onRefresh()
      } else {
        toast.error(data.error || 'Failed to create restaurant outlet')
      }
    } catch (err: any) {
      toast.error(err.message || 'Error creating restaurant outlet')
    } finally {
      setIsSubmitting(false)
    }
  }

  // Toggle Dark Store Grocery Open
  const handleToggleGrocery = async (store: StoreHub) => {
    try {
      const newStatus = !store.groceryOpen
      const res = await fetch('/api/admin/stores', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: store.id, groceryOpen: newStatus })
      })
      if (res.ok) {
        toast.success(`${store.name} Grocery Mart is now ${newStatus ? 'OPEN' : 'CLOSED'}`)
        onRefresh()
      } else {
        toast.error('Failed to update grocery status')
      }
    } catch (err: any) {
      toast.error(err.message)
    }
  }

  // Toggle Restaurant Outlet Open
  const handleToggleRestaurant = async (restaurant: any) => {
    try {
      const newStatus = !restaurant.isOpen
      const res = await fetch(`/api/restaurants/${restaurant.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isOpen: newStatus })
      })
      if (res.ok) {
        toast.success(`${restaurant.name} Kitchen is now ${newStatus ? 'OPEN' : 'CLOSED'}`)
        onRefresh()
      } else {
        toast.error('Failed to update kitchen status')
      }
    } catch (err: any) {
      toast.error(err.message)
    }
  }

  if (!isOpen) return null

  const activeStore = stores.find(s => s.id === selectedHubId) || stores[0]
  const hubCityName = activeStore?.name ? activeStore.name.replace(/\s*(market|hub|dark\s*store).*$/i, '').trim().toLowerCase() : ''
  const hubRestaurants = restaurants.filter(r => {
    if (!activeStore) return true
    if (!r.city) return false
    const rCity = r.city.trim().toLowerCase()
    return rCity === activeStore.name.toLowerCase().trim() || 
           (hubCityName && (rCity.includes(hubCityName) || hubCityName.includes(rCity)))
  })

  return (
    <div className="fixed inset-0 z-[110] flex items-center justify-center p-3 sm:p-6 bg-black/60 backdrop-blur-sm animate-fade-in overflow-y-auto">
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 15 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 15 }}
        className="bg-card border border-border/80 rounded-3xl w-full max-w-4xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
      >
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border/60 bg-muted/20">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-2xl bg-[#e20a22]/10 text-[#e20a22] flex items-center justify-center font-bold">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
                {isHubAdmin ? `${activeStore?.name || 'Hub'} Operations & Outlets` : 'Store Hubs & Multi-Domain System'}
                <span className="text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-600 border border-emerald-500/20">
                  {isHubAdmin ? 'Store Manager Mode' : 'Super Admin Architecture'}
                </span>
              </h2>
              <p className="text-xs text-text-secondary">
                {isHubAdmin 
                  ? 'Manage your territory dark store status and local partner kitchen outlets' 
                  : 'Central Grocery Domain (Dark Store) + Food & Restaurant Domain (Kitchen Outlets)'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-text-secondary hover:text-text-primary hover:bg-muted transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="flex border-b border-border/60 px-6 pt-3 gap-2 bg-muted/10">
          <button
            onClick={() => setActiveTab('hierarchy')}
            className={`pb-3 px-3 text-xs font-black uppercase tracking-wider border-b-2 transition-colors ${
              activeTab === 'hierarchy'
                ? 'border-[#e20a22] text-[#e20a22]'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            {isHubAdmin ? '🏢 My Hub & Local Outlets' : '🏢 Hub Hierarchy Tree'}
          </button>
          {!isHubAdmin && (
            <button
              onClick={() => setActiveTab('new-hub')}
              className={`pb-3 px-3 text-xs font-black uppercase tracking-wider border-b-2 transition-colors ${
                activeTab === 'new-hub'
                  ? 'border-[#e20a22] text-[#e20a22]'
                  : 'border-transparent text-text-secondary hover:text-text-primary'
              }`}
            >
              ➕ Add Store Hub
            </button>
          )}
          <button
            onClick={() => {
              if (activeStore?.name) {
                setNewOutletCity(activeStore.name)
              }
              setActiveTab('new-outlet')
            }}
            className={`pb-3 px-3 text-xs font-black uppercase tracking-wider border-b-2 transition-colors ${
              activeTab === 'new-outlet'
                ? 'border-[#e20a22] text-[#e20a22]'
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            🍳 Add Kitchen Outlet
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 overflow-y-auto space-y-6 flex-1">
          {activeTab === 'hierarchy' && (
            <div className="space-y-6">
              {/* Store Hub Switcher Bar */}
              <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-4 rounded-2xl bg-muted/30 border border-border/60">
                <div className="flex items-center gap-2.5">
                  <MapPin className="w-4 h-4 text-[#e20a22]" />
                  <span className="text-xs font-bold text-text-primary">
                    {isHubAdmin ? 'Assigned Store Hub:' : 'Select Active Store Hub:'}
                  </span>
                  {isHubAdmin ? (
                    <span className="px-3 py-1.5 rounded-xl border border-amber-500/30 bg-amber-500/10 text-amber-800 dark:text-amber-200 text-xs font-bold">
                      📍 {activeStore?.name} Hub ({activeStore?.id})
                    </span>
                  ) : (
                    <select
                      value={selectedHubId}
                      onChange={(e) => onSelectHub(e.target.value)}
                      className="px-3 py-1.5 rounded-xl border border-border/80 bg-background text-text-primary text-xs font-bold focus:outline-none focus:ring-2 focus:ring-primary/20"
                    >
                      {stores.map((s) => (
                        <option key={s.id} value={s.id}>
                          📍 {s.name} Hub ({s.id})
                        </option>
                      ))}
                    </select>
                  )}
                </div>
                <div className="text-[11px] font-bold text-text-secondary">
                  GPS: {activeStore?.latitude?.toFixed(4)}, {activeStore?.longitude?.toFixed(4)} • Serviceable Radius: {activeStore?.deliveryRadiusKm || 5.0} km
                </div>
              </div>

              {/* Visual Architecture Tree */}
              <div className="relative border border-border/80 rounded-2xl p-5 bg-card/60 shadow-sm space-y-6">
                {/* 🏢 Store Hub Header */}
                <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-3.5 rounded-xl bg-gradient-to-r from-primary/10 via-primary/5 to-transparent border border-primary/20">
                  <div className="flex items-center gap-3">
                    <div className="h-10 w-10 rounded-xl bg-primary text-primary-foreground flex items-center justify-center font-black">
                      🏢
                    </div>
                    <div>
                      <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                        Store Hub: {activeStore?.name || 'Ghatampur'}
                        <span className="text-[10px] font-mono font-bold bg-muted px-2 py-0.5 rounded-md text-text-secondary border border-border/60">
                          store_id: {activeStore?.id}
                        </span>
                      </h3>
                      <p className="text-[11px] text-text-secondary mt-0.5">
                        Master routing anchor for customer location detection, inventory, and restaurant dispatch.
                      </p>
                    </div>
                  </div>

                  {/* Hub Manager Badge / Quick Assignment */}
                  <div className="flex items-center gap-2 bg-background/90 px-3 py-1.5 rounded-xl border border-border/80 text-xs shadow-xs">
                    <ShieldCheck className="w-3.5 h-3.5 text-indigo-600 shrink-0" />
                    <div className="text-left">
                      <span className="text-[9px] font-bold text-text-secondary block">Hub Manager:</span>
                      <span className="font-bold text-text-primary text-[11px]">
                        {activeStore?.manager?.phone 
                          ? `${activeStore.manager.phone}${activeStore.manager.name ? ` (${activeStore.manager.name})` : ''}` 
                          : 'No Admin Assigned'}
                      </span>
                    </div>
                    {!isHubAdmin && (
                      editingManagerStoreId === activeStore?.id ? (
                        <div className="flex items-center gap-1 ml-2">
                          <input
                            type="tel"
                            placeholder="10-digit phone"
                            value={editManagerPhoneInput}
                            onChange={(e) => setEditManagerPhoneInput(e.target.value.replace(/\D/g, ''))}
                            className="w-28 px-2 py-0.5 text-xs rounded border border-border bg-background"
                            maxLength={10}
                          />
                          <button
                            onClick={() => activeStore && handleUpdateManagerPhone(activeStore.id)}
                            className="p-1 rounded bg-emerald-600 text-white hover:bg-emerald-700"
                            title="Save"
                          >
                            <Check className="w-3 h-3" />
                          </button>
                          <button
                            onClick={() => setEditingManagerStoreId(null)}
                            className="p-1 rounded bg-muted text-text-secondary hover:text-text-primary"
                            title="Cancel"
                          >
                            <X className="w-3 h-3" />
                          </button>
                        </div>
                      ) : (
                        <button
                          onClick={() => {
                            if (activeStore) {
                              setEditingManagerStoreId(activeStore.id)
                              setEditManagerPhoneInput(activeStore.manager?.phone?.replace(/\D/g, '').slice(-10) || '')
                            }
                          }}
                          className="ml-2 text-[10px] font-bold text-primary hover:underline"
                        >
                          {activeStore?.manager ? 'Edit' : '+ Assign'}
                        </button>
                      )
                    )}
                  </div>
                </div>

                {/* 2 DOMAIN WINGS GRID */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5 pt-2">
                  {/* 🏪 1. CENTRAL GROCERY DOMAIN */}
                  <div className="border border-emerald-500/30 rounded-2xl p-4 bg-emerald-500/5 space-y-3">
                    <div className="flex items-center justify-between pb-2 border-b border-emerald-500/20">
                      <div className="flex items-center gap-2">
                        <Store className="w-4 h-4 text-emerald-600" />
                        <h4 className="text-xs font-black uppercase tracking-wider text-emerald-700 dark:text-emerald-400">
                          1. Central Grocery Domain
                        </h4>
                      </div>
                      <span className="text-[9px] font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 font-bold">
                        store_type: GROCERY
                      </span>
                    </div>

                    <div className="bg-background/80 rounded-xl p-3 border border-border/60 space-y-2 text-xs">
                      <div className="flex items-center justify-between">
                        <span className="font-bold text-text-primary">🛒 {activeStore?.name} Dark Store</span>
                        <button
                          onClick={() => activeStore && handleToggleGrocery(activeStore)}
                          className={`text-[10px] font-black uppercase tracking-wider px-2.5 py-1 rounded-full border transition-all ${
                            activeStore?.groceryOpen
                              ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30 hover:bg-emerald-500/25'
                              : 'bg-rose-500/15 text-rose-700 dark:text-rose-300 border-rose-500/30 hover:bg-rose-500/25'
                          }`}
                        >
                          {activeStore?.groceryOpen ? '● Grocery OPEN' : '○ Grocery CLOSED'}
                        </button>
                      </div>
                      <div className="text-[11px] text-text-secondary space-y-1 font-medium">
                        <div>• Dark Store ID: <code className="font-mono font-bold text-text-primary">{activeStore?.id}</code></div>
                        <div>• Geofence: 5.0 km nearby delivery zone</div>
                        <div>• Staff Pickers: {activeStore?._count?.staffMembers ?? 0} assigned</div>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-2 pt-1">
                      <div className="p-2.5 rounded-xl bg-background/60 border border-border/50 text-center">
                        <div className="text-base font-black text-text-primary">232</div>
                        <div className="text-[10px] text-text-secondary font-bold uppercase tracking-wider">Grocery SKUs</div>
                      </div>
                      <div className="p-2.5 rounded-xl bg-background/60 border border-border/50 text-center">
                        <div className="text-base font-black text-text-primary">Categories</div>
                        <div className="text-[10px] text-text-secondary font-bold uppercase tracking-wider">By Category ID</div>
                      </div>
                    </div>
                  </div>

                  {/* 🍳 2. FOOD & RESTAURANT DOMAIN */}
                  <div className="border border-amber-500/30 rounded-2xl p-4 bg-amber-500/5 space-y-3">
                    <div className="flex items-center justify-between pb-2 border-b border-amber-500/20">
                      <div className="flex items-center gap-2">
                        <Utensils className="w-4 h-4 text-amber-600" />
                        <h4 className="text-xs font-black uppercase tracking-wider text-amber-700 dark:text-amber-400">
                          2. Food & Restaurant Domain
                        </h4>
                      </div>
                      <span className="text-[9px] font-mono px-2 py-0.5 rounded bg-amber-500/10 text-amber-700 dark:text-amber-300 font-bold">
                        store_type: RESTAURANT
                      </span>
                    </div>

                    <div className="space-y-2 max-h-56 overflow-y-auto pr-1 scrollbar-none">
                      {hubRestaurants.map((rest, idx) => (
                        <div
                          key={rest.id}
                          className="bg-background/80 rounded-xl p-3 border border-border/60 text-xs space-y-1.5"
                        >
                          <div className="flex items-center justify-between">
                            <div className="font-black text-text-primary flex items-center gap-1.5">
                              <span>🍽️ {rest.name}</span>
                              <span className="text-[9px] font-mono px-1.5 py-0.5 rounded bg-muted text-text-secondary">
                                {rest.slug}
                              </span>
                            </div>
                            <button
                              onClick={() => handleToggleRestaurant(rest)}
                              className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full border ${
                                rest.isOpen
                                  ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30'
                                  : 'bg-rose-500/15 text-rose-700 dark:text-rose-300 border-rose-500/30'
                              }`}
                            >
                              {rest.isOpen ? 'Kitchen OPEN' : 'CLOSED'}
                            </button>
                          </div>
                          <div className="flex items-center justify-between text-[11px] text-text-secondary font-medium">
                            <span className="font-mono text-[10px]">ID: {rest.id.slice(0, 14)}...</span>
                            <span className="font-bold text-text-primary">{rest._count?.products || 0} Dishes</span>
                          </div>
                          <div className="flex items-center gap-2 pt-1 border-t border-border/40">
                            <Link
                              href={`/restaurant-kitchen?restaurantId=${rest.id}`}
                              target="_blank"
                              className="text-[10px] font-bold text-[#e20a22] hover:underline flex items-center gap-1"
                            >
                              <span>Kitchen Console</span>
                              <ExternalLink className="w-2.5 h-2.5" />
                            </Link>
                            <span className="text-border">•</span>
                            <Link
                              href={`/restaurant-kitchen?restaurantId=${rest.id}&tab=catalog`}
                              target="_blank"
                              className="text-[10px] font-bold text-text-secondary hover:text-text-primary"
                            >
                              Menu Sections
                            </Link>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'new-hub' && (
            <form onSubmit={handleCreateHub} className="max-w-xl mx-auto space-y-4">
              <div className="text-center mb-4">
                <h3 className="text-base font-black text-text-primary">Create New Store Hub</h3>
                <p className="text-xs text-text-secondary mt-0.5">
                  Expand FastKirana to a new city or operational territory with its own Dark Store and location checks.
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">
                    Store Hub Name (City / Area) *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Hamirpur Central Hub"
                    value={newHubName}
                    onChange={(e) => setNewHubName(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-xs rounded-xl border border-border/80 bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1 flex items-center justify-between">
                    <span>Territory Pincode (6-Digit) *</span>
                    <span className="text-[10px] font-mono text-emerald-600 font-bold">Standard Hub ID</span>
                  </label>
                  <input
                    type="text"
                    required
                    maxLength={6}
                    placeholder="e.g. 210301"
                    value={newHubPincode}
                    onChange={(e) => setNewHubPincode(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3.5 py-2.5 text-xs font-mono font-bold rounded-xl border border-border/80 bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>
              </div>

              {/* Dynamic Systematic Hub ID Preview */}
              <div className="flex items-center justify-between px-3.5 py-2 rounded-xl bg-muted/40 border border-border/60 text-xs">
                <span className="text-[11px] text-text-secondary font-medium">Auto-generated Store ID:</span>
                <span className="font-mono font-black text-primary text-xs px-2.5 py-1 rounded bg-background border border-border shadow-xs">
                  {computedHubId}
                </span>
              </div>

              <div>
                <label className="block text-xs font-bold text-text-primary mb-1">
                  Custom Store Hub ID (Optional - overrides auto-generated pincode ID)
                </label>
                <input
                  type="text"
                  placeholder="Leave blank to use pincode format (e.g. hub-210301)"
                  value={newHubCustomId}
                  onChange={(e) => setNewHubCustomId(e.target.value)}
                  className="w-full px-3.5 py-2.5 text-xs font-mono rounded-xl border border-border/80 bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                />
              </div>

              {/* Quick City Presets */}
              <div>
                <label className="block text-[11px] font-bold text-text-secondary mb-1.5">
                  ⚡ Quick Territory Presets (Auto-sets Name, Pincode & Coordinates):
                </label>
                <div className="flex flex-wrap gap-1.5">
                  {[
                    { name: 'Hamirpur Central Hub', city: 'Hamirpur', pincode: '210301', lat: '25.9554', lng: '80.1512' },
                    { name: 'Pukhrayan Hub', city: 'Pukhrayan', pincode: '209111', lat: '26.2300', lng: '79.8500' },
                    { name: 'Kanpur South Hub', city: 'Kanpur South', pincode: '208001', lat: '26.4000', lng: '80.3000' },
                    { name: 'Ghatampur Central Hub', city: 'Ghatampur', pincode: '209206', lat: '26.1534', lng: '80.1714' },
                  ].map((preset) => (
                    <button
                      key={preset.city}
                      type="button"
                      onClick={() => {
                        setNewHubName(preset.name)
                        setNewHubPincode(preset.pincode)
                        setNewHubLat(preset.lat)
                        setNewHubLng(preset.lng)
                      }}
                      className="px-2.5 py-1 text-[10px] font-bold rounded-lg border border-border/80 bg-muted/40 hover:bg-primary/10 hover:border-primary/40 text-text-primary transition-colors cursor-pointer"
                    >
                      📍 {preset.city} ({preset.pincode})
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Latitude *</label>
                  <input
                    type="number"
                    step="any"
                    required
                    value={newHubLat}
                    onChange={(e) => setNewHubLat(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Longitude *</label>
                  <input
                    type="number"
                    step="any"
                    required
                    value={newHubLng}
                    onChange={(e) => setNewHubLng(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Delivery Radius (km)</label>
                  <input
                    type="number"
                    step="0.5"
                    value={newHubRadius}
                    onChange={(e) => setNewHubRadius(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Surge Charge (₹)</label>
                  <input
                    type="number"
                    value={newHubSurge}
                    onChange={(e) => setNewHubSurge(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
              </div>

              {/* Hub Manager / Admin Phone Number */}
              <div>
                <label className="block text-xs font-bold text-text-primary mb-1">
                  Assign Hub Admin / Store Manager Phone (Optional)
                </label>
                <div className="relative">
                  <Phone className="w-3.5 h-3.5 absolute left-3 top-3 text-text-secondary" />
                  <input
                    type="tel"
                    placeholder="e.g. 9876543210 (Automatically activates city Admin Console for this number)"
                    maxLength={10}
                    value={newHubManagerPhone}
                    onChange={(e) => setNewHubManagerPhone(e.target.value.replace(/\D/g, ''))}
                    className="w-full pl-9 pr-3.5 py-2.5 text-xs font-mono rounded-xl border border-border/80 bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                </div>
                <p className="text-[10px] text-text-secondary mt-1">
                  When this mobile number logs in via OTP, their Admin Console activates automatically, locked to this Hub.
                </p>
              </div>

              {/* Seed Grocery Dark Store Inventory Checkbox */}
              <div className="flex items-center gap-2.5 p-3 rounded-xl bg-muted/30 border border-border/60">
                <input
                  type="checkbox"
                  id="seedInventory"
                  checked={seedInventory}
                  onChange={(e) => setSeedInventory(e.target.checked)}
                  className="rounded border-border text-[#e20a22] focus:ring-[#e20a22] cursor-pointer h-4 w-4"
                />
                <label htmlFor="seedInventory" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  Auto-seed Central Grocery Dark Store inventory (all items ready for 10-min delivery)
                </label>
              </div>

              <div className="pt-2">
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-3 rounded-2xl bg-[#e20a22] hover:bg-[#c9081e] text-white text-xs font-black uppercase tracking-wider shadow-md hover:shadow-lg transition-all active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  {isSubmitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
                  <span>Initialize New Store Hub</span>
                </button>
              </div>
            </form>
          )}

          {activeTab === 'new-outlet' && (
            <form onSubmit={handleCreateOutlet} className="max-w-xl mx-auto space-y-4">
              <div className="text-center mb-4">
                <h3 className="text-base font-black text-text-primary">Add Restaurant / Kitchen Outlet</h3>
                <p className="text-xs text-text-secondary mt-0.5">
                  Link a food partner kitchen to a Store Hub with dedicated KOT, orders, and menu sections.
                </p>
              </div>

              <div>
                <label className="block text-xs font-bold text-text-primary mb-1">
                  Restaurant / Outlet Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Royal Bakes, Gupta Sweets"
                  value={newOutletName}
                  onChange={(e) => setNewOutletName(e.target.value)}
                  className="w-full px-3.5 py-2.5 text-xs rounded-xl border border-border/80 bg-background text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Associated Store Hub *</label>
                  {isHubAdmin ? (
                    <div className="w-full px-3 py-2 text-xs rounded-xl border border-emerald-500/30 bg-emerald-500/10 text-emerald-800 dark:text-emerald-200 font-bold flex items-center justify-between">
                      <span className="truncate">🏢 {activeStore?.name || 'Assigned Hub'}</span>
                      <span className="text-[9px] font-mono font-black uppercase text-emerald-700 bg-emerald-500/20 px-1.5 py-0.5 rounded">Locked</span>
                    </div>
                  ) : (
                    <select
                      value={newOutletCity}
                      onChange={(e) => setNewOutletCity(e.target.value)}
                      className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary font-bold cursor-pointer"
                    >
                      {stores.map((s) => (
                        <option key={s.id} value={s.name}>
                          {s.name}
                        </option>
                      ))}
                    </select>
                  )}
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Owner Phone (10 digits)</label>
                  <input
                    type="tel"
                    placeholder="e.g. 9876543210"
                    maxLength={10}
                    value={newOutletPhone}
                    onChange={(e) => setNewOutletPhone(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Commission Rate (%)</label>
                  <input
                    type="number"
                    value={newOutletCommission}
                    onChange={(e) => setNewOutletCommission(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-primary mb-1">Delivery Radius (km)</label>
                  <input
                    type="number"
                    step="0.5"
                    value={newOutletRadius}
                    onChange={(e) => setNewOutletRadius(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-border/80 bg-background text-text-primary"
                  />
                </div>
              </div>

              <div className="pt-3">
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-3 rounded-2xl bg-[#e20a22] hover:bg-[#c9081e] text-white text-xs font-black uppercase tracking-wider shadow-md hover:shadow-lg transition-all active:scale-[0.98] flex items-center justify-center gap-2"
                >
                  {isSubmitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
                  <span>Register Kitchen Outlet (Generates Unique ID)</span>
                </button>
              </div>
            </form>
          )}
        </div>
      </motion.div>
    </div>
  )
}
