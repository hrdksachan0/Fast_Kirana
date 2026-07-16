import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  await prisma.promoBanner.upsert({
    where: { id: 'birthday-special-banner' },
    update: {
      title: 'Make Your Birthday Special',
      description: 'freshly baked custom birthday cakes and party essentials. Order now for instant delivery!',
      gradient: 'from-pink-500 via-purple-500 to-amber-500',
      type: 'birthday-special',
      isActive: true,
    },
    create: {
      id: 'birthday-special-banner',
      title: 'Make Your Birthday Special',
      description: 'freshly baked custom birthday cakes and party essentials. Order now for instant delivery!',
      code: '',
      gradient: 'from-pink-500 via-purple-500 to-amber-500',
      type: 'birthday-special',
      isActive: true,
      sortOrder: 0,
    }
  })
  console.log('✅ Birthday banner seeded in database!')
}

main()
  .then(() => prisma.$disconnect())
  .catch((e) => {
    console.error(e)
    prisma.$disconnect()
  })
