import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { AccountDashboard } from '@/components/account/account-dashboard'

export const revalidate = 0 // Account details are fully dynamic

export default async function AccountPage() {
  const session = await auth()
  if (!session?.user?.email) {
    redirect('/login')
  }

  const email = session.user.email.toLowerCase().trim()

  // Use raw SQL to work around PrismaPg adapter enum deserialization bug
  const usersResult: any[] = await prisma.$queryRaw`
    SELECT id, name, email, phone, role::text as role
    FROM users WHERE email = ${email} LIMIT 1
  `

  const user = usersResult[0]

  if (!user) {
    redirect('/api/auth/signout')
  }

  // Fetch addresses normally (no enum fields)
  const addresses = await prisma.address.findMany({
    where: { userId: user.id },
  })

  // Fetch orders with raw SQL to avoid enum issues (status, paymentMethod, paymentStatus are enums)
  const orders: any[] = await prisma.$queryRaw`
    SELECT o.id, o.status::text as status, o.total, o."createdAt"
    FROM orders o WHERE o."userId" = ${user.id}
    ORDER BY o."createdAt" DESC
  `

  // Fetch order items for each order
  const orderIds = orders.map((o) => o.id)
  const allItems: any[] = orderIds.length > 0
    ? await prisma.$queryRaw`
        SELECT id, "orderId", name, quantity, price
        FROM order_items WHERE "orderId" = ANY(${orderIds})
      `
    : []

  const serializedUser = {
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role as 'USER' | 'PICKER' | 'CHEF' | 'DELIVERY' | 'ADMIN',
  }

  const serializedAddresses = addresses.map((addr) => ({
    id: addr.id,
    label: addr.label,
    houseNo: addr.houseNo,
    street: addr.street,
    area: addr.area,
    city: addr.city,
    pincode: addr.pincode,
    isDefault: addr.isDefault,
  }))

  const serializedOrders = orders.map((ord) => ({
    id: ord.id,
    status: ord.status,
    total: ord.total,
    createdAt: ord.createdAt instanceof Date ? ord.createdAt.toISOString() : String(ord.createdAt),
    items: allItems
      .filter((item) => item.orderId === ord.id)
      .map((item) => ({
        id: item.id,
        name: item.name,
        quantity: item.quantity,
        price: item.price,
      })),
  }))

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl space-y-6">
      <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Your Account</h1>
      <AccountDashboard
        user={serializedUser}
        addresses={serializedAddresses}
        orders={serializedOrders}
      />
    </div>
  )
}

