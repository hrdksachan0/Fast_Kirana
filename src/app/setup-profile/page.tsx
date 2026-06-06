'use client'

import { useState, useEffect, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Loader2, ShoppingBag, User, Phone } from 'lucide-react'

function ProfileSetupForm() {
  const { data: session, update, status } = useSession()
  const router = useRouter()
  const searchParams = useSearchParams()
  const callbackUrl = searchParams.get('callbackUrl') || '/'
  
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [errors, setErrors] = useState<{ name?: string; phone?: string }>({})

  useEffect(() => {
    if (session?.user?.name && !name) {
      setName(session.user.name)
    }
  }, [session, name])

  const validate = () => {
    const errs: { name?: string; phone?: string } = {}
    if (!name.trim()) errs.name = 'Full name is required'
    if (!phone.trim()) {
      errs.phone = 'Mobile number is required'
    } else if (phone.trim().replace(/\D/g, '').length < 10) {
      errs.phone = 'Mobile number must be at least 10 digits'
    }
    return errs
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const validationErrors = validate()
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors)
      return
    }
    setErrors({})
    setIsLoading(true)

    try {
      const res = await fetch('/api/auth/profile/setup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, phone }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to update profile')
        setIsLoading(false)
        return
      }

      // Update the NextAuth session dynamically
      await update({ name, phone })
      
      toast.success('Profile completed successfully!')
      router.push(callbackUrl)
      router.refresh()
    } catch (error) {
      toast.error('Something went wrong. Please try again.')
      setIsLoading(false)
    }
  }

  if (status === 'loading') {
    return (
      <div className="flex min-h-[80vh] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    )
  }

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4 py-12 sm:px-6 lg:px-8 bg-zinc-50 dark:bg-zinc-950/20">
      <div className="w-full max-w-md space-y-8 rounded-3xl border border-border/80 dark:border-zinc-800/60 bg-card/80 dark:bg-zinc-900/60 p-8 shadow-xl backdrop-blur-md relative overflow-hidden">
        
        {/* Background glow decoration */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 h-36 w-36 rounded-full bg-primary/5 blur-2xl" />

        <div className="flex flex-col items-center text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-tr from-[#e20a22] to-[#ff4d62] text-white shadow-md">
            <ShoppingBag className="h-6 w-6 animate-float" />
          </div>
          <h2 className="mt-6 text-2xl md:text-3xl font-black tracking-tight text-text-primary">
            Complete Your Profile
          </h2>
          <p className="mt-1.5 text-xs md:text-sm text-text-muted">
            Please enter your name and mobile number to complete your account registration.
          </p>
        </div>

        <form className="mt-6 space-y-5" onSubmit={handleSubmit}>
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="name" className="font-bold text-xs">Full Name</Label>
              <div className="relative">
                <User className="absolute left-3 top-3 h-4.5 w-4.5 text-text-muted" />
                <Input
                  id="name"
                  type="text"
                  placeholder="John Doe"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="pl-10 h-11"
                  disabled={isLoading}
                />
              </div>
              {errors.name && (
                <p className="text-xs font-semibold text-danger">{errors.name}</p>
              )}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="phone" className="font-bold text-xs">Mobile Number</Label>
              <div className="relative">
                <Phone className="absolute left-3 top-3 h-4.5 w-4.5 text-text-muted" />
                <Input
                  id="phone"
                  type="tel"
                  placeholder="9876543210"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                  className="pl-10 h-11"
                  disabled={isLoading}
                />
              </div>
              {errors.phone && (
                <p className="text-xs font-semibold text-danger">{errors.phone}</p>
              )}
            </div>
          </div>

          <Button
            type="submit"
            className="w-full h-11 bg-primary text-white hover:bg-primary/95 text-xs font-black rounded-xl transition-all shadow-md"
            disabled={isLoading}
          >
            {isLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Saving Details...
              </>
            ) : (
              'Save & Continue'
            )}
          </Button>
        </form>
      </div>
    </div>
  )
}

export default function ProfileSetupPage() {
  return (
    <Suspense fallback={
      <div className="flex min-h-[80vh] items-center justify-center bg-background">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    }>
      <ProfileSetupForm />
    </Suspense>
  )
}
