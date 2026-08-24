import { redirect } from 'next/navigation'
import { Metadata } from 'next'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { AccountDashboard } from '@/components/account/account-dashboard'
import { getLast10Digits } from '@/lib/phone'

export const dynamic = 'force-dynamic'
export const revalidate = 0

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

  let user: any = null
  let addresses: any[] = []
  let orders: any[] = []
  let allItems: any[] = []

  try {
    // Fast parallel execution with primary key indexes
    const [dbUser, dbAddresses, dbOrders] = await Promise.all([
      // 1. Fetch user by ID or Email
      prisma.user.findFirst({
        where: {
          OR: [
            ...(sessionId ? [{ id: sessionId }] : []),
            ...(sessionEmail ? [{ email: { equals: sessionEmail, mode: 'insensitive' as const } }] : []),
            ...(sessionPhone ? [{ phone: { contains: sessionPhone } }] : [])
          ]
        },
        select: { id: true, name: true, email: true, phone: true, role: true }
      }),

      // 2. Fetch addresses
      prisma.address.findMany({
        where: { userId: sessionId },
        orderBy: { createdAt: 'desc' },
      }),

      // 3. Fetch orders with items in a single query
      prisma.order.findMany({
        where: { userId: sessionId },
        orderBy: { createdAt: 'desc' },
        take: 30,
        select: {
          id: true,
          readableId: true,
          status: true,
          total: true,
          createdAt: true,
          items: {
            select: {
              id: true,
              orderId: true,
              name: true,
              quantity: true,
              price: true,
            }
          }
        }
      })
    ])

    user = dbUser
    addresses = dbAddresses || []
    orders = dbOrders || []
    allItems = orders.flatMap(o => o.items || [])
  } catch (error) {
    console.warn('Database connection error in account page: using session fallback', error)
  }

  // Fallback if database is offline/unreachable
  const activeUser = user || {
    name: session.user.name || 'User',
    email: sessionEmail,
    phone: sessionPhone,
    role: (session.user.role as any) || 'USER',
  }

  const serializedUser = {
    name: activeUser.name || 'User',
    email: activeUser.email || sessionEmail,
    phone: activeUser.phone || sessionPhone,
    role: activeUser.role as 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN',
  }

  const serializedAddresses = addresses.map((addr) => ({
    id: addr.id,
    label: addr.label,
    houseNo: addr.houseNo,
    street: addr.street,
    area: addr.area,
    city: addr.city,
    phone: addr.phone,
    lat: addr.lat,
    lng: addr.lng,
  }))

  const serializedOrders = orders.map((o) => ({
    id: o.id,
    readableId: o.readableId,
    status: o.status,
    total: o.total,
    createdAt: o.createdAt instanceof Date ? o.createdAt.toISOString() : String(o.createdAt),
    items: allItems
      .filter((i) => i.orderId === o.id)
      .map((i) => ({
        id: i.id,
        name: i.name,
        quantity: i.quantity,
        price: i.price,
      })),
  }))

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl animate-fade-in">
      <AccountDashboard
        user={serializedUser}
        initialAddresses={serializedAddresses}
        initialOrders={serializedOrders}
      />
    </div>
  )
}
