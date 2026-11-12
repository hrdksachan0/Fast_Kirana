import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const pool = new Pool({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
})
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  const newPhone = process.env.RIDER_NEW_PHONE || process.argv[2]
  if (!newPhone) {
    console.error('Usage: tsx src/scripts/update_rider_phone.ts <new-phone> or set RIDER_NEW_PHONE')
    process.exit(1)
  }

  const updatedRider = await prisma.user.update({
    where: {
      email: process.env.RIDER_EMAIL || process.argv[3] || 'delivery@fastkirana.com',
    },
    data: {
      name: 'FastKirana Delivery Executive',
      phone: newPhone,
    },
  })

  console.log('=== RIDER PHONE UPDATED IN DATABASE ===')
  console.log(updatedRider)
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
    await pool.end()
  })
