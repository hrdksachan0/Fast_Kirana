'use client'

import { Plus, Minus, ShoppingBag } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { Button } from '@/components/ui/button'
import { Product } from '@/types'
import { useUIStore } from '@/stores/ui-store'
import { isCafeProduct } from '@/lib/utils'
import { useRouter } from 'next/navigation'
import { triggerHaptic } from '@/lib/haptic'

interface ProductDetailActionsProps {
  product: Product
}

export function ProductDetailActions({ product }: ProductDetailActionsProps) {
  const router = useRouter()
  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const quantity = getItemQuantity(product.id)
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)

  const isCafe = isCafeProduct(product)
  const isStoreClosed = isCafe ? !cafeOpen : !groceryMartOpen

  const cartProduct = {
    id: product.id,
    name: product.name,
    slug: product.slug,
    imageUrl: product.imageUrl,
    mrp: product.mrp,
    price: product.price,
    discount: product.discount,
    unit: product.unit,
    stock: product.stock,
    category: product.category,
  }

  const handleAdd = () => {
    addItem(cartProduct)
  }

  const handleExpressBuy = () => {
    if (quantity === 0) {
      addItem(cartProduct)
    }
    triggerHaptic('success')
    router.push('/checkout')
  }

  return (
    <div className="flex flex-wrap items-center gap-3.5 w-full">
      <div className="flex-grow sm:flex-grow-0">
        {quantity === 0 ? (
          <Button
            onClick={handleAdd}
            disabled={product.stock <= 0 || isStoreClosed}
            className="w-full sm:w-auto h-12 px-8 bg-accent text-white font-extrabold hover:bg-accent-dark rounded-xl transition-all duration-200 shadow-md hover:shadow-lg flex items-center justify-center gap-2 text-base disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
          >
            {product.stock <= 0 ? (
              'Out of Stock'
            ) : isStoreClosed ? (
              isCafe ? 'Cafe Closed' : 'Mart Closed'
            ) : (
              <>
                Add to Cart
                <ShoppingBag className="h-5 w-5" />
              </>
            )}
          </Button>
        ) : (
          <div className="flex h-12 w-full sm:w-36 items-center justify-between rounded-xl bg-accent text-white font-extrabold shadow-md">
            <button
              onClick={() => updateQuantity(product.id, product.name, quantity - 1)}
              className="flex-grow h-full flex items-center justify-center rounded-l-xl hover:bg-accent-dark active:scale-90 transition-colors cursor-pointer"
              aria-label="Decrease quantity"
            >
              <Minus className="h-5 w-5" />
            </button>
            <span className="text-base select-none">{quantity}</span>
            <button
              onClick={() => updateQuantity(product.id, product.name, quantity + 1)}
              disabled={quantity >= product.stock || isStoreClosed}
              className="flex-grow h-full flex items-center justify-center rounded-r-xl hover:bg-accent-dark active:scale-90 transition-colors disabled:opacity-50 cursor-pointer"
              aria-label="Increase quantity"
            >
              <Plus className="h-5 w-5" />
            </button>
          </div>
        )}
      </div>

      {product.stock > 0 && !isStoreClosed && (
        <Button
          onClick={handleExpressBuy}
          className="h-12 px-8 bg-[#e20a22] hover:bg-[#c8081c] text-white font-black rounded-xl transition-all duration-200 shadow-md hover:shadow-lg flex-grow sm:flex-grow-0 flex items-center justify-center gap-2 text-base cursor-pointer"
        >
          ⚡ Express Buy
        </Button>
      )}
    </div>
  )
}
