import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkUserAddress() {
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) {
    console.log('User not found')
    return
  }

  const addresses = await prisma.address.findMany({
    where: { userId: user.id }
  })

  console.log(`Addresses for ${user.email}:`)
  addresses.forEach(a => {
    console.log(`- ID: ${a.id}, Label: ${a.label}, Pincode: ${a.pincode}, City: ${a.city}, Street: ${a.street}, Default: ${a.isDefault}`)
  })
}

checkUserAddress()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
