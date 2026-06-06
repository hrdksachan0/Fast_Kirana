'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Loader2 } from 'lucide-react'

export default function SignupPage() {
  const router = useRouter()

  useEffect(() => {
    // Redirect to the unified OTP login/registration page
    router.replace('/login')
  }, [router])

  return (
    <div className="flex min-h-[85vh] items-center justify-center bg-background">
      <div className="text-center space-y-4">
        <Loader2 className="h-8 w-8 animate-spin text-primary mx-auto" />
        <p className="text-sm text-text-secondary font-bold">Redirecting to login...</p>
      </div>
    </div>
  )
}
