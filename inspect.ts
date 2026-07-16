import { prisma } from './src/lib/prisma'

async function run() {
  const setting = await prisma.storeSetting.findUnique({
    where: { key: 'tax_rate' }
  })
  console.log('TAX RATE SETTING:', setting)
}

run()
