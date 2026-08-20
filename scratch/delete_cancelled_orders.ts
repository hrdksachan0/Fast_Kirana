import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('--- DELETING ALL CANCELLED ORDERS ---')
  try {
    const countBefore = await prisma.order.count({
      where: { status: 'CANCELLED' }
    })

    console.log(`Found ${countBefore} CANCELLED orders in DB. Deleting...`)

    const deleted = await prisma.order.deleteMany({
      where: { status: 'CANCELLED' }
    })

    console.log(`Successfully deleted ${deleted.count} CANCELLED orders from DB.`)
  } catch (err) {
    console.error('Error deleting cancelled orders:', err)
  } finally {
    await prisma.$disconnect()
  }
}

main()
