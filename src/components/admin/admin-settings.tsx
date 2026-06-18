'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Sliders, Save, Loader2, Eye, Heart, Star, Package, FileText } from 'lucide-react'
import { motion } from 'framer-motion'

interface AdminSettingsProps {
  onSettingsSaved?: () => void
}

export function AdminSettings({ onSettingsSaved }: AdminSettingsProps) {
  const [settingsTab, setSettingsTab] = useState<'ops' | 'cosmetics' | 'finance'>('ops')
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
  const [contactPhone, setContactPhone] = useState('+91 70544 70303')
  const [contactEmail, setContactEmail] = useState('help@fastkirana.com')
  const [contactTimings, setContactTimings] = useState('6 AM - 12 AM')
  const [contactAddress, setContactAddress] = useState('NH34, Ghatampur, Kanpur Nagar')
  
  const [categories, setCategories] = useState<any[]>([])
  const [categoryStatuses, setCategoryStatuses] = useState<Record<string, boolean>>({})
  
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  // Fetch settings on mount
  useEffect(() => {
    async function loadSettings() {
      try {
        setLoading(true)
        
        // Fetch categories first
        const catRes = await fetch('/api/categories')
        if (!catRes.ok) throw new Error('Failed to load categories')
        const cats = await catRes.json()
        setCategories(cats)

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
        if (data.contact_phone) setContactPhone(data.contact_phone)
        if (data.contact_email) setContactEmail(data.contact_email)
        if (data.contact_timings) setContactTimings(data.contact_timings)
        if (data.contact_address) setContactAddress(data.contact_address)

        // Parse category statuses
        const catStatusMap: Record<string, boolean> = {}
        cats.forEach((cat: any) => {
          catStatusMap[cat.slug] = data[`category_open_${cat.slug}`] !== 'false'
        })
        setCategoryStatuses(catStatusMap)
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
    
    if (!deliveriesCount.trim() || !ratingValue.trim() || !happyFamilies.trim() || !trustedText.trim() || !deliveryRadius.trim() || !taxRate.trim() || !miscFee.trim() || !contactPhone.trim() || !contactEmail.trim() || !contactTimings.trim() || !contactAddress.trim()) {
      toast.error('Please fill in all setting fields')
      return
    }

    try {
      setSaving(true)
      const categorySettingsPayload: Record<string, string> = {}
      Object.entries(categoryStatuses).forEach(([slug, isOpen]) => {
        categorySettingsPayload[`category_open_${slug}`] = isOpen ? 'true' : 'false'
      })

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
          contact_phone: contactPhone.trim(),
          contact_email: contactEmail.trim(),
          contact_timings: contactTimings.trim(),
          contact_address: contactAddress.trim(),
          ...categorySettingsPayload,
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
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-border/40 pb-4">
            <div>
              <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
                <Sliders className="h-5 w-5 text-accent" />
                Store Stats & Settings
              </h3>
              <p className="text-xs text-text-secondary mt-0.5">
                Customize operational parameters, storefront branding counters, and financials.
              </p>
            </div>

            {/* Tab switch header */}
            <div className="flex gap-1.5 bg-muted/30 p-1 rounded-xl max-w-max">
              {[
                { id: 'ops', label: '🚚 Operations' },
                { id: 'cosmetics', label: '🎨 Branding' },
                { id: 'finance', label: '🔑 Financials' }
              ].map(t => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setSettingsTab(t.id as any)}
                  className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all cursor-pointer ${
                    settingsTab === t.id
                      ? 'bg-card text-primary shadow-sm border border-border/40'
                      : 'text-text-secondary hover:text-text-primary'
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          <form onSubmit={handleSave} className="space-y-6">
            {settingsTab === 'cosmetics' && (
              <div className="space-y-4 animate-fade-in">
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
                </div>
              </div>
            )}

            {settingsTab === 'ops' && (
              <div className="space-y-4 animate-fade-in">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Grocery Mart Toggle */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Grocery Mart Status</label>
                    <select
                      value={groceryMartOpen ? 'true' : 'false'}
                      onChange={(e) => setGroceryMartOpen(e.target.value === 'true')}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer"
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
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer"
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
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer"
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

                  {/* Contact Phone */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Phone *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. +91 70544 70303"
                      value={contactPhone}
                      onChange={(e) => setContactPhone(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Email */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Email *</label>
                    <input
                      type="email"
                      required
                      placeholder="e.g. help@fastkirana.com"
                      value={contactEmail}
                      onChange={(e) => setContactEmail(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Timings */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Timings *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 6 AM - 12 AM"
                      value={contactTimings}
                      onChange={(e) => setContactTimings(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Address */}
                  <div className="md:col-span-3 space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Address *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. NH34, Ghatampur, Kanpur Nagar"
                      value={contactAddress}
                      onChange={(e) => setContactAddress(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>

                  {/* Category-Wise Statuses Section */}
                  <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                    <h4 className="text-xs font-black text-text-primary mb-3">🏪 Category-Wise Status (Open/Closed)</h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      {categories.map((cat) => (
                        <div key={cat.id} className="space-y-1.5">
                          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                            {cat.name} Status
                          </label>
                          <select
                            value={categoryStatuses[cat.slug] !== false ? 'true' : 'false'}
                            onChange={(e) => {
                              const isOpen = e.target.value === 'true'
                              setCategoryStatuses((prev) => ({
                                ...prev,
                                [cat.slug]: isOpen,
                              }))
                            }}
                            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer"
                          >
                            <option value="true">🟢 Open (Active)</option>
                            <option value="false">🔴 Closed (Temporarily)</option>
                          </select>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {settingsTab === 'finance' && (
              <div className="space-y-4 animate-fade-in">
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
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Miscellaneous Fee (₹) *</label>
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

                {/* Cloudinary Configuration */}
                <div className="border-t border-border/40 pt-4 mt-2">
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
            )}

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
