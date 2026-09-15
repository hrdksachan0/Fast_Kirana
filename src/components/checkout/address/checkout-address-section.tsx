'use client'

import { MapPin, Plus, Loader2 } from 'lucide-react'
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
  storeSettingsMap,
  handleDetectLocationForCheckout,
  handleSaveAddress,
  handleEditAddressClick,
  handleCancelAddressForm,
}: CheckoutAddressSectionProps) {
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h2 className="text-sm sm:text-base font-black text-text-primary flex items-center gap-2">
          <MapPin className="h-4 w-4 text-primary" />
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
            className="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer"
          >
            <Plus className="h-3.5 w-3.5" />
            <span>Add New</span>
          </button>
        )}
      </div>

      {isAddressesLoading ? (
        <div className="flex justify-center py-6">
          <Loader2 className="h-5 w-5 animate-spin text-primary" />
        </div>
      ) : (
        <div id="address-section" className="space-y-3 scroll-mt-24">
          {/* Primary Selected Address Card */}
          {!showNewAddressForm && selectedAddress && (
            <div className="rounded-2xl border border-border bg-card p-3.5 sm:p-4 relative overflow-hidden transition-all shadow-xs hover:border-primary/40">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-start gap-3 min-w-0">
                  <div className="w-9 h-9 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0 text-lg font-bold">
                    {selectedAddress.label === 'Work'
                      ? '🏢'
                      : selectedAddress.label === 'Other'
                      ? '📍'
                      : '🏠'}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-black text-sm text-text-primary">
                        {selectedAddress.label || 'Home'}
                      </span>
                      <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-700 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                        Express Delivery
                      </span>
                      {selectedAddress.isDefault && (
                        <span className="text-[9px] font-bold text-accent bg-accent/10 px-1.5 py-0.5 rounded-md">
                          Default
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-text-secondary mt-1 font-medium leading-snug break-words">
                      {formatAddress(selectedAddress)}
                    </p>
                    {selectedAddress.phone && (
                      <p className="text-[11px] text-text-muted mt-0.5 font-medium flex items-center gap-1">
                        <span>📞</span> {formatPhone(selectedAddress.phone)}
                      </p>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button
                    type="button"
                    onClick={() => setIsChangingAddress(!isChangingAddress)}
                    className="px-3 py-1.5 rounded-xl border border-border/80 bg-muted/30 hover:bg-muted text-text-primary text-xs font-bold transition-all shadow-xs cursor-pointer"
                  >
                    {isChangingAddress ? 'Done' : 'Change'}
                  </button>
                </div>
              </div>

              {/* Distance / zone check */}
              {(() => {
                const addrDist =
                  selectedAddress.lat && selectedAddress.lng
                    ? getDistanceKm(storeLat, storeLng, selectedAddress.lat, selectedAddress.lng)
                    : null
                const maxRadiusKm = parseFloat(
                  storeSettingsMap['delivery_radius'] ||
                    storeSettingsMap['max_delivery_radius'] ||
                    '5.0'
                )
                if (addrDist !== null && addrDist > maxRadiusKm) {
                  return (
                    <div className="mt-3 text-xs font-bold text-rose-600 bg-rose-500/10 p-2.5 rounded-xl border border-rose-500/20 flex items-center gap-2">
                      <span>⚠️</span>
                      <span>
                        This address is {addrDist.toFixed(1)} km away (outside our 5 km delivery
                        zone). Please pick an address in Ghatampur.
                      </span>
                    </div>
                  )
                }
                return null
              })()}
            </div>
          )}

          {/* Expandable list of saved addresses */}
          {!showNewAddressForm && isChangingAddress && addresses.length > 1 && (
            <div className="space-y-2.5 pt-1 animate-slide-down">
              <div className="text-[11px] font-bold text-text-muted px-1">
                Select delivery address:
              </div>
              {addresses.map((addr) => (
                <div
                  key={addr.id}
                  onClick={() => {
                    setSelectedAddressId(addr.id)
                    setIsChangingAddress(false)
                  }}
                  className={cn(
                    'p-3 rounded-xl border-2 cursor-pointer transition-all flex items-center justify-between gap-3 text-xs bg-card',
                    selectedAddressId === addr.id
                      ? 'border-primary bg-primary/[0.02] shadow-xs'
                      : 'border-border/60 hover:border-primary/40'
                  )}
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <span className="text-base">
                      {addr.label === 'Work' ? '🏢' : addr.label === 'Other' ? '📍' : '🏠'}
                    </span>
                    <div className="min-w-0">
                      <span className="font-bold text-text-primary mr-2">{addr.label}</span>
                      <span className="text-text-secondary truncate">{formatAddress(addr)}</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleEditAddressClick(addr)
                        setIsChangingAddress(false)
                      }}
                      className="text-[11px] font-bold text-primary hover:underline"
                    >
                      Edit
                    </button>
                  </div>
                </div>
              ))}
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
