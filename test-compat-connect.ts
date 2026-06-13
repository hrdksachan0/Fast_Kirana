import dotenv from 'dotenv'
dotenv.config()

import { Pool } from 'pg'

let connectionString = process.env.DATABASE_URL || ''
if (connectionString) {
  const separator = connectionString.includes('?') ? '&' : '?'
  connectionString = `${connectionString}${separator}uselibpqcompat=true`
}
console.log('Connecting with compat to:', connectionString)

const pool = new Pool({
  connectionString,
})

async function main() {
  try {
    const client = await pool.connect()
    console.log('Successfully connected with compat!')
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
