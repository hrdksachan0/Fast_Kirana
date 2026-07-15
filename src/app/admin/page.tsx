import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { formatPrice } from '@/lib/utils'
import { AdminDashboard } from '@/components/admin/admin-dashboard'
import {
  IndianRupee,
  ShoppingBag,
  Users,
  AlertTriangle,
  RotateCw,
  CheckCircle,
} from 'lucide-react'

export const revalidate = 0 // Admin dashboard is fully dynamic

async function retryQuery<T>(fn: () => Promise<T>, retries = 3, delay = 2000): Promise<T> {
  let lastError: any;
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      console.warn(`Database query failed. Retrying in ${delay}ms... (Attempt ${i + 1}/${retries})`);
      if (i < retries - 1) {
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }
  throw lastError;
}

export default async function AdminPage() {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
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

  try {
    const results = await retryQuery(() => Promise.all([
      prisma.user.count(),
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

    const [fetchedUsers, fetchedAddresses] = await retryQuery(() => Promise.all([
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
      const isCafe = group.shopName === 'FastKirana Cafe Kitchen'
      const isRestaurant = group.shopName === 'FastKirana Restaurant Kitchen'
      
      const count = group._count?.id || 0
      const sum = group._sum?.total || 0

      if (group.status && statusCountsMap[group.status] !== undefined) {
        statusCountsMap[group.status] += count
      }

      if (isCafe) {
        cafeTotalOrders += count
        if (group.status === 'DELIVERED') {
          cafeRevenue += sum
          cafeDeliveredOrders += count
        } else if (group.status !== 'CANCELLED') {
          cafeActiveOrders += count
        }
      } else if (isRestaurant) {
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
    { label: 'Total Revenue', value: formatPrice(revenue), icon: IndianRupee, color: 'text-accent bg-accent/10' },
    { label: 'Total Orders', value: totalOrdersCount.toString(), icon: ShoppingBag, color: 'text-primary bg-primary/10' },
    { label: 'Active Orders', value: activeOrdersCount.toString(), icon: RotateCw, color: 'text-amber-500 bg-amber-500/10' },
    { label: 'Delivered Orders', value: deliveredOrdersCount.toString(), icon: CheckCircle, color: 'text-[#00b140] bg-[#00b140]/10' },
    { label: 'Registered Users', value: userCount.toString(), icon: Users, color: 'text-blue-500 bg-blue-500/10' },
    { label: 'Low Stock Alert', value: lowStockCount.toString(), icon: AlertTriangle, color: 'text-discount bg-discount/10' },
  ]

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 bg-background animate-fade-in">
      
      {/* Title Header */}
      <div className="flex justify-between items-center border-b border-border/60 pb-4">
        <div>
          <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Admin Console</h1>
          <p className="text-xs text-text-secondary mt-0.5">Welcome, {session.user.name || 'Admin'}. Manage store status, pricing, inventory and customers.</p>
        </div>
      </div>

      {/* Grid of Stats Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-6 gap-3 sm:gap-4">
        {statsList.map((card) => {
          const CardIcon = card.icon
          return (
            <div 
              key={card.label} 
              className="relative overflow-hidden bg-card border border-border hover:border-primary/20 p-3.5 rounded-2xl shadow-xs hover:shadow-md transition-all duration-300 flex items-center gap-3 group"
            >
              {/* Subtle background glow effect on hover */}
              <div className="absolute top-0 right-0 -mt-6 -mr-6 w-16 h-16 bg-current opacity-0 group-hover:opacity-[0.03] transition-opacity duration-300 rounded-full blur-md" />
              
              <div className={`flex h-9 w-9 sm:h-10 sm:w-10 shrink-0 items-center justify-center rounded-xl transition-all duration-300 group-hover:scale-105 ${card.color}`}>
                <CardIcon className="h-4.5 w-4.5 sm:h-5 sm:w-5" />
              </div>
              
              <div className="min-w-0 flex-1">
                <span className="text-[9px] font-black text-text-secondary uppercase tracking-wider block leading-none">
                  {card.label}
                </span>
                <span className="text-sm sm:text-base font-black text-text-primary mt-1 block truncate leading-none">
                  {card.value}
                </span>
              </div>
            </div>
          )
        })}
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
          orderCount,
          userCount,
          lowStockCount,
        }}
      />

    </div>
  )
}
