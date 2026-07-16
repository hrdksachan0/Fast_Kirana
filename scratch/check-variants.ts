import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const products = await prisma.product.findMany({
    select: {
      id: true,
      name: true,
      variants: true
    }
  })

  const withCost = products.filter(p => {
    if (!p.variants || !Array.isArray(p.variants)) return false
    return p.variants.some((v: any) => v.costPrice > 0)
  })

  console.log(`Found ${withCost.length} products with non-zero variant costPrice:`)
  console.log(JSON.stringify(withCost, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
