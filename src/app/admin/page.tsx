import { redirect } from 'next/navigation'
import { Suspense } from 'react'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { formatPrice, withRetry } from '@/lib/utils'
import { AdminDashboard } from '@/components/admin/admin-dashboard'
import { getStoreUserFilter } from '@/lib/store-resolver'
import { isRootAdminAccount } from '@/lib/superadmin-config'
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


export default async function AdminPage(props: {
  searchParams?: Promise<{ storeId?: string }>
}) {
  const session = await auth()
  if (!session) {
    redirect('/login?callbackUrl=/admin')
  }

  const dbUser = session?.user?.id ? await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { id: true, role: true, phone: true, email: true, name: true, assignedStoreId: true }
  }) : null

  const userAssignedStoreId = dbUser?.assignedStoreId || (session.user as any)?.assignedStoreId || null

  const isMaster = isRootAdminAccount({
    email: dbUser?.email || session.user?.email,
    phone: dbUser?.phone || (session.user as any)?.phone,
    role: dbUser?.role || session.user?.role,
  })

  const role = (dbUser?.role || session.user?.role)?.toUpperCase()
  if (!isMaster && role !== 'ADMIN') {
    redirect('/')
  }

  const searchParams = props.searchParams ? await props.searchParams : undefined
  // For branch/hub admins (like Akbarpur), STRICTLY lock initialStoreId to their assigned store!
  const initialStoreId = isMaster
    ? (searchParams?.storeId || userAssignedStoreId || null)
    : (userAssignedStoreId || searchParams?.storeId || null)

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
  let todayDeliveryFee = 0
  let todayPackagingFee = 0

  try {
    // Exact Indian Standard Time (IST) start of day
    const now = new Date()
    const istOffset = 5.5 * 60 * 60 * 1000
    const istDate = new Date(now.getTime() + istOffset)
    istDate.setUTCHours(0, 0, 0, 0)
    const startOfToday = new Date(istDate.getTime() - istOffset)

    const storeWhere = initialStoreId && initialStoreId !== 'all'
      ? { storeId: initialStoreId }
      : undefined

    const userStoreFilter = await getStoreUserFilter(initialStoreId)

    const storeSqlWhere = initialStoreId && initialStoreId !== 'all'
      ? Prisma.sql`AND "storeId" = ${initialStoreId}`
      : Prisma.empty

    const [todayStatsRaw, statusStatsRaw, ...results] = await Promise.all([
      prisma.$queryRaw<Array<{
        today_orders: number
        today_sales: number
        today_delivered_sales: number
        today_delivery_fee: number
        today_packaging_fee: number
      }>>`
        SELECT 
          COUNT(DISTINCT COALESCE("combinedId", id))::int as today_orders,
          COALESCE(SUM(total), 0)::float as today_sales,
          COALESCE(SUM(CASE WHEN status::text = 'DELIVERED' THEN GREATEST(0, (total - COALESCE("refundAmount", 0))) ELSE 0 END), 0)::float as today_delivered_sales,
          COALESCE(SUM("deliveryFee"), 0)::float as today_delivery_fee,
          COALESCE(SUM("miscFee"), 0)::float as today_packaging_fee
        FROM orders
        WHERE ("deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL)
          AND status::text != 'CANCELLED'
          AND "createdAt" >= ${startOfToday}
          ${storeSqlWhere}
      `,
      prisma.$queryRaw<Array<{
        total: number
        pending: number
        confirmed: number
        packed: number
        shipped: number
        delivered: number
        cancelled: number
      }>>`
        SELECT 
          COUNT(DISTINCT COALESCE("combinedId", id))::int as total,
          COUNT(DISTINCT CASE WHEN status::text = 'PENDING' THEN COALESCE("combinedId", id) END)::int as pending,
          COUNT(DISTINCT CASE WHEN status::text = 'CONFIRMED' THEN COALESCE("combinedId", id) END)::int as confirmed,
          COUNT(DISTINCT CASE WHEN status::text = 'PACKED' THEN COALESCE("combinedId", id) END)::int as packed,
          COUNT(DISTINCT CASE WHEN status::text = 'SHIPPED' THEN COALESCE("combinedId", id) END)::int as shipped,
          COUNT(DISTINCT CASE WHEN status::text = 'DELIVERED' THEN COALESCE("combinedId", id) END)::int as delivered,
          COUNT(DISTINCT CASE WHEN status::text = 'CANCELLED' THEN COALESCE("combinedId", id) END)::int as cancelled
        FROM orders
        WHERE ("deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL)
          ${storeSqlWhere}
      `,
      prisma.user.count({
        where: {
          NOT: { email: { startsWith: 'guest-' } },
          ...(Object.keys(userStoreFilter).length > 0 ? userStoreFilter : {})
        } as any
      }),
      initialStoreId && initialStoreId !== 'all'
        ? prisma.storeInventory.count({
            where: {
              storeId: initialStoreId,
              stock: { lt: 15 }
            }
          })
        : prisma.product.count({
            where: {
              stock: { lt: 15 },
              isAvailable: true,
              restaurantId: null,
            },
          }),
      initialStoreId && initialStoreId !== 'all'
        ? prisma.$queryRaw`
            SELECT "shopName", "restaurantId", "orderType"::text as "orderType", status::text as status,
                   COUNT(DISTINCT COALESCE("combinedId", id))::int as count,
                   COALESCE(SUM(total), 0)::float as total,
                   COALESCE(SUM(subtotal), 0)::float as subtotal,
                   COALESCE(SUM(discount), 0)::float as discount
            FROM orders
            WHERE ("deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL)
              AND "storeId" = ${initialStoreId}
            GROUP BY "shopName", "restaurantId", "orderType", status
          `
        : prisma.$queryRaw`
            SELECT "shopName", "restaurantId", "orderType"::text as "orderType", status::text as status,
                   COUNT(DISTINCT COALESCE("combinedId", id))::int as count,
                   COALESCE(SUM(total), 0)::float as total,
                   COALESCE(SUM(subtotal), 0)::float as subtotal,
                   COALESCE(SUM(discount), 0)::float as discount
            FROM orders
            WHERE "deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL
            GROUP BY "shopName", "restaurantId", "orderType", status
          `,
      prisma.order.findMany({
        where: storeWhere,
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
              notes: true,
              refundAmount: true,
              isRefunded: true,
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

    const todayRow = (todayStatsRaw as any[])?.[0] || { today_orders: 0, today_sales: 0, today_delivered_sales: 0, today_delivery_fee: 0, today_packaging_fee: 0 }
    const statusRow = (statusStatsRaw as any[])?.[0] || { total: 0, pending: 0, confirmed: 0, packed: 0, shipped: 0, delivered: 0, cancelled: 0 }

    todayOrdersCount = todayRow.today_orders || 0
    todayRevenue = todayRow.today_sales || 0
    todayNetRevenue = todayRow.today_delivered_sales || 0
    todayDeliveryFee = todayRow.today_delivery_fee || 0
    todayPackagingFee = todayRow.today_packaging_fee || 0
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

    let platformDeliveredRevenue = 0
    groupStats.forEach((group: any) => {
      const isRestaurant = !!group.restaurantId || group.orderType === 'RESTAURANT' || (group.shopName && group.shopName.toLowerCase().includes('restaurant'))
      
      const count = group.count || 0
      // Food net sales (strictly food subtotal minus discount - packaging and delivery fees excluded)
      const foodNetSales = (group.subtotal || 0) - (group.discount || 0)
      // Total order value (customer collection: food + delivery fee + packaging miscFee)
      const totalOrderValue = group.total || 0

      if (isRestaurant) {
        restaurantTotalOrders += count
        if (group.status === 'DELIVERED') {
          restaurantRevenue += foodNetSales // Strictly Food Net Sales (no packaging, no delivery fee)
          restaurantDeliveredOrders += count
          platformDeliveredRevenue += totalOrderValue
        } else if (group.status !== 'CANCELLED') {
          restaurantActiveOrders += count
        }
      } else {
        groceryTotalOrders += count
        if (group.status === 'DELIVERED') {
          groceryRevenue += totalOrderValue
          groceryDeliveredOrders += count
          platformDeliveredRevenue += totalOrderValue
        } else if (group.status !== 'CANCELLED') {
          groceryActiveOrders += count
        }
      }
    })

    revenue = platformDeliveredRevenue + cafeRevenue
    totalOrdersCount = statusRow.total || 0
    activeOrdersCount = (statusRow.pending || 0) + (statusRow.confirmed || 0) + (statusRow.packed || 0) + (statusRow.shipped || 0)
    deliveredOrdersCount = statusRow.delivered || 0
    orderCount = deliveredOrdersCount

    initialOrderCounts = {
      ALL: totalOrdersCount,
      PENDING: statusRow.pending || 0,
      CONFIRMED: statusRow.confirmed || 0,
      PACKED: statusRow.packed || 0,
      SHIPPED: statusRow.shipped || 0,
      DELIVERED: statusRow.delivered || 0,
      CANCELLED: statusRow.cancelled || 0,
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
      combinedId: o.combinedId || null,
      orderType: o.orderType || (o.restaurantId ? 'RESTAURANT' : 'GROCERY'),
      status: o.status,
      paymentStatus: o.paymentStatus || 'PENDING',
      paymentMethod: o.paymentMethod || 'COD',
      total: o.total,
      refundAmount: o.refundAmount || 0,
      notes: o.notes || null,
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
        notes: item.notes || null,
        refundAmount: item.refundAmount || 0,
        isRefunded: item.isRefunded || false,
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
    { label: "Today's Sales", value: formatPrice(todayRevenue), icon: IndianRupee, color: 'text-emerald-500 bg-emerald-500/10' },
    { label: "Today's Net Revenue", value: formatPrice(todayNetRevenue), icon: TrendingUp, color: 'text-teal-500 bg-teal-500/10' },
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
          <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Admin Console</h1>
          <p className="text-xs text-text-secondary mt-0.5">
            Welcome, {session.user.name || 'Admin'} ({userEmail || 'admin@fastkirana.com'}). Full zone control, live orders, catalog, and store settings.
          </p>
        </div>
        <div className="flex items-center gap-2">
          {isSuperAdmin && (
            <a 
              href="/superadmin" 
              className="inline-flex items-center justify-center text-xs font-black uppercase tracking-wider bg-card border-2 border-[#e20a22]/30 text-[#e20a22] h-9 px-4 rounded-xl hover:bg-[#e20a22]/5 shadow-sm hover:shadow-md transition-all active:scale-[0.98]"
            >
              🏛️ HQ Dashboard
            </a>
          )}
          <a 
            href="/admin/restaurants" 
            className="inline-flex items-center justify-center text-xs font-black uppercase tracking-wider bg-[#e20a22] text-white h-9 px-4 rounded-xl hover:bg-[#c9081e] shadow-sm hover:shadow-md transition-all active:scale-[0.98]"
          >
            Manage Outlets 🍽️
          </a>
        </div>
      </div>

      {/* Dynamic Tabbed Console */}
      <Suspense fallback={
        <div className="flex flex-col items-center justify-center min-h-[400px] gap-3 text-muted-foreground animate-pulse">
          <div className="w-8 h-8 rounded-full border-2 border-red-500 border-t-transparent animate-spin" />
          <p className="text-xs font-bold tracking-wide">Loading Fast Kirana Admin Console...</p>
        </div>
      }>
        <AdminDashboard
          initialStoreId={initialStoreId}
          serverUser={{
            id: session.user.id,
            name: dbUser?.name || session.user.name,
            email: dbUser?.email || session.user.email,
            role: dbUser?.role || session.user.role,
            phone: dbUser?.phone || (session.user as any).phone || null,
            assignedStoreId: userAssignedStoreId,
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
            todayDeliveryFee,
            todayPackagingFee,
            orderCount: totalOrdersCount,
            activeOrderCount: activeOrdersCount,
            userCount,
            lowStockCount,
            groceryRevenue,
            restaurantRevenue,
          }}
        />
      </Suspense>

    </div>
  )
}
