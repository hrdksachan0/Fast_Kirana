import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  // Find category beverages
  const category = await prisma.category.findFirst({
    where: {
      OR: [
        { slug: { contains: 'beverage', mode: 'insensitive' } },
        { name: { contains: 'beverage', mode: 'insensitive' } }
      ]
    }
  })

  if (!category) {
    console.log('Beverages category not found')
    return
  }

  console.log('Beverages Category details:', category)

  // Find all products in this category
  const products = await prisma.product.findMany({
    where: { categoryId: category.id },
    select: {
      id: true,
      name: true,
      slug: true,
      isAvailable: true,
      stock: true,
      price: true,
      mrp: true,
      discount: true,
      tags: true,
      isFlashDeal: true,
      isBestSeller: true,
    }
  })

  console.log(`Total products in Beverages: ${products.length}`)
  console.log(JSON.stringify(products, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
