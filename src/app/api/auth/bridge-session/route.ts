import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { createClient } from '@supabase/supabase-js'
import { getLast10Digits } from '@/lib/phone'

export async function POST(request: Request) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const email = session.user.email
    const phone = session.user.phone || (session.user as any).phoneNumber || null

    if (!email && !phone) {
      return NextResponse.json({ error: 'No email or phone in session' }, { status: 400 })
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

    if (!supabaseUrl || !serviceRoleKey) {
      return NextResponse.json(
        { status: 'skipped', message: 'Supabase Auth bridge not active' },
        { status: 200 }
      )
    }

    // Initialize Supabase Admin Client using private Service Role Key (bypasses RLS)
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    const digits = phone ? getLast10Digits(String(phone)) : ''
    const e164Phone = digits && digits.length === 10 ? `+91${digits}` : undefined
    const emailToUse = email || `${digits || session.user.id}@fastkirana.com`

    // 1. Try generating magic link directly for already-synced users (O(1), avoids listUsers pagination limits)
    let { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: emailToUse,
    })

    // 2. If user does not exist in auth.users yet, create with secure app_metadata and generate link
    if (linkError) {
      const { error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: emailToUse,
        phone: e164Phone,
        email_confirm: true,
        phone_confirm: Boolean(e164Phone),
        app_metadata: {
          publicUserId: session.user.id,
          role: session.user.role || 'USER',
          assignedStoreId: (session.user as any).assignedStoreId || null,
          assignedRestaurantId: (session.user as any).assignedRestaurantId || null,
        },
      })

      if (
        createError &&
        !createError.message.includes('already exists') &&
        createError.code !== 'email_exists' &&
        createError.code !== 'phone_exists'
      ) {
        console.error('Error creating user in Supabase Auth:', createError)
        return NextResponse.json(
          { error: 'Failed to sync user to authentication system: ' + createError.message },
          { status: 500 }
        )
      }

      const retry = await supabaseAdmin.auth.admin.generateLink({
        type: 'magiclink',
        email: emailToUse,
      })
      linkData = retry.data
      linkError = retry.error
    }

    if (linkError || !linkData?.properties?.action_link) {
      throw linkError || new Error('Failed to generate magic link')
    }

    const url = new URL(linkData.properties.action_link)
    const token_hash = url.searchParams.get('token')

    return NextResponse.json({ token_hash })

  } catch (err: any) {
    console.error('Session bridge API error:', err)
    return NextResponse.json(
      { error: 'Internal Server Error: ' + err.message },
      { status: 500 }
    )
  }
}
