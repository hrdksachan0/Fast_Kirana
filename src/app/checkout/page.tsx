'use client'

import { useState, useEffect, useRef } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { useCart } from '@/hooks/use-cart'
import { useCartStore } from '@/stores/cart-store'
import type { CartItem } from '@/stores/cart-store'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn, isCafeProduct, formatPhone, formatAddress, formatPrice } from '@/lib/utils'
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
  X,
} from 'lucide-react'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import { Address } from '@/types'
import MapPicker from '@/components/shared/map-picker'
import { getDistanceKm, getDeliveryRules } from '@/lib/distance'
import { getLast10Digits, isValidIndianPhone } from '@/lib/phone'
import { formatTime12h, isNearClosing } from '@/lib/date-helpers'
import {
  validateCheckoutEligibility,
  buildOrderPayload,
  resolveStoreLat,
  resolveStoreLng,
  resolveStorePincode,
  resolveStorePhone,
  resolveStoreAddress,
  resolveShopName,
  resolveMinOrder,
  DEFAULT_STORE_PINCODE,
  DEFAULT_STORE_LAT,
  DEFAULT_STORE_LNG,
  DEFAULT_CONTACT_PHONE,
  DEFAULT_CONTACT_ADDRESS,
  DEFAULT_SHOP_NAME,
  DEFAULT_MIN_ORDER,
  DEFAULT_DELIVERY_RADIUS_KM,
  type SettingsMap,
} from '@/lib/checkout'

interface SlideToOrderProps {
  onConfirm: () => void
  isPlacingOrder: boolean
  disabled?: boolean
  amount: number
}

function SlideToOrder({ onConfirm, isPlacingOrder, amount }: SlideToOrderProps) {
  return (
    <button
      type="button"
      disabled={isPlacingOrder}
      onClick={onConfirm}
      className={cn(
        "group relative overflow-hidden w-full h-14 bg-gradient-to-r from-accent to-accent-dark text-white rounded-full font-black text-sm sm:text-base tracking-wide uppercase transition-all duration-300 hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg shadow-accent/25 hover:shadow-xl hover:shadow-accent/45",
        isPlacingOrder && "opacity-60 cursor-not-allowed shadow-none"
      )}
    >
      {isPlacingOrder ? (
        <>
          <Loader2 className="h-4 w-4 animate-spin text-white relative z-10" />
          <span className="relative z-10">Processing Order...</span>
        </>
      ) : (
        <>
          <span className="relative z-10">Place Order (₹{amount.toFixed(0)})</span>
          <ChevronsRight className="h-4 w-4 text-white relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
        </>
      )}
    </button>
  )
}

