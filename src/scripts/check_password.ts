import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import bcrypt from 'bcryptjs'
import dotenv from 'dotenv'

dotenv.config()

const pool = new Pool({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
})
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  const rider = await prisma.user.findFirst({
    where: {
      role: 'DELIVERY',
    },
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      role: true,
    },
  })

  console.log('Rider Account Details:', rider)

  if (rider) {
    const newPassword = 'delivery123'
    const passwordHash = await bcrypt.hash(newPassword, 12)

    await prisma.user.update({
      where: { id: rider.id },
      data: { passwordHash },
    })

    console.log(`Successfully set password for ${rider.email} to: ${newPassword}`)
  }
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
