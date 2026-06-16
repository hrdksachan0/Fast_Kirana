import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkOrders() {
  const orders = await prisma.order.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5,
    include: {
      user: {
        select: {
          email: true
        }
      },
      items: true
    }
  })

  console.log(`Last 5 orders:`)
  orders.forEach(o => {
    console.log(`- ID: ${o.id}, User: ${o.user.email}, Status: ${o.status}, Total: ${o.total}, Shop: "${o.shopName}", Items count: ${o.items.length}, CreatedAt: ${o.createdAt.toISOString()}`)
  })
}

checkOrders()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
