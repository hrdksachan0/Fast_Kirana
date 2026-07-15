'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Coffee, ChefHat, Plus, Trash2, Edit2, ArrowUp, ArrowDown, Save, Loader2 } from 'lucide-react'
import { DEFAULT_CAFE_MENU_SECTIONS, DEFAULT_RESTAURANT_MENU_SECTIONS, CafeMenuSection } from '@/lib/constants'
import Image from 'next/image'

const getCafeSectionImage = (tag: string) => {
  const mapping: Record<string, string> = {
    'hot-beverage': '/cafe_brews_category.png',
    'hot-bite': '/cafe_snacks_category.png',
    'sandwiches': '/cafe_sandwiches_category.png',
    'frankie-rolls': '/cafe_rolls_category.png',
    'chinese': '/cafe_chinese_category.png',
    'italian-pasta': '/cafe_pasta_category.png',
    'bombay-bites': '/cafe_bombay_bites_category.png',
    'rice-dishes': '/cafe_rice_category.png',
    'shakes': '/cafe_shakes_category.png',
    'mocktails': '/cafe_mocktails_category.png',
    'cold-coffee': '/cafe_coffee_category.png',
    'south-indian': '/cafe_south_indian_category.png',
    'chilled': '/cafe_cold_drinks_category.png',
    'beverages': '/cafe_cold_drinks_category.png',
    'drinks': '/cafe_cold_drinks_category.png',
    'bakery': '/bakery_biscuits_category.png',
    'pizza': '/cafe_pizza_category.png',
    'burgers': '/cafe_burgers_category.png',
    'garlic-bread': '/cafe_garlic_bread_category.png',
    'desserts': '/ice_cream_category.png',
  }
  return mapping[tag] || null
}

interface AdminCafeSectionsProps {
  onSectionsSaved?: () => void
  type?: 'cafe' | 'restaurant'
}

