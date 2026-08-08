'use client'

import { useState, useCallback } from 'react'
import { X, Search } from 'lucide-react'
import { toast } from 'sonner'

interface MediaImage {
  url: string
  name: string
}

interface MediaLibraryModalProps {
  showMediaLibrary: boolean
  filteredMediaImages: MediaImage[]
  mediaSearchQuery: string
  mediaTarget: string | null
  setShowMediaLibrary: (v: boolean) => void
  setMediaSearchQuery: (v: string) => void
  setMediaTarget: (v: any) => void
  onSelectImage: (url: string, target: string) => void
}

export default function MediaLibraryModal({
  showMediaLibrary,
  filteredMediaImages,
  mediaSearchQuery,
  mediaTarget,
  setShowMediaLibrary,
  setMediaSearchQuery,
  setMediaTarget,
  onSelectImage,
}: MediaLibraryModalProps) {
  if (!showMediaLibrary) return null

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setShowMediaLibrary(false)
    }
  }, [setShowMediaLibrary])

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in"
      role="dialog"
      aria-modal="true"
      aria-labelledby="media-library-title"
      onKeyDown={handleKeyDown}
    >
      <div className="bg-card border border-border rounded-3xl shadow-2xl w-full max-w-3xl max-h-[85vh] flex flex-col p-5 space-y-4">
        <div className="flex items-center justify-between border-b border-border pb-3">
          <div className="flex items-center gap-2">
            <span className="text-xl">🖼️</span>
            <div>
              <h3 id="media-library-title" className="font-extrabold text-text-primary text-sm sm:text-base">Media Photo Library</h3>
              <p className="text-[10px] text-text-secondary">Pick any existing photo from past uploads ({filteredMediaImages.length} available)</p>
            </div>
          </div>
          <button onClick={() => setShowMediaLibrary(false)} className="text-text-secondary hover:text-text-primary p-1 cursor-pointer" aria-label="Close media library">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Search filter input */}
        <div className="relative">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
          <input
            type="text"
            placeholder="Search photo by product name or keyword (e.g. dal, biryani, paneer)..."
            value={mediaSearchQuery}
            onChange={(e) => setMediaSearchQuery(e.target.value)}
            aria-label="Search photo library"
            className="w-full bg-muted/20 border border-border pl-10 pr-4 py-2.5 rounded-2xl text-xs focus:outline-none focus:border-primary font-medium"
          />
        </div>

        {/* Photo Grid */}
        <div className="flex-1 overflow-y-auto grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3 p-1 min-h-[250px]">
          {filteredMediaImages.length === 0 ? (
            <div className="col-span-full py-12 text-center text-xs font-bold text-text-muted">
              No matching images found. Try searching another keyword!
            </div>
          ) : (
            filteredMediaImages.map((img, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => {
                  onSelectImage(img.url, mediaTarget ?? '')
                  setShowMediaLibrary(false)
                  toast.success('Image selected from library! 🖼️')
                }}
                className="group relative flex flex-col items-center border border-border/50 rounded-2xl p-2 bg-muted/10 hover:bg-primary/10 hover:border-primary transition-all cursor-pointer text-center"
              >
                <div className="h-16 w-16 relative overflow-hidden rounded-xl bg-white/5 flex items-center justify-center mb-1.5 border border-border/30">
                  <img src={img.url} alt={img.name} className="h-full w-full object-contain group-hover:scale-105 transition-transform" />
                </div>
                <span className="text-[9px] font-bold text-text-secondary truncate w-full group-hover:text-primary">{img.name}</span>
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
