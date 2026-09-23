import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import {
  CreateOrderInputSchema,
  UpdateOrderStatusSchema,
} from '@/lib/validations/order'

describe('Order Zod Validation Schemas', () => {
  const validAddress = {
    houseNo: 'Flat 402, Shanti Niwas',
    street: 'Station Road',
    area: 'Ghatampur Market',
    city: 'Kanpur Nagar',
    pincode: '209206',
    lat: 26.1554,
    lng: 80.1633,
  }

  const validItem = {
    productId: 'prod_123',
    name: 'Amul Taaza Milk 500ml',
    price: 27,
    quantity: 2,
    selectedVariant: null,
    notes: null,
  }

  it('validates a complete, correctly formatted order payload', () => {
    const payload = {
      items: [validItem],
      paymentMethod: 'COD',
      address: validAddress,
      notes: 'Please leave at the door',
      couponCode: 'FAST50',
      storeId: 'hub-209206',
    }

    const result = CreateOrderInputSchema.safeParse(payload)
    assert.strictEqual(result.success, true)
  })

  it('rejects an order payload with empty items array', () => {
    const payload = {
      items: [],
      paymentMethod: 'COD',
      address: validAddress,
    }

    const result = CreateOrderInputSchema.safeParse(payload)
    assert.strictEqual(result.success, false)
    if (!result.success) {
      assert.ok(
        result.error.issues.some((e) =>
          e.message.includes('At least one item is required')
        )
      )
    }
  })

  it('rejects an invalid Indian pincode (not 6 digits)', () => {
    const payload = {
      items: [validItem],
      paymentMethod: 'COD',
      address: {
        ...validAddress,
        pincode: '20920', // only 5 digits
      },
    }

    const result = CreateOrderInputSchema.safeParse(payload)
    assert.strictEqual(result.success, false)
    if (!result.success) {
      assert.ok(
        result.error.issues.some((e) =>
          e.message.includes('Pincode must be a 6-digit')
        )
      )
    }
  })

  it('rejects an unsupported payment method', () => {
    const payload = {
      items: [validItem],
      paymentMethod: 'BITCOIN',
      address: validAddress,
    }

    const result = CreateOrderInputSchema.safeParse(payload)
    assert.strictEqual(result.success, false)
  })

  it('validates order status transitions accurately', () => {
    const validUpdate = {
      orderId: 'ord_9999',
      status: 'PREPARING',
      cancellationReason: null,
    }
    const result = UpdateOrderStatusSchema.safeParse(validUpdate)
    assert.strictEqual(result.success, true)
  })

  it('rejects invalid order status values', () => {
    const invalidUpdate = {
      orderId: 'ord_9999',
      status: 'COMPLETED_UNKNOWN',
    }
    const result = UpdateOrderStatusSchema.safeParse(invalidUpdate)
    assert.strictEqual(result.success, false)
  })
})
