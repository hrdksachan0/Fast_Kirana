import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('--- Searching for Amul/Taaza/Milk ---')
  const products = await prisma.product.findMany({
    select: {
      id: true,
      name: true,
      slug: true,
      stock: true,
      isAvailable: true
    }
  })
  
  const matches = products.filter(p => 
    p.name.toLowerCase().includes('amul') || 
    p.name.toLowerCase().includes('taaza') ||
    p.name.toLowerCase().includes('milk')
  )
  
  console.log('Matches found:', JSON.stringify(matches, null, 2))
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
