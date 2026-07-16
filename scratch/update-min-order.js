require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const setting = await prisma.storeSetting.upsert({
    where: { key: 'min_order_value' },
    update: { value: '0' },
    create: { key: 'min_order_value', value: '0' }
  });
  console.log('Upserted setting min_order_value to 0:', setting);
}

main()
  .then(async () => {
    await prisma.$disconnect();
    process.exit(0);
  })
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
