import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { createClient } from '@supabase/supabase-js'

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

    let supabaseUser = null

    // 1. Create or get user in Supabase Auth
    try {
      const emailToUse = email || `${phone}@fastkirana.com` // Fallback email if only phone is available
      
      const { data, error } = await supabaseAdmin.auth.admin.createUser({
        email: emailToUse,
        phone: phone || undefined,
        email_confirm: true,
        phone_confirm: true
      })

      if (error) {
        // If user already exists, retrieve them by email
        if (
          error.message.includes('already exists') || 
          error.code === 'email_exists' || 
          error.code === 'phone_exists'
        ) {
          const { data: userList, error: getErr } = await supabaseAdmin.auth.admin.listUsers()
          if (getErr) throw getErr
          const matched = userList.users.find(u => u.email === emailToUse)
          if (!matched) {
            throw new Error('User not found by email in fallback')
          }
          supabaseUser = matched
        } else {
          throw error
        }
      } else {
        supabaseUser = data.user
      }
    } catch (createErr: any) {
      console.error('Error finding/creating user in Supabase Auth:', createErr)
      return NextResponse.json(
        { error: 'Failed to sync user to authentication system: ' + createErr.message },
        { status: 500 }
      )
    }

    if (!supabaseUser || !supabaseUser.email) {
      return NextResponse.json({ error: 'User sync failed' }, { status: 500 })
    }

    // 2. Generate magic link login token hash using the confirmed email
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: supabaseUser.email,
    })

    if (linkError) {
      throw linkError
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
