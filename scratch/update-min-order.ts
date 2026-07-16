import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const setting = await prisma.storeSetting.upsert({
    where: { key: 'min_order_value' },
    update: { value: '0' },
    create: { key: 'min_order_value', value: '0' }
  })
  console.log('Upserted setting min_order_value to 0:', setting)
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
