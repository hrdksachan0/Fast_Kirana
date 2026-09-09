import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

/**
 * Server-side KOT Broadcast API
 * 
 * Fallback for when the client-side Supabase broadcast fails.
 * Creates a server-side Supabase client, subscribes to the channel,
 * sends the broadcast, then cleans up.
 */
// Server-side deduplication window (10 seconds) to prevent duplicate KOT ticket prints
const recentBroadcastTimestamps = new Map<string, number>()

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { orderId, readableId } = body

    if (!orderId) {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const cleanId = String(orderId).trim().replace(/^#/, '')
    const cleanReadable = readableId ? String(readableId).trim().replace(/^#/, '') : ''
    const baseReadable = cleanReadable.replace(/-[GR\d]+$/i, '')
    const now = Date.now()

    const lastBroadcastId = recentBroadcastTimestamps.get(cleanId)
    const lastBroadcastReadable = cleanReadable ? recentBroadcastTimestamps.get(cleanReadable) : undefined
    const lastBroadcastBase = baseReadable ? recentBroadcastTimestamps.get(baseReadable) : undefined
    const lastBroadcast = Math.max(lastBroadcastId || 0, lastBroadcastReadable || 0, lastBroadcastBase || 0)

    if (lastBroadcast > 0 && (now - lastBroadcast) < 10000) {
      console.log(`[KOT Broadcast API] 🛡️ Ignored duplicate broadcast for #${cleanReadable || cleanId} (${Math.round((10000 - (now - lastBroadcast)) / 1000)}s cooldown active)`)
      return NextResponse.json({ success: true, orderId: cleanId, deduped: true })
    }
    recentBroadcastTimestamps.set(cleanId, now)
    if (cleanReadable) recentBroadcastTimestamps.set(cleanReadable, now)
    if (baseReadable) recentBroadcastTimestamps.set(baseReadable, now)

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co'
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''

    let targetRestaurantId = body.restaurantId
    if (!targetRestaurantId && cleanId) {
      try {
        const { prisma } = await import('@/lib/prisma')
        const orderRecord = await prisma.order.findUnique({
          where: { id: cleanId },
          select: { restaurantId: true }
        })
        if (orderRecord?.restaurantId) {
          targetRestaurantId = orderRecord.restaurantId
        }
      } catch (_) {}
    }

    const payloadWithRest = {
      ...body,
      restaurantId: targetRestaurantId || body.restaurantId || null,
    }

    const supabase = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    })

    const channelsToNotify = ['restaurant-orders-live']
    if (targetRestaurantId) {
      channelsToNotify.push(`restaurant-orders-${targetRestaurantId}`)
    }

    await Promise.all(
      channelsToNotify.map(async (chName) => {
        try {
          const ch = supabase.channel(chName)
          await new Promise<void>((resolve, reject) => {
            const timeout = setTimeout(() => reject(new Error(`Timeout subscribing to ${chName}`)), 6000)
            ch.subscribe((status) => {
              if (status === 'SUBSCRIBED') {
                clearTimeout(timeout)
                resolve()
              } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
                clearTimeout(timeout)
                reject(new Error(`Status: ${status}`))
              }
            })
          })

          await ch.send({
            type: 'broadcast',
            event: 'reprint-kot',
            payload: payloadWithRest,
          })

          setTimeout(() => {
            try { supabase.removeChannel(ch) } catch (_) {}
          }, 2000)
        } catch (err: any) {
          console.warn(`[KOT Broadcast API] Failed broadcast on ${chName}:`, err?.message)
        }
      })
    )

    return NextResponse.json({ success: true, orderId, restaurantId: targetRestaurantId })
  } catch (error: any) {
    console.error('[KOT Broadcast API] Error:', error.message)
    return NextResponse.json(
      { error: 'Failed to send KOT broadcast', detail: error.message },
      { status: 500 }
    )
  }
}
