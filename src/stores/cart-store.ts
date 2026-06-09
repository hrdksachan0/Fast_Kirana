import { create } from 'zustand'
import { persist } from 'zustand/middleware'

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
  category?: {
    id: string
    name: string
    slug: string
    imageUrl: string | null
    parentId: string | null
    sortOrder: number
  } | null
}

export interface CartItem {
  product: CartProduct
  quantity: number
}

interface CartState {
  items: CartItem[]
  addItem: (product: CartProduct) => void
  removeItem: (productId: string) => void
  updateQuantity: (productId: string, quantity: number) => void
  clearCart: () => void
  getItemQuantity: (productId: string) => number
  getTotalItems: () => number
  getSubtotal: () => number
  getMrpTotal: () => number
  getSavings: () => number
}

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],

      addItem: (product: CartProduct) => {
        if (product.stock <= 0) return
        set((state) => {
          const existing = state.items.find((item) => item.product.id === product.id)
          if (existing) {
            return {
              items: state.items.map((item) =>
                item.product.id === product.id
                  ? { ...item, quantity: Math.min(item.quantity + 1, item.product.stock) }
                  : item
              ),
            }
          }
          return { items: [...state.items, { product, quantity: 1 }] }
        })
      },

      removeItem: (productId: string) => {
        set((state) => ({
          items: state.items.filter((item) => item.product.id !== productId),
        }))
      },

      updateQuantity: (productId: string, quantity: number) => {
        set((state) => {
          if (quantity <= 0) {
            return { items: state.items.filter((item) => item.product.id !== productId) }
          }
          return {
            items: state.items.map((item) =>
              item.product.id === productId
                ? { ...item, quantity: Math.min(quantity, item.product.stock) }
                : item
            ),
          }
        })
      },

      clearCart: () => set({ items: [] }),

      getItemQuantity: (productId: string) => {
        const item = get().items.find((i) => i.product.id === productId)
        return item?.quantity || 0
      },

      getTotalItems: () => {
        return get().items.reduce((sum, item) => sum + item.quantity, 0)
      },

      getSubtotal: () => {
        return get().items.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
      },

      getMrpTotal: () => {
        return get().items.reduce((sum, item) => sum + item.product.mrp * item.quantity, 0)
      },

      getSavings: () => {
        const state = get()
        return state.getMrpTotal() - state.getSubtotal()
      },
    }),
    {
      name: 'fastkirana-cart',
    }
  )
)
