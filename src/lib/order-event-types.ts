// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FastMinute Unified Order Event Engine — Types & Declarative Rules Matrix
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export type OrderEventTag =
  | 'ORDER_CREATED'           // New order checkout placed
  | 'ORDER_STATUS_CHANGED'    // Any status transition (PENDING, CONFIRMED, PACKED, SHIPPED, DELIVERED, CANCELLED)
  | 'ORDER_ADMIN_APPROVED'    // ADMIN_PENDING -> CONFIRMED/PENDING
  | 'RIDER_ASSIGNED'          // Delivery partner assigned or reassigned
  | 'RIDER_LOCATION_UPDATE'   // Live GPS coordinates
  | 'PAYMENT_STATUS_CHANGED'  // Payment updated (PAID, REFUNDED, FAILED)
  | 'ORDER_ROUTE_UPDATED'     // Delivery route modified by admin
  | 'ORDER_EDITED'            // Items or quantities edited

export type AlertUrgency =
  | 'CRITICAL'  // Continuous loop siren until acknowledged (Admin & Store new order)
  | 'HIGH'      // Loud 1-shot alert + popup modal (Rider assignment, Kitchen order bell)
  | 'NORMAL'    // Soft pleasant chime + tick (Customer live status step)
  | 'LOW'       // Silent push / badge update only (Store list refresh)
  | 'SILENT'    // Data-only socket update (GPS coordinates, background sync)

export type EventTargetRole =
  | 'CUSTOMER'
  | 'ADMIN'
  | 'PICKER'
  | 'RIDER'
  | 'KITCHEN'
  | 'VENDOR'

export interface AlertConfig {
  urgency: AlertUrgency
  sound: string | null        // 'order_chime' | 'kitchen_order_bell' | 'order_placed_celebrate' | null
  title: string
  body: string
}

export interface OrderEventEnvelope {
  tag: OrderEventTag
  orderId: string             // Database CUID
  readableId: string          // "FK-4306-G" or "4306"
  displayId: string           // Base number without suffix "4306"
  combinedId: string | null   // Parent combined checkout token if multi-outlet
  storeId: string | null      // Hub ID e.g. "hub-209206"
  restaurantId: string | null // Restaurant ID if food order
  orderType: 'GROCERY' | 'RESTAURANT' | 'COMBINED'

  status: string              // Current/new OrderStatus
  previousStatus: string      // Previous OrderStatus
  paymentStatus: string       // Current PaymentStatus
  paymentMethod: string       // COD | UPI | CARD | WALLET

  actorId?: string            // User ID who made the change
  actorRole?: string          // Role of actor (ADMIN, PICKER, DELIVERY, CUSTOMER, SYSTEM)

  targets: EventTargetRole[]  // Roles that must receive and process this event

  alert: {
    customer?: AlertConfig
    admin?: AlertConfig
    picker?: AlertConfig
    rider?: AlertConfig
    kitchen?: AlertConfig
  }

  payload: Record<string, any>// Extra context (rider details, location, amounts, items)
  version: number             // Monotonic timestamp/counter for strict ordering
  timestamp: number           // Milliseconds unix epoch
}

/**
 * Single Source of Truth: Declarative Alert Matrix
 * Computes exact urgency, sound asset, title, and body for every party.
 */
