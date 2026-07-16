const dotenv = require('dotenv');
dotenv.config();

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

let connectionString = process.env.DATABASE_URL || '';
if (connectionString) {
  connectionString = connectionString.replace(/\r/g, '').trim();
  if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
    connectionString = connectionString.substring(1, connectionString.length - 1);
  }
  connectionString = connectionString.trim();
  if (!connectionString.includes('uselibpqcompat=')) {
    const separator = connectionString.includes('?') ? '&' : '?';
    connectionString = `${connectionString}${separator}uselibpqcompat=true`;
  }
}

const pool = new Pool({
  connectionString,
  max: 3,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  try {
    const products = await prisma.product.findMany({
      include: {
        category: true
      }
    });
    
    console.log('=== Dairy/Breakfast related products in DB ===');
    const keywords = ['milk', 'butter', 'paneer', 'cheese', 'egg', 'bread', 'ghee', 'curd', 'dahi', 'chaach', 'lassi'];
    const matched = products.filter(p => {
      const name = p.name.toLowerCase();
      const desc = (p.description || '').toLowerCase();
      return keywords.some(k => name.includes(k) || desc.includes(k));
    });
    
    console.log(matched.map(p => ({
      name: p.name,
      categoryName: p.category ? p.category.name : 'None',
      categorySlug: p.category ? p.category.slug : 'None'
    })));
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
