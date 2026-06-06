import 'dotenv/config'
import { prisma } from './src/lib/prisma'

async function main() {
  const p = await prisma.product.findFirst({
    where: {
      OR: [
        { name: { contains: 'Aashirvaad', mode: 'insensitive' } },
        { slug: { contains: 'aashirvaad', mode: 'insensitive' } }
      ]
    }
  })
  console.log('Aashirvaad Product State in DB:', p)
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
