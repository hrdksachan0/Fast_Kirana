import { prisma } from '../src/lib/prisma'

async function main() {
  const allOrders = await prisma.order.findMany({
    select: {
      id: true,
      status: true,
      total: true,
      createdAt: true
    }
  })

  console.log('All Orders:')
  allOrders.forEach(o => {
    console.log(`Order ID: ${o.id}, Status: ${o.status}, Total: ${o.total}, CreatedAt: ${o.createdAt}`)
  })

  const deliveredTotal = allOrders
    .filter(o => o.status === 'DELIVERED')
    .reduce((sum, o) => sum + o.total, 0)

  const grandTotalAll = allOrders
    .reduce((sum, o) => sum + o.total, 0)

  console.log('\nCalculated Stats:')
  console.log(`Total Orders in DB: ${allOrders.length}`)
  console.log(`Delivered Orders Count: ${allOrders.filter(o => o.status === 'DELIVERED').length}`)
  console.log(`Sum of DELIVERED orders: ₹${deliveredTotal}`)
  console.log(`Sum of ALL orders: ₹${grandTotalAll}`)
}

main()
  .catch(err => console.error(err))
  .finally(() => prisma.$disconnect())