export function resolveAlertMatrix(params: {
  tag: OrderEventTag
  newStatus: string
  previousStatus: string
  displayId: string
  outletSummary: string
  totalAmount: number
  isCombined: boolean
  isOnlinePaid: boolean
  riderName?: string
  riderPhone?: string
}): { targets: EventTargetRole[]; alert: OrderEventEnvelope['alert'] } {
  const {
    tag,
    newStatus,
    previousStatus,
    displayId,
    outletSummary,
    totalAmount,
    isCombined,
    isOnlinePaid,
    riderName,
  } = params

  const targets = new Set<EventTargetRole>()
  const alert: OrderEventEnvelope['alert'] = {}

  // 1. ORDER CREATION (Checkout landed)
  if (tag === 'ORDER_CREATED') {
    targets.add('CUSTOMER')
    targets.add('ADMIN')

    const hasAdminPending = newStatus === 'ADMIN_PENDING'

    // Customer Alert
    alert.customer = {
      urgency: 'NORMAL',
      sound: 'order_placed_celebrate',
      title: hasAdminPending
        ? '⏳ Order Placed — Waiting for Store Approval'
        : isOnlinePaid
        ? '💳 Order Confirmed & Paid!'
        : '🎉 Order Placed Successfully!',
      body: hasAdminPending
        ? `Order #${displayId} (${outletSummary}, ₹${totalAmount.toFixed(0)}) received and awaiting store confirmation.`
        : `Order #${displayId} (${outletSummary}, ₹${totalAmount.toFixed(0)}) is confirmed and will be delivered shortly.`,
    }

    // Admin Alert: Continuous loop siren for any new incoming order
    alert.admin = {
      urgency: 'CRITICAL',
      sound: 'order_chime',
      title: hasAdminPending
        ? `🚨 New Order #${displayId} Awaiting Approval!`
        : `🔔 New Live Order #${displayId}!`,
      body: `Order #${displayId} (${outletSummary}, ₹${totalAmount.toFixed(0)}). Tap to review & dispatch.`,
    }

    // If auto-approved immediately, notify pickers or kitchens
    if (!hasAdminPending) {
      if (params.isCombined || outletSummary.toLowerCase().includes('grocery')) {
        targets.add('PICKER')
        alert.picker = {
          urgency: 'HIGH',
          sound: 'order_chime',
          title: '📦 New Grocery Order to Pick!',
          body: `Order #${displayId} (₹${totalAmount.toFixed(0)}). Tap to start packing.`,
        }
      }
      if (params.isCombined || outletSummary.toLowerCase().includes('restaurant') || outletSummary.toLowerCase().includes('cafe')) {
        targets.add('KITCHEN')
        alert.kitchen = {
          urgency: 'HIGH',
          sound: 'kitchen_order_bell',
          title: '👨‍🍳 New Food Order Received!',
          body: `Order #${displayId} (${outletSummary}). Tap to open kitchen console.`,
        }
      }
    }

    return { targets: Array.from(targets), alert }
  }

  // 2. STATUS TRANSITIONS
  if (tag === 'ORDER_STATUS_CHANGED' || tag === 'ORDER_ADMIN_APPROVED') {
    // 2A. Admin Approved (ADMIN_PENDING -> CONFIRMED / PENDING)
    if (previousStatus === 'ADMIN_PENDING' || tag === 'ORDER_ADMIN_APPROVED') {
      targets.add('CUSTOMER')
      targets.add('ADMIN')
      targets.add('PICKER')
      targets.add('KITCHEN')

      alert.customer = {
        urgency: 'NORMAL',
        sound: 'order_placed_celebrate',
        title: '✅ Store Accepted Your Order!',
        body: `Order #${displayId} is confirmed and store/kitchen is preparing your items.`,
      }
      alert.admin = {
        urgency: 'LOW',
        sound: null,
        title: `Order #${displayId} Approved`,
        body: `Dispatched to store & kitchen consoles.`,
      }
      alert.picker = {
        urgency: 'HIGH',
        sound: 'order_chime',
        title: '📦 New Approved Order to Pick!',
        body: `Order #${displayId} is ready for shelf picking & packing.`,
      }
      alert.kitchen = {
        urgency: 'HIGH',
        sound: 'kitchen_order_bell',
        title: '👨‍🍳 Food Order Approved by Admin!',
        body: `Order #${displayId} is approved. Start cooking now!`,
      }
      return { targets: Array.from(targets), alert }
    }

    // 2B. Packed (Ready for delivery pickup)
    if (newStatus === 'PACKED') {
      targets.add('CUSTOMER')
      targets.add('ADMIN')
      targets.add('RIDER')

      alert.customer = {
        urgency: 'NORMAL',
        sound: 'order_placed_celebrate',
        title: '📦 Order Packed & Quality Checked',
        body: `Your items for #${displayId} are packed safely. Delivery rider arriving shortly.`,
      }
      alert.admin = {
        urgency: 'LOW',
        sound: null,
        title: `Order #${displayId} Packed`,
        body: `Waiting for rider pickup.`,
      }
      alert.rider = {
        urgency: 'HIGH',
        sound: 'order_chime',
        title: `🛵 Order #${displayId} Ready for Pickup!`,
        body: `Order #${displayId} (${outletSummary}) is packed and waiting at pickup counter.`,
      }
      return { targets: Array.from(targets), alert }
    }

    // 2C. Shipped (Rider picked up & out for delivery)
    if (newStatus === 'SHIPPED') {
      targets.add('CUSTOMER')
      targets.add('ADMIN')

      alert.customer = {
        urgency: 'NORMAL',
        sound: 'order_placed_celebrate',
        title: '🚴 Out for Delivery!',
        body: riderName
          ? `${riderName} is on the way to your doorstep with order #${displayId}.`
          : `Rider is on the way to your doorstep with order #${displayId}.`,
      }
      alert.admin = {
        urgency: 'LOW',
        sound: null,
        title: `Order #${displayId} In Transit`,
        body: `Rider en route to customer doorstep.`,
      }
      return { targets: Array.from(targets), alert }
    }

    // 2D. Delivered (Completed successfully)
    if (newStatus === 'DELIVERED') {
      targets.add('CUSTOMER')
      targets.add('ADMIN')

      alert.customer = {
        urgency: 'NORMAL',
        sound: 'order_placed_celebrate',
        title: '🎉 Delivered Successfully!',
        body: `Order #${displayId} handed over safely. Enjoy your items!`,
      }
      alert.admin = {
        urgency: 'LOW',
        sound: null,
        title: `Order #${displayId} Delivered`,
        body: `Successfully closed.`,
      }
      return { targets: Array.from(targets), alert }
    }

    // 2E. Cancelled
    if (newStatus === 'CANCELLED') {
      targets.add('CUSTOMER')
      targets.add('ADMIN')
      targets.add('PICKER')
      targets.add('KITCHEN')
      targets.add('RIDER')

      alert.customer = {
        urgency: 'NORMAL',
        sound: null,
        title: '❌ Order Cancelled',
        body: `Order #${displayId} has been cancelled. Any online payment has been initiated for refund.`,
      }
      alert.admin = {
        urgency: 'LOW',
        sound: null,
        title: `Order #${displayId} Cancelled`,
        body: `Order cancelled. Inventory restored.`,
      }
      alert.kitchen = {
        urgency: 'LOW',
        sound: null,
        title: `Order #${displayId} Cancelled`,
        body: `Stop food preparation for #${displayId}.`,
      }
      return { targets: Array.from(targets), alert }
    }
  }

  // 3. RIDER ASSIGNMENT
  if (tag === 'RIDER_ASSIGNED') {
    targets.add('RIDER')
    targets.add('CUSTOMER')
    targets.add('ADMIN')

    alert.rider = {
      urgency: 'HIGH',
      sound: 'order_chime',
      title: '🛵 New Delivery Assigned!',
      body: `Order #${displayId} (${outletSummary}, ₹${totalAmount.toFixed(0)}) has been assigned to you. Tap to accept.`,
    }
    alert.customer = {
      urgency: 'SILENT',
      sound: null,
      title: 'Rider Assigned',
      body: riderName ? `${riderName} will deliver your order.` : 'Rider assigned.',
    }
    alert.admin = {
      urgency: 'LOW',
      sound: null,
      title: `Rider Assigned to #${displayId}`,
      body: riderName || 'Rider assigned',
    }
    return { targets: Array.from(targets), alert }
  }

  // Default fallback for other tags
  targets.add('CUSTOMER')
  targets.add('ADMIN')
  alert.customer = {
    urgency: 'NORMAL',
    sound: null,
    title: `Order #${displayId} Updated`,
    body: `Status: ${newStatus}`,
  }
  alert.admin = {
    urgency: 'LOW',
    sound: null,
    title: `Order #${displayId} Updated`,
    body: `Status: ${newStatus}`,
  }
  return { targets: Array.from(targets), alert }
}
