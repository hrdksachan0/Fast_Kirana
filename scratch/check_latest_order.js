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
    
    // Add SELECT policy for order_items if missing
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies 
          WHERE tablename = 'order_items' AND policyname = 'Allow read order_items'
        ) THEN
          CREATE POLICY "Allow read order_items" ON public.order_items
            FOR SELECT TO anon, authenticated
            USING (true);
        END IF;
      END
      $$;
    `);
    console.log('Policy applied successfully.');
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}

main();
