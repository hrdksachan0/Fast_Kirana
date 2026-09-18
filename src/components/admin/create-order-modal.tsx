'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import {
  Search,
  X,
  User,
  MapPin,
  Plus,
  Minus,
  Trash2,
  Loader2,
  Check,
  ShoppingBag,
  Percent,
  Truck,
  Store,
  Receipt,
  CreditCard,
  Sparkles,
  Phone,
  Mail,
  ArrowRight,
  ShieldCheck,
  Tag,
  AlertCircle,
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { toast } from 'sonner'
import { formatPrice, formatDisplayEmail, formatPhone, cn } from '@/lib/utils'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
import { STORE_PINCODE, SERVICE_AREA_NAME } from '@/lib/store-config'
import { getDeliveryRules } from '@/lib/distance'
import { useUIStore } from '@/stores/ui-store'

interface CreateOrderModalProps {
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

interface CustomerUser {
  id: string
  name: string | null
  email: string
  phone: string | null
}

interface Address {
  id: string
  label: string
  houseNo: string
  street: string
  area: string
  city: string
  pincode: string
  phone: string
}

interface Product {
  id: string
  name: string
  slug: string
  price: number
  mrp: number
  stock: number
  isAvailable: boolean
  tags: string[]
  variants: any
  imageUrl?: string | null
  category?: {
    id: string
    name: string
    slug: string
  }
}

interface SelectedItem {
  id: string
  product: {
    id: string
    name: string
    slug: string
    price: number
    mrp: number
    stock: number
    imageUrl: string | null
    variants: any[]
    category?: {
      id: string
      name: string
      slug: string
    }
    categorySlug: string
  }
  quantity: number
  variantName: string | null
  notes?: string
}

export function CreateOrderModal({ isOpen, onClose, onSuccess }: CreateOrderModalProps) {
  // Store settings
  const settings = useUIStore((s) => s.settings) || {}

  // Customer selection states
  const [customerSearch, setCustomerSearch] = useState('')
  const [customersList, setCustomersList] = useState<CustomerUser[]>([])
  const [isSearchingCustomers, setIsSearchingCustomers] = useState(false)
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerUser | null>(null)

  // Address selection states
  const [addresses, setAddresses] = useState<Address[]>([])
  const [selectedAddressId, setSelectedAddressId] = useState('')
  const [deliveryMethod, setDeliveryMethod] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY')
  const [isManualAddress, setIsManualAddress] = useState(false)
  const [manualHouseNo, setManualHouseNo] = useState('')
  const [manualStreet, setManualStreet] = useState('')
  const [manualArea, setManualArea] = useState('')
  const [manualPincode, setManualPincode] = useState(STORE_PINCODE)
  const [manualPhone, setManualPhone] = useState('')
  const [manualCity, setManualCity] = useState(SERVICE_AREA_NAME)

  // Product selection states
  const [productSearch, setProductSearch] = useState('')
  const [productsList, setProductsList] = useState<Product[]>([])
  const [isSearchingProducts, setIsSearchingProducts] = useState(false)
  const [selectedItems, setSelectedItems] = useState<SelectedItem[]>([])

  // Variant selector state
  const [variantProduct, setVariantProduct] = useState<Product | null>(null)

  // Order configuration states
  const [noGst, setNoGst] = useState(false)
  const [activeCartItems, setActiveCartItems] = useState<any[]>([])
  const [isLoadingActiveCart, setIsLoadingActiveCart] = useState(false)
  const [couponCode, setCouponCode] = useState('')
  const [isApplyingCoupon, setIsApplyingCoupon] = useState(false)
  const [appliedCoupon, setAppliedCoupon] = useState<any>(null)

  // Order submission states
  const [paymentMethod, setPaymentMethod] = useState<'COD' | 'UPI' | 'CARD'>('COD')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)

  // References for debouncing search
  const customerDebounce = useRef<NodeJS.Timeout | null>(null)
  const productDebounce = useRef<NodeJS.Timeout | null>(null)

  // Search customers debounced
  useEffect(() => {
    if (customerSearch.trim().length < 2) {
      setCustomersList([])
      return
    }

    if (customerDebounce.current) clearTimeout(customerDebounce.current)

    setIsSearchingCustomers(true)
    customerDebounce.current = setTimeout(async () => {
      try {
        const res = await fetch(`/api/admin/users?search=${encodeURIComponent(customerSearch)}&limit=8`)
        if (res.ok) {
          const data = await res.json()
          setCustomersList(data.users || [])
        }
      } catch (err) {
        console.error('Failed to search customers:', err)
      } finally {
        setIsSearchingCustomers(false)
      }
    }, 300)

    return () => {
      if (customerDebounce.current) clearTimeout(customerDebounce.current)
    }
  }, [customerSearch])

  // Search products debounced
  useEffect(() => {
    if (productSearch.trim().length < 2) {
      setProductsList([])
      return
    }

    if (productDebounce.current) clearTimeout(productDebounce.current)

    setIsSearchingProducts(true)
    productDebounce.current = setTimeout(async () => {
      try {
        const res = await fetch(`/api/products?search=${encodeURIComponent(productSearch)}&limit=8`)
        if (res.ok) {
          const data = await res.json()
          setProductsList(data.products || [])
        }
      } catch (err) {
        console.error('Failed to search products:', err)
      } finally {
        setIsSearchingProducts(false)
      }
    }, 300)

    return () => {
      if (productDebounce.current) clearTimeout(productDebounce.current)
    }
  }, [productSearch])

