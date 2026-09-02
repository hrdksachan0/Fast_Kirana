/**
 * Runtime input validation for all API routes using Zod schemas.
 *
 * Usage:
 *   import { validateBody } from '@/lib/validation'
 *   const result = await validateBody(request, orderSchema)
 *   if (!result.success) return result.error
 *   const data = result.data
 */

import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'

// ── Reusable primitive schemas ──────────────────────────────────────

export const indianPhone = z
  .string()
  .regex(/^[6-9]\d{9}$/, 'Invalid Indian mobile number (10 digits starting with 6-9)')

export const emailSchema = z.string().email('Invalid email address')

export const positiveInt = z.coerce.number().int().positive('Must be a positive integer')

export const nonNegativeInt = z.coerce.number().int().nonnegative('Must be a non-negative integer')

export const priceSchema = z.coerce.number().nonnegative('Price cannot be negative')

// ── Auth Schemas ────────────────────────────────────────────────────

export const signupSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: emailSchema,
  password: z.string().min(6, 'Password must be at least 6 characters').max(128),
  phone: z.string().optional().default(''),
})

export const loginSchema = z.object({
  email: z.string().optional(),
  password: z.string().optional(),
  otp: z.string().optional(),
  name: z.string().optional(),
  phone: z.string().optional(),
})

// ── Address Schemas ─────────────────────────────────────────────────

export const createAddressSchema = z.object({
  label: z.string().min(1, 'Label is required').max(30),
  houseNo: z.string().min(1, 'House number is required').max(100),
  street: z.string().min(1, 'Street is required').max(200),
  area: z.string().min(1, 'Area is required').max(200),
  city: z.string().min(1, 'City is required').max(100),
  pincode: z.string().regex(/^\d{6}$/, 'Pincode must be 6 digits'),
  phone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid 10-digit mobile number'),
  isDefault: z.union([z.boolean(), z.string()]).optional(),
  lat: z.union([z.number(), z.string()]).optional(),
  lng: z.union([z.number(), z.string()]).optional(),
})

export const updateAddressSchema = createAddressSchema.extend({
  id: z.string().min(1, 'Address ID is required'),
})

export const patchAddressSchema = z.object({
  id: z.string().min(1, 'Address ID is required'),
  lat: z.union([z.number(), z.string()]).optional(),
  lng: z.union([z.number(), z.string()]).optional(),
})

export const deleteAddressSchema = z.object({
  id: z.string().min(1, 'Address ID is required'),
})

// ── Cart Schemas ────────────────────────────────────────────────────

export const syncCartSchema = z.object({
  items: z.array(z.object({
    productId: z.string().min(1),
    quantity: z.union([z.number(), z.string()]).optional(),
    selectedVariant: z.string().nullable().optional(),
    notes: z.string().nullable().optional(),
  })).optional().default([]),
})

export const addToCartSchema = z.object({
  productId: z.string().min(1, 'Product ID is required'),
  quantity: z.coerce.number().int().positive().optional().default(1),
  selectedVariant: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
})

// ── Product Schemas ─────────────────────────────────────────────────

export const createProductSchema = z.object({
  name: z.string().min(1, 'Product name is required').max(200),
  description: z.string().nullable().optional().default(''),
  imageUrl: z.string().nullable().optional().default('📦'),
  categoryId: z.string().nullable().optional(),
  restaurantId: z.string().nullable().optional(),
  mrp: z.coerce.number().nonnegative(),
  price: z.coerce.number().nonnegative(),
  unit: z.string().nullable().optional().default(''),
  stock: z.coerce.number().int().nonnegative().optional().default(0),
  isAvailable: z.union([z.boolean(), z.string()]).nullable().optional(),
  tags: z.union([z.array(z.string()), z.string()]).nullable().optional().default([]),
  minStock: z.coerce.number().int().nonnegative().nullable().optional().default(10),
  expiryDate: z.string().nullable().optional(),
  costPrice: z.coerce.number().nonnegative().nullable().optional().default(0),
  variants: z.union([z.array(z.any()), z.string()]).nullable().optional(),
  location: z.string().nullable().optional(),
  isFlashDeal: z.union([z.boolean(), z.string()]).nullable().optional(),
  isTopPick: z.union([z.boolean(), z.string()]).nullable().optional(),
  isBestSeller: z.union([z.boolean(), z.string()]).nullable().optional(),
  sortOrder: z.coerce.number().int().nonnegative().nullable().optional().default(0),
  barcode: z.string().nullable().optional(),
})

// ── Coupon Schema ───────────────────────────────────────────────────

