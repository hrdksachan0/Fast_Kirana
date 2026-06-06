'use client'

import { useEffect, useState } from 'react'
import { Zap, Package, Leaf, Heart } from 'lucide-react'

interface SpeedStat {
  icon: React.ComponentType<any>
  iconColor: string
  label: string
  value: string
}

export function SpeedStrip() {
  const [ordersToday, setOrdersToday] = useState(1200)

  // Simulate live-feeling order count that ticks up occasionally
  useEffect(() => {
    const interval = setInterval(() => {
      setOrdersToday((prev) => prev + Math.floor(Math.random() * 3) + 1)
    }, 5000)
    return () => clearInterval(interval)
  }, [])

  const stats: SpeedStat[] = [
    { icon: Zap, iconColor: 'text-amber-500 fill-amber-500/10', label: 'Avg Delivery', value: '8 min' },
    { icon: Package, iconColor: 'text-blue-500 fill-blue-500/10', label: 'Delivered Today', value: `${ordersToday.toLocaleString('en-IN')}+` },
    { icon: Leaf, iconColor: 'text-emerald-500 fill-emerald-500/10', label: 'Fresh Stock Loaded', value: '2 hrs ago' },
    { icon: Heart, iconColor: 'text-rose-500 fill-rose-500/10', label: 'Happy Families', value: '5,000+' },
  ]

  return (
    <section className="py-3">
      <div className="relative overflow-hidden rounded-xl glass shadow-sm">
        {/* Subtle gradient overlay on edges for fade effect */}
        <div className="absolute left-0 top-0 bottom-0 w-8 bg-gradient-to-r from-white/80 dark:from-zinc-950/80 to-transparent z-10 pointer-events-none" />
        <div className="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-white/80 dark:from-zinc-950/80 to-transparent z-10 pointer-events-none" />

        {/* Ticker container */}
        <div className="py-3 px-2">
          <div className="animate-ticker flex w-max">
            {/* First set of stats */}
            {stats.map((stat, index) => (
              <div
                key={`stat-a-${index}`}
                className="flex items-center gap-2 px-5 md:px-8"
              >
                {/* Pulsing green dot */}
                <span className="relative flex h-2 w-2 flex-shrink-0">
                  <span className="animate-ping-slow absolute inline-flex h-full w-full rounded-full bg-accent opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
                </span>

                {/* Icon */}
                <span className="flex-shrink-0 flex items-center justify-center p-1 rounded bg-white/60 dark:bg-zinc-800/60 shadow-sm border border-white/80 dark:border-zinc-700/60" aria-label={stat.label}>
                  <stat.icon className={`h-4 w-4 ${stat.iconColor}`} />
                </span>

                {/* Stat text */}
                <div className="flex items-center gap-1.5 whitespace-nowrap">
                  <span className="text-xs font-medium text-text-secondary">
                    {stat.label}
                  </span>
                  <span className="text-sm font-bold text-text-primary">
                    {stat.value}
                  </span>
                </div>

                {/* Separator dot */}
                {index < stats.length - 1 && (
                  <span className="ml-3 h-1 w-1 rounded-full bg-border flex-shrink-0" />
                )}
              </div>
            ))}

            {/* Duplicated set for seamless infinite scroll */}
            {stats.map((stat, index) => (
              <div
                key={`stat-b-${index}`}
                className="flex items-center gap-2 px-5 md:px-8"
              >
                {/* Pulsing green dot */}
                <span className="relative flex h-2 w-2 flex-shrink-0">
                  <span className="animate-ping-slow absolute inline-flex h-full w-full rounded-full bg-accent opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
                </span>

                {/* Icon */}
                <span className="flex-shrink-0 flex items-center justify-center p-1 rounded bg-white/60 dark:bg-zinc-800/60 shadow-sm border border-white/80 dark:border-zinc-700/60" aria-label={stat.label}>
                  <stat.icon className={`h-4 w-4 ${stat.iconColor}`} />
                </span>

                {/* Stat text */}
                <div className="flex items-center gap-1.5 whitespace-nowrap">
                  <span className="text-xs font-medium text-text-secondary">
                    {stat.label}
                  </span>
                  <span className="text-sm font-bold text-text-primary">
                    {stat.value}
                  </span>
                </div>

                {/* Separator dot */}
                {index < stats.length - 1 && (
                  <span className="ml-3 h-1 w-1 rounded-full bg-border flex-shrink-0" />
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
