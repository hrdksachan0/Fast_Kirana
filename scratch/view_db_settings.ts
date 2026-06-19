import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkSettings() {
  const settings = await prisma.storeSetting.findMany()
  console.log('Store settings:')
  settings.forEach(s => {
    console.log(`Key: ${s.key}, Value: ${s.value}`)
  })
}

checkSettings()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
  })
