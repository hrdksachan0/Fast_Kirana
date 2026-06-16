import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkAllUserOrders() {
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) {
    console.log('User not found')
    return
  }

  const orders = await prisma.order.findMany({
    where: {
      userId: user.id,
      createdAt: {
        gte: new Date('2026-06-15T00:00:00Z')
      }
    },
    include: { items: true },
    orderBy: { createdAt: 'desc' }
  })

  console.log(`Found ${orders.length} orders for ${user.email} on 2026-06-15:`)
  orders.forEach(o => {
    console.log(`- Order ID: ${o.id}, Shop: ${o.shopName}, Subtotal: ${o.subtotal}, Taxes: ${o.taxes}, Total: ${o.total}, Status: ${o.status}, PaymentStatus: ${o.paymentStatus}, CreatedAt: ${o.createdAt.toISOString()}`)
    o.items.forEach(i => {
      console.log(`   * Item: ${i.name}, Qty: ${i.quantity}, Price: ${i.price}`)
    })
  })
}

checkAllUserOrders()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
