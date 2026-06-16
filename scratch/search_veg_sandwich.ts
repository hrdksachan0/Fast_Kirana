import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function searchProduct() {
  const products = await prisma.product.findMany({
    where: {
      name: { contains: 'Sand', mode: 'insensitive' }
    }
  })

  console.log(`Found ${products.length} products matching "Sand":`)
  products.forEach(p => {
    console.log(`- ID: ${p.id}, Name: "${p.name}", Slug: "${p.slug}", Price: ${p.price}`)
  })
}

searchProduct()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
