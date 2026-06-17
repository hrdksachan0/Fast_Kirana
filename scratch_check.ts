import { prisma } from './src/lib/prisma'

async function main() {
  const categories = await prisma.category.findMany({
    include: { _count: { select: { products: true } } }
  })
  console.log('=== DB STATUS ===')
  for (const c of categories) {
    console.log(`- Category: ${c.name} (slug: ${c.slug}), Products: ${c._count.products}`)
  }
}

main().catch(console.error).finally(() => process.exit(0))
