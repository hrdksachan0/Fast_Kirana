import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  try {
    const settings = await prisma.storeSetting.findMany()
    console.log("All Store Settings in DB:")
    console.log(JSON.stringify(settings, null, 2))
  } catch (error) {
    console.error("Error querying database:", error)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
