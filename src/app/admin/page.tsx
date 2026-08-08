import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { formatPrice, withRetry } from '@/lib/utils'
import { AdminDashboard } from '@/components/admin/admin-dashboard'
import {
  IndianRupee,
  ShoppingBag,
  Users,
  AlertTriangle,
  RotateCw,
  CheckCircle,
  TrendingUp,
} from 'lucide-react'

export const revalidate = 0 // Admin dashboard is fully dynamic


export default async function AdminPage() {
  const session = await auth()
  if (!session) {
    redirect('/login?callbackUrl=/admin')
  }

  const role = session.user?.role?.toUpperCase()
  if (role !== 'ADMIN') {
    redirect('/')
  }

  // 1. Fetch all store data in parallel
  let orderCount = 0
  let userCount = 0
  let lowStockCount = 0
  let revenue = 0
  let totalOrdersCount = 0
  let activeOrdersCount = 0
  let deliveredOrdersCount = 0
  let groceryRevenue = 0
  let restaurantRevenue = 0
  let cafeRevenue = 0
  let groceryTotalOrders = 0
  let restaurantTotalOrders = 0
  let cafeTotalOrders = 0
  let groceryActiveOrders = 0
  let restaurantActiveOrders = 0
  let cafeActiveOrders = 0
  let groceryDeliveredOrders = 0
  let restaurantDeliveredOrders = 0
  let cafeDeliveredOrders = 0
  let ordersRaw: any[] = []
  let productsRaw: any[] = []
  let categoriesRaw: any[] = []
  let reviewsRaw: any[] = []
  let couponsRaw: any[] = []
  let usersRaw: any[] = []
  let allProductsRaw: any[] = []
  let allUsers: any[] = []
  let allAddresses: any[] = []
  let initialOrderCounts = {
    ALL: 0,
    PENDING: 0,
    CONFIRMED: 0,
    PACKED: 0,
    SHIPPED: 0,
    DELIVERED: 0,
    CANCELLED: 0
  }

  let todayOrdersCount = 0
  let todayRevenue = 0
  let todayNetRevenue = 0

  try {
    const startOfToday = new Date()
    startOfToday.setHours(0, 0, 0, 0)

    const [todayOrders, todayRevAgg, todayDeliveredAgg, ...results] = await withRetry(() => Promise.all([
      prisma.order.count({
        where: {
          createdAt: { gte: startOfToday },
        },
      }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          status: { not: 'CANCELLED' },
        },
        _sum: { total: true },
      }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          status: 'DELIVERED',
        },
        _sum: { total: true },
      }),
      prisma.user.count({
        where: {
          NOT: {
            email: { startsWith: 'guest-' }
          }
        }
      }),
      prisma.product.count({
        where: {
          stock: { lt: 15 },
          isAvailable: true,
          category: { slug: { not: 'cafe' } },
        },
      }),
      prisma.order.groupBy({
        by: ['shopName', 'status'],
        _sum: { total: true },
        _count: { id: true },
      }),
      prisma.$queryRaw`
        SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId"
        FROM orders o
        ORDER BY o."createdAt" DESC
        LIMIT 10
      ` as Promise<any[]>,
      prisma.category.findMany({
        include: {
          _count: {
            select: { products: true },
          },
        },
        orderBy: {
          sortOrder: 'asc',
        },
      }),
    ]))

    todayOrdersCount = todayOrders as number
    todayRevenue = (todayRevAgg as any)._sum?.total || 0
    todayNetRevenue = (todayDeliveredAgg as any)._sum?.total || 0
    userCount = results[0] as number
    lowStockCount = results[1] as number
    const groupStats = results[2] as any[]
    ordersRaw = results[3] as any[]
    categoriesRaw = results[4] as any[]

    productsRaw = []
    reviewsRaw = []
    couponsRaw = []
    usersRaw = []
    allProductsRaw = []

    const userIds = [...new Set(ordersRaw.map(o => o.userId))]
    const addressIds = [...new Set(ordersRaw.map(o => o.addressId))].filter(Boolean)

    const [fetchedUsers, fetchedAddresses] = await withRetry(() => Promise.all([
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>)
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
    ]))
    allUsers = fetchedUsers
    allAddresses = fetchedAddresses

    const statusCountsMap: Record<string, number> = {
      PENDING: 0,
      CONFIRMED: 0,
      PACKED: 0,
      SHIPPED: 0,
      DELIVERED: 0,
      CANCELLED: 0,
    }
    
    groupStats.forEach((group: any) => {
      const isRestaurant = !!group.restaurantId || group.orderType === 'RESTAURANT'
      
      const count = group._count?.id || 0
      const sum = group._sum?.total || 0

      if (group.status && statusCountsMap[group.status] !== undefined) {
        statusCountsMap[group.status] += count
      }

      if (isRestaurant) {
        restaurantTotalOrders += count
        if (group.status === 'DELIVERED') {
          restaurantRevenue += sum
          restaurantDeliveredOrders += count
        } else if (group.status !== 'CANCELLED') {
          restaurantActiveOrders += count
        }
      } else {
        groceryTotalOrders += count
        if (group.status === 'DELIVERED') {
          groceryRevenue += sum
          groceryDeliveredOrders += count
        } else if (group.status !== 'CANCELLED') {
          groceryActiveOrders += count
        }
      }
    })

    revenue = groceryRevenue + restaurantRevenue + cafeRevenue
    totalOrdersCount = groceryTotalOrders + restaurantTotalOrders + cafeTotalOrders
    activeOrdersCount = groceryActiveOrders + restaurantActiveOrders + cafeActiveOrders
    deliveredOrdersCount = groceryDeliveredOrders + restaurantDeliveredOrders + cafeDeliveredOrders
    orderCount = deliveredOrdersCount

    initialOrderCounts = {
      ALL: totalOrdersCount,
      PENDING: statusCountsMap.PENDING,
      CONFIRMED: statusCountsMap.CONFIRMED,
      PACKED: statusCountsMap.PACKED,
      SHIPPED: statusCountsMap.SHIPPED,
      DELIVERED: statusCountsMap.DELIVERED,
      CANCELLED: statusCountsMap.CANCELLED,
    }
  } catch (error) {
    console.error('Database connection error in admin page:', error)
    return (
      <div className="container mx-auto px-4 py-24 flex items-center justify-center min-h-[70vh]">
        <div className="bg-card border border-border rounded-3xl p-8 max-w-md w-full shadow-lg text-center space-y-6 animate-fade-in">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-amber-500/10 text-amber-500">
            <AlertTriangle className="h-7 w-7" />
          </div>
          <div className="space-y-2">
            <h2 className="text-xl font-black text-text-primary">Database Waking Up</h2>
            <p className="text-sm text-text-secondary">
              The store database is currently resuming from its serverless sleep. This typically takes 5 to 7 seconds.
            </p>
          </div>
          <div className="bg-slate-50 dark:bg-zinc-900/50 rounded-xl p-4 text-xs text-text-muted text-left border border-border/40">
            <strong>What happened?</strong> To save resources, our Neon Postgres database pauses when idle. It automatically starts up the moment a new request comes in.
          </div>
          <div className="pt-2">
            <a 
              href="/admin" 
              className="inline-flex w-full items-center justify-center rounded-xl bg-primary hover:bg-primary/95 text-white font-extrabold py-3 px-4 text-sm transition-colors shadow-sm active:scale-[0.98]"
            >
              Refresh Admin Panel
            </a>
          </div>
        </div>
      </div>
    )
  }

  // Compute total revenue
  // (already computed above via DB aggregate sum)

  // Map objects to serializable structures for the client components
  const orders = ordersRaw.map((o) => {
    const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', email: '', phone: '' }
    const address = allAddresses.find(a => a.id === o.addressId) || null
    return {
      id: o.id,
      status: o.status,
      total: o.total,
      createdAt: new Date(o.createdAt).toISOString(),
      updatedAt: new Date(o.updatedAt).toISOString(),
      userName: user.name,
      userEmail: user.email,
      userPhone: user.phone,
      isB2B: o.isB2B,
      deliveryMethod: o.deliveryMethod,
      shopName: o.shopName,
      shopPhone: o.shopPhone,
      address: address ? {
        houseNo: address.houseNo,
        street: address.street,
        area: address.area,
        city: address.city,
        phone: address.phone,
      } : null,
    }
  })

  const products = productsRaw.map((p) => ({
    id: p.id,
    name: p.name,
    slug: p.slug,
    description: p.description,
    imageUrl: p.imageUrl,
    categoryId: p.categoryId,
    mrp: p.mrp,
    price: p.price,
    discount: p.discount,
    unit: p.unit,
    stock: p.stock,
    isAvailable: p.isAvailable,
    tags: p.tags,
    variants: p.variants,
    category: {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
    },
  }))

  const categories = categoriesRaw.map((c) => ({
    id: c.id,
    name: c.name,
    slug: c.slug,
    imageUrl: c.imageUrl,
    sortOrder: c.sortOrder,
    parentId: c.parentId || null,
    _count: {
      products: c._count.products,
    },
  }))

  const users = usersRaw.map((u: any) => ({
    id: u.id,
    name: u.name,
    email: u.email,
    phone: u.phone,
    role: u.role,
    createdAt: u.createdAt instanceof Date ? u.createdAt.toISOString() : String(u.createdAt),
    _count: {
      orders: u.order_count ?? 0,
    },
  }))

  const reviews = reviewsRaw.map((r) => ({
    id: r.id,
    rating: r.rating,
    comment: r.comment,
    createdAt: r.createdAt.toISOString(),
    user: { id: r.user.id, name: r.user.name, email: r.user.email },
    product: { id: r.product.id, name: r.product.name, slug: r.product.slug, imageUrl: r.product.imageUrl },
  }))

  const coupons = couponsRaw.map((c) => ({
    id: c.id,
    code: c.code,
    discountType: c.discountType,
    value: c.value,
    minOrder: c.minOrder,
    maxDiscount: c.maxDiscount,
    maxUses: c.maxUses,
    usedCount: c.usedCount,
    isActive: c.isActive,
    expiresAt: c.expiresAt ? c.expiresAt.toISOString() : null,
    createdAt: c.createdAt.toISOString(),
  }))

  const allProducts = allProductsRaw.map((p) => ({
    id: p.id,
    name: p.name,
    price: p.price,
    mrp: p.mrp,
    costPrice: p.costPrice ?? 0,
    stock: p.stock,
    minStock: p.minStock,
    isAvailable: p.isAvailable,
    tags: p.tags,
    variants: p.variants,
    category: {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
    },
  }))

  const statsList = [
    { label: 'Active Live Orders', value: activeOrdersCount.toString(), icon: RotateCw, color: 'text-amber-500 bg-amber-500/10' },
    { label: "Today's Net Revenue", value: formatPrice(todayRevenue), icon: IndianRupee, color: 'text-emerald-500 bg-emerald-500/10' },
    { label: "Today's Orders", value: todayOrdersCount.toString(), icon: ShoppingBag, color: 'text-primary bg-primary/10' },
    { label: 'Total Sales Revenue', value: formatPrice(revenue), icon: TrendingUp, color: 'text-blue-500 bg-blue-500/10' },
  ]

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 bg-background animate-fade-in">
      
      {/* Title Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center border-b border-border/60 pb-4 gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Admin Console</h1>
          <p className="text-xs text-text-secondary mt-0.5">Welcome, {session.user.name || 'Admin'}. Monitor finance, live order fulfillment, and store metrics.</p>
        </div>
        <a 
          href="/admin/restaurants" 
          className="inline-flex items-center justify-center text-xs font-black uppercase tracking-wider bg-[#e20a22] text-white h-9 px-4 rounded-xl hover:bg-[#c9081e] shadow-sm hover:shadow-md transition-all active:scale-[0.98]"
        >
          Manage Outlets 🍽️
        </a>
      </div>

      {/* Dynamic Tabbed Console */}
      <AdminDashboard
        initialOrders={orders}
        initialProducts={products}
        initialCategories={categories}
        initialUsers={users}
        initialReviews={reviews}
        initialCoupons={coupons}
        allProducts={allProducts}
        initialOrderCounts={initialOrderCounts}
        stats={{
          revenue,
          todaySales: todayRevenue,
          netSales: todayNetRevenue,
          todayOrdersCount: todayOrdersCount,
          orderCount: totalOrdersCount,
          activeOrderCount: activeOrdersCount,
          userCount,
          lowStockCount,
        }}
      />

    </div>
  )
}
