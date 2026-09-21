import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { isCafeProduct, getProductLimit } from '@/lib/utils'

export interface CartProduct {
  id: string
  name: string
  slug: string
  imageUrl: string | null
  mrp: number
  price: number
  discount: number
  unit: string
  stock: number
  isAvailable?: boolean
  tags?: string[]
  restaurantId?: string | null
  restaurantName?: string | null
  menuSection?: string | null
  selectedVariant?: string | null
  variant?: string | null
  restaurant?: {
    id: string
    name: string
    slug: string
  } | null
  category?: {
    id: string
    name: string
    slug: string
    imageUrl: string | null
    parentId: string | null
    sortOrder: number
  } | null
  selectedAddons?: { name: string; price: number }[]
}

export interface CartItem {
  product: CartProduct
  quantity: number
  notes?: string
}

interface CartState {
  items: CartItem[]
  addItem: (product: CartProduct) => void
  removeItem: (productId: string) => void
  updateQuantity: (productId: string, quantity: number) => void
  clearCart: () => void
  clearRestaurantItems: () => void
  getItemQuantity: (productId: string) => number
  getTotalItems: () => number
  getSubtotal: () => number
  getMrpTotal: () => number
  getSavings: () => number
  updateCartProduct: (productId: string, updates: Partial<CartProduct>) => void
  updateItemNotes: (productId: string, notes: string) => void
  appliedCouponCode: string | null
  setAppliedCouponCode: (code: string | null) => void
}

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],
      appliedCouponCode: null,
      setAppliedCouponCode: (code) => set({ appliedCouponCode: code }),

      addItem: (product: CartProduct) => {
        if (!product || product.stock <= 0 || product.isAvailable === false) return
        set((state) => {
          const existing = state.items.find((item) => item?.product?.id === product.id)
          if (existing) {
            const maxAllowed = product.stock > 0 ? product.stock : 9999
            return {
              items: state.items.map((item) =>
                item?.product?.id === product.id
                  ? { ...item, quantity: Math.min(item.quantity + 1, maxAllowed) }
                  : item
              ),
            }
          }
          return { items: [...state.items, { product, quantity: 1 }] }
        })
      },

      removeItem: (productId: string) => {
        set((state) => ({
          items: state.items.filter((item) => item?.product?.id !== productId),
        }))
      },

      updateQuantity: (productId: string, quantity: number) => {
        set((state) => {
          if (quantity <= 0) {
            return { items: state.items.filter((item) => item?.product?.id !== productId) }
          }
          return {
            items: state.items.map((item) => {
              if (item?.product?.id === productId) {
                const maxAllowed = item.product.stock > 0 ? item.product.stock : 9999
                return { ...item, quantity: Math.min(quantity, maxAllowed) }
              }
              return item
            }),
          }
        })
      },

      clearCart: () => set({ items: [], appliedCouponCode: null }),

      clearRestaurantItems: () => {
        set((state) => ({
          items: state.items.filter((item) => item?.product && !isCafeProduct(item.product)),
        }))
      },

      getItemQuantity: (productId: string) => {
        const item = get().items.find((i) => i?.product?.id === productId)
        return item?.quantity || 0
      },

      getTotalItems: () => {
        return get().items.reduce((sum, item) => sum + (Number(item?.quantity) || 0), 0)
      },

      getSubtotal: () => {
        return get().items.reduce(
          (sum, item) => sum + (Number(item?.product?.price) || 0) * (Number(item?.quantity) || 0),
          0
        )
      },

      getMrpTotal: () => {
        return get().items.reduce((sum, item) => {
          const mrp = Number(item?.product?.mrp) || Number(item?.product?.price) || 0
          return sum + mrp * (Number(item?.quantity) || 0)
        }, 0)
      },

      getSavings: () => {
        const state = get()
        return Math.max(0, state.getMrpTotal() - state.getSubtotal())
      },
      updateCartProduct: (productId: string, updates: Partial<CartProduct>) => {
        set((state) => ({
          items: state.items
            .map((item) => {
              if (item.product.id !== productId) return item
              const newProduct = { ...item.product, ...updates }
              let newQty = item.quantity
              if (updates.stock !== undefined && updates.stock > 0 && newQty > updates.stock) {
                newQty = updates.stock
              }
              return {
                product: newProduct,
                quantity: newQty,
              }
            })
            .filter((item) => {
              if (item.product.id === productId) {
                return item.quantity > 0 && updates.isAvailable !== false
              }
              return item.quantity > 0
            }),
        }))
      },
      updateItemNotes: (productId: string, notes: string) => {
        set((state) => ({
          items: state.items.map((item) =>
            item.product.id === productId ? { ...item, notes } : item
          ),
        }))
      },
    }),
    {
      name: 'fastkirana-cart',
    }
  )
)
