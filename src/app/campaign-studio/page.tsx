import type { Metadata } from 'next'
import { CampaignStudio } from '@/components/campaign-studio/campaign-studio'

export const metadata: Metadata = {
  title: 'Campaign Design Studio',
  robots: { index: false, follow: false },
}

export default function CampaignStudioPage() {
  return <CampaignStudio />
}
