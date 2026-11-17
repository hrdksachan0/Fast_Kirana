/**
 * Order Combiner Utility
 * Ensures that multi-vendor / combined orders (e.g., Grocery Darkstore + Restaurant Food)
 * are treated as a SINGLE unified delivery entity across Rider and Admin consoles.
 */

export interface UnifiedOrder {
  id: string
  combinedId?: string | null
  readableId?: string
  isCombined?: boolean
  companionOrder?: any | null
  subOrders?: any[]
  total: number
  combinedTotal?: number
  items: any[]
  status: string
  paymentMethod: string
  paymentStatus: string
  shopName?: string
  restaurantName?: string
  deliveryUserId?: string | null
  [key: string]: any
}

/**
 * Groups and merges orders sharing the same combinedId into a single unified order.
 * - Primary order (usually Grocery / Darkstore, or the first order) becomes the main container.
 * - Sibling order becomes `companionOrder`.
 * - All siblings are preserved in `subOrders` array.
 * - Combined total is calculated accurately without duplication.
 */
export function groupCombinedDeliveryOrders(rawOrders: any[]): any[] {
  if (!Array.isArray(rawOrders) || rawOrders.length === 0) return []

  const processedIds = new Set<string>()
  const result: any[] = []

  for (const order of rawOrders) {
    if (!order || !order.id) continue
    if (processedIds.has(order.id)) continue

    // Case A: Order is already grouped from backend (/api/orders format)
    if (order.isCombined && Array.isArray(order.subOrders) && order.subOrders.length > 1) {
      processedIds.add(order.id)
      const companion = order.companionOrder || order.subOrders.find((s: any) => s.id !== order.id) || order.subOrders[1]
      const totalAmount = order.subOrders.reduce((sum: number, s: any) => sum + (Number(s.total) || 0), 0)
      result.push({
        ...order,
        companionOrder: companion ? { ...companion } : null,
        combinedTotal: totalAmount || order.total,
      })
      continue
    }

    const combinedId = order.combinedId ? String(order.combinedId).trim() : null

    // Case B: Raw individual orders sharing the same combinedId
    if (combinedId) {
      const siblings = rawOrders.filter(
        (o) => o && o.id && !processedIds.has(o.id) && o.combinedId && String(o.combinedId).trim() === combinedId
      )

      if (siblings.length > 1) {
        siblings.forEach((s) => processedIds.add(s.id))

        // Prefer grocery/darkstore as primary order (no restaurantId)
        const primary = siblings.find((s) => !s.restaurantId && !s.restaurant) || siblings[0]
        const secondary = siblings.find((s) => s.id !== primary.id) || siblings[1]

        // Sum up total without double counting
        const totalAmount = siblings.reduce((sum: number, s: any) => sum + (Number(s.total) || 0), 0)

        // Composite shop name
        const primaryShop = primary.shopName || (primary.restaurantId ? 'Restaurant Kitchen' : 'FastMinute Hub')
        const secondaryShop = secondary?.shopName || (secondary?.restaurantId ? 'Restaurant Kitchen' : 'FastMinute Hub')
        const compositeShopName = primaryShop !== secondaryShop ? `${primaryShop} + ${secondaryShop}` : primaryShop

        const merged: any = {
          ...primary,
          isCombined: true,
          companionOrder: secondary ? { ...secondary } : null,
          subOrders: siblings.map((s: any) => ({
            id: s.id,
            readableId: s.readableId,
            shopName: s.shopName || (s.restaurantId ? 'Restaurant Kitchen' : 'FastMinute Hub'),
            status: s.status,
            total: s.total || 0,
            restaurantId: s.restaurantId,
            items: s.items || [],
            paymentMethod: s.paymentMethod,
            paymentStatus: s.paymentStatus,
          })),
          total: Number(primary.total) || 0,
          combinedTotal: totalAmount,
          items: primary.items || [],
          shopName: compositeShopName,
        }

        result.push(merged)
        continue
      }
    }

    // Case C: Standard standalone single order
    processedIds.add(order.id)
    result.push(order)
  }

  return result
}
