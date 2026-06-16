import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkOrderDetail() {
  const orderId = 'cmqfj537r0000j8idqbe2tmmx'
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    include: { items: true }
  })

  if (!order) {
    console.log(`Order ${orderId} not found`)
    return
  }

  console.log(`Order ${orderId} detail:`)
  console.log(`- Subtotal: ${order.subtotal}`)
  console.log(`- Discount: ${order.discount}`)
  console.log(`- Delivery Fee: ${order.deliveryFee}`)
  console.log(`- Taxes: ${order.taxes}`)
  console.log(`- Total: ${order.total}`)
  console.log(`- Items:`)
  order.items.forEach(i => {
    console.log(`  * ID: ${i.id}, Name: ${i.name}, Qty: ${i.quantity}, Price: ${i.price}`)
  })
}

checkOrderDetail()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
