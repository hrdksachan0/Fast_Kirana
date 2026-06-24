'use client'

import { useState, useEffect, useRef } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { useCart } from '@/hooks/use-cart'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn, isCafeProduct, formatPhone, formatAddress } from '@/lib/utils'
import {
  MapPin,
  ShoppingBag,
  CreditCard,
  Plus,
  Loader2,
  Check,
  ChevronRight,
  ShieldCheck,
  QrCode,
  Smartphone,
  ChevronsRight,
} from 'lucide-react'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import { Address } from '@/types'
import MapPicker from '@/components/shared/map-picker'

function getDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Radius of the earth in km
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c // Distance in km
}

interface SlideToOrderProps {
  onConfirm: () => void
  isPlacingOrder: boolean
  disabled: boolean
  amount: number
}

function SlideToOrder({ onConfirm, isPlacingOrder, disabled, amount }: SlideToOrderProps) {
  return (
    <>
      <style>{`
        @keyframes shimmer {
          100% {
            transform: translateX(100%);
          }
        }
        .shimmer-btn {
          position: relative;
          overflow: hidden;
        }
        .shimmer-btn::after {
          position: absolute;
          top: 0;
          right: 0;
          bottom: 0;
          left: 0;
          transform: translateX(-100%);
          background-image: linear-gradient(
            90deg,
            rgba(255, 255, 255, 0) 0%,
            rgba(255, 255, 255, 0.25) 30%,
            rgba(255, 255, 255, 0.5) 60%,
            rgba(255, 255, 255, 0) 100%
          );
          animation: shimmer 2s infinite;
          content: '';
        }
        @keyframes pulseGlow {
          0%, 100% {
            box-shadow: 0 4px 14px 0 rgba(34, 197, 94, 0.45);
          }
          50% {
            box-shadow: 0 4px 24px 0 rgba(34, 197, 94, 0.75);
          }
        }
        .glow-btn {
          animation: pulseGlow 2s infinite;
        }
      `}</style>
      <button
        type="button"
        disabled={disabled || isPlacingOrder}
        onClick={onConfirm}
        className={cn(
          "w-full h-14 bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 text-white rounded-full font-black text-xs tracking-widest uppercase shadow-lg transition-all duration-300 hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center gap-2",
          "shimmer-btn",
          !disabled && !isPlacingOrder && "glow-btn",
          (disabled || isPlacingOrder) && "opacity-60 cursor-not-allowed"
        )}
      >
        {isPlacingOrder ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin text-white" />
            <span>Processing Order...</span>
          </>
        ) : (
          <>
            <span>Place Order (₹{amount.toFixed(0)})</span>
            <ChevronsRight className="h-4 w-4 text-white animate-bounce" style={{ animationDuration: '1.5s' }} />
          </>
        )}
      </button>
    </>
  )
}