  // Fetch addresses and active cart once customer is selected
  useEffect(() => {
    if (!selectedCustomer) {
      setAddresses([])
      setSelectedAddressId('')
      setActiveCartItems([])
      setIsManualAddress(false)
      setManualHouseNo('')
      setManualStreet('')
      setManualArea('')
      setManualPincode(STORE_PINCODE)
      setManualPhone('')
      return
    }

    setManualPhone(selectedCustomer.phone || '')
    setManualHouseNo('')
    setManualStreet('')
    setManualArea('')
    setManualPincode(STORE_PINCODE)

    const fetchAddressesAndCart = async () => {
      try {
        const res = await fetch(`/api/admin/users/${selectedCustomer.id}/addresses`)
        if (res.ok) {
          const data = await res.json()
          setAddresses(data || [])
          if (data && data.length > 0) {
            setSelectedAddressId(data[0].id)
            setIsManualAddress(false)
          } else {
            setIsManualAddress(true)
          }
        }
      } catch (err) {
        console.error('Failed to fetch addresses:', err)
      }

      try {
        setIsLoadingActiveCart(true)
        const cartRes = await fetch(`/api/admin/users/${selectedCustomer.id}/cart`)
        if (cartRes.ok) {
          const cartData = await cartRes.json()
          if (cartData && cartData.items && cartData.items.length > 0) {
            setActiveCartItems(cartData.items)
          } else {
            setActiveCartItems([])
          }
        }
      } catch (err) {
        console.error('Failed to fetch customer cart:', err)
      } finally {
        setIsLoadingActiveCart(false)
      }
    }

    fetchAddressesAndCart()
  }, [selectedCustomer])

  // Recalculate coupon if items change
  useEffect(() => {
    if (appliedCoupon) {
      handleApplyCoupon(true)
    }
  }, [selectedItems])

  const handleSelectCustomer = (user: CustomerUser) => {
    setSelectedCustomer(user)
    setCustomerSearch('')
    setCustomersList([])
  }

  const handleSelectProduct = (product: Product) => {
    let variantsList: any[] = []
    if (Array.isArray(product.variants)) {
      variantsList = product.variants
    } else if (typeof product.variants === 'string') {
      try {
        const parsed = JSON.parse(product.variants)
        if (Array.isArray(parsed)) variantsList = parsed
      } catch {}
    }

    if (variantsList.length > 0) {
      setVariantProduct({ ...product, variants: variantsList })
    } else {
      addProductToCart(product, null)
    }
    setProductSearch('')
    setProductsList([])
  }

  const addProductToCart = (product: Product, variantName: string | null) => {
    const cartId = variantName ? `${product.id}_${variantName}` : product.id

    let variantsList: any[] = []
    if (Array.isArray(product.variants)) {
      variantsList = product.variants
    } else if (typeof product.variants === 'string') {
      try {
        const parsed = JSON.parse(product.variants)
        if (Array.isArray(parsed)) variantsList = parsed
      } catch {}
    }

    let price = product.price
    let mrp = product.mrp
    let stock = product.stock

    if (variantName && variantsList.length > 0) {
      const v = variantsList.find((variant: any) => variant.name === variantName)
      if (v) {
        price = v.price !== undefined ? v.price : price
        mrp = v.mrp !== undefined ? v.mrp : mrp
        stock = v.stock !== undefined ? v.stock : stock
      }
    }

    setSelectedItems((prev) => {
      const existing = prev.find((item) => item.id === cartId)
      if (existing) {
        const isCafe = product.category?.slug === 'cafe' || product.tags?.includes('cafe')
        const limit = isCafe ? 10 : 99999
        const newQty = Math.min(existing.quantity + 1, stock, limit)
        return prev.map((item) => (item.id === cartId ? { ...item, quantity: newQty } : item))
      }
      return [
        ...prev,
        {
          id: cartId,
          product: {
            id: product.id,
            name: product.name,
            slug: product.slug,
            price,
            mrp,
            stock,
            imageUrl: product.imageUrl || null,
            variants: Array.isArray(product.variants) ? product.variants : [],
            category: product.category ? {
              id: product.category.id,
              name: product.category.name,
              slug: product.category.slug
            } : undefined,
            categorySlug: product.category?.slug || '',
          },
          quantity: 1,
          variantName,
        },
      ]
    })
    setVariantProduct(null)
    toast.success(`${product.name} ${variantName ? `(${variantName})` : ''} added`)
  }

  const handleUpdateQty = (itemId: string, currentQty: number, change: number, maxStock: number, isCafe: boolean) => {
    const limit = isCafe ? 10 : 99999
    const newQty = currentQty + change
    if (newQty <= 0) {
      setSelectedItems((prev) => prev.filter((item) => item.id !== itemId))
      return
    }
    if (newQty > Math.min(maxStock, limit)) return

    setSelectedItems((prev) =>
      prev.map((item) => (item.id === itemId ? { ...item, quantity: newQty } : item))
    )
  }

  const handleRemoveItem = (itemId: string) => {
    setSelectedItems((prev) => prev.filter((item) => item.id !== itemId))
  }

