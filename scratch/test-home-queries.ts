import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

const productSelect = {
  id: true,
  name: true,
  slug: true,
  description: true,
  imageUrl: true,
  categoryId: true,
  mrp: true,
  price: true,
  discount: true,
  unit: true,
  stock: true,
  isAvailable: true,
  tags: true,
  minStock: true,
  variants: true,
  category: {
    select: {
      id: true,
      name: true,
      slug: true,
      imageUrl: true,
      parentId: true,
      sortOrder: true,
    }
  }
}

async function main() {
  const flash = await prisma.product.findMany({
    where: {
      isAvailable: true,
      OR: [
        { isFlashDeal: true },
        { discount: { gt: 10 } }
      ]
    },
    select: productSelect
  })

  const best = await prisma.product.findMany({
    where: {
      isAvailable: true,
    },
    orderBy: [
      { isBestSeller: 'desc' },
      { createdAt: 'desc' }
    ],
    take: 150,
    select: productSelect
  })

  // Filter both lists for Beverages category (id: cmqgzqfz20008vkidoycqg5u2 or slug: beverages)
  const flashBeverages = flash.filter(p => p.category?.slug === 'beverages')
  const bestBeverages = best.filter(p => p.category?.slug === 'beverages')

  console.log(`Flash Deals total products: ${flash.length}, in beverages: ${flashBeverages.length}`)
  console.log('Flash beverages names:', flashBeverages.map(p => p.name))
  console.log(`Best Sellers total products: ${best.length}, in beverages: ${bestBeverages.length}`)
  console.log('Best beverages names:', bestBeverages.map(p => p.name))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
