import dotenv from 'dotenv'
dotenv.config()

import { Pool } from 'pg'

const connectionString = process.env.DATABASE_URL
console.log('Connecting to:', connectionString)

const pool = new Pool({
  connectionString,
})

async function main() {
  try {
    const client = await pool.connect()
    console.log('Successfully connected!')
    const res = await client.query('SELECT NOW()')
    console.log('Query result:', res.rows[0])
    client.release()
  } catch (err) {
    console.error('Connection error:', err)
  } finally {
    await pool.end()
  }
}

main()
