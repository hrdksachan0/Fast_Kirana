import { notFound, redirect } from 'next/navigation'
import Link from 'next/link'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { OrderTracker } from '@/components/order/order-tracker'

interface OrderTrackingPageProps {
  params: Promise<{ id: string }>
}

export const revalidate = 0 // Polled tracker is dynamic

export default async function OrderTrackingPage({ params }: OrderTrackingPageProps) {
  const session = await auth()
  if (!session?.user?.id) {
    redirect('/login')
  }

  const { id } = await params

  let orderRaw = null
  let companionOrder = null

  try {
    orderRaw = await prisma.order.findUnique({
      where: { id },
      include: {
        items: true,
        address: true,
      },
    })
  } catch (error) {
    console.warn('Database connection error: failed to fetch tracking order')
  }

  if (!orderRaw) {
    notFound()
  }

  // Verify ownership
  if (orderRaw.userId !== session.user.id && session.user.role !== 'ADMIN') {
    redirect('/')
  }

  try {
    // Find other orders placed by the same user within 5 seconds of this order
    const fiveSecondsAgo = new Date(orderRaw.createdAt.getTime() - 5000)
    const fiveSecondsAfter = new Date(orderRaw.createdAt.getTime() + 5000)
    companionOrder = await prisma.order.findFirst({
      where: {
        userId: orderRaw.userId,
        id: { not: orderRaw.id },
        createdAt: {
          gte: fiveSecondsAgo,
          lte: fiveSecondsAfter,
        },
      },
    })
  } catch (error) {
    console.warn('Database connection error: failed to fetch tracking companion order')
  }

  const isCafeOrder = orderRaw.shopName === 'FastKirana Cafe Kitchen'
  const isCompanionCafe = companionOrder?.shopName === 'FastKirana Cafe Kitchen'

  // Cast prisma order output to UI tracker schema format
  const order = {
    id: orderRaw.id,
    status: orderRaw.status,
    subtotal: orderRaw.subtotal,
    discount: orderRaw.discount,
    deliveryFee: orderRaw.deliveryFee,
    taxes: orderRaw.taxes,
    total: orderRaw.total,
    paymentMethod: orderRaw.paymentMethod,
    paymentStatus: orderRaw.paymentStatus,
    estimatedDelivery: orderRaw.estimatedDelivery?.toISOString() || null,
    deliveryPhoto: orderRaw.deliveryPhoto || null,
    deliveryLat: orderRaw.deliveryLat || null,
    deliveryLng: orderRaw.deliveryLng || null,
    deliveryMethod: orderRaw.deliveryMethod,
    isB2B: orderRaw.isB2B,
    shopName: orderRaw.shopName,
    shopPhone: orderRaw.shopPhone,
    createdAt: orderRaw.createdAt.toISOString(),
    items: orderRaw.items.map((i) => ({
      id: i.id,
      name: i.name,
      price: i.price,
      quantity: i.quantity,
    })),
    address: {
      label: orderRaw.address.label,
      houseNo: orderRaw.address.houseNo,
      street: orderRaw.address.street,
      area: orderRaw.address.area,
      city: orderRaw.address.city,
      pincode: orderRaw.address.pincode,
      lat: orderRaw.address.lat,
      lng: orderRaw.address.lng,
    },
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-3xl space-y-6">
      <div className="flex flex-col gap-4">
        <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Track Your Delivery</h1>
        
        {companionOrder && (
          <div className="bg-gradient-to-r from-rose-500 via-pink-500 to-orange-500 p-4 rounded-2xl text-white shadow-md flex flex-col md:flex-row justify-between items-start md:items-center gap-4 animate-slide-up">
            <div className="space-y-1">
              <span className="inline-flex items-center gap-1 rounded-full bg-white/20 px-2.5 py-0.5 text-[9px] font-black uppercase tracking-wider">
                {isCompanionCafe ? '☕ Cafe Order Split' : '📦 Grocery Order Split'}
              </span>
              <h3 className="text-sm font-black">Your Order Has Been Split!</h3>
              <p className="text-[10px] text-white/90 leading-relaxed font-semibold">
                {isCafeOrder
                  ? 'To ensure your beverages and hot bites are delivered piping hot, we created a separate order for your other grocery items. Track the Grocery order here.'
                  : 'To ensure your beverages and hot bites are delivered piping hot, we created a separate Cafe order for them. Track the Cafe order here.'}
              </p>
            </div>
            <Link
              href={`/order/${companionOrder.id}/track`}
              className="px-4 py-2 bg-white hover:bg-white/90 text-rose-600 font-extrabold rounded-xl text-xs transition-all shrink-0 shadow-sm active:scale-98"
            >
              {isCompanionCafe ? 'Track Cafe Order →' : 'Track Grocery Order →'}
            </Link>
          </div>
        )}
      </div>

      <OrderTracker initialOrder={order} />
    </div>
  )
}
