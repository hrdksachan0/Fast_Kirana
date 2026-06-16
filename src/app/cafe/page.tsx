import { prisma } from '@/lib/prisma'
import { CafeStorefront } from '@/components/cafe/cafe-storefront'
import { Suspense } from 'react'

export const dynamic = 'force-dynamic'

export default async function CafePage() {
  // 1. Fetch or create Cafe category just for DB consistency
  let cafeCategory = null
  try {
    cafeCategory = await prisma.category.findUnique({
      where: { slug: 'cafe' }
    })

    if (!cafeCategory) {
      cafeCategory = await prisma.category.create({
        data: {
          name: 'FastKirana Cafe',
          slug: 'cafe',
          imageUrl: '/cafe_category.png',
          sortOrder: 0,
        }
      })
    } else if (cafeCategory.imageUrl === '☕') {
      // Update existing cafe category with proper image
      cafeCategory = await prisma.category.update({
        where: { id: cafeCategory.id },
        data: { imageUrl: '/cafe_category.png' }
      })
    }
  } catch (e) {
    console.warn('Database connection error in cafe page: failed to fetch cafe category')
  }

  // 2. Fetch all products under Cafe category
  let dbCafeProducts: any[] = []
  try {
    dbCafeProducts = await prisma.product.findMany({
      where: {
        category: {
          slug: 'cafe'
        },
        isAvailable: true,
      },
      include: { category: true }
    })
  } catch (e) {
    console.warn('Database connection error in cafe page: failed to fetch cafe products')
  }

  // 3. Load custom cafe menu sections if defined
  let customMenuSections = null
  try {
    const setting = await prisma.storeSetting.findUnique({
      where: { key: 'cafe_menu_sections' }
    })
    if (setting) {
      customMenuSections = JSON.parse(setting.value)
    }
  } catch (e) {
    console.warn('Failed to fetch/parse cafe menu sections:', e)
  }

  return (
    <Suspense fallback={<div className="container mx-auto px-4 py-20 text-center font-extrabold text-text-muted">Loading FastKirana Café...</div>}>
      <CafeStorefront initialProducts={dbCafeProducts} customSections={customMenuSections || undefined} />
    </Suspense>
  )
}
