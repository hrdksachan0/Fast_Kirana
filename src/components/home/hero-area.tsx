'use client'

import { HeroBanner } from './hero-banner'

interface HeroAreaProps {
  initialBanners?: any[]
}

export function HeroArea({ initialBanners }: HeroAreaProps) {
  return (
    <div className="w-full relative z-10">
      <HeroBanner initialBanners={initialBanners} mode="grocery" />
    </div>
  )
}
