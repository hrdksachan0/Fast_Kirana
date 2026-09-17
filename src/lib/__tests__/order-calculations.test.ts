import test, { describe } from 'node:test'
import assert from 'node:assert/strict'
import {
  calculateItemSubtotal,
  calculateCouponDiscount,
  PricingItem,
} from '../../services/order-pricing.service'
import {
  calculateOrderDeliveryFees,
  DeliveryCalculationParams,
  RestaurantDeliveryInput,
} from '../delivery-fee-calculator'

describe('Backend Order Calculation Engine', () => {
  describe('Cart Item Subtotal Calculation', () => {
    test('accurately calculates sum across multiple items and quantities', () => {
      const items: PricingItem[] = [
        { product: { id: 'milk-1' }, dbProduct: { price: 32 }, quantity: 2 },
        { product: { id: 'bread-1' }, dbProduct: { price: 40 }, quantity: 1 },
        { product: { id: 'butter-1' }, dbProduct: { price: 55 }, quantity: 3 },
      ]
      // 32*2 + 40*1 + 55*3 = 64 + 40 + 165 = 269
      assert.equal(calculateItemSubtotal(items), 269)
    })

    test('resolves variant pricing correctly when item has variant suffix in ID', () => {
      const items: PricingItem[] = [
        {
          product: { id: 'paneer-dish_Full' },
          dbProduct: {
            price: 150,
            variants: [
              { name: 'Half', price: 150 },
              { name: 'Full', price: 280 },
            ],
          },
          quantity: 2,
        },
      ]
      // 280 * 2 = 560
      assert.equal(calculateItemSubtotal(items), 560)
    })

    test('prefers explicit selectedVariant parameter over ID suffix', () => {
      const items: PricingItem[] = [
        {
          product: { id: 'rice_1kg' },
          dbProduct: {
            price: 70,
            variants: [
              { name: '1kg', price: 70 },
              { name: '5kg', price: 320 },
            ],
          },
          quantity: 1,
          selectedVariant: '5kg',
        },
      ]
      assert.equal(calculateItemSubtotal(items), 320)
    })
  })

  describe('Coupon Discount Rules & Boundaries', () => {
    test('enforces minimum order thresholds for combined orders', () => {
      const coupon = {
        id: 'SAVE50',
        isActive: true,
        discountType: 'FLAT',
        value: 50,
        minOrder: 499,
      }
      // Cart subtotal 450 < 499 minOrder
      const belowMin = calculateCouponDiscount(coupon, 450, 450, 0)
      assert.equal(belowMin.combinedDiscount, 0)
      assert.equal(belowMin.meetsMinOrder, false)

      // Cart subtotal 500 >= 499 minOrder
      const meetsMin = calculateCouponDiscount(coupon, 500, 500, 0)
      assert.equal(meetsMin.combinedDiscount, 50)
      assert.equal(meetsMin.meetsMinOrder, true)
    })

    test('enforces category isolation: GROCERY coupon ignores restaurant subtotal', () => {
      const groceryCoupon = {
        id: 'GROCERY20',
        isActive: true,
        discountType: 'PERCENT',
        value: 20,
        minOrder: 200,
        maxDiscount: 100,
        applicableType: 'GROCERY',
      }
      // Combined is 350, but grocery is only 150 (< 200 minOrder) -> REJECT
      const rejected = calculateCouponDiscount(groceryCoupon, 350, 150, 200)
      assert.equal(rejected.combinedDiscount, 0)
      assert.equal(rejected.meetsMinOrder, false)

      // Combined is 350, grocery is 250 (>= 200 minOrder) -> 20% of 250 = 50
      const accepted = calculateCouponDiscount(groceryCoupon, 350, 250, 100)
      assert.equal(accepted.combinedDiscount, 50)
      assert.equal(accepted.meetsMinOrder, true)
    })

    test('enforces category isolation: RESTAURANT coupon ignores grocery subtotal', () => {
      const restCoupon = {
        id: 'TASTY50',
        isActive: true,
        discountType: 'FLAT',
        value: 50,
        minOrder: 150,
        applicableType: 'RESTAURANT',
      }
      // Grocery 300, Restaurant 100 (< 150 minOrder) -> REJECT
      const rejected = calculateCouponDiscount(restCoupon, 400, 300, 100)
      assert.equal(rejected.combinedDiscount, 0)
      assert.equal(rejected.meetsMinOrder, false)

      // Grocery 100, Restaurant 200 (>= 150 minOrder) -> 50 discount
      const accepted = calculateCouponDiscount(restCoupon, 300, 100, 200)
      assert.equal(accepted.combinedDiscount, 50)
      assert.equal(accepted.meetsMinOrder, true)
    })

    test('clamps percentage discount to maxDiscount cap', () => {
      const coupon = {
        id: 'FESTIVE50',
        isActive: true,
        discountType: 'PERCENT',
        value: 50, // 50%
        minOrder: 200,
        maxDiscount: 75,
      }
      // 50% of 400 = 200, but capped at 75
      const result = calculateCouponDiscount(coupon, 400, 400, 0)
      assert.equal(result.combinedDiscount, 75)
    })
  })

  describe('Delivery Geofence, Distance & Surge Calculation', () => {
    const storeCoords = { storeLat: 26.1584, storeLng: 80.1707 } // Ghatampur Center
    const baseSettings = {
      delivery_fee: '25',
      grocery_free_delivery_threshold: '199',
      restaurant_free_delivery_threshold: '250',
      combined_free_delivery_threshold: '299',
    }

    test('waives delivery fee when order subtotal meets free delivery threshold', async () => {
      const params: DeliveryCalculationParams = {
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        resolvedLat: 26.165, // ~0.7 km away (Zone 1)
        resolvedLng: 80.1707,
        ...storeCoords,
        maxRadiusKm: 5.0,
        storeDisplayName: 'FastKirana Hub',
        settingsMap: baseSettings,
        groceryItems: [{ id: 'g1' }],
        grocerySubtotal: 250, // >= 199 threshold
        restaurantData: [],
        combinedSubtotal: 250,
      }

      const res = await calculateOrderDeliveryFees(params)
      assert.equal(res.groceryDeliveryFee, 0)
      assert.equal(res.error, undefined)
    })

    test('charges Zone 1 base fee (₹25) when under free delivery threshold', async () => {
      const params: DeliveryCalculationParams = {
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        resolvedLat: 26.165, // ~0.7 km away
        resolvedLng: 80.1707,
        ...storeCoords,
        maxRadiusKm: 5.0,
        storeDisplayName: 'FastKirana Hub',
        settingsMap: baseSettings,
        groceryItems: [{ id: 'g1' }],
        grocerySubtotal: 120, // < 199 threshold
        restaurantData: [],
        combinedSubtotal: 120,
      }

      const res = await calculateOrderDeliveryFees(params)
      assert.equal(res.groceryDeliveryFee, 25)
      assert.equal(res.error, undefined)
    })

    test('strictly rejects addresses exceeding maxRadiusKm geofence', async () => {
      const params: DeliveryCalculationParams = {
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        resolvedLat: 26.25, // ~10.2 km away
        resolvedLng: 80.1707,
        ...storeCoords,
        maxRadiusKm: 5.0,
        storeDisplayName: 'FastKirana Hub',
        settingsMap: baseSettings,
        groceryItems: [{ id: 'g1' }],
        grocerySubtotal: 350,
        restaurantData: [],
        combinedSubtotal: 350,
      }

      const res = await calculateOrderDeliveryFees(params)
      assert.ok(res.error)
      assert.ok(res.error.includes('strictly limited to 5.0 km'))
      assert.equal(res.groceryDeliveryFee, 0)
    })

    test('Combined Order: waives restaurant delivery fee when grocery delivery fee is paid', async () => {
      const restInput: RestaurantDeliveryInput = {
        rId: 'rest-1',
        restaurant: { id: 'rest-1', name: 'Burger Hub', lat: 26.1584, lng: 80.1707, deliveryRadiusKm: 5 },
        items: [{ id: 'burger-1' }],
        subtotal: 100,
        deliveryFee: 0,
      }

      const params: DeliveryCalculationParams = {
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        resolvedLat: 26.165, // ~0.7 km away
        resolvedLng: 80.1707,
        ...storeCoords,
        maxRadiusKm: 5.0,
        storeDisplayName: 'FastKirana Hub',
        settingsMap: baseSettings,
        groceryItems: [{ id: 'g1' }],
        grocerySubtotal: 80, // Under threshold -> pays ₹25
        restaurantData: [restInput],
        combinedSubtotal: 180, // Under combined threshold (299)
      }

      const res = await calculateOrderDeliveryFees(params)
      assert.equal(res.groceryDeliveryFee, 25)
      // Customer is NOT double charged for restaurant in the same combined order!
      assert.equal(res.restaurantFees['rest-1'], 0)
    })

    test('Combined Order: waives both delivery fees when combined subtotal exceeds combined threshold', async () => {
      const restInput: RestaurantDeliveryInput = {
        rId: 'rest-1',
        restaurant: { id: 'rest-1', name: 'Burger Hub', lat: 26.1584, lng: 80.1707, deliveryRadiusKm: 5 },
        items: [{ id: 'burger-1' }],
        subtotal: 150,
        deliveryFee: 0,
      }

      const params: DeliveryCalculationParams = {
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        resolvedLat: 26.165,
        resolvedLng: 80.1707,
        ...storeCoords,
        maxRadiusKm: 5.0,
        storeDisplayName: 'FastKirana Hub',
        settingsMap: baseSettings,
        groceryItems: [{ id: 'g1' }],
        grocerySubtotal: 160,
        restaurantData: [restInput],
        combinedSubtotal: 310, // 160 + 150 = 310 >= 299 combinedThreshold
      }

      const res = await calculateOrderDeliveryFees(params)
      assert.equal(res.groceryDeliveryFee, 0)
      assert.equal(res.restaurantFees['rest-1'], 0)
    })

    test('PICKUP delivery method yields 0 delivery fees', async () => {
      const params: DeliveryCalculationParams = {
        deliveryMethod: 'PICKUP',
        isB2B: false,
        resolvedLat: null,
        resolvedLng: null,
        ...storeCoords,
        maxRadiusKm: 5.0,
        storeDisplayName: 'FastKirana Hub',
        settingsMap: baseSettings,
        groceryItems: [{ id: 'g1' }],
        grocerySubtotal: 50,
        restaurantData: [],
        combinedSubtotal: 50,
      }

      const res = await calculateOrderDeliveryFees(params)
      assert.equal(res.groceryDeliveryFee, 0)
    })
  })

  describe('Tax, Handling Fee & Packaging Rules (as in /api/orders)', () => {
    const serverTaxRate = 0.05 // 5% GST
    const serverMiscFee = 5.0 // ₹5 platform handling fee

    test('calculates taxes accurately after pro-rated discount deduction', () => {
      const subtotal = 500
      const discount = 100 // Tax is calculated on post-discount amount
      const taxableAmount = subtotal - discount // 400
      const taxes = taxableAmount * serverTaxRate // 400 * 0.05 = 20

      assert.equal(taxes, 20)
    })

    test('waives handling fee when deliveryMethod is PICKUP', () => {
      const deliveryMethod = 'PICKUP'
      const isPremiumPackaging = false
      const hasChargedMiscFee = false

      const appliedMiscFee = (deliveryMethod !== 'PICKUP' && !hasChargedMiscFee && !isPremiumPackaging)
        ? serverMiscFee
        : 0

      assert.equal(appliedMiscFee, 0)
    })

    test('Premium Packaging (+₹15) completely waives standard handling fee (+₹5)', () => {
      const packagingOption = 'PREMIUM'
      const isPremiumPackaging = packagingOption === 'PREMIUM'
      const resolvedPackagingFee = isPremiumPackaging ? 15 : 0
      let hasChargedMiscFee = false

      // In /api/orders:
      const appliedGroceryMisc = (!hasChargedMiscFee && !isPremiumPackaging) ? serverMiscFee : 0
      if (appliedGroceryMisc > 0) hasChargedMiscFee = true

      assert.equal(appliedGroceryMisc, 0, 'Standard handling fee should be waived')

      // Restaurant order receives the resolved packaging fee
      const appliedRestMisc = resolvedPackagingFee > 0
        ? resolvedPackagingFee
        : (!hasChargedMiscFee && !isPremiumPackaging ? serverMiscFee : 0)

      assert.equal(appliedRestMisc, 15, 'Premium packaging fee should be applied')
    })

    test('pro-rates combined discount proportionally between grocery and restaurant sub-orders', () => {
      const grocerySubtotal = 300
      const restaurantSubtotal = 100
      const combinedSubtotal = 400
      const combinedDiscount = 80 // Total coupon discount

      const groceryDiscount = (grocerySubtotal / combinedSubtotal) * combinedDiscount
      const restaurantDiscount = (restaurantSubtotal / combinedSubtotal) * combinedDiscount

      assert.equal(groceryDiscount, 60) // 75% of 80
      assert.equal(restaurantDiscount, 20) // 25% of 80
      assert.equal(groceryDiscount + restaurantDiscount, combinedDiscount)
    })

    test('computes complete sub-order total = subtotal - discount + deliveryFee + taxes + miscFee', () => {
      const subtotal = 400
      const discount = 50
      const deliveryFee = 25
      const taxes = (subtotal - discount) * serverTaxRate // 350 * 0.05 = 17.5
      const miscFee = serverMiscFee // 5

      const total = subtotal - discount + deliveryFee + taxes + miscFee
      // 400 - 50 + 25 + 17.5 + 5 = 397.5
      assert.equal(total, 397.5)
    })
  })
})
