import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { auth } from '@/auth'

/**
 * Server-side KOT Broadcast API
 * 
 * Single authoritative gateway for KOT dispatch.
 * Strictly gated so only Admin / Staff or manual dispatch triggers kitchen prints.
 * Automatically ignores automated checkout calls from legacy APK versions.
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

    // 🛡️ Legacy APK Protection:
    // If a customer checkout from an older APK version tries to auto-broadcast KOT,
    // intercept it and return 200 without broadcasting to the kitchen.
    const session = await auth()
    const headerRole = request.headers.get('x-user-role')?.toUpperCase()
    const headerPhone = request.headers.get('x-user-phone')
    const role = (session?.user as any)?.role?.toUpperCase() || headerRole
    const userPhone = (session?.user as any)?.phone || headerPhone
    const isAdminOrStaff = role === 'ADMIN' || role === 'RESTAURANT_OWNER' || role === 'CHEF' || userPhone === '8112849854'
    const isManualAdminDispatch = Boolean(
      body.manual === true ||
      body.isManualAdminDispatch === true ||
      body.source === 'orders_tab' ||
      body.source === 'admin_console' ||
      body.source === 'kitchen_console' ||
      (body.kotText && body.kotText.includes('FASTKIRANA KOT'))
    )

    if (!isAdminOrStaff && !isManualAdminDispatch) {
      console.log(`[KOT Broadcast API] 🛡️ Ignored legacy checkout auto-KOT for Order #${cleanReadable || cleanId}`)
      return NextResponse.json({ success: true, ignored: true, reason: 'Auto-KOT on checkout disabled' })
    }

    const lastBroadcastId = recentBroadcastTimestamps.get(cleanId)
    const lastBroadcastReadable = cleanReadable ? recentBroadcastTimestamps.get(cleanReadable) : undefined
    const lastBroadcastBase = baseReadable ? recentBroadcastTimestamps.get(baseReadable) : undefined
    const lastBroadcast = Math.max(lastBroadcastId || 0, lastBroadcastReadable || 0, lastBroadcastBase || 0)

    // Manual admin dispatches have a 2s debounce; automated triggers have 10s
    const cooldownWindow = isManualAdminDispatch ? 2000 : 10000
    if (lastBroadcast > 0 && (now - lastBroadcast) < cooldownWindow) {
      console.log(`[KOT Broadcast API] 🛡️ Ignored duplicate broadcast for #${cleanReadable || cleanId} (${Math.round((cooldownWindow - (now - lastBroadcast)) / 1000)}s cooldown active)`)
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

    // 🛡️ Persistent Offline Queue (Strict Anti-Duplicate Protection):
    // If this order is ALREADY waiting in PENDING queue, update it rather than inserting a duplicate row!
    try {
      const { data: existingPending } = await supabase
        .from('kitchen_kot_queue')
        .select('id')
        .or(`order_id.eq.${cleanId},readable_id.eq.${cleanReadable || cleanId}`)
        .eq('status', 'PENDING')
        .maybeSingle()

      if (existingPending) {
        await supabase
          .from('kitchen_kot_queue')
          .update({
            payload: payloadWithRest,
            readable_id: cleanReadable || cleanId,
            restaurant_id: targetRestaurantId || null,
            created_at: new Date().toISOString(),
          })
          .eq('id', existingPending.id)
        console.log(`[KOT Broadcast API] 🛡️ Anti-Duplicate: Order #${cleanReadable || cleanId} already in queue, updated existing pending row`)
      } else {
        await supabase.from('kitchen_kot_queue').insert({
          order_id: cleanId,
          readable_id: cleanReadable || cleanId,
          restaurant_id: targetRestaurantId || null,
          payload: payloadWithRest,
          status: 'PENDING',
          created_at: new Date().toISOString(),
        })
        console.log(`[KOT Broadcast API] 📦 Enqueued Order #${cleanReadable || cleanId} into persistent kitchen_kot_queue`)
      }
    } catch (queueErr: any) {
      console.warn('[KOT Broadcast API] Warning: Failed to insert/update kitchen_kot_queue:', queueErr?.message)
    }

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
