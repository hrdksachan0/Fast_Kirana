const { PrismaClient } = require('@prisma/client')
const { PrismaPg } = require('@prisma/adapter-pg')
const { Pool } = require('pg')
const dotenv = require('dotenv')
dotenv.config()

let connectionString = process.env.DATABASE_URL || ''
if (connectionString) {
  connectionString = connectionString.replace(/\r/g, '').trim()
  if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
    connectionString = connectionString.substring(1, connectionString.length - 1)
  }
}

const pool = new Pool({
  connectionString,
  max: 1
})
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  const settings = await prisma.storeSetting.findMany()
  console.log(JSON.stringify(settings, null, 2))
}

main().catch(console.error).finally(async () => {
  await prisma.$disconnect()
  await pool.end()
})
