import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const pool = new Pool({
  connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL,
})
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  const OLD_CLOUD = 'dvcsjvpbg'
  const NEW_CLOUD = 'dbf3lhk94'

  console.log(`Checking for old cloud name "${OLD_CLOUD}" in database...`)

  // Check store_settings
  const settingsWithOld = await prisma.storeSetting.findMany({
    where: { value: { contains: OLD_CLOUD } },
  })
  console.log(`Found ${settingsWithOld.length} store_settings containing "${OLD_CLOUD}"`)

  for (const s of settingsWithOld) {
    const updatedValue = s.value.replaceAll(OLD_CLOUD, NEW_CLOUD)
    await prisma.storeSetting.update({
      where: { id: s.id },
      data: { value: updatedValue },
    })
    console.log(`Updated storeSetting "${s.key}" to use "${NEW_CLOUD}"`)
  }

  // Check products
  const productsWithOld = await prisma.product.findMany({
    where: { imageUrl: { contains: OLD_CLOUD } },
  })
  console.log(`Found ${productsWithOld.length} products containing "${OLD_CLOUD}"`)
  for (const p of productsWithOld) {
    if (p.imageUrl) {
      await prisma.product.update({
        where: { id: p.id },
        data: { imageUrl: p.imageUrl.replaceAll(OLD_CLOUD, NEW_CLOUD) },
      })
    }
  }

  // Check categories
  const categoriesWithOld = await prisma.category.findMany({
    where: { imageUrl: { contains: OLD_CLOUD } },
  })
  console.log(`Found ${categoriesWithOld.length} categories containing "${OLD_CLOUD}"`)
  for (const c of categoriesWithOld) {
    if (c.imageUrl) {
      await prisma.category.update({
        where: { id: c.id },
        data: { imageUrl: c.imageUrl.replaceAll(OLD_CLOUD, NEW_CLOUD) },
      })
    }
  }

  // Check promo_banners
  const bannersWithOld = await prisma.promoBanner.findMany({
    where: { imageUrl: { contains: OLD_CLOUD } },
  })
  console.log(`Found ${bannersWithOld.length} promo_banners containing "${OLD_CLOUD}"`)
  for (const b of bannersWithOld) {
    if (b.imageUrl) {
      await prisma.promoBanner.update({
        where: { id: b.id },
        data: { imageUrl: b.imageUrl.replaceAll(OLD_CLOUD, NEW_CLOUD) },
      })
    }
  }

  console.log('\n=== MIGRATION COMPLETE ===')
  console.log(`All references to "${OLD_CLOUD}" have been migrated to current active cloud name "${NEW_CLOUD}".`)
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
