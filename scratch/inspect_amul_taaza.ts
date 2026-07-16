import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('--- Inspecting Amul Milk ---')
  const products = await prisma.product.findMany({
    where: {
      name: { contains: 'Amul', mode: 'insensitive' }
    },
    include: {
      inventories: {
        include: {
          store: true
        }
      }
    }
  })

  console.log(JSON.stringify(products, null, 2))
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
