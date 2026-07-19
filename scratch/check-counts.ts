import { prisma } from '../src/lib/prisma'

async function main() {
  const categories = await prisma.category.findMany({
    include: {
      _count: {
        select: { products: true }
      }
    }
  })
  console.log("Categories and product counts:")
  categories.forEach(c => {
    console.log(`- Slug: "${c.slug}" | Name: "${c.name}" | Products count: ${c._count.products}`)
  })
}

main().catch(console.error)
