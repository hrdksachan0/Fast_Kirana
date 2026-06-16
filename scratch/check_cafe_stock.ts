import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkStock() {
  const products = await prisma.product.findMany({
    where: {
      category: { slug: 'cafe' }
    },
    select: {
      id: true,
      name: true,
      stock: true,
      isAvailable: true
    }
  })

  console.log(`Cafe products stock details:`)
  products.forEach(p => {
    console.log(`- Name: "${p.name}", Stock: ${p.stock}, Available: ${p.isAvailable}`)
  })
}

checkStock()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
