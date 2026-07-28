import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { RestaurantForm } from '@/components/admin/restaurant-form'
import { ChevronLeft, Package } from 'lucide-react'
import Link from 'next/link'
import { Badge } from '@/components/ui/badge'

export default async function EditRestaurantPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await auth()
  const role = session?.user?.role
  if (!session || (role !== 'ADMIN' && role !== 'RESTAURANT_OWNER' && role !== 'CHEF')) {
    redirect('/admin')
  }

  const { id } = await params

  const restaurant = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { id },
        { slug: id }
      ]
    },
    include: {
      staff: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
        }
      },
      products: {
        select: {
          id: true,
          name: true,
          price: true,
          stock: true,
          isAvailable: true
        },
        orderBy: { name: 'asc' }
      }
    }
  })

  if (!restaurant) {
    redirect('/admin/restaurants')
  }

  const formattedRestaurant = {
    ...restaurant,
    createdAt: restaurant.createdAt.toISOString(),
    updatedAt: restaurant.updatedAt.toISOString(),
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl animate-fade-in space-y-8">
      <div className="flex items-center gap-4">
        <Link 
          href="/admin/restaurants"
          className="flex h-10 w-10 items-center justify-center rounded-full bg-card border border-border hover:bg-accent hover:text-accent-foreground transition-colors"
        >
          <ChevronLeft className="h-5 w-5" />
        </Link>
        <div>
          <h1 className="text-2xl font-black text-text-primary tracking-tight">Edit Restaurant</h1>
          <p className="text-sm text-text-secondary mt-1">Update profile for {restaurant.name}.</p>
        </div>
      </div>
      
      <RestaurantForm restaurant={formattedRestaurant} />
      
      {/* Products Section */}
      <div className="bg-card border border-border rounded-2xl overflow-hidden mt-8">
        <div className="p-4 border-b border-border bg-muted/30 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Package className="h-5 w-5 text-primary" />
            <h2 className="font-bold text-lg">Menu Items ({restaurant.products.length})</h2>
          </div>
          <Link href={`/admin?tab=products&shop=${restaurant.id}`} className="text-sm text-primary hover:underline font-medium">
            Manage in Catalog →
          </Link>
        </div>
        
        <div className="p-0 overflow-x-auto">
          {restaurant.products.length === 0 ? (
            <div className="p-8 text-center text-text-secondary">
              No products found for this restaurant.
            </div>
          ) : (
            <table className="w-full text-sm text-left">
              <thead className="text-xs text-text-secondary uppercase bg-muted/50 border-b border-border">
                <tr>
                  <th className="px-6 py-3 font-semibold">Name</th>
                  <th className="px-6 py-3 font-semibold">Price</th>
                  <th className="px-6 py-3 font-semibold">Stock</th>
                  <th className="px-6 py-3 font-semibold">Status</th>
                </tr>
              </thead>
              <tbody>
                {restaurant.products.map(product => (
                  <tr key={product.id} className="border-b border-border hover:bg-muted/30">
                    <td className="px-6 py-4 font-medium text-text-primary">{product.name}</td>
                    <td className="px-6 py-4">₹{product.price}</td>
                    <td className="px-6 py-4">{product.stock}</td>
                    <td className="px-6 py-4">
                      <Badge variant="outline" className={product.isAvailable ? "bg-green-100 text-green-700 border-green-200" : "bg-red-100 text-red-700 border-red-200"}>
                        {product.isAvailable ? 'Available' : 'Out of Stock'}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  )
}
