'use client'

import { useEffect, useState } from 'react'
import { useSession } from 'next-auth/react'

export default function MobileCallbackPage() {
  const { data: session, status } = useSession()
  const [redirectTarget, setRedirectTarget] = useState<string | null>(null)
  
  useEffect(() => {
    if (status === 'authenticated' && session?.user) {
      // Retrieve the dynamic mobile deep link from localStorage
      const redirectBase = localStorage.getItem('mobile_redirect_url') || 'fastkirana://'
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
      
      setRedirectTarget(target)
      console.log('Redirecting to mobile deep link:', target)
      
      // Clear localStorage
      localStorage.removeItem('mobile_redirect_url')
      
      // Redirect back to the mobile app
      window.location.href = target
    }
  }, [session, status])

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-zinc-950 text-white p-6">
      <div className="w-12 h-12 rounded-full border-4 border-t-emerald-500 border-zinc-800 animate-spin mb-4" />
      <h1 className="text-xl font-bold mb-2">Connecting to FastKirana App...</h1>
      <p className="text-zinc-400 text-sm text-center max-w-xs mb-4">
        Please wait while we redirect you back to the mobile app.
      </p>
      
      {redirectTarget && (
        <a 
          href={redirectTarget}
          className="mt-6 px-6 py-3 bg-red-600 hover:bg-red-700 text-white font-bold rounded-xl transition-colors shadow-lg shadow-red-900/30 text-center"
        >
          Open App Manually
        </a>
      )}
    </div>
  )
}
