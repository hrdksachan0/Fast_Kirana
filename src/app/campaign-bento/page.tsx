import type { Metadata } from 'next'
import { InteractiveCampaignBento } from '@/components/home/interactive-campaign-bento'
import Link from 'next/link'
import { ArrowLeft, Sparkles } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Campaign Bento Hub | FastMinute',
  description: 'Interactive high-converting dynamic Bento campaign cards for FastMinute.',
  robots: { index: false, follow: false },
}

export default function CampaignBentoPage() {
  return (
    <main className="min-h-screen bg-[#FDFBF7] text-zinc-900 pb-20">
      {/* Top Bar */}
      <header className="sticky top-0 z-40 bg-[#FAF8F5]/90 backdrop-blur-md border-b border-amber-900/10 px-4 sm:px-8 py-3.5 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Link
            href="/"
            className="w-8 h-8 rounded-full bg-zinc-200/80 hover:bg-zinc-300 flex items-center justify-center text-zinc-700 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
          </Link>
          <div>
            <h1 className="text-base font-black tracking-tight text-zinc-900 flex items-center gap-1.5">
              <span>FastMinute Bento Studio</span>
              <span className="text-[10px] uppercase font-bold tracking-widest px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
                Live Interactive
              </span>
            </h1>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Link
            href="/campaign-studio"
            className="text-xs font-bold text-zinc-600 hover:text-zinc-900 px-3 py-1.5 rounded-lg border border-zinc-300 bg-white shadow-2xs transition-colors"
          >
            Campaign Studio ➔
          </Link>
        </div>
      </header>

      {/* The Dynamic Campaign Bento Hub */}
      <InteractiveCampaignBento />
    </main>
  )
}
