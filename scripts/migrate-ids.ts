import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('Starting migration to backfill readableIds...')

  // 1. Backfill Products
  const products = await prisma.product.findMany({
    where: { readableId: null },
    orderBy: { createdAt: 'asc' }
  })
  console.log(`Found ${products.length} products to backfill.`)

  let productCount = 0
  for (let i = 0; i < products.length; i++) {
    const p = products[i]
    const assignedId = 200000 + i + 1
    await prisma.product.update({
      where: { id: p.id },
      data: { readableId: assignedId }
    })
    productCount++
  }
  console.log(`Successfully backfilled ${productCount} products.`)

  // 2. Backfill Orders
  const orders = await prisma.order.findMany({
    where: { readableId: null },
    orderBy: { createdAt: 'asc' }
  })
  console.log(`Found ${orders.length} orders to backfill.`)

  let orderCount = 0
  for (let i = 0; i < orders.length; i++) {
    const o = orders[i]
    const assignedId = 600000 + i + 1
    await prisma.order.update({
      where: { id: o.id },
      data: { readableId: assignedId }
    })
    orderCount++
  }
  console.log(`Successfully backfilled ${orderCount} orders.`)

  console.log('Migration completed successfully!')
}

main()
  .catch((e) => {
    console.error('Migration failed:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
