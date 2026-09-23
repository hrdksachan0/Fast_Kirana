import { z } from 'zod'

export const OrderItemSchema = z.object({
  productId: z.string().min(1, 'Product ID is required'),
  name: z.string().min(1, 'Product name is required'),
  price: z.number().nonnegative('Price cannot be negative'),
  quantity: z.number().int().positive('Quantity must be at least 1'),
  imageUrl: z.string().optional().nullable(),
  selectedVariant: z.string().optional().nullable(),
  notes: z.string().max(250).optional().nullable(),
})

export const DeliveryAddressInputSchema = z.object({
  houseNo: z.string().min(1, 'House/Flat number is required'),
  street: z.string().optional().nullable(),
  area: z.string().min(1, 'Area/Locality is required'),
  city: z.string().min(1, 'City is required'),
  pincode: z.string().regex(/^\d{6}$/, 'Pincode must be a 6-digit Indian PIN code'),
  lat: z.number().optional().nullable(),
  lng: z.number().optional().nullable(),
})

export const CreateOrderInputSchema = z.object({
  items: z.array(OrderItemSchema).min(1, 'At least one item is required to place an order'),
  paymentMethod: z.enum(['COD', 'ONLINE', 'RAZORPAY', 'CASHFREE', 'PAYTM', 'WALLET'], {
    message: 'Invalid payment method',
  }),
  address: DeliveryAddressInputSchema,
  notes: z.string().max(500).optional().nullable(),
  couponCode: z.string().max(30).optional().nullable(),
  storeId: z.string().optional().nullable(),
  isGift: z.boolean().optional(),
})

export const UpdateOrderStatusSchema = z.object({
  orderId: z.string().min(1, 'Order ID is required'),
  status: z.enum([
    'ADMIN_PENDING',
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'PACKED',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
    'CANCELLED',
  ]),
  cancellationReason: z.string().max(300).optional().nullable(),
})

export type OrderItemInput = z.infer<typeof OrderItemSchema>
export type DeliveryAddressInput = z.infer<typeof DeliveryAddressInputSchema>
export type CreateOrderInput = z.infer<typeof CreateOrderInputSchema>
export type UpdateOrderStatusInput = z.infer<typeof UpdateOrderStatusSchema>
