'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Sliders, Save, Loader2, Eye, Heart, Star, Package, FileText } from 'lucide-react'
import { motion } from 'framer-motion'

export function AdminSettings() {
  const [deliveriesCount, setDeliveriesCount] = useState('10,000+')
  const [ratingValue, setRatingValue] = useState('4.8')
  const [happyFamilies, setHappyFamilies] = useState('5,000+')
  const [trustedText, setTrustedText] = useState('✨ Trusted by 5,000+ families in your town')
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [deliveryRadius, setDeliveryRadius] = useState('5')
  const [cloudinaryCloudName, setCloudinaryCloudName] = useState('')
  const [cloudinaryUploadPreset, setCloudinaryUploadPreset] = useState('')
  const [storeLat, setStoreLat] = useState('26.1534185')
  const [storeLng, setStoreLng] = useState('80.1714024')

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  // Fetch settings on mount
  useEffect(() => {
    async function loadSettings() {
      try {
        setLoading(true)
        const res = await fetch('/api/settings')
        if (!res.ok) throw new Error('Failed to load settings')
        const data = await res.json()
        
        if (data.deliveries_count) setDeliveriesCount(data.deliveries_count)
        if (data.rating_value) setRatingValue(data.rating_value)
        if (data.happy_families) setHappyFamilies(data.happy_families)
        if (data.trusted_text) setTrustedText(data.trusted_text)
        if (data.grocery_mart_open !== undefined) setGroceryMartOpen(data.grocery_mart_open === 'true')
        if (data.cafe_open !== undefined) setCafeOpen(data.cafe_open === 'true')
        if (data.delivery_radius !== undefined) setDeliveryRadius(data.delivery_radius)
        if (data.cloudinary_cloud_name) setCloudinaryCloudName(data.cloudinary_cloud_name)
        if (data.cloudinary_upload_preset) setCloudinaryUploadPreset(data.cloudinary_upload_preset)
        if (data.store_lat) setStoreLat(data.store_lat)
        if (data.store_lng) setStoreLng(data.store_lng)
      } catch (err: any) {
        console.error(err)
        toast.error('Could not fetch store settings')
      } finally {
        setLoading(false)
      }
    }

    loadSettings()
  }, [])

  // Save settings handler
  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!deliveriesCount.trim() || !ratingValue.trim() || !happyFamilies.trim() || !trustedText.trim() || !deliveryRadius.trim()) {
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
          delivery_radius: deliveryRadius.trim(),
          cloudinary_cloud_name: cloudinaryCloudName.trim(),
          cloudinary_upload_preset: cloudinaryUploadPreset.trim(),
          store_lat: storeLat.trim(),
          store_lng: storeLng.trim(),
        }),
      })

      if (!res.ok) throw new Error('Failed to update settings')
      
      toast.success('Store settings updated successfully!')
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
