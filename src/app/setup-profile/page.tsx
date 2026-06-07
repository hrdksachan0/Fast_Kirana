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
    <div className="flex min-h-[85vh] items-center justify-center px-4 py-12 sm:px-6 lg:px-8 bg-zinc-50 dark:bg-zinc-950/20 relative overflow-hidden">
      {/* Decorative gradient blobs in background */}
      <div className="absolute top-1/4 left-1/4 -translate-x-1/2 -translate-y-1/2 w-80 h-80 rounded-full bg-primary/8 dark:bg-primary/10 blur-[100px] pointer-events-none animate-float-slow" />
      <div className="absolute bottom-1/4 right-1/4 translate-x-1/2 translate-y-1/2 w-96 h-96 rounded-full bg-accent/8 dark:bg-accent/10 blur-[110px] pointer-events-none animate-float-reverse" />
      <div className="absolute top-1/2 right-1/3 w-64 h-64 rounded-full bg-rose-400/5 dark:bg-rose-400/5 blur-[90px] pointer-events-none animate-float" />

      <div className="w-full max-w-md space-y-8 rounded-3xl border border-white/20 dark:border-white/10 bg-white/70 dark:bg-zinc-900/60 p-8 shadow-2xl backdrop-blur-2xl relative overflow-hidden transition-all duration-300">
        
        {/* Background glow decoration inside card */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 h-36 w-36 rounded-full bg-primary/10 blur-2xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 -ml-16 -mb-16 h-36 w-36 rounded-full bg-accent/10 blur-2xl pointer-events-none" />

        <div className="flex flex-col items-center text-center relative z-10">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-[#e20a22] to-[#ff4d62] text-white shadow-lg shadow-primary/25 hover:rotate-6 transition-transform">
            <ShoppingBag className="h-7 w-7 animate-float" />
          </div>
          <h2 className="mt-6 text-2xl md:text-3xl font-black tracking-tight text-text-primary bg-gradient-to-r from-text-primary via-text-primary to-text-secondary bg-clip-text">
            Complete Your Profile
          </h2>
          <p className="mt-2 text-xs md:text-sm text-text-muted max-w-[280px]">
            Please enter your details to complete your account registration
          </p>
        </div>

        <form className="mt-6 space-y-5 relative z-10" onSubmit={handleSubmit}>
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="name" className="font-bold text-xs text-text-secondary">Full Name</Label>
              <div className="relative group">
                <User className="absolute left-3.5 top-3.5 h-5 w-5 text-text-muted group-focus-within:text-primary transition-colors" />
                <Input
                  id="name"
                  type="text"
                  placeholder="John Doe"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="pl-11 h-12 rounded-xl border-border bg-white/50 dark:bg-black/20 text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-text-muted/60"
                  disabled={isLoading}
                  required
                />
              </div>
              {errors.name && (
                <p className="text-xs font-bold text-danger animate-slide-down">{errors.name}</p>
              )}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="phone" className="font-bold text-xs text-text-secondary">Mobile Number</Label>
              <div className="relative group">
                <Phone className="absolute left-3.5 top-3.5 h-5 w-5 text-text-muted group-focus-within:text-primary transition-colors" />
                <Input
                  id="phone"
                  type="tel"
                  placeholder="9876543210"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                  className="pl-11 h-12 rounded-xl border-border bg-white/50 dark:bg-black/20 text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-text-muted/60"
                  disabled={isLoading}
                  required
                />
              </div>
              {errors.phone && (
                <p className="text-xs font-bold text-danger animate-slide-down">{errors.phone}</p>
              )}
            </div>
          </div>

          <Button
            type="submit"
            className="w-full h-12 bg-gradient-to-r from-primary to-primary-light text-white text-xs font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all shadow-lg shadow-primary/20 cursor-pointer flex items-center justify-center gap-1.5"
            disabled={isLoading}
          >
            {isLoading ? (
              <>
                <Loader2 className="h-5 w-5 animate-spin" />
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
