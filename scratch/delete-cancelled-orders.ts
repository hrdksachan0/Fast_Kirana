import 'dotenv/config'
import { PrismaClient, OrderStatus } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  try {
    // 1. Get count of cancelled orders
    const count = await prisma.order.count({
      where: { status: OrderStatus.CANCELLED }
    })
    console.log(`Found ${count} CANCELLED orders in database.`)

    if (count > 0) {
      // 2. Delete the cancelled orders (related OrderItems will be cascade deleted)
      const deleted = await prisma.order.deleteMany({
        where: { status: OrderStatus.CANCELLED }
      })
      console.log(`Successfully deleted ${deleted.count} CANCELLED orders (and their associated order items).`)
    } else {
      console.log("No CANCELLED orders found to delete.")
    }
  } catch (error) {
    console.error("Error deleting cancelled orders:", error)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
