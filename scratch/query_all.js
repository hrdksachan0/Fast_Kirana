const { Client } = require('pg');
require('dotenv').config();

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

const client = new Client({
  connectionString,
  ssl: {
    rejectUnauthorized: false
  }
});

async function main() {
  try {
    await client.connect();
    
    // Fetch count of orders by status
    const statusRes = await client.query('SELECT status, COUNT(*) FROM orders GROUP BY status');
    console.log('Status counts:');
    console.log(statusRes.rows);

    // Fetch last 10 orders
    const res = await client.query('SELECT id, status, total, "createdAt", "shopName" FROM orders ORDER BY "createdAt" DESC LIMIT 10');
    console.log('Latest 10 orders:');
    console.log(res.rows);
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}

main();
