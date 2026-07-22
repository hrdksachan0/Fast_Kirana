import { Zap, Package, Leaf, Heart } from 'lucide-react'

interface SpeedStat {
  icon: React.ComponentType<any>
  iconColor: string
  label: string
  value: string
}

interface SpeedStripProps {
  avgDelivery?: string
  deliveredCount?: string
  freshStock?: string
  happyFamilies?: string
}

export function SpeedStrip({
  avgDelivery = 'Ghatampur',
  deliveredCount = '1,231+',
  freshStock = '2 hrs ago',
  happyFamilies = '5,000+',
}: SpeedStripProps) {
  const stats: SpeedStat[] = [
    { icon: Zap, iconColor: 'text-amber-500 fill-amber-500/10', label: 'Delivery Zone', value: 'Ghatampur' },
    { icon: Package, iconColor: 'text-blue-500 fill-blue-500/10', label: 'Delivered Today', value: deliveredCount },
    { icon: Leaf, iconColor: 'text-emerald-500 fill-emerald-500/10', label: 'Fresh Stock Loaded', value: freshStock },
    { icon: Heart, iconColor: 'text-rose-500 fill-rose-500/10', label: 'Happy Families', value: happyFamilies },
  ]

  return (
    <section className="py-1.5 md:py-3">
      {/* Mobile: Compact stats bar */}
      <div className="flex md:hidden items-center justify-center gap-4 px-3 py-2.5 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 border border-zinc-200/50 dark:border-zinc-800/30 shadow-xs">
        <div className="flex items-center gap-1.5">
          <span className="relative flex h-1.5 w-1.5 flex-shrink-0">
            <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-accent" />
          </span>
          <Zap className="h-3 w-3 text-amber-500 fill-amber-500/10" />
          <span className="text-[10px] font-black text-text-primary">Ghatampur</span>
        </div>
        <span className="h-3 w-[1px] bg-zinc-200 dark:bg-zinc-700" />
        <div className="flex items-center gap-1.5">
          <Package className="h-3 w-3 text-blue-500 fill-blue-500/10" />
          <span className="text-[10px] font-black text-text-primary">{deliveredCount}</span>
        </div>
        <span className="h-3 w-[1px] bg-zinc-200 dark:bg-zinc-700" />
        <div className="flex items-center gap-1.5">
          <Heart className="h-3 w-3 text-rose-500 fill-rose-500/10" />
          <span className="text-[10px] font-black text-text-primary">{happyFamilies}</span>
        </div>
      </div>

      {/* Desktop: Elegant 4-Column Grid (Static & Premium) */}
      <div className="hidden md:grid grid-cols-4 gap-4">
        {stats.map((stat, index) => (
          <div
            key={index}
            className="flex items-center gap-3 p-3 bg-white/60 dark:bg-zinc-900/35 rounded-2xl shadow-xs border border-zinc-200/50 dark:border-zinc-800/60 backdrop-blur-xs hover:bg-white/80 dark:hover:bg-zinc-900/50 transition-colors"
          >
            {/* Live Indicator Dot */}
            <span className="relative flex h-2 w-2 flex-shrink-0">
              <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
            </span>

            {/* Icon Wrapper */}
            <span className="flex-shrink-0 flex items-center justify-center p-1.5 rounded bg-zinc-50 dark:bg-zinc-900/65 shadow-xs border border-zinc-200/30 dark:border-zinc-800/50" aria-label={stat.label}>
              <stat.icon className={`h-4 w-4 ${stat.iconColor}`} />
            </span>

            {/* Label and Value */}
            <div className="flex flex-col text-left">
              <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider">
                {stat.label}
              </span>
              <span className="text-sm font-black text-text-primary">
                {stat.value}
              </span>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
