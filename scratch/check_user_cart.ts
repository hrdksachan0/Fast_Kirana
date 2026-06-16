import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkCarts() {
  const carts = await prisma.cart.findMany({
    include: {
      user: {
        select: {
          email: true
        }
      },
      items: {
        include: {
          product: true
        }
      }
    }
  })

  console.log(`Found ${carts.length} carts:`)
  carts.forEach(c => {
    console.log(`- User: ${c.user.email}, Items count: ${c.items.length}`)
    c.items.forEach(item => {
      console.log(`  * Product ID: ${item.productId}, Name: "${item.product?.name}", Qty: ${item.quantity}, Stock: ${item.product?.stock}, Available: ${item.product?.isAvailable}`)
    })
  })
}

checkCarts()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
