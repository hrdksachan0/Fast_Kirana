'use client'

import { MapPin, Loader2, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn } from '@/lib/utils'
import { getLast10Digits } from '@/lib/phone'
import MapPicker from '@/components/shared/map-picker'
import { AddressFormData } from '@/hooks/checkout/use-checkout-address'

interface CheckoutAddressFormProps {
  addressForm: AddressFormData
  setAddressForm: React.Dispatch<React.SetStateAction<AddressFormData>>
  editingAddressId: string | null
  hasExistingAddresses: boolean
  isSavingAddress: boolean
  isDetectingLocation: boolean
  showMapPicker: boolean
  setShowMapPicker: (val: boolean) => void
  storeLat: number
  storeLng: number
  handleSaveAddress: (e: React.FormEvent) => Promise<void>
  handleCancelAddressForm: () => void
  handleDetectLocationForCheckout: () => void
}

export function CheckoutAddressForm({
  addressForm,
  setAddressForm,
  editingAddressId,
  hasExistingAddresses,
  isSavingAddress,
  isDetectingLocation,
  showMapPicker,
  setShowMapPicker,
  storeLat,
  storeLng,
  handleSaveAddress,
  handleCancelAddressForm,
  handleDetectLocationForCheckout,
}: CheckoutAddressFormProps) {
  return (
    <form
      id="new-address-form"
      onSubmit={handleSaveAddress}
      className="border border-border/80 p-3.5 sm:p-5 rounded-2xl space-y-3.5 bg-card shadow-xs animate-slide-up"
    >
      <div className="flex items-center justify-between border-b border-border/40 pb-2.5">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold">
            <MapPin className="h-3.5 w-3.5" />
          </div>
          <div>
            <h3 className="font-black text-xs sm:text-sm text-text-primary">
              {editingAddressId ? 'Edit Address' : 'Add Delivery Address'}
            </h3>
            <p className="text-[10px] text-text-muted">Ghatampur local delivery</p>
          </div>
        </div>
        {hasExistingAddresses && (
          <button
            type="button"
            onClick={handleCancelAddressForm}
            className="text-xs font-bold text-text-muted hover:text-text-primary p-1 rounded-lg hover:bg-muted"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      {/* 1-Tap Use Current Location Button */}
      <button
        type="button"
        onClick={handleDetectLocationForCheckout}
        disabled={isDetectingLocation}
        className="w-full flex items-center justify-center gap-2 p-2.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/25 border border-emerald-500/30 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100/50 transition-all font-bold text-xs active:scale-[0.99] cursor-pointer"
      >
        {isDetectingLocation ? (
          <>
            <Loader2 className="h-3.5 w-3.5 animate-spin text-emerald-600" />
            <span>Detecting GPS location...</span>
          </>
        ) : (
          <>
            <span className="text-sm">📍</span>
            <span>Use Current Location</span>
          </>
        )}
      </button>

      {/* Address Label Selector */}
      <div>
        <Label className="text-[10px] font-bold text-text-secondary uppercase tracking-wider">
          Save As
        </Label>
        <div className="grid grid-cols-3 gap-2 mt-1">
          {[
            { key: 'Home', label: 'Home', icon: '🏠' },
            { key: 'Work', label: 'Work', icon: '🏢' },
            { key: 'Other', label: 'Other', icon: '📍' },
          ].map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => setAddressForm({ ...addressForm, label: item.key })}
              className={cn(
                'h-9 text-xs font-bold rounded-xl border transition-all flex items-center justify-center gap-1.5 active:scale-95 cursor-pointer',
                addressForm.label === item.key
                  ? 'bg-primary text-white border-primary shadow-xs'
                  : 'bg-background border-border text-text-secondary hover:border-primary/40'
              )}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Complete Delivery Address */}
      <div>
        <Label
          htmlFor="street"
          className="text-[10px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between"
        >
          <span>Complete Address</span>
          <span className="text-red-500 font-bold">*</span>
        </Label>
        <textarea
          id="street"
          required
          rows={2}
          placeholder="House / Flat No., Street, Landmark, Ghatampur"
          value={addressForm.street}
          onChange={(e) => setAddressForm({ ...addressForm, street: e.target.value })}
          className="mt-1 block w-full rounded-xl border border-border bg-background px-3 py-2 text-xs font-medium focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary placeholder:text-text-muted/60"
        />
      </div>

      {/* Phone & Pincode/City Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
        <div>
          <Label
            htmlFor="phone"
            className="text-[10px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between"
          >
            <span>Phone Number</span>
            <span className="text-red-500 font-bold">*</span>
          </Label>
          <Input
            id="phone"
            type="tel"
            required
            maxLength={10}
            placeholder="10-digit mobile number"
            value={addressForm.phone}
            onChange={(e) =>
              setAddressForm({ ...addressForm, phone: getLast10Digits(e.target.value) })
            }
            className="mt-1 h-9 text-xs font-medium rounded-xl border-border bg-background"
          />
        </div>
        <div>
          <Label
            htmlFor="city-pincode"
            className="text-[10px] font-bold text-text-secondary uppercase tracking-wider"
          >
            <span>City & Pincode</span>
          </Label>
          <div className="mt-1 h-9 px-3 flex items-center justify-between rounded-xl border border-border bg-muted/30 text-xs font-bold text-text-secondary">
            <span>Ghatampur</span>
            <span className="text-primary font-black">209206</span>
          </div>
        </div>
      </div>

      {/* Optional Map Toggle */}
      <div className="pt-0.5">
        <button
          type="button"
          onClick={() => setShowMapPicker(!showMapPicker)}
          className="text-xs font-bold text-primary flex items-center gap-1.5 hover:underline cursor-pointer"
        >
          <span>🗺️</span>
          <span>{showMapPicker ? 'Hide map pin' : 'Adjust pin on map (optional)'}</span>
        </button>
        {showMapPicker && (
          <div className="mt-2 rounded-xl overflow-hidden border border-border animate-slide-down">
            <MapPicker
              initialLat={addressForm.lat ?? null}
              initialLng={addressForm.lng ?? null}
              storeLat={storeLat}
              storeLng={storeLng}
              onLocationSelect={(loc) => {
                setAddressForm((prev) => ({
                  ...prev,
                  lat: loc.lat,
                  lng: loc.lng,
                  street: loc.street,
                  city: loc.city,
                  pincode: loc.pincode,
                }))
              }}
            />
          </div>
        )}
      </div>

      {/* Form Action Buttons */}
      <div className="flex gap-2 justify-end pt-2 border-t border-border/40">
        {hasExistingAddresses && (
          <Button
            type="button"
            variant="ghost"
            onClick={handleCancelAddressForm}
            disabled={isSavingAddress}
            className="rounded-xl text-xs font-bold h-9 px-3.5 cursor-pointer"
          >
            Cancel
          </Button>
        )}
        <Button
          type="submit"
          disabled={isSavingAddress}
          className="bg-primary text-white rounded-xl text-xs font-black px-5 h-9 hover:bg-primary/95 shadow-sm active:scale-98 transition-all flex items-center gap-1.5 cursor-pointer"
        >
          {isSavingAddress ? (
            <>
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
              <span>Saving...</span>
            </>
          ) : (
            <span>{editingAddressId ? 'Update Address' : 'Deliver to this Address »'}</span>
          )}
        </Button>
      </div>
    </form>
  )
}
