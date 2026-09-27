'use client'

import { useState, useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { MapPin, Loader2, X, ShieldCheck, CheckCircle2, Smartphone, Send, ArrowRight } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn } from '@/lib/utils'
import { getLast10Digits } from '@/lib/phone'
import { toast } from 'sonner'
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
  const { data: session } = useSession()

  // Clean phone number
  const cleanPhone = getLast10Digits(addressForm.phone || '')
  const sessionUserPhone = getLast10Digits(session?.user?.phone || '')

  // Track verified numbers (session account number is auto-verified)
  const [verifiedPhones, setVerifiedPhones] = useState<Set<string>>(() => {
    const s = new Set<string>()
    if (sessionUserPhone && sessionUserPhone.length === 10) {
      s.add(sessionUserPhone)
    }
    return s
  })

  // Also auto-verify initial phone in edit mode
  const [initialEditPhone] = useState<string>(() => getLast10Digits(addressForm.phone || ''))

  const isPhoneVerified =
    verifiedPhones.has(cleanPhone) ||
    (Boolean(editingAddressId) && cleanPhone === initialEditPhone && cleanPhone.length === 10)

  // OTP flow state
  const [isSendingOtp, setIsSendingOtp] = useState(false)
  const [isVerifyingOtp, setIsVerifyingOtp] = useState(false)
  const [otpSent, setOtpSent] = useState(false)
  const [otpCode, setOtpCode] = useState('')
  const [otpCountdown, setOtpCountdown] = useState(0)

  // Countdown timer effect
  useEffect(() => {
    if (otpCountdown <= 0) return
    const timer = setInterval(() => {
      setOtpCountdown((prev) => prev - 1)
    }, 1000)
    return () => clearInterval(timer)
  }, [otpCountdown])

  // Reset OTP state when phone changes to unverified number
  const handlePhoneChange = (val: string) => {
    const cleaned = getLast10Digits(val)
    setAddressForm((prev) => ({ ...prev, phone: cleaned }))
    if (!verifiedPhones.has(cleaned)) {
      setOtpSent(false)
      setOtpCode('')
    }
  }

  // Send OTP
  const handleSendOtp = async (phoneToVerify = cleanPhone) => {
    if (phoneToVerify.length !== 10) {
      toast.error('Please enter a valid 10-digit mobile number first.')
      return
    }

    setIsSendingOtp(true)
    try {
      const res = await fetch('/api/auth/otp/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: phoneToVerify }),
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to send OTP')
      }
      setOtpSent(true)
      setOtpCountdown(30)
      toast.success(`Verification code sent to +91 ${phoneToVerify} via WhatsApp / SMS! 📲`)
    } catch (err: any) {
      toast.error(err.message || 'Unable to send OTP. Please try again.')
    } finally {
      setIsSendingOtp(false)
    }
  }

  // Verify OTP
  const handleVerifyOtp = async () => {
    const cleanCode = otpCode.trim().replace(/\D/g, '')
    if (cleanCode.length !== 6) {
      toast.error('Please enter the 6-digit OTP code.')
      return
    }

    setIsVerifyingOtp(true)
    try {
      const res = await fetch('/api/auth/otp/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: cleanPhone, otp: cleanCode }),
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Invalid or expired OTP')
      }
      setVerifiedPhones((prev) => new Set(prev).add(cleanPhone))
      setOtpSent(false)
      setOtpCode('')
      toast.success('Mobile number verified successfully! ✅')
    } catch (err: any) {
      toast.error(err.message || 'OTP verification failed. Please try again.')
    } finally {
      setIsVerifyingOtp(false)
    }
  }

  // Intercept form submit: ensure phone is verified
  const onSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault()

    if (cleanPhone.length !== 10) {
      toast.error('Please enter a valid 10-digit mobile number')
      return
    }

    if (!isPhoneVerified) {
      if (!otpSent) {
        toast.info('Please verify your mobile number with OTP before continuing.')
        await handleSendOtp(cleanPhone)
      } else {
        toast.error('Please enter the 6-digit OTP code to verify your phone number.')
      }
      return
    }

    await handleSaveAddress(e)
  }
  return (
    <form
      id="new-address-form"
      onSubmit={onSubmitForm}
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
          <div className="flex items-center justify-between">
            <Label
              htmlFor="phone"
              className="text-[10px] font-bold text-text-secondary uppercase tracking-wider flex items-center gap-1"
            >
              <span>Phone Number</span>
              <span className="text-red-500 font-bold">*</span>
            </Label>
            {isPhoneVerified ? (
              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-600 bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                <CheckCircle2 className="w-3 h-3" />
                Verified
              </span>
            ) : cleanPhone.length === 10 ? (
              <button
                type="button"
                onClick={() => handleSendOtp(cleanPhone)}
                disabled={isSendingOtp}
                className="inline-flex items-center gap-1 text-[10px] font-bold text-primary hover:underline cursor-pointer"
              >
                {isSendingOtp ? (
                  <>
                    <Loader2 className="w-2.5 h-2.5 animate-spin" />
                    <span>Sending...</span>
                  </>
                ) : (
                  <>
                    <Smartphone className="w-2.5 h-2.5" />
                    <span>Verify via OTP</span>
                  </>
                )}
              </button>
            ) : null}
          </div>
          <Input
            id="phone"
            type="tel"
            required
            maxLength={10}
            placeholder="10-digit mobile number"
            value={addressForm.phone}
            onChange={(e) => handlePhoneChange(e.target.value)}
            className={cn(
              "mt-1 h-9 text-xs font-medium rounded-xl border-border bg-background transition-colors",
              isPhoneVerified && "border-emerald-500/50 bg-emerald-50/20 dark:bg-emerald-950/10"
            )}
          />

          {/* Inline OTP Verification Box */}
          {otpSent && !isPhoneVerified && (
            <div className="mt-2 p-2.5 rounded-xl border border-primary/30 bg-primary/5 space-y-2 animate-slide-down">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-text-primary flex items-center gap-1">
                  <ShieldCheck className="w-3.5 h-3.5 text-primary" />
                  OTP sent to WhatsApp / SMS
                </span>
                {otpCountdown > 0 ? (
                  <span className="text-[10px] font-semibold text-text-muted">
                    Resend in {otpCountdown}s
                  </span>
                ) : (
                  <button
                    type="button"
                    onClick={() => handleSendOtp(cleanPhone)}
                    disabled={isSendingOtp}
                    className="text-[10px] font-bold text-primary hover:underline cursor-pointer"
                  >
                    Resend OTP
                  </button>
                )}
              </div>
              <div className="flex items-center gap-2">
                <Input
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={6}
                  placeholder="6-digit code"
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                  className="h-8 text-xs font-mono font-bold tracking-widest bg-background"
                />
                <Button
                  type="button"
                  size="sm"
                  onClick={handleVerifyOtp}
                  disabled={isVerifyingOtp || otpCode.trim().length !== 6}
                  className="h-8 text-xs font-bold px-3 bg-primary text-white hover:bg-primary/90 shrink-0 cursor-pointer"
                >
                  {isVerifyingOtp ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : 'Verify'}
                </Button>
              </div>
            </div>
          )}
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