export default function CheckoutPage() {

  const router = useRouter()
  const { data: session } = useSession()
  const prefilledPhoneRef = useRef(false)
  const { items, removeItem, clearCart, getSubtotal, getSavings, getMrpTotal, updateQuantity, updateCartProduct } = useCart()
  const appliedCouponCode = useCartStore((s) => s.appliedCouponCode)
  const [appliedCoupon, setAppliedCoupon] = useState<{
    code: string
    discountAmount: number
  } | null>(null)
  const [isValidatingCoupon, setIsValidatingCoupon] = useState(false)

  const [addresses, setAddresses] = useState<Address[]>([])
  const [selectedAddressId, setSelectedAddressId] = useState<string>('')
  const [deliveryRadius, setDeliveryRadius] = useState(DEFAULT_DELIVERY_RADIUS_KM)
  const [storeLat, setStoreLat] = useState(DEFAULT_STORE_LAT)
  const [storeLng, setStoreLng] = useState(DEFAULT_STORE_LNG)
  const [onlyCod, setOnlyCod] = useState(false)
  const [taxRate, setTaxRate] = useState(0.00)
  const [miscFee, setMiscFee] = useState(0.0)
  const [miscFeeLabel, setMiscFeeLabel] = useState('Miscellaneous Additions')
  const [contactPhone, setContactPhone] = useState(DEFAULT_CONTACT_PHONE)
  const [contactAddress, setContactAddress] = useState(DEFAULT_CONTACT_ADDRESS)
  const [groceryPickupAddress, setGroceryPickupAddress] = useState('')
  const [cafePickupAddress, setCafePickupAddress] = useState('')
  const [restaurantPickupAddress, setRestaurantPickupAddress] = useState('')
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [restaurantOpen, setRestaurantOpen] = useState(true)
  const [storeSettingsMap, setStoreSettingsMap] = useState<Record<string, string>>({})
  const [isSettingsLoading, setIsSettingsLoading] = useState(true)
  const [groceryThreshold, setGroceryThreshold] = useState(GROCERY_FREE_DELIVERY_THRESHOLD)
  const [cafeThreshold, setCafeThreshold] = useState(CAFE_FREE_DELIVERY_THRESHOLD)
  const [combinedThreshold, setCombinedThreshold] = useState(COMBINED_FREE_DELIVERY_THRESHOLD)
  const [deliveryFeeVal, setDeliveryFeeVal] = useState(DELIVERY_FEE)
  const [groceryCloseTime, setGroceryCloseTime] = useState('23:59')
  const [cafeCloseTime, setCafeCloseTime] = useState('23:59')
  const [restaurantsList, setRestaurantsList] = useState<any[]>([])

  useEffect(() => {
    fetch('/api/restaurants')
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) setRestaurantsList(data)
      })
      .catch(() => {})
  }, [])


  useEffect(() => {
    fetch('/api/settings', { cache: 'no-store' })
      .then(res => res.json())
      .then(data => {
        if (data && typeof data === 'object') {
          setStoreSettingsMap(data)
        }
        if (data.grocery_mart_open !== undefined) {
          setGroceryMartOpen(data.grocery_mart_open === 'true')
        }
        if (data.cafe_open !== undefined) {
          setCafeOpen(data.cafe_open === 'true')
        }
        if (data.restaurant_open !== undefined) {
          setRestaurantOpen(data.restaurant_open === 'true')
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
          setTaxRate(0.00)
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
        if (data.grocery_pickup_address) {
          setGroceryPickupAddress(data.grocery_pickup_address)
        }
        if (data.cafe_pickup_address) {
          setCafePickupAddress(data.cafe_pickup_address)
        }
        if (data.restaurant_pickup_address) {
          setRestaurantPickupAddress(data.restaurant_pickup_address)
        }
        if (data.grocery_free_delivery_threshold) {
          setGroceryThreshold(parseFloat(data.grocery_free_delivery_threshold))
        }
        if (data.cafe_free_delivery_threshold) {
          setCafeThreshold(parseFloat(data.cafe_free_delivery_threshold))
        }
        if (data.combined_free_delivery_threshold) {
          setCombinedThreshold(parseFloat(data.combined_free_delivery_threshold))
        }
        if (data.delivery_fee) {
          setDeliveryFeeVal(parseFloat(data.delivery_fee))
        }
        if (data.grocery_close_time) {
          setGroceryCloseTime(data.grocery_close_time)
        }
        if (data.cafe_close_time) {
          setCafeCloseTime(data.cafe_close_time)
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
                removeItem(update.productId, update.name)
                toast.error(`"${update.name}" is currently out of stock and was removed from your cart.`, {
                  id: `checkout-out-of-stock-${update.productId}`,
                  duration: 6000,
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
  const [editingAddressId, setEditingAddressId] = useState<string | null>(null)
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
    pincode: DEFAULT_STORE_PINCODE,
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
      const digits = getLast10Digits(phoneVal)
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
        const dist = getDistanceKm(storeLat, storeLng, latitude, longitude)

        if (dist > deliveryRadius) {
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
              const streetName = streetParts.length > 0 ? streetParts.join(', ') : firstResult.formatted_address.split(',')[0]

              setAddressForm(prev => ({
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
  const [isPaymentModalOpen, setIsPaymentModalOpen] = useState(false)
  const [deliveryMethod, setDeliveryMethod] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY')
  const [scheduledSlot, setScheduledSlot] = useState<string>('INSTANT')
  const [packagingOption, setPackagingOption] = useState<'NORMAL' | 'PREMIUM'>('NORMAL')

  const selectedAddress = addresses.find((a) => a.id === selectedAddressId)

  // Calculations for checkout items
  const subtotal = getSubtotal()

  const hasCafeItems = items.some(item => isCafeProduct(item.product))
  const hasGroceryItems = items.some(item => !isCafeProduct(item.product))

  const isCafeNearClosing = hasCafeItems && isNearClosing(cafeCloseTime) && cafeOpen
  const isGroceryNearClosing = hasGroceryItems && isNearClosing(groceryCloseTime) && groceryMartOpen


  // Auto-validate coupon on checkout page load
  useEffect(() => {
    if (appliedCouponCode && items.length > 0) {
      setIsValidatingCoupon(true)
      fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: appliedCouponCode,
          subtotal,
          items: items.map(i => ({
            id: i.product.id,
            price: i.product.price,
            categoryId: i.product.category?.id,
            quantity: i.quantity
          }))
        })
      })
      .then(res => {
        if (res.ok) return res.json()
        throw new Error('Invalid')
      })
      .then(data => {
        setAppliedCoupon({
          code: data.coupon.code,
          discountAmount: data.coupon.discountAmount,
        })
      })
      .catch(() => {
        useCartStore.getState().setAppliedCouponCode(null)
        setAppliedCoupon(null)
      })
      .finally(() => {
        setIsValidatingCoupon(false)
      })
    } else {
      setAppliedCoupon(null)
    }
  }, [appliedCouponCode, items.length, subtotal])
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
  const groceryTaxes = groceryAdjustedSubtotal * taxRate

  // Cafe Calculations
  const cafeSubtotal = cafeCartItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const cafeMrpSubtotal = cafeCartItems.reduce((sum, item) => sum + item.product.mrp * item.quantity, 0)
  const cafeSavings = cafeMrpSubtotal - cafeSubtotal
  const cafeB2BDiscount = 0
  const cafeAdjustedSubtotal = cafeSubtotal - cafeB2BDiscount
  const cafeTaxes = cafeAdjustedSubtotal * taxRate

  // 1. Calculate distance-based delivery rules if address has coords
  let distanceKm: number | null = null
  let deliveryRules: any = null
  let isBelowMinOrder = subtotal < 20
  let minOrderRequired = 20

  if (deliveryMethod === 'DELIVERY' && selectedAddress) {
    if (selectedAddress.lat && selectedAddress.lng) {
      const maxRadiusKm = parseFloat(storeSettingsMap['delivery_radius'] || storeSettingsMap['max_delivery_radius'] || '2.0')
      const surgeFee = parseFloat(storeSettingsMap['surge_charge'] || '0')
      distanceKm = getDistanceKm(storeLat, storeLng, selectedAddress.lat, selectedAddress.lng)
      deliveryRules = getDeliveryRules(distanceKm, { maxRadiusKm, surgeFee })
    }
  }

  let groceryDeliveryFee = 0
  let cafeDeliveryFee = 0

  if (deliveryMethod === 'DELIVERY') {
    const activeThreshold = (groceryCartItems.length > 0 && cafeCartItems.length > 0)
      ? combinedThreshold
      : (cafeCartItems.length > 0 ? cafeThreshold : groceryThreshold)

    const targetThreshold = (deliveryRules && deliveryRules.isServiceable)
      ? deliveryRules.freeDeliveryThreshold
      : activeThreshold

    const feeToCharge = (deliveryRules && deliveryRules.isServiceable)
      ? deliveryRules.deliveryFee
      : deliveryFeeVal

    if (adjustedSubtotal < targetThreshold) {
      if (groceryCartItems.length > 0) {
        groceryDeliveryFee = feeToCharge
      } else if (cafeCartItems.length > 0) {
        cafeDeliveryFee = feeToCharge
      }
    }
  }

  const isPremiumPackagingSelected = (hasCafeItems || cafeCartItems.length > 0) && packagingOption === 'PREMIUM'
  const packagingFee = isPremiumPackagingSelected ? 15 : 0

  // When Premium Thermal Packaging is selected (+₹15), the normal handling/packaging fee is completely waived
  const groceryChargedMisc = groceryCartItems.length > 0 && deliveryMethod !== 'PICKUP' && !isPremiumPackagingSelected
  const effectiveGroceryMiscFee = groceryChargedMisc ? miscFee : 0
  const cafeChargedMisc = cafeCartItems.length > 0 && !groceryChargedMisc && !isPremiumPackagingSelected
  const effectiveCafeMiscFee = cafeChargedMisc ? miscFee : 0
  const effectiveMiscFee = effectiveGroceryMiscFee + effectiveCafeMiscFee

  const groceryTotal = groceryAdjustedSubtotal + groceryDeliveryFee + groceryTaxes + effectiveGroceryMiscFee
  const cafeTotal = cafeAdjustedSubtotal + cafeDeliveryFee + cafeTaxes + effectiveCafeMiscFee + packagingFee

  const couponDiscount = appliedCoupon ? appliedCoupon.discountAmount : 0
  const deliveryFee = groceryDeliveryFee + cafeDeliveryFee
  const taxes = Math.max(0, adjustedSubtotal - couponDiscount) * taxRate
  const grandTotal = Math.max(0, adjustedSubtotal - couponDiscount) + deliveryFee + taxes + effectiveMiscFee + packagingFee

  // Fetch Saved Addresses
  useEffect(() => {
    async function loadAddresses() {
      try {
        const res = await fetch('/api/addresses')
        if (res.ok) {
          const data = await res.json()
          const deliveryAddrs = data.filter((a: any) => !['STORE_PICKUP', 'STORE_PICKUP_RESTAURANT', 'STORE_PICKUP_CAFE'].includes(a.label))
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

    const serviceablePincode = resolveStorePincode(storeSettingsMap)
    if (cleanPincode !== serviceablePincode) {
      toast.error(`FastKirana only delivers to pincode ${serviceablePincode}.`)
      return
    }

    const trimmedPhone = phone.trim()
    let cleanPhone = getLast10Digits(trimmedPhone)
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

      const payload: any = {
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

      if (editingAddressId) {
        payload.id = editingAddressId
      }

      const res = await fetch('/api/addresses', {
        method: editingAddressId ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (res.ok) {
        const savedAddress = await res.json()
        if (editingAddressId) {
          setAddresses(addresses.map(a => a.id === editingAddressId ? savedAddress : a))
          toast.success('Address updated successfully!')
        } else {
          setAddresses([savedAddress, ...addresses])
          toast.success('Address saved successfully!')
        }
        setSelectedAddressId(savedAddress.id)
        setShowNewAddressForm(false)
        setEditingAddressId(null)
        setAddressForm({
          label: 'Home',
          houseNo: '.',
          street: '',
          area: '.',
          city: 'Ghatampur',
          pincode: DEFAULT_STORE_PINCODE,
          phone: addressForm.phone, // keep phone number for convenience
          isDefault: false,
          lat: null,
          lng: null,
        })
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
    setAddressForm({
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
  }

  // Place Order
  const handlePlaceOrder = async (overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET') => {
    const selectedMethod = overrideMethod || paymentMethod
    setIsPlacingOrder(true)
    try {
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map(i => ({ product: i.product as CartItem['product'] })),
        addresses,
        selectedAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        contactPhone,
        packagingOption,
        packagingFee,
      })

      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      const data = await res.json()

      if (res.ok) {
        triggerHaptic('success')
        toast.success('Order placed successfully! Redirecting to tracking...')
        clearCart()
        router.push(`/order/${data.id}/success`)
      } else {
        toast.error(data.error || 'Failed to place order')
      }
    } catch (err) {
      toast.error('Connection error. Please try again.')
    } finally {
      setIsPlacingOrder(false)
    }
  }

  // Handle Razorpay Payment Gateway Checkout
  const loadRazorpayScript = (): Promise<boolean> => {
    return new Promise((resolve) => {
      if ((window as any).Razorpay) {
        resolve(true)
        return
      }
      const script = document.createElement('script')
      script.src = 'https://checkout.razorpay.com/v1/checkout.js'
      script.onload = () => resolve(true)
      script.onerror = () => resolve(false)
      document.body.appendChild(script)
    })
  }

  // Preload Razorpay SDK as soon as checkout page mounts for instant popup
  useEffect(() => {
    loadRazorpayScript()
  }, [])

  const handleRazorpayCheckout = async (overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET') => {
    const selectedMethod = overrideMethod || paymentMethod
    setIsPlacingOrder(true)
    try {
      // 1. Validate checkout eligibility
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map(i => ({ product: i.product as CartItem['product'] })),
        addresses,
        selectedAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      // 2. Pre-create DB Order in PENDING / UNPAID state BEFORE opening Razorpay
      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        contactPhone,
        packagingOption,
        packagingFee,
      })

      const orderRes = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      const orderData = await orderRes.json()

      if (!orderRes.ok) {
        toast.error(orderData.error || 'Failed to initialize order')
        setIsPlacingOrder(false)
        return
      }

      // 3. Create Razorpay Payment Order ID linked to DB order.id
      const rzpRes = await fetch('/api/payment/razorpay/create-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId: orderData.id }),
      })

      const rzpData = await rzpRes.json()

      if (!rzpRes.ok) {
        toast.error(rzpData.detail || 'Razorpay order creation failed')
        setIsPlacingOrder(false)
        return
      }

      const loaded = await loadRazorpayScript()
      if (!loaded) {
        toast.error('Failed to load Razorpay Checkout SDK.')
        setIsPlacingOrder(false)
        return
      }

      let paymentSuccess = false

      const options = {
        key: rzpData.keyId,
        amount: rzpData.amount,
        currency: rzpData.currency,
        name: 'FastKirana',
        description: `FastKirana Order #${orderData.readableId || orderData.id.slice(-6).toUpperCase()}`,
        order_id: rzpData.razorpayOrderId,
        handler: async function (response: any) {
          paymentSuccess = true
          try {
            // Verify signature & confirm payment status
            const verifyRes = await fetch('/api/payment/razorpay/verify-signature', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                orderId: orderData.id,
                razorpay_order_id: response.razorpay_order_id,
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_signature: response.razorpay_signature,
              }),
            })
            const verifyData = await verifyRes.json()
            if (verifyRes.ok) {
              clearCart()
              triggerHaptic('success')
              toast.success('🎉 Payment Successful!')
              window.location.href = `/order/${orderData.id}/success`
            } else {
              toast.error(verifyData.error || verifyData.detail || 'Payment verification failed')
              setIsPlacingOrder(false)
            }
          } catch (err) {
            toast.error('Payment verification error')
            setIsPlacingOrder(false)
          }
        },
        modal: {
          ondismiss: function () {
            if (!paymentSuccess) {
              setIsPlacingOrder(false)
              toast.info('Payment incomplete. Your order is saved as Pending in My Orders.')
            }
          },
        },
        prefill: {
          name: session?.user?.name || 'Customer',
          email: session?.user?.email || 'customer@fastkirana.in',
          contact: selectedAddress?.phone || (session?.user as any)?.phone || contactPhone || '9999999999',
        },
        theme: {
          color: '#10b981',
        },
      }

      const rzp = new (window as any).Razorpay(options)
      rzp.open()
    } catch (err) {
      toast.error('An unexpected error occurred during Razorpay checkout.')
      setIsPlacingOrder(false)
    }
  }

  const handlePlaceOrderClick = () => {
    if (isPlacingOrder) return

    if (showNewAddressForm) {
      triggerHaptic('warning')
      toast.error('Please save your new address first by clicking Save & Select')
      const el = document.getElementById('new-address-form')
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
      return
    }

    if (deliveryMethod === 'DELIVERY') {
      const targetId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
      if (!targetId) {
        triggerHaptic('warning')
        toast.error('Please select or add a delivery address')
        const el = document.getElementById('address-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }

      if (deliveryRules && !deliveryRules.isServiceable) {
        triggerHaptic('warning')
        toast.error(`Your address is outside our delivery zone (${distanceKm?.toFixed(1)} km away). We deliver only up to 3 km.`)
        return
      }
    }

    if (onlyCod) {
      setPaymentMethod('COD')
      handlePlaceOrder('COD')
    } else {
      triggerHaptic('light')
      setIsPaymentModalOpen(true)
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

  const hasCafe = items.some((item) => item.product.category?.slug === 'cafe' || (item.product as any).tags?.includes('cafe'))
  const hasRestaurant = items.some((item) => item.product.category?.slug === 'restaurant' || (item.product as any).tags?.includes('restaurant'))
  const hasGrocery = items.some((item) => {
    const isC = item.product.category?.slug === 'cafe' || (item.product as any).tags?.includes('cafe')
    const isR = item.product.category?.slug === 'restaurant' || (item.product as any).tags?.includes('restaurant')
    return !isC && !isR
  })
  const isStoreClosed = (hasGrocery && !groceryMartOpen) || (hasCafe && !cafeOpen) || (hasRestaurant && !restaurantOpen)

  const hasInventoryIssues = items.some(
    (item) => item.quantity > item.product.stock || item.product.stock <= 0 || item.product.isAvailable === false
  )

  if (hasInventoryIssues && !isSettingsLoading) {
    const handleRemoveOutOfStock = () => {
      let count = 0
      items.forEach(item => {
        if (item.product.stock <= 0 || item.product.isAvailable === false) {
          removeItem(item.product.id, item.product.name)
          count++
        } else if (item.quantity > item.product.stock) {
          updateQuantity(item.product.id, item.product.name, item.product.stock)
          count++
        }
      })
      if (count > 0) {
        toast.success(`Adjusted out-of-stock items in your cart!`)
      }
    }

    return (
      <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
        <div className="h-20 w-20 bg-rose-50 dark:bg-rose-950/20 text-rose-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner border border-rose-200/60 dark:border-rose-900/40">
          ⚠️
        </div>
        <h1 className="text-2xl font-black text-text-primary">Item(s) Out of Stock</h1>
        <p className="text-sm text-text-secondary leading-relaxed">
          Some items in your cart just went out of stock or have limited quantity. Please adjust them to proceed with your order.
        </p>
        <div className="space-y-2 max-h-48 overflow-y-auto p-2 bg-muted/20 rounded-xl border border-border/50">
          {items.filter(item => item.product.stock <= 0 || item.product.isAvailable === false || item.quantity > item.product.stock).map(item => (
            <div key={item.product.id} className="flex items-center justify-between text-xs py-1.5 px-2 font-bold text-left">
              <span className="truncate flex-1">{item.product.name}</span>
              <span className="text-rose-500 font-black text-[10px] uppercase ml-2">
                {item.product.stock <= 0 || item.product.isAvailable === false ? 'Out of Stock' : `Only ${item.product.stock} available`}
              </span>
            </div>
          ))}
        </div>
        <div className="pt-2 flex flex-col gap-3">
          <button
            onClick={handleRemoveOutOfStock}
            className="w-full px-6 py-3 bg-rose-600 text-white font-black text-xs rounded-full hover:bg-rose-700 transition-all shadow-md active:scale-98 cursor-pointer"
          >
            Remove Out-of-Stock Items & Proceed
          </button>
          <Link
            href="/cart"
            className="w-full px-6 py-3 bg-muted text-text-primary font-black text-xs rounded-full hover:bg-muted/80 transition-all text-center"
          >
            Go Back to Cart
          </Link>
        </div>
      </div>
    )
  }

  if (isBelowMinOrder && !isSettingsLoading) {
    return (
      <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
        <div className="h-20 w-20 bg-rose-50 dark:bg-rose-950/20 text-rose-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner border border-rose-200/60 dark:border-rose-900/40">
          🛍️
        </div>
        <h1 className="text-2xl font-black text-text-primary">Minimum Order Required</h1>
        <p className="text-sm text-text-secondary leading-relaxed">
          Minimum order value is ₹20 to place an order. Your current cart subtotal is only {formatPrice(subtotal)}. Please add more items to checkout!
        </p>
        <div className="pt-4 flex flex-col gap-3">
          <Link
            href="/cart"
            className="px-6 py-3 bg-primary text-white font-black text-xs rounded-full hover:bg-primary/95 transition-all shadow-md text-center"
          >
            Go Back to Cart
          </Link>
        </div>
      </div>
    )
  }

  if (isStoreClosed && !isSettingsLoading) {
    return (
      <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
        <div className="h-20 w-20 bg-amber-50 dark:bg-amber-950/20 text-amber-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner animate-pulse-gentle border border-amber-200/60 dark:border-amber-900/40">
          🏪
        </div>
        <h1 className="text-2xl font-black text-text-primary">Store Closed Temporarily</h1>
        <p className="text-sm text-text-secondary leading-relaxed">
          {hasGrocery && !groceryMartOpen && hasCafe && !cafeOpen && hasRestaurant && !restaurantOpen ? (
            "Our Grocery Mart, Cafe, and Wedson Restaurant are temporarily closed. Please check back later!"
          ) : hasGrocery && !groceryMartOpen ? (
            "Our Grocery Mart is temporarily closed. You can proceed with other items by removing grocery items from your cart."
          ) : hasCafe && !cafeOpen ? (
            "Our Cafe is temporarily closed. You can proceed by removing cafe items from your cart."
          ) : (
            "Wedson Restaurant is temporarily closed. You can proceed by removing restaurant items from your cart."
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

      {/* Near Closing Time Warnings */}
      {(isCafeNearClosing || isGroceryNearClosing) && (
        <div className="bg-amber-50 dark:bg-amber-950/20 border-2 border-amber-200 dark:border-amber-900/50 p-4 rounded-2xl flex items-start gap-3 shadow-md animate-pulse-gentle">
          <div className="h-10 w-10 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-400 flex items-center justify-center shrink-0 font-bold text-lg select-none">
            ⚠️
          </div>
          <div className="space-y-1">
            <h2 className="text-xs sm:text-sm font-black text-amber-800 dark:text-amber-400 tracking-tight">Hurry Up! Shop is closing soon</h2>
            <p className="text-[10px] sm:text-xs text-amber-700 dark:text-amber-500 leading-relaxed font-bold">
              {isCafeNearClosing && isGroceryNearClosing ? (
                `FastKirana Cafe (closes at ${formatTime12h(cafeCloseTime)}) and Mart (closes at ${formatTime12h(groceryCloseTime)}) are closing in less than 30 minutes! Place your order now to ensure tonight's delivery.`
              ) : isCafeNearClosing ? (
                `Our Cafe kitchen closes at ${formatTime12h(cafeCloseTime)} (in less than 30 minutes!). Please place your order immediately to get your hot food prepared and dispatched.`
              ) : (
                `Our Grocery Mart closes at ${formatTime12h(groceryCloseTime)} (in less than 30 minutes!). Please complete your checkout now to receive your groceries tonight.`
              )}
            </p>
          </div>
        </div>
      )}



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
                  <div className="rounded-xl border border-primary/20 bg-primary/5 p-5 space-y-4">
                    <div className="flex items-start gap-3">
                      <span className="text-2xl">🏪</span>
                      <div className="space-y-3 flex-1">
                        <h4 className="text-sm font-black text-text-primary uppercase tracking-wide">Pickup Addresses</h4>
                        
                        {hasGrocery && (
                          <div className="border-l-2 border-primary/30 pl-3">
                            <span className="text-[10px] uppercase font-black text-primary">Grocery Mart Pickup</span>
                            <p className="text-xs text-text-secondary leading-relaxed mt-0.5">
                              {groceryPickupAddress || contactAddress}
                            </p>
                          </div>
                        )}

                        {hasCafe && (
                          (() => {
                            const cafeItem = items.find((item) => item.product.category?.slug === 'cafe' || (item.product as any).tags?.includes('cafe'))
                            const restaurantId = (cafeItem?.product as any)?.restaurantId || (cafeItem?.product as any)?.restaurant?.id
                            const specificCafe = restaurantsList.find(r => r.id === restaurantId || r.slug?.includes('cafe')) || (cafeItem?.product as any)?.restaurant

                            return (
                              <div className="border-l-2 border-orange-500/30 pl-3">
                                <span className="text-[10px] uppercase font-black text-orange-600">
                                  ☕ {specificCafe ? specificCafe.name : 'Cafe'} Pickup
                                </span>
                                <p className="text-xs text-text-secondary leading-relaxed mt-0.5 font-bold">
                                  {specificCafe?.address || cafePickupAddress || contactAddress}
                                </p>
                              </div>
                            )
                          })()
                        )}

                        {hasRestaurant && (
                          (() => {
                            const restaurantItem = items.find((item) => (item.product as any).restaurantId || (item.product as any).restaurant)
                            const prodRest = (restaurantItem?.product as any)?.restaurant
                            const restaurantId = (restaurantItem?.product as any)?.restaurantId || prodRest?.id
                            const specificRestaurant = prodRest || restaurantsList.find(r => r.id === restaurantId || (prodRest?.slug && r.slug === prodRest.slug)) || restaurantsList.find(r => r.slug?.includes('wedson')) || restaurantsList[0]

                            return (
                              <div className="border-l-2 border-rose-500/30 pl-3">
                                <span className="text-[10px] uppercase font-black text-rose-600">
                                  📍 {specificRestaurant ? specificRestaurant.name : 'Restaurant'} Pickup
                                </span>
                                <p className="text-xs text-text-secondary leading-relaxed mt-0.5 font-bold">
                                  {specificRestaurant?.address || restaurantPickupAddress || contactAddress}
                                </p>
                              </div>
                            )
                          })()
                        )}

                        <p className="text-xs text-text-secondary pt-1 border-t border-border/20">
                          Phone: <span className="font-semibold text-primary">{formatPhone(contactPhone)}</span>
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
                            <div className="flex items-center justify-between gap-2 mb-1.5">
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-[10px] text-text-primary uppercase bg-muted px-2 py-0.5 rounded-md tracking-wider">
                                  {addr.label}
                                </span>
                                {addr.isDefault && (
                                  <span className="text-[9px] text-accent font-bold bg-accent/10 px-2 py-0.5 rounded-md">
                                    Default
                                  </span>
                                )}
                              </div>
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation()
                                  handleEditAddressClick(addr)
                                }}
                                className="text-[10.5px] font-black text-primary hover:underline cursor-pointer active:scale-95 transition-all"
                              >
                                ✏️ Edit
                              </button>
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
                              {editingAddressId ? 'Edit Delivery Location' : 'Choose Delivery Location'}
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
                                onChange={(e) => setAddressForm({ ...addressForm, phone: getLast10Digits(e.target.value) })}
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
                              onClick={handleCancelAddressForm}
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
                              ) : editingAddressId ? 'Update & Select' : 'Save & Select'}
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

              {/* Food Packaging Option Selection (Only shown when food / cafe items exist in cart) */}
              {(hasCafeItems || cafeCartItems.length > 0) && (
                <div className="border-t border-border/40 pt-5 md:pt-6 space-y-3.5">
                  <div className="flex items-center justify-between">
                    <h3 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
                      <span className="text-xl">🍱</span>
                      <span>Food Packaging Option</span>
                    </h3>
                    <span className="text-[10px] font-extrabold uppercase px-2.5 py-1 rounded-full bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20">
                      Hot Prepared Food
                    </span>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                    {/* Normal Packaging (₹0) */}
                    <div
                      onClick={() => {
                        triggerHaptic('light')
                        setPackagingOption('NORMAL')
                      }}
                      className={cn(
                        "flex items-start gap-3 p-4 rounded-2xl border-2 cursor-pointer transition-all duration-200 relative overflow-hidden select-none bg-white dark:bg-zinc-900/50",
                        packagingOption === 'NORMAL'
                          ? "border-primary bg-primary/[0.02] shadow-xs"
                          : "border-border/60 hover:border-primary/40"
                      )}
                    >
                      <div className={cn(
                        "w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 mt-0.5 transition-all duration-200",
                        packagingOption === 'NORMAL' ? "border-primary bg-primary" : "border-border"
                      )}>
                        {packagingOption === 'NORMAL' && <div className="w-2 h-2 rounded-full bg-white" />}
                      </div>
                      <div className="flex-grow text-xs">
                        <div className="flex items-center justify-between font-extrabold text-text-primary mb-1">
                          <span className="flex items-center gap-1.5 text-sm">
                            <span>📦</span> Normal Packaging
                          </span>
                          <span className="text-emerald-600 dark:text-emerald-400 font-black text-xs bg-emerald-50 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md border border-emerald-500/20">
                            FREE (₹0)
                          </span>
                        </div>
                        <p className="text-[11px] text-text-secondary leading-relaxed font-semibold">
                          Standard eco-friendly containers & paper bag packaging.
                        </p>
                      </div>
                    </div>

                    {/* Premium Packaging (₹15) */}
                    <div
                      onClick={() => {
                        triggerHaptic('light')
                        setPackagingOption('PREMIUM')
                      }}
                      className={cn(
                        "flex items-start gap-3 p-4 rounded-2xl border-2 cursor-pointer transition-all duration-200 relative overflow-hidden select-none bg-white dark:bg-zinc-900/50",
                        packagingOption === 'PREMIUM'
                          ? "border-amber-500 bg-amber-500/[0.04] shadow-xs ring-1 ring-amber-500/20"
                          : "border-border/60 hover:border-amber-500/40"
                      )}
                    >
                      <div className={cn(
                        "w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 mt-0.5 transition-all duration-200",
                        packagingOption === 'PREMIUM' ? "border-amber-500 bg-amber-500" : "border-border"
                      )}>
                        {packagingOption === 'PREMIUM' && <div className="w-2 h-2 rounded-full bg-white" />}
                      </div>
                      <div className="flex-grow text-xs">
                        <div className="flex items-center justify-between font-extrabold text-text-primary mb-1">
                          <span className="flex items-center gap-1.5 text-sm">
                            <span>✨</span> Premium Packaging
                          </span>
                          <span className="text-amber-600 dark:text-amber-400 font-black text-xs bg-amber-50 dark:bg-amber-950/40 px-2 py-0.5 rounded-md border border-amber-500/20">
                            +₹15
                          </span>
                        </div>
                        <p className="text-[11px] text-text-secondary leading-relaxed font-semibold">
                          Insulated thermal pouch + heavy-duty spill-proof boxes & cutlery set.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Secure Transaction notice */}
              <div className="flex items-center gap-2 border border-accent/20 bg-accent/5 p-3 rounded-xl text-xs font-semibold text-accent">
                <ShieldCheck className="h-5 w-5 shrink-0" />
                <span>100% Secure &amp; Verified Order • Fast &amp; Reliable Delivery</span>
              </div>

              {/* Place Order Button (Desktop Only) */}
              <div className="hidden md:block border-t border-border/40 pt-5 md:pt-6">
                <SlideToOrder
                  onConfirm={handlePlaceOrderClick}
                  isPlacingOrder={isPlacingOrder}
                  amount={grandTotal}
                />
              </div>
            </div>
        </div>

        {/* Right Column: Mini Bill Summary (Persistent) */}
        <div className="bg-white/80 dark:bg-zinc-900/85 backdrop-blur-md border border-white/60 dark:border-zinc-800/60 p-5 rounded-2xl shadow-[0_8px_30px_rgb(0,0,0,0.02)] h-fit space-y-5">

          
          <h3 className="text-sm font-black text-text-primary border-b border-border/40 pb-2.5 flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <span>🧾</span> Bill Summary
            </span>
            <span className="text-xs text-text-muted font-bold">{groceryCartItems.length + cafeCartItems.length} items</span>
          </h3>

          {/* Single Consolidated Bill Breakdown */}
          <div className="space-y-2.5 text-xs font-semibold">
            {grocerySavings + groceryB2BDiscount + cafeSavings + cafeB2BDiscount > 0 ? (
              <>
                <div className="flex justify-between text-text-secondary">
                  <span>Item Total (MRP)</span>
                  <span>₹{(groceryMrpSubtotal + cafeMrpSubtotal).toFixed(0)}</span>
                </div>
                <div className="flex justify-between text-accent font-bold">
                  <span>Product Discount</span>
                  <span>-₹{(grocerySavings + groceryB2BDiscount + cafeSavings + cafeB2BDiscount).toFixed(0)}</span>
                </div>
              </>
            ) : (
              <div className="flex justify-between text-text-secondary">
                <span>Item Total</span>
                <span>₹{(grocerySubtotal + cafeSubtotal).toFixed(0)}</span>
              </div>
            )}

            <div className="flex justify-between text-text-secondary items-center">
              <div className="flex flex-col text-left">
                <span>Delivery Charge</span>
                <span className="text-[9px] text-text-muted">
                  {deliveryMethod === 'PICKUP' 
                    ? 'Store Pickup' 
                    : adjustedSubtotal >= ((deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200))
                    ? `Free delivery on orders ₹${(deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200)}+`
                    : `₹${deliveryFee} fee on orders under ₹${(deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200)}`}
                </span>
              </div>
              <span className={cn(deliveryFee === 0 ? "text-accent font-black text-xs" : "")}>
                {deliveryFee === 0 ? 'FREE 🎉' : `₹${deliveryFee}`}
              </span>
            </div>

            {packagingFee > 0 && (
              <div className="flex justify-between items-center text-amber-700 dark:text-amber-400 font-extrabold bg-amber-500/10 px-2.5 py-1 rounded-lg border border-amber-500/20">
                <span className="flex items-center gap-1.5 text-xs">
                  <span>✨</span> Premium Packaging
                </span>
                <span>+₹{packagingFee}</span>
              </div>
            )}

            {couponDiscount > 0 && (
              <div className="flex justify-between text-emerald-600 dark:text-emerald-400 font-semibold">
                <span>Coupon Applied ({appliedCoupon?.code})</span>
                <span>-₹{couponDiscount.toFixed(0)}</span>
              </div>
            )}

            {taxRate > 0 && (
              <div className="flex justify-between text-text-secondary">
                <span>GST & Taxes ({Math.round(taxRate * 100)}%)</span>
                <span>₹{taxes.toFixed(0)}</span>
              </div>
            )}

            {effectiveMiscFee > 0 && (
              <div className="flex justify-between text-text-secondary">
                <span>{miscFeeLabel}</span>
                <span>₹{effectiveMiscFee.toFixed(0)}</span>
              </div>
            )}

            {deliveryMethod === 'DELIVERY' && selectedAddress && (
              <>
                {deliveryRules && !deliveryRules.isServiceable && (
                  <div className="bg-rose-50 dark:bg-rose-950/20 border border-rose-200 dark:border-rose-900/50 p-2.5 rounded-xl text-center mt-2">
                    <p className="text-[10px] font-black text-rose-600 dark:text-rose-400">
                      ❌ Address is {distanceKm?.toFixed(1)} km away. Delivery only available up to 3 km.
                    </p>
                  </div>
                )}
                {adjustedSubtotal < ((deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200)) && (
                  <div className="bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-900/50 p-2.5 rounded-xl text-center mt-2">
                    <p className="text-[10px] font-black text-emerald-600 dark:text-emerald-400">
                      💡 Add ₹{(((deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200)) - adjustedSubtotal).toFixed(0)} more items for FREE Delivery!
                    </p>
                  </div>
                )}
              </>
            )}

            {/* Grand Total */}
            <div className="border-t-2 border-dashed border-border/60 pt-3 mt-3 flex justify-between items-center text-base font-black text-text-primary">
              <span>Grand Total</span>
              <span className="text-primary text-lg font-black">₹{grandTotal.toFixed(0)}</span>
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
          disabled={isPlacingOrder}
          onClick={handlePlaceOrderClick}
          className={cn(
            "group relative overflow-hidden text-white rounded-full font-black text-xs sm:text-sm tracking-wide uppercase px-6 h-12 transition-all duration-300 active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg",
            paymentMethod !== 'COD'
              ? "bg-gradient-to-r from-emerald-600 to-teal-600 shadow-emerald-500/25 hover:shadow-emerald-500/40"
              : "bg-gradient-to-r from-accent to-accent-dark shadow-accent/25 hover:shadow-accent/40",
            isPlacingOrder && "opacity-60 cursor-not-allowed shadow-none"
          )}
        >
          {isPlacingOrder ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin text-white relative z-10" />
              <span className="relative z-10">Processing...</span>
            </>
          ) : (
            <>
              <span className="relative z-10">Proceed to Pay</span>
              <ChevronsRight className="h-4 w-4 text-white relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
            </>
          )}
        </button>
      </div>

      {/* Payment Selection Popup Modal (Design 3: 2 Big Action Buttons) */}
      {isPaymentModalOpen && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4 animate-in fade-in duration-200">
          <div className="bg-white dark:bg-zinc-900 border border-border/80 w-full sm:max-w-md rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4 transform transition-all animate-in slide-in-from-bottom-5 sm:zoom-in-95 duration-200">
            
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-border/40 pb-3.5">
              <div>
                <h3 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
                  💳 Select Payment Method
                </h3>
                <p className="text-xs text-text-secondary font-medium mt-0.5">
                  Grand Total: <span className="font-extrabold text-emerald-600 dark:text-emerald-400">₹{grandTotal.toFixed(0)}</span>
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsPaymentModalOpen(false)}
                className="h-8 w-8 rounded-full bg-zinc-100 dark:bg-zinc-800 text-text-secondary hover:text-text-primary flex items-center justify-center transition-colors cursor-pointer"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {onlyCod && (
              <div className="border border-amber-500/20 bg-amber-500/5 p-3 rounded-xl text-xs font-semibold text-amber-600 dark:text-amber-400 flex items-center gap-2">
                <span>ℹ️</span>
                <span>Online payment options are temporarily disabled by the store.</span>
              </div>
            )}

            {/* 2 Big Action Buttons */}
            <div className="space-y-3 pt-1">
              {/* Option 1: Cash on Delivery (DEFAULT) */}
              <button
                type="button"
                disabled={isPlacingOrder}
                onClick={() => {
                  setIsPaymentModalOpen(false)
                  setPaymentMethod('COD')
                  handlePlaceOrder('COD')
                }}
                className="group relative overflow-hidden w-full p-4 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 text-white font-black text-left transition-all duration-200 hover:scale-[1.01] active:scale-[0.99] shadow-lg shadow-emerald-600/25 flex items-center justify-between border border-emerald-400/30 cursor-pointer"
              >
                <div className="flex items-center gap-3.5 relative z-10">
                  <div className="h-10 w-10 rounded-xl bg-white/20 backdrop-blur-md flex items-center justify-center text-xl shrink-0">
                    💵
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs sm:text-sm font-black tracking-wide uppercase">
                        {deliveryMethod === 'PICKUP' ? 'Cash on Pickup (COP)' : 'Cash on Delivery (COD)'}
                      </span>
                      <span className="bg-white/25 text-white text-[8px] font-black uppercase px-2 py-0.5 rounded-full shadow-sm">
                        DEFAULT ⚡
                      </span>
                    </div>
                    <p className="text-[10px] text-emerald-100 font-medium mt-0.5">
                      {deliveryMethod === 'PICKUP' ? 'Pay cash or UPI at store counter' : 'Pay cash or UPI to delivery rider at doorstep'}
                    </p>
                  </div>
                </div>
                <ChevronsRight className="h-5 w-5 text-white/90 relative z-10 transition-transform group-hover:translate-x-1" />
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
              </button>

              {/* Option 2: Pay Online (Razorpay) */}
              {!onlyCod && (
                <button
                  type="button"
                  disabled={isPlacingOrder}
                  onClick={() => {
                    setIsPaymentModalOpen(false)
                    setPaymentMethod('UPI')
                    handleRazorpayCheckout('UPI')
                  }}
                  className="group relative w-full p-4 rounded-2xl bg-zinc-100 dark:bg-zinc-800/80 hover:bg-zinc-200 dark:hover:bg-zinc-800 border-2 border-zinc-200 dark:border-zinc-700/80 text-text-primary font-black text-left transition-all duration-200 hover:scale-[1.01] active:scale-[0.99] flex items-center justify-between cursor-pointer"
                >
                  <div className="flex items-center gap-3.5">
                    <div className="h-10 w-10 rounded-xl bg-zinc-200 dark:bg-zinc-700 flex items-center justify-center text-xl shrink-0">
                      ⚡
                    </div>
                    <div>
                      <span className="text-xs sm:text-sm font-black tracking-wide uppercase">Pay Online (₹{grandTotal.toFixed(0)})</span>
                      <p className="text-[10px] text-text-secondary font-medium mt-0.5">
                        Instant UPI (GPay / PhonePe / Paytm), Cards &amp; NetBanking
                      </p>
                    </div>
                  </div>
                  <ChevronsRight className="h-5 w-5 text-text-secondary transition-transform group-hover:translate-x-1" />
                </button>
              )}
            </div>

            {/* Footer Trust Badge */}
            <div className="flex items-center justify-center gap-1.5 text-[10px] font-bold text-text-secondary pt-1">
              <ShieldCheck className="h-4 w-4 text-emerald-600 shrink-0" />
              <span>100% Safe Payment • Verified by FastKirana</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
