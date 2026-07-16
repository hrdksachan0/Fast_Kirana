import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const category = await prisma.category.findFirst({
    where: { slug: 'beverages' }
  })

  if (!category) {
    console.log('Beverages category not found')
    return
  }

  const products = await prisma.product.findMany({
    where: { categoryId: category.id },
    select: {
      id: true,
      name: true,
      slug: true,
      imageUrl: true,
      isAvailable: true,
    }
  })

  console.log('Beverages Products and Image URLs:')
  console.log(JSON.stringify(products, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
