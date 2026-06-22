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
    
    // Fetch latest order details
    const res = await client.query('SELECT * FROM orders ORDER BY "createdAt" DESC LIMIT 1');
    if (res.rows.length === 0) {
      console.log('{"error": "No orders found"}');
      return;
    }
    
    const order = res.rows[0];
    
    // Fetch items
    const itemsRes = await client.query('SELECT * FROM "order_items" WHERE "orderId" = $1', [order.id]);
    order.items = itemsRes.rows;
    
    // Fetch address
    const addressRes = await client.query('SELECT * FROM addresses WHERE id = $1', [order.addressId]);
    order.address = addressRes.rows[0];

    // Fetch user
    const userRes = await client.query('SELECT name, email, phone FROM users WHERE id = $1', [order.userId]);
    order.user = userRes.rows[0];
    
    console.log(JSON.stringify(order, null, 2));
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}

main();