  const handleApplyCoupon = async (silent = false) => {
    if (!couponCode.trim()) {
      if (!silent) toast.error('Please enter a coupon code')
      return
    }
    setIsApplyingCoupon(true)
    try {
      const subtotal = calculateSubtotal()
      const res = await fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          code: couponCode.toUpperCase(), 
          subtotal,
          items: selectedItems.map(item => ({
            id: item.product.id,
            price: item.product.price,
            categoryId: item.product.category?.id,
            quantity: item.quantity
          }))
        }),
      })

      if (res.ok) {
        const data = await res.json()
        setAppliedCoupon(data.coupon)
        if (!silent) toast.success(`Coupon "${couponCode}" applied successfully!`)
      } else {
        const data = await res.json()
        setAppliedCoupon(null)
        if (!silent) toast.error(data.error || 'Invalid coupon code')
      }
    } catch (err) {
      setAppliedCoupon(null)
    } finally {
      setIsApplyingCoupon(false)
    }
  }

  const handleRemoveCoupon = () => {
    setAppliedCoupon(null)
    setCouponCode('')
  }

  // Calculations helper
  const calculateSubtotal = () => {
    return selectedItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  }

  const calculateMrpTotal = () => {
    return selectedItems.reduce((sum, item) => sum + (item.product.mrp || item.product.price) * item.quantity, 0)
  }

  const calculateDiscount = (subtotal: number) => {
    if (appliedCoupon) {
      return appliedCoupon.discountAmount || 0
    }
    return 0
  }

  const calculateFees = (subtotal: number, discount: number) => {
    if (selectedItems.length === 0) return { deliveryFee: 0, taxes: 0, miscFee: 0, total: 0, savings: 0 }

    const mrpTotal = calculateMrpTotal()
    const itemSavings = Math.max(0, mrpTotal - subtotal)

    // Dynamic distance tier rules calculation
    const rules = getDeliveryRules(1.0, { settings })
    const activeThreshold = rules.isServiceable
      ? rules.freeDeliveryThreshold
      : (settings.delivery_threshold_tier1 ? parseFloat(settings.delivery_threshold_tier1) : FREE_DELIVERY_THRESHOLD)

    const deliveryFeeVal = rules.isServiceable
      ? rules.deliveryFee
      : (settings.delivery_fee_tier1 ? parseFloat(settings.delivery_fee_tier1) : DELIVERY_FEE)

    let deliveryFee = 0
    if (deliveryMethod === 'DELIVERY') {
      deliveryFee = subtotal < activeThreshold ? deliveryFeeVal : 0
    }

    const discountedSubtotal = Math.max(0, subtotal - discount)
    const taxes = noGst ? 0 : 0 // Standard GST already embedded in retail prices
    const miscFee = settings.misc_fee ? parseFloat(settings.misc_fee) : 5
    const total = discountedSubtotal + deliveryFee + taxes + miscFee

    return {
      deliveryFee,
      taxes,
      miscFee,
      total,
      savings: itemSavings + discount,
      activeThreshold,
    }
  }

  const handleFormSubmit = async () => {
    if (!selectedCustomer) {
      toast.error('Please select a customer')
      return
    }
    if (deliveryMethod === 'DELIVERY') {
      if (isManualAddress) {
        if (!manualHouseNo.trim() || !manualStreet.trim() || !manualArea.trim() || !manualPincode.trim() || !manualPhone.trim()) {
          toast.error('Please fill in all manual address fields')
          return
        }
        if (manualPincode.trim() !== STORE_PINCODE) {
          toast.error(`Only pincode ${STORE_PINCODE} is serviceable for delivery in ${SERVICE_AREA_NAME}.`)
          return
        }
      } else {
        if (!selectedAddressId) {
          toast.error('Please select a delivery address')
          return
        }
      }
    }
    if (selectedItems.length === 0) {
      toast.error('Please add at least one product to the cart')
      return
    }

    setIsSubmitting(true)
    setSubmitError(null)

    try {
      let resolvedAddressId = selectedAddressId

      if (deliveryMethod === 'DELIVERY' && isManualAddress) {
        const addrRes = await fetch(`/api/admin/users/${selectedCustomer.id}/addresses`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            label: 'Home (Admin)',
            houseNo: manualHouseNo.trim(),
            street: manualStreet.trim(),
            area: manualArea.trim(),
            city: manualCity.trim(),
            pincode: manualPincode.trim(),
            phone: manualPhone.trim(),
          })
        })
        if (!addrRes.ok) {
          const err = await addrRes.json()
          throw new Error(err.error || 'Failed to save custom delivery address')
        }
        const savedAddr = await addrRes.json()
        resolvedAddressId = savedAddr.id
      }

      const payload = {
        customerId: selectedCustomer.id,
        addressId: deliveryMethod === 'PICKUP' ? null : resolvedAddressId,
        deliveryMethod,
        paymentMethod,
        noGst,
        couponCode: appliedCoupon ? appliedCoupon.code : null,
        items: selectedItems.map((item) => ({
          productId: item.product.id,
          name: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
          selectedVariant: item.variantName || null,
          notes: item.notes || null,
          product: {
            id: item.product.id,
            slug: item.product.slug,
            name: item.product.name,
            imageUrl: item.product.imageUrl,
            price: item.product.price,
            mrp: item.product.mrp,
            unit: '',
            stock: item.product.stock,
            isAvailable: true,
          },
        })),
      }

      const res = await fetch('/api/admin/orders/create-on-behalf', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (res.ok) {
        toast.success('Order placed successfully on behalf of customer!')
        onSuccess()
        resetForm()
        onClose()
      } else {
        const data = await res.json()
        setSubmitError(data.error || 'Failed to place order')
        toast.error(data.error || 'Failed to place order')
      }
    } catch (err: any) {
      console.error('Failed to submit order:', err)
      setSubmitError(err.message || 'Failed to connect to the server')
    } finally {
      setIsSubmitting(false)
    }
  }

  const resetForm = () => {
    setSelectedCustomer(null)
    setCustomerSearch('')
    setCustomersList([])
    setAddresses([])
    setSelectedAddressId('')
    setDeliveryMethod('DELIVERY')
    setProductSearch('')
    setProductsList([])
    setSelectedItems([])
    setVariantProduct(null)
    setCouponCode('')
    setAppliedCoupon(null)
    setPaymentMethod('COD')
    setSubmitError(null)
  }

  if (!isOpen) return null

  const subtotal = calculateSubtotal()
  const discount = calculateDiscount(subtotal)
  const { deliveryFee, taxes, miscFee, total, savings, activeThreshold } = calculateFees(subtotal, discount)
  const totalItemCount = selectedItems.reduce((sum, item) => sum + item.quantity, 0)

  // Customer initials
  const customerInitials = selectedCustomer?.name
    ? selectedCustomer.name
        .split(' ')
        .map((n) => n[0])
        .slice(0, 2)
        .join('')
        .toUpperCase()
    : 'CU'

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-3 sm:p-5 select-none overflow-y-auto">
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 10 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.96, y: 10 }}
        transition={{ duration: 0.2, ease: 'easeOut' }}
        className="bg-card border border-border/80 w-full max-w-5xl rounded-3xl shadow-2xl flex flex-col max-h-[92vh] overflow-hidden text-text-primary my-auto"
      >
        {/* Header Strip */}
        <div className="flex items-center justify-between border-b border-border/70 px-6 py-4.5 bg-gradient-to-r from-card via-muted/20 to-card">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-2xl bg-primary/10 text-primary flex items-center justify-center font-black shadow-xs border border-primary/20">
              <ShoppingBag className="h-5 w-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-black tracking-tight text-text-primary">
                  Place Order on Behalf of Customer
                </h2>
                <span className="hidden sm:inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 text-[10px] font-black border border-emerald-500/20">
                  <Sparkles className="h-3 w-3" />
                  Terminal Ready
                </span>
              </div>
              <p className="text-xs text-text-secondary font-medium mt-0.5">
                Admin POS Terminal • Live catalog, synchronized pricing &amp; auto-assignment
              </p>
            </div>
          </div>
          <button
            onClick={() => {
              resetForm()
              onClose()
            }}
            className="p-2 rounded-xl hover:bg-muted/80 text-text-secondary hover:text-text-primary transition-colors cursor-pointer border border-transparent hover:border-border/60 active:scale-95"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Modal Main Body Grid */}
        <div className="flex-1 overflow-y-auto p-5 sm:p-6 grid grid-cols-1 lg:grid-cols-12 gap-6 min-h-0">
          {/* Left Column (Customer, Delivery, Config) - 6 Cols */}
          <div className="lg:col-span-6 space-y-5">
            {/* Step 1: Customer Profile */}
            <div className="bg-muted/20 border border-border/70 rounded-2xl p-4.5 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="h-5.5 w-5.5 rounded-lg bg-primary text-white text-[11px] font-black flex items-center justify-center shadow-xs">
                    1
                  </span>
                  <span className="text-xs font-black uppercase tracking-wider text-text-primary">
                    Select Customer
                  </span>
                </div>
                {selectedCustomer && (
                  <button
                    onClick={() => {
                      setSelectedCustomer(null)
                      setAddresses([])
                      setSelectedAddressId('')
                      setActiveCartItems([])
                    }}
                    className="text-[11px] font-black text-rose-500 hover:text-rose-600 hover:underline tracking-wide uppercase cursor-pointer"
                  >
                    Change Customer
                  </button>
                )}
              </div>

              {!selectedCustomer ? (
                <div className="relative">
                  <div className="relative">
                    <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
                    <input
                      type="text"
                      value={customerSearch}
                      onChange={(e) => setCustomerSearch(e.target.value)}
                      placeholder="Search by name, 10-digit mobile, or email..."
                      className="w-full pl-10 pr-4 py-2.5 border border-border rounded-xl text-xs bg-card focus:outline-none focus:border-primary focus:ring-4 focus:ring-primary/10 font-bold text-text-primary placeholder:text-text-muted transition-all"
                    />
                    {isSearchingCustomers && (
                      <Loader2 className="absolute right-3.5 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin text-primary" />
                    )}
                  </div>

                  {/* Dropdown Results */}
                  {customersList.length > 0 && (
                    <div className="absolute left-0 right-0 mt-1.5 z-30 bg-card border border-border rounded-2xl shadow-xl max-h-52 overflow-y-auto divide-y divide-border/40 p-1">
                      {customersList.map((user) => (
                        <button
                          key={user.id}
                          onClick={() => handleSelectCustomer(user)}
                          className="w-full text-left p-2.5 hover:bg-muted/60 rounded-xl text-xs transition-all flex items-center justify-between cursor-pointer group"
                        >
                          <div className="flex items-center gap-3">
                            <div className="h-8 w-8 rounded-full bg-primary/10 text-primary font-black flex items-center justify-center text-xs shrink-0">
                              {(user.name || 'CU').slice(0, 2).toUpperCase()}
                            </div>
                            <div>
                              <span className="font-extrabold block text-text-primary group-hover:text-primary transition-colors">
                                {user.name || 'Anonymous Customer'}
                              </span>
                              <span className="text-[10px] text-text-muted font-semibold block mt-0.5">
                                {[formatPhone(user.phone || ''), formatDisplayEmail(user.email)].filter(Boolean).join(' • ') || 'No contact details'}
                              </span>
                            </div>
                          </div>
                          <span className="text-[10px] font-bold text-primary opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-1">
                            Select <ArrowRight className="h-3 w-3" />
                          </span>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-2.5">
                  <div className="flex items-center justify-between p-3.5 border border-primary/25 bg-gradient-to-r from-primary/10 via-primary/5 to-transparent rounded-2xl">
                    <div className="flex items-center gap-3.5 min-w-0">
                      <div className="h-10 w-10 rounded-2xl bg-primary text-white flex items-center justify-center font-black text-xs shadow-xs shrink-0">
                        {customerInitials}
                      </div>
                      <div className="min-w-0">
                        <span className="font-black text-xs block text-text-primary truncate">
                          {selectedCustomer.name || 'Anonymous Customer'}
                        </span>
                        <div className="flex flex-wrap items-center gap-2 mt-0.5">
                          {selectedCustomer.phone && (
                            <span className="inline-flex items-center gap-1 text-[10px] font-bold text-text-secondary">
                              <Phone className="h-2.5 w-2.5 text-primary" />
                              {selectedCustomer.phone}
                            </span>
                          )}
                          <span className="inline-flex items-center gap-1 text-[10px] font-medium text-text-muted truncate">
                            <Mail className="h-2.5 w-2.5 text-text-muted" />
                            {selectedCustomer.email}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Active Cart Banner */}
                  {activeCartItems.length > 0 && (
                    <div className="p-3 bg-amber-500/10 border border-amber-500/25 rounded-2xl flex items-center justify-between gap-3 animate-fade-in">
                      <div>
                        <span className="text-xs font-black text-amber-700 dark:text-amber-400 block flex items-center gap-1.5">
                          🛒 Active Cart ({activeCartItems.length} items)
                        </span>
                        <span className="text-[10px] font-medium text-text-secondary block mt-0.5">
                          Customer already has items staged in their cart.
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          setSelectedItems(activeCartItems)
                          toast.success(`Imported ${activeCartItems.length} items from customer's cart!`)
                        }}
                        className="px-3.5 py-1.5 bg-amber-600 hover:bg-amber-700 text-white text-[11px] font-black rounded-xl transition-all shrink-0 cursor-pointer shadow-xs active:scale-95 flex items-center gap-1"
                      >
                        Import ⚡
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Step 2: Shipping & Delivery */}
            <div className="bg-muted/20 border border-border/70 rounded-2xl p-4.5 space-y-3.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="h-5.5 w-5.5 rounded-lg bg-primary text-white text-[11px] font-black flex items-center justify-center shadow-xs">
                    2
                  </span>
                  <span className="text-xs font-black uppercase tracking-wider text-text-primary">
                    Shipping &amp; Fulfillment
                  </span>
                </div>
                {deliveryMethod === 'DELIVERY' && selectedCustomer && addresses.length > 0 && (
                  <button
                    type="button"
                    onClick={() => setIsManualAddress(!isManualAddress)}
                    className="text-[11px] text-primary hover:underline font-black cursor-pointer"
                  >
                    {isManualAddress ? '← Saved Addresses' : '+ Custom Address'}
                  </button>
                )}
              </div>

              {/* Delivery / Pickup Segmented Control */}
              <div className="grid grid-cols-2 gap-2 bg-muted/40 p-1 rounded-2xl border border-border/60">
                <button
                  type="button"
                  onClick={() => setDeliveryMethod('DELIVERY')}
                  className={`py-2 px-3 text-xs font-black rounded-xl transition-all cursor-pointer flex items-center justify-center gap-2 ${
                    deliveryMethod === 'DELIVERY'
                      ? 'bg-card text-primary shadow-xs border border-border scale-101'
                      : 'text-text-secondary hover:text-text-primary'
                  }`}
                >
                  <Truck className="h-3.5 w-3.5 text-primary" />
                  Home Delivery
                </button>
                <button
                  type="button"
                  onClick={() => setDeliveryMethod('PICKUP')}
                  className={`py-2 px-3 text-xs font-black rounded-xl transition-all cursor-pointer flex items-center justify-center gap-2 ${
                    deliveryMethod === 'PICKUP'
                      ? 'bg-card text-primary shadow-xs border border-border scale-101'
                      : 'text-text-secondary hover:text-text-primary'
                  }`}
                >
                  <Store className="h-3.5 w-3.5 text-primary" />
                  Self Pickup (Store)
                </button>
              </div>

              {deliveryMethod === 'DELIVERY' ? (
                <div className="space-y-2.5">
                  {!isManualAddress && addresses.length > 0 ? (
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary block">
                        Select Saved Address
                      </label>
                      <select
                        value={selectedAddressId}
                        onChange={(e) => setSelectedAddressId(e.target.value)}
                        className="w-full px-3.5 py-2.5 border border-border rounded-xl text-xs bg-card focus:outline-none focus:border-primary font-bold text-text-primary cursor-pointer shadow-2xs"
                      >
                        {addresses.map((addr) => (
                          <option key={addr.id} value={addr.id}>
                            📍 [{addr.label.toUpperCase()}] {addr.houseNo}, {addr.street}, {addr.area} ({addr.pincode})
                          </option>
                        ))}
                      </select>
                    </div>
                  ) : (
                    <div className="space-y-2.5 bg-card/60 border border-border/80 p-3.5 rounded-2xl animate-fade-in">
                      <div className="flex items-center gap-1.5 text-[10px] font-black text-text-secondary uppercase tracking-wider">
                        <MapPin className="h-3.5 w-3.5 text-primary" />
                        Enter Delivery Address
                      </div>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        <div className="space-y-1">
                          <label className="text-[9.5px] font-bold text-text-secondary">House / Flat / Floor *</label>
                          <input
                            type="text"
                            required
                            placeholder="e.g. Flat 402, Block B"
                            value={manualHouseNo}
                            onChange={(e) => setManualHouseNo(e.target.value)}
                            className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-card focus:outline-none focus:border-primary font-bold text-text-primary placeholder:text-text-muted"
                          />
                        </div>
                        <div className="space-y-1">
                          <label className="text-[9.5px] font-bold text-text-secondary">Street / Landmark *</label>
                          <input
                            type="text"
                            required
                            placeholder="e.g. Near Vikas Medical Store"
                            value={manualStreet}
                            onChange={(e) => setManualStreet(e.target.value)}
                            className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-card focus:outline-none focus:border-primary font-bold text-text-primary placeholder:text-text-muted"
                          />
                        </div>
                      </div>
                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                        <div className="space-y-1">
                          <label className="text-[9.5px] font-bold text-text-secondary">Area / Mohalla *</label>
                          <input
                            type="text"
                            required
                            placeholder="e.g. Kanpur Road"
                            value={manualArea}
                            onChange={(e) => setManualArea(e.target.value)}
                            className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-card focus:outline-none focus:border-primary font-bold text-text-primary placeholder:text-text-muted"
                          />
                        </div>
                        <div className="space-y-1">
                          <label className="text-[9.5px] font-bold text-text-secondary">Pincode *</label>
                          <input
                            type="text"
                            required
                            disabled
                            value={manualPincode}
                            className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-muted/40 text-text-muted focus:outline-none font-bold"
                          />
                        </div>
                        <div className="space-y-1">
                          <label className="text-[9.5px] font-bold text-text-secondary">Recipient Phone *</label>
                          <input
                            type="text"
                            required
                            placeholder="10-digit mobile"
                            value={manualPhone}
                            onChange={(e) => setManualPhone(e.target.value)}
                            className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-card focus:outline-none focus:border-primary font-bold text-text-primary placeholder:text-text-muted"
                          />
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="p-3.5 border border-emerald-500/25 bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 rounded-2xl flex items-start gap-2.5">
                  <Check className="h-4 w-4 stroke-[3] shrink-0 mt-0.5" />
                  <div>
                    <span className="font-black text-xs block">Warehouse Pickup Selected</span>
                    <p className="text-[10px] font-medium leading-relaxed mt-0.5">
                      Order will be packed at the dark store hub for customer counter pickup. Zero delivery fees applied.
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* Step 3: Order Settings & Promo */}
            <div className="bg-muted/20 border border-border/70 rounded-2xl p-4.5 space-y-3.5">
              <div className="flex items-center gap-2">
                <span className="h-5.5 w-5.5 rounded-lg bg-primary text-white text-[11px] font-black flex items-center justify-center shadow-xs">
                  3
                </span>
                <span className="text-xs font-black uppercase tracking-wider text-text-primary">
                  Order Configuration &amp; Promo
                </span>
              </div>

              {/* Coupon Code Input Strip */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary block">
                  Apply Discount Coupon
                </label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <Tag className="absolute left-3.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted" />
                    <input
                      type="text"
                      value={couponCode}
                      onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                      placeholder="ENTER COUPON CODE..."
                      disabled={!!appliedCoupon || isApplyingCoupon}
                      className="w-full pl-9 pr-3 py-2 border border-border rounded-xl text-xs bg-card focus:outline-none focus:border-primary uppercase font-black tracking-wider text-text-primary disabled:opacity-60"
                    />
                  </div>
                  {!appliedCoupon ? (
                    <button
                      type="button"
                      onClick={() => handleApplyCoupon()}
                      disabled={isApplyingCoupon || !couponCode.trim()}
                      className="bg-primary hover:bg-primary-dark text-white font-black text-xs px-4 py-2 rounded-xl transition-all cursor-pointer disabled:opacity-50 active:scale-95 shadow-xs"
                    >
                      {isApplyingCoupon ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Apply'}
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={handleRemoveCoupon}
                      className="bg-muted hover:bg-muted/80 text-text-primary font-black text-xs px-3.5 py-2 rounded-xl transition-all cursor-pointer border border-border"
                    >
                      Remove
                    </button>
                  )}
                </div>
                {appliedCoupon && (
                  <p className="text-[10px] text-emerald-600 dark:text-emerald-400 font-extrabold flex items-center gap-1 mt-1">
                    <Percent className="h-3 w-3" />
                    Coupon &quot;{appliedCoupon.code}&quot; applied! Save {formatPrice(appliedCoupon.discountAmount)}
                  </p>
                )}
              </div>

              {/* No GST Checkbox */}
              <label className="flex items-center gap-3 cursor-pointer bg-card/60 border border-border/70 p-3 rounded-xl hover:bg-card transition-all select-none">
                <input
                  type="checkbox"
                  checked={noGst}
                  onChange={(e) => setNoGst(e.target.checked)}
                  className="h-4 w-4 rounded border-border text-primary focus:ring-primary cursor-pointer accent-primary"
                />
                <div>
                  <span className="text-xs font-black block text-text-primary">
                    Tax Exempt / B2B Direct (0% Tax)
                  </span>
                  <span className="text-[10px] font-medium text-text-secondary block">
                    Retail prices already include all statutory GST. Check to record zero tax breakdown.
                  </span>
                </div>
              </label>
            </div>
          </div>

          {/* Right Column (Product Search, Items, Billing & Submit) - 6 Cols */}
          <div className="lg:col-span-6 flex flex-col min-h-0 space-y-4">
            {/* Step 4: Add Products Search */}
            <div className="bg-muted/20 border border-border/70 rounded-2xl p-4.5 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="h-5.5 w-5.5 rounded-lg bg-primary text-white text-[11px] font-black flex items-center justify-center shadow-xs">
                    4
                  </span>
                  <span className="text-xs font-black uppercase tracking-wider text-text-primary">
                    Catalog &amp; Cart Items
                  </span>
                </div>
                <span className="text-[10px] font-black px-2 py-0.5 rounded-md bg-primary/10 text-primary">
                  {totalItemCount} {totalItemCount === 1 ? 'item' : 'items'}
                </span>
              </div>

              <div className="relative">
                <div className="relative">
                  <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
                  <input
                    type="text"
                    value={productSearch}
                    onChange={(e) => setProductSearch(e.target.value)}
                    placeholder="Search products by name or category..."
                    className="w-full pl-10 pr-4 py-2.5 border border-border rounded-xl text-xs bg-card focus:outline-none focus:border-primary focus:ring-4 focus:ring-primary/10 font-bold text-text-primary placeholder:text-text-muted transition-all"
                  />
                  {isSearchingProducts && (
                    <Loader2 className="absolute right-3.5 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin text-primary" />
                  )}
                </div>

                {/* Dropdown Products Search Results */}
                {productsList.length > 0 && (
                  <div className="absolute left-0 right-0 mt-1.5 z-30 bg-card border border-border rounded-2xl shadow-xl max-h-56 overflow-y-auto divide-y divide-border/40 p-1">
                    {productsList.map((product) => (
                      <button
                        key={product.id}
                        onClick={() => handleSelectProduct(product)}
                        disabled={product.stock <= 0 || !product.isAvailable}
                        className="w-full text-left p-2.5 hover:bg-muted/60 rounded-xl text-xs transition-all flex items-center justify-between cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed group"
                      >
                        <div className="min-w-0 pr-3">
                          <span className="font-extrabold block text-text-primary group-hover:text-primary transition-colors truncate">
                            {product.name}
                          </span>
                          <span className="text-[10px] text-text-muted font-bold block mt-0.5">
                            ₹{product.price} {product.mrp > product.price && `(MRP: ₹${product.mrp})`} • Stock: {product.stock}
                          </span>
                        </div>
                        <div className="h-7 w-7 rounded-lg bg-primary/10 text-primary group-hover:bg-primary group-hover:text-white flex items-center justify-center transition-all shrink-0">
                          <Plus className="h-4 w-4" />
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Variant Selector Popout */}
              {variantProduct && (
                <div className="p-3.5 border border-primary/30 bg-primary/5 rounded-2xl space-y-2 animate-fade-in">
                  <div className="flex items-center justify-between">
                    <span className="font-black text-xs text-text-primary">
                      Select Variant for {variantProduct.name}
                    </span>
                    <button onClick={() => setVariantProduct(null)} className="text-text-muted hover:text-text-primary">
                      <X className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="space-y-1.5 max-h-36 overflow-y-auto">
                    {variantProduct.variants.map((v: any) => (
                      <button
                        key={v.name}
                        onClick={() => addProductToCart(variantProduct, v.name)}
                        disabled={v.stock <= 0}
                        className="w-full flex items-center justify-between p-2.5 border border-border/80 bg-card hover:border-primary rounded-xl text-xs font-bold transition-all disabled:opacity-50 text-left cursor-pointer"
                      >
                        <div>
                          <span className="font-black text-text-primary block">{v.name}</span>
                          <span className="text-[10px] text-text-secondary font-medium">
                            Price: ₹{v.price} • Stock: {v.stock}
                          </span>
                        </div>
                        <div className="h-6 w-6 rounded-lg bg-primary/10 text-primary flex items-center justify-center">
                          <Plus className="h-3.5 w-3.5" />
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* Selected Items List Box */}
            <div className="flex-1 min-h-[160px] max-h-[220px] overflow-y-auto border border-border/70 rounded-2xl p-3 space-y-2.5 bg-muted/10">
              {selectedItems.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-center p-6 space-y-2">
                  <ShoppingBag className="h-8 w-8 text-text-muted stroke-[1.5]" />
                  <p className="text-xs font-bold text-text-secondary">
                    No products added yet.
                  </p>
                  <p className="text-[10px] text-text-muted">
                    Search and click on any product from the catalog above to add.
                  </p>
                </div>
              ) : (
                selectedItems.map((item) => {
                  const isCafe = item.product.categorySlug === 'cafe'
                  return (
                    <div
                      key={item.id}
                      className="p-3 border border-border/70 bg-card rounded-xl space-y-2 shadow-2xs"
                    >
                      <div className="flex items-center justify-between gap-3">
                        <div className="min-w-0 flex-1">
                          <span className="font-black text-xs text-text-primary block truncate">
                            {item.product.name}
                          </span>
                          <div className="flex items-center gap-2 mt-0.5">
                            {item.variantName && (
                              <span className="text-[9px] font-black text-primary bg-primary/10 px-1.5 py-0.5 rounded-md">
                                {item.variantName}
                              </span>
                            )}
                            <span className="text-[11px] font-extrabold text-text-secondary">
                              {formatPrice(item.product.price)}
                            </span>
                            <span className="text-[10px] text-text-muted font-medium">
                              • In Stock: {item.product.stock}
                            </span>
                          </div>
                        </div>

                        {/* Stepper and Delete */}
                        <div className="flex items-center gap-2">
                          <div className="flex items-center border border-border/80 rounded-xl bg-muted/30 p-0.5 shadow-2xs">
                            <button
                              type="button"
                              onClick={() => handleUpdateQty(item.id, item.quantity, -1, item.product.stock, isCafe)}
                              className="h-6 w-6 rounded-lg hover:bg-card text-text-secondary hover:text-text-primary flex items-center justify-center transition-colors cursor-pointer"
                            >
                              <Minus className="h-3 w-3 stroke-[3]" />
                            </button>
                            <span className="w-6 text-center text-xs font-black text-text-primary">
                              {item.quantity}
                            </span>
                            <button
                              type="button"
                              onClick={() => handleUpdateQty(item.id, item.quantity, 1, item.product.stock, isCafe)}
                              className="h-6 w-6 rounded-lg hover:bg-card text-text-primary flex items-center justify-center transition-colors cursor-pointer"
                            >
                              <Plus className="h-3 w-3 stroke-[3]" />
                            </button>
                          </div>
                          <button
                            type="button"
                            onClick={() => handleRemoveItem(item.id)}
                            className="p-1.5 rounded-lg text-rose-500 hover:bg-rose-500/10 transition-colors cursor-pointer"
                            title="Remove item"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </div>

                      {/* Notes for kitchen/outlet */}
                      {isCafe && (
                        <input
                          type="text"
                          value={item.notes || ''}
                          onChange={(e) => {
                            const val = e.target.value
                            setSelectedItems((prev) =>
                              prev.map((si) => (si.id === item.id ? { ...si, notes: val } : si))
                            )
                          }}
                          placeholder="Cooking instruction (e.g. less spicy, extra dip)..."
                          className="w-full px-2.5 py-1 text-[10px] border border-border/60 rounded-lg bg-muted/20 focus:outline-none focus:border-primary font-medium"
                        />
                      )}
                    </div>
                  )
                })
              )}
            </div>

            {/* Systematic Bill Receipt & Action Bar */}
            <div className="bg-card border border-border/80 rounded-2xl p-4.5 space-y-3.5 shadow-xs">
              <div className="flex items-center justify-between border-b border-border/50 pb-2">
                <span className="text-xs font-black text-text-primary flex items-center gap-1.5">
                  <Receipt className="h-3.5 w-3.5 text-primary" />
                  Bill Breakdown
                </span>
                {savings > 0 && (
                  <span className="text-[10px] font-black text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full">
                    Saving {formatPrice(savings)}
                  </span>
                )}
              </div>

              <div className="space-y-1.5 text-xs">
                <div className="flex justify-between font-bold text-text-secondary">
                  <span>Items Subtotal</span>
                  <span>{formatPrice(subtotal)}</span>
                </div>

                {discount > 0 && (
                  <div className="flex justify-between font-extrabold text-emerald-600 dark:text-emerald-400">
                    <span>Coupon Discount</span>
                    <span>-{formatPrice(discount)}</span>
                  </div>
                )}

                {deliveryMethod === 'DELIVERY' && (
                  <div className="flex justify-between font-bold text-text-secondary">
                    <span>Delivery Charges</span>
                    <span>{deliveryFee === 0 ? <span className="text-emerald-600 font-extrabold">FREE</span> : formatPrice(deliveryFee)}</span>
                  </div>
                )}

                <div className="flex justify-between font-bold text-text-secondary">
                  <span>Handling / Platform Fee</span>
                  <span>{formatPrice(miscFee)}</span>
                </div>

                <div className="flex justify-between items-center text-sm font-black text-text-primary border-t border-border/80 pt-2.5 mt-1">
                  <span>Grand Total</span>
                  <span className="text-base text-primary font-black">{formatPrice(total)}</span>
                </div>
              </div>

              {/* Payment Mode Selector & Confirmation Button */}
              <div className="space-y-2.5 pt-1">
                <div className="flex items-center gap-2.5">
                  <label className="text-[10px] font-black uppercase text-text-secondary shrink-0 flex items-center gap-1">
                    <CreditCard className="h-3 w-3 text-text-muted" />
                    Payment Mode
                  </label>
                  <select
                    value={paymentMethod}
                    onChange={(e: any) => setPaymentMethod(e.target.value)}
                    className="flex-1 px-3 py-1.5 border border-border rounded-xl text-xs bg-muted/20 focus:outline-none focus:border-primary font-bold text-text-primary cursor-pointer"
                  >
                    <option value="COD">💵 Cash on Delivery (COD)</option>
                    <option value="UPI">📱 Instant UPI / QR Payment</option>
                    <option value="CARD">💳 Debit / Credit Card</option>
                  </select>
                </div>

                {submitError && (
                  <div className="text-[10px] font-extrabold text-rose-500 bg-rose-500/10 border border-rose-500/20 p-2.5 rounded-xl text-center flex items-center justify-center gap-1.5">
                    <AlertCircle className="h-3.5 w-3.5 shrink-0" />
                    {submitError}
                  </div>
                )}

                <button
                  type="button"
                  onClick={handleFormSubmit}
                  disabled={isSubmitting || !selectedCustomer || selectedItems.length === 0}
                  className="w-full bg-primary hover:bg-primary-dark text-white font-black text-xs py-3.5 rounded-2xl transition-all shadow-md active:scale-98 flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed uppercase tracking-wider border border-white/10"
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Creating Order...
                    </>
                  ) : (
                    <>
                      <Check className="h-4 w-4 stroke-[3]" />
                      Confirm &amp; Place Order ({formatPrice(total)})
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
