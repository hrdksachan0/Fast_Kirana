'use client'

import { useState, useEffect, useRef } from 'react'
import { toast } from 'sonner'
import { Plus, Trash2, Edit2, ArrowUp, ArrowDown, Save, Loader2, ListCollapse, Upload } from 'lucide-react'
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

interface RestaurantMenuSectionsEditorProps {
  assignedRestaurantId: string
  isCafe: boolean
}

export function RestaurantMenuSectionsEditor({ assignedRestaurantId, isCafe }: RestaurantMenuSectionsEditorProps) {
  const defaultSections = isCafe ? DEFAULT_CAFE_MENU_SECTIONS : DEFAULT_RESTAURANT_MENU_SECTIONS
  const [menuSections, setMenuSections] = useState<CafeMenuSection[]>(defaultSections)
  
  // Section Editing Form States
  const [isAddingNewSec, setIsAddingNewSec] = useState(false)
  const [editingSecIndex, setEditingSecIndex] = useState<number | null>(null)
  const [secTag, setSecTag] = useState('')
  const [secTitle, setSecTitle] = useState('')
  const [secEmoji, setSecEmoji] = useState('')
  const [secDescription, setSecDescription] = useState('')
  const [secMatchTags, setSecMatchTags] = useState('')
  const [secImageUrl, setSecImageUrl] = useState('')
  const [uploadingSecImage, setUploadingSecImage] = useState(false)
  const secFileInputRef = useRef<HTMLInputElement>(null)

  const handleSecImageUpload = async (file: File) => {
    if (!file) return
    setUploadingSecImage(true)
    try {
      const data = new FormData()
      data.append('file', file)
      const res = await fetch('/api/upload', {
        method: 'POST',
        body: data
      })
      if (!res.ok) throw new Error('Upload failed')
      const json = await res.json()
      if (json.url) {
        setSecImageUrl(json.url)
        toast.success('Category icon uploaded successfully!')
      }
    } catch (err) {
      console.error(err)
      toast.error('Failed to upload category image')
    } finally {
      setUploadingSecImage(false)
    }
  }

  const [loading, setLoading] = useState(true)
  const [savingSections, setSavingSections] = useState(false)

  // Fetch restaurant sections on mount
  useEffect(() => {
    async function loadRestaurant() {
      try {
        setLoading(true)
        const res = await fetch(`/api/restaurants/${assignedRestaurantId}`)
        if (!res.ok) throw new Error('Failed to load restaurant data')
        const data = await res.json()
        
        if (data.menuSections) {
          try {
            const parsed = typeof data.menuSections === 'string' ? JSON.parse(data.menuSections) : data.menuSections
            if (Array.isArray(parsed)) {
              setMenuSections(parsed)
            }
          } catch (e) {
            console.error('Failed to parse restaurant menuSections:', e)
          }
        }
      } catch (err: any) {
        console.error(err)
        toast.error('Could not fetch custom menu sections')
      } finally {
        setLoading(false)
      }
    }

    if (assignedRestaurantId) {
      loadRestaurant()
    }
  }, [assignedRestaurantId])

  const handleEditSection = (index: number) => {
    const sec = menuSections[index]
    if (!sec) return
    setEditingSecIndex(index)
    setIsAddingNewSec(false)
    setSecTag(sec.tag)
    setSecTitle(sec.title)
    setSecEmoji(sec.emoji)
    setSecDescription(sec.description || '')
    setSecMatchTags(sec.matchTags?.join(', ') || '')
    setSecImageUrl((sec as any).imageUrl || (sec as any).image || '')
  }

  const handleAddNewSectionClick = () => {
    setIsAddingNewSec(true)
    setEditingSecIndex(null)
    setSecTag('')
    setSecTitle('')
    setSecEmoji('🍽️')
    setSecDescription('')
    setSecMatchTags('')
    setSecImageUrl('')
  }

  const handleCancelSectionEdit = () => {
    setIsAddingNewSec(false)
    setEditingSecIndex(null)
  }

  const handleSaveSectionForm = (e: React.FormEvent) => {
    e.preventDefault()
    if (!secTag || !secTitle) {
      toast.error('Tag and Title are required!')
      return
    }

    const cleanTag = secTag.toLowerCase().replace(/[^a-z0-9-]/g, '').trim()
    const parsedMatchTags = secMatchTags
      .split(',')
      .map(t => t.trim().toLowerCase())
      .filter(Boolean)

    const newSec: CafeMenuSection = {
      tag: cleanTag,
      title: secTitle.trim(),
      emoji: secEmoji.trim() || '🍽️',
      description: secDescription.trim(),
      matchTags: parsedMatchTags.length > 0 ? parsedMatchTags : [cleanTag],
      disabled: false
    }
    if (secImageUrl.trim()) {
      ;(newSec as any).imageUrl = secImageUrl.trim()
    }

    if (isAddingNewSec) {
      // Check for duplicate tags
      if (menuSections.some(s => s.tag === cleanTag)) {
        toast.error(`A section with tag "#${cleanTag}" already exists!`)
        return
      }
      setMenuSections([...menuSections, newSec])
      toast.success(`Category "${secTitle}" added! Click save below to apply.`)
    } else if (editingSecIndex !== null) {
      // Check for duplicate tags elsewhere
      if (menuSections.some((s, idx) => s.tag === cleanTag && idx !== editingSecIndex)) {
        toast.error(`Another section with tag "#${cleanTag}" already exists!`)
        return
      }
      const updated = [...menuSections]
      updated[editingSecIndex] = {
        ...updated[editingSecIndex],
        ...newSec,
        disabled: updated[editingSecIndex].disabled
      }
      setMenuSections(updated)
      toast.success(`Category "${secTitle}" updated! Click save below to apply.`)
    }

    setIsAddingNewSec(false)
    setEditingSecIndex(null)
  }

  const handleDeleteSection = (index: number) => {
    const sec = menuSections[index]
    if (!sec) return
    if (!confirm(`Are you sure you want to delete "${sec.title}"?`)) return
    
    const updated = menuSections.filter((_, idx) => idx !== index)
    setMenuSections(updated)
    toast.success(`Category "${sec.title}" deleted! Click save below to apply.`)
  }

  const handleMoveSection = (index: number, direction: 'up' | 'down') => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1
    if (targetIndex < 0 || targetIndex >= menuSections.length) return
    
    const copy = [...menuSections]
    const temp = copy[index]
    copy[index] = copy[targetIndex]
    copy[targetIndex] = temp
    setMenuSections(copy)
  }

  const handleSaveMenuSections = async () => {
    try {
      setSavingSections(true)
      const res = await fetch(`/api/restaurants/${assignedRestaurantId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ menuSections })
      })

      if (!res.ok) throw new Error('Failed to update sections')
      
      toast.success('Menu categories updated successfully!')
    } catch (err: any) {
      console.error(err)
      toast.error('Failed to save menu categories')
    } finally {
      setSavingSections(false)
    }
  }

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-3">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="text-sm font-extrabold text-zinc-500">Loading custom sections...</p>
      </div>
    )
  }

  return (
    <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-6">
      <div className="flex items-center justify-between border-b border-border/50 pb-3">
        <div>
          <h3 className="text-[16px] font-black text-text-primary flex items-center gap-2">
            <ListCollapse className="h-5 w-5 text-primary" />
            Menu Categories Editor
          </h3>
          <p className="text-[11px] text-text-secondary mt-0.5">
            Create, edit, toggle and reorder your menu categories. Changes will be instantly shown on your storefront.
          </p>
        </div>
        
        {!isAddingNewSec && editingSecIndex === null && (
          <button
            type="button"
            onClick={handleAddNewSectionClick}
            className="flex items-center gap-1.5 px-3 py-2 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-450 border border-emerald-500/20 rounded-xl text-xs font-black transition-all cursor-pointer"
          >
            <Plus className="h-3.5 w-3.5" />
            Add Category
          </button>
        )}
      </div>

      {/* Editor Form */}
      {(isAddingNewSec || editingSecIndex !== null) && (
        <form onSubmit={handleSaveSectionForm} className="p-4 bg-muted/30 border border-border/60 rounded-xl space-y-4 animate-fade-in">
          <h4 className="text-xs font-black text-text-primary uppercase tracking-wider">
            {isAddingNewSec ? 'Create Custom Category' : 'Edit Category Details'}
          </h4>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div className="space-y-1">
              <label className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider block">Category Name *</label>
              <input
                type="text"
                placeholder="e.g. Italian Pasta"
                value={secTitle}
                onChange={(e) => setSecTitle(e.target.value)}
                required
                className="w-full text-xs font-bold bg-background border border-border rounded-lg h-9 px-3 outline-none focus:border-primary"
              />
            </div>
            
            <div className="space-y-1">
              <label className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider block">Unique URL Tag *</label>
              <input
                type="text"
                placeholder="e.g. italian-pasta"
                value={secTag}
                onChange={(e) => setSecTag(e.target.value)}
                required
                disabled={editingSecIndex !== null}
                className="w-full text-xs font-bold bg-background border border-border rounded-lg h-9 px-3 outline-none focus:border-primary disabled:opacity-50"
              />
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider block">Emoji Accent</label>
              <input
                type="text"
                placeholder="e.g. 🍝"
                value={secEmoji}
                onChange={(e) => setSecEmoji(e.target.value)}
                className="w-full text-xs font-bold bg-background border border-border rounded-lg h-9 px-3 outline-none focus:border-primary"
              />
            </div>

            <div className="space-y-1">
              <label className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider block">Category Icon Image</label>
              <div className="flex items-center gap-2">
                <input
                  type="url"
                  placeholder="Paste URL or upload image ->"
                  value={secImageUrl}
                  onChange={(e) => setSecImageUrl(e.target.value)}
                  className="w-full text-xs font-bold bg-background border border-border rounded-lg h-9 px-3 outline-none focus:border-primary"
                />
                <input
                  type="file"
                  ref={secFileInputRef}
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) handleSecImageUpload(file)
                  }}
                />
                <button
                  type="button"
                  disabled={uploadingSecImage}
                  onClick={() => secFileInputRef.current?.click()}
                  className="px-3 py-2 bg-orange-500/10 hover:bg-orange-500/20 text-orange-600 dark:text-orange-400 font-bold text-xs rounded-lg border border-orange-500/30 flex items-center gap-1.5 transition-all cursor-pointer shrink-0"
                >
                  {uploadingSecImage ? (
                    <>
                      <Loader2 className="h-3.5 w-3.5 animate-spin" />
                      <span>Uploading...</span>
                    </>
                  ) : (
                    <>
                      <Upload className="h-3.5 w-3.5" />
                      <span>Upload</span>
                    </>
                  )}
                </button>
              </div>
            </div>

            <div className="sm:col-span-2 space-y-1">
              <label className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider block">Cuisine / Product Tags Match (comma separated)</label>
              <input
                type="text"
                placeholder="e.g. pasta, spaghetti, macaroni, lasagna (leave empty to match URL tag)"
                value={secMatchTags}
                onChange={(e) => setSecMatchTags(e.target.value)}
                className="w-full text-xs font-bold bg-background border border-border rounded-lg h-9 px-3 outline-none focus:border-primary"
              />
            </div>

            <div className="sm:col-span-2 space-y-1">
              <label className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider block">Description / Subtitle</label>
              <input
                type="text"
                placeholder="e.g. Cheesy and freshly baked Italian delicacies"
                value={secDescription}
                onChange={(e) => setSecDescription(e.target.value)}
                className="w-full text-xs font-bold bg-background border border-border rounded-lg h-9 px-3 outline-none focus:border-primary"
              />
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
              className="px-4.5 py-1.5 bg-[#e20a22] hover:bg-[#c9081e] text-white rounded-lg text-xs font-black transition-colors shadow cursor-pointer"
            >
              Apply Changes
            </button>
          </div>
        </form>
      )}

      {/* List of Custom Categories */}
      <div className="space-y-2 max-h-[380px] overflow-y-auto pr-1">
        {menuSections.map((sec, idx) => (
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
                  <span className="text-[9px] font-mono font-bold bg-muted px-1.5 py-0.5 rounded border border-border/40 text-text-secondary">#{sec.tag}</span>
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
                  disabled={idx === menuSections.length - 1}
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
                  const copy = [...menuSections]
                  copy[idx] = {
                    ...copy[idx],
                    disabled: !copy[idx].disabled
                  }
                  setMenuSections(copy)
                  toast.success(
                    copy[idx].disabled
                      ? `"${sec.title}" turned OFF! (Click Save below to apply)`
                      : `"${sec.title}" turned ON! (Click Save below to apply)`
                  )
                }}
                className={`px-2.5 py-1 border rounded-lg text-[9px] font-black tracking-wide transition-all cursor-pointer ${
                  sec.disabled 
                    ? 'border-rose-500/25 bg-rose-500/5 text-rose-500 hover:bg-rose-500/10' 
                    : 'border-emerald-500/25 bg-emerald-500/5 text-emerald-600 hover:bg-emerald-500/10'
                }`}
                title={sec.disabled ? "Turn ON Category" : "Turn OFF Category"}
              >
                {sec.disabled ? 'OFF' : 'ON'}
              </button>

              {/* Edit */}
              <button
                type="button"
                onClick={() => handleEditSection(idx)}
                className="p-1.5 border border-border hover:bg-muted text-text-secondary hover:text-text-primary rounded-lg transition-colors cursor-pointer"
                title="Edit Category"
              >
                <Edit2 className="h-3.5 w-3.5" />
              </button>

              {/* Delete */}
              <button
                type="button"
                onClick={() => handleDeleteSection(idx)}
                className="p-1.5 border border-rose-500/20 bg-rose-500/5 hover:bg-rose-500/10 text-rose-600 rounded-lg transition-colors cursor-pointer"
                title="Delete Category"
              >
                <Trash2 className="h-3.5 w-3.5" />
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Save Button */}
      <div className="pt-4 border-t border-border flex justify-end">
        <button
          type="button"
          onClick={handleSaveMenuSections}
          disabled={savingSections}
          className="px-6 py-2.5 rounded-xl bg-[#e20a22] hover:bg-[#c9081e] text-white font-black text-xs transition-all flex items-center gap-2 shadow-md hover:shadow-lg disabled:opacity-50 cursor-pointer"
        >
          {savingSections ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin text-white" />
              Saving Categories...
            </>
          ) : (
            <>
              <Save className="h-4 w-4" />
              Save Menu Categories
            </>
          )}
        </button>
      </div>
    </div>
  )
}
