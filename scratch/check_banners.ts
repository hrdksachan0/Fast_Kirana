import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('--- Checking Promo Banners ---')
  const banners = await prisma.promoBanner.findMany()
  console.log(JSON.stringify(banners, null, 2))
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
