import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

/**
 * Server-side KOT Broadcast API
 * 
 * Fallback for when the client-side Supabase broadcast fails.
 * Creates a server-side Supabase client, subscribes to the channel,
 * sends the broadcast, then cleans up.
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { orderId, readableId } = body

    if (!orderId) {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co'
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''

    const supabase = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    })

    const channel = supabase.channel('restaurant-orders-live')

    // Subscribe and wait for connection
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Channel subscribe timeout')), 8000)
      channel.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          clearTimeout(timeout)
          resolve()
        } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          clearTimeout(timeout)
          reject(new Error(`Channel status: ${status}`))
        }
      })
    })

    // Send the broadcast
    await channel.send({
      type: 'broadcast',
      event: 'reprint-kot',
      payload: { orderId, readableId }
    })

    // Keep alive briefly for propagation
    await new Promise((resolve) => setTimeout(resolve, 1500))

    // Cleanup
    supabase.removeChannel(channel)

    return NextResponse.json({ success: true, orderId })
  } catch (error: any) {
    console.error('[KOT Broadcast API] Error:', error.message)
    return NextResponse.json(
      { error: 'Failed to send KOT broadcast', detail: error.message },
      { status: 500 }
    )
  }
}
