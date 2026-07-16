import { PrismaClient } from '@prisma/client'

const p = new PrismaClient()

async function main() {
  const products = await p.product.findMany({
    select: {
      id: true,
      name: true,
      slug: true,
    }
  })
  console.log("Found products in DB:")
  console.log(JSON.stringify(products.slice(0, 10), null, 2))
}

main().catch(console.error).finally(() => p.$disconnect())