export default function CheckoutPage() {
  const router = useRouter()
  const { data: session } = useSession()
  const prefilledPhoneRef = useRef(false)
  const { items, removeItem, clearCart, getSubtotal, getSavings, getMrpTotal, updateQuantity, updateCartProduct } = useCart()

  const [addresses, setAddresses] = useState<Address[]>([])
  const [selectedAddressId, setSelectedAddressId] = useState<string>('')
  const [deliveryRadius, setDeliveryRadius] = useState(5.0)
  const [storeLat, setStoreLat] = useState(26.1534185)
  const [storeLng, setStoreLng] = useState(80.1714024)
  const [onlyCod, setOnlyCod] = useState(false)
  const [taxRate, setTaxRate] = useState(0.05)
  const [miscFee, setMiscFee] = useState(0.0)
  const [miscFeeLabel, setMiscFeeLabel] = useState('Miscellaneous Additions')
  const [contactPhone, setContactPhone] = useState('+91 70544 70303')
  const [contactAddress, setContactAddress] = useState('NH34, Ghatampur, Kanpur Nagar')
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [isSettingsLoading, setIsSettingsLoading] = useState(true)

  useEffect(() => {
    fetch('/api/settings', { cache: 'no-store' })
      .then(res => res.json())
      .then(data => {
        if (data.grocery_mart_open !== undefined) {
          setGroceryMartOpen(data.grocery_mart_open === 'true')
        }
        if (data.cafe_open !== undefined) {
          setCafeOpen(data.cafe_open === 'true')
        }
        if (data.delivery_radius) {
          setDeliveryRadius(parseFloat(data.delivery_radius))
        }
        if (data.store_lat) {
          setStoreLat(parseFloat(data.store_lat))
        }
        if (data.store_lng) {
          setStoreLng(parseFloat(data.store_lng))
        }
        if (data.only_cod !== undefined) {
          setOnlyCod(data.only_cod === 'true')
        }
        if (data.tax_rate !== undefined) {
          setTaxRate(parseFloat(data.tax_rate) / 100)
        }
        if (data.misc_fee !== undefined) {
          setMiscFee(parseFloat(data.misc_fee))
        }
        if (data.misc_fee_label !== undefined) {
          setMiscFeeLabel(data.misc_fee_label)
        }
        if (data.contact_phone) {
          setContactPhone(data.contact_phone)
        }
        if (data.contact_address) {
          setContactAddress(data.contact_address)
        }
        setIsSettingsLoading(false)
      })
      .catch(err => {
        console.error('Error fetching settings on checkout mount:', err)
        setIsSettingsLoading(false)
      })
  }, [])

  useEffect(() => {
    async function validateCartOnCheckout() {
      if (items.length === 0) return
      try {
        const res = await fetch('/api/products/validate-cart', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ items }),
        })
        if (res.ok) {
          const data = await res.json()
          if (data.hasChanges && data.updates.length > 0) {
            data.updates.forEach((update: any) => {
              if (update.type === 'OUT_OF_STOCK') {
                updateCartProduct(update.productId, { isAvailable: false, stock: 0 })
                toast.error(`"${update.name}" is out of stock and was removed from your cart.`, {
                  id: `checkout-out-of-stock-${update.productId}`,
                })
              } else if (update.type === 'QUANTITY_CAP') {
                updateQuantity(update.productId, update.name, update.newVal)
                toast.warning(`Quantity for "${update.name}" was reduced to ${update.newVal} (max stock).`, {
                  id: `checkout-qty-cap-${update.productId}`,
                })
              } else if (update.type === 'PRICE_UPDATE') {
                updateCartProduct(update.productId, { price: update.newVal })
                toast.info(`Price for "${update.name}" updated to ₹${update.newVal}.`, {
                  id: `checkout-price-update-${update.productId}`,
                })
              } else if (update.type === 'MRP_UPDATE') {
                updateCartProduct(update.productId, { mrp: update.newVal })
              }
            })
          }
        }
      } catch (err) {
        console.error('Error validating cart on checkout mount:', err)
      }
    }

    validateCartOnCheckout()
  }, [])
  const [isAddressesLoading, setIsAddressesLoading] = useState(true)
  const [isPlacingOrder, setIsPlacingOrder] = useState(false)

  // New Address Form State
  const [showNewAddressForm, setShowNewAddressForm] = useState(false)
  const [isSavingAddress, setIsSavingAddress] = useState(false)
  const [addressForm, setAddressForm] = useState<{
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
  }>({
    label: 'Home',
    houseNo: '.',
    street: '',
    area: '.',
    city: 'Ghatampur',
    pincode: '209206',
    phone: '',
    isDefault: false,
    lat: null,
    lng: null,
  })

  const [isDetectingLocation, setIsDetectingLocation] = useState(false)

  // Pre-fill phone number from session if available
  useEffect(() => {
    if (session?.user?.phone && !prefilledPhoneRef.current) {
      prefilledPhoneRef.current = true
      let phoneVal = session.user.phone
      if (phoneVal.startsWith('wa-') && phoneVal.includes('@')) {
        phoneVal = phoneVal.split('@')[0].replace('wa-', '')
      }
      const digits = phoneVal.replace(/\D/g, '')
      const cleanPhone = digits.length > 10 && digits.startsWith('91') ? digits.slice(-10) : digits
      
      setAddressForm(prev => ({
        ...prev,
        phone: prev.phone || cleanPhone || phoneVal
      }))
    }
  }, [session])

  const handleDetectLocationForCheckout = () => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser')
      return
    }

    setIsDetectingLocation(true)
    const toastId = toast.loading('Detecting your GPS location...')
    navigator.geolocation.getCurrentPosition(
      (position) => {
        let { latitude, longitude } = position.coords
        
        // Calculate distance from store
        const dist = getDistance(storeLat, storeLng, latitude, longitude)
        
        // If developer testing from far away (> 20 km), automatically mock to nearby (2.5 km away)
        if (dist > 20) {
          toast.warning(`Detected GPS is ${dist.toFixed(0)} km away. Mocking to 2.5 km for local testing!`)
          latitude = storeLat + 0.015
          longitude = storeLng + 0.015
          toast.dismiss(toastId)
          setIsDetectingLocation(false)
          setAddressForm(prev => ({
            ...prev,
            label: prev.label || 'Home',
            houseNo: '.',
            street: 'Vikas Medical Store, NH34, Ghatampur',
            area: '.',
            city: 'Ghatampur',
            pincode: '209206',
            lat: latitude,
            lng: longitude,
          }))
          toast.success('Location detected and filled (Kanpur NH34 mock)!')
          return
        } else if (dist > deliveryRadius) {
          toast.dismiss(toastId)
          setIsDetectingLocation(false)
          toast.error(`Detected location is outside our delivery zone (${dist.toFixed(1)} km away). If you are ordering for home, please type your Ghatampur address manually.`, { duration: 6000 })
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
              let postcode = '209206'
              
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
              const streetName = streetParts.length > 0 ? streetParts.join(', ') : firstResult.formatted_address.split(',')[0]

              setAddressForm(prev => ({
                ...prev,
                label: prev.label || 'Home',
                houseNo: '.',
                street: streetName || 'Detected Location',
                area: '.',
                city: city || 'Ghatampur',
                pincode: postcode || '209206',
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

  // Payment Method
  const [paymentMethod, setPaymentMethod] = useState<'COD' | 'UPI' | 'CARD' | 'WALLET'>('COD')
  const [deliveryMethod, setDeliveryMethod] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY')
  const [scheduledSlot, setScheduledSlot] = useState<string>('INSTANT')

  const selectedAddress = addresses.find((a) => a.id === selectedAddressId)

  // Calculations for checkout items
  const subtotal = getSubtotal()
  const mrpTotal = getMrpTotal()
  const savings = getSavings()
  const b2bDiscount = 0
  const adjustedSubtotal = subtotal - b2bDiscount
  const discount = savings + b2bDiscount
  
  // Split items into Cafe and Grocery categories
  const cafeCartItems = items.filter((item) => isCafeProduct(item.product))
  const groceryCartItems = items.filter((item) => !isCafeProduct(item.product))

  // Grocery Calculations
  const grocerySubtotal = groceryCartItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const groceryMrpSubtotal = groceryCartItems.reduce((sum, item) => sum + item.product.mrp * item.quantity, 0)
  const grocerySavings = groceryMrpSubtotal - grocerySubtotal
  const groceryB2BDiscount = 0
  const groceryAdjustedSubtotal = grocerySubtotal - groceryB2BDiscount
  const groceryDeliveryFee = deliveryMethod === 'PICKUP' ? 0 : (groceryCartItems.length > 0 && groceryAdjustedSubtotal < FREE_DELIVERY_THRESHOLD ? DELIVERY_FEE : 0)
  const groceryTaxes = groceryAdjustedSubtotal * taxRate
  const groceryTotal = groceryAdjustedSubtotal + groceryDeliveryFee + groceryTaxes + (groceryCartItems.length > 0 ? miscFee : 0)

  // Cafe Calculations
  const cafeSubtotal = cafeCartItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const cafeMrpSubtotal = cafeCartItems.reduce((sum, item) => sum + item.product.mrp * item.quantity, 0)
  const cafeSavings = cafeMrpSubtotal - cafeSubtotal
  const cafeB2BDiscount = 0
  const cafeAdjustedSubtotal = cafeSubtotal - cafeB2BDiscount
  const cafeDeliveryFee = deliveryMethod === 'PICKUP' ? 0 : (cafeCartItems.length > 0 && cafeAdjustedSubtotal < 200 ? 25 : 0)
  const cafeTaxes = cafeAdjustedSubtotal * taxRate
  const cafeTotal = cafeAdjustedSubtotal + cafeDeliveryFee + cafeTaxes + (groceryCartItems.length === 0 ? miscFee : 0)

  const deliveryFee = groceryDeliveryFee + cafeDeliveryFee
  const taxes = adjustedSubtotal * taxRate
  const grandTotal = adjustedSubtotal + deliveryFee + taxes + miscFee

  // Fetch Saved Addresses
  useEffect(() => {
    async function loadAddresses() {
      try {
        const res = await fetch('/api/addresses')
        if (res.ok) {
          const data = await res.json()
          const deliveryAddrs = data.filter((a: any) => a.label !== 'STORE_PICKUP')
          setAddresses(deliveryAddrs)
          if (deliveryAddrs.length > 0) {
            const def = deliveryAddrs.find((a: any) => a.isDefault)
            setSelectedAddressId(def ? def.id : deliveryAddrs[0].id)
          } else {
            setSelectedAddressId('')
          }

          // Automatically geocode in background if any saved address lacks coordinates
          deliveryAddrs.forEach(async (addr: any) => {
            if (addr.lat === null || addr.lng === null) {
              try {
                const searchQuery = `${addr.street}, ${addr.city}, ${addr.pincode}`
                const geoRes = await fetch(`/api/geocode?address=${encodeURIComponent(searchQuery)}`)
                if (geoRes.ok) {
                  const geoData = await geoRes.json()
                  let finalLat = null
                  let finalLng = null
                  const results = geoData.data?.results
                  if (results && results.length > 0) {
                    finalLat = Math.round(results[0].geometry.location.lat * 1000000) / 1000000
                    finalLng = Math.round(results[0].geometry.location.lng * 1000000) / 1000000
                  }
                  
                  if (finalLat && finalLng) {
                    await fetch('/api/addresses', {
                      method: 'PATCH',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ id: addr.id, lat: finalLat, lng: finalLng }),
                    })
                    setAddresses(prev => prev.map(a => a.id === addr.id ? { ...a, lat: finalLat, lng: finalLng } : a))
                  }
                }
              } catch (err) {
                console.error('Error auto-geocoding existing address:', addr.id, err)
              }
            }
          })
        }
      } catch (err) {
        toast.error('Failed to load saved addresses')
      } finally {
        setIsAddressesLoading(false)
      }
    }
    loadAddresses()
  }, [])



  // Create New Address
  const handleSaveAddress = async (e: React.FormEvent) => {
    e.preventDefault()
    const { label, street, pincode, phone, isDefault } = addressForm

    if (!street || !pincode || !phone) {
      toast.error('Please fill in all address details, including pincode and phone number')
      return
    }

    const cleanPincode = pincode.trim()

    if (!/^\d{6}$/.test(cleanPincode)) {
      toast.error('Pincode must be a 6-digit number')
      return
    }

    if (cleanPincode !== '209206') {
      toast.error('FastKirana only delivers to Ghatampur area (Pincode: 209206)')
      return
    }

    const trimmedPhone = phone.trim()
    let cleanPhone = trimmedPhone.replace(/\D/g, '')
    if (cleanPhone.length > 10 && cleanPhone.startsWith('91')) {
      cleanPhone = cleanPhone.slice(-10)
    }

    if (cleanPhone.length !== 10) {
      toast.error('Mobile number must be a valid 10-digit number')
      return
    }

    const inferredCity = 'Ghatampur'

    setIsSavingAddress(true)
    try {
      let finalLat = addressForm.lat
      let finalLng = addressForm.lng

      // Fallback: If coordinates are not set, try to geocode the manually typed address in the background
      if (!finalLat || !finalLng) {
        try {
          const searchQuery = `${street.trim()}, ${inferredCity}, ${cleanPincode}`
          const geoRes = await fetch(`/api/geocode?address=${encodeURIComponent(searchQuery)}`)
          if (geoRes.ok) {
            const geoData = await geoRes.json()
            const results = geoData.data?.results
            if (results && results.length > 0) {
              finalLat = results[0].geometry.location.lat
              finalLng = results[0].geometry.location.lng
            }
          }
        } catch (err) {
          console.error('Error auto-geocoding manual address:', err)
        }
      }

      const payload = {
        label: label || 'Home',
        houseNo: '.',
        street: street.trim(),
        area: '.',
        city: inferredCity,
        pincode: cleanPincode,
        phone: cleanPhone,
        isDefault: !!isDefault,
        lat: finalLat,
        lng: finalLng,
      }

      const res = await fetch('/api/addresses', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (res.ok) {
        const newAddress = await res.json()
        setAddresses([newAddress, ...addresses])
        setSelectedAddressId(newAddress.id)
        setShowNewAddressForm(false)
        setAddressForm({
          label: 'Home',
          houseNo: '.',
          street: '',
          area: '.',
          city: 'Ghatampur',
          pincode: '209206',
          phone: addressForm.phone, // keep phone number for convenience
          isDefault: false,
          lat: null,
          lng: null,
        })
        toast.success('Address saved successfully!')
      } else {
        const errorData = await res.json()
        toast.error(errorData.error || 'Failed to save address')
      }
    } catch (err) {
      toast.error('Something went wrong')
    } finally {
      setIsSavingAddress(false)
    }
  }

  // Place Order
  const handlePlaceOrder = async () => {
    if (deliveryMethod === 'DELIVERY' && !selectedAddressId && addresses.length === 0) {
      toast.error('Please select a delivery address')
      return
    }

    setIsPlacingOrder(true)
    try {
      if (deliveryMethod === 'DELIVERY') {
        const targetId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
        const selectedAddr = addresses.find((a) => a.id === targetId)
        if (selectedAddr) {
          const p = selectedAddr.pincode.trim()
          const c = selectedAddr.city.trim().toLowerCase()
          if (p !== '209206') {
            triggerHaptic('warning')
            toast.error('Selected address is outside our delivery zone. Please add/select a Ghatampur address (Pincode: 209206).')
            setIsPlacingOrder(false)
            return
          }
          if (!c.includes('ghatampur') && !c.includes('kanpur')) {
            triggerHaptic('warning')
            toast.error('Selected address city is outside our delivery zone. FastKirana only delivers to Ghatampur / Kanpur.')
            setIsPlacingOrder(false)
            return
          }
          const phoneVal = (selectedAddr.phone || '').trim().replace(/\D/g, '')
          const cleanPhone = phoneVal.length > 10 && phoneVal.startsWith('91') ? phoneVal.slice(-10) : phoneVal
          if (cleanPhone.length !== 10) {
            triggerHaptic('warning')
            toast.error('The selected address is missing a valid 10-digit mobile number. Please add a new address with a valid phone number.')
            setIsPlacingOrder(false)
            return
          }
        }
      }
      // Fetch settings to check store status
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings = await settingsRes.json()
      
      const hasGrocery = items.some((item) => !isCafeProduct(item.product))
      const hasCafe = items.some((item) => isCafeProduct(item.product))
      
      if (hasGrocery && settings.grocery_mart_open === 'false') {
        triggerHaptic('warning')
        toast.error('Grocery Mart is temporarily closed. Please remove grocery items to checkout.')
        setIsPlacingOrder(false)
        return
      }
      
      if (hasCafe && settings.cafe_open === 'false') {
        triggerHaptic('warning')
        toast.error('FastKirana Cafe is temporarily closed. Please remove cafe items to checkout.')
        setIsPlacingOrder(false)
        return
      }

      const finalAddressId = deliveryMethod === 'PICKUP' ? 'STORE_PICKUP' : (selectedAddressId || (addresses.length > 0 ? addresses[0].id : ''))
      
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          addressId: finalAddressId,
          paymentMethod,
          items,
          deliveryMethod,
          isB2B: false,
          scheduledSlot,
          shopName: 'FastKirana Dark Store',
          shopPhone: contactPhone,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        triggerHaptic('success')
        toast.success('Order placed successfully! Redirecting to tracking...')
        clearCart()
        router.push(`/order/${data.id}`)
      } else {
        toast.error(data.error || 'Failed to place order')
      }
    } catch (err) {
      toast.error('Connection error. Please try again.')
    } finally {
      setIsPlacingOrder(false)
    }
  }

  // Helper function to load Paytm script dynamically
  const loadPaytmScript = (mid: string, env: string): Promise<boolean> => {
    return new Promise((resolve) => {
      const host = env === 'prod' ? 'securegw.paytm.in' : 'securegw-stage.paytm.in'
      const scriptUrl = `https://${host}/merchantpgpui/checkoutjs/merchants/${mid}.js`
      
      const existingScript = document.getElementById('paytm-checkout-script')
      if (existingScript) {
        resolve(true)
        return
      }
      
      const script = document.createElement('script')
      script.type = 'text/javascript'
      script.src = scriptUrl
      script.id = 'paytm-checkout-script'
      script.onload = () => resolve(true)
      script.onerror = () => resolve(false)
      document.body.appendChild(script)
    })
  }

  // Run simulated checkout fallback if Paytm is offline
  const runSimulatedCheckout = async (orderId: string) => {
    const toastId = toast.loading('Paytm Staging Gateway is offline. Simulating payment fallback for local demo...')
    try {
      const res = await fetch('/api/payment/paytm/mock-success', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId }),
      })
      const data = await res.json()
      if (res.ok && data.success) {
        toast.dismiss(toastId)
        toast.success('Demo payment successful! Order confirmed.')
        triggerHaptic('success')
        clearCart()
        router.push(`/order/${orderId}`)
      } else {
        toast.dismiss(toastId)
        toast.error(data.error || 'Demo payment simulation failed')
        setIsPlacingOrder(false)
      }
    } catch (err) {
      toast.dismiss(toastId)
      toast.error('Failed to communicate with local checkout simulation service')
      setIsPlacingOrder(false)
    }
  }

  // Handle Paytm Payment Gateway Checkout
  const handlePaytmCheckout = async () => {
    setIsPlacingOrder(true)
    try {
      // 1. Fetch settings to check store status
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings = await settingsRes.json()
      
      const hasGrocery = items.some((item) => !isCafeProduct(item.product))
      const hasCafe = items.some((item) => isCafeProduct(item.product))
      
      if (hasGrocery && settings.grocery_mart_open === 'false') {
        triggerHaptic('warning')
        toast.error('Grocery Mart is temporarily closed. Cannot complete checkout.')
        setIsPlacingOrder(false)
        return
      }
      
      if (hasCafe && settings.cafe_open === 'false') {
        triggerHaptic('warning')
        toast.error('FastKirana Cafe is temporarily closed. Cannot complete checkout.')
        setIsPlacingOrder(false)
        return
      }

      if (deliveryMethod === 'DELIVERY') {
        const targetId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
        const selectedAddr = addresses.find((a) => a.id === targetId)
        if (selectedAddr) {
          const p = selectedAddr.pincode.trim()
          const c = selectedAddr.city.trim().toLowerCase()
          if (p !== '209206') {
            triggerHaptic('warning')
            toast.error('Selected address is outside our delivery zone. Please add/select a Ghatampur address (Pincode: 209206).')
            setIsPlacingOrder(false)
            return
          }
          if (!c.includes('ghatampur') && !c.includes('kanpur')) {
            triggerHaptic('warning')
            toast.error('Selected address city is outside our delivery zone. FastKirana only delivers to Ghatampur / Kanpur.')
            setIsPlacingOrder(false)
            return
          }
          const phoneVal = (selectedAddr.phone || '').trim().replace(/\D/g, '')
          const cleanPhone = phoneVal.length > 10 && phoneVal.startsWith('91') ? phoneVal.slice(-10) : phoneVal
          if (cleanPhone.length !== 10) {
            triggerHaptic('warning')
            toast.error('The selected address is missing a valid 10-digit mobile number. Please add a new address with a valid phone number.')
            setIsPlacingOrder(false)
            return
          }
        }
      }

      const finalAddressId = deliveryMethod === 'PICKUP' ? 'STORE_PICKUP' : (selectedAddressId || (addresses.length > 0 ? addresses[0].id : ''))
      
      // 2. Create the order in the database with PENDING payment status
      const orderRes = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          addressId: finalAddressId,
          paymentMethod: paymentMethod,
          items,
          deliveryMethod,
          isB2B: false,
          scheduledSlot,
          shopName: 'FastKirana Dark Store',
          shopPhone: contactPhone,
        }),
      })

      const orderData = await orderRes.json()

      if (!orderRes.ok) {
        toast.error(orderData.error || 'Failed to place order')
        setIsPlacingOrder(false)
        return
      }

      // 3. Initiate Paytm transaction to get txnToken
      let initiateData;
      try {
        const initiateRes = await fetch('/api/payment/paytm/initiate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ orderId: orderData.id }),
        })
        initiateData = await initiateRes.json()
        if (!initiateRes.ok) {
          console.warn('Paytm initiate failed:', initiateData.error)
          await runSimulatedCheckout(orderData.id)
          return
        }
      } catch (initiateError) {
        console.error('Failed to initiate Paytm payment:', initiateError)
        await runSimulatedCheckout(orderData.id)
        return
      }

      // 4. Load Paytm CheckoutJS script dynamically
      const scriptLoaded = await loadPaytmScript(initiateData.mid, initiateData.env)
      if (!scriptLoaded) {
        console.warn('Paytm script failed to load, falling back to simulation.')
        await runSimulatedCheckout(orderData.id)
        return
      }

      // 5. Initialize and invoke CheckoutJS
      const config = {
        root: "",
        flow: "DEFAULT",
        data: {
          orderId: initiateData.orderId,
          token: initiateData.txnToken,
          tokenType: "TXN_TOKEN",
          amount: initiateData.amount
        },
        handler: {
          notifyMerchant: (eventName: string, response: any) => {
            if (eventName === 'MERCHANT_CLOSE') {
              setIsPlacingOrder(false)
              toast.info('Payment window closed. You can retry from your orders page or select COD.')
            }
          }
        }
      }

      const paytmWindow = (window as any).Paytm
      if (paytmWindow && paytmWindow.CheckoutJS) {
        paytmWindow.CheckoutJS.init(config).then(() => {
          paytmWindow.CheckoutJS.invoke()
        }).catch(async (err: any) => {
          console.error('Paytm CheckoutJS init error:', err)
          await runSimulatedCheckout(orderData.id)
        })
      } else {
        console.warn('Paytm SDK window object not available, falling back to simulation.')
        await runSimulatedCheckout(orderData.id)
      }

    } catch (err) {
      console.error('Paytm checkout exception:', err)
      toast.error('An unexpected error occurred during checkout.')
      setIsPlacingOrder(false)
    }
  }

  const handlePlaceOrderClick = () => {
    if (deliveryMethod === 'DELIVERY' && !selectedAddressId) {
      toast.error('Please select a delivery address')
      return
    }

    if (paymentMethod !== 'COD') {
      handlePaytmCheckout()
    } else {
      handlePlaceOrder()
    }
  }

  if (items.length === 0) {
    return (
      <div className="container mx-auto px-4 py-16 text-center max-w-md space-y-6">
        <span className="text-6xl block">🛒</span>
        <h1 className="text-xl font-bold">Your cart is empty</h1>
        <Link href="/" className="inline-block bg-primary text-white px-6 py-3 rounded-xl font-bold">
          Explore Products
        </Link>
      </div>
    )
  }

  const hasGrocery = items.some((item) => !isCafeProduct(item.product))
  const hasCafe = items.some((item) => isCafeProduct(item.product))
  const isStoreClosed = (hasGrocery && !groceryMartOpen) || (hasCafe && !cafeOpen)

  if (isStoreClosed && !isSettingsLoading) {
    return (
      <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
        <div className="h-20 w-20 bg-amber-50 dark:bg-amber-950/20 text-amber-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner animate-pulse-gentle border border-amber-200/60 dark:border-amber-900/40">
          🏪
        </div>
        <h1 className="text-2xl font-black text-text-primary">Store Closed Temporarily</h1>
        <p className="text-sm text-text-secondary leading-relaxed">
          {hasGrocery && !groceryMartOpen && hasCafe && !cafeOpen ? (
            "Both our Grocery Mart and Cafe are temporarily closed and not accepting orders right now. Please check back later!"
          ) : hasGrocery && !groceryMartOpen ? (
            "Our Grocery Mart is temporarily closed. You can proceed with Cafe items by removing grocery items from your cart."
          ) : (
            "Our Cafe is temporarily closed. You can proceed with Grocery items by removing cafe items from your cart."
          )}
        </p>
        <div className="pt-4 flex flex-col gap-3">
          <Link
            href="/cart"
            className="px-6 py-3 bg-primary text-white font-black text-xs rounded-full hover:bg-primary/95 transition-all shadow-md active:scale-98 text-center"
          >
            Go Back to Cart
          </Link>
          <Link
            href="/"
            className="px-6 py-3 border-2 border-border text-text-secondary font-black text-xs rounded-full hover:bg-muted/30 transition-all active:scale-98 text-center"
          >
            Continue Browsing
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-5xl space-y-6 md:space-y-8 pb-28 md:pb-8">
      {/* Premium Header */}
      <div className="flex items-center justify-between border-b border-border pb-4">
        <div>
          <h1 className="text-xl md:text-2xl font-black text-text-primary flex items-center gap-2">
            <span>⚡</span> Quick Checkout
          </h1>
          <p className="text-[11px] md:text-xs text-text-secondary mt-0.5">
            Confirm your order details below to place order instantly
          </p>
        </div>
        <div className="hidden lg:flex items-center gap-2 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 px-3 py-1.5 rounded-full text-xs font-extrabold border border-emerald-500/20">
          <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
          Secured Checkout
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        {/* Left: Checkout Details */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* Main Checkout Box */}
          <div className="bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-6 md:space-y-8 animate-fade-in">
              <div className="space-y-4">
                <h2 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
                  <MapPin className="h-5 w-5 text-primary" />
                  Choose Fulfillment Method
                </h2>

                {/* Fulfillment Option */}
                <div className="grid grid-cols-2 gap-3 md:gap-4">
                  <div
                    onClick={() => setDeliveryMethod('DELIVERY')}
                    className={cn(
                      "flex flex-col items-center justify-center p-3 min-[375px]:p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 text-center gap-2",
                      deliveryMethod === 'DELIVERY' ? "border-primary bg-primary/5 shadow-sm text-primary" : "border-border hover:border-primary/40 text-text-secondary"
                    )}
                  >
                    <span className="text-2xl">🚚</span>
                    <span className="text-sm font-bold">Home Delivery</span>
                    <span className="text-[10px] text-text-muted">Delivered to your doorstep</span>
                  </div>
                  <div
                    onClick={() => setDeliveryMethod('PICKUP')}
                    className={cn(
                      "flex flex-col items-center justify-center p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 text-center gap-2",
                      deliveryMethod === 'PICKUP' ? "border-primary bg-primary/5 shadow-sm text-primary" : "border-border hover:border-primary/40 text-text-secondary"
                    )}
                  >
                    <span className="text-2xl">🏪</span>
                    <span className="text-sm font-bold">Self-Pickup</span>
                    <span className="text-[10px] text-text-muted">Waived delivery fee (Save ₹25)</span>
                  </div>
                </div>

                {deliveryMethod === 'PICKUP' ? (
                  <div className="rounded-xl border border-primary/20 bg-primary/5 p-5 space-y-3">
                    <div className="flex items-start gap-3">
                      <span className="text-2xl">🏪</span>
                      <div>
                        <h4 className="text-sm font-bold text-text-primary">FastKirana Ghatampur Hub</h4>
                        <p className="text-xs text-text-secondary leading-relaxed mt-1">
                          {contactAddress}
                        </p>
                        <p className="text-xs text-text-secondary mt-1">
                          Pin: 209206 | Phone: <span className="font-semibold text-primary">{formatPhone(contactPhone)}</span>
                        </p>
                        <div className="mt-3 text-[10px] text-accent font-bold bg-accent/10 px-2 py-1 rounded inline-block">
                          ✓ Self-Pickup Selected: No delivery charge
                        </div>
                      </div>
                    </div>
                  </div>
                ) : (
                  isAddressesLoading ? (
                    <div className="flex justify-center py-10">
                      <Loader2 className="h-6 w-6 animate-spin text-primary" />
                    </div>
                  ) : (
                    <div id="address-section" className="space-y-4 scroll-mt-24">
                      {addresses.map((addr) => (
                        <div
                          key={addr.id}
                          onClick={() => setSelectedAddressId(addr.id)}
                          className={cn(
                            "flex items-start gap-3.5 p-4 rounded-2xl border-2 cursor-pointer transition-all duration-300 relative overflow-hidden bg-white dark:bg-zinc-900/50",
                            selectedAddressId === addr.id
                              ? "border-primary bg-primary/[0.01] shadow-[0_4px_20px_rgba(251,37,118,0.06)]"
                              : "border-border/60 hover:border-primary/30"
                          )}
                        >
                          {/* Premium Radio Selector */}
                          <div className={cn(
                            "w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 mt-0.5 transition-all duration-200",
                            selectedAddressId === addr.id ? "border-primary bg-primary" : "border-border"
                          )}>
                            {selectedAddressId === addr.id && (
                              <div className="w-2 h-2 rounded-full bg-white" />
                            )}
                          </div>
                          
                          <div className="flex-grow text-xs">
                            <div className="flex items-center gap-2 mb-1.5">
                              <span className="font-bold text-[10px] text-text-primary uppercase bg-muted px-2 py-0.5 rounded-md tracking-wider">
                                {addr.label}
                              </span>
                              {addr.isDefault && (
                                <span className="text-[9px] text-accent font-bold bg-accent/10 px-2 py-0.5 rounded-md">
                                  Default
                                </span>
                              )}
                            </div>
                            <p className="text-text-secondary leading-relaxed font-semibold">
                              {formatAddress(addr)}
                            </p>
                            {addr.phone && (
                              <p className="text-[10px] text-text-secondary mt-1.5 font-bold flex items-center gap-1">
                                <span className="opacity-80">📞</span> Phone: <span className="text-text-primary">{formatPhone(addr.phone)}</span>
                              </p>
                            )}
                          </div>
                        </div>
                      ))}

                      {/* Add New Address Button */}
                      {!showNewAddressForm && (
                        <Button
                          onClick={() => setShowNewAddressForm(true)}
                          variant="outline"
                          className="w-full border-dashed border-2 hover:border-primary/50 hover:bg-primary/[0.02] rounded-2xl h-12 transition-all font-bold text-xs"
                        >
                          <Plus className="h-4 w-4 mr-1.5 text-primary" />
                          Add New Address
                        </Button>
                      )}

                      {/* New Address Collapsible Form */}
                      {showNewAddressForm && (
                        <form id="new-address-form" onSubmit={handleSaveAddress} className="border border-border/80 p-5 sm:p-6 rounded-2xl space-y-5 bg-card/60 backdrop-blur-sm animate-slide-up shadow-sm">
                          <div className="flex justify-between items-center border-b border-border/40 pb-3">
                            <h3 className="font-black text-sm text-text-primary text-primary flex items-center gap-2">
                              <MapPin className="h-4 w-4 text-primary animate-pulse" />
                              Choose Delivery Location
                            </h3>
                          </div>
                          
                          {addressForm.lat && addressForm.lng && (
                            <div className="text-xs text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/20 p-3 rounded-xl border border-emerald-200/50 dark:border-emerald-900/30 flex items-center gap-2 font-bold">
                              <span className="text-sm shrink-0">📍</span>
                              <span>GPS Location Pinned! Coordinates: {addressForm.lat.toFixed(6)}, {addressForm.lng.toFixed(6)}</span>
                            </div>
                          )}
                          
                          <div className="text-xs text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/20 p-3.5 rounded-xl border border-blue-200/50 dark:border-blue-900/30 flex items-start gap-2.5 leading-relaxed font-medium">
                            <span className="text-base shrink-0 mt-0.5">ℹ️</span>
                            <span>
                              <strong>Ordering for someone else?</strong> Drag the map marker to pin your exact address. If ordering for a home in Ghatampur while elsewhere, use the search bar or drag the pin manually.
                            </span>
                          </div>

                          {/* Interactive Swiggy/Zomato Map Picker */}
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
                          
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                            <div>
                              <Label htmlFor="phone" className="text-xs font-bold text-text-primary flex items-center gap-1">
                                Phone Number <span className="text-red-500 font-bold">*</span>
                              </Label>
                              <Input
                                id="phone"
                                type="tel"
                                required
                                placeholder="Enter 10-digit mobile number"
                                value={addressForm.phone}
                                onChange={(e) => setAddressForm({ ...addressForm, phone: e.target.value.replace(/\D/g, '') })}
                                className="mt-1.5 h-11 text-xs font-semibold rounded-xl border-border focus-visible:ring-primary focus-visible:border-primary bg-background"
                              />
                            </div>
                            <div>
                              <Label className="text-xs font-bold text-text-primary">Address Label</Label>
                              <div className="flex gap-2.5 mt-1.5">
                                {['Home', 'Work'].map((lbl) => (
                                  <button
                                    key={lbl}
                                    type="button"
                                    onClick={() => setAddressForm({ ...addressForm, label: lbl })}
                                    className={cn(
                                      "px-4 py-2 h-11 text-xs font-bold rounded-xl border transition-all flex items-center gap-1.5 select-none w-full justify-center active:scale-95",
                                      addressForm.label === lbl
                                        ? "bg-primary text-white border-primary shadow-md"
                                        : "bg-background border-border text-text-secondary hover:border-primary/40 hover:bg-muted/10"
                                    )}
                                  >
                                    <span>{lbl === 'Home' ? '🏠' : '🏢'}</span>
                                    <span>{lbl}</span>
                                  </button>
                                ))}
                              </div>
                            </div>
                          </div>

                          <div>
                            <Label htmlFor="pincode" className="text-xs font-bold text-text-primary flex items-center gap-1">
                              Pincode (6 digits) <span className="text-red-500 font-bold">*</span>
                            </Label>
                            <Input
                              id="pincode"
                              required
                              maxLength={6}
                              placeholder="e.g. 209206"
                              value={addressForm.pincode}
                              onChange={(e) => setAddressForm({ ...addressForm, pincode: e.target.value })}
                              className="mt-1.5 h-11 text-xs font-semibold rounded-xl border-border focus-visible:ring-primary focus-visible:border-primary bg-background"
                            />
                          </div>

                          <div>
                            <Label htmlFor="street" className="text-xs font-bold text-text-primary flex items-center gap-1">
                              Complete Delivery Address <span className="text-red-500 font-bold">*</span>
                            </Label>
                            <textarea
                              id="street"
                              required
                              rows={3}
                              placeholder="Enter landmark, house number, building, road, and locality details..."
                              value={addressForm.street}
                              onChange={(e) => setAddressForm({ ...addressForm, street: e.target.value })}
                              className="mt-1.5 block w-full rounded-xl border border-border bg-background px-3.5 py-2.5 text-xs font-semibold focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary focus:ring-offset-0 placeholder:text-text-muted/60"
                            />
                          </div>

                          <div className="flex gap-3 justify-end pt-3">
                            <Button
                              type="button"
                              variant="ghost"
                              onClick={() => setShowNewAddressForm(false)}
                              disabled={isSavingAddress}
                              className="rounded-xl text-xs font-bold hover:bg-muted h-10 px-4"
                            >
                              Cancel
                            </Button>
                            <Button
                              type="submit"
                              className="bg-primary text-white rounded-xl text-xs font-black px-5 h-10 hover:bg-primary/95 shadow-md active:scale-98 transition-all"
                              disabled={isSavingAddress}
                            >
                              {isSavingAddress ? (
                                <span className="flex items-center gap-1.5">
                                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                                  Saving...
                                </span>
                              ) : 'Save & Select'}
                            </Button>
                          </div>
                        </form>
                      )}
                    </div>
                  )
                )}
              </div>



              {/* Cart Items Review */}
              <div className="border-t border-border/40 pt-5 md:pt-6 space-y-4">
                <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                  <ShoppingBag className="h-5 w-5 text-primary" />
                  Review Your Cart Items
                </h3>

                <div className="divide-y divide-border/40 max-h-60 overflow-y-auto pr-1">
                  {items.map((item) => (
                    <div key={item.product.id} className="flex justify-between items-center py-3 first:pt-0 last:pb-0 text-xs font-semibold">
                      <div className="max-w-[70%]">
                        <h4 className="text-text-primary font-bold">{item.product.name}</h4>
                        <p className="text-[10px] text-text-secondary mt-0.5">{item.product.unit} × {item.quantity}</p>
                      </div>
                      <span className="text-text-primary font-bold">₹{item.product.price * item.quantity}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Integrated Payment Method Selection */}
              <div className="border-t border-border/40 pt-5 md:pt-6 space-y-4">
                <h2 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
                  <CreditCard className="h-5 w-5 text-primary" />
                  Choose Payment Method
                </h2>

                {onlyCod && (
                  <div className="border border-amber-500/20 bg-amber-500/5 p-4 rounded-xl text-xs font-semibold text-amber-600 dark:text-amber-400 flex items-center gap-2">
                    <span>ℹ️</span>
                    <span>Online payment options are temporarily disabled by the store. Please proceed with Cash on Delivery / Cash on Pickup.</span>
                  </div>
                )}

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Cash on Delivery */}
                  <div
                    onClick={() => setPaymentMethod('COD')}
                    className={cn(
                      "flex items-start gap-3.5 p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 hover:bg-muted/30",
                      paymentMethod === 'COD' ? "border-primary bg-primary/5" : "border-border hover:border-primary/30"
                    )}
                  >
                    <input
                      type="radio"
                      checked={paymentMethod === 'COD'}
                      onChange={() => setPaymentMethod('COD')}
                      className="cursor-pointer mt-1"
                    />
                    <div className="flex-grow">
                      <div className="flex items-center gap-2">
                        <span className="text-lg">💵</span>
                        <h4 className="text-sm font-bold text-text-primary">
                          {deliveryMethod === 'PICKUP' ? 'Cash on Pickup (COP)' : 'Cash on Delivery (COD)'}
                        </h4>
                      </div>
                      <p className="text-[10px] text-text-secondary mt-1 font-semibold leading-relaxed">
                        {deliveryMethod === 'PICKUP' ? 'Pay in cash or UPI at the store' : 'Pay in cash or UPI at the door'}
                      </p>
                    </div>
                  </div>

                  {!onlyCod && (
                    <>
                      {/* Instant UPI */}
                      <div
                        onClick={() => setPaymentMethod('UPI')}
                        className={cn(
                          "flex items-start gap-3.5 p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 hover:bg-muted/30",
                          paymentMethod === 'UPI' ? "border-primary bg-primary/5" : "border-border hover:border-primary/30"
                        )}
                      >
                        <input
                          type="radio"
                          checked={paymentMethod === 'UPI'}
                          onChange={() => setPaymentMethod('UPI')}
                          className="cursor-pointer mt-1"
                        />
                        <div className="flex-grow">
                          <div className="flex items-center gap-2">
                            <span className="text-lg">📱</span>
                            <h4 className="text-sm font-bold text-text-primary">Google Pay / PhonePe / Paytm UPI</h4>
                          </div>
                          <p className="text-[10px] text-text-secondary mt-1 font-semibold leading-relaxed">
                            Pay instantly from your mobile screen using any installed UPI application
                          </p>
                        </div>
                      </div>

                      {/* Credit / Debit Card */}
                      <div
                        onClick={() => setPaymentMethod('CARD')}
                        className={cn(
                          "flex items-start gap-3.5 p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 hover:bg-muted/30",
                          paymentMethod === 'CARD' ? "border-primary bg-primary/5" : "border-border hover:border-primary/30"
                        )}
                      >
                        <input
                          type="radio"
                          checked={paymentMethod === 'CARD'}
                          onChange={() => setPaymentMethod('CARD')}
                          className="cursor-pointer mt-1"
                        />
                        <div className="flex-grow">
                          <div className="flex items-center gap-2">
                            <span className="text-lg">💳</span>
                            <h4 className="text-sm font-bold text-text-primary">Credit / Debit Card</h4>
                          </div>
                          <p className="text-[10px] text-text-secondary mt-1 font-semibold leading-relaxed">
                            Pay securely with Visa, MasterCard, RuPay, Maestro, or Diner's Club cards
                          </p>
                        </div>
                      </div>

                      {/* Paytm Wallet / Netbanking */}
                      <div
                        onClick={() => setPaymentMethod('WALLET')}
                        className={cn(
                          "flex items-start gap-3.5 p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 hover:bg-muted/30",
                          paymentMethod === 'WALLET' ? "border-primary bg-primary/5" : "border-border hover:border-primary/30"
                        )}
                      >
                        <input
                          type="radio"
                          checked={paymentMethod === 'WALLET'}
                          onChange={() => setPaymentMethod('WALLET')}
                          className="cursor-pointer mt-1"
                        />
                        <div className="flex-grow">
                          <div className="flex items-center gap-2">
                            <span className="text-lg">🏦</span>
                            <h4 className="text-sm font-bold text-text-primary">Wallet & Netbanking</h4>
                          </div>
                          <p className="text-[10px] text-text-secondary mt-1 font-semibold leading-relaxed">
                            Pay using Paytm Wallet, Amazon Pay, Mobikwik, or Netbanking (SBI, HDFC, ICICI, etc.)
                          </p>
                        </div>
                      </div>
                    </>
                  )}
                </div>
              </div>

              {/* Secure Transaction notice */}
              <div className="flex items-center gap-2 border border-accent/20 bg-accent/5 p-3 rounded-xl text-xs font-semibold text-accent">
                <ShieldCheck className="h-5 w-5" />
                Your transaction is simulated safely for local demonstration.
              </div>

              {/* Place Order Button (Desktop Only) */}
              <div className="hidden md:block border-t border-border/40 pt-5 md:pt-6">
                <SlideToOrder
                  onConfirm={() => {
                    if (showNewAddressForm) {
                      toast.error('Please save your new address first by clicking Save & Select')
                      return
                    }
                    if (deliveryMethod === 'DELIVERY' && !selectedAddressId) {
                      toast.error('Please select or add a delivery address')
                      return
                    }
                    handlePlaceOrderClick()
                  }}
                  isPlacingOrder={isPlacingOrder}
                  disabled={showNewAddressForm || (deliveryMethod === 'DELIVERY' && !selectedAddressId)}
                  amount={grandTotal}
                />
              </div>
            </div>
        </div>

        {/* Right Column: Mini Bill Summary (Persistent) */}
        <div className="bg-white/80 dark:bg-zinc-900/85 backdrop-blur-md border border-white/60 dark:border-zinc-800/60 p-5 rounded-2xl shadow-[0_8px_30px_rgb(0,0,0,0.02)] h-fit space-y-5">

          
          <h3 className="text-sm font-black text-text-primary border-b border-border/40 pb-2 flex items-center gap-1.5">
            <span>🧾</span> Order Calculation
          </h3>

          {/* Grocery Bill Section */}
          {groceryCartItems.length > 0 && (
            <div className="space-y-2.5">
              <div className="flex items-center justify-between text-xs font-black text-primary bg-primary/5 px-2 py-1 rounded">
                <span>📦 Grocery Bill</span>
                <span>{groceryCartItems.length} items</span>
              </div>
              <div className="space-y-1.5 text-xs font-semibold pl-1">
                <div className="flex justify-between text-text-secondary">
                  <span>Subtotal</span>
                  <span>₹{grocerySubtotal.toFixed(0)}</span>
                </div>
                {grocerySavings + groceryB2BDiscount > 0 && (
                  <div className="flex justify-between text-accent font-bold">
                    <span>Savings</span>
                    <span>-₹{(grocerySavings + groceryB2BDiscount).toFixed(0)}</span>
                  </div>
                )}
                <div className="flex justify-between text-text-secondary">
                  <span>Delivery Fee</span>
                  <span className={cn(groceryDeliveryFee === 0 ? "text-accent font-bold" : "")}>
                    {groceryDeliveryFee === 0 ? 'FREE' : `₹${groceryDeliveryFee}`}
                  </span>
                </div>
                <div className="flex justify-between text-text-secondary">
                  <span>GST / Taxes ({Math.round(taxRate * 100)}%)</span>
                  <span>₹{groceryTaxes.toFixed(0)}</span>
                </div>
                {miscFee > 0 && (
                  <div className="flex justify-between text-text-secondary">
                    <span>{miscFeeLabel}</span>
                    <span>₹{miscFee.toFixed(0)}</span>
                  </div>
                )}
                <div className="flex justify-between text-text-primary font-bold border-t border-border/20 pt-1">
                  <span>Grocery Total</span>
                  <span>₹{groceryTotal.toFixed(0)}</span>
                </div>
              </div>
            </div>
          )}

          {/* Cafe Bill Section */}
          {cafeCartItems.length > 0 && (
            <div className="space-y-2.5 pt-1">
              <div className="flex items-center justify-between text-xs font-black text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950/20 px-2 py-1 rounded">
                <span>☕ Cafe Bill</span>
                <span>{cafeCartItems.length} items</span>
              </div>
              <div className="space-y-1.5 text-xs font-semibold pl-1">
                <div className="flex justify-between text-text-secondary">
                  <span>Subtotal</span>
                  <span>₹{cafeSubtotal.toFixed(0)}</span>
                </div>
                {cafeSavings + cafeB2BDiscount > 0 && (
                  <div className="flex justify-between text-accent font-bold">
                    <span>Savings</span>
                    <span>-₹{(cafeSavings + cafeB2BDiscount).toFixed(0)}</span>
                  </div>
                )}
                <div className="flex justify-between text-text-secondary">
                  <span>Delivery Fee</span>
                  <span className={cn(cafeDeliveryFee === 0 ? "text-accent font-bold" : "")}>
                    {cafeDeliveryFee === 0 ? 'FREE' : `₹${cafeDeliveryFee}`}
                  </span>
                </div>
                <div className="flex justify-between text-text-secondary">
                  <span>GST / Taxes ({Math.round(taxRate * 100)}%)</span>
                  <span>₹{cafeTaxes.toFixed(0)}</span>
                </div>
                {miscFee > 0 && groceryCartItems.length === 0 && (
                  <div className="flex justify-between text-text-secondary">
                    <span>{miscFeeLabel}</span>
                    <span>₹{miscFee.toFixed(0)}</span>
                  </div>
                )}
                <div className="flex justify-between text-text-primary font-bold border-t border-border/20 pt-1">
                  <span>Cafe Total</span>
                  <span>₹{cafeTotal.toFixed(0)}</span>
                </div>
              </div>
            </div>
          )}

          {/* Combined Grand Total */}
          <div className="border-t-2 border-dashed border-border/60 pt-4 mt-4 space-y-2">
            <div className="flex justify-between text-base font-black text-text-primary">
              <span>Grand Total</span>
              <span className="text-primary text-lg">₹{grandTotal.toFixed(0)}</span>
            </div>
          </div>
          
          <div className="text-[10px] text-text-muted text-center pt-2 leading-relaxed">
            By placing the order you agree to our terms & conditions.
          </div>
        </div>

      </div>

      {/* Mobile Sticky Bottom Checkout Bar (Zepto/Blinkit Style) */}
      <div 
        className="fixed bottom-0 left-0 right-0 z-40 md:hidden bg-white dark:bg-zinc-950 border-t border-border/80 shadow-[0_-8px_30px_rgba(0,0,0,0.08)] px-4 py-3.5 flex items-center justify-between"
        style={{ paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 14px)' }}
      >
        <div className="flex flex-col">
          <span className="text-[9px] text-text-secondary font-medium leading-none">Grand Total</span>
          <span className="text-base font-black text-primary mt-1">₹{grandTotal.toFixed(0)}</span>
          <div className="text-[9px] text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-0.5 mt-0.5 max-w-[140px] truncate">
            {deliveryMethod === 'PICKUP' ? (
              <span>🏪 Store Pickup</span>
            ) : selectedAddress ? (
              <span className="truncate">📍 {selectedAddress.street}</span>
            ) : (
              <span className="text-rose-500">📍 Select Address</span>
            )}
          </div>
        </div>

        <button
          type="button"
          disabled={isPlacingOrder || showNewAddressForm || (deliveryMethod === 'DELIVERY' && !selectedAddressId)}
          onClick={() => {
            if (showNewAddressForm) {
              toast.error('Please save your new address first by clicking Save & Select')
              return
            }
            if (deliveryMethod === 'DELIVERY' && !selectedAddressId) {
              toast.error('Please select or add a delivery address')
              const el = document.getElementById('address-section')
              if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
              return
            }
            handlePlaceOrderClick()
          }}
          className={cn(
            "bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 text-white rounded-full font-black text-xs tracking-wider uppercase px-6 h-11 shadow-md transition-all active:scale-95 flex items-center justify-center gap-1.5",
            (isPlacingOrder || showNewAddressForm || (deliveryMethod === 'DELIVERY' && !selectedAddressId)) && "opacity-60 cursor-not-allowed"
          )}
        >
          {isPlacingOrder ? (
            <>
              <Loader2 className="h-3.5 w-3.5 animate-spin text-white" />
              <span>Processing...</span>
            </>
          ) : (
            <>
              <span>Place Order</span>
              <ChevronsRight className="h-3.5 w-3.5 text-white animate-bounce" style={{ animationDuration: '1.5s' }} />
            </>
          )}
        </button>
      </div>
    </div>
  )
}
