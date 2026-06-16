import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkRecentOrders() {
  const orders = await prisma.order.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5,
    include: {
      items: true,
      user: {
        select: { email: true, name: true }
      }
    }
  })

  console.log(`Latest ${orders.length} orders:`)
  orders.forEach(o => {
    console.log(`- ID: ${o.id}, User: ${o.user.email}, Total: ₹${o.total}, Status: ${o.status}, PaymentStatus: ${o.paymentStatus}, Shop: ${o.shopName}, CreatedAt: ${o.createdAt.toISOString()}`)
    o.items.forEach(i => {
      console.log(`   * Item: ${i.name}, Qty: ${i.quantity}, Price: ${i.price}`)
    })
  })
}

checkRecentOrders()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
