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
    take: 10,
    include: {
      address: true,
      items: true
    }
  })
  console.log('Last 10 orders:')
  orders.forEach((o, index) => {
    console.log(`[${index}] ID: ${o.id}, Status: ${o.status}, DeliveryMethod: ${o.deliveryMethod}, Total: ${o.total}, AddressLabel: ${o.address?.label}, Pincode: ${o.address?.pincode}, City: ${o.address?.city}, Created: ${o.createdAt}`)
  })
}

checkOrders()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
  })
