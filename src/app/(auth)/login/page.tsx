'use client'

import { useState, Suspense, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { signIn } from 'next-auth/react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Loader2, ShoppingBag, ArrowLeft, Mail, KeyRound, User, Phone } from 'lucide-react'

const getRoleRedirect = (role: string, callbackUrl: string) => {
  switch (role) {
    case 'ADMIN': return '/admin'
    case 'CHEF': return '/cafe-kitchen'
    case 'PICKER': return '/picker'
    case 'DELIVERY': return '/delivery'
    default: return callbackUrl || '/'
  }
}

function LoginForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const callbackUrl = searchParams.get('callbackUrl') || '/'
  const errorParam = searchParams.get('error')

  useEffect(() => {
    if (errorParam) {
      console.error('NextAuth Error Parameter:', errorParam)
      if (errorParam === 'OAuthAccountNotLinked') {
        toast.error('Email is already registered. Please login with email/OTP instead, or link accounts.')
      } else if (errorParam === 'Callback') {
        toast.error('Sign-in failed. This could be due to a configuration or database issue. Please try again.')
      } else {
        toast.error(`Authentication error: ${errorParam}`)
      }
    }
  }, [errorParam])
  
  // Auth steps: 'EMAIL' | 'PASSWORD' | 'OTP' | 'PROFILE'
  const [step, setStep] = useState<'EMAIL' | 'PASSWORD' | 'OTP' | 'PROFILE'>('EMAIL')
  const [isLoading, setIsLoading] = useState(false)
  const [isGoogleLoading, setIsGoogleLoading] = useState(false)
  const [loginType, setLoginType] = useState<'WHATSAPP' | 'EMAIL'>('WHATSAPP')

  // Fields state
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [otp, setOtp] = useState('')
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  
  // Role-based state from /api/auth/email/check
  const [isWorker, setIsWorker] = useState(false)
  const [hasPassword, setHasPassword] = useState(true)
  const [needsProfileSetup, setNeedsProfileSetup] = useState(false)
  const [userRole, setUserRole] = useState<string>('')

  // Test mode helper
  const [testOtp, setTestOtp] = useState<string | null>(null)

  // Errors state
  const [errors, setErrors] = useState<{ email?: string; password?: string; otp?: string; name?: string; phone?: string }>({})

  const isPhoneNumber = (val: string) => {
    const cleaned = val.replace(/\D/g, '')
    return cleaned.length === 10 || (cleaned.length === 12 && cleaned.startsWith('91'))
  }

  const normalizePhoneNumber = (val: string) => {
    const cleaned = val.replace(/\D/g, '')
    if (cleaned.length === 10) return `+91${cleaned}`
    if (cleaned.length === 12 && cleaned.startsWith('91')) return `+${cleaned}`
    return val
  }

  const validateIdentifier = (val: string) => {
    const trimmed = val.trim()
    if (loginType === 'WHATSAPP') {
      if (!trimmed) return 'WhatsApp number is required'
      if (!isPhoneNumber(trimmed)) return 'Please enter a valid 10-digit WhatsApp number'
      return null
    } else {
      if (!trimmed) return 'Email is required'
      if (!/\S+@\S+\.\S+/.test(trimmed)) return 'Please enter a valid email address'
      return null
    }
  }

  const formatIdentifierDisplay = (val: string): string => {
    if (val.startsWith('wa-') && val.includes('@')) {
      const phoneDigits = val.split('@')[0].replace('wa-', '')
      return `WhatsApp (+91 ${phoneDigits})`
    }
    return val
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

  // Step 1: Check email/phone type via API
  const handleEmailSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const idErr = validateIdentifier(email)
    if (idErr) {
      setErrors({ email: idErr })
      return
    }
    setErrors({})
    setIsLoading(true)

    const normalizedInput = loginType === 'WHATSAPP' ? normalizePhoneNumber(email) : email.toLowerCase().trim()

    try {
      const res = await fetch('/api/auth/email/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: normalizedInput }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to check account status')
        return
      }

      // Store role info from response
      setIsWorker(data.isWorker ?? false)
      setHasPassword(data.hasPassword ?? false)
      setNeedsProfileSetup(data.needsProfileSetup ?? false)
      setUserRole(data.role ?? '')

      let finalEmail = normalizedInput
      if (data.email) {
        finalEmail = data.email
        setEmail(data.email)
        if (data.email.startsWith('wa-')) {
          const phoneDigits = data.email.split('@')[0].replace('wa-', '')
          setPhone(`+91${phoneDigits}`)
        }
      }

      if (data.isWorker) {
        // Worker flow → password step
        if (!data.hasPassword) {
          toast.error('Your admin hasn\'t set your password yet. Please contact your admin.')
          return
        }
        setStep('PASSWORD')
      } else {
        // Customer flow → auto-send OTP and go to OTP step
        await sendOtp(finalEmail)
      }
    } catch {
      toast.error('Something went wrong. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  // Send OTP helper (used for customer flow)
  const sendOtp = async (targetEmail?: string) => {
    const emailToUse = targetEmail || email
    try {
      const res = await fetch('/api/auth/otp/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: emailToUse.toLowerCase().trim() }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to send OTP code')
      } else {
        toast.success(`Verification code sent to ${formatIdentifierDisplay(emailToUse)}`)
        if (data.otp) {
          setTestOtp(data.otp)
        }
        setStep('OTP')
      }
    } catch {
      toast.error('Something went wrong. Please try again.')
    }
  }

  // Step 2a: Worker password login
  const handlePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!password) {
      setErrors({ password: 'Password is required' })
      return
    }
    setErrors({})
    setIsLoading(true)

    try {
      const res = await signIn('credentials', {
        email: email.toLowerCase().trim(),
        password,
        redirect: false,
      })

      if (res?.error) {
        toast.error('Invalid password. Please try again.')
      } else {
        toast.success('Successfully logged in!')
        const redirect = getRoleRedirect(userRole, callbackUrl)
        router.push(redirect)
        router.refresh()
      }
    } catch {
      toast.error('Authentication failed. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  // Step 2b: Customer OTP verification
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
        body: JSON.stringify({ email: email.toLowerCase().trim(), otp }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Verification failed')
      } else {
        if (data.needsProfileSetup) {
          toast.info('New account detected! Please enter your name and phone to continue.')
          setNeedsProfileSetup(true)
          setStep('PROFILE')
        } else {
          // Existing customer — sign in directly
          await triggerNextAuthSignIn()
        }
      }
    } catch {
      toast.error('Failed to verify OTP. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  // Step 3: Save profile and login (new customers only)
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
    } catch {
      toast.error('Failed to complete login. Please try again.')
      setIsLoading(false)
    }
  }

  // NextAuth OTP sign-in (customers)
  const triggerNextAuthSignIn = async (userName?: string, userPhone?: string) => {
    const res = await signIn('otp', {
      email: email.toLowerCase().trim(),
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
      router.push(callbackUrl || '/')
      router.refresh()
    }
  }

  // Resend OTP for customer flow
  const handleResendOtp = async () => {
    setIsLoading(true)
    try {
      await sendOtp()
    } finally {
      setIsLoading(false)
    }
  }

  const handleGoogleLogin = async () => {
    setIsGoogleLoading(true)
    try {
      await signIn('google', { callbackUrl })
    } catch {
      toast.error('Failed to log in with Google')
      setIsGoogleLoading(false)
    }
  }

  // Reset to email step
  const goBackToEmail = () => {
    setStep('EMAIL')
    setPassword('')
    setOtp('')
    setTestOtp(null)
    setName('')
    setPhone('')
    setErrors({})
    setIsWorker(false)
    setHasPassword(true)
    setNeedsProfileSetup(false)
    setUserRole('')

    // If it's a WhatsApp placeholder email, convert it back to the 10-digit phone number
    if (email.startsWith('wa-') && email.includes('@')) {
      const phoneDigits = email.split('@')[0].replace('wa-', '')
      setEmail(phoneDigits)
      setLoginType('WHATSAPP')
    }
  }

  return (
    <div className="flex min-h-[85vh] items-center justify-center px-4 py-6 sm:py-12 sm:px-6 lg:px-8 bg-zinc-50 dark:bg-zinc-950/20 relative overflow-hidden">
      {/* Decorative gradient blobs in background for a modern visual feel */}
      <div className="absolute top-1/4 left-1/4 -translate-x-1/2 -translate-y-1/2 w-80 h-80 rounded-full bg-primary/8 dark:bg-primary/10 blur-[100px] pointer-events-none animate-float-slow" />
      <div className="absolute bottom-1/4 right-1/4 translate-x-1/2 translate-y-1/2 w-96 h-96 rounded-full bg-accent/8 dark:bg-accent/10 blur-[110px] pointer-events-none animate-float-reverse" />
      <div className="absolute top-1/2 right-1/3 w-64 h-64 rounded-full bg-rose-400/5 dark:bg-rose-400/5 blur-[90px] pointer-events-none animate-float" />

      <div className="w-full max-w-md space-y-5 sm:space-y-8 rounded-3xl border border-white/20 dark:border-white/10 bg-white/70 dark:bg-zinc-900/60 p-5 min-[375px]:p-6 sm:p-8 shadow-2xl backdrop-blur-2xl relative overflow-hidden transition-all duration-300 hover:shadow-primary/5">
        
        {/* Background glow decoration inside card */}
        <div className="absolute top-0 right-0 -mr-16 -mt-16 h-36 w-36 rounded-full bg-primary/10 blur-2xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 -ml-16 -mb-16 h-36 w-36 rounded-full bg-accent/10 blur-2xl pointer-events-none" />

        <div className="flex flex-col items-center text-center relative z-10">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-[#e20a22] to-[#ff4d62] text-white shadow-lg shadow-primary/25 hover:rotate-6 transition-transform">
            <ShoppingBag className="h-7 w-7 animate-float" />
          </div>
          <h2 className="mt-4 sm:mt-6 text-xl md:text-3xl font-black tracking-tight text-text-primary bg-gradient-to-r from-text-primary via-text-primary to-text-secondary bg-clip-text">
            {step === 'EMAIL' && 'Welcome to FastKirana'}
            {step === 'PASSWORD' && 'Enter Password'}
            {step === 'OTP' && (email.startsWith('wa-') ? 'Verify WhatsApp' : 'Verify Email')}
            {step === 'PROFILE' && 'Complete Profile'}
          </h2>
          <p className="mt-1.5 sm:mt-2 text-xs md:text-sm text-text-muted max-w-[280px]">
            {step === 'EMAIL' && 'Log in or sign up to shop groceries with fast delivery'}
            {step === 'PASSWORD' && `Enter password for ${email}`}
            {step === 'OTP' && `We sent a 6-digit OTP code to ${formatIdentifierDisplay(email)}`}
            {step === 'PROFILE' && 'Enter your name and phone number to finish setup'}
          </p>
        </div>

        {/* Development mode test banner styled as a premium glass status bar */}
        {testOtp && step === 'OTP' && (
          <div className="relative z-10 rounded-2xl border border-amber-500/20 bg-amber-500/10 p-3.5 text-center text-xs font-bold text-amber-700 dark:text-amber-400 shadow-sm animate-spring-in">
            <span className="block text-[10px] uppercase tracking-wider text-amber-600 dark:text-amber-500 mb-1">🧪 Developer Test Code</span>
            OTP Code: <span className="underline font-black tracking-widest text-sm bg-white/50 dark:bg-black/30 px-2 py-0.5 rounded ml-1">{testOtp}</span>
          </div>
        )}

        {/* STEP 1: ENTER EMAIL OR WHATSAPP */}
        {step === 'EMAIL' && (
          <form
            className="mt-4 sm:mt-6 space-y-4 sm:space-y-5 animate-slide-down relative z-10"
            onSubmit={handleEmailSubmit}
          >
            {/* Tabs Selector */}
            <div className="grid grid-cols-2 gap-2 bg-zinc-100/80 dark:bg-zinc-900/50 p-1 rounded-xl border border-zinc-200/50 dark:border-zinc-800/40">
              <button
                type="button"
                onClick={() => {
                  setLoginType('WHATSAPP')
                  setEmail('')
                  setErrors({})
                }}
                className={`py-2 px-3 text-xs font-black rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                  loginType === 'WHATSAPP'
                    ? 'bg-white dark:bg-zinc-800 text-primary shadow-xs border border-zinc-200/30'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                <Phone size={14} className="stroke-[2.2]" />
                WhatsApp
              </button>
              <button
                type="button"
                onClick={() => {
                  setLoginType('EMAIL')
                  setEmail('')
                  setErrors({})
                }}
                className={`py-2 px-3 text-xs font-black rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                  loginType === 'EMAIL'
                    ? 'bg-white dark:bg-zinc-800 text-primary shadow-xs border border-zinc-200/30'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                <Mail size={14} className="stroke-[2.2]" />
                Email
              </button>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="email" className="font-bold text-xs text-text-secondary">
                {loginType === 'WHATSAPP' ? 'WhatsApp Number' : 'Email Address'}
              </Label>
              <div className="relative group">
                {loginType === 'WHATSAPP' ? (
                  <Phone className="absolute left-3.5 top-3.5 h-5 w-5 text-text-muted group-focus-within:text-primary transition-colors" />
                ) : (
                  <Mail className="absolute left-3.5 top-3.5 h-5 w-5 text-text-muted group-focus-within:text-primary transition-colors" />
                )}
                <Input
                  id="email"
                  type={loginType === 'WHATSAPP' ? 'text' : 'email'}
                  placeholder={loginType === 'WHATSAPP' ? 'Enter 10-digit number' : 'name@example.com'}
                  value={email}
                  onChange={(e) => {
                    let val = e.target.value
                    if (loginType === 'WHATSAPP') {
                      val = val.replace(/\D/g, '').slice(0, 10)
                    }
                    setEmail(val)
                  }}
                  className="pl-11 h-12 rounded-xl border-border bg-white/50 dark:bg-black/20 text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-text-muted/60"
                  disabled={isLoading}
                  required
                />
              </div>
              {errors.email && (
                <p className="text-xs font-bold text-danger animate-slide-down">{errors.email}</p>
              )}
            </div>

            <Button
              type="submit"
              className="w-full h-12 bg-gradient-to-r from-primary to-primary-light text-white font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all shadow-lg shadow-primary/20 cursor-pointer flex items-center justify-center gap-1.5"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Checking...
                </>
              ) : (
                'Continue'
              )}
            </Button>

            <div className="relative flex items-center justify-center text-xs uppercase my-3 sm:my-4">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-border/60"></div>
              </div>
              <span className="relative bg-[#fafafa] dark:bg-zinc-900 px-3 text-text-muted font-bold text-[10px] tracking-wider">Or continue with</span>
            </div>

            <Button
              type="button"
              variant="outline"
              className="w-full h-12 border-border bg-white/40 dark:bg-black/10 hover:bg-white/60 dark:hover:bg-black/20 text-xs font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all cursor-pointer shadow-sm flex items-center justify-center gap-2"
              onClick={handleGoogleLogin}
              disabled={isLoading || isGoogleLoading}
            >
              {isGoogleLoading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <svg className="h-5 w-5 shrink-0" aria-hidden="true" focusable="false" data-prefix="fab" data-icon="google" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 488 512">
                  <path fill="currentColor" d="M488 261.8C488 403.3 391.1 504 248 504 110.8 504 0 393.2 0 256S110.8 8 248 8c66.8 0 123 24.5 166.3 64.9l-67.5 64.9C258.5 52.6 94.3 116.6 94.3 256c0 86.5 69.1 156.6 153.7 156.6 98.2 0 135-70.4 140.8-106.9H248v-85.3h236.1c2.3 12.7 3.9 24.9 3.9 41.4z"></path>
                </svg>
              )}
              Google Sign In
            </Button>
          </form>
        )}

        {/* STEP 2a: WORKER PASSWORD LOGIN */}
        {step === 'PASSWORD' && (
          <form
            className="mt-4 sm:mt-6 space-y-4 sm:space-y-5 animate-slide-down relative z-10"
            onSubmit={handlePasswordSubmit}
          >
            <div className="space-y-1.5">
              <Label htmlFor="password" className="font-bold text-xs text-text-secondary">Password</Label>
              <div className="relative group">
                <KeyRound className="absolute left-3.5 top-3.5 h-5 w-5 text-text-muted group-focus-within:text-primary transition-colors" />
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="pl-11 h-12 rounded-xl border-border bg-white/50 dark:bg-black/20 text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all placeholder:text-text-muted/60"
                  disabled={isLoading}
                  required
                  autoFocus
                />
              </div>
              {errors.password && (
                <p className="text-xs font-bold text-danger animate-slide-down">{errors.password}</p>
              )}
            </div>

            <Button
              type="submit"
              className="w-full h-12 bg-gradient-to-r from-primary to-primary-light text-white font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all shadow-lg shadow-primary/20 cursor-pointer flex items-center justify-center gap-1.5"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Logging in...
                </>
              ) : (
                'Login with Password'
              )}
            </Button>

            <div className="flex flex-col gap-2.5 mt-2">
              <button
                type="button"
                onClick={goBackToEmail}
                className="text-xs font-bold text-text-muted hover:underline cursor-pointer text-center"
                disabled={isLoading}
              >
                Use another email address
              </button>
            </div>
          </form>
        )}

        {/* STEP 2b: CUSTOMER OTP VERIFICATION */}
        {step === 'OTP' && (
          <form
            className="mt-4 sm:mt-6 space-y-4 sm:space-y-5 animate-slide-down relative z-10"
            onSubmit={handleVerifyOtp}
          >
            <div className="space-y-1.5">
              <Label htmlFor="otp" className="font-bold text-xs text-text-secondary">Enter 6-Digit OTP</Label>
              <div className="relative group">
                <KeyRound className="absolute left-3.5 top-3.5 h-5 w-5 text-text-muted group-focus-within:text-accent transition-colors" />
                <Input
                  id="otp"
                  type="text"
                  maxLength={6}
                  placeholder="123456"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  className="pl-11 h-12 tracking-[0.6em] text-center font-black text-lg focus:tracking-[0.6em] rounded-xl border-border bg-white/50 dark:bg-black/20 focus:border-accent focus:ring-2 focus:ring-accent/20 transition-all placeholder:text-text-muted/40 placeholder:tracking-normal"
                  disabled={isLoading}
                  required
                  autoFocus
                />
              </div>
              {errors.otp && (
                <p className="text-xs font-bold text-danger animate-slide-down">{errors.otp}</p>
              )}
            </div>

            <div className="flex gap-3.5">
              <Button
                type="button"
                variant="outline"
                onClick={goBackToEmail}
                className="flex-1 h-12 border-border bg-white/40 dark:bg-black/10 hover:bg-white/60 dark:hover:bg-black/20 text-xs font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all cursor-pointer shadow-sm flex items-center justify-center gap-1.5"
                disabled={isLoading}
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </Button>
              <Button
                type="submit"
                className="flex-[2] h-12 bg-gradient-to-r from-accent to-accent-light text-white text-xs font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all shadow-lg shadow-accent/20 cursor-pointer flex items-center justify-center gap-1.5"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="h-5 w-5 animate-spin" />
                    Verifying...
                  </>
                ) : (
                  'Verify Code'
                )}
              </Button>
            </div>

            <button
              type="button"
              onClick={handleResendOtp}
              className="w-full text-xs font-black text-accent dark:text-emerald-400 hover:underline cursor-pointer text-center mt-1"
              disabled={isLoading}
            >
              Resend OTP code
            </button>
          </form>
        )}

        {/* STEP 3: CONFIGURE PROFILE (new customers only) */}
        {step === 'PROFILE' && (
          <form
            className="mt-4 sm:mt-6 space-y-4 sm:space-y-5 animate-slide-down relative z-10"
            onSubmit={handleSaveProfileAndLogin}
          >
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
                    autoFocus
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

            <div className="flex gap-3.5">
              <Button
                type="button"
                variant="outline"
                onClick={() => {
                  setStep('OTP')
                }}
                className="flex-1 h-12 border-border bg-white/40 dark:bg-black/10 hover:bg-white/60 dark:hover:bg-black/20 text-xs font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all cursor-pointer shadow-sm flex items-center justify-center gap-1.5"
                disabled={isLoading}
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </Button>
              <Button
                type="submit"
                className="flex-[2] h-12 bg-gradient-to-r from-primary to-primary-light text-white text-xs font-black rounded-xl hover:scale-[1.01] active:scale-95 transition-all shadow-lg shadow-primary/20 cursor-pointer flex items-center justify-center gap-1.5"
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Loader2 className="h-5 w-5 animate-spin" />
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
