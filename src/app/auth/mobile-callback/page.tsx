'use client'

import { useEffect } from 'react'
import { useSearchParams } from 'next/navigation'
import { useSession } from 'next-auth/react'

export default function MobileCallbackPage() {
  const searchParams = useSearchParams()
  const { data: session, status } = useSession()
  
  useEffect(() => {
    if (status === 'authenticated' && session?.user) {
      const redirectBase = searchParams.get('redirect') || 'fastkirana://'
      const user = {
        id: session.user.id,
        name: session.user.name,
        email: session.user.email,
        phone: session.user.phone,
        role: session.user.role || 'USER'
      }
      
      // Join redirect base with query parameters
      const separator = redirectBase.includes('?') ? '&' : '?'
      const target = `${redirectBase}${separator}user=${encodeURIComponent(JSON.stringify(user))}`
      
      // Redirect back to the mobile app
      window.location.href = target
    }
  }, [session, status, searchParams])

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-zinc-950 text-white p-6">
      <div className="w-12 h-12 rounded-full border-4 border-t-emerald-500 border-zinc-800 animate-spin mb-4" />
      <h1 className="text-xl font-bold mb-2">Connecting to FastKirana App...</h1>
      <p className="text-zinc-400 text-sm">Please wait while we redirect you back to the mobile app.</p>
    </div>
  )
}
