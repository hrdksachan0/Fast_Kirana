'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn, isCafeProduct } from '@/lib/utils'
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
} from 'lucide-react'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import { Address } from '@/types'

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

export default function CheckoutPage() {
  const router = useRouter()
  const { items, removeItem, clearCart, getSubtotal, getSavings, getMrpTotal } = useCart()

  // Steps: 1 = Address, 2 = Review, 3 = Payment
  const [step, setStep] = useState(1)
  const [addresses, setAddresses] = useState<Address[]>([])
  const [selectedAddressId, setSelectedAddressId] = useState<string>('')
  const [deliveryRadius, setDeliveryRadius] = useState(5.0)
  const [storeLat, setStoreLat] = useState(26.1534185)
  const [storeLng, setStoreLng] = useState(80.1714024)

  useEffect(() => {
    fetch('/api/settings')
      .then(res => res.json())
      .then(data => {
        if (data.delivery_radius) {
          setDeliveryRadius(parseFloat(data.delivery_radius))
        }
        if (data.store_lat) {
          setStoreLat(parseFloat(data.store_lat))
        }
        if (data.store_lng) {
          setStoreLng(parseFloat(data.store_lng))
        }
      })
      .catch(err => console.error('Error fetching settings on checkout mount:', err))
  }, [])
  const [isAddressesLoading, setIsAddressesLoading] = useState(true)
  const [isPlacingOrder, setIsPlacingOrder] = useState(false)

  // New Address Form State
  const [showNewAddressForm, setShowNewAddressForm] = useState(false)
  const [isSavingAddress, setIsSavingAddress] = useState(false)
  const [addressForm, setAddressForm] = useState({
    label: 'Home',
    houseNo: '',
    street: '',
    area: '',
    city: '',
    pincode: '',
    phone: '',
    isDefault: false,
  })

  const [isDetectingLocation, setIsDetectingLocation] = useState(false)

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
          setAddressForm({
            label: addressForm.label || 'Home',
            houseNo: 'Vikas Medical Store',
            street: 'NH34, Ghatampur',
            area: 'Kanpur Nagar',
            city: 'Kanpur',
            pincode: '209206',
            phone: addressForm.phone,
            isDefault: addressForm.isDefault,
          })
          toast.success('Location detected and filled (Kanpur NH34 mock)!')
          return
        } else if (dist > deliveryRadius) {
          toast.dismiss(toastId)
          setIsDetectingLocation(false)
          toast.error(`Detected location is outside our delivery zone! (${dist.toFixed(1)} km away. Delivery radius is ${deliveryRadius} km.)`)
          return
        }

        fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=16&addressdetails=1`)
          .then((res) => res.json())
          .then((data) => {
            toast.dismiss(toastId)
            if (data && data.address) {
              const address = data.address
              setAddressForm({
                label: addressForm.label || 'Home',
                houseNo: address.building || address.house_number || '',
                street: address.road || address.suburb || '',
                area: address.neighbourhood || address.city_district || address.suburb || '',
                city: address.city || address.town || address.village || '',
                pincode: address.postcode || '',
                phone: addressForm.phone,
                isDefault: addressForm.isDefault,
              })
              toast.success('Location detected and filled!')
            } else {
              toast.error('Failed to parse address details.')
            }
          })
          .catch(() => {
            toast.dismiss(toastId)
            toast.error('Error fetching details from map server.')
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

  // Payment Method
  const [paymentMethod, setPaymentMethod] = useState<'COD' | 'UPI'>('COD')
  const [deliveryMethod, setDeliveryMethod] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY')
  const [scheduledSlot, setScheduledSlot] = useState<string>('INSTANT')

  // SafePay Modal state
  const [showSafePayModal, setShowSafePayModal] = useState(false)
  const [safePayUpiApp, setSafePayUpiApp] = useState<'PHONEPE' | 'GPAY' | 'PAYTM'>('PHONEPE')
  const [safePayMethod, setSafePayMethod] = useState<'INTENT' | 'QR' | 'UPI_ID'>('INTENT')
  const [upiId, setUpiId] = useState('')
  const [isVerifyingUpi, setIsVerifyingUpi] = useState(false)
  const [isUpiVerified, setIsUpiVerified] = useState(false)
  const [paymentSuccess, setPaymentSuccess] = useState(false)
  const [paymentError, setPaymentError] = useState<string | null>(null)
  const [isWaitingForIntentReturn, setIsWaitingForIntentReturn] = useState(false)

  const isB2BMode = useUIStore((s) => s.isB2BMode)
  const shopName = useUIStore((s) => s.shopName)
  const shopPhone = useUIStore((s) => s.shopPhone)

  // Calculations for checkout items
  const subtotal = getSubtotal()
  const mrpTotal = getMrpTotal()
  const savings = getSavings()
  const b2bDiscount = isB2BMode ? subtotal * 0.1 : 0
  const adjustedSubtotal = subtotal - b2bDiscount
  const discount = savings + b2bDiscount
  
  // Split items into Cafe and Grocery categories
  const cafeCartItems = items.filter((item) => isCafeProduct(item.product))
  const groceryCartItems = items.filter((item) => !isCafeProduct(item.product))

  // Grocery Calculations
  const grocerySubtotal = groceryCartItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const groceryMrpSubtotal = groceryCartItems.reduce((sum, item) => sum + item.product.mrp * item.quantity, 0)
  const grocerySavings = groceryMrpSubtotal - grocerySubtotal
  const groceryB2BDiscount = isB2BMode ? grocerySubtotal * 0.1 : 0
  const groceryAdjustedSubtotal = grocerySubtotal - groceryB2BDiscount
  const groceryDeliveryFee = (deliveryMethod === 'PICKUP' || isB2BMode) ? 0 : (groceryCartItems.length > 0 && groceryAdjustedSubtotal < FREE_DELIVERY_THRESHOLD ? DELIVERY_FEE : 0)
  const groceryTaxes = groceryAdjustedSubtotal * TAX_RATE
  const groceryTotal = groceryAdjustedSubtotal + groceryDeliveryFee + groceryTaxes

  // Cafe Calculations
  const cafeSubtotal = cafeCartItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const cafeMrpSubtotal = cafeCartItems.reduce((sum, item) => sum + item.product.mrp * item.quantity, 0)
  const cafeSavings = cafeMrpSubtotal - cafeSubtotal
  const cafeB2BDiscount = isB2BMode ? cafeSubtotal * 0.1 : 0
  const cafeAdjustedSubtotal = cafeSubtotal - cafeB2BDiscount
  const cafeDeliveryFee = (deliveryMethod === 'PICKUP' || isB2BMode) ? 0 : (cafeCartItems.length > 0 && cafeAdjustedSubtotal < 200 ? 25 : 0)
  const cafeTaxes = cafeAdjustedSubtotal * TAX_RATE
  const cafeTotal = cafeAdjustedSubtotal + cafeDeliveryFee + cafeTaxes

  const deliveryFee = groceryDeliveryFee + cafeDeliveryFee
  const taxes = adjustedSubtotal * TAX_RATE
  const grandTotal = adjustedSubtotal + deliveryFee + taxes

  // Fetch Saved Addresses
  useEffect(() => {
    async function loadAddresses() {
      try {
        const res = await fetch('/api/addresses')
        if (res.ok) {
          const data = await res.json()
          setAddresses(data)
          if (data.length > 0) {
            const def = data.find((a: Address) => a.isDefault)
            setSelectedAddressId(def ? def.id : data[0].id)
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

  // Trigger focus return listener when waiting for app redirection
  useEffect(() => {
    if (!isWaitingForIntentReturn) return

    const handleFocus = () => {
      // User returned from UPI app! Clear listeners and trigger payment verification
      setIsWaitingForIntentReturn(false)
      window.removeEventListener('focus', handleFocus)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
      
      handleSimulatedPayment('QR_SUCCESS')
    }

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        handleFocus()
      }
    }

    window.addEventListener('focus', handleFocus)
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      window.removeEventListener('focus', handleFocus)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [isWaitingForIntentReturn])

  // Create New Address
  const handleSaveAddress = async (e: React.FormEvent) => {
    e.preventDefault()
    const { label, houseNo, street, area, city, pincode, phone } = addressForm

    if (!label || !houseNo || !street || !area || !city || !pincode || !phone) {
      toast.error('Please fill in all address details, including a compulsory phone number')
      return
    }

    setIsSavingAddress(true)
    try {
      const res = await fetch('/api/addresses', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(addressForm),
      })

      if (res.ok) {
        const newAddress = await res.json()
        setAddresses([newAddress, ...addresses])
        setSelectedAddressId(newAddress.id)
        setShowNewAddressForm(false)
        setAddressForm({
          label: 'Home',
          houseNo: '',
          street: '',
          area: '',
          city: '',
          pincode: '',
          phone: '',
          isDefault: false,
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
    if (deliveryMethod === 'DELIVERY' && !selectedAddressId) {
      toast.error('Please select a delivery address')
      setStep(1)
      return
    }

    setIsPlacingOrder(true)
    try {
      // Fetch settings to check store status
      const settingsRes = await fetch('/api/settings')
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

      const finalAddressId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
      
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          addressId: finalAddressId,
          paymentMethod,
          items,
          deliveryMethod,
          isB2B: isB2BMode,
          scheduledSlot,
          shopName: isB2BMode ? shopName : 'FastKirana Dark Store',
          shopPhone: isB2BMode ? shopPhone : '+91 70544 70303',
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

  // Launch standard universal UPI deep link intent URI
  const handleUpiIntentPay = () => {
    const upiLink = `upi://pay?pa=fastkirana@upi&pn=FastKirana&am=${grandTotal.toFixed(2)}&cu=INR&tn=FastKirana%20Order`
    
    // Set waiting state and attempt redirect
    setIsWaitingForIntentReturn(true)
    setPaymentError(null)
    window.location.href = upiLink
  }

  // Verify UPI ID format and simulate lookup
  const handleVerifyUpiId = () => {
    if (!upiId || !upiId.includes('@')) {
      setPaymentError('Invalid UPI ID format. E.g. name@upi')
      toast.error('Please enter a valid UPI ID (e.g. name@upi)')
      return
    }
    
    setPaymentError(null)
    setIsVerifyingUpi(true)
    setTimeout(() => {
      setIsVerifyingUpi(false)
      setIsUpiVerified(true)
      toast.success('UPI ID verified successfully!')
    }, 1500)
  }

  // Simulate payment clearing and place the order
  const handleSimulatedPayment = async (type: 'QR_SUCCESS' | 'UPI_ID_SUCCESS') => {
    setIsPlacingOrder(true)
    setPaymentError(null)
    
    // Simulate payment clearing latency
    setTimeout(async () => {
      try {
        // Fetch settings to check store status
        const settingsRes = await fetch('/api/settings')
        const settings = await settingsRes.json()
        
        const hasGrocery = items.some((item) => !isCafeProduct(item.product))
        const hasCafe = items.some((item) => isCafeProduct(item.product))
        
        if (hasGrocery && settings.grocery_mart_open === 'false') {
          triggerHaptic('warning')
          setPaymentError('Grocery Mart is temporarily closed. Cannot complete checkout.')
          toast.error('Grocery Mart is temporarily closed. Please remove grocery items.')
          setIsPlacingOrder(false)
          return
        }
        
        if (hasCafe && settings.cafe_open === 'false') {
          triggerHaptic('warning')
          setPaymentError('FastKirana Cafe is temporarily closed. Cannot complete checkout.')
          toast.error('FastKirana Cafe is temporarily closed. Please remove cafe items.')
          setIsPlacingOrder(false)
          return
        }

        const finalAddressId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
        
        const res = await fetch('/api/orders', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            addressId: finalAddressId,
            paymentMethod: 'UPI',
            items,
            deliveryMethod,
            isB2B: isB2BMode,
            scheduledSlot,
            shopName: isB2BMode ? shopName : 'FastKirana Dark Store',
            shopPhone: isB2BMode ? shopPhone : '+91 70544 70303',
          }),
        })

        const data = await res.json()

        if (res.ok) {
          triggerHaptic('success')
          setPaymentSuccess(true)
          toast.success('Payment Received!')
          
          setTimeout(() => {
            clearCart()
            setShowSafePayModal(false)
            setPaymentSuccess(false)
            setUpiId('')
            setIsUpiVerified(false)
            router.push(`/order/${data.id}`)
          }, 2000)
        } else {
          setPaymentError(data.error || 'Failed to complete transaction')
          setIsPlacingOrder(false)
        }
      } catch (err) {
        setPaymentError('Connection error. Please try again.')
        setIsPlacingOrder(false)
      }
    }, 1500)
  }

  const handlePlaceOrderClick = () => {
    if (deliveryMethod === 'DELIVERY' && !selectedAddressId) {
      toast.error('Please select a delivery address')
      setStep(1)
      return
    }

    if (paymentMethod === 'UPI') {
      setShowSafePayModal(true)
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

  return (
    <div className="container mx-auto px-4 py-6 max-w-5xl space-y-8">
      {/* Step Progress Tracker */}
      <div className="flex items-center justify-center gap-2 md:gap-4 text-xs md:text-sm font-bold text-text-secondary border-b border-border pb-6">
        <button
          onClick={() => setStep(1)}
          className={cn(
            "flex items-center gap-2 pb-1 transition-colors",
            step >= 1 ? "text-primary border-b-2 border-primary" : ""
          )}
        >
          <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs">1</span>
          Fulfillment
        </button>
        <ChevronRight className="h-4 w-4 text-text-muted" />
        <button
          onClick={() => (deliveryMethod === 'PICKUP' || selectedAddressId) && setStep(2)}
          disabled={deliveryMethod === 'DELIVERY' && !selectedAddressId}
          className={cn(
            "flex items-center gap-2 pb-1 transition-colors",
            step >= 2 ? "text-primary border-b-2 border-primary" : ""
          )}
        >
          <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs">2</span>
          Review & Schedule
        </button>
        <ChevronRight className="h-4 w-4 text-text-muted" />
        <button
          onClick={() => (deliveryMethod === 'PICKUP' || selectedAddressId) && setStep(3)}
          disabled={deliveryMethod === 'DELIVERY' && !selectedAddressId}
          className={cn(
            "flex items-center gap-2 pb-1 transition-colors",
            step === 3 ? "text-primary border-b-2 border-primary" : ""
          )}
        >
          <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs">3</span>
          Payment
        </button>
      </div>

      {/* Mobile Top Bill Indicator */}
      <div className="block lg:hidden rounded-2xl bg-card border border-border p-4 shadow-sm animate-fade-in">
        <div className="flex justify-between items-center text-xs font-semibold">
          <div>
            <span className="text-[10px] uppercase font-bold text-text-secondary block">Grand Total</span>
            <span className="text-sm font-black text-primary">
              ₹{grandTotal.toFixed(0)} 
              {isB2BMode && <span className="text-[9px] text-primary ml-1 font-bold">(10% Wholesale Off)</span>}
            </span>
          </div>
          <div className="text-[10px] text-accent font-bold bg-accent/10 px-2.5 py-1 rounded">
            {deliveryMethod === 'PICKUP' ? '🏪 Store Pickup' : '🚚 Doorstep Delivery'}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        {/* Left: Step Panels */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* STEP 1: Address Selection / Fulfillment Option */}
          {step === 1 && (
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6 animate-fade-in">
              <h2 className="text-lg font-black text-text-primary flex items-center gap-2">
                <MapPin className="h-5 w-5 text-primary" />
                Choose Fulfillment Method
              </h2>

              {/* Fulfillment Option */}
              <div className="grid grid-cols-2 gap-4">
                <div
                  onClick={() => setDeliveryMethod('DELIVERY')}
                  className={cn(
                    "flex flex-col items-center justify-center p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20 text-center gap-2",
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
                        NH34, Ghatampur, Kanpur Nagar
                      </p>
                      <p className="text-xs text-text-secondary mt-1">
                        Pin: 209206 | Phone: <span className="font-semibold text-primary">+91 70544 70303</span>
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
                  <div className="space-y-4">
                    {addresses.map((addr) => (
                      <div
                        key={addr.id}
                        onClick={() => setSelectedAddressId(addr.id)}
                        className={cn(
                          "flex items-start gap-3 p-4 rounded-xl border-2 cursor-pointer transition-all duration-200 bg-muted/20",
                          selectedAddressId === addr.id
                            ? "border-primary bg-primary/5 shadow-sm"
                            : "border-border hover:border-primary/40"
                        )}
                      >
                        <input
                          type="radio"
                          checked={selectedAddressId === addr.id}
                          onChange={() => setSelectedAddressId(addr.id)}
                          className="mt-1"
                        />
                        <div className="flex-grow text-xs">
                          <div className="flex items-center gap-2 mb-1">
                            <span className="font-bold text-text-primary uppercase bg-muted/60 px-2 py-0.5 rounded">
                              {addr.label}
                            </span>
                            {addr.isDefault && (
                              <span className="text-[10px] text-accent font-semibold bg-accent/10 px-1.5 py-0.5 rounded">
                                Default
                              </span>
                            )}
                          </div>
                          <p className="text-text-secondary leading-relaxed mt-1 font-semibold">
                            House No {addr.houseNo}, {addr.street}, {addr.area}, {addr.city} - {addr.pincode}
                          </p>
                          {addr.phone && (
                            <p className="text-[10px] text-text-secondary mt-1 font-extrabold flex items-center gap-1">
                              <span>📞</span> Phone: {addr.phone}
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
                        className="w-full border-dashed border-2 hover:bg-muted/50 rounded-xl"
                      >
                        <Plus className="h-4 w-4 mr-2" />
                        Add New Address
                      </Button>
                    )}

                    {/* New Address Collapsible Form */}
                    {showNewAddressForm && (
                      <form onSubmit={handleSaveAddress} className="border border-border p-4 rounded-xl space-y-4 bg-muted/10 animate-slide-up">
                        <div className="flex justify-between items-center border-b border-border/40 pb-2">
                          <h3 className="font-bold text-sm">New Delivery Address</h3>
                          <Button
                            type="button"
                            onClick={handleDetectLocationForCheckout}
                            disabled={isDetectingLocation}
                            variant="ghost"
                            className="text-xs text-primary font-black hover:text-primary-dark hover:bg-primary/5 flex items-center gap-1.5 h-8 border border-primary/20 rounded-lg shrink-0 px-2.5"
                          >
                            {isDetectingLocation ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              <MapPin className="h-3.5 w-3.5 animate-pulse-gentle text-primary" />
                            )}
                            {isDetectingLocation ? 'Detecting...' : 'Auto-detect Location'}
                          </Button>
                        </div>
                        <div className="grid grid-cols-1 gap-4">
                          <div>
                            <Label htmlFor="phone" className="text-xs font-bold text-text-primary flex items-center gap-1">
                              Phone Number <span className="text-red-500 font-black text-[10px] bg-red-50 px-1.5 py-0.5 rounded">* COMPULSORY</span>
                            </Label>
                            <Input
                              id="phone"
                              type="tel"
                              placeholder="Enter contact phone number"
                              value={addressForm.phone}
                              onChange={(e) => setAddressForm({ ...addressForm, phone: e.target.value })}
                              className="mt-1 text-xs font-bold"
                            />
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                          <div>
                            <Label htmlFor="label">Address Label (e.g. Home, Work)</Label>
                            <Input
                              id="label"
                              value={addressForm.label}
                              onChange={(e) => setAddressForm({ ...addressForm, label: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                          <div>
                            <Label htmlFor="pincode">Pincode (6 digits)</Label>
                            <Input
                              id="pincode"
                              maxLength={6}
                              value={addressForm.pincode}
                              onChange={(e) => setAddressForm({ ...addressForm, pincode: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                          <div>
                            <Label htmlFor="houseNo">Flat / House / Apartment No</Label>
                            <Input
                              id="houseNo"
                              value={addressForm.houseNo}
                              onChange={(e) => setAddressForm({ ...addressForm, houseNo: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                          <div>
                            <Label htmlFor="street">Street / Road Name</Label>
                            <Input
                              id="street"
                              value={addressForm.street}
                              onChange={(e) => setAddressForm({ ...addressForm, street: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                          <div>
                            <Label htmlFor="area">Area / Sector / Locality</Label>
                            <Input
                              id="area"
                              value={addressForm.area}
                              onChange={(e) => setAddressForm({ ...addressForm, area: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                          <div>
                            <Label htmlFor="city">City</Label>
                            <Input
                              id="city"
                              value={addressForm.city}
                              onChange={(e) => setAddressForm({ ...addressForm, city: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                        </div>
                        <div className="flex gap-2 justify-end pt-2">
                          <Button
                            type="button"
                            variant="ghost"
                            onClick={() => setShowNewAddressForm(false)}
                            disabled={isSavingAddress}
                          >
                            Cancel
                          </Button>
                          <Button
                            type="submit"
                            className="bg-primary text-white"
                            disabled={isSavingAddress}
                          >
                            {isSavingAddress ? 'Saving...' : 'Save & Select'}
                          </Button>
                        </div>
                      </form>
                    )}
                  </div>
                )
              )}

              {/* Action Button */}
              {deliveryMethod === 'PICKUP' ? (
                <Button
                  onClick={() => setStep(2)}
                  className="w-full bg-accent text-white hover:bg-accent-dark h-11 rounded-xl"
                >
                  Confirm Pickup Details
                </Button>
              ) : (
                selectedAddressId && (
                  <Button
                    onClick={() => setStep(2)}
                    className="w-full bg-accent text-white hover:bg-accent-dark h-11 rounded-xl"
                  >
                    Deliver to this Address
                  </Button>
                )
              )}
            </div>
          )}

          {/* STEP 2: Order Review & Scheduling */}
          {step === 2 && (
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6 animate-fade-in">
              <h2 className="text-lg font-black text-text-primary flex items-center gap-2">
                <ShoppingBag className="h-5 w-5 text-primary" />
                Review Your Cart Items
              </h2>

              <div className="divide-y divide-border/40">
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


              {/* Delivery Scheduling */}
              <div className="border-t border-border/40 pt-5 space-y-3">
                <h3 className="text-sm font-bold text-text-primary flex items-center gap-2">
                  <span>📅</span> Choose Delivery Schedule
                </h3>
                
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setScheduledSlot('INSTANT')}
                    className={cn(
                      "flex flex-col items-center justify-center p-3 rounded-xl border-2 text-center gap-1 transition-all",
                      scheduledSlot === 'INSTANT'
                        ? "border-primary bg-primary/5 text-primary font-bold shadow-sm"
                        : "border-border hover:border-primary/20 text-text-secondary bg-muted/20"
                    )}
                  >
                    <span className="text-sm">⚡ Instant Delivery</span>
                    <span className="text-[10px] text-text-muted">Deliver within 10-15 mins</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      if (scheduledSlot === 'INSTANT') {
                        setScheduledSlot('07:00 AM - 09:00 AM') // default first slot
                      }
                    }}
                    className={cn(
                      "flex flex-col items-center justify-center p-3 rounded-xl border-2 text-center gap-1 transition-all",
                      scheduledSlot !== 'INSTANT'
                        ? "border-primary bg-primary/5 text-primary font-bold shadow-sm"
                        : "border-border hover:border-primary/20 text-text-secondary bg-muted/20"
                    )}
                  >
                    <span className="text-sm">🕒 Schedule for Later</span>
                    <span className="text-[10px] text-text-muted">Choose your preferred time slot</span>
                  </button>
                </div>

                {scheduledSlot !== 'INSTANT' && (
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mt-2 animate-slide-up">
                    {[
                      "07:00 AM - 09:00 AM",
                      "12:00 PM - 02:00 PM",
                      "06:00 PM - 08:00 PM"
                    ].map((slot) => (
                      <button
                        key={slot}
                        type="button"
                        onClick={() => setScheduledSlot(slot)}
                        className={cn(
                          "py-2 px-3 text-xs font-semibold rounded-lg border text-center transition-all",
                          scheduledSlot === slot
                            ? "bg-primary text-white border-primary shadow-sm"
                            : "bg-background border-border hover:border-primary/40 text-text-secondary"
                        )}
                      >
                        {slot}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              <div className="flex gap-4 border-t border-border/40 pt-5">
                <Button
                  variant="outline"
                  onClick={() => setStep(1)}
                  className="w-1/3 rounded-xl"
                >
                  Back
                </Button>
                <Button
                  onClick={() => setStep(3)}
                  className="w-2/3 bg-accent text-white hover:bg-accent-dark rounded-xl"
                >
                  Proceed to Payment
                </Button>
              </div>
            </div>
          )}

          {/* STEP 3: Payment Selection */}
          {step === 3 && (
            <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6 animate-fade-in">
              <h2 className="text-lg font-black text-text-primary flex items-center gap-2">
                <CreditCard className="h-5 w-5 text-primary" />
                Choose Payment Method
              </h2>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Cash on Delivery */}
                <div
                  onClick={() => setPaymentMethod('COD')}
                  className={cn(
                    "flex items-center gap-3 p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20",
                    paymentMethod === 'COD' ? "border-primary bg-primary/5" : "border-border hover:border-primary/40"
                  )}
                >
                  <input
                    type="radio"
                    checked={paymentMethod === 'COD'}
                    onChange={() => setPaymentMethod('COD')}
                    className="cursor-pointer"
                  />
                  <div>
                    <h4 className="text-sm font-bold text-text-primary">Cash on Delivery (COD)</h4>
                    <p className="text-[10px] text-text-secondary mt-0.5">Pay in cash or UPI at the door</p>
                  </div>
                </div>

                {/* Simulated UPI */}
                <div
                  onClick={() => setPaymentMethod('UPI')}
                  className={cn(
                    "flex items-center gap-3 p-4 rounded-xl border-2 cursor-pointer transition-all bg-muted/20",
                    paymentMethod === 'UPI' ? "border-primary bg-primary/5" : "border-border hover:border-primary/40"
                  )}
                >
                  <input
                    type="radio"
                    checked={paymentMethod === 'UPI'}
                    onChange={() => setPaymentMethod('UPI')}
                    className="cursor-pointer"
                  />
                  <div>
                    <h4 className="text-sm font-bold text-text-primary">PhonePe / Google Pay / Paytm (UPI)</h4>
                    <p className="text-[10px] text-text-secondary mt-0.5">Simulate instant mobile payment</p>
                  </div>
                </div>
              </div>

              {/* Secure Transaction notice */}
              <div className="flex items-center gap-2 border border-accent/20 bg-accent/5 p-3 rounded-xl text-xs font-semibold text-accent">
                <ShieldCheck className="h-5 w-5" />
                Your transaction is simulated safely for local demonstration.
              </div>

              <div className="flex gap-4">
                <Button
                  variant="outline"
                  onClick={() => setStep(2)}
                  className="w-1/3 rounded-xl"
                  disabled={isPlacingOrder}
                >
                  Back
                </Button>
                <Button
                  onClick={handlePlaceOrderClick}
                  className="w-2/3 bg-accent text-white hover:bg-accent-dark rounded-xl h-11"
                  disabled={isPlacingOrder}
                >
                  {isPlacingOrder ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                      Placing Order...
                    </>
                  ) : (
                    `Place Order (₹${grandTotal.toFixed(0)})`
                  )}
                </Button>
              </div>
            </div>
          )}

          {/* Simulated UPI Payment Gateway Modal */}
          {showSafePayModal && (
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-md p-4">
              <style>{`
                @keyframes scan {
                  0% { top: 0%; }
                  50% { top: 100%; }
                  100% { top: 0%; }
                }
                .scanner-line {
                  animation: scan 2s linear infinite;
                }
              `}</style>
              <div className="relative bg-white dark:bg-zinc-950 w-full max-w-md rounded-3xl shadow-2xl border border-zinc-200/50 dark:border-zinc-800/50 overflow-hidden">
                {/* Brand Top Bar */}
                <div className={cn(
                  "px-6 py-4 text-white transition-all duration-300 flex items-center justify-between",
                  safePayUpiApp === 'PHONEPE' ? "bg-[#5f259f]" :
                  safePayUpiApp === 'GPAY' ? "bg-[#1a73e8]" : "bg-[#00b9f5]"
                )}>
                  <div className="flex items-center gap-2">
                    <span className="text-xl">🛡️</span>
                    <div>
                      <h3 className="font-extrabold text-sm tracking-wide">FastKirana SafePay</h3>
                      <p className="text-[10px] opacity-80 font-medium">100% Secure Simulated UPI Gateway</p>
                    </div>
                  </div>
                  <button 
                    onClick={() => {
                      setShowSafePayModal(false)
                      setPaymentSuccess(false)
                      setPaymentError(null)
                    }}
                    className="text-white/80 hover:text-white text-xs bg-white/10 hover:bg-white/20 px-2.5 py-1 rounded-full font-bold transition-all cursor-pointer"
                  >
                    Cancel
                  </button>
                </div>

                {/* Payment details strip */}
                <div className="bg-zinc-50 dark:bg-zinc-900 border-b border-zinc-100 dark:border-zinc-800/40 px-6 py-3.5 flex justify-between items-center text-xs font-semibold">
                  <div className="text-text-secondary">Amount to Pay</div>
                  <div className="text-sm font-black text-primary">₹{grandTotal.toFixed(0)}</div>
                </div>

                {/* Main Container */}
                {!paymentSuccess ? (
                  <div className="p-6 space-y-6">
                    {/* UPI App Tabs selector */}
                    <div className="space-y-2">
                      <label className="text-[10px] font-bold text-text-secondary uppercase tracking-wider block">Select UPI App</label>
                      <div className="grid grid-cols-3 gap-2">
                        {[
                          { id: 'PHONEPE' as const, label: 'PhonePe', icon: '🟣' },
                          { id: 'GPAY' as const, label: 'GPay', icon: '🔵' },
                          { id: 'PAYTM' as const, label: 'Paytm UPI', icon: '💠' },
                        ].map((app) => (
                          <button
                            key={app.id}
                            type="button"
                            onClick={() => {
                              setSafePayUpiApp(app.id)
                              setPaymentError(null)
                            }}
                            className={cn(
                              "flex flex-col items-center justify-center p-3 rounded-2xl border-2 transition-all text-xs font-black cursor-pointer",
                              safePayUpiApp === app.id
                                ? (app.id === 'PHONEPE' ? 'border-[#5f259f] text-[#5f259f] bg-[#5f259f]/5' : app.id === 'GPAY' ? 'border-[#1a73e8] text-[#1a73e8] bg-[#1a73e8]/5' : 'border-[#00b9f5] text-[#00b9f5] bg-[#00b9f5]/5')
                                : "border-zinc-100 dark:border-zinc-800 hover:border-zinc-200 hover:bg-zinc-50 text-text-secondary bg-white/5"
                            )}
                          >
                            <span className="text-base mb-1">{app.icon}</span>
                            {app.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Payment Method Selector (Pay via App vs QR vs UPI ID) */}
                    <div className="flex border border-zinc-100 dark:border-zinc-800 rounded-xl overflow-hidden p-1 bg-zinc-50/50 dark:bg-zinc-900/40">
                      <button
                        type="button"
                        onClick={() => {
                          setSafePayMethod('INTENT')
                          setPaymentError(null)
                        }}
                        className={cn(
                          "flex-1 py-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1 cursor-pointer",
                          safePayMethod === 'INTENT' ? "bg-white dark:bg-zinc-800 text-text-primary shadow-sm" : "text-text-secondary hover:text-text-primary"
                        )}
                      >
                        <Smartphone className="h-3.5 w-3.5" />
                        Pay via App
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setSafePayMethod('QR')
                          setPaymentError(null)
                        }}
                        className={cn(
                          "flex-1 py-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1 cursor-pointer",
                          safePayMethod === 'QR' ? "bg-white dark:bg-zinc-800 text-text-primary shadow-sm" : "text-text-secondary hover:text-text-primary"
                        )}
                      >
                        <QrCode className="h-3.5 w-3.5" />
                        Scan QR
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setSafePayMethod('UPI_ID')
                          setPaymentError(null)
                        }}
                        className={cn(
                          "flex-1 py-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1 cursor-pointer",
                          safePayMethod === 'UPI_ID' ? "bg-white dark:bg-zinc-800 text-text-primary shadow-sm" : "text-text-secondary hover:text-text-primary"
                        )}
                      >
                        <span className="text-[10px]">👤</span>
                        UPI ID
                      </button>
                    </div>

                    {/* Tab Contents */}
                    {safePayMethod === 'INTENT' ? (
                      /* Pay via UPI App Redirect View */
                      <div className="flex flex-col items-center justify-center py-4 space-y-4 text-center">
                        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/5 text-primary text-2xl animate-pulse-gentle">
                          📱
                        </div>
                        
                        {!isWaitingForIntentReturn ? (
                          <>
                            <div className="space-y-1">
                              <h4 className="text-xs font-bold text-text-primary">Pay via UPI App</h4>
                              <p className="text-[10px] text-text-secondary max-w-[265px] leading-normal mx-auto font-medium">
                                Click below to launch your default UPI app (PhonePe, GPay, Paytm) and complete payment of <strong>₹{grandTotal.toFixed(0)}</strong>.
                              </p>
                            </div>
                            
                            <Button
                              onClick={handleUpiIntentPay}
                              className="w-full bg-[#2e7d32] hover:bg-[#1b5e20] text-white font-extrabold rounded-2xl h-11 shadow-md hover:scale-[1.02] active:scale-98 transition-all cursor-pointer flex items-center justify-center gap-1.5"
                            >
                              ⚡ Pay via UPI App
                            </Button>
                          </>
                        ) : (
                          <>
                            <div className="rounded-xl border border-blue-100 bg-blue-50/50 dark:border-blue-900/30 dark:bg-blue-950/20 p-4 text-center text-xs font-bold text-blue-600 dark:text-blue-400 flex flex-col items-center gap-2 animate-slide-up w-full">
                              <div className="flex items-center gap-2">
                                <Loader2 className="h-4 w-4 animate-spin text-blue-600" />
                                <span>Waiting for payment in UPI app...</span>
                              </div>
                              <p className="text-[10px] font-medium text-blue-500 leading-relaxed max-w-[240px]">
                                Once payment is completed in your app, return to this tab. We will automatically detect your return and verify the payment.
                              </p>
                            </div>

                            <Button
                              onClick={() => handleSimulatedPayment('QR_SUCCESS')}
                              className="w-full bg-[#2e7d32] hover:bg-[#1b5e20] text-white font-extrabold rounded-2xl h-11 shadow-md hover:scale-[1.02] active:scale-98 transition-all cursor-pointer"
                              disabled={isPlacingOrder}
                            >
                              {isPlacingOrder ? (
                                <Loader2 className="h-4 w-4 animate-spin mx-auto text-white" />
                              ) : (
                                "✓ Confirm Payment Manually"
                              )}
                            </Button>
                          </>
                        )}
                      </div>
                    ) : safePayMethod === 'QR' ? (
                      /* QR Code Simulator View */
                      <div className="flex flex-col items-center justify-center py-4 space-y-4">
                        <div className="relative border-4 border-zinc-100 dark:border-zinc-800 p-4 rounded-3xl bg-white overflow-hidden shadow-inner flex items-center justify-center w-48 h-48">
                          {/* SVG Mock QR Code */}
                          <svg className="w-full h-full text-zinc-800" viewBox="0 0 100 100">
                            <rect x="0" y="0" width="25" height="25" fill="currentColor"/>
                            <rect x="5" y="5" width="15" height="15" fill="white"/>
                            <rect x="9" y="9" width="7" height="7" fill="currentColor"/>
                            
                            <rect x="75" y="0" width="25" height="25" fill="currentColor"/>
                            <rect x="75" y="5" width="15" height="15" fill="white"/>
                            <rect x="79" y="9" width="7" height="7" fill="currentColor"/>

                            <rect x="0" y="75" width="25" height="25" fill="currentColor"/>
                            <rect x="5" y="75" width="15" height="15" fill="white"/>
                            <rect x="9" y="79" width="7" height="7" fill="currentColor"/>

                            <rect x="35" y="10" width="10" height="5" fill="currentColor"/>
                            <rect x="50" y="20" width="15" height="10" fill="currentColor"/>
                            <rect x="40" y="40" width="20" height="20" fill="currentColor"/>
                            <rect x="70" y="45" width="10" height="15" fill="currentColor"/>
                            <rect x="20" y="55" width="15" height="5" fill="currentColor"/>
                            <rect x="10" y="40" width="5" height="10" fill="currentColor"/>
                            <rect x="80" y="80" width="15" height="15" fill="currentColor"/>
                            <rect x="45" y="80" width="15" height="10" fill="currentColor"/>
                            <rect x="80" y="65" width="5" height="10" fill="currentColor"/>
                          </svg>
                          {/* Scanner laser line animation */}
                          <div className="absolute left-0 right-0 h-1 bg-primary/80 dark:bg-primary shadow-[0_0_8px_rgba(46,125,50,0.8)] scanner-line pointer-events-none" />
                        </div>
                        <p className="text-[10px] text-text-muted text-center max-w-xs font-semibold leading-relaxed">
                          Scan this QR code using your {safePayUpiApp === 'PHONEPE' ? 'PhonePe' : safePayUpiApp === 'GPAY' ? 'Google Pay' : 'Paytm'} app to pay.
                        </p>
                        
                        <Button
                          onClick={() => handleSimulatedPayment('QR_SUCCESS')}
                          className="w-full bg-[#2e7d32] hover:bg-[#1b5e20] text-white font-extrabold rounded-2xl h-11 shadow-md hover:scale-[1.02] active:scale-98 transition-all cursor-pointer"
                          disabled={isPlacingOrder}
                        >
                          {isPlacingOrder ? (
                            <>
                              <Loader2 className="h-4 w-4 animate-spin mr-2" />
                              Processing Payment...
                            </>
                          ) : (
                            "✓ Simulate Scan Success"
                          )}
                        </Button>
                      </div>
                    ) : (
                      /* UPI ID View */
                      <div className="space-y-4 py-2">
                        <div className="space-y-1">
                          <Label htmlFor="upi-id-input" className="text-xs font-bold text-text-primary">
                            Enter UPI ID / VPA
                          </Label>
                          <div className="relative">
                            <Input
                              id="upi-id-input"
                              placeholder="e.g. name@upi or cellno@ybl"
                              value={upiId}
                              onChange={(e) => {
                                setUpiId(e.target.value)
                                setIsUpiVerified(false)
                                setPaymentError(null)
                              }}
                              className="text-xs font-semibold pr-20"
                              disabled={isVerifyingUpi || isPlacingOrder}
                            />
                            <button
                              type="button"
                              onClick={handleVerifyUpiId}
                              disabled={!upiId || isVerifyingUpi || isUpiVerified || isPlacingOrder}
                              className={cn(
                                "absolute right-2 top-1/2 -translate-y-1/2 text-[10px] font-black uppercase px-2.5 py-1.5 rounded-lg transition-all cursor-pointer",
                                isUpiVerified 
                                  ? "bg-green-50 text-green-600 border border-green-200"
                                  : "bg-primary/10 hover:bg-primary text-primary hover:text-white"
                              )}
                            >
                              {isVerifyingUpi ? (
                                <Loader2 className="h-3 w-3 animate-spin" />
                              ) : isUpiVerified ? (
                                "Verified ✓"
                              ) : (
                                "Verify"
                              )}
                            </button>
                          </div>
                        </div>

                        {isUpiVerified && (
                          <div className="rounded-xl border border-blue-100 bg-blue-50/50 dark:border-blue-900/30 dark:bg-blue-950/20 p-3.5 text-center text-xs font-bold text-blue-600 dark:text-blue-400 flex flex-col items-center gap-1.5">
                            <div className="flex items-center gap-1.5">
                              <Loader2 className="h-3.5 w-3.5 animate-spin text-blue-600" />
                              <span>Payment request sent to {upiId}</span>
                            </div>
                            <span className="text-[10px] font-medium text-blue-500">Please approve the payment request in your UPI app.</span>
                          </div>
                        )}

                        {paymentError && (
                          <div className="rounded-xl border border-red-100 bg-red-50 text-xs font-bold text-red-600 p-3 flex items-center gap-2">
                            <span>❌</span>
                            <span>{paymentError}</span>
                          </div>
                        )}

                        <Button
                          onClick={() => handleSimulatedPayment('UPI_ID_SUCCESS')}
                          className="w-full bg-[#2e7d32] hover:bg-[#1b5e20] text-white font-extrabold rounded-2xl h-11 shadow-md cursor-pointer"
                          disabled={!isUpiVerified || isPlacingOrder}
                        >
                          {isPlacingOrder ? (
                            <>
                              <Loader2 className="h-4 w-4 animate-spin mr-2" />
                              Completing Order...
                            </>
                          ) : (
                            "Approve & Pay ₹" + grandTotal.toFixed(0)
                          )}
                        </Button>
                      </div>
                    )}

                    {/* Secure gateway trust footer */}
                    <div className="flex justify-center items-center gap-1.5 text-[10px] text-text-muted font-semibold pt-2 border-t border-zinc-100 dark:border-zinc-800/40">
                      <span>🔒</span> Secured by FastKirana SafePay Gateway
                    </div>
                  </div>
                ) : (
                  /* Success Screen */
                  <div className="p-8 flex flex-col items-center justify-center text-center space-y-5">
                    <div className="w-16 h-16 bg-[#2e7d32] text-white rounded-full flex items-center justify-center text-3xl font-black shadow-lg border-4 border-green-100">
                      ✓
                    </div>
                    <div>
                      <h3 className="text-base font-black text-text-primary">Payment Successful!</h3>
                      <p className="text-xs text-[#2e7d32] font-black mt-1">₹{grandTotal.toFixed(0)} debited successfully</p>
                      <p className="text-[10px] text-text-muted mt-3 max-w-[240px] leading-relaxed mx-auto font-medium">
                        Generating your order and linking with Rider dispatch queue...
                      </p>
                    </div>
                    <div className="w-full max-w-[200px] py-1">
                      <Loader2 className="h-5 w-5 animate-spin mx-auto text-primary" />
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Right Column: Mini Bill Summary (Persistent) */}
        <div className="bg-white/80 backdrop-blur-md border border-white/60 p-5 rounded-2xl shadow-[0_8px_30px_rgb(0,0,0,0.02)] h-fit space-y-5">
          {isB2BMode && (
            <div className="rounded-xl bg-primary/10 border border-primary/20 p-3 text-center text-xs font-black text-primary animate-pulse-gentle flex flex-col gap-1">
              <span>🏢 B2B WHOLESALE ACTIVE</span>
              <span className="text-[10px] font-semibold text-primary/80">Flat 10% Wholesale discount applied</span>
            </div>
          )}
          
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
                  <span>GST / Taxes (5%)</span>
                  <span>₹{groceryTaxes.toFixed(0)}</span>
                </div>
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
              <div className="flex items-center justify-between text-xs font-black text-rose-600 bg-rose-50 px-2 py-1 rounded">
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
                  <span>GST / Taxes (5%)</span>
                  <span>₹{cafeTaxes.toFixed(0)}</span>
                </div>
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
    </div>
  )
}
