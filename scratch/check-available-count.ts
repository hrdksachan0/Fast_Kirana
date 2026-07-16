import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const totalProducts = await prisma.product.count()
  const totalAvailable = await prisma.product.count({
    where: { isAvailable: true }
  })
  const categoryProducts = await prisma.product.findMany({
    where: {
      category: { slug: 'beverages' }
    },
    select: {
      name: true,
      createdAt: true,
      isAvailable: true,
    },
    orderBy: { createdAt: 'desc' }
  })

  console.log(`Total Products in Database: ${totalProducts}`)
  console.log(`Total Available Products: ${totalAvailable}`)
  console.log(`Beverages category products:`)
  console.log(JSON.stringify(categoryProducts, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
