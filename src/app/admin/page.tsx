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
    const results = await Promise.all([
      prisma.user.count(),
      prisma.product.count({
        where: {
          stock: { lt: 15 },
          isAvailable: true,
          category: { slug: { not: 'cafe' } },
        },
      }),
      prisma.order.aggregate({
        _sum: { total: true },
        where: { status: 'DELIVERED' },
      }),
      prisma.$queryRaw`
        SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId"
        FROM orders o
        ORDER BY o."createdAt" DESC
        LIMIT 10
      ` as Promise<any[]>,
      prisma.product.findMany({
        include: {
          category: true,
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: 10,
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
      prisma.review.findMany({
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: {
          user: { select: { id: true, name: true, email: true } },
          product: { select: { id: true, name: true, slug: true, imageUrl: true } },
        },
      }),
      prisma.coupon.findMany({
        orderBy: { createdAt: 'desc' },
      }),
      prisma.$queryRaw`
        SELECT u.id, u.name, u.email, u.phone, u.role::text as role, u."createdAt",
               (SELECT COUNT(*)::int FROM orders o WHERE o."userId" = u.id) as order_count
        FROM users u ORDER BY u."createdAt" DESC LIMIT 10
      `,
      prisma.product.findMany({
        select: {
          id: true,
          name: true,
          price: true,
          mrp: true,
          costPrice: true,
          stock: true,
          minStock: true,
          isAvailable: true,
          tags: true,
          variants: true,
          category: {
            select: {
              id: true,
              name: true,
              slug: true,
            }
          }
        }
      }),
      prisma.$queryRaw`
        SELECT o.status::text as status, COUNT(*)::int as count
        FROM orders o
        GROUP BY o.status
      ` as Promise<any[]>,
    ])

    userCount = results[0] as number
    lowStockCount = results[1] as number
    const aggregateResult = results[2] as any
    revenue = aggregateResult._sum?.total || 0
    ordersRaw = results[3] as any[]
    productsRaw = results[4] as any[]
    categoriesRaw = results[5] as any[]
    reviewsRaw = results[6] as any[]
    couponsRaw = results[7] as any[]
    usersRaw = results[8] as any[]
    allProductsRaw = results[9] as any[]
    const statusGroups = results[10] as any[]

    const userIds = [...new Set(ordersRaw.map(o => o.userId))]
    const addressIds = [...new Set(ordersRaw.map(o => o.addressId))].filter(Boolean)

    const [fetchedUsers, fetchedAddresses] = await Promise.all([
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>)
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
    ])
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
    statusGroups.forEach((group) => {
      if (group.status && statusCountsMap[group.status] !== undefined) {
        statusCountsMap[group.status] = group.count || 0
      }
    })

    totalOrdersCount = Object.values(statusCountsMap).reduce((a, b) => a + b, 0)
    activeOrdersCount = statusCountsMap.PENDING + statusCountsMap.CONFIRMED + statusCountsMap.PACKED + statusCountsMap.SHIPPED
    deliveredOrdersCount = statusCountsMap.DELIVERED
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
    console.warn('Database connection error in admin page: using empty dashboard fallback')
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
      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {statsList.map((card) => {
          const CardIcon = card.icon
          return (
            <div key={card.label} className="bg-card border border-border p-5 rounded-2xl shadow-sm flex items-center gap-4">
              <div className={`flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-xl ${card.color}`}>
                <CardIcon className="h-5 w-5" />
              </div>
              <div>
                <span className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider block">
                  {card.label}
                </span>
                <span className="text-lg md:text-xl font-black text-text-primary mt-1 block">
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
