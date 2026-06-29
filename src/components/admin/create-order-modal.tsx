'use client'

import { useState, useEffect, useRef } from 'react'
import { Search, X, User, MapPin, Plus, Minus, Trash2, Loader2, Check, ShoppingBag, Percent } from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
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
  variants: any // JSON array
  category?: {
    id: string
    name: string
    slug: string
  }
}

interface SelectedItem {
  id: string // product id + variant name if variant
  product: {
    id: string
    name: string
    slug: string
    price: number
    mrp: number
    stock: number
    imageUrl: string | null
    variants: any[]
    categorySlug: string
  }
  quantity: number
  variantName: string | null
  notes?: string
}

export function CreateOrderModal({ isOpen, onClose, onSuccess }: CreateOrderModalProps) {
  // Customer selection states
  const [customerSearch, setCustomerSearch] = useState('')
  const [customersList, setCustomersList] = useState<CustomerUser[]>([])
  const [isSearchingCustomers, setIsSearchingCustomers] = useState(false)
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerUser | null>(null)

  // Address selection states
  const [addresses, setAddresses] = useState<Address[]>([])
  const [selectedAddressId, setSelectedAddressId] = useState('')
  const [deliveryMethod, setDeliveryMethod] = useState<'DELIVERY' | 'PICKUP'>('DELIVERY')

  // Product selection states
  const [productSearch, setProductSearch] = useState('')
  const [productsList, setProductsList] = useState<Product[]>([])
  const [isSearchingProducts, setIsSearchingProducts] = useState(false)
  const [selectedItems, setSelectedItems] = useState<SelectedItem[]>([])

  // Variant selector state
  const [variantProduct, setVariantProduct] = useState<Product | null>(null)

  // B2B & coupon states
  const [isB2B, setIsB2B] = useState(false)
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

  // Fetch addresses once customer is selected
  useEffect(() => {
    if (!selectedCustomer) {
      setAddresses([])
      setSelectedAddressId('')
      return
    }

    const fetchAddresses = async () => {
      try {
        const res = await fetch(`/api/admin/users/${selectedCustomer.id}/addresses`)
        if (res.ok) {
          const data = await res.json()
          setAddresses(data || [])
          if (data && data.length > 0) {
            setSelectedAddressId(data[0].id)
          }
        }
      } catch (err) {
        console.error('Failed to fetch addresses:', err)
      }
    }

    fetchAddresses()
  }, [selectedCustomer])

  // Recalculate coupon if items or B2B status changes
  useEffect(() => {
    if (appliedCoupon) {
      // Re-validate coupon
      handleApplyCoupon(true)
    }
  }, [selectedItems, isB2B])

  const handleSelectCustomer = (user: CustomerUser) => {
    setSelectedCustomer(user)
    setCustomerSearch('')
    setCustomersList([])
  }

  const handleSelectProduct = (product: Product) => {
    const hasVariants = product.variants && Array.isArray(product.variants) && product.variants.length > 0
    if (hasVariants) {
      setVariantProduct(product)
    } else {
      addProductToCart(product, null)
    }
    setProductSearch('')
    setProductsList([])
  }

  const addProductToCart = (product: Product, variantName: string | null) => {
    const cartId = variantName ? `${product.id}_${variantName}` : product.id
    
    // Resolve price, mrp and stock
    let price = product.price
    let mrp = product.mrp
    let stock = product.stock
    
    if (variantName && product.variants && Array.isArray(product.variants)) {
      const v = product.variants.find((variant: any) => variant.name === variantName)
      if (v) {
        price = v.price
        mrp = v.mrp
        stock = v.stock
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
            imageUrl: null,
            variants: Array.isArray(product.variants) ? product.variants : [],
            categorySlug: product.category?.slug || '',
          },
          quantity: 1,
          variantName,
        },
      ]
    })
    setVariantProduct(null)
    toast.success(`${product.name} ${variantName ? `(${variantName})` : ''} added to cart`)
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
            categoryId: item.product.categoryId,
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

  const calculateDiscount = (subtotal: number) => {
    if (isB2B) {
      return subtotal * 0.1 // Wholesale 10% discount
    }
    if (appliedCoupon) {
      return appliedCoupon.discountAmount || 0
    }
    return 0
  }

  const calculateFees = (subtotal: number, discount: number) => {
    if (selectedItems.length === 0) return { deliveryFee: 0, taxes: 0, miscFee: 0, total: 0 }

    // Check split delivery fees
    const cafeItems = selectedItems.filter(item => item.product.categorySlug === 'cafe')
    const groceryItems = selectedItems.filter(item => item.product.categorySlug !== 'cafe')

    const cafeSubtotal = cafeItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
    const grocerySubtotal = groceryItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)

    const settings = useUIStore.getState().settings || {}
    const groceryThreshold = settings.grocery_free_delivery_threshold ? parseFloat(settings.grocery_free_delivery_threshold) : FREE_DELIVERY_THRESHOLD
    const cafeThreshold = settings.cafe_free_delivery_threshold ? parseFloat(settings.cafe_free_delivery_threshold) : 199
    const combinedThreshold = settings.combined_free_delivery_threshold ? parseFloat(settings.combined_free_delivery_threshold) : 200
    const deliveryFeeVal = settings.delivery_fee ? parseFloat(settings.delivery_fee) : DELIVERY_FEE

    let deliveryFee = 0

    if (deliveryMethod === 'DELIVERY' && !isB2B) {
      let groceryDeliveryFee = (groceryItems.length > 0 && grocerySubtotal < groceryThreshold) ? deliveryFeeVal : 0
      let cafeDeliveryFee = (cafeItems.length > 0 && cafeSubtotal < cafeThreshold) ? deliveryFeeVal : 0

      // Apply combined fee cap
      if (groceryItems.length > 0 && cafeItems.length > 0 && subtotal >= combinedThreshold) {
        deliveryFee = 0
      } else {
        deliveryFee = groceryDeliveryFee + cafeDeliveryFee
      }
    }

    const discountedSubtotal = Math.max(0, subtotal - discount)
    const taxes = discountedSubtotal * 0.05 // 5% standard tax
    const miscFee = 5 // Standard ₹5 platform handling fee

    const total = discountedSubtotal + deliveryFee + taxes + miscFee

    return {
      deliveryFee,
      taxes,
      miscFee,
      total,
    }
  }

  const handleFormSubmit = async () => {
    if (!selectedCustomer) {
      toast.error('Please select a customer')
      return
    }
    if (deliveryMethod === 'DELIVERY' && !selectedAddressId) {
      toast.error('Please select a delivery address')
      return
    }
    if (selectedItems.length === 0) {
      toast.error('Please add at least one product to the cart')
      return
    }

    const subtotal = calculateSubtotal()
    if (isB2B && subtotal < 1000) {
      toast.error('B2B Wholesale orders require a minimum subtotal of ₹1,000')
      return
    }

    setIsSubmitting(true)
    setSubmitError(null)

    try {
      const payload = {
        customerId: selectedCustomer.id,
        addressId: deliveryMethod === 'PICKUP' ? null : selectedAddressId,
        deliveryMethod,
        paymentMethod,
        isB2B,
        couponCode: appliedCoupon ? appliedCoupon.code : null,
        items: selectedItems.map((item) => ({
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
          quantity: item.quantity,
          notes: item.notes || null,
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
    } catch (err) {
      console.error('Failed to submit order:', err)
      setSubmitError('Failed to connect to the server')
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
    setIsB2B(false)
    setCouponCode('')
    setAppliedCoupon(null)
    setPaymentMethod('COD')
    setSubmitError(null)
  }

  if (!isOpen) return null

  const subtotal = calculateSubtotal()
  const discount = calculateDiscount(subtotal)
  const { deliveryFee, taxes, miscFee, total } = calculateFees(subtotal, discount)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 select-none">
      <div className="bg-card border border-border w-full max-w-4xl rounded-2xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-scale-in text-text-primary">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-border px-6 py-4">
          <div className="flex items-center gap-2">
            <ShoppingBag className="text-primary h-5 w-5" />
            <h2 className="text-base font-black">Place Order on Behalf of Customer</h2>
          </div>
          <button
            onClick={() => {
              resetForm()
              onClose()
            }}
            className="p-1 rounded-full hover:bg-muted text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Modal Scrollable Body */}
        <div className="flex-1 overflow-y-auto p-6 grid grid-cols-1 md:grid-cols-2 gap-6 min-h-0">
          {/* Left Column: Customer & Shipping Details */}
          <div className="space-y-5">
            {/* 1. Customer Selection */}
            <div className="space-y-2 text-left">
              <label className="text-[11px] font-black uppercase tracking-wider text-text-muted">
                1. Select Customer
              </label>
              
              {!selectedCustomer ? (
                <div className="relative">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
                    <input
                      type="text"
                      value={customerSearch}
                      onChange={(e) => setCustomerSearch(e.target.value)}
                      placeholder="Search customer by name, email, or phone..."
                      className="w-full pl-9 pr-4 py-2 border border-border rounded-xl text-xs bg-muted/20 focus:outline-none focus:border-primary/50 focus:ring-4 focus:ring-primary/5 font-semibold"
                    />
                    {isSearchingCustomers && (
                      <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin text-primary" />
                    )}
                  </div>

                  {/* Dropdown Results */}
                  {customersList.length > 0 && (
                    <div className="absolute left-0 right-0 mt-1 z-25 bg-card border border-border rounded-xl shadow-lg max-h-48 overflow-y-auto divide-y divide-border/40">
                      {customersList.map((user) => (
                        <button
                          key={user.id}
                          onClick={() => handleSelectCustomer(user)}
                          className="w-full text-left px-4 py-2.5 hover:bg-muted text-xs transition-colors flex items-center justify-between cursor-pointer"
                        >
                          <div>
                            <span className="font-extrabold block text-text-primary">
                              {user.name || 'Anonymous User'}
                            </span>
                            <span className="text-[10px] text-text-muted font-bold block mt-0.5">
                              {user.email} {user.phone && `• ${user.phone}`}
                            </span>
                          </div>
                          <Check className="h-4 w-4 text-emerald-500 opacity-0 hover:opacity-100" />
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              ) : (
                <div className="flex items-center justify-between p-3.5 border border-primary/20 bg-primary/5 rounded-xl">
                  <div className="flex items-start gap-3">
                    <div className="h-8 w-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-sm">
                      <User className="h-4.5 w-4.5" />
                    </div>
                    <div className="text-left">
                      <span className="font-black text-xs block text-text-primary">
                        {selectedCustomer.name || 'Anonymous User'}
                      </span>
                      <span className="text-[10px] font-bold text-text-secondary block mt-0.5">
                        {selectedCustomer.email} {selectedCustomer.phone && `• ${selectedCustomer.phone}`}
                      </span>
                    </div>
                  </div>
                  <button
                    onClick={() => {
                      setSelectedCustomer(null)
                      setAddresses([])
                      setSelectedAddressId('')
                    }}
                    className="text-[10px] font-black text-rose-500 hover:underline tracking-wider uppercase cursor-pointer"
                  >
                    Change
                  </button>
                </div>
              )}
            </div>

            {/* 2. Delivery Method & Address Selector */}
            {selectedCustomer && (
              <div className="space-y-3 text-left animate-slide-up">
                <label className="text-[11px] font-black uppercase tracking-wider text-text-muted block">
                  2. Shipping & Delivery
                </label>

                {/* Method Switches */}
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => setDeliveryMethod('DELIVERY')}
                    className={`flex-1 py-2 px-3 text-xs font-bold rounded-xl border text-center transition-all cursor-pointer ${
                      deliveryMethod === 'DELIVERY'
                        ? 'border-primary bg-primary/5 text-primary font-black shadow-xs'
                        : 'border-border bg-card text-text-secondary hover:border-border/80'
                    }`}
                  >
                    Home Delivery
                  </button>
                  <button
                    type="button"
                    onClick={() => setDeliveryMethod('PICKUP')}
                    className={`flex-1 py-2 px-3 text-xs font-bold rounded-xl border text-center transition-all cursor-pointer ${
                      deliveryMethod === 'PICKUP'
                        ? 'border-primary bg-primary/5 text-primary font-black shadow-xs'
                        : 'border-border bg-card text-text-secondary hover:border-border/80'
                    }`}
                  >
                    Self Pickup
                  </button>
                </div>

                {deliveryMethod === 'DELIVERY' && (
                  <div className="space-y-2">
                    {addresses.length === 0 ? (
                      <div className="p-4 border border-dashed border-border bg-muted/10 rounded-xl text-center">
                        <MapPin className="h-6 w-6 text-text-muted mx-auto mb-1.5" />
                        <p className="text-[10px] font-bold text-text-muted">
                          Customer has no registered delivery addresses. Please ask them to add an address in their profile.
                        </p>
                      </div>
                    ) : (
                      <div className="relative">
                        <select
                          value={selectedAddressId}
                          onChange={(e) => setSelectedAddressId(e.target.value)}
                          className="w-full px-3 py-2 border border-border rounded-xl text-xs bg-muted/20 focus:outline-none focus:border-primary/50 font-bold"
                        >
                          {addresses.map((addr) => (
                            <option key={addr.id} value={addr.id}>
                              [{addr.label.toUpperCase()}] {addr.houseNo}, {addr.street}, {addr.area} ({addr.pincode})
                            </option>
                          ))}
                        </select>
                      </div>
                    )}
                  </div>
                )}

                {deliveryMethod === 'PICKUP' && (
                  <div className="p-3 border border-emerald-500/25 bg-emerald-500/5 text-emerald-600 dark:text-emerald-400 rounded-xl text-left flex items-start gap-2">
                    <Check className="h-4.5 w-4.5 stroke-[3] shrink-0 mt-0.5" />
                    <div>
                      <span className="font-extrabold text-[11px] block">Self Pickup Activated</span>
                      <p className="text-[10px] leading-tight mt-0.5 font-medium">
                        The order will be prepared for store pickup at the configured warehouse location. No shipping fee will apply.
                      </p>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* 3. Wholesale B2B & Coupon Configuration */}
            {selectedCustomer && (
              <div className="space-y-3.5 text-left border-t border-border/40 pt-4 animate-slide-up">
                <label className="text-[11px] font-black uppercase tracking-wider text-text-muted block">
                  3. Order Configuration
                </label>

                {/* B2B Toggle */}
                <label className="flex items-center gap-2.5 cursor-pointer bg-muted/10 border border-border/50 p-2.5 rounded-xl hover:bg-muted/20 transition-all select-none">
                  <input
                    type="checkbox"
                    checked={isB2B}
                    onChange={(e) => {
                      setIsB2B(e.target.checked)
                      if (e.target.checked) handleRemoveCoupon() // B2B disables coupon
                    }}
                    className="accent-primary h-4.5 w-4.5"
                  />
                  <div className="text-left">
                    <span className="text-xs font-black block text-text-primary">
                      B2B Wholesale Order
                    </span>
                    <span className="text-[9.5px] font-semibold text-text-secondary block mt-0.5">
                      Apply flat 10% wholesale discount (minimum subtotal ₹1,000 required).
                    </span>
                  </div>
                </label>

                {/* Coupon Code Input */}
                {!isB2B && (
                  <div className="space-y-2">
                    <label className="text-[10px] font-bold text-text-secondary block">
                      Apply Promo Coupon
                    </label>
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={couponCode}
                        onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                        placeholder="ENTER COUPON CODE..."
                        disabled={!!appliedCoupon || isApplyingCoupon}
                        className="flex-1 px-3 py-2 border border-border rounded-xl text-xs bg-muted/20 focus:outline-none focus:border-primary/50 uppercase font-black tracking-wider disabled:opacity-70"
                      />
                      {!appliedCoupon ? (
                        <button
                          type="button"
                          onClick={() => handleApplyCoupon()}
                          disabled={isApplyingCoupon || !couponCode.trim()}
                          className="bg-primary hover:bg-primary/95 text-white font-extrabold text-[10px] px-4 py-2 rounded-xl transition-all cursor-pointer disabled:opacity-50"
                        >
                          {isApplyingCoupon ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            'APPLY'
                          )}
                        </button>
                      ) : (
                        <button
                          type="button"
                          onClick={handleRemoveCoupon}
                          className="bg-zinc-200 dark:bg-zinc-800 text-text-primary hover:bg-zinc-300 dark:hover:bg-zinc-700 font-extrabold text-[10px] px-4 py-2 rounded-xl transition-all cursor-pointer"
                        >
                          REMOVE
                        </button>
                      )}
                    </div>
                    {appliedCoupon && (
                      <p className="text-[10px] text-emerald-600 dark:text-emerald-400 font-extrabold flex items-center gap-1.5 mt-1">
                        <Percent className="h-3 w-3" />
                        Coupon Applied! (Save {formatPrice(appliedCoupon.discountAmount)})
                      </p>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Right Column: Cart Item Details & Checkout Calculation */}
          <div className="flex flex-col min-h-0 border-t md:border-t-0 md:border-l border-border/60 md:pl-6 pt-6 md:pt-0">
            {/* 4. Product search */}
            <div className="space-y-2 text-left shrink-0">
              <label className="text-[11px] font-black uppercase tracking-wider text-text-muted">
                4. Add Products
              </label>
              
              <div className="relative">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
                  <input
                    type="text"
                    value={productSearch}
                    onChange={(e) => setProductSearch(e.target.value)}
                    placeholder="Search product name or categories..."
                    className="w-full pl-9 pr-4 py-2 border border-border rounded-xl text-xs bg-muted/20 focus:outline-none focus:border-primary/50 focus:ring-4 focus:ring-primary/5 font-semibold"
                  />
                  {isSearchingProducts && (
                    <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin text-primary" />
                  )}
                </div>

                {/* Dropdown Results */}
                {productsList.length > 0 && (
                  <div className="absolute left-0 right-0 mt-1 z-25 bg-card border border-border rounded-xl shadow-lg max-h-48 overflow-y-auto divide-y divide-border/40">
                    {productsList.map((product) => (
                      <button
                        key={product.id}
                        onClick={() => handleSelectProduct(product)}
                        disabled={product.stock <= 0 || !product.isAvailable}
                        className="w-full text-left px-4 py-2.5 hover:bg-muted text-xs transition-colors flex items-center justify-between cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        <div>
                          <span className="font-extrabold block text-text-primary">
                            {product.name}
                          </span>
                          <span className="text-[10px] text-text-muted font-bold block mt-0.5">
                            ₹{product.price} {product.mrp > product.price && `(MRP: ₹${product.mrp})`} • Stock: {product.stock}
                          </span>
                        </div>
                        <Plus className="h-4.5 w-4.5 text-primary" />
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Variant Selector Overlay/Inline Modal */}
            {variantProduct && (
              <div className="mt-3 p-3.5 border border-primary/25 bg-primary/5 rounded-xl text-left animate-slide-down shrink-0">
                <div className="flex justify-between items-center mb-2">
                  <span className="font-black text-xs text-text-primary">Select Variant for {variantProduct.name}</span>
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
                      className="w-full flex items-center justify-between p-2 border border-border bg-card hover:border-primary/30 rounded-lg text-xs font-semibold disabled:opacity-50 text-left"
                    >
                      <div>
                        <span className="font-bold text-text-primary">{v.name}</span>
                        <span className="block text-[9.5px] text-text-muted font-medium mt-0.5">
                          Price: ₹{v.price} • Stock: {v.stock}
                        </span>
                      </div>
                      <Plus className="h-4 w-4 text-primary" />
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Cart Items List */}
            <div className="flex-1 min-h-[160px] overflow-y-auto border border-border/80 rounded-xl my-4 p-3 space-y-2 text-left bg-muted/5">
              {selectedItems.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-center p-6">
                  <ShoppingBag className="h-8 w-8 text-text-muted stroke-[1.5] mb-2" />
                  <p className="text-[10px] font-bold text-text-muted">
                    No items added yet. Search products above.
                  </p>
                </div>
              ) : (
                selectedItems.map((item) => {
                  const isCafe = item.product.categorySlug === 'cafe'
                  return (
                    <div
                      key={item.id}
                      className="flex flex-col gap-2 p-2.5 border border-border/60 bg-card rounded-lg"
                    >
                      <div className="flex items-center justify-between">
                        <div className="min-w-0 flex-1 pr-3">
                          <span className="font-extrabold text-[11px] text-text-primary block truncate">
                            {item.product.name}
                          </span>
                          {item.variantName && (
                            <span className="inline-block text-[8px] font-bold text-primary bg-primary/5 px-1 py-0.5 rounded mt-0.5">
                              {item.variantName}
                            </span>
                          )}
                          <span className="text-[10px] font-extrabold text-text-secondary block mt-0.5">
                            {formatPrice(item.product.price)} • Stock: {item.product.stock}
                          </span>
                        </div>

                        {/* Quantity Controller & Delete */}
                        <div className="flex items-center gap-2">
                          <div className="flex items-center border border-border rounded-full p-0.5 bg-card">
                            <button
                              onClick={() => handleUpdateQty(item.id, item.quantity, -1, item.product.stock, isCafe)}
                              className="h-6 w-6 rounded-full hover:bg-muted text-text-secondary flex items-center justify-center transition-colors cursor-pointer"
                            >
                              <Minus className="h-3 w-3 stroke-[3]" />
                            </button>
                            <span className="w-5 text-center text-[10px] font-black text-text-primary">
                              {item.quantity}
                            </span>
                            <button
                              onClick={() => handleUpdateQty(item.id, item.quantity, 1, item.product.stock, isCafe)}
                              className="h-6 w-6 rounded-full hover:bg-muted text-text-primary flex items-center justify-center transition-colors cursor-pointer"
                            >
                              <Plus className="h-3 w-3 stroke-[3]" />
                            </button>
                          </div>
                          <button
                            onClick={() => handleRemoveItem(item.id)}
                            className="p-1 rounded-lg text-rose-500 hover:bg-rose-500/10 transition-colors cursor-pointer"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </div>

                      {/* Cooking Instructions Notes for Cafe Items */}
                      {isCafe && (
                        <div className="mt-1 border-t border-border/30 pt-2 shrink-0">
                          <input
                            type="text"
                            value={item.notes || ''}
                            onChange={(e) => {
                              const val = e.target.value
                              setSelectedItems((prev) =>
                                prev.map((si) => (si.id === item.id ? { ...si, notes: val } : si))
                              )
                            }}
                            placeholder="Cooking instruction (e.g. less sugar, extra spicy)..."
                            className="w-full px-3 py-1.5 border border-border/80 rounded-xl text-[10px] bg-muted/20 focus:outline-none focus:border-primary/45 font-bold"
                          />
                        </div>
                      )}
                    </div>
                  )
                })
              )}
            </div>

            {/* Calculations Breakdown */}
            <div className="border-t border-border pt-4 mt-auto space-y-2 text-xs shrink-0 bg-card">
              <div className="flex justify-between font-bold text-text-secondary">
                <span>Subtotal</span>
                <span>{formatPrice(subtotal)}</span>
              </div>
              
              {(discount > 0) && (
                <div className="flex justify-between font-bold text-emerald-600 dark:text-emerald-400">
                  <span>Discount {isB2B && '(B2B Wholesale 10%)'}</span>
                  <span>-{formatPrice(discount)}</span>
                </div>
              )}

              {deliveryMethod === 'DELIVERY' && (
                <div className="flex justify-between font-bold text-text-secondary">
                  <span>Delivery Fee</span>
                  <span>{deliveryFee === 0 ? 'FREE' : formatPrice(deliveryFee)}</span>
                </div>
              )}

              <div className="flex justify-between font-bold text-text-secondary">
                <span>Estimated Taxes (5%)</span>
                <span>{formatPrice(taxes)}</span>
              </div>

              <div className="flex justify-between font-bold text-text-secondary">
                <span>Platform/Handling Fee</span>
                <span>{formatPrice(miscFee)}</span>
              </div>

              <div className="flex justify-between text-sm font-black text-text-primary border-t border-border/80 pt-2.5 mt-1.5">
                <span>Grand Total</span>
                <span>{formatPrice(total)}</span>
              </div>

              {/* Payment selection & Submit Button */}
              {selectedCustomer && selectedItems.length > 0 && (
                <div className="space-y-3 pt-3 animate-slide-up">
                  <div className="flex items-center gap-3">
                    <label className="text-[10px] font-black text-text-muted uppercase shrink-0">
                      Payment
                    </label>
                    <select
                      value={paymentMethod}
                      onChange={(e: any) => setPaymentMethod(e.target.value)}
                      className="flex-1 px-3 py-1.5 border border-border rounded-xl text-xs bg-muted/20 focus:outline-none focus:border-primary/50 font-bold"
                    >
                      <option value="COD">Cash on Delivery (COD)</option>
                      <option value="UPI">UPI Payment</option>
                      <option value="CARD">Credit/Debit Card</option>
                    </select>
                  </div>

                  {submitError && (
                    <div className="text-[10px] font-extrabold text-rose-500 bg-rose-500/5 border border-rose-500/10 p-2 rounded-xl text-center">
                      Error: {submitError}
                    </div>
                  )}

                  <button
                    onClick={handleFormSubmit}
                    disabled={isSubmitting}
                    className="w-full bg-primary hover:bg-primary/95 text-white font-black text-xs py-3 rounded-xl transition-all shadow-md active:scale-98 flex items-center justify-center gap-2 cursor-pointer disabled:opacity-75 disabled:cursor-not-allowed uppercase tracking-wider border border-white/10"
                  >
                    {isSubmitting ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin" />
                        Placing Order...
                      </>
                    ) : (
                      <>
                        <Check className="h-4 w-4 stroke-[3]" />
                        Confirm & Place Order
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
