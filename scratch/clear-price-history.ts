import { prisma } from '../src/lib/prisma'

async function main() {
  const result = await prisma.priceHistory.deleteMany()
  console.log(`Deleted ${result.count} price history logs.`)
}

main()
  .catch(e => {
    console.error(e)
    process.exit(1)
  })
