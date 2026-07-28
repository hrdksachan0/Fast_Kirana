import { redirect } from 'next/navigation'

export default async function RestaurantSlugPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  redirect(`/food/${slug}`)
}
