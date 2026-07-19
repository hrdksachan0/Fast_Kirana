import { prisma } from '../src/lib/prisma'

async function main() {
  const products = await prisma.product.findMany({
    where: { category: { slug: 'cafe' } },
    select: { name: true, tags: true },
    take: 20
  })
  products.forEach(p => console.log(p.name, '|', JSON.stringify(p.tags)))
  
  console.log('\n--- Restaurant products ---')
  const restProducts = await prisma.product.findMany({
    where: { category: { slug: 'restaurant' } },
    select: { name: true, tags: true },
    take: 20
  })
  restProducts.forEach(p => console.log(p.name, '|', JSON.stringify(p.tags)))
}

main().catch(console.error)
