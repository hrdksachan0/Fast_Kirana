'use client'

import { useEffect, useState } from 'react'
import { usePathname } from 'next/navigation'
import { ShoppingBag, ShieldCheck, User, CreditCard, Coffee, Truck, Package, Search } from 'lucide-react'

export default function Loading() {
  const pathname = usePathname()
  const [visible, setVisible] = useState(false)

  // Delay showing the loader by 250ms to prevent flickering on fast transitions
  useEffect(() => {
    const timer = setTimeout(() => setVisible(true), 250)
    return () => clearTimeout(timer)
  }, [])

  if (!visible) return null

  // Determine path-aware text and icon
  let loadingText = 'Getting fresh items for you...'
  let Icon = ShoppingBag
  let glowColor = 'from-primary via-rose-500 to-amber-500'

  if (pathname.startsWith('/admin')) {
    loadingText = 'Accessing Admin Dashboard...'
    Icon = ShieldCheck
    glowColor = 'from-rose-600 via-red-500 to-orange-500'
  } else if (pathname.startsWith('/account')) {
    loadingText = 'Opening Account Settings...'
    Icon = User
    glowColor = 'from-blue-500 via-indigo-500 to-purple-500'
  } else if (pathname.startsWith('/checkout')) {
    loadingText = 'Securing checkout portal...'
    Icon = CreditCard
    glowColor = 'from-emerald-500 via-teal-500 to-cyan-500'
  } else if (pathname.startsWith('/cafe')) {
    loadingText = 'Opening Cafe & Kitchen...'
    Icon = Coffee
    glowColor = 'from-amber-500 via-orange-500 to-yellow-500'
  } else if (pathname.startsWith('/delivery')) {
    loadingText = 'Opening Delivery Portal...'
    Icon = Truck
    glowColor = 'from-cyan-500 via-blue-500 to-indigo-500'
  } else if (pathname.startsWith('/picker')) {
    loadingText = 'Opening Picker Dashboard...'
    Icon = Package
    glowColor = 'from-orange-500 via-rose-500 to-amber-500'
  } else if (pathname.startsWith('/search')) {
    loadingText = 'Searching catalog...'
    Icon = Search
    glowColor = 'from-zinc-500 via-slate-400 to-zinc-600'
  } else if (pathname.startsWith('/order')) {
    loadingText = 'Retrieving order status...'
    Icon = Package
    glowColor = 'from-primary via-red-500 to-pink-500'
  }

  return (
    <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-background/45 backdrop-blur-md animate-fade-in">
      {/* Outer subtle glowing mesh behind loader */}
      <div className={`absolute w-[280px] h-[280px] rounded-full bg-gradient-to-tr ${glowColor} opacity-10 blur-[80px] pointer-events-none animate-pulse-gentle`} />
      
      {/* Premium Glassmorphic Loader Card */}
      <div className="relative flex flex-col items-center p-8 rounded-3xl border border-white/[0.08] dark:border-white/[0.04] bg-white/70 dark:bg-zinc-950/70 shadow-elevated glass max-w-[280px] w-full text-center overflow-hidden animate-spring-in">
        
        {/* Animated Rotating Gradient Border */}
        <div className="absolute inset-0 -z-10 p-[1.5px] rounded-3xl overflow-hidden">
          <div className={`w-[200%] h-[200%] absolute top-[-50%] left-[-50%] bg-gradient-to-r ${glowColor} animate-spin-slow origin-center opacity-40`} />
          <div className="w-full h-full bg-white dark:bg-zinc-950 rounded-[22px]" />
        </div>

        {/* Animated Icon Ring */}
        <div className="relative flex items-center justify-center w-20 h-20 mb-5">
          {/* Pulsing glow underlay */}
          <div className="absolute inset-0 rounded-full bg-primary/15 blur-md animate-ping-slow" />
          
          {/* Spinner Ring */}
          <div className="absolute inset-0 border-[3px] border-primary/10 border-t-primary rounded-full animate-spin" style={{ animationDuration: '0.8s' }} />
          
          {/* Inner pulsating Icon */}
          <div className="relative flex items-center justify-center w-12 h-12 rounded-full bg-primary/10 text-primary animate-bounce-subtle">
            <Icon className="h-6 w-6 stroke-[2]" />
          </div>
        </div>

        {/* Brand Name */}
        <h3 className="text-lg font-black tracking-tight text-gradient-primary uppercase animate-pulse-gentle">
          FastKirana
        </h3>
        
        {/* Loading Subtext */}
        <p className="text-xs font-bold text-text-secondary mt-1.5 animate-pulse-gentle min-h-[16px]">
          {loadingText}
        </p>

        {/* Small horizontal linear progress bar */}
        <div className="w-24 h-1 bg-muted dark:bg-zinc-800 rounded-full mt-4 overflow-hidden">
          <div className="h-full bg-primary rounded-full w-full origin-left animate-progress" />
        </div>
      </div>
    </div>
  )
}
