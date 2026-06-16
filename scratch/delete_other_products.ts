import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('Starting product cleanup...')

  // 1. Count products before deletion
  const countBefore = await prisma.product.count()
  console.log(`Total products before cleanup: ${countBefore}`)

  // 2. Perform deletion of products NOT in 'cafe', 'beverages', and 'ice-cream' categories
  const result = await prisma.product.deleteMany({
    where: {
      category: {
        slug: {
          notIn: ['cafe', 'beverages', 'ice-cream']
        }
      }
    }
  })

  console.log(`Successfully deleted ${result.count} products.`)

  // 3. Count products after deletion
  const countAfter = await prisma.product.count()
  console.log(`Total products after cleanup: ${countAfter}`)
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
