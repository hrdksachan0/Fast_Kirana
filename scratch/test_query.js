require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

let connectionString = process.env.DATABASE_URL || '';
if (connectionString) {
  connectionString = connectionString.replace(/\r/g, '').trim();
  if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
    connectionString = connectionString.substring(1, connectionString.length - 1);
  }
}
const pool = new Pool({
  connectionString,
  max: 3,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5500
});
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  try {
    console.log('Querying product counts grouped by category...');
    const productCounts = await prisma.product.groupBy({
      by: ['categoryId'],
      where: { isAvailable: true },
      _count: {
        id: true,
      },
    });
    console.log('Product counts result:', JSON.stringify(productCounts, null, 2));

    const countsMap = {};
    productCounts.forEach((group) => {
      countsMap[group.categoryId] = group._count.id;
    });
    console.log('Mapped countsMap:', countsMap);
  } catch (err) {
    console.error('Query failed with error:', err);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

main();
