'use client'

import { useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { supabase } from '@/lib/supabase-client'

export function SupabaseAuthBridge() {
  const { data: session, status } = useSession()

  useEffect(() => {
    if (status !== 'authenticated' || !session?.user) return

    const checkAndBridge = async () => {
      try {
        // 1. Check if client already has a valid active Supabase session
        const { data: { session: sbSession } } = await supabase.auth.getSession()
        if (sbSession) return

        // 2. Request token_hash from the bridge API
        const res = await fetch('/api/auth/bridge-session', { method: 'POST' })
        if (res.ok) {
          const { token_hash } = await res.json()
          if (token_hash) {
            // 3. Silently sign in the client using the GoTrue verify OTP method
            const { error } = await supabase.auth.verifyOtp({
              token_hash,
              type: 'magiclink'
            })
            
            if (error) {
              console.error('[AuthBridge] Silent verification failed:', error.message)
            } else {
              console.log('[AuthBridge] Session successfully bridged to Supabase Auth silently!')
            }
          }
        }
      } catch (err) {
        console.error('[AuthBridge] Background session bridge error:', err)
      }
    }

    checkAndBridge()
  }, [session, status])

  return null
}
export default SupabaseAuthBridge
