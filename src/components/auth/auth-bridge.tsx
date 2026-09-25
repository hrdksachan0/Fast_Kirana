'use client'

import { useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { supabase } from '@/lib/supabase-client'

export function SupabaseAuthBridge() {
  const { data: session, status } = useSession()

  useEffect(() => {
    if (status === 'unauthenticated') {
      try {
        if (typeof window !== 'undefined') {
          localStorage.removeItem('fastapi_token')
          localStorage.removeItem('fastkirana_token')
          document.cookie = 'fastapi_token=; path=/; max-age=0; SameSite=Lax; Secure'
          document.cookie = 'fastkirana_token=; path=/; max-age=0; SameSite=Lax; Secure'
        }
      } catch {}
      return
    }

    if (status !== 'authenticated' || !session?.user) return

    // 1. Sync FastAPI JWT to localStorage and cookie for 100% decoupled backend calls
    const fastToken = (session as any)?.fastapiToken || (session?.user as any)?.fastapiToken
    if (fastToken && typeof window !== 'undefined') {
      try {
        localStorage.setItem('fastapi_token', fastToken)
        localStorage.setItem('fastkirana_token', fastToken)
        document.cookie = `fastapi_token=${fastToken}; path=/; max-age=2592000; SameSite=Lax; Secure`
        document.cookie = `fastkirana_token=${fastToken}; path=/; max-age=2592000; SameSite=Lax; Secure`
      } catch (e) {
        console.error('[FastApiBridge] Cookie/storage set error:', e)
      }
    }

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
