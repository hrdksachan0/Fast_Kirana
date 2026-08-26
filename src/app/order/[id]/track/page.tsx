import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { redirect } from 'next/navigation'
import { TrackingPageClient } from '@/components/order/tracking-page-client'

interface OrderTrackingPageProps {
  params: Promise<{ id: string }>
}

export const dynamic = 'force-dynamic'

async function getOrderDetails(id: string) {
  try {
    const orders: any[] = await prisma.$queryRaw`
      SELECT o.id, o."userId", o."addressId", o."readableId",
             o.status::text as status,
             o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
             o."paymentMethod"::text as "paymentMethod",
             o."paymentStatus"::text as "paymentStatus",
             o."estimatedDelivery", o."createdAt", o."updatedAt",
             o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
             o."deliveryUserId",
             o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
             o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
             o.notes, o."couponCode"
      FROM orders o WHERE o.id = ${id} OR o."readableId" = ${id} LIMIT 1
    `

    if (orders.length === 0) return null
    const order = orders[0]

    // Fetch address
    const address = await prisma.address.findUnique({
      where: { id: order.addressId },
    })

    // Fetch delivery user details
    let deliveryUser = null
    if (order.deliveryUserId) {
      const riders: any[] = await prisma.$queryRaw`
        SELECT id, name, phone, role::text as role, "liveLat", "liveLng" FROM users WHERE id = ${order.deliveryUserId} LIMIT 1
      `
      if (riders.length > 0) {
        let name = riders[0].name
        let phone = riders[0].phone
        if (riders[0].role === 'ADMIN' || name === 'Admin') {
          const mainRider: any[] = await prisma.$queryRaw`
            SELECT name, phone FROM users WHERE role::text = 'DELIVERY' LIMIT 1
          `
          if (mainRider.length > 0) {
            name = mainRider[0].name || 'FastKirana Delivery Executive'
            phone = mainRider[0].phone || '+919696503759'
          } else {
            name = 'FastKirana Delivery Executive'
            phone = '+919696503759'
          }
        }
        deliveryUser = { name, phone }
        if (riders[0].liveLat !== null && riders[0].liveLng !== null) {
          order.deliveryLat = riders[0].liveLat
          order.deliveryLng = riders[0].liveLng
        }
      }
    }

    // If order has combinedId, merge all sub-orders into unified response
    if (order.combinedId && typeof order.combinedId === 'string' && order.combinedId.trim().length > 0) {
      const combinedOrders: any[] = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
               o."deliveryUserId",
               o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
               o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
               o.notes, o."couponCode"
        FROM orders o WHERE o."combinedId" = ${order.combinedId}
        ORDER BY o."createdAt" ASC
      `

      if (combinedOrders.length > 0) {
        const combinedOrderIds = combinedOrders.map(o => o.id)
        const allItems = await prisma.orderItem.findMany({
          where: { orderId: { in: combinedOrderIds } }
        })

        function getCombinedStatus(statuses: string[]): string {
          const active = statuses.filter(s => s !== 'CANCELLED')
          if (active.length === 0) return 'CANCELLED'
          if (active.includes('PENDING')) return 'PENDING'
          if (active.includes('CONFIRMED')) return 'CONFIRMED'
          if (active.includes('PACKED')) return 'PACKED'
          if (active.includes('SHIPPED')) return 'SHIPPED'
          return 'DELIVERED'
        }

        const statuses = combinedOrders.map(o => o.status)
        const combinedStatus = getCombinedStatus(statuses)
        const baseReadableId = (order.readableId || '').replace(/-[GR\d]+$/i, '') || order.readableId

        const subOrders = combinedOrders.map(o => {
          const subItems = allItems.filter(item => item.orderId === o.id)
          const isRest = (o.orderType === 'RESTAURANT' || !!o.restaurantId || (o.readableId && o.readableId.endsWith('-R')) || (o.shopName && o.shopName.toLowerCase().includes('restaurant')))
          return {
            id: o.id,
            readableId: o.readableId,
            type: isRest ? 'RESTAURANT' : 'GROCERY',
            shopName: isRest ? (o.shopName || 'Restaurant') : (o.shopName || 'FastKirana Dark Store'),
            status: o.status,
            subtotal: Number(o.subtotal || 0),
            total: Number(o.total || 0),
            itemsCount: subItems.length,
            items: subItems.map((i: any) => ({
              id: i.id,
              productId: i.productId,
              name: i.name,
              price: Number(i.price || 0),
              quantity: i.quantity,
              selectedVariant: i.selectedVariant || null,
              imageUrl: i.imageUrl || null,
              notes: i.notes || null,
              shopName: i.shopName || null,
            })),
          }
        })

        const grocerySub = subOrders.find(s => s.type === 'GROCERY')
        const restaurantSub = subOrders.find(s => s.type === 'RESTAURANT')

        return {
          ...order,
          readableId: baseReadableId,
          baseReadableId,
          status: combinedStatus,
          subtotal: combinedOrders.reduce((sum, o) => sum + Number(o.subtotal || 0), 0),
          discount: combinedOrders.reduce((sum, o) => sum + Number(o.discount || 0), 0),
          deliveryFee: combinedOrders.reduce((sum, o) => sum + Number(o.deliveryFee || 0), 0),
          taxes: combinedOrders.reduce((sum, o) => sum + Number(o.taxes || 0), 0),
          miscFee: combinedOrders.reduce((sum, o) => sum + Number(o.miscFee || 0), 0),
          total: combinedOrders.reduce((sum, o) => sum + Number(o.total || 0), 0),
          estimatedDelivery: order.estimatedDelivery ? new Date(order.estimatedDelivery).toISOString() : null,
          createdAt: order.createdAt ? new Date(order.createdAt).toISOString() : new Date().toISOString(),
          updatedAt: order.updatedAt ? new Date(order.updatedAt).toISOString() : new Date().toISOString(),
          items: allItems.map((i: any) => ({
            id: i.id,
            productId: i.productId,
            name: i.name,
            price: Number(i.price || 0),
            quantity: i.quantity,
            selectedVariant: i.selectedVariant || null,
            imageUrl: i.imageUrl || null,
            notes: i.notes || null,
            shopName: i.shopName || null,
          })),
          address: address || {
            label: 'Delivery Location',
            houseNo: '',
            street: '',
            area: 'Ghatampur',
            city: 'Kanpur',
            pincode: '209206',
            lat: 26.1534185,
            lng: 80.1714024,
          },
          deliveryUser,
          isCombined: true,
          groceryStatus: grocerySub?.status || null,
          groceryItems: grocerySub?.items || [],
          restaurantStatus: restaurantSub?.status || null,
          restaurantName: restaurantSub?.shopName || null,
          restaurantItems: restaurantSub?.items || [],
          subOrders,
        }
      }
    }

    // Default individual order details for non-combined orders
    const items = await prisma.orderItem.findMany({
      where: { orderId: order.id },
    })

    return {
      ...order,
      subtotal: Number(order.subtotal || 0),
      discount: Number(order.discount || 0),
      deliveryFee: Number(order.deliveryFee || 0),
      taxes: Number(order.taxes || 0),
      miscFee: Number(order.miscFee || 0),
      total: Number(order.total || 0),
      estimatedDelivery: order.estimatedDelivery ? new Date(order.estimatedDelivery).toISOString() : null,
      createdAt: order.createdAt ? new Date(order.createdAt).toISOString() : new Date().toISOString(),
      updatedAt: order.updatedAt ? new Date(order.updatedAt).toISOString() : new Date().toISOString(),
      items: items.map((i: any) => ({
        id: i.id,
        productId: i.productId,
        name: i.name,
        price: Number(i.price || 0),
        quantity: i.quantity,
        selectedVariant: i.selectedVariant || null,
        imageUrl: i.imageUrl || null,
        notes: i.notes || null,
        shopName: i.shopName || null,
      })),
      address: address || {
        label: 'Delivery Location',
        houseNo: '',
        street: '',
        area: 'Ghatampur',
        city: 'Kanpur',
        pincode: '209206',
        lat: 26.1534185,
        lng: 80.1714024,
      },
      readableId: order.readableId || order.id?.slice(0, 8),
      deliveryUser,
    }
  } catch (err) {
    console.error('Error pre-fetching order for track page:', err)
    return null
  }
}

export default async function OrderTrackingPage({ params }: OrderTrackingPageProps) {
  const session = await auth()
  if (!session?.user?.id) {
    redirect('/login')
  }

  const { id } = await params
  const initialOrder = await getOrderDetails(id)

  return <TrackingPageClient orderId={id} initialOrder={initialOrder} />
}
