import test, { describe } from 'node:test'
import assert from 'node:assert/strict'
import {
  classifyItems,
  validateAddress,
  validateCheckoutEligibility,
  CartItemInput,
  Address,
  SettingsMap,
  DEFAULT_STORE_LAT,
  DEFAULT_STORE_LNG,
} from '../checkout'

describe('Checkout Validation & Logic Utilities', () => {
  describe('classifyItems', () => {
    test('identifies pure grocery carts', () => {
      const items: CartItemInput[] = [
        { product: { id: '1', name: 'Tata Salt', category: { slug: 'staples' }, tags: ['salt', 'cooking'] } },
        { product: { id: '2', name: 'Amul Milk', category: { slug: 'dairy' }, tags: ['milk', 'fresh'] } },
      ]
      const classification = classifyItems(items)
      assert.equal(classification.hasGrocery, true)
      assert.equal(classification.hasCafe, false)
      assert.equal(classification.hasRestaurant, false)
    })

    test('identifies restaurant items by restaurant category or tag', () => {
      const items: CartItemInput[] = [
        { product: { id: '3', name: 'Paneer Butter Masala', category: { slug: 'restaurant' }, tags: ['food', 'main-course'] } },
      ]
      const classification = classifyItems(items)
      assert.equal(classification.hasRestaurant, true)
      assert.equal(classification.hasGrocery, false)
    })

    test('identifies cafe items by cafe category, restaurantId or beverage tags', () => {
      const items: CartItemInput[] = [
        { product: { id: '4', name: 'Cold Coffee', category: { slug: 'beverages' }, tags: ['shakes', 'beverage'] } },
        { product: { id: '5', name: 'Brownie', restaurantId: 'rest_cafe_1', category: null } },
      ]
      const classification = classifyItems(items)
      assert.equal(classification.hasCafe, true)
      assert.equal(classification.hasGrocery, false)
    })

    test('identifies mixed cart items accurately', () => {
      const items: CartItemInput[] = [
        { product: { id: '1', name: 'Maggi', category: { slug: 'instant-food' } } },
        { product: { id: '3', name: 'Chicken Biryani', category: { slug: 'restaurant' } } },
      ]
      const classification = classifyItems(items)
      assert.equal(classification.hasGrocery, true)
      assert.equal(classification.hasRestaurant, true)
    })
  })

  describe('validateAddress', () => {
    const validAddress: Address = {
      id: 'addr_1',
      pincode: '209206',
      city: 'Ghatampur, Kanpur Nagar',
      phone: '9876543210',
      lat: DEFAULT_STORE_LAT,
      lng: DEFAULT_STORE_LNG,
    }

    test('approves valid address within service zone', () => {
      const result = validateAddress(validAddress, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, 5.0)
      assert.equal(result.valid, true)
      assert.equal(result.error, undefined)
    })

    test('rejects address with invalid phone number', () => {
      const invalidPhoneAddr: Address = { ...validAddress, phone: '123' }
      const result = validateAddress(invalidPhoneAddr, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, 5.0)
      assert.equal(result.valid, false)
      assert.ok(result.error?.includes('10-digit mobile number'))
    })

    test('rejects address outside delivery radius when lat/lng are present', () => {
      // Point ~10km away from store
      const farAddress: Address = {
        ...validAddress,
        lat: DEFAULT_STORE_LAT + 0.1,
        lng: DEFAULT_STORE_LNG + 0.1,
      }
      const result = validateAddress(farAddress, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, 2.0)
      assert.equal(result.valid, false)
      assert.ok(result.error?.includes('outside our delivery zone'))
    })
  })

  describe('validateCheckoutEligibility', () => {
    const mockGroceryItems: CartItemInput[] = [
      { product: { id: '1', name: 'Atta 5kg', category: { slug: 'staples' } } },
    ]

    const mockAddress: Address = {
      id: 'addr_10',
      pincode: '209206',
      city: 'Ghatampur',
      phone: '9876543210',
      lat: DEFAULT_STORE_LAT,
      lng: DEFAULT_STORE_LNG,
    }

    test('rejects delivery if no addresses are provided and none selected', async () => {
      const result = await validateCheckoutEligibility({
        items: mockGroceryItems,
        addresses: [],
        selectedAddressId: undefined,
        deliveryMethod: 'DELIVERY',
        settings: { grocery_mart_open: 'true' },
      })
      assert.equal(result.valid, false)
      assert.equal(result.error, 'Please select a delivery address')
    })

    test('allows pickup even without address', async () => {
      const result = await validateCheckoutEligibility({
        items: mockGroceryItems,
        addresses: [],
        selectedAddressId: undefined,
        deliveryMethod: 'PICKUP',
        settings: { grocery_mart_open: 'true' },
      })
      assert.equal(result.valid, true)
      assert.equal(result.finalAddressId, 'STORE_PICKUP')
    })

    test('blocks grocery checkout when grocery_mart_open is false', async () => {
      const result = await validateCheckoutEligibility({
        items: mockGroceryItems,
        addresses: [mockAddress],
        selectedAddressId: 'addr_10',
        deliveryMethod: 'DELIVERY',
        settings: { grocery_mart_open: 'false' },
      })
      assert.equal(result.valid, false)
      assert.ok(result.error?.includes('Grocery Mart is temporarily closed'))
    })

    test('allows checkout when grocery mart is open and address is valid', async () => {
      const result = await validateCheckoutEligibility({
        items: mockGroceryItems,
        addresses: [mockAddress],
        selectedAddressId: 'addr_10',
        deliveryMethod: 'DELIVERY',
        settings: { grocery_mart_open: 'true', delivery_radius: '5.0' },
      })
      assert.equal(result.valid, true)
      assert.equal(result.finalAddressId, 'addr_10')
    })
  })
})
