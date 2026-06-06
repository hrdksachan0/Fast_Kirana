'use client'

import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { signIn } from 'next-auth/react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Loader2, ShoppingBag, ArrowLeft, Mail, KeyRound, User, Phone } from 'lucide-react'

function LoginForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const callbackUrl = searchParams.get('callbackUrl') || '/'
  
  // Auth steps: 'EMAIL' | 'OTP' | 'PROFILE'
  const [step, setStep] = useState<'EMAIL' | 'OTP' | 'PROFILE'>('EMAIL')
  const [isLoading, setIsLoading] = useState(false)
  const [isGoogleLoading, setIsGoogleLoading] = useState(false)

  // Fields state
  const [email, setEmail] = useState('')
  const [otp, setOtp] = useState('')
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  
  // Test mode helper
  const [testOtp, setTestOtp] = useState<string | null>(null)

  // Errors state
  const [errors, setErrors] = useState<{ email?: string; otp?: string; name?: string; phone?: string }>({})

  const validateEmail = (val: string) => {
    if (!val) return 'Email is required'
    if (!/\S+@\S+\.\S+/.test(val)) return 'Please enter a valid email address'
    return null
  }

  const validateOtp = (val: string) => {
    if (!val) return 'OTP code is required'
    if (val.length !== 6 || isNaN(Number(val))) return 'OTP must be a 6-digit number'
    return null
  }

  const validateProfile = () => {
    const errs: { name?: string; phone?: string } = {}
    if (!name.trim()) errs.name = 'Full name is required'
    if (!phone.trim()) {
      errs.phone = 'Mobile number is required'
    } else if (phone.trim().length < 10) {
      errs.phone = 'Mobile number must be at least 10 digits'
    }
    return errs
  }

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    const emailErr = validateEmail(email)
    if (emailErr) {
      setErrors({ email: emailErr })
      return
    }
    setErrors({})
    setIsLoading(true)

    try {
      const res = await fetch('/api/auth/otp/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to send OTP code')
      } else {
        toast.success(`Verification code generated for ${email}`)
        if (data.otp) {
          setTestOtp(data.otp) // Expose in UI during development since SMTP is disabled
        }
        setStep('OTP')
      }
    } catch (error) {
      toast.error('Something went wrong. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    const otpErr = validateOtp(otp)
    if (otpErr) {
      setErrors({ otp: otpErr })
      return
    }
    setErrors({})
    setIsLoading(true)

    try {
      const res = await fetch('/api/auth/otp/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otp }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Verification failed')
      } else {
        if (data.needsProfileSetup) {
          toast.info('New account detected! Please enter your name and phone to continue.')
          setStep('PROFILE')
        } else {
          // Profile exists, trigger sign-in directly
          await triggerNextAuthSignIn()
        }
      }
    } catch (error) {
      toast.error('Failed to verify OTP. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleSaveProfileAndLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    const profileErrs = validateProfile()
    if (Object.keys(profileErrs).length > 0) {
      setErrors(profileErrs)
      return
    }
    setErrors({})
    setIsLoading(true)

    try {
      await triggerNextAuthSignIn(name, phone)
    } catch (error) {
      toast.error('Failed to complete login. Please try again.')
      setIsLoading(false)
    }
  }

  const triggerNextAuthSignIn = async (userName?: string, userPhone?: string) => {
    const res = await signIn('otp', {
      email,
      otp,
      name: userName || '',
      phone: userPhone || '',
      redirect: false,
    })

    if (res?.error) {
      toast.error(res.error || 'Failed to authenticate. OTP may be expired.')
      setIsLoading(false)
    } else {
      toast.success('Successfully logged in!')
      router.push(callbackUrl)
      router.refresh()
    }
  }

  const handleGoogleLogin = async () => {
    setIsGoogleLoading(true)
    try {
      await signIn('google', { callbackUrl })
    } catch (error) {
      toast.error('Failed to log in with Google')
      setIsGoogleLoading(false)
    }
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
          <h2 className="mt-6 text-2xl md:text-3xl font-black tracking-tight text-text-primary animate-slide-down">
            {step === 'EMAIL' && 'Sign in or Sign up'}
            {step === 'OTP' && 'Verify Email'}
            {step === 'PROFILE' && 'Create Profile'}
          </h2>
          <p className="mt-1.5 text-xs md:text-sm text-text-muted">
            {step === 'EMAIL' && 'Enter your email address to get started'}
            {step === 'OTP' && `We sent a 6-digit OTP code to ${email}`}
            {step === 'PROFILE' && 'Please complete your details to finish registration'}
          </p>
        </div>

        {/* Development mode test banner */}
        {testOtp && step === 'OTP' && (
          <div className="rounded-xl border border-amber-500/20 bg-amber-500/10 p-3 text-center text-xs font-bold text-amber-700 dark:text-amber-400 animate-pulse-gentle">
            🧪 Test Mode OTP code: <span className="underline font-black tracking-widest text-sm">{testOtp}</span>
          </div>
        )}

        {/* STEP 1: ENTER EMAIL */}
        {step === 'EMAIL' && (
          <form
            className="mt-6 space-y-5 animate-slide-down"
            onSubmit={handleSendOtp}
          >
            <div className="space-y-1.5">
              <Label htmlFor="email" className="font-bold text-xs">Email Address</Label>
              <div className="relative">
                <Mail className="absolute left-3 top-3 h-4.5 w-4.5 text-text-muted" />
                <Input
                  id="email"
                  type="email"
                  placeholder="name@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="pl-10 h-11"
                  disabled={isLoading}
                />
              </div>
              {errors.email && (
                <p className="text-xs font-semibold text-danger">{errors.email}</p>
              )}
            </div>

            <Button
              type="submit"
              className="w-full h-11 bg-primary text-white hover:bg-primary/95 text-xs font-black rounded-xl transition-all shadow-md hover:shadow-lg disabled:opacity-50"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Sending Code...
                </>
              ) : (
                'Send Verification Code'
              )}
            </Button>

            <div className="relative flex justify-center text-xs uppercase my-4">
              <span className="bg-card px-2 text-text-muted font-bold text-[10px] tracking-wider">Or continue with</span>
            </div>

            <Button
              type="button"
              variant="outline"
              className="w-full h-11 border-border hover:bg-muted/50 text-xs font-black rounded-xl transition-all"
              onClick={handleGoogleLogin}
              disabled={isLoading || isGoogleLoading}
            >
              {isGoogleLoading ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <svg className="mr-2 h-4 w-4 shrink-0" aria-hidden="true" focusable="false" data-prefix="fab" data-icon="google" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 488 512">
                  <path fill="currentColor" d="M488 261.8C488 403.3 391.1 504 248 504 110.8 504 0 393.2 0 256S110.8 8 248 8c66.8 0 123 24.5 166.3 64.9l-67.5 64.9C258.5 52.6 94.3 116.6 94.3 256c0 86.5 69.1 156.6 153.7 156.6 98.2 0 135-70.4 140.8-106.9H248v-85.3h236.1c2.3 12.7 3.9 24.9 3.9 41.4z"></path>
                </svg>
              )}
              Google Sign In
            </Button>
          </form>
        )}

        {/* STEP 2: ENTER OTP */}
        {step === 'OTP' && (
          <form
            className="mt-6 space-y-5 animate-slide-down"
            onSubmit={handleVerifyOtp}
          >
            <div className="space-y-1.5">
              <Label htmlFor="otp" className="font-bold text-xs">Enter 6-Digit OTP</Label>
              <div className="relative">
                <KeyRound className="absolute left-3 top-3 h-4.5 w-4.5 text-text-muted" />
                <Input
                  id="otp"
                  type="text"
                  maxLength={6}
                  placeholder="123456"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  className="pl-10 h-11 tracking-[0.5em] text-center font-black text-lg focus:tracking-[0.5em]"
                  disabled={isLoading}
                />
              </div>
              {errors.otp && (
                <p className="text-xs font-semibold text-danger">{errors.otp}</p>
              )}
            </div>

            <div className="flex gap-3">
              <Button
                type="button"
                variant="outline"
                onClick={() => {
                  setStep('EMAIL')
                  setOtp('')
                  setTestOtp(null)
                }}
                className="flex-1 h-11 border-border font-bold rounded-xl text-xs flex gap-1.5"
                disabled={isLoading}
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </Button>
              <Button
                type="submit"
                className="flex-[2] h-11 bg-primary text-white hover:bg-primary/95 text-xs font-black rounded-xl transition-all shadow-md"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Verifying...
                  </>
                ) : (
                  'Verify Code'
                )}
              </Button>
            </div>
          </form>
        )}

        {/* STEP 3: CONFIGURE PROFILE */}
        {step === 'PROFILE' && (
          <form
            className="mt-6 space-y-5 animate-slide-down"
            onSubmit={handleSaveProfileAndLogin}
          >
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

            <div className="flex gap-3">
              <Button
                type="button"
                variant="outline"
                onClick={() => {
                  setStep('OTP')
                }}
                className="flex-1 h-11 border-border font-bold rounded-xl text-xs flex gap-1.5"
                disabled={isLoading}
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </Button>
              <Button
                type="submit"
                className="flex-[2] h-11 bg-primary text-white hover:bg-primary/95 text-xs font-black rounded-xl transition-all shadow-md"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Saving...
                  </>
                ) : (
                  'Save & Sign In'
                )}
              </Button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={
      <div className="flex min-h-[80vh] items-center justify-center bg-background">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    }>
      <LoginForm />
    </Suspense>
  )
}
