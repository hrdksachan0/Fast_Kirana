import { prisma } from '../src/lib/prisma'

async function main() {
  console.log('Setting up order readableId sequence in DB...')
  
  // Find highest readableId to set the start value
  const maxOrder = await prisma.order.findFirst({
    orderBy: { readableId: 'desc' },
    select: { readableId: true }
  })
  
  const startVal = (maxOrder?.readableId || 600000) + 1
  console.log(`Highest readableId found: ${maxOrder?.readableId || 'none'}. Sequence starting at: ${startVal}`)
  
  // Create sequence
  await prisma.$executeRawUnsafe(`CREATE SEQUENCE IF NOT EXISTS order_readable_id_seq START WITH ${startVal};`)
  console.log('Sequence order_readable_id_seq created successfully!')
  
  // Verify next value (will increment sequence by 1 once)
  const res = await prisma.$queryRawUnsafe<{ nextval: any }[]>("SELECT nextval('order_readable_id_seq') as nextval;")
  console.log('Next value from sequence verified:', Number(res[0].nextval))
}

main()
  .catch(err => {
    console.error('Error during sequence initialization:', err)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
