import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkAddresses() {
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) {
    console.error('User not found')
    process.exit(1)
  }

  const addresses = await prisma.address.findMany({
    where: { userId: user.id }
  })
  console.log(`Addresses for user ${user.email}:`)
  addresses.forEach((a, index) => {
    console.log(`[${index}] ID: ${a.id}, Label: ${a.label}, HouseNo: ${a.houseNo}, Street: ${a.street}, Area: ${a.area}, City: ${a.city}, Pincode: ${a.pincode}, Phone: ${a.phone}`)
  })
}

checkAddresses()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
  })
