'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { signIn, signOut } from 'next-auth/react'
import { toast } from 'sonner'
import { Loader2, Coffee, KeyRound, Mail, ArrowLeft } from 'lucide-react'

export default function CafeLoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!email.trim() || !password.trim()) {
      toast.error('Please enter both email and password')
      return
    }

    setIsLoading(true)
    try {
      const res = await signIn('credentials', {
        email: email.trim().toLowerCase(),
        password: password.trim(),
        redirect: false,
      })

      if (res?.error) {
        toast.error('Invalid credentials. Please try again.')
        setIsLoading(false)
        return
      }

      // Fetch session info to verify chef authorization
      const sessionRes = await fetch('/api/auth/session')
      const session = await sessionRes.json()
      
      const role = session?.user?.role
      const userEmail = session?.user?.email || ''
      const isAllowed = role === 'ADMIN' || (role === 'CHEF' && !userEmail.toLowerCase().startsWith('restaurant'))

      if (isAllowed) {
        toast.success('Welcome back, Chef! Redirecting to Cafe kitchen...')
        router.push('/cafe-kitchen')
        router.refresh()
      } else {
        toast.error('Access Denied. Only registered Cafe chefs are allowed to log in here.')
        await signOut({ redirect: false })
        setIsLoading(false)
      }
    } catch (err) {
      toast.error('Authentication failed. Please try again.')
      console.error(err)
      setIsLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-950 px-4 sm:px-6 relative overflow-hidden">
      {/* Cafe background glow */}
      <div className="absolute top-1/4 left-1/4 h-[350px] w-[350px] rounded-full bg-orange-600/10 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 h-[350px] w-[350px] rounded-full bg-amber-600/5 blur-[120px] pointer-events-none" />

      <div className="w-full max-w-md space-y-6 z-10">
        {/* Back to Home Button */}
        <button 
          onClick={() => router.push('/')}
          className="inline-flex items-center gap-1.5 text-zinc-450 hover:text-zinc-200 text-xs font-bold transition-colors cursor-pointer select-none"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to Storefront
        </button>

        {/* Login Card */}
        <div className="bg-[#111113] border border-zinc-800/60 rounded-3xl p-6 sm:p-8 shadow-2xl shadow-orange-950/5">
          <div className="text-center space-y-2 mb-6">
            <div className="h-14 w-14 rounded-2xl bg-orange-500/10 text-orange-500 flex items-center justify-center mx-auto shadow-inner border border-orange-500/20">
              <Coffee className="h-6 w-6" />
            </div>
            <h2 className="text-lg font-black tracking-tight text-white uppercase mt-4 font-sans">FastKirana Cafe</h2>
            <p className="text-[11px] text-zinc-400 font-bold uppercase tracking-wider">Cafe Chef Staff Portal</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-4">
            {/* Email Field */}
            <div className="space-y-1.5">
              <label className="text-[10px] font-extrabold uppercase tracking-wider text-zinc-400">Chef Email / Username</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-zinc-500" />
                <input
                  type="email"
                  placeholder="e.g. chef@fastkirana.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={isLoading}
                  required
                  className="w-full bg-zinc-900 border border-zinc-800 focus:border-orange-500/50 pl-10 pr-4 py-2.5 rounded-2xl text-xs font-semibold text-white focus:outline-none placeholder-zinc-600 disabled:opacity-50"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1.5">
              <label className="text-[10px] font-extrabold uppercase tracking-wider text-zinc-400">Security Password</label>
              <div className="relative">
                <KeyRound className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-zinc-500" />
                <input
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isLoading}
                  required
                  className="w-full bg-zinc-900 border border-zinc-800 focus:border-orange-500/50 pl-10 pr-4 py-2.5 rounded-2xl text-xs font-semibold text-white focus:outline-none placeholder-zinc-600 disabled:opacity-50"
                />
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full inline-flex items-center justify-center gap-2 py-3 bg-orange-600 hover:bg-orange-700 text-white font-black text-xs rounded-2xl shadow-lg shadow-orange-600/10 active:scale-98 transition-all cursor-pointer disabled:opacity-60"
            >
              {isLoading ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  AUTHENTICATING CHEF...
                </>
              ) : (
                'ENTER CAFE CONSOLE'
              )}
            </button>
          </form>

          {/* Footnote */}
          <p className="text-[9px] font-bold text-center text-zinc-500 mt-6 uppercase tracking-wider leading-relaxed">
            Restricted Area • Authorized Cafe Personnel Only
          </p>
        </div>
      </div>
    </div>
  )
}
