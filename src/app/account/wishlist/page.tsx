import { Suspense } from 'react'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { redirect } from 'next/navigation'
import { WishlistClient } from '@/components/account/wishlist-client'

export default async function WishlistPage() {
  const session = await auth()

  if (!session?.user?.id) {
    redirect('/login?callbackUrl=/account/wishlist')
  }

  // Pre-fetch wishlist data on server
  let rawItems: any[] = []
  try {
    const delegate = (prisma as any)?.wishlistItem || (prisma as any)?.wishlistItems
    if (delegate?.findMany) {
      rawItems = await delegate.findMany({
        where: { userId: session.user.id },
        include: {
          product: {
            include: {
              category: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      })
    }
  } catch (err) {
    console.error('Wishlist page fetch error:', err)
  }

  const items = rawItems.map((item: any) => ({
    id: item.id,
    productId: item.productId,
    createdAt: item.createdAt,
    product: item.product,
  }))

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-text-primary">My Wishlist</h2>
        <p className="text-xs text-text-secondary mt-1">
          {items.length} {items.length === 1 ? 'item' : 'items'} saved
        </p>
      </div>
      <Suspense fallback={<div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>}>
        <WishlistClient initialItems={items} />
      </Suspense>
    </div>
  )
}
