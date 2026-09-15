import test, { describe } from 'node:test'
import assert from 'node:assert/strict'
import { getDistanceKm, getDeliveryRules } from '../distance'
import {
  calculateItemSubtotal,
  calculateCouponDiscount,
  PricingItem,
} from '../../services/order-pricing.service'

describe('Core Pricing & Distance Utilities', () => {
  describe('getDistanceKm (Haversine Formula)', () => {
    test('returns 0 for identical coordinates', () => {
      const dist = getDistanceKm(26.1584, 80.1707, 26.1584, 80.1707)
      assert.equal(Math.round(dist), 0)
    })

    test('calculates correct approximate distance between two known points', () => {
      // Coordinates approx 1.1 km apart in Ghatampur
      const dist = getDistanceKm(26.1584, 80.1707, 26.1684, 80.1707)
      assert.ok(dist > 1.0 && dist < 1.3, `Expected ~1.11km, got ${dist}`)
    })
  })

  describe('getDeliveryRules', () => {
    test('Zone 1: <= 2.0 km', () => {
      const rules = getDeliveryRules(1.5)
      assert.equal(rules.isServiceable, true)
      assert.equal(rules.baseFee, 25)
      assert.equal(rules.deliveryFee, 25)
      assert.equal(rules.freeDeliveryThreshold, 199)
    })

    test('Zone 2: 2.0 - 3.0 km', () => {
      const rules = getDeliveryRules(2.5)
      assert.equal(rules.isServiceable, true)
      assert.equal(rules.baseFee, 35)
      assert.equal(rules.deliveryFee, 35)
      assert.equal(rules.freeDeliveryThreshold, 299)
    })

    test('Zone 3: 3.0 - 5.0 km', () => {
      const rules = getDeliveryRules(4.2)
      assert.equal(rules.isServiceable, true)
      assert.equal(rules.baseFee, 50)
      assert.equal(rules.deliveryFee, 50)
      assert.equal(rules.freeDeliveryThreshold, 399)
    })

    test('Outside Delivery Zone (> maxRadiusKm)', () => {
      const rules = getDeliveryRules(6.5, { maxRadiusKm: 5.0 })
      assert.equal(rules.isServiceable, false)
      assert.equal(rules.deliveryFee, 0)
    })

    test('Applies surge fee additively to base delivery fee', () => {
      const rules = getDeliveryRules(1.0, { surgeFee: 15, surgeReason: 'Heavy Rain' })
      assert.equal(rules.isServiceable, true)
      assert.equal(rules.baseFee, 25)
      assert.equal(rules.surgeFee, 15)
      assert.equal(rules.deliveryFee, 40)
      assert.equal(rules.surgeReason, 'Heavy Rain')
    })
  })

  describe('calculateItemSubtotal', () => {
    test('calculates subtotal for standard items', () => {
      const items: PricingItem[] = [
        {
          product: { id: 'prod-1' },
          dbProduct: { price: 100 },
          quantity: 2,
        },
        {
          product: { id: 'prod-2' },
          dbProduct: { price: 50 },
          quantity: 3,
        },
      ]
      const subtotal = calculateItemSubtotal(items)
      assert.equal(subtotal, 350)
    })

    test('calculates subtotal using variant price when variant is selected', () => {
      const items: PricingItem[] = [
        {
          product: { id: 'prod-1_Half' },
          dbProduct: {
            price: 200,
            variants: [
              { name: 'Half', price: 120 },
              { name: 'Full', price: 200 },
            ],
          },
          quantity: 2,
          selectedVariant: 'Half',
        },
      ]
      const subtotal = calculateItemSubtotal(items)
      assert.equal(subtotal, 240) // 120 * 2
    })

    test('falls back to base price if variant is not in list', () => {
      const items: PricingItem[] = [
        {
          product: { id: 'prod-1_Quarter' },
          dbProduct: {
            price: 200,
            variants: [{ name: 'Full', price: 200 }],
          },
          quantity: 1,
          selectedVariant: 'Quarter',
        },
      ]
      const subtotal = calculateItemSubtotal(items)
      assert.equal(subtotal, 200)
    })
  })

  describe('calculateCouponDiscount', () => {
    test('returns 0 for inactive coupon', () => {
      const coupon = { id: 'c1', isActive: false, discountType: 'FLAT', value: 50, minOrder: 100 }
      const res = calculateCouponDiscount(coupon, 200, 200, 0)
      assert.equal(res.combinedDiscount, 0)
      assert.equal(res.meetsMinOrder, false)
    })

    test('returns 0 when subtotal does not meet minOrder', () => {
      const coupon = { id: 'c1', isActive: true, discountType: 'FLAT', value: 50, minOrder: 300 }
      const res = calculateCouponDiscount(coupon, 250, 250, 0)
      assert.equal(res.combinedDiscount, 0)
      assert.equal(res.meetsMinOrder, false)
    })

    test('applies FLAT discount capped at eligible subtotal', () => {
      const coupon = { id: 'c1', isActive: true, discountType: 'FLAT', value: 50, minOrder: 100 }
      const res = calculateCouponDiscount(coupon, 200, 200, 0)
      assert.equal(res.combinedDiscount, 50)
      assert.equal(res.meetsMinOrder, true)

      // Capped if discount exceeds subtotal
      const bigCoupon = { id: 'c2', isActive: true, discountType: 'FLAT', value: 300, minOrder: 50 }
      const resCapped = calculateCouponDiscount(bigCoupon, 100, 100, 0)
      assert.equal(resCapped.combinedDiscount, 100)
    })

    test('applies PERCENT discount capped at maxDiscount', () => {
      const coupon = {
        id: 'c1',
        isActive: true,
        discountType: 'PERCENT',
        value: 20, // 20%
        minOrder: 100,
        maxDiscount: 50,
      }
      // 20% of 500 = 100, capped at 50
      const res = calculateCouponDiscount(coupon, 500, 500, 0)
      assert.equal(res.combinedDiscount, 50)
      assert.equal(res.meetsMinOrder, true)

      // 20% of 200 = 40 (< 50 max discount)
      const resUnder = calculateCouponDiscount(coupon, 200, 200, 0)
      assert.equal(resUnder.combinedDiscount, 40)
    })

    test('respects RESTAURANT applicableType restriction', () => {
      const coupon = {
        id: 'c1',
        isActive: true,
        discountType: 'PERCENT',
        value: 10,
        minOrder: 200,
        applicableType: 'RESTAURANT',
      }
      // Combined is 300, but restaurantSubtotal is only 100 -> does not meet minOrder
      const resFail = calculateCouponDiscount(coupon, 300, 200, 100)
      assert.equal(resFail.combinedDiscount, 0)
      assert.equal(resFail.meetsMinOrder, false)

      // Restaurant is 250 -> meets minOrder
      const resPass = calculateCouponDiscount(coupon, 350, 100, 250)
      assert.equal(resPass.combinedDiscount, 25) // 10% of 250
      assert.equal(resPass.meetsMinOrder, true)
    })
  })
})
