import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('--- CHECKING CANCELLED ORDERS IN DB ---')
  try {
    const cancelledOrders = await prisma.order.findMany({
      where: {
        status: 'CANCELLED'
      },
      select: {
        id: true,
        status: true,
        userId: true,
        createdAt: true
      }
    })
    console.log(`Found ${cancelledOrders.length} CANCELLED orders:`)
    console.log(JSON.stringify(cancelledOrders, null, 2))
  } catch (err) {
    console.error('Error:', err)
  }
}

main()
