'use client'

import { useState, useEffect, useRef } from 'react'
import { useSession } from 'next-auth/react'
import { Address } from '@/types'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import { getDistanceKm } from '@/lib/distance'
import { getLast10Digits } from '@/lib/phone'
import { DEFAULT_STORE_PINCODE, resolveStorePincode } from '@/lib/checkout'

export interface AddressFormData {
  label: string
  houseNo: string
  street: string
  area: string
  city: string
  pincode: string
  phone: string
  isDefault: boolean
  lat?: number | null
  lng?: number | null
}

interface UseCheckoutAddressProps {
  storeLat: number
  storeLng: number
  deliveryRadius: number
  storeSettingsMap: Record<string, string>
}

export function useCheckoutAddress({
  storeLat,
  storeLng,
  deliveryRadius,
  storeSettingsMap,
}: UseCheckoutAddressProps) {
  const { data: session } = useSession()
  const prefilledPhoneRef = useRef(false)
  const activeCheckoutAddressRef = useRef<{ id: string; addresses: Address[] } | null>(null)

  const [addresses, setAddresses] = useState<Address[]>([])
  const [selectedAddressId, setSelectedAddressId] = useState<string>('')
  const [isAddressesLoading, setIsAddressesLoading] = useState(true)

  const [showNewAddressForm, setShowNewAddressForm] = useState(false)
  const [isSavingAddress, setIsSavingAddress] = useState(false)
  const [editingAddressId, setEditingAddressId] = useState<string | null>(null)
  const [isChangingAddress, setIsChangingAddress] = useState(false)
  const [showMapPicker, setShowMapPicker] = useState(false)
  const [isDetectingLocation, setIsDetectingLocation] = useState(false)

  const [addressForm, setAddressForm] = useState<AddressFormData>({
    label: 'Home',
    houseNo: '.',
    street: '',
    area: '.',
    city: 'Ghatampur',
    pincode: DEFAULT_STORE_PINCODE,
    phone: '',
    isDefault: false,
    lat: null,
    lng: null,
  })

  // Pre-fill phone number from session if available
  useEffect(() => {
    if (session?.user?.phone && !prefilledPhoneRef.current) {
      prefilledPhoneRef.current = true
      let phoneVal = session.user.phone
      if (phoneVal.startsWith('wa-') && phoneVal.includes('@')) {
        phoneVal = phoneVal.split('@')[0].replace('wa-', '')
      }
      const digits = getLast10Digits(phoneVal)
      const cleanPhone = digits.length > 10 && digits.startsWith('91') ? digits.slice(-10) : digits

      setAddressForm((prev) => ({
        ...prev,
        phone: prev.phone || cleanPhone || phoneVal,
      }))
    }
  }, [session])

  // Scroll new address form into view when opened
  useEffect(() => {
    if (showNewAddressForm) {
      setTimeout(() => {
        const el = document.getElementById('new-address-form')
        if (el) {
          el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        }
      }, 150)
    }
  }, [showNewAddressForm])

  // Fetch Saved Addresses
  useEffect(() => {
    async function loadAddresses() {
      try {
        setIsAddressesLoading(true)
        const res = await fetch('/api/addresses')
        if (res.ok) {
          const data = await res.json()
          const deliveryAddrs = Array.isArray(data)
            ? data.filter(
                (a: any) =>
                  a && !['STORE_PICKUP', 'STORE_PICKUP_RESTAURANT', 'STORE_PICKUP_CAFE'].includes(a.label)
              )
            : []
          setAddresses(deliveryAddrs)
          if (deliveryAddrs.length > 0) {
            const def = deliveryAddrs.find((a: any) => a.isDefault)
            setSelectedAddressId(def ? def.id : deliveryAddrs[0].id)
            setShowNewAddressForm(false)
            setIsChangingAddress(false)
          } else {
            setSelectedAddressId('')
            setShowNewAddressForm(true)
          }
        }
      } catch (err) {
        toast.error('Failed to load saved addresses')
      } finally {
        setIsAddressesLoading(false)
      }
    }
    loadAddresses()
  }, [])

  const handleDetectLocationForCheckout = () => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser')
      return
    }

    setIsDetectingLocation(true)
    const toastId = toast.loading('Detecting your GPS location...')
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords

        // Calculate distance from store
        const dist = getDistanceKm(storeLat, storeLng, latitude, longitude)

        if (dist > deliveryRadius) {
          toast.dismiss(toastId)
          setIsDetectingLocation(false)
          toast.error(
            `Detected location is outside our delivery zone (${dist.toFixed(1)} km away). If you are ordering for home, please type your Ghatampur address manually.`,
            { duration: 6000 }
          )
          return
        }

        fetch(`/api/geocode?lat=${latitude}&lng=${longitude}`)
          .then((res) => {
            if (!res.ok) throw new Error('Geocoding failed')
            return res.json()
          })
          .then((resData) => {
            toast.dismiss(toastId)
            const results = resData.data?.results
            if (results && results.length > 0) {
              const firstResult = results[0]
              const addressComponents = firstResult.address_components

              let route = ''
              let sublocality = ''
              let city = 'Ghatampur'
              let postcode = DEFAULT_STORE_PINCODE

              addressComponents.forEach((comp: any) => {
                if (comp.types.includes('route')) {
                  route = comp.long_name
                }
                if (
                  comp.types.includes('sublocality') ||
                  comp.types.includes('sublocality_level_1') ||
                  comp.types.includes('sublocality_level_2')
                ) {
                  sublocality = comp.long_name
                }
                if (comp.types.includes('locality')) {
                  city = comp.long_name
                }
                if (comp.types.includes('postal_code')) {
                  postcode = comp.long_name
                }
              })

              const streetParts = [sublocality, route].filter(Boolean)
              const streetName =
                streetParts.length > 0
                  ? streetParts.join(', ')
                  : firstResult.formatted_address.split(',')[0]

              setAddressForm((prev) => ({
                ...prev,
                label: prev.label || 'Home',
                houseNo: '.',
                street: streetName || 'Detected Location',
                area: '.',
                city: city || 'Ghatampur',
                pincode: postcode || DEFAULT_STORE_PINCODE,
                lat: latitude,
                lng: longitude,
              }))
              toast.success('Location detected using Google Maps!')
            } else {
              toast.error('Failed to parse Google Maps location details.')
            }
          })
          .catch(() => {
            toast.dismiss(toastId)
            toast.error('Error fetching details from Google Maps geocoding service.')
          })
          .finally(() => {
            setIsDetectingLocation(false)
          })
      },
      (error) => {
        toast.dismiss(toastId)
        setIsDetectingLocation(false)
        toast.error('Unable to fetch GPS. Please allow location permissions.')
      },
      { enableHighAccuracy: true, timeout: 8000 }
    )
  }

  // Reusable core address saving logic for both explicit submit and on-the-fly checkout auto-save
  const saveAddressCore = async (): Promise<{
    savedAddress: Address
    newAddresses: Address[]
  } | null> => {
    const { label, street, pincode, phone, isDefault } = addressForm

    if (!street || !pincode || !phone) {
      toast.error('Please fill in all address details, including pincode and phone number')
      return null
    }

    const cleanPincode = pincode.trim().replace(/\s+/g, '')

    if (!/^\d{6}$/.test(cleanPincode)) {
      toast.error('Pincode must be a 6-digit number')
      return null
    }

    const serviceablePincode = resolveStorePincode(storeSettingsMap)
    const allowedPincodes = [
      serviceablePincode,
      DEFAULT_STORE_PINCODE,
      '209206',
      '224122',
      '209201',
      '209214',
      '209208',
      '208001',
      '208002',
      '208011',
      '208012',
      '208020',
    ]
    if (!allowedPincodes.includes(cleanPincode)) {
      toast.error(`FastKirana delivers to Ghatampur (209206) & Akbarpur (224122). Pincode ${cleanPincode} is not serviceable.`)
      return null
    }

    const trimmedPhone = phone.trim()
    let cleanPhone = getLast10Digits(trimmedPhone)
    if (cleanPhone.length > 10 && cleanPhone.startsWith('91')) {
      cleanPhone = cleanPhone.slice(-10)
    }

    if (cleanPhone.length !== 10) {
      toast.error('Mobile number must be a valid 10-digit number')
      return null
    }

    const inferredCity = cleanPincode === '224122' ? 'Akbarpur' : (addressForm.city || 'Ghatampur')

    setIsSavingAddress(true)
    try {
      let finalLat = addressForm.lat
      let finalLng = addressForm.lng

      // Fallback: If coordinates are not set, try a quick geocode (max 1.5s timeout)
      if (!finalLat || !finalLng) {
        try {
          const searchQuery = `${street.trim()}, ${inferredCity}, ${cleanPincode}`
          const controller = new AbortController()
          const timer = setTimeout(() => controller.abort(), 1500)
          const geoRes = await fetch(`/api/geocode?address=${encodeURIComponent(searchQuery)}`, {
            signal: controller.signal,
          })
          clearTimeout(timer)
          if (geoRes.ok) {
            const geoData = await geoRes.json()
            const results = geoData.data?.results
            if (results && results.length > 0) {
              finalLat = results[0].geometry.location.lat
              finalLng = results[0].geometry.location.lng
            }
          }
        } catch {
          // Non-blocking fallback
        }
      }

      const payload: any = {
        label: label || 'Home',
        houseNo: addressForm.houseNo || '.',
        street: street.trim(),
        area: addressForm.area || '.',
        city: inferredCity,
        pincode: cleanPincode,
        phone: cleanPhone,
        isDefault: !!isDefault,
        lat: finalLat,
        lng: finalLng,
      }

      if (editingAddressId) {
        payload.id = editingAddressId
      }

      const res = await fetch('/api/addresses', {
        method: editingAddressId ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (res.ok) {
        const savedAddress: Address = await res.json()
        let nextAddresses: Address[]
        if (editingAddressId) {
          nextAddresses = addresses.map((a) => (a.id === editingAddressId ? savedAddress : a))
          toast.success('Address updated successfully!')
        } else {
          nextAddresses = [savedAddress, ...addresses.filter((a) => a.id !== savedAddress.id)]
          toast.success('Address saved successfully!')
        }
        setAddresses(nextAddresses)
        setSelectedAddressId(savedAddress.id)
        activeCheckoutAddressRef.current = { id: savedAddress.id, addresses: nextAddresses }
        setShowNewAddressForm(false)
        setEditingAddressId(null)
        setAddressForm({
          label: 'Home',
          houseNo: '.',
          street: '',
          area: '.',
          city: 'Ghatampur',
          pincode: DEFAULT_STORE_PINCODE,
          phone: addressForm.phone,
          isDefault: false,
          lat: null,
          lng: null,
        })
        return { savedAddress, newAddresses: nextAddresses }
      } else {
        const errorData = await res.json().catch(() => ({}))
        toast.error(errorData.error || 'Failed to save address')
        return null
      }
    } catch (err) {
      console.error('Error saving address:', err)
      toast.error('Something went wrong saving address')
      return null
    } finally {
      setIsSavingAddress(false)
    }
  }

  const handleSaveAddress = async (e: React.FormEvent) => {
    e.preventDefault()
    await saveAddressCore()
  }

  const handleEditAddressClick = (addr: any) => {
    triggerHaptic('light')
    setEditingAddressId(addr.id)
    setAddressForm({
      label: addr.label || 'Home',
      houseNo: addr.houseNo || '.',
      street: addr.street || '',
      area: addr.area || '.',
      city: addr.city || 'Ghatampur',
      pincode: addr.pincode || DEFAULT_STORE_PINCODE,
      phone: addr.phone || '',
      isDefault: addr.isDefault || false,
      lat: addr.lat || null,
      lng: addr.lng || null,
    })
    setShowNewAddressForm(true)
  }

  const handleCancelAddressForm = () => {
    triggerHaptic('light')
    setShowNewAddressForm(false)
    setEditingAddressId(null)
    setIsChangingAddress(false)
    setShowMapPicker(false)
    setAddressForm({
      label: 'Home',
      houseNo: '.',
      street: '',
      area: '.',
      city: 'Ghatampur',
      pincode: DEFAULT_STORE_PINCODE,
      phone: addressForm.phone,
      isDefault: false,
      lat: null,
      lng: null,
    })
  }

  const selectedAddress = addresses.find((a) => a.id === selectedAddressId)

  return {
    addresses,
    setAddresses,
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
    activeCheckoutAddressRef,
    handleDetectLocationForCheckout,
    saveAddressCore,
    handleSaveAddress,
    handleEditAddressClick,
    handleCancelAddressForm,
  }
}
