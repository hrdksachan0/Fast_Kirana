import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('--- Updating Amul Taaza Milk to Out of Stock ---')
  const result = await prisma.product.updateMany({
    where: {
      name: { contains: 'Amul Taaza', mode: 'insensitive' }
    },
    data: {
      stock: 0,
      isAvailable: false
    }
  })

  console.log('Updated rows:', result)
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
