import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

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

async function verifyHealth() {
  console.log('🔍 Running Comprehensive Website Health Diagnosis...');
  let hasErrors = false;

  try {
    // 1. Check Database connection
    console.log('\n--- 1. Database Connection Status ---');
    const userCount = await prisma.user.count();
    console.log(`✅ Connection OK. Total users in database: ${userCount}`);

    // 2. Check Store settings
    console.log('\n--- 2. Store Setting Status ---');
    const settings = await prisma.storeSetting.findMany();
    const settingsMap = new Map(settings.map(s => [s.key, s.value]));

    const avgDeliveryTime = settingsMap.get('avg_delivery_time') || '8 min';
    const deliveredToday = settingsMap.get('delivered_today') || '1231+';
    const groceryOpen = settingsMap.get('grocery_mart_open') || 'true';
    const cafeOpen = settingsMap.get('cafe_open') || 'true';

    console.log(`- Avg Delivery Time: ${avgDeliveryTime}`);
    console.log(`- Delivered Today: ${deliveredToday}`);
    console.log(`- Grocery Mart Open: ${groceryOpen}`);
    console.log(`- Cafe Kitchen Open: ${cafeOpen}`);
    console.log('✅ Store settings loaded successfully.');

    // 3. Check Categories
    console.log('\n--- 3. Category Details ---');
    const categories = await prisma.category.findMany({
      orderBy: { sortOrder: 'asc' },
      include: {
        _count: {
          select: { products: true }
        }
      }
    });

    console.log(`Total categories: ${categories.length}`);
    categories.forEach(cat => {
      console.log(`- ${cat.name} (${cat.slug}): ${cat._count.products} products, sortOrder: ${cat.sortOrder}`);
    });
    console.log('✅ Categories check completed.');

    // 4. Verify Promos/Banners
    console.log('\n--- 4. Active Promo Banners ---');
    const banners = await prisma.promoBanner.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' }
    });
    console.log(`Total active promo banners: ${banners.length}`);
    banners.forEach(banner => {
      console.log(`- Banner ID: ${banner.id}, Title: ${banner.title || 'N/A'}, Image: ${banner.imageUrl}`);
    });
    console.log('✅ Promo banners check completed.');

    // 5. Sample Products check
    console.log('\n--- 5. Sample Products ---');
    const sampleProducts = await prisma.product.findMany({
      take: 5,
      select: {
        id: true,
        name: true,
        slug: true,
        price: true,
        category: {
          select: { name: true }
        }
      }
    });
    console.log(`Sample Products retrieved: ${sampleProducts.length}`);
    sampleProducts.forEach(prod => {
      console.log(`- Name: ${prod.name}, Slug: ${prod.slug}, Price: Rs. ${prod.price}, Category: ${prod.category?.name || 'None'}`);
    });
    console.log('✅ Sample products check completed.');

  } catch (error) {
    hasErrors = true;
    console.error('❌ Error during health check:', error);
  } finally {
    await prisma.$disconnect();
    await pool.end();
    console.log('\n--- Diagnosis Finished ---');
    if (hasErrors) {
      console.log('❌ Health check failed with errors.');
      process.exit(1);
    } else {
      console.log('✅ All website database queries are fully healthy.');
      process.exit(0);
    }
  }
}

verifyHealth();
