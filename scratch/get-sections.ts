import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const settings = await prisma.storeSetting.findMany()
  console.log('All Store Settings:')
  console.log(JSON.stringify(settings, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
