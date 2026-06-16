import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  const products = await prisma.product.findMany({
    include: {
      category: true
    }
  })
  
  const cafeProducts = products.filter(p => 
    p.category?.slug === 'cafe' || 
    p.tags?.some((t: string) => t.toLowerCase() === 'cafe')
  )
  
  console.log(`Found ${cafeProducts.length} Cafe products:`)
  cafeProducts.forEach(p => {
    console.log(`- ID: ${p.id}, Name: "${p.name}", Slug: "${p.slug}", Price: ${p.price}, MRP: ${p.mrp}, Unit: "${p.unit}", Tags: ${JSON.stringify(p.tags)}`)
  })
}

main()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
