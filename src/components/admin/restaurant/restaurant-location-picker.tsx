'use client'

import React from 'react'
import { MapPin, Globe, ExternalLink, Navigation, Check } from 'lucide-react'
import { toast } from 'sonner'

interface RestaurantLocationPickerProps {
  formData: any
  setFormData: React.Dispatch<React.SetStateAction<any>>
  handleChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => void
  darkStores: any[]
  selectedStoreHubId: string
  setSelectedStoreHubId: (id: string) => void
  pasteInput: string
  setPasteInput: (val: string) => void
  handleExtractFromGoogleMaps: (rawText: string) => void
  mapType: 'm' | 'k'
  setMapType: (type: 'm' | 'k') => void
  mapZoom: number
  setMapZoom: React.Dispatch<React.SetStateAction<number>>
}

const inputClass = "w-full px-3.5 py-2.5 text-sm font-semibold bg-background border border-border rounded-xl outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all placeholder:text-text-secondary/40"

export function RestaurantLocationPicker({
  formData,
  setFormData,
  handleChange,
  darkStores,
  selectedStoreHubId,
  setSelectedStoreHubId,
  pasteInput,
  setPasteInput,
  handleExtractFromGoogleMaps,
  mapType,
  setMapType,
  mapZoom,
  setMapZoom,
}: RestaurantLocationPickerProps) {
  return (
    <div id="sec-location" className="bg-card border border-border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300">
      <div className="p-4 border-b border-border/60 bg-gradient-to-r from-blue-500/10 via-blue-500/5 to-blue-500/0 flex items-center gap-3">
        <div className="h-9 w-9 rounded-xl bg-white/80 dark:bg-white/10 backdrop-blur-sm flex items-center justify-center shadow-sm">
          <MapPin className="h-4.5 w-4.5 text-text-primary" />
        </div>
        <div>
          <h2 className="font-black text-sm text-text-primary tracking-wide">Location & Contact</h2>
          <p className="text-[10px] text-text-secondary font-medium">Address, map coordinates and outlet location</p>
        </div>
      </div>
      <div className="p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div className="md:col-span-2 space-y-1.5">
            <label htmlFor="address" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Full Address
            </label>
            <input
              id="address"
              name="address"
              value={formData.address}
              onChange={handleChange}
              placeholder="e.g. 123 Main St, Near Market, Lucknow"
              className={inputClass}
            />
          </div>

          <div className="space-y-1.5">
            <label htmlFor="storeHub" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              Dark Store Hub / Territory
            </label>
            <select
              id="storeHub"
              value={selectedStoreHubId}
              onChange={(e) => {
                const sId = e.target.value
                setSelectedStoreHubId(sId)
                const st = darkStores.find((s: any) => s.id === sId)
                if (st) {
                  const clean = st.name.replace(/\s*(central\s*hub|dark\s*store|hub|store)\s*/gi, '').trim()
                  setFormData((prev: any) => ({ ...prev, city: clean }))
                }
              }}
              className={inputClass}
            >
              <option value="">-- Select Associated Dark Store Hub --</option>
              {darkStores.map((st: any) => (
                <option key={st.id} value={st.id}>
                  🏢 {st.name} ({st.id})
                </option>
              ))}
            </select>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="city" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
              City
            </label>
            <input
              id="city"
              name="city"
              value={formData.city}
              onChange={handleChange}
              placeholder="e.g. Akbarpur / Ghatampur"
              className={inputClass}
            />
          </div>

          {/* Google Maps Link / Coordinates Quick Paste Helper */}
          <div className="md:col-span-2 bg-blue-50/70 dark:bg-blue-950/30 border border-blue-200/80 dark:border-blue-800/40 rounded-2xl p-4 space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-blue-700 dark:text-blue-300 flex items-center gap-1.5">
                <Globe className="h-4 w-4 text-blue-600" />
                Paste Google Maps Link / Coordinates
              </span>
              <a
                href="https://www.google.com/maps"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[11px] font-bold text-blue-600 hover:text-blue-700 hover:underline flex items-center gap-1"
              >
                Open Google Maps <ExternalLink className="h-3 w-3" />
              </a>
            </div>
            <div className="flex items-center gap-2">
              <input
                type="text"
                placeholder="Paste Google Maps link (maps.app.goo.gl/...) or coordinates (e.g. 26.1558, 80.1685)"
                value={pasteInput}
                onChange={(e) => setPasteInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    handleExtractFromGoogleMaps(pasteInput)
                  }
                }}
                className="flex-1 px-3.5 py-2.5 text-xs bg-background border border-border rounded-xl font-medium outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/10 transition-all placeholder:text-text-secondary/40"
              />
              <button
                type="button"
                onClick={() => handleExtractFromGoogleMaps(pasteInput)}
                className="px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-xs font-black transition-all shrink-0 cursor-pointer shadow-sm active:scale-95 flex items-center gap-1.5"
              >
                <Check className="h-3.5 w-3.5" />
                Auto-Extract
              </button>
            </div>
            <p className="text-[10px] text-text-secondary/80 font-medium">
              💡 <strong>Google Maps Tip:</strong> Google Maps app mein dukaan par long press karke <em>Share Link</em> ya coordinates copy karein aur yahan paste karke Auto-Extract dabayein.
            </p>
          </div>

          {/* Manual Latitude / Longitude & GPS Auto Fetch */}
          <div className="md:col-span-2 space-y-2">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary">
                Map Coordinates (GPS)
              </label>
              <button
                type="button"
                onClick={() => {
                  if (navigator.geolocation) {
                    toast.loading('Fetching current GPS coordinates...')
                    navigator.geolocation.getCurrentPosition(
                      (pos) => {
                        toast.dismiss()
                        setFormData((prev: any) => ({
                          ...prev,
                          lat: pos.coords.latitude.toFixed(6),
                          lng: pos.coords.longitude.toFixed(6)
                        }))
                        toast.success('GPS coordinates auto-filled! 📍')
                      },
                      () => {
                        toast.dismiss()
                        toast.error('Location permission denied or unavailable.')
                      }
                    )
                  } else {
                    toast.error('Geolocation is not supported by your browser')
                  }
                }}
                className="flex items-center gap-1.5 px-3 py-1 bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20 rounded-lg text-[10px] font-black hover:bg-blue-500/20 transition-all cursor-pointer shadow-2xs active:scale-95"
              >
                <Navigation className="h-3 w-3" />
                Auto-fill Live Device GPS
              </button>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <label htmlFor="lat" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                  Latitude
                </label>
                <input
                  id="lat"
                  name="lat"
                  type="number"
                  step="any"
                  value={formData.lat}
                  onChange={handleChange}
                  placeholder="Latitude e.g. 26.1558"
                  className={inputClass}
                />
              </div>
              <div className="space-y-1.5">
                <label htmlFor="lng" className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                  Longitude
                </label>
                <input
                  id="lng"
                  name="lng"
                  type="number"
                  step="any"
                  value={formData.lng}
                  onChange={handleChange}
                  placeholder="Longitude e.g. 80.1685"
                  className={inputClass}
                />
              </div>
            </div>
          </div>

          {/* Dedicated Google Maps Preview */}
          <div className="md:col-span-2 space-y-2">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <label className="text-[11px] font-bold uppercase tracking-wider text-text-secondary block">
                  📍 Google Maps Preview
                </label>
                {formData.lat && formData.lng && (
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
                    {formData.lat}, {formData.lng}
                  </span>
                )}
              </div>
              <div className="flex items-center gap-2">
                {/* Map Type Switcher */}
                <div className="flex items-center bg-muted p-0.5 rounded-lg border border-border">
                  <button
                    type="button"
                    onClick={() => setMapType('m')}
                    className={`px-2.5 py-1 text-[10px] font-bold rounded-md transition-all cursor-pointer ${
                      mapType === 'm' ? 'bg-background shadow-xs text-text-primary' : 'text-text-secondary hover:text-text-primary'
                    }`}
                  >
                    🗺️ Map
                  </button>
                  <button
                    type="button"
                    onClick={() => setMapType('k')}
                    className={`px-2.5 py-1 text-[10px] font-bold rounded-md transition-all cursor-pointer ${
                      mapType === 'k' ? 'bg-background shadow-xs text-text-primary' : 'text-text-secondary hover:text-text-primary'
                    }`}
                  >
                    🛰️ Satellite
                  </button>
                </div>

                {/* Zoom Controls */}
                <div className="flex items-center bg-muted p-0.5 rounded-lg border border-border">
                  <button
                    type="button"
                    onClick={() => setMapZoom(z => Math.max(12, z - 1))}
                    className="px-2 py-0.5 text-xs font-bold text-text-secondary hover:text-text-primary cursor-pointer"
                    title="Zoom Out"
                  >
                    -
                  </button>
                  <span className="text-[10px] font-bold px-1.5 text-text-secondary">{mapZoom}z</span>
                  <button
                    type="button"
                    onClick={() => setMapZoom(z => Math.min(21, z + 1))}
                    className="px-2 py-0.5 text-xs font-bold text-text-secondary hover:text-text-primary cursor-pointer"
                    title="Zoom In"
                  >
                    +
                  </button>
                </div>

                {formData.lat && formData.lng && (
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${formData.lat},${formData.lng}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-1 text-[10px] font-bold text-blue-600 hover:text-blue-700 bg-blue-50 dark:bg-blue-950/40 px-2.5 py-1 rounded-lg border border-blue-200 dark:border-blue-800 transition-colors"
                  >
                    <ExternalLink className="h-3 w-3" />
                    Open in Google Maps App
                  </a>
                )}
              </div>
            </div>

            <div className="h-72 w-full rounded-2xl border border-border overflow-hidden bg-muted/20 relative shadow-inner">
              {formData.lat && formData.lng ? (
                <iframe
                  key={`gmap-${formData.lat}-${formData.lng}-${mapType}-${mapZoom}`}
                  src={`https://maps.google.com/maps?q=${formData.lat},${formData.lng}&hl=en&z=${mapZoom}&t=${mapType}&output=embed`}
                  width="100%"
                  height="100%"
                  style={{ border: 0 }}
                  allowFullScreen
                  loading="lazy"
                  referrerPolicy="no-referrer-when-downgrade"
                  className="rounded-2xl w-full h-full"
                />
              ) : (
                <div className="absolute inset-0 flex flex-col items-center justify-center text-text-secondary/50 p-6 text-center">
                  <MapPin className="h-10 w-10 mb-2 text-rose-500/60 animate-bounce" />
                  <p className="text-xs font-bold text-text-primary">Enter or Paste Coordinates above</p>
                  <p className="text-[10px] text-text-secondary mt-1">Google Maps preview with Satellite View will appear here</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
