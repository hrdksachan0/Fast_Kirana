import 'dotenv/config'
import { prisma } from './src/lib/prisma'

async function main() {
  const categories = await prisma.category.findMany({
    select: {
      name: true,
      slug: true,
      _count: {
        select: { products: true }
      }
    }
  })
  console.log('--- DB Categories Summary ---')
  console.log(JSON.stringify(categories, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
