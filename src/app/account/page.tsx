import { redirect } from 'next/navigation'
import { Metadata } from 'next'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { AccountDashboard } from '@/components/account/account-dashboard'
import { getLast10Digits } from '@/lib/phone'

export const revalidate = 0 // Account details are fully dynamic

export async function generateMetadata(): Promise<Metadata> {
  return {
    title: 'My Account - FastKirana',
    description: 'Manage your FastKirana account. View orders, addresses, and profile settings.',
  }
}

export default async function AccountPage() {
  const session = await auth()
  if (!session?.user) {
    redirect('/login')
  }

  const sessionId = session.user.id || ''
  const sessionEmail = session.user.email ? session.user.email.toLowerCase().trim() : ''
  const sessionPhone = (session.user as any).phone ? getLast10Digits((session.user as any).phone) : ''

  let user = null
  let addresses: any[] = []
  let orders: any[] = []
  let allItems: any[] = []

  try {
    // Find user by ID, Email, or Phone
    const usersResult: any[] = await prisma.$queryRaw`
      SELECT id, name, email, phone, role::text as role
      FROM users 
      WHERE id = ${sessionId}
         OR (email IS NOT NULL AND LOWER(email) = ${sessionEmail} AND ${sessionEmail} != '')
         OR (phone IS NOT NULL AND ${sessionPhone} != '' AND REPLACE(REPLACE(phone, '+', ''), ' ', '') LIKE ${'%' + sessionPhone})
      LIMIT 1
    `
    user = usersResult[0]

    const targetUserId = user?.id || sessionId

    if (targetUserId) {
      // Fetch addresses
      addresses = await prisma.address.findMany({
        where: {
          OR: [
            { userId: targetUserId },
            ...(sessionId ? [{ userId: sessionId }] : [])
          ]
        },
      })

      // Fetch orders matching targetUserId OR sessionId OR matching phone
      orders = await prisma.$queryRaw`
        SELECT o.id, o.status::text as status, o.total, o."createdAt"
        FROM orders o 
        WHERE o."userId" = ${targetUserId}
           OR o."userId" = ${sessionId}
           OR (${sessionPhone} != '' AND o."userId" IN (
                SELECT id FROM users WHERE REPLACE(REPLACE(phone, '+', ''), ' ', '') LIKE ${'%' + sessionPhone}
              ))
        ORDER BY o."createdAt" DESC
        LIMIT 50
      `

      // Fetch order items for each order
      const orderIds = orders.map((o) => o.id)
      allItems = orderIds.length > 0
        ? await prisma.$queryRaw`
            SELECT id, "orderId", name, quantity, price
            FROM order_items WHERE "orderId" = ANY(${orderIds})
          `
        : []
    }
  } catch (error) {
    console.warn('Database connection error in account page: using session fallback')
  }

  // Fallback if database is offline/unreachable
  const activeUser = user || {
    name: session.user.name || 'User',
    email: sessionEmail,
    phone: sessionPhone,
    role: 'USER',
  }

  const serializedUser = {
    name: activeUser.name,
    email: activeUser.email,
    phone: activeUser.phone,
    role: activeUser.role as 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN',
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
    <div className="container mx-auto px-4 py-4 md:py-8 max-w-4xl space-y-6">
      <h1 className="text-lg md:text-2xl font-black text-text-primary tracking-tight">Your Account</h1>
      <AccountDashboard
        user={serializedUser}
        addresses={serializedAddresses}
        orders={serializedOrders}
      />
    </div>
  )
}

