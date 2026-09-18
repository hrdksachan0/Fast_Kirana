import { MapPin, Plus, Loader2, Home, Building2, Navigation, Check, Edit2, ChevronDown, ChevronUp } from 'lucide-react'
import { Address } from '@/types'
import { cn, formatAddress, formatPhone } from '@/lib/utils'
import { getDistanceKm } from '@/lib/distance'
import { CheckoutAddressForm } from './checkout-address-form'
import { AddressFormData } from '@/hooks/checkout/use-checkout-address'

interface CheckoutAddressSectionProps {
  addresses: Address[]
  selectedAddressId: string
  setSelectedAddressId: (id: string) => void
  selectedAddress?: Address
  isAddressesLoading: boolean
  showNewAddressForm: boolean
  setShowNewAddressForm: (val: boolean) => void
  isSavingAddress: boolean
  editingAddressId: string | null
  setEditingAddressId: (id: string | null) => void
  isChangingAddress: boolean
  setIsChangingAddress: (val: boolean) => void
  showMapPicker: boolean
  setShowMapPicker: (val: boolean) => void
  isDetectingLocation: boolean
  addressForm: AddressFormData
  setAddressForm: React.Dispatch<React.SetStateAction<AddressFormData>>
  storeLat: number
  storeLng: number
  storeSettingsMap: Record<string, string>
  originName?: string
  originLat?: number
  originLng?: number
  maxRadiusKm?: number
  isRestaurantOrder?: boolean
  handleDetectLocationForCheckout: () => void
  handleSaveAddress: (e: React.FormEvent) => Promise<void>
  handleEditAddressClick: (addr: Address) => void
  handleCancelAddressForm: () => void
}

