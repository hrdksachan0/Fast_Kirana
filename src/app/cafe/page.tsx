import { redirect } from 'next/navigation'
import { prisma } from '@/lib/prisma'

export default async function CafePage() {
  // Find A.S Cafe restaurant slug to redirect
  const cafe = await prisma.restaurant.findFirst({
    where: {
      OR: [
        { slug: { contains: 'cafe' } },
        { name: { contains: 'Cafe', mode: 'insensitive' } },
      ],
      isActive: true,
    },
    select: { slug: true },
  })

  if (cafe) {
    redirect(`/food/${cafe.slug}`)
  }

  redirect('/food')
}
