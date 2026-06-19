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
    console.log('Querying categories and product counts from DB...');
    const categories = await prisma.category.findMany({
      include: {
        _count: {
          select: { products: true }
        }
      }
    });
    console.log('Categories list in DB:');
    categories.forEach(cat => {
      console.log(`- ID: ${cat.id}, Name: "${cat.name}", Slug: "${cat.slug}", Products Count: ${cat._count.products}`);
    });

    console.log('\nQuerying products in beverages category...');
    const beveragesProducts = await prisma.product.findMany({
      where: {
        category: {
          slug: 'beverages'
        }
      }
    });
    console.log(`Found ${beveragesProducts.length} products with category slug 'beverages':`);
    beveragesProducts.forEach(p => {
      console.log(`- ID: ${p.id}, Name: "${p.name}", Available: ${p.isAvailable}, Stock: ${p.stock}`);
    });
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

main();
