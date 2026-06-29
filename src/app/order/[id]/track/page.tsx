import { TrackingPageClient } from '@/components/order/tracking-page-client'

interface OrderTrackingPageProps {
  params: Promise<{ id: string }>
}

export const dynamic = 'force-dynamic'

export default async function OrderTrackingPage({ params }: OrderTrackingPageProps) {
  const { id } = await params

  return <TrackingPageClient orderId={id} />
}
