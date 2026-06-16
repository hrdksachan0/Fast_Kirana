import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('Querying categories and product counts from DB...')
  const categories = await prisma.category.findMany({
    include: {
      _count: {
        select: { products: true }
      }
    }
  })
  console.log('Categories list in DB:')
  categories.forEach(cat => {
    console.log(`- ID: ${cat.id}, Name: "${cat.name}", Slug: "${cat.slug}", Products Count: ${cat._count.products}`)
  })
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
