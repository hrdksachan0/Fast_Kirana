'use client'

import { useEffect } from 'react'
import { useSearchParams } from 'next/navigation'
import { signIn } from 'next-auth/react'

export default function MobileLoginPage() {
  const searchParams = useSearchParams()

  useEffect(() => {
    const redirectUrl = searchParams.get('redirect')
    if (redirectUrl) {
      // Store redirect URL in localStorage (persists across OAuth redirect loops)
      localStorage.setItem('mobile_redirect_url', redirectUrl)
    }
    
    console.log('Initiating Google sign-in redirect to callback...')
    signIn('google', { callbackUrl: '/auth/mobile-callback' })
  }, [searchParams])

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-zinc-950 text-white p-6">
      <div className="w-12 h-12 rounded-full border-4 border-t-emerald-500 border-zinc-800 animate-spin mb-4" />
      <h1 className="text-xl font-bold mb-2">Connecting to Google...</h1>
      <p className="text-zinc-400 text-sm">Please wait while we redirect you to the Google sign-in page.</p>
    </div>
  )
}
