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
    // Exact Indian Standard Time (IST) start of day
    const now = new Date()
    const istOffset = 5.5 * 60 * 60 * 1000
    const istDate = new Date(now.getTime() + istOffset)
    istDate.setUTCHours(0, 0, 0, 0)
    const startOfToday = new Date(istDate.getTime() - istOffset)

    const [todayOrders, todayRevAgg, todayDeliveredAgg, ...results] = await Promise.all([
      prisma.order.count({
        where: {
          createdAt: { gte: startOfToday },
          deliveryMethod: { not: 'RETAIL' },
        },
      }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          status: { not: 'CANCELLED' },
          deliveryMethod: { not: 'RETAIL' },
        },
        _sum: { total: true },
      }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          status: 'DELIVERED',
          deliveryMethod: { not: 'RETAIL' },
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
          restaurantId: null,
        },
      }),
      prisma.$queryRaw`
        SELECT "shopName", "restaurantId", "orderType"::text as "orderType", status::text as status,
               COUNT(id)::int as count,
               COALESCE(SUM(total), 0)::float as total,
               COALESCE(SUM(subtotal), 0)::float as subtotal,
               COALESCE(SUM(discount), 0)::float as discount
        FROM orders
        WHERE "deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL
        GROUP BY "shopName", "restaurantId", "orderType", status
      `,
      prisma.order.findMany({
        take: 40,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, name: true, email: true, phone: true } },
          address: true,
          items: {
            select: {
              id: true,
              name: true,
              price: true,
              quantity: true,
              imageUrl: true,
              selectedVariant: true,
            }
          }
        },
      }),
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
    ])

    todayOrdersCount = (todayOrders as number) || 0
    todayRevenue = (todayRevAgg as any)?._sum?.total || 0
    todayNetRevenue = (todayDeliveredAgg as any)?._sum?.total || 0
    userCount = (results[0] as number) || 0
    lowStockCount = (results[1] as number) || 0
    const groupStats = (results[2] as any[]) || []
    const recentOrdersList = (results[3] as any[]) || []
    categoriesRaw = (results[4] as any[]) || []

    productsRaw = []
    reviewsRaw = []
    couponsRaw = []
    usersRaw = []
    allProductsRaw = []

    ordersRaw = recentOrdersList

    const statusCountsMap: Record<string, number> = {
      PENDING: 0,
      CONFIRMED: 0,
      PACKED: 0,
      SHIPPED: 0,
      DELIVERED: 0,
      CANCELLED: 0,
    }
    
    groupStats.forEach((group: any) => {
      const isRestaurant = !!group.restaurantId || group.orderType === 'RESTAURANT' || (group.shopName && group.shopName.toLowerCase().includes('restaurant'))
      
      const count = group.count || 0
      const foodNetSales = (group.subtotal || 0) - (group.discount || 0)
      const sum = isRestaurant && foodNetSales > 0 ? foodNetSales : (group.total || 0)

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
    console.error('Database connection warning in admin page:', error)
  }

  // Compute total revenue
  // (already computed above via DB aggregate sum)

  // Map objects to serializable structures for the client components
  const orders = ordersRaw.map((o) => {
    const user = o.user || { name: 'Customer', email: '', phone: '' }
    const address = o.address || null
    return {
      id: o.id,
      readableId: o.readableId || o.id.slice(-6).toUpperCase(),
      status: o.status,
      paymentStatus: o.paymentStatus || 'PENDING',
      paymentMethod: o.paymentMethod || 'COD',
      total: o.total,
      createdAt: new Date(o.createdAt).toISOString(),
      updatedAt: new Date(o.updatedAt).toISOString(),
      userName: user.name,
      userEmail: user.email,
      userPhone: address?.phone || user.phone || o.shopPhone || null,
      isB2B: o.isB2B,
      deliveryMethod: o.deliveryMethod,
      shopName: o.shopName,
      shopPhone: o.shopPhone,
      restaurantId: o.restaurantId || null,
      items: (o.items || []).map((item: any) => ({
        id: item.id,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        imageUrl: item.imageUrl,
        selectedVariant: item.selectedVariant,
      })),
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
    category: p.category ? {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
    } : { id: '', name: 'General', slug: 'general' },
  }))

  const categories = categoriesRaw.map((c) => ({
    id: c.id,
    name: c.name,
    slug: c.slug,
    imageUrl: c.imageUrl,
    sortOrder: c.sortOrder,
    parentId: c.parentId || null,
    _count: {
      products: c._count?.products ?? 0,
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
    createdAt: r.createdAt ? new Date(r.createdAt).toISOString() : new Date().toISOString(),
    user: r.user ? { id: r.user.id, name: r.user.name, email: r.user.email } : { id: '', name: 'Customer', email: '' },
    product: r.product ? { id: r.product.id, name: r.product.name, slug: r.product.slug, imageUrl: r.product.imageUrl } : null,
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
    expiresAt: c.expiresAt ? (c.expiresAt instanceof Date ? c.expiresAt.toISOString() : String(c.expiresAt)) : null,
    createdAt: c.createdAt instanceof Date ? c.createdAt.toISOString() : String(c.createdAt || new Date().toISOString()),
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
    tags: p.tags || [],
    variants: p.variants || null,
    category: p.category ? {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
    } : { id: '', name: 'General', slug: 'general' },
  }))

  const statsList = [
    { label: 'Active Live Orders', value: activeOrdersCount.toString(), icon: RotateCw, color: 'text-amber-500 bg-amber-500/10' },
    { label: "Today's Net Revenue", value: formatPrice(todayRevenue), icon: IndianRupee, color: 'text-emerald-500 bg-emerald-500/10' },
    { label: "Today's Orders", value: todayOrdersCount.toString(), icon: ShoppingBag, color: 'text-primary bg-primary/10' },
    { label: 'Total Sales Revenue', value: formatPrice(revenue), icon: TrendingUp, color: 'text-blue-500 bg-blue-500/10' },
  ]

  const userEmail = (session.user?.email || '').toLowerCase().trim()
  const userPhone = ((session.user as any)?.phone || '').replace(/\D/g, '').slice(-10)
  const isSuperAdmin = 
    userEmail === 'superadmin@fastkirana.com' || 
    userEmail.startsWith('superadmin') || 
    userPhone === '9170942500'

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 bg-background animate-fade-in">
      
      {/* Title Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center border-b border-border/60 pb-4 gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">
              {isSuperAdmin ? '👑 Super Admin Executive Console' : '🏢 Store Operations Manager Console'}
            </h1>
            <span className={`text-[10px] font-black uppercase tracking-wider px-2.5 py-0.5 rounded-full border ${
              isSuperAdmin 
                ? 'bg-[#e20a22]/10 text-[#e20a22] border-[#e20a22]/20' 
                : 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
            }`}>
              {isSuperAdmin ? 'Super Admin HQ' : 'Store Manager'}
            </span>
          </div>
          <p className="text-xs text-text-secondary mt-0.5">
            {isSuperAdmin
              ? `Welcome, ${session.user.name || 'Super Admin'} (${userEmail || 'superadmin@fastkirana.com'}). Executive overview of multi-hub network, staff roles, and platform settings.`
              : `Welcome, ${session.user.name || 'Store Manager'} (${userEmail || 'admin@fastkirana.com'}). Manage live order fulfillment, inventory stock, and store operations.`
            }
          </p>
        </div>
        {isSuperAdmin && (
          <a 
            href="/admin/restaurants" 
            className="inline-flex items-center justify-center text-xs font-black uppercase tracking-wider bg-[#e20a22] text-white h-9 px-4 rounded-xl hover:bg-[#c9081e] shadow-sm hover:shadow-md transition-all active:scale-[0.98]"
          >
            Manage Outlets 🍽️
          </a>
        )}
      </div>

      {/* Dynamic Tabbed Console */}
      <AdminDashboard
        serverUser={{
          id: session.user.id,
          name: session.user.name,
          email: session.user.email,
          role: session.user.role,
          phone: (session.user as any).phone || null,
          assignedStoreId: (session.user as any).assignedStoreId || null,
        }}
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
          groceryRevenue,
          restaurantRevenue,
        }}
      />

    </div>
  )
}
