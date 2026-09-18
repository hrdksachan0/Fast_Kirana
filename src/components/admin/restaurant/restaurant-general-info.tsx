'use client'

import React, { useRef } from 'react'
import { Store, Image as ImageIcon, Star, X, Plus, Upload, Loader2, Eye, Leaf, Clock } from 'lucide-react'

interface RestaurantGeneralInfoProps {
  formData: any
  setFormData: React.Dispatch<React.SetStateAction<any>>
  handleChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => void
  tagInput: string
  setTagInput: (val: string) => void
  handleAddTag: () => void
  handleRemoveTag: (tag: string) => void
  handleTagKeyDown: (e: React.KeyboardEvent<HTMLInputElement>) => void
  handleFileUpload: (file: File, field: 'logoUrl' | 'bannerUrl') => Promise<void>
  uploadingLogo: boolean
  uploadingBanner: boolean
}

const inputClass = "w-full px-3.5 py-2.5 text-sm font-semibold bg-background border border-border rounded-xl outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all placeholder:text-text-secondary/40"

export function RestaurantGeneralInfo({
  formData,
  setFormData,
  handleChange,
  tagInput,
  setTagInput,
  handleAddTag,
  handleRemoveTag,
  handleTagKeyDown,
  handleFileUpload,
  uploadingLogo,
  uploadingBanner,
}: RestaurantGeneralInfoProps) {
  const logoFileInputRef = useRef<HTMLInputElement>(null)
  const bannerFileInputRef = useRef<HTMLInputElement>(null)
  const tagInputRef = useRef<HTMLInputElement>(null)

  return (
    <div className="space-y-6">
      {/* 1. BASIC INFORMATION */}
      <div id="sec-profile" className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
        <div className="p-4 border-b border-border/60 bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-emerald-500/0 flex items-center gap-3">
          <div className="h-9 w-9 rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm flex items-center justify-center shadow-sm">
            <Store className="h-4.5 w-4.5 text-text-primary" />
          </div>
          <div>
            <h2 className="font-black text-sm text-text-primary tracking-wide">Basic Information</h2>
            <p className="text-[10px] text-text-secondary font-medium">Restaurant identity and core details</p>
          </div>
        </div>
        <div className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div className="space-y-1.5">
              <label htmlFor="name" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Restaurant Name <span className="text-rose-500">*</span>
              </label>
              <input
                id="name"
                name="name"
                value={formData.name}
                onChange={handleChange}
                required
                placeholder="e.g. Wedson Restaurant"
                className={inputClass}
              />
            </div>

            <div className="space-y-1.5">
              <label htmlFor="slug" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                URL Slug <span className="text-rose-500">*</span>
              </label>
              <input
                id="slug"
                name="slug"
                value={formData.slug}
                onChange={handleChange}
                required
                placeholder="wedson-restaurant"
                className={`${inputClass} font-mono text-xs`}
              />
            </div>

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
                      onClick={() => setFormData((prev: any) => ({ ...prev, rating: star }))}
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
        </div>
      </div>

      {/* 2. IMAGES & BRANDING */}
      <div id="sec-branding" className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
        <div className="p-4 border-b border-border/60 bg-gradient-to-r from-violet-500/10 via-violet-500/5 to-violet-500/0 flex items-center gap-3">
          <div className="h-9 w-9 rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm flex items-center justify-center shadow-sm">
            <ImageIcon className="h-4.5 w-4.5 text-text-primary" />
          </div>
          <div>
            <h2 className="font-black text-sm text-text-primary tracking-wide">Images & Branding</h2>
            <p className="text-[10px] text-text-secondary font-medium">Logo, banner and visual identity</p>
          </div>
        </div>
        <div className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Logo */}
            <div className="space-y-3">
              <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                Restaurant Logo
              </label>
              <div className="flex items-start gap-4">
                <input
                  ref={logoFileInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) handleFileUpload(file, 'logoUrl')
                  }}
                />
                <div 
                  onClick={() => logoFileInputRef.current?.click()}
                  className="h-24 w-24 rounded-2xl border-2 border-dashed border-primary/40 hover:border-primary bg-muted/20 flex items-center justify-center overflow-hidden shrink-0 relative group cursor-pointer transition-all shadow-xs"
                >
                  {formData.logoUrl ? (
                    <>
                      <img
                        src={formData.logoUrl}
                        alt="Logo preview"
                        className="w-full h-full object-cover"
                        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
                      />
                      <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center text-white">
                        <Upload className="h-5 w-5" />
                        <span className="text-[8px] font-bold mt-1">CHANGE</span>
                      </div>
                    </>
                  ) : (
                    <div className="text-center p-2">
                      <Upload className="h-6 w-6 text-primary mx-auto" />
                      <span className="text-[9px] text-primary font-black block mt-1">UPLOAD LOGO</span>
                    </div>
                  )}
                  {uploadingLogo && (
                    <div className="absolute inset-0 bg-black/60 flex items-center justify-center text-white">
                      <Loader2 className="h-5 w-5 animate-spin" />
                    </div>
                  )}
                </div>
                <div className="flex-1 space-y-2">
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => logoFileInputRef.current?.click()}
                      disabled={uploadingLogo}
                      className="px-3.5 py-2 text-xs font-black bg-primary text-white hover:bg-primary/90 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer shadow-xs"
                    >
                      <Upload className="h-3.5 w-3.5" />
                      {uploadingLogo ? 'Uploading...' : 'Upload Logo File'}
                    </button>
                  </div>
                  <input
                    id="logoUrl"
                    name="logoUrl"
                    value={formData.logoUrl}
                    onChange={handleChange}
                    placeholder="Or paste logo image URL..."
                    className={inputClass}
                  />
                  <div className="flex flex-wrap items-center gap-1.5">
                    <span className="text-[9px] text-text-secondary font-bold">Quick Presets:</span>
                    <button
                      type="button"
                      onClick={() => setFormData((prev: any) => ({ ...prev, logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80' }))}
                      className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                    >
                      Dining Logo
                    </button>
                    <button
                      type="button"
                      onClick={() => setFormData((prev: any) => ({ ...prev, logoUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80' }))}
                      className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                    >
                      Cafe Logo
                    </button>
                    {formData.logoUrl && (
                      <button
                        type="button"
                        onClick={() => setFormData((prev: any) => ({ ...prev, logoUrl: '' }))}
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
                <input
                  ref={bannerFileInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) handleFileUpload(file, 'bannerUrl')
                  }}
                />
                <div 
                  onClick={() => bannerFileInputRef.current?.click()}
                  className="h-32 w-full rounded-2xl border-2 border-dashed border-primary/40 hover:border-primary bg-muted/20 flex items-center justify-center overflow-hidden relative group cursor-pointer transition-all shadow-xs"
                >
                  {formData.bannerUrl ? (
                    <>
                      <img
                        src={formData.bannerUrl}
                        alt="Banner preview"
                        className="w-full h-full object-cover"
                        onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
                      />
                      <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center text-white">
                        <Upload className="h-6 w-6" />
                        <span className="text-[9px] font-bold mt-1">CHANGE COVER BANNER</span>
                      </div>
                    </>
                  ) : (
                    <div className="text-center p-3">
                      <Upload className="h-7 w-7 text-primary mx-auto" />
                      <span className="text-[10px] text-primary font-black block mt-1">UPLOAD COVER BANNER</span>
                    </div>
                  )}
                  {uploadingBanner && (
                    <div className="absolute inset-0 bg-black/60 flex items-center justify-center text-white">
                      <Loader2 className="h-6 w-6 animate-spin" />
                    </div>
                  )}
                </div>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => bannerFileInputRef.current?.click()}
                    disabled={uploadingBanner}
                    className="px-3.5 py-2 text-xs font-black bg-primary text-white hover:bg-primary/90 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer shadow-xs"
                  >
                    <Upload className="h-3.5 w-3.5" />
                    {uploadingBanner ? 'Uploading...' : 'Upload Banner File'}
                  </button>
                </div>
                <input
                  id="bannerUrl"
                  name="bannerUrl"
                  value={formData.bannerUrl}
                  onChange={handleChange}
                  placeholder="Or paste banner image URL..."
                  className={inputClass}
                />
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="text-[9px] text-text-secondary font-bold">Quick Presets:</span>
                  <button
                    type="button"
                    onClick={() => setFormData((prev: any) => ({ ...prev, bannerUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80' }))}
                    className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                  >
                    🥘 North Indian Feast
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormData((prev: any) => ({ ...prev, bannerUrl: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?auto=format&fit=crop&w=1200&q=80' }))}
                    className="px-2 py-0.5 text-[9px] font-bold bg-muted hover:bg-muted/80 rounded border border-border cursor-pointer"
                  >
                    🍔 Fast Food & Burgers
                  </button>
                  {formData.bannerUrl && (
                    <button
                      type="button"
                      onClick={() => setFormData((prev: any) => ({ ...prev, bannerUrl: '' }))}
                      className="px-2 py-0.5 text-[9px] font-bold bg-rose-500/10 text-rose-600 hover:bg-rose-500/20 rounded border border-rose-500/20 cursor-pointer ml-auto"
                    >
                      Clear
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Live Interactive Banner Preview */}
          <div className="mt-6 pt-5 border-t border-border/40 space-y-3">
            <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
              <span>📱 Live Storefront Banner Preview</span>
              <span className="text-[9px] font-mono font-bold px-2 py-0.5 bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 rounded-full">REALTIME</span>
            </label>
            <div className="relative w-full h-[180px] sm:h-[220px] rounded-3xl overflow-hidden border border-border shadow-md">
              {formData.bannerUrl ? (
                <img
                  src={formData.bannerUrl}
                  alt="Banner"
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-orange-500 via-red-500 to-pink-500" />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/40 to-transparent" />
              <div className="absolute bottom-0 left-0 right-0 p-4">
                <div className="flex items-end gap-3">
                  {formData.logoUrl ? (
                    <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-2xl border-2 border-white/40 overflow-hidden flex-shrink-0 bg-white shadow-md">
                      <img src={formData.logoUrl} alt="Logo" className="object-cover w-full h-full" />
                    </div>
                  ) : (
                    <div className="w-14 h-14 sm:w-16 sm:h-16 rounded-2xl border-2 border-white/40 overflow-hidden flex-shrink-0 bg-white/20 backdrop-blur-md flex items-center justify-center text-white text-2xl font-black">
                      🍽️
                    </div>
                  )}
                  <div className="flex-1 min-w-0">
                    <h2 className="text-base sm:text-lg font-black text-white drop-shadow-md truncate">
                      {formData.name || 'Your Restaurant Name'}
                    </h2>
                    <div className="flex flex-wrap items-center gap-1.5 mt-1">
                      {formData.cuisineTags.length > 0 ? (
                        formData.cuisineTags.slice(0, 3).map((tag: string) => (
                          <span key={tag} className="text-[9px] font-bold uppercase tracking-wider text-white/90 bg-white/20 backdrop-blur-xs px-2 py-0.5 rounded-full">
                            {tag}
                          </span>
                        ))
                      ) : (
                        <span className="text-[9px] font-bold uppercase text-white/70 bg-white/10 px-2 py-0.5 rounded-full">
                          Multi-Cuisine
                        </span>
                      )}
                    </div>
                    {formData.isPureVeg && (
                      <div className="flex items-center gap-1 mt-1">
                        <span className="text-[10px] font-black text-emerald-400 bg-emerald-950/60 px-2 py-0.5 rounded-md border border-emerald-500/30">
                          🌱 100% Pure Veg
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
              {formData.discountOffer && (
                <div className="absolute top-3 right-3 bg-blue-600 text-white px-2.5 py-1 rounded-xl shadow-lg border border-blue-400/30">
                  <span className="text-[10px] font-black">{formData.discountOffer}</span>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