export const validateCouponSchema = z.object({
  code: z.string().min(1, 'Coupon code is required'),
  subtotal: z.coerce.number().nonnegative('Subtotal must be a positive number'),
  items: z.array(z.object({
    productId: z.string().nullable().optional(),
    categoryId: z.string().nullable().optional(),
    restaurantId: z.string().nullable().optional(),
    price: z.coerce.number().nonnegative(),
    quantity: z.coerce.number().int().positive(),
  })).optional().default([]),
})

// ── Order Schema ────────────────────────────────────────────────────

export const createOrderSchema = z.object({
  // Mobile app user resolution (optional, only used when no NextAuth session)
  phone: z.string().nullable().optional(),
  email: z.string().nullable().optional(),
  userId: z.string().nullable().optional(),
  customerPhone: z.string().nullable().optional(),
  userName: z.string().nullable().optional(),
  customerName: z.string().nullable().optional(),

  // Core order fields
  addressId: z.string().nullable().optional(),
  paymentMethod: z.enum(['COD', 'RAZORPAY', 'UPI', 'CARD', 'WALLET', 'ONLINE']),
  items: z.array(z.object({
    product: z.object({
      id: z.string().min(1),
      name: z.string().optional(),
      price: z.coerce.number().nonnegative().optional().default(0),
      slug: z.string().optional(),
      imageUrl: z.string().optional(),
      restaurantId: z.string().nullable().optional(),
    }),
    quantity: z.coerce.number().int().positive().optional().default(1),
    selectedVariant: z.string().nullable().optional(),
  })).min(1, 'At least one item is required'),
  couponCode: z.string().nullable().optional().default(''),
  deliveryMethod: z.enum(['DELIVERY', 'PICKUP']).optional().default('DELIVERY'),
  isB2B: z.union([z.boolean(), z.string()]).nullable().optional().default(false),
  scheduledSlot: z.string().nullable().optional().default('INSTANT'),
  shopName: z.string().nullable().optional(),
  shopPhone: z.string().nullable().optional(),
  storeId: z.string().nullable().optional(),
  packagingOption: z.enum(['NORMAL', 'PREMIUM']).optional().default('NORMAL'),
  packagingFee: z.coerce.number().nonnegative().optional().default(0),
  // Payment verification (webhook callback)
  paymentStatus: z.string().nullable().optional(),
  paymentId: z.string().nullable().optional(),
  razorpayPaymentId: z.string().nullable().optional(),
  razorpay_payment_id: z.string().nullable().optional(),
  customerAddress: z.string().nullable().optional(),
})

// ── Payment Schema ──────────────────────────────────────────────────

export const createRazorpayOrderSchema = z.object({
  orderId: z.string().nullable().optional(),
  amount: z.coerce.number().positive('Amount must be greater than 0').optional(),
})

// ── Validate-Cart Schema ────────────────────────────────────────────

export const validateCartSchema = z.object({
  items: z.array(z.object({
    product: z.object({
      id: z.string().min(1),
      name: z.string().optional(),
      price: z.coerce.number().nonnegative(),
      mrp: z.coerce.number().nonnegative().optional(),
      restaurantId: z.string().nullable().optional(),
    }),
    quantity: z.coerce.number().int().positive(),
  })).min(1, 'Cart items are required'),
})

// ── Generic Validation Helper ───────────────────────────────────────

export async function validateBody<T extends z.ZodType>(
  request: NextRequest,
  schema: T,
): Promise<{ success: true; data: z.infer<T> } | { success: false; error: NextResponse }> {
  let body: unknown
  try {
    body = await request.json()
  } catch {
    return {
      success: false as const,
      error: NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 }),
    }
  }

  const result = schema.safeParse(body)
  if (!result.success) {
    const messages = result.error.issues.map((i) => {
      const field = i.path.join('.')
      return field ? `${field}: ${i.message}` : i.message
    }).join(', ')
    return {
      success: false as const,
      error: NextResponse.json({ error: messages }, { status: 400 }),
    }
  }

  return { success: true, data: result.data }
}

export async function validateBodyLegacy<T extends z.ZodType>(
  request: Request,
  schema: T,
): Promise<{ success: true; data: z.infer<T> } | { success: false; error: NextResponse }> {
  let body: unknown
  try {
    body = await request.json()
  } catch {
    return {
      success: false as const,
      error: NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 }),
    }
  }

  const result = schema.safeParse(body)
  if (!result.success) {
    const messages = result.error.issues.map((i) => i.message).join(', ')
    return {
      success: false as const,
      error: NextResponse.json({ error: messages }, { status: 400 }),
    }
  }

  return { success: true, data: result.data }
}
