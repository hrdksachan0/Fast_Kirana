import { redirect } from 'next/navigation'

export default async function OrderSuccessRedirect({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  redirect(`/order/${id}/success`)
}
