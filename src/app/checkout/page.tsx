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
import { cn, isCafeProduct, isProductStoreClosed, formatPhone, formatAddress, formatPrice } from '@/lib/utils'
import { getOutletName } from '@/lib/constants'
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

import { SlideToOrder } from '@/components/checkout/slide-to-order'
import { PaymentSelectionModal } from '@/components/checkout/payment-selection-modal'

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
  const [activePendingOrderId, setActivePendingOrderId] = useState<string | null>(null)
  const [cookingInstruction, setCookingInstruction] = useState('')

  // Order for someone else state
  const [orderForSomeone, setOrderForSomeone] = useState(false)
  const [recipientName, setRecipientName] = useState('')
  const [recipientPhone, setRecipientPhone] = useState('')

  // New Address Form State
  const [showNewAddressForm, setShowNewAddressForm] = useState(false)
  const [isSavingAddress, setIsSavingAddress] = useState(false)
  const [editingAddressId, setEditingAddressId] = useState<string | null>(null)
  const [isChangingAddress, setIsChangingAddress] = useState(false)
  const [showMapPicker, setShowMapPicker] = useState(false)
  const activeCheckoutAddressRef = useRef<{ id: string; addresses: Address[] } | null>(null)
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
  let isBelowMinOrder = false
  let minOrderRequired = 0

  if (deliveryMethod === 'DELIVERY' && selectedAddress) {
    if (selectedAddress.lat && selectedAddress.lng) {
      const maxRadiusKm = parseFloat(storeSettingsMap['delivery_radius'] || storeSettingsMap['max_delivery_radius'] || '5.0')
      const surgeFee = parseFloat(storeSettingsMap['surge_charge'] || storeSettingsMap['surge_fee'] || '0')
      const surgeReason = storeSettingsMap['surge_reason'] || (surgeFee > 0 ? 'Special Delivery Surge' : '')
      distanceKm = getDistanceKm(storeLat, storeLng, selectedAddress.lat, selectedAddress.lng)
      deliveryRules = getDeliveryRules(distanceKm, { maxRadiusKm, surgeFee, surgeReason })
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
  const appliedSurgeFee = (deliveryFee > 0 && deliveryRules && deliveryRules.isServiceable) ? (deliveryRules.surgeFee || 0) : 0
  const baseDeliveryFee = Math.max(0, deliveryFee - appliedSurgeFee)
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
            setShowNewAddressForm(false)
            setIsChangingAddress(false)
          } else {
            setSelectedAddressId('')
            setShowNewAddressForm(true)
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



  // Reusable core address saving logic for both explicit submit and on-the-fly checkout auto-save
  const saveAddressCore = async (): Promise<{ savedAddress: Address; newAddresses: Address[] } | null> => {
    const { label, street, pincode, phone, isDefault } = addressForm

    if (!street || !pincode || !phone) {
      toast.error('Please fill in all address details, including pincode and phone number')
      return null
    }

    const cleanPincode = pincode.trim()

    if (!/^\d{6}$/.test(cleanPincode)) {
      toast.error('Pincode must be a 6-digit number')
      return null
    }

    const serviceablePincode = resolveStorePincode(storeSettingsMap)
    if (cleanPincode !== serviceablePincode) {
      toast.error(`FastKirana only delivers to pincode ${serviceablePincode}.`)
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
        const savedAddress: Address = await res.json()
        let nextAddresses: Address[]
        if (editingAddressId) {
          nextAddresses = addresses.map(a => a.id === editingAddressId ? savedAddress : a)
          toast.success('Address updated successfully!')
        } else {
          nextAddresses = [savedAddress, ...addresses.filter(a => a.id !== savedAddress.id)]
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
          phone: addressForm.phone, // keep phone number for convenience
          isDefault: false,
          lat: null,
          lng: null,
        })
        return { savedAddress, newAddresses: nextAddresses }
      } else {
        const errorData = await res.json()
        toast.error(errorData.error || 'Failed to save address')
        return null
      }
    } catch (err) {
      toast.error('Something went wrong')
      return null
    } finally {
      setIsSavingAddress(false)
    }
  }

  // Create / Update New Address from explicit button click
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

  // Order Helpers for Notes & Recipient Phone
  const getOrderNotes = () => {
    const cleanP = recipientPhone.replace(/\D/g, '')
    const orderForNote = (orderForSomeone && recipientName.trim())
      ? `🎁 Order for: ${recipientName.trim()}${cleanP ? ` (${cleanP})` : ''}`
      : ''
    return [orderForNote, cookingInstruction.trim()].filter(Boolean).join(' | ') || undefined
  }

  const getEffectiveCustomerPhone = (activeSelectedAddress?: Address) => {
    const cleanP = recipientPhone.replace(/\D/g, '')
    if (orderForSomeone && cleanP.length === 10) {
      return cleanP
    }
    return activeSelectedAddress?.phone || addressForm.phone || (session?.user as any)?.phone || ''
  }

  // Place Order
  const handlePlaceOrder = async (
    overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET',
    overrideAddressId?: string,
    overrideAddresses?: Address[]
  ) => {
    const selectedMethod = overrideMethod || paymentMethod
    const activeAddresses = overrideAddresses || addresses
    const activeAddressId = overrideAddressId || selectedAddressId
    const activeSelectedAddress = activeAddresses.find(a => a.id === activeAddressId) || selectedAddress

    setIsPlacingOrder(true)
    try {
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map(i => ({ product: i.product as CartItem['product'] })),
        addresses: activeAddresses,
        selectedAddressId: activeAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      const effectiveCustomerPhone = getEffectiveCustomerPhone(activeSelectedAddress)
      const finalNotes = getOrderNotes()

      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        customerPhone: effectiveCustomerPhone,
        contactPhone,
        packagingOption,
        packagingFee,
      })

      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...payload,
          existingOrderId: activePendingOrderId || undefined,
          notes: finalNotes
        }),
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

  // Handle Cashfree Payment Gateway Checkout
  const loadCashfreeScript = (): Promise<boolean> => {
    return new Promise((resolve) => {
      if ((window as any).Cashfree) {
        resolve(true)
        return
      }
      const script = document.createElement('script')
      script.src = 'https://sdk.cashfree.com/js/v3/cashfree.js'
      script.onload = () => resolve(true)
      script.onerror = () => resolve(false)
      document.body.appendChild(script)
    })
  }

  // Handle Razorpay Payment Gateway Checkout (legacy fallback)
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

  // Preload Payment SDKs
  useEffect(() => {
    loadCashfreeScript()
    loadRazorpayScript()
  }, [])

  const handleCashfreeCheckout = async (
    overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET',
    overrideAddressId?: string,
    overrideAddresses?: Address[]
  ) => {
    const selectedMethod = overrideMethod || paymentMethod
    const activeAddresses = overrideAddresses || addresses
    const activeAddressId = overrideAddressId || selectedAddressId
    const activeSelectedAddress = activeAddresses.find(a => a.id === activeAddressId) || selectedAddress

    setIsPlacingOrder(true)
    try {
      // 1. Validate checkout eligibility
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map(i => ({ product: i.product as CartItem['product'] })),
        addresses: activeAddresses,
        selectedAddressId: activeAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      // 2. Pre-create DB Order in PENDING / UNPAID state
      const effectiveCustomerPhone = getEffectiveCustomerPhone(activeSelectedAddress)
      const finalNotes = getOrderNotes()

      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        customerPhone: effectiveCustomerPhone,
        contactPhone,
        packagingOption,
        packagingFee,
      })

      const orderRes = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...payload,
          existingOrderId: activePendingOrderId || undefined,
          notes: finalNotes
        }),
      })

      const orderData = await orderRes.json()

      if (!orderRes.ok) {
        toast.error(orderData.error || 'Failed to initialize order')
        setIsPlacingOrder(false)
        return
      }

      setActivePendingOrderId(orderData.id)

      // 3. Create Cashfree Payment Order Session
      const cfRes = await fetch('/api/payment/cashfree/create-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId: orderData.id }),
      })

      const cfData = await cfRes.json()

      if (!cfRes.ok || !cfData.paymentSessionId) {
        console.warn('Cashfree session failed, falling back to Razorpay:', cfData.error)
        return handleRazorpayCheckout('UPI', activeAddressId, activeAddresses)
      }

      const loaded = await loadCashfreeScript()
      if (!loaded || !(window as any).Cashfree) {
        console.warn('Cashfree SDK failed to load, falling back to Razorpay')
        return handleRazorpayCheckout('UPI', activeAddressId, activeAddresses)
      }

      const cashfree = (window as any).Cashfree({
        mode: process.env.NEXT_PUBLIC_CASHFREE_ENV === 'SANDBOX' ? 'sandbox' : 'production'
      })

      let paymentSuccess = false

      // Polling loop to auto-confirm if customer pays via external UPI app
      let pollCount = 0
      const pollTimer = setInterval(async () => {
        pollCount++
        if (pollCount > 60 || paymentSuccess) {
          clearInterval(pollTimer)
          return
        }
        try {
          const verifyRes = await fetch('/api/payment/cashfree/verify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId: orderData.id }),
          })
          const verifyData = await verifyRes.json()
          if (verifyRes.ok && verifyData.paymentStatus === 'PAID') {
            paymentSuccess = true
            clearInterval(pollTimer)
            clearCart()
            triggerHaptic('success')
            toast.success('🎉 Payment Verified Successfully!')
            window.location.href = `/order/${orderData.id}/success`
          }
        } catch (_) {}
      }, 2500)

      // Launch Cashfree In-Page Modal
      try {
        await cashfree.checkout({
          paymentSessionId: cfData.paymentSessionId,
          redirectTarget: '_modal',
        })
      } catch (checkoutErr) {
        console.warn('Cashfree checkout modal note:', checkoutErr)
      }

      // Check status once modal closes
      setTimeout(async () => {
        if (!paymentSuccess) {
          try {
            const verifyRes = await fetch('/api/payment/cashfree/verify', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ orderId: orderData.id }),
            })
            const verifyData = await verifyRes.json()
            if (verifyRes.ok && verifyData.paymentStatus === 'PAID') {
              paymentSuccess = true
              clearInterval(pollTimer)
              clearCart()
              triggerHaptic('success')
              toast.success('🎉 Payment Successful!')
              window.location.href = `/order/${orderData.id}/success`
              return
            }
          } catch (_) {}

          setIsPlacingOrder(false)
          triggerHaptic('warning')
          toast.info('Payment window closed. You can retry or switch payment method.')
        }
      }, 1500)

    } catch (err) {
      console.error('Error during Cashfree checkout:', err)
      toast.error('An unexpected error occurred during checkout.')
      setIsPlacingOrder(false)
    }
  }

  const handleRazorpayCheckout = async (
    overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET',
    overrideAddressId?: string,
    overrideAddresses?: Address[]
  ) => {
    const selectedMethod = overrideMethod || paymentMethod
    const activeAddresses = overrideAddresses || addresses
    const activeAddressId = overrideAddressId || selectedAddressId
    const activeSelectedAddress = activeAddresses.find(a => a.id === activeAddressId) || selectedAddress

    setIsPlacingOrder(true)
    try {
      // 1. Validate checkout eligibility
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map(i => ({ product: i.product as CartItem['product'] })),
        addresses: activeAddresses,
        selectedAddressId: activeAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      // 2. Pre-create DB Order in PENDING / UNPAID state BEFORE opening Razorpay (reuses existing pending order on retry)
      const effectiveCustomerPhone = getEffectiveCustomerPhone(activeSelectedAddress)
      const finalNotes = getOrderNotes()

      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        customerPhone: effectiveCustomerPhone,
        contactPhone,
        packagingOption,
        packagingFee,
      })

      const orderRes = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...payload,
          existingOrderId: activePendingOrderId || undefined,
          notes: finalNotes
        }),
      })

      const orderData = await orderRes.json()

      if (!orderRes.ok) {
        toast.error(orderData.error || 'Failed to initialize order')
        setIsPlacingOrder(false)
        return
      }

      // Save pending order ID to reuse if customer retries or switches payment method
      setActivePendingOrderId(orderData.id)

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
          ondismiss: async function () {
            if (!paymentSuccess) {
              // Try syncing with Razorpay before giving up — customer might have paid in external UPI app
              try {
                const syncRes = await fetch('/api/payment/razorpay/sync-order', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ orderId: orderData.id }),
                })
                const syncData = await syncRes.json()
                if (syncRes.ok && syncData.paymentStatus === 'PAID') {
                  clearCart()
                  triggerHaptic('success')
                  toast.success('🎉 Payment Successful!')
                  window.location.href = `/order/${orderData.id}/success`
                  return
                }
              } catch (_) {}

              setIsPlacingOrder(false)
              triggerHaptic('warning')
              toast.info('Payment was not completed. You can retry or switch payment method.')
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

      // Real-time auto-polling loop: automatically detects payment completion (e.g. from UPI apps)
      let pollCount = 0
      const pollTimer = setInterval(async () => {
        pollCount++
        if (pollCount > 60 || paymentSuccess) {
          clearInterval(pollTimer)
          return
        }
        try {
          const syncRes = await fetch('/api/payment/razorpay/sync-order', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId: orderData.id }),
          })
          const syncData = await syncRes.json()
          if (syncRes.ok && syncData.paymentStatus === 'PAID') {
            paymentSuccess = true
            clearInterval(pollTimer)
            clearCart()
            triggerHaptic('success')
            toast.success('🎉 Payment Verified Automatically!')
            window.location.href = `/order/${orderData.id}/success`
          }
        } catch (_) {}
      }, 2500)
    } catch (err) {
      toast.error('An unexpected error occurred during Razorpay checkout.')
      setIsPlacingOrder(false)
    }
  }

  const handlePlaceOrderClick = async () => {
    if (isPlacingOrder || isSavingAddress) return

    let effectiveAddressId = selectedAddressId
    let effectiveAddresses = addresses

    if (showNewAddressForm) {
      const hasEnteredStreet = addressForm.street && addressForm.street.trim().length > 0
      if (hasEnteredStreet) {
        // Seamlessly auto-save the address on-the-fly without forcing the user to find/click 'Save & Select'
        const result = await saveAddressCore()
        if (!result) {
          const el = document.getElementById('new-address-form')
          if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
          return
        }
        effectiveAddressId = result.savedAddress.id
        effectiveAddresses = result.newAddresses
      } else if (addresses.length > 0) {
        // Address form was open but empty; fall back to already selected or primary address
        setShowNewAddressForm(false)
        setEditingAddressId(null)
        effectiveAddressId = selectedAddressId || addresses[0].id
        setSelectedAddressId(effectiveAddressId)
      } else {
        // No saved address and empty address form
        triggerHaptic('warning')
        toast.error('Please enter your delivery address')
        const el = document.getElementById('new-address-form')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }
    }

    activeCheckoutAddressRef.current = { id: effectiveAddressId, addresses: effectiveAddresses }

    if (deliveryMethod === 'DELIVERY') {
      const targetId = effectiveAddressId || (effectiveAddresses.length > 0 ? effectiveAddresses[0].id : '')
      if (!targetId) {
        triggerHaptic('warning')
        toast.error('Please select or add a delivery address')
        const el = document.getElementById('address-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }

      const activeAddress = effectiveAddresses.find(a => a.id === targetId)
      if (activeAddress && activeAddress.lat && activeAddress.lng && storeSettingsMap.store_lat && storeSettingsMap.store_lng) {
        const storeLatVal = parseFloat(storeSettingsMap.store_lat) || DEFAULT_STORE_LAT
        const storeLngVal = parseFloat(storeSettingsMap.store_lng) || DEFAULT_STORE_LNG
        const maxDist = parseFloat(storeSettingsMap.delivery_radius || String(DEFAULT_DELIVERY_RADIUS_KM))
        const dist = getDistanceKm(storeLatVal, storeLngVal, activeAddress.lat, activeAddress.lng)
        if (dist > maxDist) {
          triggerHaptic('warning')
          toast.error(`Your address is outside our delivery zone (${dist.toFixed(1)} km away). We deliver only up to ${maxDist} km.`)
          return
        }
      } else if (deliveryRules && !deliveryRules.isServiceable) {
        triggerHaptic('warning')
        toast.error(`Your address is outside our delivery zone (${distanceKm?.toFixed(1)} km away). We deliver only up to 3 km.`)
        return
      }
    }

    if (orderForSomeone) {
      if (!recipientName.trim()) {
        triggerHaptic('warning')
        toast.error('Please enter recipient name (कृपया प्राप्तकर्ता का नाम लिखें)')
        const el = document.getElementById('order-for-someone-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }
      const cleanP = recipientPhone.replace(/\D/g, '')
      if (cleanP && cleanP.length !== 10) {
        triggerHaptic('warning')
        toast.error('Please enter a valid 10-digit phone number (कृपया 10 अंकों का फोन नंबर लिखें)')
        const el = document.getElementById('order-for-someone-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }
    }

    if (onlyCod) {
      setPaymentMethod('COD')
      handlePlaceOrder('COD', effectiveAddressId, effectiveAddresses)
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
  const hasRestaurant = items.some((item) => (item.product as any).restaurantId || (item.product as any).restaurant || item.product.category?.slug === 'restaurant' || (item.product as any).tags?.includes('restaurant'))
  const hasGrocery = items.some((item) => {
    const isC = item.product.category?.slug === 'cafe' || (item.product as any).tags?.includes('cafe')
    const isR = (item.product as any).restaurantId || (item.product as any).restaurant || item.product.category?.slug === 'restaurant' || (item.product as any).tags?.includes('restaurant')
    return !isC && !isR
  })

  const closedItems = items.filter((item) => {
    return isProductStoreClosed(
      item.product,
      { groceryMartOpen, cafeOpen, restaurantOpen }
    )
  })
  const isStoreClosed = closedItems.length > 0

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


  if (isStoreClosed && !isSettingsLoading) {
    const handleRemoveClosedItems = () => {
      let count = 0
      closedItems.forEach(item => {
        removeItem(item.product.id, item.product.name)
        count++
      })
      if (count > 0) {
        toast.success(`Removed closed outlet item(s) from your cart!`)
      }
    }

    const closedOutletNames = Array.from(
      new Set(
        closedItems.map(
          i => (i.product as any).restaurant?.name || (i.product as any).shopName || (isCafeProduct(i.product) ? 'Cafe' : 'Grocery Mart')
        ).filter(Boolean)
      )
    )

    return (
      <div className="container mx-auto px-4 py-16 max-w-md text-center space-y-6 animate-fade-in">
        <div className="h-20 w-20 bg-amber-50 dark:bg-amber-950/20 text-amber-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner animate-pulse-gentle border border-amber-200/60 dark:border-amber-900/40">
          🏪
        </div>
        <h1 className="text-2xl font-black text-text-primary">Outlet Closed Temporarily</h1>
        <p className="text-sm text-text-secondary leading-relaxed">
          {closedOutletNames.length > 0 ? closedOutletNames.join(' & ') : 'This store'} is temporarily closed right now. You can proceed with your order by removing items from this closed outlet.
        </p>
        <div className="space-y-2 max-h-48 overflow-y-auto p-2 bg-muted/20 rounded-xl border border-border/50">
          {closedItems.map(item => (
            <div key={item.product.id} className="flex items-center justify-between text-xs py-1.5 px-2 font-bold text-left">
              <span className="truncate flex-1">{item.product.name}</span>
              <span className="text-amber-600 dark:text-amber-400 font-black text-[10px] uppercase ml-2 bg-amber-500/10 px-1.5 py-0.5 rounded">
                Closed Outlet
              </span>
            </div>
          ))}
        </div>
        <div className="pt-4 flex flex-col gap-3">
          <button
            onClick={handleRemoveClosedItems}
            className="w-full px-6 py-3 bg-primary text-white font-black text-xs rounded-full hover:bg-primary-dark transition-all shadow-md active:scale-98 cursor-pointer"
          >
            Remove Closed Items & Proceed
          </button>
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
              {/* Delivery Address Section */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h2 className="text-base sm:text-lg font-black text-text-primary flex items-center gap-2">
                    <MapPin className="h-5 w-5 text-primary" />
                    <span>Delivery Address (डिलीवरी पता)</span>
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
                          pincode: DEFAULT_STORE_PINCODE,
                          phone: addressForm.phone,
                          isDefault: false,
                          lat: null,
                          lng: null,
                        })
                        setEditingAddressId(null)
                        setShowNewAddressForm(true)
                        setIsChangingAddress(false)
                      }}
                      className="text-xs font-black text-primary hover:underline flex items-center gap-1 cursor-pointer"
                    >
                      <Plus className="h-3.5 w-3.5" />
                      <span>+ Add New</span>
                    </button>
                  )}
                </div>

                {isAddressesLoading ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="h-6 w-6 animate-spin text-primary" />
                  </div>
                ) : (
                  <div id="address-section" className="space-y-3 scroll-mt-24">
                    {/* Primary Selected Address Card */}
                    {!showNewAddressForm && selectedAddress && (
                      <div className="rounded-2xl border-2 border-primary/30 bg-gradient-to-br from-primary/[0.03] to-emerald-500/[0.02] p-4 sm:p-5 relative overflow-hidden transition-all shadow-xs">
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-start gap-3.5 min-w-0">
                            <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0 text-xl font-bold">
                              {selectedAddress.label === 'Work' ? '🏢' : selectedAddress.label === 'Other' ? '📍' : '🏠'}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <span className="font-black text-sm text-text-primary">
                                  {selectedAddress.label || 'Home'}
                                </span>
                                <span className="inline-flex items-center gap-1 text-[10px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/10 px-2.5 py-0.5 rounded-full border border-emerald-500/20">
                                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                  15–25 Mins Express
                                </span>
                                {selectedAddress.isDefault && (
                                  <span className="text-[9px] font-bold text-accent bg-accent/10 px-2 py-0.5 rounded-md">
                                    Default
                                  </span>
                                )}
                              </div>
                              <p className="text-xs text-text-secondary mt-1 font-semibold leading-relaxed break-words">
                                {formatAddress(selectedAddress)}
                              </p>
                              {selectedAddress.phone && (
                                <p className="text-[11px] text-text-muted mt-1 font-medium flex items-center gap-1">
                                  <span>📞</span> {formatPhone(selectedAddress.phone)}
                                </p>
                              )}
                            </div>
                          </div>
                          <div className="flex items-center gap-2 shrink-0">
                            <button
                              type="button"
                              onClick={() => setIsChangingAddress(!isChangingAddress)}
                              className="px-3 py-1.5 rounded-xl border border-primary/30 bg-white dark:bg-zinc-800 text-primary text-xs font-black hover:bg-primary/5 active:scale-95 transition-all shadow-xs cursor-pointer"
                            >
                              {isChangingAddress ? 'Done' : 'Change / बदलें'}
                            </button>
                          </div>
                        </div>

                        {/* Distance / zone check */}
                        {(() => {
                          const addrDist = (selectedAddress.lat && selectedAddress.lng) ? getDistanceKm(storeLat, storeLng, selectedAddress.lat, selectedAddress.lng) : null
                          const maxRadiusKm = parseFloat(storeSettingsMap['delivery_radius'] || storeSettingsMap['max_delivery_radius'] || '5.0')
                          if (addrDist !== null && addrDist > maxRadiusKm) {
                            return (
                              <div className="mt-3 text-xs font-bold text-rose-600 bg-rose-500/10 p-2.5 rounded-xl border border-rose-500/20 flex items-center gap-2">
                                <span>⚠️</span>
                                <span>This address is {addrDist.toFixed(1)} km away (outside our 5 km delivery zone). Please pick an address in Ghatampur.</span>
                              </div>
                            )
                          }
                          return null
                        })()}
                      </div>
                    )}

                    {/* Expandable list of saved addresses (when user taps 'Change') */}
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
                              "p-3 rounded-xl border-2 cursor-pointer transition-all flex items-center justify-between gap-3 text-xs bg-card",
                              selectedAddressId === addr.id
                                ? "border-primary bg-primary/[0.02] shadow-xs"
                                : "border-border/60 hover:border-primary/40"
                            )}
                          >
                            <div className="flex items-center gap-2.5 min-w-0">
                              <span className="text-base">{addr.label === 'Work' ? '🏢' : addr.label === 'Other' ? '📍' : '🏠'}</span>
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

                    {/* Clean, Simple & Modern Address Form */}
                    {showNewAddressForm && (
                      <form id="new-address-form" onSubmit={handleSaveAddress} className="border-2 border-primary/25 p-4 sm:p-5 rounded-2xl space-y-4 bg-card shadow-sm animate-slide-up">
                        <div className="flex items-center justify-between border-b border-border/40 pb-3">
                          <div className="flex items-center gap-2">
                            <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold">
                              <MapPin className="h-4 w-4" />
                            </div>
                            <div>
                              <h3 className="font-black text-sm text-text-primary">
                                {editingAddressId ? 'Edit Address' : 'Add Delivery Address (डिलीवरी पता)'}
                              </h3>
                              <p className="text-[10.5px] text-text-muted">Ghatampur express delivery (15-25 mins)</p>
                            </div>
                          </div>
                          {addresses.length > 0 && (
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
                          className="w-full flex items-center justify-center gap-2 p-3 rounded-xl bg-emerald-50 dark:bg-emerald-950/25 border-2 border-emerald-500/30 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100/50 dark:hover:bg-emerald-900/30 transition-all font-black text-xs active:scale-[0.99] shadow-xs cursor-pointer"
                        >
                          {isDetectingLocation ? (
                            <>
                              <Loader2 className="h-4 w-4 animate-spin text-emerald-600" />
                              <span>GPS लोकेशन ढूंढी जा रही है...</span>
                            </>
                          ) : (
                            <>
                              <span className="text-base">📍</span>
                              <span>Use Current Location (मेरी वर्तमान लोकेशन लगाएं)</span>
                            </>
                          )}
                        </button>

                        {/* Address Label Selector */}
                        <div>
                          <Label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider">Address Type</Label>
                          <div className="grid grid-cols-3 gap-2 mt-1.5">
                            {[
                              { key: 'Home', label: 'Home / घर', icon: '🏠' },
                              { key: 'Work', label: 'Work / ऑफिस', icon: '🏢' },
                              { key: 'Other', label: 'Other / अन्य', icon: '📍' },
                            ].map((item) => (
                              <button
                                key={item.key}
                                type="button"
                                onClick={() => setAddressForm({ ...addressForm, label: item.key })}
                                className={cn(
                                  "h-10 text-xs font-black rounded-xl border transition-all flex items-center justify-center gap-1.5 active:scale-95 cursor-pointer",
                                  addressForm.label === item.key
                                    ? "bg-primary text-white border-primary shadow-xs"
                                    : "bg-background border-border text-text-secondary hover:border-primary/40"
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
                          <Label htmlFor="street" className="text-[11px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between">
                            <span>Complete Address (मकान नं., रास्ता, लैंडमार्क)</span>
                            <span className="text-red-500 font-bold">*</span>
                          </Label>
                          <textarea
                            id="street"
                            required
                            rows={2}
                            placeholder="उदा. मकान नं. 12, स्टेशन रोड, स्टेट बैंक के पास, घाटमपुर"
                            value={addressForm.street}
                            onChange={(e) => setAddressForm({ ...addressForm, street: e.target.value })}
                            className="mt-1.5 block w-full rounded-xl border border-border bg-background px-3.5 py-2.5 text-xs font-semibold focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary placeholder:text-text-muted/60"
                          />
                        </div>

                        {/* Phone & Pincode/City Grid */}
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                          <div>
                            <Label htmlFor="phone" className="text-[11px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between">
                              <span>Phone Number (मोबाइल नंबर)</span>
                              <span className="text-red-500 font-bold">*</span>
                            </Label>
                            <Input
                              id="phone"
                              type="tel"
                              required
                              maxLength={10}
                              placeholder="10 अंकों का मोबाइल नंबर"
                              value={addressForm.phone}
                              onChange={(e) => setAddressForm({ ...addressForm, phone: getLast10Digits(e.target.value) })}
                              className="mt-1 h-10 text-xs font-bold rounded-xl border-border bg-background"
                            />
                          </div>
                          <div>
                            <Label htmlFor="city-pincode" className="text-[11px] font-bold text-text-secondary uppercase tracking-wider">
                              <span>City & Pincode</span>
                            </Label>
                            <div className="mt-1 h-10 px-3 flex items-center justify-between rounded-xl border border-border bg-muted/30 text-xs font-bold text-text-secondary">
                              <span>Ghatampur</span>
                              <span className="text-primary font-black">209206</span>
                            </div>
                          </div>
                        </div>

                        {/* Optional Map Toggle */}
                        <div className="pt-1">
                          <button
                            type="button"
                            onClick={() => setShowMapPicker(!showMapPicker)}
                            className="text-xs font-bold text-primary flex items-center gap-1.5 hover:underline cursor-pointer"
                          >
                            <span>🗺️</span>
                            <span>{showMapPicker ? 'Hide map pin' : 'Adjust pin on map (वैकल्पिक)'}</span>
                          </button>
                          {showMapPicker && (
                            <div className="mt-2.5 rounded-xl overflow-hidden border border-border animate-slide-down">
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
                        <div className="flex gap-2.5 justify-end pt-2 border-t border-border/40">
                          {addresses.length > 0 && (
                            <Button
                              type="button"
                              variant="ghost"
                              onClick={handleCancelAddressForm}
                              disabled={isSavingAddress}
                              className="rounded-xl text-xs font-bold h-10 px-4 cursor-pointer"
                            >
                              Cancel
                            </Button>
                          )}
                          <Button
                            type="submit"
                            disabled={isSavingAddress}
                            className="bg-primary text-white rounded-xl text-xs font-black px-6 h-10 hover:bg-primary/95 shadow-md active:scale-98 transition-all flex items-center gap-2 cursor-pointer"
                          >
                            {isSavingAddress ? (
                              <>
                                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                                <span>Saving...</span>
                              </>
                            ) : (
                              <span>{editingAddressId ? 'Update Address' : 'Deliver to this Address (इस पते पर मंगवाएं) »'}</span>
                            )}
                          </Button>
                        </div>
                      </form>
                    )}
                  </div>
                )}
              </div>

              {/* Order For Someone Else Card */}
              <div id="order-for-someone-section" className="rounded-2xl border border-border/80 bg-card p-3.5 sm:p-4 shadow-sm space-y-3 transition-all">
                <div
                  role="button"
                  tabIndex={0}
                  onClick={() => {
                    triggerHaptic('light')
                    setOrderForSomeone(!orderForSomeone)
                  }}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault()
                      setOrderForSomeone(!orderForSomeone)
                    }
                  }}
                  className="flex items-center justify-between cursor-pointer select-none"
                >
                  <div className="flex items-center gap-3">
                    <div className={cn(
                      "h-9 w-9 rounded-xl flex items-center justify-center text-lg shrink-0 transition-colors",
                      orderForSomeone ? "bg-amber-500 text-white shadow-md shadow-amber-500/20" : "bg-amber-500/10 text-amber-600 dark:text-amber-400"
                    )}>
                      🎁
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs sm:text-sm font-black text-text-primary">
                          Ordering for someone else?
                        </span>
                        <span className="text-[10px] font-bold text-amber-700 dark:text-amber-300 bg-amber-500/15 px-2 py-0.5 rounded-full">
                          किसी और के लिए?
                        </span>
                      </div>
                      <p className="text-[11px] text-text-secondary font-medium mt-0.5">
                        दोस्त या परिवार के सदस्य के लिए सामान मंगवाएं
                      </p>
                    </div>
                  </div>

                  {/* Switch Pill */}
                  <div className={cn(
                    "w-11 h-6 rounded-full p-0.5 transition-colors duration-200 flex items-center shrink-0",
                    orderForSomeone ? "bg-primary" : "bg-muted-foreground/25"
                  )}>
                    <div className={cn(
                      "w-5 h-5 rounded-full bg-white shadow-md transform transition-transform duration-200 flex items-center justify-center text-[10px]",
                      orderForSomeone ? "translate-x-5 text-primary" : "translate-x-0"
                    )}>
                      {orderForSomeone && <Check className="h-3 w-3 stroke-[3]" />}
                    </div>
                  </div>
                </div>

                {/* Collapsible Details Inputs */}
                {orderForSomeone && (
                  <div className="pt-2 border-t border-border/40 space-y-3 animate-in fade-in slide-in-from-top-2 duration-200">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <Label htmlFor="recipient-name" className="text-[11px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between">
                          <span>Recipient's Name (नाम)</span>
                          <span className="text-red-500 font-bold">*</span>
                        </Label>
                        <Input
                          id="recipient-name"
                          type="text"
                          required
                          placeholder="उदा. राहुल शर्मा (Recipient Name)"
                          value={recipientName}
                          onChange={(e) => setRecipientName(e.target.value)}
                          className="mt-1 h-10 text-xs font-bold rounded-xl border-border bg-background"
                        />
                      </div>
                      <div>
                        <Label htmlFor="recipient-phone" className="text-[11px] font-bold text-text-secondary uppercase tracking-wider flex items-center justify-between">
                          <span>Phone Number (मोबाइल नंबर)</span>
                          <span className="text-text-muted font-normal text-[10px]">वैकल्पिक / Optional</span>
                        </Label>
                        <Input
                          id="recipient-phone"
                          type="tel"
                          maxLength={10}
                          placeholder="10 अंकों का मोबाइल नंबर"
                          value={recipientPhone}
                          onChange={(e) => setRecipientPhone(getLast10Digits(e.target.value))}
                          className="mt-1 h-10 text-xs font-bold rounded-xl border-border bg-background"
                        />
                      </div>
                    </div>

                    <div className="p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/20 text-[11px] font-semibold text-amber-800 dark:text-amber-300 flex items-center gap-2">
                      <span className="text-base shrink-0">📞</span>
                      <span>डिलीवरी राइडर सीधे इस नंबर पर संपर्क करेगा और सही व्यक्ति को सामान डिलीवर होगा।</span>
                    </div>
                  </div>
                )}
              </div>

              {/* Cart Items Review */}
              <div className="border-t border-border/40 pt-4 space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
                    <ShoppingBag className="h-4 w-4 text-primary" />
                    <span>Order Items ({items.length})</span>
                  </h3>
                  <Link href="/cart" className="text-xs font-bold text-primary hover:underline">
                    Edit Cart
                  </Link>
                </div>

                <div className="rounded-2xl border border-border/70 bg-muted/10 p-3 sm:p-4 space-y-3">
                  <div className="divide-y divide-border/40">
                    {items.map((item) => (
                      <div key={item.product.id} className="flex justify-between items-center py-2.5 first:pt-0 last:pb-0 text-xs font-semibold">
                        <div className="flex items-center gap-2.5 min-w-0 pr-2">
                          {item.product.imageUrl && (
                            <img src={item.product.imageUrl} alt={item.product.name} className="w-10 h-10 object-cover rounded-xl border border-border/50 shrink-0 bg-white" />
                          )}
                          <div className="truncate">
                            <h4 className="text-text-primary font-bold truncate text-xs">{item.product.name}</h4>
                            <p className="text-[10.5px] text-text-muted mt-0.5">
                              {item.product.unit || '1 unit'} × <span className="font-bold text-text-primary">{item.quantity}</span>
                            </p>
                          </div>
                        </div>
                        <span className="text-text-primary font-black shrink-0 text-xs">
                          ₹{(item.product.price * item.quantity).toFixed(0)}
                        </span>
                      </div>
                    ))}
                  </div>

                  {/* Single Delivery / Cooking Note Input */}
                  <div className="pt-2 border-t border-border/30">
                    <div className="flex items-center gap-2 p-2 rounded-xl border border-border/70 bg-background focus-within:border-primary">
                      <span className="text-sm shrink-0">📝</span>
                      <input
                        type="text"
                        placeholder="Add note for restaurant / rider (उदा. कम मिर्च, रिंग बेल बजाएं)..."
                        value={cookingInstruction}
                        onChange={(e) => setCookingInstruction(e.target.value)}
                        className="w-full text-xs font-semibold bg-transparent placeholder:text-text-muted/60 focus:outline-none"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Food Packaging Option (Shown only when cafe/restaurant items are present) */}
              {(hasCafeItems || cafeCartItems.length > 0) && (
                <div className="border-t border-border/40 pt-4 space-y-2.5">
                  <div className="flex items-center justify-between">
                    <h3 className="text-xs sm:text-sm font-black text-text-primary flex items-center gap-1.5">
                      <span>🍱</span>
                      <span>Food Packaging</span>
                    </h3>
                    <span className="text-[10px] font-bold text-text-muted">Safe & Hot Delivery</span>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                    {/* Standard Packaging (₹0) */}
                    <div
                      onClick={() => {
                        triggerHaptic('light')
                        setPackagingOption('NORMAL')
                      }}
                      className={cn(
                        "p-3 rounded-xl border-2 cursor-pointer transition-all flex items-center justify-between select-none",
                        packagingOption === 'NORMAL'
                          ? "border-primary bg-primary/[0.02] shadow-xs"
                          : "border-border/60 hover:border-border"
                      )}
                    >
                      <div>
                        <div className="flex items-center gap-1.5 font-bold text-xs text-text-primary">
                          <span>📦</span> Standard Eco Box
                        </div>
                        <p className="text-[10.5px] text-text-muted mt-0.5">Eco-friendly packaging</p>
                      </div>
                      <span className="text-emerald-600 dark:text-emerald-400 font-black text-[11px] bg-emerald-50 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md">
                        FREE
                      </span>
                    </div>

                    {/* Premium Thermal Packaging (₹15) */}
                    <div
                      onClick={() => {
                        triggerHaptic('light')
                        setPackagingOption('PREMIUM')
                      }}
                      className={cn(
                        "p-3 rounded-xl border-2 cursor-pointer transition-all flex items-center justify-between select-none",
                        packagingOption === 'PREMIUM'
                          ? "border-amber-500 bg-amber-500/[0.04] shadow-xs ring-1 ring-amber-500/20"
                          : "border-border/60 hover:border-amber-500/40"
                      )}
                    >
                      <div>
                        <div className="flex items-center gap-1.5 font-bold text-xs text-text-primary">
                          <span>✨</span> Thermal Hot Box
                        </div>
                        <p className="text-[10.5px] text-text-muted mt-0.5">Insulated + spill-proof</p>
                      </div>
                      <span className="text-amber-600 dark:text-amber-400 font-black text-[11px] bg-amber-50 dark:bg-amber-950/40 px-2 py-0.5 rounded-md">
                        +₹15
                      </span>
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
                  isPlacingOrder={isPlacingOrder || isSavingAddress}
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
                  {deliveryRules?.zoneName ? `${deliveryRules.zoneName} · ` : ''}
                  {adjustedSubtotal >= ((deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200))
                    ? `Free delivery on orders ₹${(deliveryRules && deliveryRules.isServiceable) ? deliveryRules.freeDeliveryThreshold : (groceryThreshold || 200)}+`
                    : `Standard delivery fee`}
                </span>
              </div>
              <span className={cn(baseDeliveryFee === 0 ? "text-accent font-black text-xs" : "")}>
                {baseDeliveryFee === 0 ? 'FREE 🎉' : `₹${baseDeliveryFee}`}
              </span>
            </div>

            {appliedSurgeFee > 0 && (
              <div className="flex justify-between items-center text-amber-700 dark:text-amber-400 font-bold bg-amber-500/10 px-2.5 py-1.5 rounded-lg border border-amber-500/20">
                <div className="flex flex-col text-left">
                  <span className="flex items-center gap-1 text-xs">
                    <span>⚡</span> {deliveryRules?.surgeReason || 'Delivery Surge'}
                  </span>
                  <span className="text-[9px] text-amber-600/80 dark:text-amber-400/80 font-normal">
                    Applied for rider safety & high demand
                  </span>
                </div>
                <span>+₹{appliedSurgeFee}</span>
              </div>
            )}

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

            {selectedAddress && (
              <>
                {deliveryRules && !deliveryRules.isServiceable && (
                  <div className="bg-rose-50 dark:bg-rose-950/20 border border-rose-200 dark:border-rose-900/50 p-2.5 rounded-xl text-center mt-2">
                    <p className="text-[10px] font-black text-rose-600 dark:text-rose-400">
                      ❌ Address is {distanceKm?.toFixed(1)} km away. Delivery only available up to 5 km.
                    </p>
                  </div>
                )}
                {deliveryRules && deliveryRules.isServiceable && (
                  <div className={cn(
                    "p-2.5 rounded-xl border text-center mt-2 flex items-center justify-center gap-1.5",
                    adjustedSubtotal >= deliveryRules.freeDeliveryThreshold
                      ? "bg-emerald-50 dark:bg-emerald-950/20 border-emerald-200/50 dark:border-emerald-900/30 text-emerald-700 dark:text-emerald-300 font-extrabold text-[10.5px]"
                      : "bg-blue-50 dark:bg-blue-950/20 border-blue-200/50 dark:border-blue-900/30 text-blue-700 dark:text-blue-300 font-extrabold text-[10.5px]"
                  )}>
                    <span>{adjustedSubtotal >= deliveryRules.freeDeliveryThreshold ? '🎉' : '🚚'}</span>
                    <span>
                      {adjustedSubtotal >= deliveryRules.freeDeliveryThreshold
                        ? "Congratulations! FREE Delivery Unlocked for your location!"
                        : `Add ₹${(deliveryRules.freeDeliveryThreshold - adjustedSubtotal).toFixed(0)} more for FREE Delivery (Free on ₹${deliveryRules.freeDeliveryThreshold}+)`}
                    </span>
                  </div>
                )}
              </>
            )}

            {/* Savings Callout */}
            {(grocerySavings + groceryB2BDiscount + cafeSavings + cafeB2BDiscount + couponDiscount) > 0 && (
              <div className="bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 p-2.5 rounded-xl text-xs font-black flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <span>🎉</span> You Save on this Order
                </span>
                <span>₹{(grocerySavings + groceryB2BDiscount + cafeSavings + cafeB2BDiscount + couponDiscount).toFixed(0)}</span>
              </div>
            )}

            {/* Grand Total */}
            <div className="border-t-2 border-dashed border-border/60 pt-3 mt-3 flex justify-between items-center text-base font-black text-text-primary">
              <span>To Pay (कुल भुगतान)</span>
              <span className="text-primary text-xl font-black">₹{grandTotal.toFixed(0)}</span>
            </div>
          </div>
          
          <div className="text-[10px] text-text-muted text-center pt-2 leading-relaxed flex items-center justify-center gap-1.5">
            <ShieldCheck className="h-3.5 w-3.5 text-emerald-500" />
            <span>100% Safe &amp; Contactless Delivery</span>
          </div>
        </div>

      </div>

      {/* Mobile Sticky Bottom Checkout Bar (Zepto/Blinkit Style) */}
      <div 
        className="fixed bottom-0 left-0 right-0 z-40 md:hidden bg-white dark:bg-zinc-950 border-t border-border/80 shadow-[0_-8px_30px_rgba(0,0,0,0.08)] px-4 py-3 flex items-center justify-between"
        style={{ paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 12px)' }}
      >
        <div className="flex flex-col min-w-0 pr-2">
          <span className="text-[10px] text-text-secondary font-medium leading-none">To Pay</span>
          <span className="text-lg font-black text-primary leading-tight mt-0.5">₹{grandTotal.toFixed(0)}</span>
          <div className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1 mt-0.5 truncate">
            {selectedAddress ? (
              <span className="truncate">📍 {selectedAddress.label || selectedAddress.street}</span>
            ) : (
              <span className="text-rose-500">📍 Select Address</span>
            )}
          </div>
        </div>

        <button
          type="button"
          disabled={isPlacingOrder || isSavingAddress}
          onClick={handlePlaceOrderClick}
          className={cn(
            "group relative overflow-hidden text-white rounded-2xl font-black text-xs sm:text-sm tracking-wide px-5 h-12 transition-all duration-300 active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg shrink-0",
            paymentMethod !== 'COD'
              ? "bg-gradient-to-r from-emerald-600 to-teal-600 shadow-emerald-500/25 hover:shadow-emerald-500/40"
              : "bg-gradient-to-r from-primary to-primary-dark shadow-primary/25 hover:shadow-primary/40",
            (isPlacingOrder || isSavingAddress) && "opacity-60 cursor-not-allowed shadow-none"
          )}
        >
          {isPlacingOrder || isSavingAddress ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin text-white relative z-10" />
              <span className="relative z-10">{isSavingAddress ? 'Saving Address...' : 'Processing...'}</span>
            </>
          ) : (
            <>
              <span className="relative z-10">Place Order (₹{grandTotal.toFixed(0)})</span>
              <ChevronsRight className="h-4 w-4 text-white relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
            </>
          )}
        </button>
      </div>

      <PaymentSelectionModal
        isOpen={isPaymentModalOpen}
        onClose={() => setIsPaymentModalOpen(false)}
        grandTotal={grandTotal}
        onlyCod={onlyCod}
        deliveryMethod={deliveryMethod}
        isPlacingOrder={isPlacingOrder}
        onSelectCod={() => {
          setIsPaymentModalOpen(false)
          setPaymentMethod('COD')
          handlePlaceOrder(
            'COD',
            activeCheckoutAddressRef.current?.id || selectedAddressId,
            activeCheckoutAddressRef.current?.addresses || addresses
          )
        }}
        onSelectOnline={() => {
          setIsPaymentModalOpen(false)
          setPaymentMethod('UPI')
          handleCashfreeCheckout(
            'UPI',
            activeCheckoutAddressRef.current?.id || selectedAddressId,
            activeCheckoutAddressRef.current?.addresses || addresses
          )
        }}
      />
    </div>
  )
}
