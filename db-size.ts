import { prisma } from './src/lib/prisma'

async function main() {
  console.log('Querying Postgres database size...')
  
  // Get database size in pretty format (e.g. "15 MB")
  const sizePrettyResult = await prisma.$queryRaw<Array<{ pg_size_pretty: string }>>`
    SELECT pg_size_pretty(pg_database_size(current_database())) as pg_size_pretty;
  `
  
  // Get database size in bytes
  const sizeBytesResult = await prisma.$queryRaw<Array<{ pg_database_size: number }>>`
    SELECT pg_database_size(current_database()) as pg_database_size;
  `

  const sizePretty = sizePrettyResult[0]?.pg_size_pretty || 'Unknown'
  const sizeBytes = Number(sizeBytesResult[0]?.pg_database_size || 0)
  
  console.log(`DATABASE_SIZE_PRETTY: ${sizePretty}`)
  console.log(`DATABASE_SIZE_BYTES: ${sizeBytes}`)
}

main()
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
