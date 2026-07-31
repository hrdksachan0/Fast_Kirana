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

  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const [restaurants, orderStats] = await Promise.all([
    prisma.restaurant.findMany({
      orderBy: { sortOrder: 'asc' },
      include: {
        _count: {
          select: { products: true }
        }
      }
    }),
    prisma.order.groupBy({
      by: ['restaurantId'],
      where: {
        status: 'DELIVERED',
        restaurantId: { not: null },
        createdAt: { gte: thirtyDaysAgo }
      },
      _sum: { subtotal: true, discount: true },
      _count: { id: true }
    })
  ])

  const statsMap: Record<string, { totalSales: number; ordersCount: number }> = {}
  orderStats.forEach((s) => {
    if (s.restaurantId) {
      const sales = Math.max(0, (s._sum.subtotal || 0) - (s._sum.discount || 0))
      statsMap[s.restaurantId] = {
        totalSales: sales,
        ordersCount: s._count.id || 0
      }
    }
  })

  const formattedRestaurants = restaurants.map(r => ({
    ...r,
    createdAt: r.createdAt.toISOString(),
    updatedAt: r.updatedAt.toISOString(),
    stats30Days: statsMap[r.id] || { totalSales: 0, ordersCount: 0 }
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
