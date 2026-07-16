import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const categories = await prisma.category.findMany({
    select: {
      id: true,
      name: true,
      slug: true,
      parentId: true,
      _count: {
        select: { products: true }
      }
    }
  })
  console.log('Categories in DB:')
  console.log(JSON.stringify(categories, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
