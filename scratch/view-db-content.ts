import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const categories = await prisma.category.findMany()
  console.log('CATEGORIES:')
  console.log(categories.map(c => ({ id: c.id, name: c.name, slug: c.slug, imageUrl: c.imageUrl })))

  const products = await prisma.product.findMany({
    where: {
      OR: [
        { name: { contains: 'Farmers', mode: 'insensitive' } },
        { description: { contains: 'Farmers', mode: 'insensitive' } }
      ]
    }
  })
  console.log('PRODUCTS WITH FARMERS:')
  console.log(products.map(p => ({ id: p.id, name: p.name })))

  const settings = await prisma.storeSetting.findMany()
  console.log('SETTINGS:')
  console.log(settings)

  const banners = await prisma.promoBanner.findMany()
  console.log('ALL BANNERS:')
  console.log(banners)
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
