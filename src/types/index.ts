export interface Product {
  id: string
  name: string
  slug: string
  description: string | null
  imageUrl: string | null
  categoryId: string
  mrp: number
  price: number
  discount: number
  unit: string
  stock: number
  isAvailable: boolean
  tags: string[]
  variants?: any[] | null
  minStock?: number
  category?: Category
  images?: ProductImage[]
  reviews?: Review[]
  isBestSeller?: boolean
  isFlashDeal?: boolean
  isTopPick?: boolean
  sortOrder?: number
  createdAt?: string
}

export interface Category {
  id: string
  name: string
  slug: string
  imageUrl: string | null
  parentId: string | null
  sortOrder: number
  _count?: { products: number }
}

export interface ProductImage {
  id: string
  productId: string
  url: string
  sortOrder: number
}

export interface CartItem {
  id: string
  productId: string
  quantity: number
  product: Product
  selectedVariant?: string | null
}

export interface Address {
  id: string
  userId: string
  label: string
  houseNo: string
  street: string
  area: string
  city: string
  pincode: string
  phone: string
  lat: number | null
  lng: number | null
  isDefault: boolean
}

export interface Order {
  id: string
  readableId?: number
  userId: string
  addressId: string
  status: string
  subtotal: number
  discount: number
  deliveryFee: number
  taxes: number
  miscFee: number
  total: number
  paymentMethod: string
  paymentStatus: string
  estimatedDelivery: string | null
  createdAt: string
  items: OrderItem[]
  address?: Address
  combinedId?: string | null
  isCombined?: boolean
  subOrders?: any[]
}

export interface OrderItem {
  id: string
  orderId: string
  productId: string
  name: string
  price: number
  quantity: number
  imageUrl: string | null
  selectedVariant?: string | null
}

export interface Review {
  id: string
  userId: string
  productId: string
  rating: number
  comment: string | null
  createdAt: string
  user?: { name: string; image: string | null }
}

export interface Coupon {
  id: string
  code: string
  discountType: 'FLAT' | 'PERCENT'
  value: number
  minOrder: number
  maxDiscount: number | null
}
