import { Loader2, ShoppingBag } from 'lucide-react'

export default function Loading() {
  return (
    <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-background/80 backdrop-blur-md transition-all duration-300">
      {/* Outer subtle glowing mesh behind loader */}
      <div className="absolute w-[300px] h-[300px] rounded-full bg-primary/10 blur-[80px] pointer-events-none animate-pulse-gentle" />
      
      {/* Glassmorphic Loader Container */}
      <div className="relative flex flex-col items-center p-8 rounded-3xl border border-border/60 bg-card/75 shadow-elevated glass max-w-[280px] w-full text-center">
        {/* Animated Icon Ring */}
        <div className="relative flex items-center justify-center w-20 h-20 mb-5">
          {/* Pulsing glow underlay */}
          <div className="absolute inset-0 rounded-full bg-primary/20 blur-md animate-ping-slow" />
          
          {/* Spinner Ring */}
          <div className="absolute inset-0 border-4 border-primary/10 border-t-primary rounded-full animate-spin" />
          
          {/* Inner pulsating Shopping Bag */}
          <div className="relative flex items-center justify-center w-12 h-12 rounded-full bg-primary/10 text-primary animate-bounce-subtle">
            <ShoppingBag className="h-6 w-6 stroke-[2]" />
          </div>
        </div>

        {/* Brand Name */}
        <h3 className="text-lg font-black tracking-tight text-gradient-primary uppercase animate-pulse-gentle">
          FastKirana
        </h3>
        
        {/* Loading Subtext */}
        <p className="text-xs font-semibold text-text-secondary mt-1.5 animate-pulse-gentle">
          Getting fresh items for you...
        </p>

        {/* Small horizontal linear progress bar */}
        <div className="w-24 h-1 bg-muted rounded-full mt-4 overflow-hidden">
          <div className="h-full bg-primary rounded-full w-full origin-left animate-progress" />
        </div>
      </div>
    </div>
  )
}
