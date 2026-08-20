import { notFound, redirect } from 'next/navigation'
import Link from 'next/link'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { withRetry } from '@/lib/utils'
import { CheckCircle2, MapPin, Clock, ArrowRight } from 'lucide-react'
import { formatPrice, formatAddress } from '@/lib/utils'
import { formatDate } from '@/lib/date-helpers'
import { OrderSuccessEffects } from '@/components/shared/order-success-effects'
import { OrderConfirmationStatus } from '@/components/order/order-confirmation-status'
import { LockscreenAlertMockup } from '@/components/order/lockscreen-alert-mockup'
import { PayOnlineButton } from '@/components/order/pay-online-button'

interface OrderConfirmPageProps {
  params: Promise<{ id: string }>
}

export default async function OrderConfirmPage({ params }: OrderConfirmPageProps) {
  const session = await auth()
  if (!session?.user?.id) {
    redirect('/login')
  }

  const { id } = await params

  let order: any = null
  let companionOrder = null

  try {
    await withRetry(async () => {
      const orders: any[] = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone"
        FROM orders o WHERE o.id = ${id} LIMIT 1
      `

      if (orders.length > 0) {
        const orderRaw = orders[0]

        // Fetch items
        const items = await prisma.orderItem.findMany({
          where: { orderId: id },
        })

        // Fetch address
        const address = await prisma.address.findUnique({
          where: { id: orderRaw.addressId },
        })

        order = {
          ...orderRaw,
          items,
          address: address || {
            label: 'Pickup Location',
            houseNo: '',
            street: '',
            area: 'Hub Store',
            city: 'Kanpur',
            pincode: '209206',
            lat: 26.1534185,
            lng: 80.1714024,
          },
        }
      }
    })
  } catch (error) {
    console.error('Database connection error after retries: failed to fetch order details', error)
    throw error
  }

  if (!order) {
    notFound()
  }

  // Verify ownership
  if (order.userId !== session.user.id && session.user.role !== 'ADMIN') {
    redirect('/')
  }

  try {
    // If order belongs to a combined order group, merge companion order items and totals for customer view
    let combinedOrdersToMerge: any[] = []
    if (order.combinedId && typeof order.combinedId === 'string' && order.combinedId.trim().length > 0) {
      combinedOrdersToMerge = await prisma.order.findMany({
        where: { combinedId: order.combinedId },
        include: { items: true }
      })
    }

    if (combinedOrdersToMerge.length > 1) {
      const mergedItems = combinedOrdersToMerge.flatMap(o => o.items)
      const mergedSubtotal = combinedOrdersToMerge.reduce((sum, o) => sum + (o.subtotal || 0), 0)
      const mergedDiscount = combinedOrdersToMerge.reduce((sum, o) => sum + (o.discount || 0), 0)
      const mergedDeliveryFee = combinedOrdersToMerge.reduce((sum, o) => sum + (o.deliveryFee || 0), 0)
      const mergedTaxes = combinedOrdersToMerge.reduce((sum, o) => sum + (o.taxes || 0), 0)
      const mergedMiscFee = combinedOrdersToMerge.reduce((sum, o) => sum + (o.miscFee || 0), 0)
      const mergedTotal = combinedOrdersToMerge.reduce((sum, o) => sum + (o.total || 0), 0)

      order = {
        ...order,
        items: mergedItems,
        subtotal: mergedSubtotal,
        discount: mergedDiscount,
        deliveryFee: mergedDeliveryFee,
        taxes: mergedTaxes,
        miscFee: mergedMiscFee,
        total: mergedTotal,
        isCombined: true
      }
    }
  } catch (error) {
    console.warn('Database connection error: failed to merge combined order details', error)
  }

  // Fetch store settings for dynamic miscFeeLabel
  let miscFeeLabel = 'Miscellaneous Additions'
  try {
    const setting = await prisma.storeSetting.findUnique({
      where: { key: 'misc_fee_label' }
    })
    if (setting) {
      miscFeeLabel = setting.value
    }
  } catch (error) {
    console.warn('Database connection error: failed to fetch miscFeeLabel setting')
  }

  const isScheduled = order.estimatedDelivery && order.createdAt && 
    (new Date(order.estimatedDelivery).getTime() - new Date(order.createdAt).getTime() > 45 * 60 * 1000)


  return (
    <div className="container mx-auto px-3 min-[375px]:px-4 py-4 min-[375px]:py-8 max-w-3xl space-y-6 md:space-y-8 bg-background relative">
      {/* 60fps Canvas Confetti & Chime sound effects */}
      <OrderSuccessEffects />

      {/* Confirmation Success Hero Card (Modern Glassmorphism) */}
      <div className="relative z-10 flex flex-col items-center text-center p-6 min-[375px]:p-8 bg-gradient-to-b from-emerald-500/10 via-card to-card border border-emerald-500/20 dark:border-emerald-500/30 rounded-3xl shadow-xl animate-card-enter overflow-hidden">
        {/* Glow Ring */}
        <div className="absolute -top-20 -right-20 w-48 h-48 bg-emerald-500/15 rounded-full blur-3xl pointer-events-none" />

        <div className="h-20 w-20 bg-emerald-500/15 rounded-3xl flex items-center justify-center text-emerald-500 mb-4 border border-emerald-500/30 shadow-inner animate-status-pulse">
          <CheckCircle2 className="h-10 w-10 text-emerald-500 animate-bounce-subtle" />
        </div>

        <h1 className="text-2xl min-[375px]:text-3xl font-black text-text-primary tracking-tight">
          Order Placed Successfully!
        </h1>
        <p className="text-xs font-semibold text-text-secondary mt-1.5 max-w-sm">
          Thank you for shopping with FastKirana. Your order is registered and active!
        </p>

        {/* Animated Delivery Timeline */}
        <OrderConfirmationStatus
          orderId={order.id}
          initialStatus={order.status}
          deliveryMethod={order.deliveryMethod}
        />

        <div className="flex flex-col sm:flex-row gap-3 mt-6 w-full sm:w-auto">
          <Link
            href={`/order/${order.id}/track`}
            className="flex-1 sm:flex-initial flex items-center justify-center gap-2 px-7 py-3.5 bg-gradient-to-r from-primary via-primary/95 to-rose-600 hover:opacity-95 text-white font-black rounded-2xl text-xs transition-all shadow-lg hover:shadow-xl active:scale-95"
          >
            {order.deliveryMethod === 'PICKUP' ? 'Track Pickup Status 🏬' : 'Track Delivery Live ⚡'}
            <ArrowRight className="h-4 w-4" />
          </Link>
          <Link
            href="/"
            className="flex-1 sm:flex-initial px-6 py-3.5 border border-border/80 bg-card hover:bg-muted/40 font-black rounded-2xl text-xs transition-colors text-text-primary text-center"
          >
            Continue Shopping 🛍️
          </Link>
        </div>
      </div>

      <LockscreenAlertMockup orderId={order.id} deliveryMethod={order.deliveryMethod} />

      {/* Pay Online Option for COD Orders */}
      {order.paymentStatus !== 'PAID' && (
        <PayOnlineButton
          orderId={order.id}
          amount={order.total}
          readableId={order.readableId}
          variant="card"
        />
      )}

      {/* Summary grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5 md:gap-6">
        {/* Delivery schedules */}
        <div className="bg-card border border-border/80 p-5 rounded-3xl shadow-sm space-y-4 hover:border-primary/30 transition-colors">
          <h2 className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-2 border-b border-border/40 pb-3">
            <Clock className="h-4 w-4 text-primary" />
            {order.deliveryMethod === 'PICKUP' ? 'Pickup Schedule' : 'Delivery Schedule'}
          </h2>
          <div className="text-xs font-semibold text-text-primary space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-text-secondary">Estimated Arrival</span>
              <span className="px-3 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 text-xs font-black uppercase tracking-wider">
                {order.deliveryMethod === 'PICKUP' ? 'Instant Pickup' : '⚡ Arriving Soon'}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-text-secondary">{order.deliveryMethod === 'PICKUP' ? 'Pickup Date' : 'Delivery Date'}</span>
              <span className="font-bold">
                {formatDate(order.createdAt, 'd MMM yyyy')}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-text-secondary">Order Number</span>
              <span className="font-mono font-black text-primary bg-primary/10 px-2.5 py-1 rounded-xl text-xs border border-primary/20">
                #{order.readableId || order.id.slice(-6).toUpperCase()}
              </span>
            </div>
            <div className="flex justify-between items-center pt-1 border-t border-border/30">
              <span className="text-text-secondary">Order Reference</span>
              <span className="font-mono text-[9px] select-all bg-muted/70 text-text-secondary px-2 py-0.5 rounded-lg break-all font-bold">
                {order.id}
              </span>
            </div>
          </div>
        </div>

        {/* Saved Address Destination */}
        <div className="bg-card border border-border/80 p-5 rounded-3xl shadow-sm space-y-4 hover:border-primary/30 transition-colors flex flex-col justify-between">
          <div>
            <h2 className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-2 border-b border-border/40 pb-3">
              <MapPin className="h-4 w-4 text-primary" />
              {order.deliveryMethod === 'PICKUP' ? 'Pickup Location' : 'Delivery Destination'}
            </h2>
            <div className="mt-3">
              <span className="font-black uppercase bg-primary/10 text-primary px-2.5 py-1 rounded-lg text-[9px] border border-primary/20 tracking-wider">
                {order.address.label}
              </span>
              <p className="text-text-secondary text-xs leading-relaxed font-semibold mt-2.5">
                {formatAddress(order.address)}
              </p>
            </div>
          </div>
          <a
            href={
              order.address.lat && order.address.lng
                ? `https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`
                : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                    formatAddress(order.address)
                  )}`
            }
            target="_blank"
            rel="noopener noreferrer"
            className="mt-4 inline-flex items-center gap-1.5 text-xs font-black text-primary hover:underline bg-primary/5 hover:bg-primary/10 px-3.5 py-2 rounded-xl border border-primary/15 transition-all w-fit"
          >
            <span>📍</span> View Address on Google Maps
          </a>
        </div>

        {/* Fulfilling Shop */}
        {!order.isB2B && order.shopName && (
          <div className="bg-card border border-border/80 p-5 rounded-3xl shadow-sm space-y-3 md:col-span-2 hover:border-primary/30 transition-colors">
            <h2 className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-2 border-b border-border/40 pb-3">
              <span className="text-base">🏪</span>
              Fulfillment Center
            </h2>
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 text-xs font-semibold">
              <div>
                <p className="text-text-primary font-black text-sm">{order.shopName}</p>
                <p className="text-text-secondary mt-1 leading-relaxed text-[11px]">
                  {order.deliveryMethod === 'PICKUP'
                    ? 'Your order is packed and ready for pickup at our local FastKirana Ghatampur Hub.'
                    : 'Your order is packed and dispatched directly from our local FastKirana Dark Store to ensure maximum quality, safety, and instant delivery.'}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Receipt Summary */}
      <div className="bg-card border border-border/80 p-5 rounded-3xl shadow-sm space-y-4">
        <h2 className="text-xs font-black uppercase tracking-wider text-text-primary border-b border-border/40 pb-3">
          Receipt Summary
        </h2>
        <div className="text-xs font-semibold text-text-secondary space-y-2.5">
          {order.items.map((item: any) => (
            <div key={item.id} className="flex justify-between items-center text-text-primary">
              <span className="font-semibold">
                {item.name} <span className="text-text-secondary font-mono">× {item.quantity}</span>
              </span>
              <span className="font-bold">{formatPrice(item.price * item.quantity)}</span>
            </div>
          ))}
          <div className="flex justify-between pt-2 border-t border-border/30">
            <span className="text-text-secondary">Subtotal</span>
            <span className="font-bold">{formatPrice(order.subtotal)}</span>
          </div>
          {order.discount > 0 && (
            <div className="flex justify-between text-emerald-600 dark:text-emerald-400 font-bold">
              <span>Savings</span>
              <span>-{formatPrice(order.discount)}</span>
            </div>
          )}
          <div className="flex justify-between">
            <span className="text-text-secondary">Delivery Fee</span>
            <span className="font-bold">{order.deliveryFee === 0 ? 'FREE' : formatPrice(order.deliveryFee)}</span>
          </div>
          {order.taxes > 0 && (
            <div className="flex justify-between">
              <span className="text-text-secondary">GST / Taxes</span>
              <span className="font-bold">{formatPrice(order.taxes)}</span>
            </div>
          )}
          {order.miscFee > 0 && (
            <div className="flex justify-between">
              <span className="text-text-secondary">{miscFeeLabel}</span>
              <span className="font-bold">{formatPrice(order.miscFee)}</span>
            </div>
          )}
          <div className="flex justify-between items-center text-base font-black text-text-primary border-t border-border/40 pt-3.5 mt-3">
            <span>Total Paid ({order.paymentMethod === 'COD' ? (order.deliveryMethod === 'PICKUP' ? 'COP' : 'COD') : order.paymentMethod})</span>
            <span className="text-primary text-lg">{formatPrice(order.total)}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
