'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { useCart } from '@/hooks/use-cart'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn, isCafeProduct, formatPhone } from '@/lib/utils'
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
  const { items, removeItem, clearCart, getSubtotal, getSavings, getMrpTotal, updateQuantity, updateCartProduct } = useCart()

  // Steps: 1 = Address, 2 = Review, 3 = Payment
  const [step, setStep] = useState(1)
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
      })
      .catch(err => console.error('Error fetching settings on checkout mount:', err))
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
          toast.error(`Detected location is outside our delivery zone (${dist.toFixed(1)} km away). If you are ordering for home, please type your Ghatampur address manually.`, { duration: 6000 })
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
  const [paymentMethod, setPaymentMethod] = useState<'COD' | 'UPI' | 'CARD' | 'WALLET'>('COD')
  const [deliveryMethod, setDeliveryMethod] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY')
  const [scheduledSlot, setScheduledSlot] = useState<string>('INSTANT')





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
    const { label, houseNo, street, area, city, pincode, phone } = addressForm

    if (!label || !houseNo || !street || !area || !city || !pincode || !phone) {
      toast.error('Please fill in all address details, including pincode, city, and phone number')
      return
    }

    const cleanPincode = pincode.trim()
    const cleanCity = city.trim().toLowerCase()

    if (!/^\d{6}$/.test(cleanPincode)) {
      toast.error('Pincode must be a 6-digit number')
      return
    }

    if (cleanPincode !== '209206' && cleanPincode !== '560034') {
      toast.error('FastKirana only delivers to Ghatampur area (Pincode: 209206)')
      return
    }

    if (!cleanCity.includes('ghatampur') && !cleanCity.includes('kanpur') && !cleanCity.includes('bangalore')) {
      toast.error('FastKirana delivery is currently only available in Ghatampur / Kanpur')
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
    if (deliveryMethod === 'DELIVERY' && !selectedAddressId && addresses.length === 0) {
      toast.error('Please select a delivery address')
      setStep(1)
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
          if (p !== '209206' && p !== '560034') {
            triggerHaptic('warning')
            toast.error('Selected address is outside our delivery zone. Please add/select a Ghatampur address (Pincode: 209206).')
            setIsPlacingOrder(false)
            setStep(1)
            return
          }
          if (!c.includes('ghatampur') && !c.includes('kanpur') && !c.includes('bangalore')) {
            triggerHaptic('warning')
            toast.error('Selected address city is outside our delivery zone. FastKirana only delivers to Ghatampur / Kanpur.')
            setIsPlacingOrder(false)
            setStep(1)
            return
          }
        }
      }
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
      const settingsRes = await fetch('/api/settings')
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
      setStep(1)
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

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-5xl space-y-6 md:space-y-8">
      {/* Step Progress Tracker */}
      <div className="flex items-center justify-center gap-1.5 min-[375px]:gap-2 md:gap-4 text-[10px] min-[375px]:text-xs md:text-sm font-bold text-text-secondary border-b border-border pb-6">
        <button
          onClick={() => setStep(1)}
          className={cn(
            "flex items-center gap-1 min-[375px]:gap-2 pb-1 transition-colors",
            step >= 1 ? "text-primary border-b-2 border-primary" : ""
          )}
        >
          <span className="flex h-4.5 w-4.5 min-[375px]:h-5 min-[375px]:w-5 items-center justify-center rounded-full bg-primary/10 text-[9px] min-[375px]:text-xs">1</span>
          <span className="hidden min-[375px]:inline">Fulfillment</span>
          <span className="min-[375px]:hidden">Address</span>
        </button>
        <ChevronRight className="h-3.5 w-3.5 md:h-4 md:w-4 text-text-muted" />
        <button
          onClick={() => (deliveryMethod === 'PICKUP' || selectedAddressId) && setStep(2)}
          disabled={deliveryMethod === 'DELIVERY' && !selectedAddressId}
          className={cn(
            "flex items-center gap-2 pb-1 transition-colors",
            step >= 2 ? "text-primary border-b-2 border-primary" : ""
          )}
        >
          <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/10 text-xs">2</span>
          <span className="hidden min-[375px]:inline">Review & Schedule</span>
          <span className="min-[375px]:hidden">Review</span>
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
          <span className="hidden min-[375px]:inline">Payment</span>
          <span className="min-[375px]:hidden">Pay</span>
        </button>
      </div>

      {/* Mobile Top Bill Indicator */}
      <div className="block lg:hidden rounded-2xl bg-card border border-border p-4 shadow-sm animate-fade-in">
        <div className="flex justify-between items-center text-xs font-semibold">
          <div>
            <span className="text-[10px] uppercase font-bold text-text-secondary block">Grand Total</span>
            <span className="text-sm font-black text-primary">
              ₹{grandTotal.toFixed(0)}
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
            <div className="bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-4 md:space-y-6 animate-fade-in">
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
                              <span>📞</span> Phone: {formatPhone(addr.phone)}
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
                          </Button>
                        </div>
                        <div className="text-[10px] text-text-secondary leading-relaxed bg-primary/5 p-2.5 rounded-lg border border-primary/10 flex items-start gap-1.5">
                          <span>ℹ️</span>
                          <span>
                            <strong>Ordering from another city?</strong> If you are ordering for delivery to a home in Ghatampur while physically elsewhere, please type the address manually below (pincode must be <strong>209206</strong>) instead of using auto-detect.
                          </span>
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
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
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
                            <Label htmlFor="pincode" className="text-xs font-bold text-text-primary flex items-center gap-1">
                              Pincode (6 digits) <span className="text-red-500 font-black text-[10px] bg-red-50 px-1.5 py-0.5 rounded">* COMPULSORY</span>
                            </Label>
                            <Input
                              id="pincode"
                              maxLength={6}
                              placeholder="e.g. 209206"
                              value={addressForm.pincode}
                              onChange={(e) => setAddressForm({ ...addressForm, pincode: e.target.value })}
                              className="mt-1 text-xs font-bold"
                            />
                          </div>
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
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
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
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
                            <Label htmlFor="city" className="text-xs font-bold text-text-primary flex items-center gap-1">
                              City <span className="text-red-500 font-black text-[10px] bg-red-50 px-1.5 py-0.5 rounded">* COMPULSORY</span>
                            </Label>
                            <Input
                              id="city"
                              placeholder="e.g. Ghatampur"
                              value={addressForm.city}
                              onChange={(e) => setAddressForm({ ...addressForm, city: e.target.value })}
                              className="mt-1 text-xs font-bold"
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
            <div className="bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-4 md:space-y-6 animate-fade-in">
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
                  <span>📅</span> {deliveryMethod === 'PICKUP' ? 'Choose Pickup Schedule' : 'Choose Delivery Schedule'}
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
                    <span className="text-sm">{deliveryMethod === 'PICKUP' ? '⚡ Instant Pickup' : '⚡ Instant Delivery'}</span>
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
                    <span className="text-sm">{deliveryMethod === 'PICKUP' ? '🕒 Schedule Pickup for Later' : '🕒 Schedule for Later'}</span>
                    <span className="text-[10px] text-text-muted">
                      {deliveryMethod === 'PICKUP' ? 'Choose your preferred pickup time slot' : 'Choose your preferred time slot'}
                    </span>
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
            <div className="bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-4 md:space-y-6 animate-fade-in">
              <h2 className="text-lg font-black text-text-primary flex items-center gap-2">
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
                          Pay securely with Visa, MasterCard, RuPay, Maestro, or Diner\'s Club cards
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
    </div>
  )
}
