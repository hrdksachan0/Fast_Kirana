import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function checkProducts() {
  const products = await prisma.product.findMany({
    where: {
      OR: [
        { name: { contains: 'Dosa', mode: 'insensitive' } },
        { name: { contains: 'Sandwitch', mode: 'insensitive' } },
        { name: { contains: 'Potato', mode: 'insensitive' } },
        { name: { contains: 'Paneer', mode: 'insensitive' } },
      ]
    },
    include: {
      category: true
    }
  })

  console.log(`Found ${products.length} matching products:`)
  products.forEach(p => {
    console.log(`- ID: ${p.id}, Name: ${p.name}, Slug: ${p.slug}, Category: ${p.category?.name} (${p.category?.slug}), Price: ${p.price}, Stock: ${p.stock}, Tags: ${JSON.stringify(p.tags)}`)
  })
}

checkProducts()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