export function CheckoutAddressSection({
  addresses,
  selectedAddressId,
  setSelectedAddressId,
  selectedAddress,
  isAddressesLoading,
  showNewAddressForm,
  setShowNewAddressForm,
  isSavingAddress,
  editingAddressId,
  setEditingAddressId,
  isChangingAddress,
  setIsChangingAddress,
  showMapPicker,
  setShowMapPicker,
  isDetectingLocation,
  addressForm,
  setAddressForm,
  storeLat,
  storeLng,
  storeSettingsMap = {},
  originName,
  originLat,
  originLng,
  maxRadiusKm: passedMaxRadiusKm,
  isRestaurantOrder,
  handleDetectLocationForCheckout,
  handleSaveAddress,
  handleEditAddressClick,
  handleCancelAddressForm,
}: CheckoutAddressSectionProps) {
  const getAddressIcon = (label?: string) => {
    const l = (label || '').toLowerCase()
    if (l.includes('work') || l.includes('office')) {
      return <Building2 className="h-4 w-4 text-amber-600 dark:text-amber-400" />
    }
    if (l.includes('current') || l.includes('other') || l.includes('location')) {
      return <Navigation className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
    }
    return <Home className="h-4 w-4 text-rose-600 dark:text-rose-400" />
  }

  const getAddressIconBg = (label?: string) => {
    const l = (label || '').toLowerCase()
    if (l.includes('work') || l.includes('office')) {
      return 'bg-amber-500/10 border-amber-500/20'
    }
    if (l.includes('current') || l.includes('other') || l.includes('location')) {
      return 'bg-emerald-500/10 border-emerald-500/20'
    }
    return 'bg-rose-500/10 border-rose-500/20'
  }

  return (
    <div className="space-y-3.5">
      <div className="flex items-center justify-between">
        <h2 className="text-sm sm:text-base font-black text-text-primary flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center text-primary">
            <MapPin className="h-4 w-4" />
          </div>
          <span>Delivery Address</span>
        </h2>
        {!showNewAddressForm && addresses.length > 0 && (
          <button
            type="button"
            onClick={() => {
              setAddressForm({
                label: 'Home',
                houseNo: '.',
                street: '',
                area: '.',
                city: 'Ghatampur',
                pincode: storeSettingsMap['store_pincode'] || '209206',
                phone: addressForm.phone,
                isDefault: false,
                lat: null,
                lng: null,
              })
              setEditingAddressId(null)
              setShowNewAddressForm(true)
              setIsChangingAddress(false)
            }}
            className="text-xs font-bold text-primary hover:text-primary/80 transition-colors flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-primary/10 hover:bg-primary/15 border border-primary/20 cursor-pointer"
          >
            <Plus className="h-3.5 w-3.5 stroke-[2.5]" />
            <span>Add New</span>
          </button>
        )}
      </div>

      {isAddressesLoading ? (
        <div className="flex justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
        </div>
      ) : (
        <div id="address-section" className="space-y-3 scroll-mt-24">
          {/* Primary Active Delivery Card */}
          {!showNewAddressForm && selectedAddress && (
            <div className="rounded-2xl border-2 border-primary/30 bg-gradient-to-br from-primary/[0.03] via-card to-card p-4 relative overflow-hidden transition-all shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-start gap-3 min-w-0 flex-1">
                  <div className={cn('w-10 h-10 rounded-xl border flex items-center justify-center shrink-0 shadow-2xs', getAddressIconBg(selectedAddress.label))}>
                    {getAddressIcon(selectedAddress.label)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-extrabold text-sm text-text-primary">
                        {selectedAddress.label || 'Home'}
                      </span>
                      <span className="inline-flex items-center gap-1 text-[10px] font-black text-emerald-700 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                        Express Delivery
                      </span>
                      {selectedAddress.isDefault && (
                        <span className="text-[9px] font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-md border border-primary/20">
                          Default
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-text-secondary mt-1.5 font-medium leading-relaxed">
                      {formatAddress(selectedAddress)}
                    </p>
                    {selectedAddress.phone && (
                      <p className="text-[11px] text-text-muted mt-1 font-semibold flex items-center gap-1.5">
                        <span>📞</span> {formatPhone(selectedAddress.phone)}
                      </p>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button
                    type="button"
                    onClick={() => setIsChangingAddress(!isChangingAddress)}
                    className="px-3.5 py-1.5 rounded-xl border border-border/80 bg-white dark:bg-zinc-800 hover:bg-muted text-text-primary text-xs font-bold transition-all shadow-2xs flex items-center gap-1 cursor-pointer"
                  >
                    <span>{isChangingAddress ? 'Done' : 'Change'}</span>
                    {isChangingAddress ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
                  </button>
                </div>
              </div>

              {/* Dynamic Live Distance & Delivery Tier Explanation Card */}
              {(() => {
                const effectiveLat = originLat ?? storeLat
                const effectiveLng = originLng ?? storeLng
                const addrDist =
                  selectedAddress.lat && selectedAddress.lng
                    ? getDistanceKm(effectiveLat, effectiveLng, selectedAddress.lat, selectedAddress.lng)
                    : null
                const effectiveMaxRadius = passedMaxRadiusKm ?? parseFloat(
                  storeSettingsMap['delivery_radius'] ||
                    storeSettingsMap['max_delivery_radius'] ||
                    '5.0'
                )

                if (addrDist === null || isNaN(Number(addrDist))) return null

                if (addrDist > effectiveMaxRadius) {
                  return (
                    <div className="mt-3 text-xs font-bold text-rose-600 bg-rose-500/10 p-3 rounded-xl border border-rose-500/20 flex items-center gap-2">
                      <span>⚠️</span>
                      <span>
                        Yeh address {addrDist.toFixed(1)} km door hai ({originName || 'delivery zone'} {effectiveMaxRadius.toFixed(0)} km tak hai). Kripya serviceable address chunein.
                      </span>
                    </div>
                  )
                }

                // Dynamic values directly from live store settings
                const t1Fee = storeSettingsMap['delivery_fee_tier1'] || storeSettingsMap['delivery_fee'] || '25'
                const t2Fee = storeSettingsMap['delivery_fee_tier2'] || '35'
                const t3Fee = storeSettingsMap['delivery_fee_tier3'] || '50'

                const t1Threshold = storeSettingsMap['delivery_threshold_tier1'] || storeSettingsMap['grocery_free_delivery_threshold'] || '199'
                const t2Threshold = storeSettingsMap['delivery_threshold_tier2'] || '299'
                const t3Threshold = storeSettingsMap['delivery_threshold_tier3'] || '399'

                let currentTier = 1
                let currentFee = t1Fee
                let currentThreshold = t1Threshold
                let currentRange = '0 - 2 km (Local Zone)'

                if (addrDist <= 2.0) {
                  currentTier = 1
                  currentFee = t1Fee
                  currentThreshold = t1Threshold
                  currentRange = '0 - 2 km'
                } else if (addrDist <= 3.0) {
                  currentTier = 2
                  currentFee = t2Fee
                  currentThreshold = t2Threshold
                  currentRange = '2 - 3 km'
                } else {
                  currentTier = 3
                  currentFee = t3Fee
                  currentThreshold = t3Threshold
                  currentRange = '3 - 5 km'
                }

                return (
                  <div className="mt-3 rounded-xl bg-gradient-to-r from-emerald-500/10 via-teal-500/5 to-blue-500/10 border border-emerald-500/25 p-3 text-xs">
                    <div className="flex items-center justify-between gap-2 flex-wrap mb-1.5">
                      <div className="flex items-center gap-1.5 font-black text-text-primary text-[11.5px]">
                        <span className="text-sm">📍</span>
                        <span>
                          Delivery Distance: <strong className="text-emerald-700 dark:text-emerald-300 font-mono">{addrDist.toFixed(1)} km</strong>
                          {originName && <span className="text-[10px] font-bold text-text-secondary ml-1">({originName})</span>}
                        </span>
                        <span className="text-[10px] font-bold text-text-muted">({currentRange})</span>
                      </div>
                      <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30">
                        Tier {currentTier}
                      </span>
                    </div>

                    <div className="text-[11px] text-text-secondary leading-relaxed space-y-1">
                      <p className="flex items-center gap-1.5 font-semibold">
                        <span className="text-emerald-600">✓</span>
                        <span>Delivery Fee: <strong className="text-text-primary">₹{currentFee}</strong> (FREE on orders above <strong className="text-emerald-600 dark:text-emerald-400">₹{currentThreshold}</strong>)</span>
                      </p>
                      <p className="text-[10px] text-text-muted font-medium">
                        Distance pricing: 0–2 km: ₹{t1Fee} (Free ₹{t1Threshold}+) • 2–3 km: ₹{t2Fee} (Free ₹{t2Threshold}+) • 3–5 km: ₹{t3Fee} (Free ₹{t3Threshold}+)
                      </p>
                    </div>
                  </div>
                )
              })()}
            </div>
          )}

          {/* Organized List of Other Saved Addresses */}
          {!showNewAddressForm && isChangingAddress && addresses.length > 1 && (
            <div className="space-y-2.5 pt-1 animate-slide-down">
              <div className="flex items-center justify-between px-1">
                <span className="text-xs font-black text-text-secondary tracking-tight">
                  Choose delivery address ({addresses.length})
                </span>
                <span className="text-[11px] text-text-muted font-medium">Tap to select</span>
              </div>
              <div className="space-y-2 max-h-[340px] overflow-y-auto pr-1">
                {addresses.map((addr) => {
                  const isSelected = selectedAddressId === addr.id
                  return (
                    <div
                      key={addr.id}
                      onClick={() => {
                        setSelectedAddressId(addr.id)
                        setIsChangingAddress(false)
                      }}
                      className={cn(
                        'p-3.5 rounded-2xl border-2 transition-all flex items-center justify-between gap-3 text-xs bg-card cursor-pointer group',
                        isSelected
                          ? 'border-primary bg-primary/[0.03] shadow-xs'
                          : 'border-border/60 hover:border-primary/40 hover:bg-muted/30'
                      )}
                    >
                      <div className="flex items-center gap-3 min-w-0 flex-1">
                        <div className={cn('w-8 h-8 rounded-xl border flex items-center justify-center shrink-0 shadow-2xs', getAddressIconBg(addr.label))}>
                          {getAddressIcon(addr.label)}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-1.5">
                            <span className="font-black text-xs text-text-primary">{addr.label || 'Home'}</span>
                            {addr.isDefault && (
                              <span className="text-[9px] font-bold text-primary bg-primary/10 px-1.5 py-0.2 rounded border border-primary/20">
                                Default
                              </span>
                            )}
                          </div>
                          <p className="text-[11px] text-text-secondary truncate mt-0.5 font-medium">
                            {formatAddress(addr)}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        {isSelected && (
                          <div className="w-5 h-5 rounded-full bg-primary text-white flex items-center justify-center shadow-xs">
                            <Check className="h-3 w-3 stroke-[3]" />
                          </div>
                        )}
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation()
                            handleEditAddressClick(addr)
                            setIsChangingAddress(false)
                          }}
                          className="p-1.5 rounded-lg border border-border/60 hover:border-primary text-text-secondary hover:text-primary transition-all cursor-pointer"
                          title="Edit address"
                        >
                          <Edit2 className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          )}

          {/* Form */}
          {showNewAddressForm && (
            <CheckoutAddressForm
              addressForm={addressForm}
              setAddressForm={setAddressForm}
              editingAddressId={editingAddressId}
              hasExistingAddresses={addresses.length > 0}
              isSavingAddress={isSavingAddress}
              isDetectingLocation={isDetectingLocation}
              showMapPicker={showMapPicker}
              setShowMapPicker={setShowMapPicker}
              storeLat={storeLat}
              storeLng={storeLng}
              handleSaveAddress={handleSaveAddress}
              handleCancelAddressForm={handleCancelAddressForm}
              handleDetectLocationForCheckout={handleDetectLocationForCheckout}
            />
          )}
        </div>
      )}
    </div>
  )
}
