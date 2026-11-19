import { redirect } from 'next/navigation'

interface Props {
  params: Promise<{ id: string }>
}

export default async function OrdersIdRedirectPage({ params }: Props) {
  const { id } = await params
  redirect(`/order/${id}/track`)
}
