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
  Settings,
  Star,
  Ticket,
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
  let deliveredOrders: { total: number }[] = []
  let ordersRaw: any[] = []
  let productsRaw: any[] = []
  let categoriesRaw: any[] = []
  let reviewsRaw: any[] = []
  let couponsRaw: any[] = []
  let usersRaw: any[] = []

  try {
    const results = await Promise.all([
      prisma.order.count(),
      prisma.user.count(),
      prisma.product.count({
        where: {
          stock: { lt: 15 },
          isAvailable: true,
        },
      }),
      prisma.order.findMany({
        where: { status: 'DELIVERED' },
        select: { total: true },
      }),
      prisma.order.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: {
            select: {
              name: true,
              email: true,
            },
          },
          address: true,
        },
        take: 100,
      }),
      prisma.product.findMany({
        include: {
          category: true,
        },
        orderBy: {
          createdAt: 'desc',
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
      prisma.review.findMany({
        orderBy: { createdAt: 'desc' },
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
        FROM users u ORDER BY u."createdAt" DESC
      `
    ])

    orderCount = results[0] as number
    userCount = results[1] as number
    lowStockCount = results[2] as number
    deliveredOrders = results[3] as { total: number }[]
    ordersRaw = results[4] as any[]
    productsRaw = results[5] as any[]
    categoriesRaw = results[6] as any[]
    reviewsRaw = results[7] as any[]
    couponsRaw = results[8] as any[]
    usersRaw = results[9] as any[]
  } catch (error) {
    console.error('Failed to fetch admin dashboard details from database:', error)
  }

  // Compute total revenue
  const revenue = deliveredOrders.reduce((sum, o) => sum + o.total, 0)

  // Map objects to serializable structures for the client components
  const orders = ordersRaw.map((o) => ({
    id: o.id,
    status: o.status,
    total: o.total,
    createdAt: o.createdAt.toISOString(),
    updatedAt: o.updatedAt.toISOString(),
    userName: o.user.name,
    userEmail: o.user.email,
    isB2B: o.isB2B,
    deliveryMethod: o.deliveryMethod,
    shopName: o.shopName,
    shopPhone: o.shopPhone,
    address: {
      houseNo: o.address.houseNo,
      street: o.address.street,
      area: o.address.area,
      city: o.address.city,
    },
  }))

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

  const statsList = [
    { label: 'Total Revenue', value: formatPrice(revenue), icon: IndianRupee, color: 'text-accent bg-accent/10' },
    { label: 'Total Orders', value: orderCount.toString(), icon: ShoppingBag, color: 'text-primary bg-primary/10' },
    { label: 'Registered Users', value: userCount.toString(), icon: Users, color: 'text-blue-500 bg-blue-500/10' },
    { label: 'Low Stock Items', value: lowStockCount.toString(), icon: AlertTriangle, color: 'text-discount bg-discount/10' },
    { label: 'Customer Reviews', value: reviews.length.toString(), icon: Star, color: 'text-yellow-500 bg-yellow-500/10' },
    { label: 'Active Coupons', value: coupons.filter((c) => c.isActive).length.toString(), icon: Ticket, color: 'text-purple-500 bg-purple-500/10' },
  ]

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 bg-background animate-fade-in">
      
      {/* Title Header */}
      <div className="flex justify-between items-center border-b border-border/60 pb-4">
        <div>
          <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Admin Console</h1>
          <p className="text-xs text-text-secondary mt-0.5">Welcome, {session.user.name || 'Admin'}. Manage store status, pricing, inventory and customers.</p>
        </div>
        <div className="h-9 w-9 rounded-full bg-muted flex items-center justify-center text-text-secondary border">
          <Settings className="h-5 w-5 animate-spin-slow" />
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
