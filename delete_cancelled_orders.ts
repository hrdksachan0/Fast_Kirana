import { prisma } from './src/lib/prisma'

async function main() {
  console.log('Fetching cancelled orders count...')
  const count = await prisma.order.count({
    where: { status: 'CANCELLED' }
  })
  
  console.log(`Found ${count} cancelled orders. Deleting them...`)
  const result = await prisma.order.deleteMany({
    where: { status: 'CANCELLED' }
  })
  
  console.log(`Successfully deleted ${result.count} cancelled orders from the database!`)
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
