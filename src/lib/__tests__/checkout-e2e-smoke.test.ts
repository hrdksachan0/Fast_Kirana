import test, { describe } from 'node:test'
import assert from 'node:assert/strict'
import {
  classifyItems,
  validateAddress,
  validateCheckoutEligibility,
  DEFAULT_STORE_LAT,
  DEFAULT_STORE_LNG,
  Address,
} from '../checkout'
import {
  calculateItemSubtotal,
  calculateCouponDiscount,
  PricingItem,
} from '../../services/order-pricing.service'
import {
  calculateOrderDeliveryFees,
  DeliveryCalculationParams,
} from '../delivery-fee-calculator'
import {
  CreateOrderInputSchema,
  UpdateOrderStatusSchema,
} from '../validations/order'

describe('Automated E2E Checkout Smoke Test (Web)', () => {
  // ── Test Context Fixtures ──
  const mockAddress: Address = {
    id: 'addr_customer_101',
    pincode: '209206',
    city: 'Ghatampur, Kanpur Nagar',
    phone: '9876543210',
    lat: DEFAULT_STORE_LAT + 0.005, // ~600m from dark store hub
    lng: DEFAULT_STORE_LNG + 0.004,
  }

  const baseSettings = {
    delivery_fee: '25',
    grocery_free_delivery_threshold: '199',
    restaurant_free_delivery_threshold: '250',
    combined_free_delivery_threshold: '299',
  }

  const mockGroceryProduct1 = {
    id: 'prod_atta_5kg',
    name: 'Aashirvaad Shudh Chakki Atta 5kg',
    price: 245,
    category: { slug: 'staples' },
    tags: ['atta', 'grocery', 'flour'],
  }

  const mockGroceryProduct2 = {
    id: 'prod_milk_amul',
    name: 'Amul Taaza Toned Milk 500ml',
    price: 27,
    category: { slug: 'dairy' },
    tags: ['milk', 'dairy', 'fresh'],
  }

  const mockVariantProduct = {
    id: 'prod_basmati_rice',
    name: 'India Gate Basmati Rice',
    price: 110,
    category: { slug: 'staples' },
    variants: [
      { name: '1kg', price: 110 },
      { name: '5kg', price: 520 },
    ],
  }

  test('E2E Flow 1: Grocery Cash on Delivery (COD) Standard Delivery Checkout', async () => {
    // Step 1: Cart Preparation
    const cartItems = [
      { product: mockGroceryProduct1, quantity: 1 },
      { product: mockGroceryProduct2, quantity: 2 },
      {
        product: mockVariantProduct,
        quantity: 1,
        selectedVariant: '5kg',
      },
    ]

    // Verify item classification
    const classification = classifyItems(cartItems)
    assert.equal(classification.hasGrocery, true)
    assert.equal(classification.hasRestaurant, false)
    assert.equal(classification.hasCafe, false)

    // Step 2: Address & Geofence Validation
    const addressValidation = validateAddress(mockAddress, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, 5.0)
    assert.equal(addressValidation.valid, true, 'Address must be inside 5km service geofence')

    // Step 3: Checkout Eligibility
    const eligibility = await validateCheckoutEligibility({
      items: cartItems,
      addresses: [mockAddress],
      selectedAddressId: mockAddress.id,
      deliveryMethod: 'DELIVERY',
      settings: {
        grocery_mart_open: 'true',
        delivery_radius: '5.0',
        min_order_value: '50',
      },
    })
    assert.equal(eligibility.valid, true)
    assert.equal(eligibility.finalAddressId, mockAddress.id)

    // Step 4: Subtotal Calculation
    const pricingItems: PricingItem[] = [
      { product: { id: mockGroceryProduct1.id }, dbProduct: { price: mockGroceryProduct1.price }, quantity: 1 },
      { product: { id: mockGroceryProduct2.id }, dbProduct: { price: mockGroceryProduct2.price }, quantity: 2 },
      {
        product: { id: mockVariantProduct.id },
        dbProduct: { price: mockVariantProduct.price, variants: mockVariantProduct.variants },
        quantity: 1,
        selectedVariant: '5kg',
      },
    ]
    // 245*1 + 27*2 + 520*1 = 245 + 54 + 520 = 819
    const subtotal = calculateItemSubtotal(pricingItems)
    assert.equal(subtotal, 819)

    // Step 5: Coupon Application (Flat ₹50 off on orders >= ₹500)
    const couponResult = calculateCouponDiscount(
      {
        id: 'c_grocery_50',
        isActive: true,
        discountType: 'FLAT',
        value: 50,
        minOrder: 500,
        applicableType: 'GROCERY',
      },
      subtotal,
      subtotal,
      0
    )
    assert.equal(couponResult.meetsMinOrder, true)
    assert.equal(couponResult.combinedDiscount, 50)

    // Step 6: Delivery Fee & Packaging Fee
    const deliveryParams: DeliveryCalculationParams = {
      deliveryMethod: 'DELIVERY',
      isB2B: false,
      resolvedLat: mockAddress.lat!,
      resolvedLng: mockAddress.lng!,
      storeLat: DEFAULT_STORE_LAT,
      storeLng: DEFAULT_STORE_LNG,
      maxRadiusKm: 5.0,
      storeDisplayName: 'FastKirana Hub',
      settingsMap: baseSettings,
      groceryItems: [{ id: mockGroceryProduct1.id }],
      grocerySubtotal: subtotal,
      restaurantData: [],
      combinedSubtotal: subtotal,
    }
    const deliveryResult = await calculateOrderDeliveryFees(deliveryParams)
    // Subtotal ₹819 is >= ₹199 free delivery threshold
    assert.equal(deliveryResult.groceryDeliveryFee, 0, 'Delivery fee should be free for subtotal >= ₹199')

    const handlingFee = 5 // Normal handling fee
    const finalPayable = subtotal - couponResult.combinedDiscount + deliveryResult.groceryDeliveryFee + handlingFee
    assert.equal(finalPayable, 819 - 50 + 0 + 5) // 774

    // Step 7: Order Payload Validation (Zod Schema for /api/orders)
    const orderPayload = {
      items: [
        {
          productId: mockGroceryProduct1.id,
          name: mockGroceryProduct1.name,
          price: mockGroceryProduct1.price,
          quantity: 1,
        },
        {
          productId: mockGroceryProduct2.id,
          name: mockGroceryProduct2.name,
          price: mockGroceryProduct2.price,
          quantity: 2,
        },
        {
          productId: mockVariantProduct.id,
          name: mockVariantProduct.name,
          price: 520,
          quantity: 1,
          selectedVariant: '5kg',
        },
      ],
      paymentMethod: 'COD' as const,
      address: {
        houseNo: 'House #12',
        street: 'Ghatampur Bazaar',
        area: 'Main Market',
        city: 'Kanpur Nagar',
        pincode: '209206',
        lat: mockAddress.lat,
        lng: mockAddress.lng,
      },
      couponCode: 'GROCERY50',
      notes: 'Leave at door, do not call',
      storeId: 'hub-209206',
    }

    const parseResult = CreateOrderInputSchema.safeParse(orderPayload)
    assert.equal(parseResult.success, true, 'Order payload must pass strict schema validation')

    // Step 8: Order Status Lifecycle Progression
    const statuses = ['PENDING', 'CONFIRMED', 'PREPARING', 'PACKED', 'OUT_FOR_DELIVERY', 'DELIVERED']
    for (const status of statuses) {
      const statusUpdate = UpdateOrderStatusSchema.safeParse({
        orderId: 'ord_test_cod_001',
        status,
      })
      assert.equal(statusUpdate.success, true, `Status ${status} transition must be valid`)
    }
  })

  test('E2E Flow 2: Online Payment (Pay-First-Order-Later) Pre-Order Verification', async () => {
    // Step 1: Cart below free-delivery threshold to verify base delivery charge
    const smallCart = [
      { product: mockGroceryProduct2, quantity: 4 }, // 27 * 4 = 108
    ]

    const pricingItems: PricingItem[] = [
      { product: { id: mockGroceryProduct2.id }, dbProduct: { price: mockGroceryProduct2.price }, quantity: 4 },
    ]
    const subtotal = calculateItemSubtotal(pricingItems)
    assert.equal(subtotal, 108)

    // Delivery calculation for address ~600m away (Zone 1: ₹25 fee)
    const deliveryParams: DeliveryCalculationParams = {
      deliveryMethod: 'DELIVERY',
      isB2B: false,
      resolvedLat: mockAddress.lat!,
      resolvedLng: mockAddress.lng!,
      storeLat: DEFAULT_STORE_LAT,
      storeLng: DEFAULT_STORE_LNG,
      maxRadiusKm: 5.0,
      storeDisplayName: 'FastKirana Hub',
      settingsMap: baseSettings,
      groceryItems: [{ id: mockGroceryProduct2.id }],
      grocerySubtotal: subtotal,
      restaurantData: [],
      combinedSubtotal: subtotal,
    }
    const deliveryResult = await calculateOrderDeliveryFees(deliveryParams)
    assert.equal(deliveryResult.groceryDeliveryFee, 25, 'Subtotal under threshold pays base delivery fee')

    // Premium packaging (+₹15, waives standard handling fee)
    const packagingFee = 15
    const totalAmount = subtotal + deliveryResult.groceryDeliveryFee + packagingFee
    assert.equal(totalAmount, 108 + 25 + 15) // 148

    // Step 2: Online payment order payload creation
    const onlineOrderPayload = {
      items: [
        {
          productId: mockGroceryProduct2.id,
          name: mockGroceryProduct2.name,
          price: mockGroceryProduct2.price,
          quantity: 4,
        },
      ],
      paymentMethod: 'ONLINE' as const,
      address: {
        houseNo: 'Ward 4',
        area: 'Near Post Office',
        city: 'Ghatampur',
        pincode: '209206',
        lat: mockAddress.lat,
        lng: mockAddress.lng,
      },
      storeId: 'hub-209206',
    }

    const validation = CreateOrderInputSchema.safeParse(onlineOrderPayload)
    assert.equal(validation.success, true)

    // Step 3: Cashfree / Gateway Payment Lifecycle
    // Pre-order session created with status 'PENDING'
    // Once webhook/callback returns 'SUCCESS', status transitions to 'CONFIRMED' with paymentStatus 'PAID'
    const confirmUpdate = UpdateOrderStatusSchema.safeParse({
      orderId: 'ord_online_session_999',
      status: 'CONFIRMED',
    })
    assert.equal(confirmUpdate.success, true)
  })

  test('E2E Flow 3: Store Pickup (Self-Pickup) Zero Delivery Fee Checkout', async () => {
    // Pickup order allows null address in eligibility
    const cartItems = [{ product: mockGroceryProduct1, quantity: 2 }]
    const eligibility = await validateCheckoutEligibility({
      items: cartItems,
      addresses: [],
      selectedAddressId: undefined,
      deliveryMethod: 'PICKUP',
      settings: { grocery_mart_open: 'true' },
    })
    assert.equal(eligibility.valid, true)
    assert.equal(eligibility.finalAddressId, 'STORE_PICKUP')

    // Delivery calculation must yield exactly 0 fee
    const deliveryResult = await calculateOrderDeliveryFees({
      deliveryMethod: 'PICKUP',
      isB2B: false,
      resolvedLat: null,
      resolvedLng: null,
      storeLat: DEFAULT_STORE_LAT,
      storeLng: DEFAULT_STORE_LNG,
      maxRadiusKm: 5.0,
      storeDisplayName: 'FastKirana Hub',
      settingsMap: baseSettings,
      groceryItems: [{ id: mockGroceryProduct1.id }],
      grocerySubtotal: 490,
      restaurantData: [],
      combinedSubtotal: 490,
    })
    assert.equal(deliveryResult.groceryDeliveryFee, 0)
    assert.equal(deliveryResult.hubSurgeFee, 0)
    assert.equal(deliveryResult.error, undefined)
    assert.deepEqual(deliveryResult.restaurantFees, {})
  })
})
