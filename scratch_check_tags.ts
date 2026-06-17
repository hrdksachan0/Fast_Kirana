import { prisma } from './src/lib/prisma'

async function main() {
  const products = await prisma.product.findMany({
    include: { category: true }
  })
  
  console.log(`TOTAL PRODUCTS IN DB: ${products.length}`)
  
  const cafeMatched = products.filter(p => {
    // Check if category is cafe, or if it has tags matching cafe
    const isCafe = p.category.slug === 'cafe'
    const hasTags = p.tags && p.tags.length > 0
    return isCafe || hasTags
  })
  
  console.log(`\nMatched Cafe/Tagged products count: ${cafeMatched.length}`)
  for (const p of cafeMatched) {
    console.log(`- ${p.name} (Category: ${p.category.slug}, Tags: ${JSON.stringify(p.tags)}, isAvailable: ${p.isAvailable})`)
  }
}

main().catch(console.error).finally(() => process.exit(0))
