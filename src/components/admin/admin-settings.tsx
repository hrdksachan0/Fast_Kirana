'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Sliders, Save, Loader2, Eye, Heart, Star, Package, FileText, Coffee, Plus, Trash2, Edit2, ArrowUp, ArrowDown } from 'lucide-react'
import { motion } from 'framer-motion'
import { DEFAULT_CAFE_MENU_SECTIONS, CafeMenuSection } from '@/lib/constants'

interface AdminSettingsProps {
  onSettingsSaved?: () => void
}

export function AdminSettings({ onSettingsSaved }: AdminSettingsProps) {
  const [deliveriesCount, setDeliveriesCount] = useState('10,000+')
  const [ratingValue, setRatingValue] = useState('4.8')
  const [happyFamilies, setHappyFamilies] = useState('5,000+')
  const [trustedText, setTrustedText] = useState('✨ Trusted by 5,000+ families in your town')
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [onlyCod, setOnlyCod] = useState(false)
  const [deliveryRadius, setDeliveryRadius] = useState('5')
  const [cloudinaryCloudName, setCloudinaryCloudName] = useState('')
  const [cloudinaryUploadPreset, setCloudinaryUploadPreset] = useState('')
  const [storeLat, setStoreLat] = useState('26.1534185')
  const [storeLng, setStoreLng] = useState('80.1714024')
  const [avgDeliveryTime, setAvgDeliveryTime] = useState('8 min')
  const [deliveredToday, setDeliveredToday] = useState('1,231+')
  const [freshStockLoaded, setFreshStockLoaded] = useState('2 hrs ago')
  const [taxRate, setTaxRate] = useState('5')
  const [miscFee, setMiscFee] = useState('0')
  const [miscFeeLabel, setMiscFeeLabel] = useState('Miscellaneous Additions')
  const [cafeMenuSections, setCafeMenuSections] = useState<CafeMenuSection[]>(DEFAULT_CAFE_MENU_SECTIONS)
  
  // Section Editing Form States
  const [isAddingNewSec, setIsAddingNewSec] = useState(false)
  const [editingSecIndex, setEditingSecIndex] = useState<number | null>(null)
  const [secTag, setSecTag] = useState('')
  const [secTitle, setSecTitle] = useState('')
  const [secEmoji, setSecEmoji] = useState('')
  const [secDescription, setSecDescription] = useState('')
  const [secMatchTags, setSecMatchTags] = useState('')

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [savingSections, setSavingSections] = useState(false)

  // Fetch settings on mount
  useEffect(() => {
    async function loadSettings() {
      try {
        setLoading(true)
        const res = await fetch('/api/settings', { cache: 'no-store' })
        if (!res.ok) throw new Error('Failed to load settings')
        const data = await res.json()
        
        if (data.deliveries_count) setDeliveriesCount(data.deliveries_count)
        if (data.rating_value) setRatingValue(data.rating_value)
        if (data.happy_families) setHappyFamilies(data.happy_families)
        if (data.trusted_text) setTrustedText(data.trusted_text)
        if (data.grocery_mart_open !== undefined) setGroceryMartOpen(data.grocery_mart_open === 'true')
        if (data.cafe_open !== undefined) setCafeOpen(data.cafe_open === 'true')
        if (data.only_cod !== undefined) setOnlyCod(data.only_cod === 'true')
        if (data.delivery_radius !== undefined) setDeliveryRadius(data.delivery_radius)
        if (data.cloudinary_cloud_name) setCloudinaryCloudName(data.cloudinary_cloud_name)
        if (data.cloudinary_upload_preset) setCloudinaryUploadPreset(data.cloudinary_upload_preset)
        if (data.store_lat) setStoreLat(data.store_lat)
        if (data.store_lng) setStoreLng(data.store_lng)
        if (data.avg_delivery_time) setAvgDeliveryTime(data.avg_delivery_time)
        if (data.delivered_today) setDeliveredToday(data.delivered_today)
        if (data.fresh_stock_loaded) setFreshStockLoaded(data.fresh_stock_loaded)
        if (data.tax_rate !== undefined) setTaxRate(data.tax_rate)
        if (data.misc_fee !== undefined) setMiscFee(data.misc_fee)
        if (data.misc_fee_label !== undefined) setMiscFeeLabel(data.misc_fee_label)
        if (data.cafe_menu_sections) {
          try {
            const parsed = JSON.parse(data.cafe_menu_sections)
            if (Array.isArray(parsed)) {
              setCafeMenuSections(parsed)
            }
          } catch (e) {
            console.error('Failed to parse cafe menu sections setting:', e)
          }
        }
      } catch (err: any) {
        console.error(err)
        toast.error('Could not fetch store settings')
      } finally {
        setLoading(false)
      }
    }

    loadSettings()
  }, [])

  // Café Menu Sections Manager Actions
  const handleEditSection = (index: number) => {
    const sec = cafeMenuSections[index]
    if (!sec) return
    setEditingSecIndex(index)
    setIsAddingNewSec(false)
    setSecTag(sec.tag)
    setSecTitle(sec.title)
    setSecEmoji(sec.emoji)
    setSecDescription(sec.description || '')
    setSecMatchTags(sec.matchTags ? sec.matchTags.join(', ') : sec.tag)
  }

  const handleAddNewSectionClick = () => {
    setIsAddingNewSec(true)
    setEditingSecIndex(null)
    setSecTag('')
    setSecTitle('')
    setSecEmoji('')
    setSecDescription('')
    setSecMatchTags('')
  }

  const handleCancelSectionEdit = () => {
    setIsAddingNewSec(false)
    setEditingSecIndex(null)
    setSecTag('')
    setSecTitle('')
    setSecEmoji('')
    setSecDescription('')
    setSecMatchTags('')
  }

  const handleSaveSection = (e: React.FormEvent) => {
    e.preventDefault()
    if (!secTag.trim() || !secTitle.trim() || !secEmoji.trim()) {
      toast.error('Tag, Title and Emoji are required')
      return
    }

    const cleanTag = secTag.trim().toLowerCase().replace(/\s+/g, '-')
    const cleanMatchTags = secMatchTags.trim() 
      ? secMatchTags.split(',').map(t => t.trim().toLowerCase()).filter(Boolean)
      : [cleanTag]

    const updatedSec: CafeMenuSection = {
      tag: cleanTag,
      title: secTitle.trim(),
      emoji: secEmoji.trim(),
      description: secDescription.trim(),
      matchTags: cleanMatchTags
    }

    if (isAddingNewSec) {
      if (cafeMenuSections.some(s => s.tag === cleanTag)) {
        toast.error('A section with this tag slug already exists')
        return
      }
      setCafeMenuSections([...cafeMenuSections, updatedSec])
      toast.success('Section added! (Click Save Settings below to apply permanently)')
    } else if (editingSecIndex !== null) {
      const copy = [...cafeMenuSections]
      copy[editingSecIndex] = updatedSec
      setCafeMenuSections(copy)
      toast.success('Section updated! (Click Save Settings below to apply permanently)')
    }

    handleCancelSectionEdit()
  }

  const handleDeleteSection = (index: number) => {
    if (!confirm('Are you sure you want to delete this menu section? Products in this section will fall back to "More Specials".')) return
    const copy = [...cafeMenuSections]
    copy.splice(index, 1)
    setCafeMenuSections(copy)
    toast.success('Section deleted! (Click Save Settings below to apply permanently)')
  }

  const handleMoveSection = (index: number, direction: 'up' | 'down') => {
    if (direction === 'up' && index === 0) return
    if (direction === 'down' && index === cafeMenuSections.length - 1) return

    const copy = [...cafeMenuSections]
    const targetIdx = direction === 'up' ? index - 1 : index + 1
    const [moved] = copy.splice(index, 1)
    copy.splice(targetIdx, 0, moved)
    setCafeMenuSections(copy)
  }

  // Save cafe menu sections directly
  const handleSaveMenuSections = async () => {
    try {
      setSavingSections(true)
      const res = await fetch('/api/admin/settings', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          cafe_menu_sections: JSON.stringify(cafeMenuSections),
        }),
      })

      if (!res.ok) throw new Error('Failed to update café menu sections')
      
      toast.success('Café menu sections saved successfully!')
      if (onSettingsSaved) onSettingsSaved()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error saving café menu sections')
    } finally {
      setSavingSections(false)
    }
  }

  // Save settings handler
  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!deliveriesCount.trim() || !ratingValue.trim() || !happyFamilies.trim() || !trustedText.trim() || !deliveryRadius.trim() || !taxRate.trim() || !miscFee.trim()) {
      toast.error('Please fill in all setting fields')
      return
    }

    try {
      setSaving(true)
      const res = await fetch('/api/admin/settings', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          deliveries_count: deliveriesCount.trim(),
          rating_value: ratingValue.trim(),
          happy_families: happyFamilies.trim(),
          trusted_text: trustedText.trim(),
          grocery_mart_open: groceryMartOpen ? 'true' : 'false',
          cafe_open: cafeOpen ? 'true' : 'false',
          only_cod: onlyCod ? 'true' : 'false',
          delivery_radius: deliveryRadius.trim(),
          cloudinary_cloud_name: cloudinaryCloudName.trim(),
          cloudinary_upload_preset: cloudinaryUploadPreset.trim(),
          store_lat: storeLat.trim(),
          store_lng: storeLng.trim(),
          avg_delivery_time: avgDeliveryTime.trim(),
          delivered_today: deliveredToday.trim(),
          fresh_stock_loaded: freshStockLoaded.trim(),
          tax_rate: taxRate.trim(),
          misc_fee: miscFee.trim(),
          misc_fee_label: miscFeeLabel.trim(),
        }),
      })

      if (!res.ok) throw new Error('Failed to update settings')
      
      toast.success('Store settings updated successfully!')
      if (onSettingsSaved) onSettingsSaved()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error saving store settings')
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="py-20 flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-accent" />
      </div>
    )
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -15 }}
      transition={{ duration: 0.35, ease: 'easeOut' }}
      className="grid grid-cols-1 lg:grid-cols-3 gap-6"
    >
      {/* Settings Form */}
      <div className="lg:col-span-2 space-y-6">
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          <div>
            <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
              <Sliders className="h-5 w-5 text-accent" />
              Store Stats & Settings
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Customize the statistics, ratings, and social proof messages displayed on the storefront.
            </p>
          </div>

          <form onSubmit={handleSave} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              
              {/* Deliveries Count */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Deliveries Counter *</label>
                <div className="relative">
                  <Package className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                  <input
                    type="text"
                    required
                    placeholder="e.g. 10,000+"
                    value={deliveriesCount}
                    onChange={(e) => setDeliveriesCount(e.target.value)}
                    className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                  />
                </div>
              </div>

              {/* Average Rating */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Rating *</label>
                <div className="relative">
                  <Star className="absolute left-3 top-2.5 h-4 w-4 text-amber-500 fill-amber-500/10" />
                  <input
                    type="text"
                    required
                    placeholder="e.g. 4.8"
                    value={ratingValue}
                    onChange={(e) => setRatingValue(e.target.value)}
                    className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                  />
                </div>
              </div>

              {/* Happy Families Count */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Happy Families Counter *</label>
                <div className="relative">
                  <Heart className="absolute left-3 top-2.5 h-4 w-4 text-primary fill-primary/10" />
                  <input
                    type="text"
                    required
                    placeholder="e.g. 5,000+"
                    value={happyFamilies}
                    onChange={(e) => setHappyFamilies(e.target.value)}
                    className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                  />
                </div>
              </div>

              {/* Social Proof Header Strip Text */}
              <div className="md:col-span-3 space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Social Proof Strip Text (Footer) *</label>
                <div className="relative">
                  <FileText className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                  <input
                    type="text"
                    required
                    placeholder="e.g. ✨ Trusted by 5,000+ families in your town"
                    value={trustedText}
                    onChange={(e) => setTrustedText(e.target.value)}
                    className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>

              {/* Store Closed Toggles & Radius Controls */}
              <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                <h4 className="text-xs font-black text-text-primary mb-3">🏪 Store Availability & Delivery Radius</h4>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Grocery Mart Toggle */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Grocery Mart Status</label>
                    <select
                      value={groceryMartOpen ? 'true' : 'false'}
                      onChange={(e) => setGroceryMartOpen(e.target.value === 'true')}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    >
                      <option value="true">🟢 Open (Active)</option>
                      <option value="false">🔴 Closed (Temporarily)</option>
                    </select>
                  </div>

                  {/* Cafe Toggle */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Cafe Status</label>
                    <select
                      value={cafeOpen ? 'true' : 'false'}
                      onChange={(e) => setCafeOpen(e.target.value === 'true')}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    >
                      <option value="true">🟢 Open (Active)</option>
                      <option value="false">🔴 Closed (Temporarily)</option>
                    </select>
                  </div>

                  {/* Only Cash on Delivery */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Only Cash on Delivery</label>
                    <select
                      value={onlyCod ? 'true' : 'false'}
                      onChange={(e) => setOnlyCod(e.target.value === 'true')}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    >
                      <option value="false">🔴 Off (All Payments)</option>
                      <option value="true">🟢 On (COD/COP Only)</option>
                    </select>
                  </div>

                  {/* Delivery Radius */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Delivery Radius (km) *</label>
                    <input
                      type="number"
                      required
                      min="1"
                      max="100"
                      placeholder="e.g. 5"
                      value={deliveryRadius}
                      onChange={(e) => setDeliveryRadius(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Store Latitude */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Latitude (GPS) *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 26.1555"
                      value={storeLat}
                      onChange={(e) => setStoreLat(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Store Longitude */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Longitude (GPS) *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 80.1688"
                      value={storeLng}
                      onChange={(e) => setStoreLng(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>
                </div>
              </div>

              {/* GST/Tax & Miscellaneous Settings */}
              <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                <h4 className="text-xs font-black text-text-primary mb-3">💰 GST/Taxes & Miscellaneous Fees Settings</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* GST/Tax Rate */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">GST/Tax Rate (%) *</label>
                    <input
                      type="number"
                      required
                      min="0"
                      max="100"
                      step="0.1"
                      placeholder="e.g. 5"
                      value={taxRate}
                      onChange={(e) => setTaxRate(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Miscellaneous Fee */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Miscellaneous Fee / Additions (₹) *</label>
                    <input
                      type="number"
                      required
                      min="0"
                      step="0.01"
                      placeholder="e.g. 0"
                      value={miscFee}
                      onChange={(e) => setMiscFee(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Miscellaneous Fee Label */}
                  <div className="space-y-1.5 md:col-span-2">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Miscellaneous Fee Label *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Packaging Charge"
                      value={miscFeeLabel}
                      onChange={(e) => setMiscFeeLabel(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>
                </div>
              </div>

              {/* Speed Strip Ticker Configuration */}
              <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                <h4 className="text-xs font-black text-text-primary mb-3">⚡ Live Speed Ticker Strip Settings</h4>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Avg Delivery Time */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Average Delivery Time *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 8 min"
                      value={avgDeliveryTime}
                      onChange={(e) => setAvgDeliveryTime(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Delivered Today */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Delivered Today Counter *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 1,231+"
                      value={deliveredToday}
                      onChange={(e) => setDeliveredToday(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Fresh Stock Loaded */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Fresh Stock Loaded Indicator *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 2 hrs ago"
                      value={freshStockLoaded}
                      onChange={(e) => setFreshStockLoaded(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>
                </div>
              </div>

              {/* Cloudinary Configuration */}
              <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                <h4 className="text-xs font-black text-text-primary mb-3">☁️ Cloudinary Configurations (Direct Image Uploads)</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Cloud Name */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Cloudinary Cloud Name</label>
                    <input
                      type="text"
                      placeholder="e.g. your_cloud_name"
                      value={cloudinaryCloudName}
                      onChange={(e) => setCloudinaryCloudName(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Upload Preset */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Cloudinary Upload Preset (Unsigned)</label>
                    <input
                      type="text"
                      placeholder="e.g. unsigned_preset"
                      value={cloudinaryUploadPreset}
                      onChange={(e) => setCloudinaryUploadPreset(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>
                </div>
                <p className="text-[9px] text-text-secondary mt-1.5 font-semibold">
                  To enable direct uploads for product images from your computer, create a free account on <a href="https://cloudinary.com" target="_blank" rel="noreferrer" className="text-primary hover:underline">Cloudinary.com</a> and configure an Unsigned upload preset.
                </p>
              </div>

            </div>

            {/* Action buttons */}
            <div className="pt-4 border-t border-border/40 flex justify-end">
              <button
                type="submit"
                disabled={saving}
                className="h-10 px-6 rounded-xl bg-accent hover:bg-accent-dark text-white font-black text-xs transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60 cursor-pointer shadow active:scale-98"
              >
                {saving ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Saving Settings...
                  </>
                ) : (
                  <>
                    <Save className="h-4 w-4" />
                    Save Settings
                  </>
                )}
              </button>
            </div>
          </form>
        </div>

        {/* Café Menu Sections Manager */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
                <Coffee className="h-5 w-5 text-accent" />
                Café Menu Sections Editor
              </h3>
              <p className="text-xs text-text-secondary mt-0.5 font-medium">
                Manage the sections shown on the Café page storefront. Reorder, add, edit, or delete them.
              </p>
            </div>
            
            {!(isAddingNewSec || editingSecIndex !== null) && (
              <button
                type="button"
                onClick={handleAddNewSectionClick}
                className="px-3 py-1.5 rounded-xl bg-accent/10 border border-accent/20 text-accent font-black text-xs hover:bg-accent/25 transition-all flex items-center gap-1 cursor-pointer"
              >
                <Plus className="h-3.5 w-3.5" />
                Add Section
              </button>
            )}
          </div>

          {/* Inline Add / Edit Form */}
          {(isAddingNewSec || editingSecIndex !== null) && (
            <form onSubmit={handleSaveSection} className="bg-muted/30 border border-border p-4 rounded-xl space-y-4">
              <h4 className="text-xs font-black text-text-primary">
                {isAddingNewSec ? '✨ Add New Café Menu Section' : '📝 Edit Café Menu Section'}
              </h4>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                {/* Title */}
                <div className="space-y-1">
                  <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Section Title *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Gourmet Sandwiches"
                    value={secTitle}
                    onChange={(e) => setSecTitle(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-primary font-bold"
                  />
                </div>

                {/* Tag Slug */}
                <div className="space-y-1">
                  <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Tag Slug (Unique) *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. sandwiches"
                    value={secTag}
                    onChange={(e) => setSecTag(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-primary font-mono text-xs font-bold"
                  />
                </div>

                {/* Emoji Icon */}
                <div className="space-y-1">
                  <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Emoji Icon *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 🥪"
                    value={secEmoji}
                    onChange={(e) => setSecEmoji(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-primary text-center font-bold"
                  />
                </div>

                {/* Description */}
                <div className="md:col-span-2 space-y-1">
                  <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Description / Subtitle</label>
                  <input
                    type="text"
                    placeholder="e.g. Freshly grilled loaded sandwiches"
                    value={secDescription}
                    onChange={(e) => setSecDescription(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-primary font-medium"
                  />
                </div>

                {/* Match Tags */}
                <div className="space-y-1">
                  <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Match Product Tags (Comma-separated)</label>
                  <input
                    type="text"
                    placeholder="e.g. sandwich, sandwiches"
                    value={secMatchTags}
                    onChange={(e) => setSecMatchTags(e.target.value)}
                    className="w-full bg-background border border-border px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-primary font-bold"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={handleCancelSectionEdit}
                  className="px-3 py-1.5 border rounded-lg text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4.5 py-1.5 bg-accent hover:bg-accent-dark text-white rounded-lg text-xs font-black transition-colors shadow cursor-pointer"
                >
                  Apply Changes
                </button>
              </div>
            </form>
          )}

          {/* List of Cafe Menu Sections */}
          <div className="space-y-2 max-h-[360px] overflow-y-auto pr-1">
            {cafeMenuSections.map((sec, idx) => (
              <div
                key={sec.tag}
                className="p-3 border border-border bg-muted/10 rounded-xl flex items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <span className="text-2xl h-10 w-10 flex items-center justify-center rounded-lg bg-background border shrink-0">{sec.emoji}</span>
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <strong className="text-xs text-text-primary font-extrabold">{sec.title}</strong>
                      <span className="text-[9px] font-mono font-bold bg-muted px-1.5 py-0.5 rounded border">#{sec.tag}</span>
                    </div>
                    {sec.description && (
                      <p className="text-[10px] text-text-secondary truncate mt-0.5">{sec.description}</p>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-1 shrink-0">
                  {/* Reordering */}
                  <div className="flex flex-col gap-0.5 mr-1">
                    <button
                      type="button"
                      disabled={idx === 0}
                      onClick={() => handleMoveSection(idx, 'up')}
                      className="p-0.5 hover:bg-muted text-text-secondary disabled:opacity-30 rounded"
                      title="Move Up"
                    >
                      <ArrowUp className="h-3 w-3" />
                    </button>
                    <button
                      type="button"
                      disabled={idx === cafeMenuSections.length - 1}
                      onClick={() => handleMoveSection(idx, 'down')}
                      className="p-0.5 hover:bg-muted text-text-secondary disabled:opacity-30 rounded"
                      title="Move Down"
                    >
                      <ArrowDown className="h-3 w-3" />
                    </button>
                  </div>

                  {/* Edit */}
                  <button
                    type="button"
                    onClick={() => handleEditSection(idx)}
                    className="p-1.5 border border-border hover:bg-muted text-text-secondary hover:text-text-primary rounded-lg transition-colors cursor-pointer"
                    title="Edit Section"
                  >
                    <Edit2 className="h-3.5 w-3.5" />
                  </button>

                  {/* Delete */}
                  <button
                    type="button"
                    onClick={() => handleDeleteSection(idx)}
                    className="p-1.5 border border-danger/20 bg-danger/5 hover:bg-danger/10 text-danger rounded-lg transition-colors cursor-pointer"
                    title="Delete Section"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Separate Save Button for Sections */}
          <div className="pt-4 border-t border-border flex justify-end">
            <button
              type="button"
              onClick={handleSaveMenuSections}
              disabled={savingSections}
              className="px-6 py-2.5 rounded-xl bg-accent hover:bg-accent-dark text-white font-black text-xs transition-all flex items-center gap-2 shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer"
            >
              {savingSections ? (
                <>
                  <span className="h-3.5 w-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  Saving Sections...
                </>
              ) : (
                <>
                  <Save className="h-4 w-4" />
                  Save Café Sections
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Live Preview Sidebar */}
      <div className="space-y-6">
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex items-center gap-1.5">
            <Eye className="h-5 w-5 text-accent" />
            <h3 className="text-sm font-bold text-text-primary">Live Preview</h3>
          </div>
          
          {/* Stats Bar Preview */}
          <div className="space-y-2">
            <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-muted">Home Page Stats Bar</label>
            <div className="flex items-center justify-center gap-4 py-3 bg-muted/20 border border-border/60 rounded-xl px-2">
              <div className="flex items-center gap-1">
                <Package className="h-3.5 w-3.5 text-primary" />
                <span className="text-[11px] font-black text-text-primary">{deliveriesCount}</span>
                <span className="text-[10px] text-text-secondary font-medium">Deliveries</span>
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1">
                <Star className="h-3.5 w-3.5 text-amber-500" />
                <span className="text-[11px] font-black text-text-primary">{ratingValue}★</span>
                <span className="text-[10px] text-text-secondary font-medium">Rating</span>
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1">
                <Heart className="h-3.5 w-3.5 text-primary" />
                <span className="text-[11px] font-black text-text-primary">{happyFamilies}</span>
                <span className="text-[10px] text-text-secondary font-medium">Families</span>
              </div>
            </div>
          </div>

          {/* Social Proof Strip Preview */}
          <div className="space-y-2">
            <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-muted">Footer Social Proof Bar</label>
            <div className="bg-text-primary py-2.5 rounded-xl text-center border border-border/60 shadow-sm overflow-hidden">
              <p className="text-[10px] font-extrabold text-accent leading-normal select-none px-4">
                {trustedText}
              </p>
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  )
}
