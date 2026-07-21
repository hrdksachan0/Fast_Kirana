import { prisma } from '../src/lib/prisma'

const SYNONYM_DICTIONARY: Record<string, string[]> = {
  'aalu': ['potato', 'aloo'],
  'aloo': ['potato', 'aalu'],
  'pyaz': ['onion', 'pyaj'],
  'pyaj': ['onion', 'pyaz'],
  'doodh': ['milk', 'dudh'],
  'dudh': ['milk', 'doodh'],
  'dahi': ['curd', 'yogurt'],
  'anda': ['egg', 'eggs'],
  'tamatar': ['tomato', 'tomatoes'],
  'makhan': ['butter'],
  'nimbu': ['lemon', 'lime'],
  'chai': ['tea'],
  'patti': ['tea'],
  'pani': ['water'],
  'chawal': ['rice'],
  'chini': ['sugar'],
  'namak': ['salt']
}

async function testSearch(search: string) {
  console.log(`\nTesting search for: "${search}"`)
  
  const searchWords = search.trim().toLowerCase().split(/\s+/)
  const wordClauses = searchWords.map(w => {
    const syns = SYNONYM_DICTIONARY[w] || []
    const wordOptions = [w, ...syns]
    
    return {
      OR: wordOptions.flatMap(opt => [
        { name: { contains: opt, mode: 'insensitive' } },
        { description: { contains: opt, mode: 'insensitive' } },
        { tags: { has: opt } }
      ])
    }
  })

  const products = await prisma.product.findMany({
    where: {
      AND: wordClauses
    },
    select: {
      name: true,
      price: true,
      stock: true
    },
    take: 5
  })
  
  console.log(`Results: ${products.length} found`)
  products.forEach(p => console.log(`- ${p.name} (₹${p.price})`))
}

async function main() {
  await testSearch('doodh')
  await testSearch('aalu')
  await testSearch('Roti Butter')
}

main().catch(console.error)