export function AdminCafeSections({ onSectionsSaved, type = 'cafe' }: AdminCafeSectionsProps) {
  const isRestaurant = type === 'restaurant'
  const defaultSections = isRestaurant ? DEFAULT_RESTAURANT_MENU_SECTIONS : DEFAULT_CAFE_MENU_SECTIONS
  const [cafeMenuSections, setCafeMenuSections] = useState<CafeMenuSection[]>(defaultSections)
  
  // Section Editing Form States
  const [isAddingNewSec, setIsAddingNewSec] = useState(false)
  const [editingSecIndex, setEditingSecIndex] = useState<number | null>(null)
  const [secTag, setSecTag] = useState('')
  const [secTitle, setSecTitle] = useState('')
  const [secEmoji, setSecEmoji] = useState('')
  const [secDescription, setSecDescription] = useState('')
  const [secMatchTags, setSecMatchTags] = useState('')
  const [secImageUrl, setSecImageUrl] = useState('')
  const [secDisabled, setSecDisabled] = useState(false)

  const [loading, setLoading] = useState(true)
  const [savingSections, setSavingSections] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [settingsMap, setSettingsMap] = useState<Record<string, string>>({})

  // Fetch settings on mount
  useEffect(() => {
    async function loadSettings() {
      try {
        setLoading(true)
        const res = await fetch('/api/settings', { cache: 'no-store' })
        if (!res.ok) throw new Error('Failed to load settings')
        const data = await res.json()
        setSettingsMap(data)
        
        const settingKey = isRestaurant ? 'restaurant_menu_sections' : 'cafe_menu_sections'
        if (data[settingKey]) {
          try {
            const parsed = JSON.parse(data[settingKey])
            if (Array.isArray(parsed)) {
              setCafeMenuSections(parsed)
            }
          } catch (e) {
            console.error(`Failed to parse ${settingKey} setting:`, e)
          }
        }
      } catch (err: any) {
        console.error(err)
        toast.error(isRestaurant ? 'Could not fetch restaurant sections' : 'Could not fetch café sections')
      } finally {
        setLoading(false)
      }
    }

    loadSettings()
  }, [isRestaurant])

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
    setSecImageUrl(sec.imageUrl || sec.image || '')
    setSecDisabled(!!sec.disabled)
  }

  const handleAddNewSectionClick = () => {
    setIsAddingNewSec(true)
    setEditingSecIndex(null)
    setSecTag('')
    setSecTitle('')
    setSecEmoji('')
    setSecDescription('')
    setSecMatchTags('')
    setSecImageUrl('')
    setSecDisabled(false)
  }

  const handleCancelSectionEdit = () => {
    setIsAddingNewSec(false)
    setEditingSecIndex(null)
    setSecTag('')
    setSecTitle('')
    setSecEmoji('')
    setSecDescription('')
    setSecMatchTags('')
    setSecImageUrl('')
    setSecDisabled(false)
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
      matchTags: cleanMatchTags,
      imageUrl: secImageUrl.trim() || undefined,
      image: secImageUrl.trim() || undefined,
      disabled: secDisabled
    }

    if (isAddingNewSec) {
      if (cafeMenuSections.some(s => s.tag === cleanTag)) {
        toast.error('A section with this tag slug already exists')
        return
      }
      setCafeMenuSections([...cafeMenuSections, updatedSec])
      toast.success(isRestaurant ? 'Section added! (Click Save Restaurant Sections below to apply permanently)' : 'Section added! (Click Save Café Sections below to apply permanently)')
    } else if (editingSecIndex !== null) {
      const copy = [...cafeMenuSections]
      copy[editingSecIndex] = updatedSec
      setCafeMenuSections(copy)
      toast.success(isRestaurant ? 'Section updated! (Click Save Restaurant Sections below to apply permanently)' : 'Section updated! (Click Save Café Sections below to apply permanently)')
    }

    handleCancelSectionEdit()
  }

  const handleDeleteSection = (index: number) => {
    if (!confirm('Are you sure you want to delete this menu section? Products in this section will fall back to "More Specials".')) return
    const copy = [...cafeMenuSections]
    copy.splice(index, 1)
    setCafeMenuSections(copy)
    toast.success(isRestaurant ? 'Section deleted! (Click Save Restaurant Sections below to apply permanently)' : 'Section deleted! (Click Save Café Sections below to apply permanently)')
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

  const handleSaveMenuSections = async () => {
    try {
      setSavingSections(true)
      const settingKey = isRestaurant ? 'restaurant_menu_sections' : 'cafe_menu_sections'
      const res = await fetch('/api/admin/settings', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          [settingKey]: JSON.stringify(cafeMenuSections),
        }),
      })

      if (!res.ok) throw new Error(isRestaurant ? 'Failed to update restaurant menu sections' : 'Failed to update café menu sections')
      
      toast.success(isRestaurant ? 'Restaurant menu sections saved successfully!' : 'Café menu sections saved successfully!')
      if (onSectionsSaved) onSectionsSaved()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || (isRestaurant ? 'Error saving restaurant menu sections' : 'Error saving café menu sections'))
    } finally {
      setSavingSections(false)
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
    <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
            {isRestaurant ? (
              <ChefHat className="h-5 w-5 text-accent" />
            ) : (
              <Coffee className="h-5 w-5 text-accent" />
            )}
            {isRestaurant ? 'Restaurant Menu Sections Editor' : 'Café Menu Sections Editor'}
          </h3>
          <p className="text-xs text-text-secondary mt-0.5 font-medium">
            Manage the sections shown on the {isRestaurant ? 'Restaurant' : 'Café'} page storefront. Reorder, add, edit, or delete them.
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
            {isAddingNewSec 
              ? `✨ Add New ${isRestaurant ? 'Restaurant' : 'Café'} Menu Section` 
              : `📝 Edit ${isRestaurant ? 'Restaurant' : 'Café'} Menu Section`}
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

            {/* Status (ON/OFF) */}
            <div className="space-y-1">
              <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Section Status</label>
              <button
                type="button"
                onClick={() => setSecDisabled(!secDisabled)}
                className={`w-full bg-background border px-3 py-1.5 rounded-lg text-xs font-bold transition-all focus:outline-none h-[30px] flex items-center justify-center cursor-pointer ${
                  secDisabled 
                    ? 'border-rose-500/30 bg-rose-500/5 text-rose-600 font-extrabold' 
                    : 'border-emerald-500/30 bg-emerald-500/5 text-emerald-600 font-extrabold'
                }`}
              >
                {secDisabled ? '🔴 DISABLED (OFF)' : '🟢 ENABLED (ON)'}
              </button>
            </div>

            {/* Section Image / Icon */}
            <div className="md:col-span-3 space-y-1">
              <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary block">Section Image (Cloudinary / absolute link)</label>
              <div className="flex gap-2 items-center">
                <input
                  type="text"
                  placeholder="e.g. /cafe_brews_category.png or upload an image"
                  value={secImageUrl}
                  onChange={(e) => setSecImageUrl(e.target.value)}
                  className="flex-1 bg-background border border-border px-3 py-1.5 rounded-lg text-xs focus:outline-none focus:border-primary font-semibold"
                />
                <label
                  htmlFor="section-image-file-upload"
                  className="cursor-pointer px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-bold rounded-lg border border-primary/20 transition-all flex items-center gap-1.5 shrink-0 select-none"
                >
                  {isUploading ? <Loader2 className="h-3 w-3 animate-spin animate-spin-fast" /> : 'Upload Photo'}
                </label>
                <input
                  id="section-image-file-upload"
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const file = e.target.files?.[0]
                    if (file) {
                      const cloudName = settingsMap['cloudinary_cloud_name']
                      const uploadPreset = settingsMap['cloudinary_upload_preset']
                      if (!cloudName || !uploadPreset) {
                        toast.error('Cloudinary credentials missing. Please set them in settings.')
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
                        const resData = await res.json()
                        if (res.ok && resData.secure_url) {
                          setSecImageUrl(resData.secure_url)
                          toast.success('Uploaded to Cloudinary successfully!')
                        } else {
                          toast.error(`Upload failed: ${resData.error?.message || 'Check credentials'}`)
                        }
                      } catch (err) {
                        console.error(err)
                        toast.error('Cloudinary upload error')
                      } finally {
                        setIsUploading(false)
                      }
                    }
                    e.target.value = ''
                  }}
                  className="sr-only"
                  disabled={isUploading}
                />
              </div>
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-border/40">
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
            className={`p-3 border rounded-xl flex items-center justify-between gap-3 transition-opacity ${
              sec.disabled 
                ? 'border-rose-500/20 bg-rose-500/5 opacity-60' 
                : 'border-border bg-muted/10'
            }`}
          >
            <div className="flex items-center gap-3 min-w-0">
              <div className="h-10 w-10 rounded-lg overflow-hidden flex items-center justify-center bg-background border shrink-0 relative">
                {(() => {
                  const image = (sec as any).imageUrl || (sec as any).image || getCafeSectionImage(sec.tag)
                  return image ? (
                    <Image
                      src={image}
                      alt={sec.title}
                      fill
                      sizes="40px"
                      className="object-cover"
                    />
                  ) : (
                    <span className="text-2xl leading-none select-none">{sec.emoji}</span>
                  )
                })()}
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <strong className="text-xs text-text-primary font-extrabold">{sec.title}</strong>
                  <span className="text-[9px] font-mono font-bold bg-muted px-1.5 py-0.5 rounded border border-border/40">#{sec.tag}</span>
                  {sec.disabled && (
                    <span className="text-[8px] font-black uppercase bg-rose-500/10 text-rose-600 px-1.5 py-0.5 rounded border border-rose-500/20 animate-pulse">OFF</span>
                  )}
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

              {/* ON/OFF Switch */}
              <button
                type="button"
                onClick={() => {
                  const copy = [...cafeMenuSections]
                  copy[idx] = {
                    ...copy[idx],
                    disabled: !copy[idx].disabled
                  }
                  setCafeMenuSections(copy)
                  toast.success(
                    copy[idx].disabled
                      ? `"${sec.title}" turned OFF! (Click Save at bottom to apply)`
                      : `"${sec.title}" turned ON! (Click Save at bottom to apply)`
                  )
                }}
                className={`px-2.5 py-1 border rounded-lg text-[9px] font-black tracking-wide transition-all cursor-pointer ${
                  sec.disabled 
                    ? 'border-rose-500/25 bg-rose-500/5 text-rose-500 hover:bg-rose-500/10' 
                    : 'border-emerald-500/25 bg-emerald-500/5 text-emerald-600 hover:bg-emerald-500/10'
                }`}
                title={sec.disabled ? "Turn ON Section" : "Turn OFF Section"}
              >
                {sec.disabled ? 'OFF' : 'ON'}
              </button>

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
                className="p-1.5 border border-rose-500/20 bg-rose-500/5 hover:bg-rose-500/10 text-rose-600 rounded-lg transition-colors cursor-pointer"
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
              <Loader2 className="h-4 w-4 animate-spin text-white" />
              Saving Sections...
            </>
          ) : (
            <>
              <Save className="h-4 w-4" />
              {isRestaurant ? 'Save Restaurant Sections' : 'Save Café Sections'}
            </>
          )}
        </button>
      </div>
    </div>
  )
}
