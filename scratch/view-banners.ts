import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const banners = await prisma.promoBanner.findMany()
  console.log('ACTIVE BANNERS IN DB:')
  console.log(JSON.stringify(banners, null, 2))
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
