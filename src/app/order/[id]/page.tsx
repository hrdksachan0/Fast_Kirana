import { notFound, redirect } from 'next/navigation'
import Link from 'next/link'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { CheckCircle2, MapPin, Clock, ArrowRight } from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { OrderSuccessEffects } from '@/components/shared/order-success-effects'
import { OrderConfirmationStatus } from '@/components/order/order-confirmation-status'
import { LockscreenAlertMockup } from '@/components/order/lockscreen-alert-mockup'

interface OrderConfirmPageProps {
  params: Promise<{ id: string }>
}

export default async function OrderConfirmPage({ params }: OrderConfirmPageProps) {
  const session = await auth()
  if (!session?.user?.id) {
    redirect('/login')
  }

  const { id } = await params

  let order = null
  let companionOrder = null

  try {
    order = await prisma.order.findUnique({
      where: { id },
      include: {
        items: true,
        address: true,
      },
    })
  } catch (error) {
    console.warn('Database connection error: failed to fetch order details')
  }

  if (!order) {
    notFound()
  }

  // Verify ownership
  if (order.userId !== session.user.id && session.user.role !== 'ADMIN') {
    redirect('/')
  }

  try {
    // Find other orders placed by the same user within 5 seconds of this order
    const fiveSecondsAgo = new Date(order.createdAt.getTime() - 5000)
    const fiveSecondsAfter = new Date(order.createdAt.getTime() + 5000)
    companionOrder = await prisma.order.findFirst({
      where: {
        userId: order.userId,
        id: { not: order.id },
        createdAt: {
          gte: fiveSecondsAgo,
          lte: fiveSecondsAfter,
        },
      },
    })
  } catch (error) {
    console.warn('Database connection error: failed to fetch companion order')
  }

  const isCafeOrder = order.shopName === 'FastKirana Cafe Kitchen'
  const isCompanionCafe = companionOrder?.shopName === 'FastKirana Cafe Kitchen'

  const isScheduled = order.estimatedDelivery && order.createdAt && 
    (new Date(order.estimatedDelivery).getTime() - new Date(order.createdAt).getTime() > 15 * 60 * 1000)

  return (
    <div className="container mx-auto px-2.5 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl space-y-6 md:space-y-8 bg-background relative">
      {/* 60fps Canvas Confetti & Chime sound effects */}
      <OrderSuccessEffects />

      {companionOrder && (
        <div className="bg-gradient-to-r from-rose-500 via-pink-500 to-orange-500 p-4 rounded-2xl text-white shadow-md flex flex-col md:flex-row justify-between items-start md:items-center gap-4 animate-slide-up relative z-10">
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
            href={`/order/${companionOrder.id}`}
            className="px-4 py-2 bg-white hover:bg-white/90 text-rose-600 font-extrabold rounded-xl text-xs transition-all shrink-0 shadow-sm active:scale-98"
          >
            {isCompanionCafe ? 'Track Cafe Order →' : 'Track Grocery Order →'}
          </Link>
        </div>
      )}

      {/* Confirmation success block */}
      <div className="relative z-10 flex flex-col items-center text-center p-4 min-[375px]:p-6 bg-card border border-border/80 dark:border-zinc-800/60 rounded-3xl shadow-lg animate-card-enter">
        <div className="h-16 w-16 bg-accent/10 rounded-full flex items-center justify-center text-accent mb-4 border border-accent/20 animate-status-pulse">
          <CheckCircle2 className="h-9 w-9 text-accent animate-bounce-subtle" />
        </div>
        <h1 className="text-2xl font-black text-text-primary tracking-tight">Order Placed Successfully!</h1>
        <p className="text-xs text-text-secondary mt-1">Thank you for shopping. Your order has been registered.</p>
        
        {/* Animated Delivery Timeline (Client Component for live status updates) */}
        <OrderConfirmationStatus
          orderId={order.id}
          initialStatus={order.status}
          deliveryMethod={order.deliveryMethod}
        />

        <div className="flex gap-3 mt-6 w-full sm:w-auto">
          <Link
            href={`/order/${order.id}/track`}
            className="flex-1 sm:flex-initial flex items-center justify-center gap-1.5 px-6 py-3 bg-primary hover:bg-primary/95 text-white font-black rounded-xl text-xs transition-all shadow-md hover:shadow-lg active:scale-[0.98]"
          >
            {order.deliveryMethod === 'PICKUP' ? 'Track Pickup Status' : 'Track Delivery Live'}
            <ArrowRight className="h-4 w-4" />
          </Link>
          <Link
            href="/"
            className="flex-1 sm:flex-initial px-6 py-3 border border-border bg-card hover:bg-muted/30 font-black rounded-xl text-xs transition-colors text-text-primary"
          >
            Continue Shopping
          </Link>
        </div>
      </div>

      <LockscreenAlertMockup orderId={order.id} />

      {/* Summary grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Delivery schedules */}
        <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-4">
          <h2 className="text-sm font-bold text-text-primary flex items-center gap-2 border-b border-border/40 pb-2">
            <Clock className="h-4 w-4 text-primary" />
            {order.deliveryMethod === 'PICKUP' ? 'Pickup Schedule' : 'Delivery Schedule'}
          </h2>
          <div className="text-xs font-semibold text-text-primary space-y-2">
            <div className="flex justify-between">
              <span className="text-text-secondary">Estimated Arrival</span>
              <span className="text-accent font-bold">
                {isScheduled && order.estimatedDelivery
                  ? `${new Date(order.estimatedDelivery).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}`
                  : order.deliveryMethod === 'PICKUP' ? 'Instant Pickup' : 'Fast Delivery'}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-secondary">{order.deliveryMethod === 'PICKUP' ? 'Pickup Date' : 'Delivery Date'}</span>
              <span>
                {new Date(order.createdAt).toLocaleDateString('en-IN', {
                  day: 'numeric',
                  month: 'short',
                  year: 'numeric',
                })}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-secondary">Order ID</span>
              <span className="font-mono text-[10px] select-all bg-muted px-1.5 py-0.5 rounded break-all">{order.id}</span>
            </div>
          </div>
        </div>

        {/* Saved Addresses destination */}
        <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-4">
          <h2 className="text-sm font-bold text-text-primary flex items-center gap-2 border-b border-border/40 pb-2">
            <MapPin className="h-4 w-4 text-primary" />
            {order.deliveryMethod === 'PICKUP' ? 'Pickup Location' : 'Delivery Destination'}
          </h2>
          <div className="text-xs flex flex-col justify-between h-[calc(100%-2rem)]">
            <div>
              <span className="font-extrabold uppercase bg-muted px-2 py-0.5 rounded text-[10px]">
                {order.address.label}
              </span>
              <p className="text-text-secondary leading-relaxed font-semibold mt-2">
                House No {order.address.houseNo}, {order.address.street}, {order.address.area}, {order.address.city} - {order.address.pincode}
              </p>
            </div>
            <a
              href={
                order.address.lat && order.address.lng
                  ? `https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`
                  : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                      `${order.address.houseNo} ${order.address.street} ${order.address.area} ${order.address.city} ${order.address.pincode}`
                    )}`
              }
              target="_blank"
              rel="noopener noreferrer"
              className="mt-3 inline-flex items-center gap-1 text-[11px] font-black text-accent hover:underline w-fit"
            >
              📍 View Address on Google Maps
            </a>
          </div>
        </div>

        {/* Fulfilling Shop */}
        {!order.isB2B && order.shopName && (
          <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-4 md:col-span-2">
            <h2 className="text-sm font-bold text-text-primary flex items-center gap-2 border-b border-border/40 pb-2">
              <span className="text-base">🏪</span>
              Fulfillment Center
            </h2>
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 text-xs font-semibold">
              <div>
                <p className="text-text-primary font-black text-sm">{order.shopName}</p>
                <p className="text-text-secondary mt-1">
                  {order.deliveryMethod === 'PICKUP'
                    ? 'Your order is packed and ready for pickup at our local FastKirana Ghatampur Hub.'
                    : 'Your order is packed and dispatched directly from our local FastKirana Dark Store to ensure maximum quality, safety, and instant delivery.'}
                </p>
              </div>
              {order.shopPhone && (
                <a
                  href={`tel:${order.shopPhone}`}
                  className="px-4 py-2 bg-primary/10 hover:bg-primary/20 text-primary font-black rounded-xl transition-all flex items-center gap-1.5 shrink-0"
                >
                  <span>📞</span> Call Shop
                </a>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Reciept Summary */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-4">
        <h2 className="text-sm font-bold text-text-primary border-b border-border/40 pb-2">
          Receipt Sum
        </h2>
        <div className="text-xs font-semibold text-text-secondary space-y-2.5">
          {order.items.map((item) => (
            <div key={item.id} className="flex justify-between">
              <span>
                {item.name} × {item.quantity}
              </span>
              <span>{formatPrice(item.price * item.quantity)}</span>
            </div>
          ))}
          <div className="flex justify-between">
            <span className="text-text-secondary">Subtotal</span>
            <span>{formatPrice(order.subtotal)}</span>
          </div>
          {order.discount > 0 && (
            <div className="flex justify-between text-accent font-bold">
              <span>Savings</span>
              <span>-{formatPrice(order.discount)}</span>
            </div>
          )}
          <div className="flex justify-between">
            <span className="text-text-secondary">Delivery Fee</span>
            <span>{order.deliveryFee === 0 ? 'FREE' : formatPrice(order.deliveryFee)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-text-secondary">GST / Taxes (5%)</span>
            <span>{formatPrice(order.taxes)}</span>
          </div>
          <div className="flex justify-between text-base font-black text-text-primary border-t border-border/40 pt-3 mt-3">
            <span>Amount Paid ({order.paymentMethod === 'COD' ? (order.deliveryMethod === 'PICKUP' ? 'COP' : 'COD') : order.paymentMethod})</span>
            <span className="text-primary">{formatPrice(order.total)}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
