import { z } from 'zod'

export const createDishSchema = z.object({
  name: z.string().trim().min(2, 'Name must be at least 2 characters').max(150, 'Name is too long'),
  price: z.coerce.number().positive('Selling price must be greater than 0'),
  mrp: z.coerce.number().positive('MRP must be greater than 0').optional(),
  unit: z.string().trim().default('1 Serving'),
  stock: z.coerce.number().int().nonnegative().default(999),
  description: z.string().trim().nullable().optional(),
  imageUrl: z.string().trim().nullable().optional(),
  categoryId: z.string().trim().nullable().optional(),
  restaurantId: z.string().trim().optional(),
  variants: z.any().optional(),
  foodType: z.string().trim().optional(),
  prepTime: z.union([z.number(), z.string()]).optional(),
  sectionId: z.string().trim().optional(),
  menuSectionId: z.string().trim().optional(),
  availableStartTime: z.string().nullable().optional(),
  availableEndTime: z.string().nullable().optional(),
  tags: z.array(z.string()).optional(),
}).refine(
  (data) => !data.mrp || data.price <= data.mrp,
  {
    message: 'Selling price cannot exceed MRP',
    path: ['price'],
  }
)

export type CreateDishSchemaInput = z.infer<typeof createDishSchema>

export const updateOrderActionSchema = z.object({
  orderId: z.string().trim().min(1, 'Order ID is required'),
  action: z.enum(['accept', 'pack', 'reject'], {
    message: 'Action must be one of: accept, pack, reject',
  }),
  restaurantId: z.string().trim().optional(),
})

export type UpdateOrderActionInput = z.infer<typeof updateOrderActionSchema>
