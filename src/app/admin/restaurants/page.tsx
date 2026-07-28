import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { RestaurantManager } from '@/components/admin/restaurant-manager'

export const revalidate = 0

export default async function AdminRestaurantsPage() {
  const session = await auth()
  if (!session || session.user?.role !== 'ADMIN') {
    redirect('/')
  }

  const restaurants = await prisma.restaurant.findMany({
    orderBy: { sortOrder: 'asc' },
    include: {
      _count: {
        select: { products: true }
      }
    }
  })

  const formattedRestaurants = restaurants.map(r => ({
    ...r,
    createdAt: r.createdAt.toISOString(),
    updatedAt: r.updatedAt.toISOString(),
  }))

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl animate-fade-in">
      <div className="mb-6">
        <h1 className="text-2xl font-black text-text-primary tracking-tight">Restaurant Management</h1>
        <p className="text-sm text-text-secondary mt-1">Manage restaurants, their status, and settings.</p>
      </div>
      <RestaurantManager initialRestaurants={formattedRestaurants} />
    </div>
  )
}
