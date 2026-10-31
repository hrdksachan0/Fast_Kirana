import { prisma } from '@/lib/prisma'
import { sendPushNotification } from '@/lib/push-notification'
import { sseEmitter } from '@/lib/sse-emitter'

/**
 * Calculates straight-line distance in kilometers between two GPS coordinates using Haversine formula.
 */
export function calculateDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371 // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

export interface BatchResult {
  batched: boolean
  targetOrderId: string
  pairedOrderId?: string
  pairedReadableId?: string
  riderId?: string
  distanceKm?: number
  reason?: string
}

export class RiderBatchingService {
  public static readonly MAX_BATCH_RADIUS_KM = 1.5 // Multi-drop route maximum gap (1.5 km)
  public static readonly MAX_BATCH_ORDERS_PER_RIDER = 2 // Strict limit: max 2 orders per rider to preserve 10-15m ETA
  public static readonly MAX_CANDIDATE_AGE_MINUTES = 25 // Time window for orders dispatched together

  /**
   * Attempts to auto-batch an incoming or ready order with another order heading in the same route.
   */
  static async attemptAutoBatchForOrder(targetOrderId: string): Promise<BatchResult> {
    try {
      const targetOrder = await prisma.order.findUnique({
        where: { id: targetOrderId },
        select: {
          id: true,
          readableId: true,
          storeId: true,
          status: true,
          deliveryLat: true,
          deliveryLng: true,
          deliveryUserId: true,
          createdAt: true,
          notes: true,
        },
      })

      if (!targetOrder) {
        return { batched: false, targetOrderId, reason: 'Order not found' }
      }

      if (!targetOrder.deliveryLat || !targetOrder.deliveryLng) {
        return { batched: false, targetOrderId, reason: 'Target order missing delivery GPS coordinates' }
      }

      if (!targetOrder.storeId) {
        return { batched: false, targetOrderId, reason: 'Target order not associated with a specific dark store hub' }
      }

      // Check if target order is in a batchable status
      const validStatuses = ['CONFIRMED', 'PACKED', 'SHIPPED']
      if (!validStatuses.includes(targetOrder.status)) {
        return { batched: false, targetOrderId, reason: `Status ${targetOrder.status} not eligible for batching` }
      }

      const cutoffTime = new Date(Date.now() - this.MAX_CANDIDATE_AGE_MINUTES * 60 * 1000)

      // Find candidates from the same dark store hub created within the time window
      const candidates = await prisma.order.findMany({
        where: {
          storeId: targetOrder.storeId,
          id: { not: targetOrderId },
          status: { in: ['CONFIRMED', 'PACKED', 'SHIPPED'] },
          createdAt: { gte: cutoffTime },
          deliveryLat: { not: null },
          deliveryLng: { not: null },
        },
        select: {
          id: true,
          readableId: true,
          deliveryLat: true,
          deliveryLng: true,
          deliveryUserId: true,
          status: true,
          notes: true,
        },
        orderBy: { createdAt: 'desc' },
        take: 20,
      })

      if (candidates.length === 0) {
        return { batched: false, targetOrderId, reason: 'No recent candidates at this hub' }
      }

      // Find the closest candidate within MAX_BATCH_RADIUS_KM
      let closestCandidate: (typeof candidates)[0] | null = null
      let minDistanceKm = Infinity

      for (const candidate of candidates) {
        if (!candidate.deliveryLat || !candidate.deliveryLng) continue

        const dist = calculateDistanceKm(
          targetOrder.deliveryLat,
          targetOrder.deliveryLng,
          candidate.deliveryLat,
          candidate.deliveryLng
        )

        if (dist <= this.MAX_BATCH_RADIUS_KM && dist < minDistanceKm) {
          // If candidate already has a rider, check if that rider has capacity
          if (candidate.deliveryUserId) {
            const activeDeliveriesCount = await prisma.order.count({
              where: {
                deliveryUserId: candidate.deliveryUserId,
                status: { in: ['PACKED', 'SHIPPED'] },
              },
            })

            if (activeDeliveriesCount >= this.MAX_BATCH_ORDERS_PER_RIDER) {
              continue // Rider is full, check next candidate
            }
          }

          minDistanceKm = dist
          closestCandidate = candidate
        }
      }

      if (!closestCandidate) {
        return {
          batched: false,
          targetOrderId,
          reason: `No candidates within ${this.MAX_BATCH_RADIUS_KM} km threshold`,
        }
      }

      const assignedRiderId = closestCandidate.deliveryUserId || targetOrder.deliveryUserId

      if (assignedRiderId) {
        // Assign target order to the same rider
        const batchTag = `[BATCH #${closestCandidate.readableId || closestCandidate.id.slice(-6)} - ${minDistanceKm.toFixed(1)}km away]`
        const updatedNotes = targetOrder.notes ? `${targetOrder.notes} ${batchTag}` : batchTag

        await prisma.order.update({
          where: { id: targetOrderId },
          data: {
            deliveryUserId: assignedRiderId,
            notes: updatedNotes,
          },
        })

        // Notify Rider with FCM Push
        try {
          await sendPushNotification(assignedRiderId, {
            title: '🛵 Multi-Delivery Batch Assigned!',
            body: `Order #${targetOrder.readableId || targetOrder.id.slice(-6)} is on your route (${minDistanceKm.toFixed(1)}km from Order #${closestCandidate.readableId || closestCandidate.id.slice(-6)}).`,
            data: {
              type: 'BATCH_ASSIGNMENT',
              orderId: targetOrderId,
              pairedOrderId: closestCandidate.id,
              distanceKm: minDistanceKm.toFixed(2),
              screen: 'delivery',
            },
          })
        } catch (pushErr) {
          console.warn('[RiderBatching] Push alert notice:', pushErr)
        }

        // Emit SSE to live rider and admin dashboards
        try {
          sseEmitter.emit('order:assigned', {
            orderId: targetOrderId,
            deliveryUserId: assignedRiderId,
            isBatched: true,
            pairedOrderId: closestCandidate.id,
            distanceKm: minDistanceKm,
          })
        } catch (_) {}

        console.log(
          `[RiderBatching] Successfully batched Order #${targetOrder.readableId} with Order #${closestCandidate.readableId} to Rider ${assignedRiderId} (${minDistanceKm.toFixed(2)} km apart)`
        )

        return {
          batched: true,
          targetOrderId,
          pairedOrderId: closestCandidate.id,
          pairedReadableId: closestCandidate.readableId || undefined,
          riderId: assignedRiderId,
          distanceKm: minDistanceKm,
        }
      }

      return {
        batched: true,
        targetOrderId,
        pairedOrderId: closestCandidate.id,
        pairedReadableId: closestCandidate.readableId || undefined,
        distanceKm: minDistanceKm,
        reason: 'Orders clustered; awaiting rider claim',
      }
    } catch (error) {
      console.error('[RiderBatching] Exception in attemptAutoBatchForOrder:', error)
      return { batched: false, targetOrderId, reason: String(error) }
    }
  }

  /**
   * Returns active batched orders for a rider, sorted by delivery sequence.
   */
  static async getActiveBatchForRider(riderId: string) {
    return prisma.order.findMany({
      where: {
        deliveryUserId: riderId,
        status: { in: ['PACKED', 'SHIPPED'] },
      },
      include: {
        address: true,
        items: true,
      },
      orderBy: { createdAt: 'asc' },
    })
  }
}
