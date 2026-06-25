import dns from 'dns'
import fs from 'fs'
import path from 'path'

// Force Node to resolve IPv4 addresses first to prevent P1001 connection errors on IPv4-only networks (like Render build containers)
if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first')
}

// Load .env file manually if process.env.DATABASE_URL is not set
if (!process.env.DATABASE_URL) {
  try {
    const envPath = path.resolve(process.cwd(), '.env')
    if (fs.existsSync(envPath)) {
      const envContent = fs.readFileSync(envPath, 'utf-8')
      for (let line of envContent.split('\n')) {
        line = line.replace(/\r/g, '').trim()
        if (!line || line.startsWith('#')) continue
        const match = line.match(/^([\w.-]+)\s*=\s*(.*)?$/)
        if (match) {
          const key = match[1]
          const value = (match[2] || '').trim()
          process.env[key] = value
        }
      }
    }
  } catch (err) {
    // Ignore errors loading .env
  }
}

// Unconditionally clean the connection string to handle quotes and whitespace from both .env and OS environments
let databaseUrl = process.env.DATABASE_URL || ''
if (databaseUrl) {
  databaseUrl = databaseUrl.replace(/\r/g, '').trim()
  if (databaseUrl.startsWith('"') && databaseUrl.endsWith('"')) {
    databaseUrl = databaseUrl.substring(1, databaseUrl.length - 1)
  } else if (databaseUrl.startsWith("'") && databaseUrl.endsWith("'")) {
    databaseUrl = databaseUrl.substring(1, databaseUrl.length - 1)
  }
  databaseUrl = databaseUrl.trim()
  
  // Automatically append connect_timeout=30 to handle Neon compute wake-up cold starts
  if (databaseUrl && !databaseUrl.includes('connect_timeout=')) {
    const separator = databaseUrl.includes('?') ? '&' : '?'
    databaseUrl = `${databaseUrl}${separator}connect_timeout=30`
  }
  
  // Suppress SSL warning by appending uselibpqcompat=true
  if (databaseUrl && !databaseUrl.includes('uselibpqcompat=')) {
    const separator = databaseUrl.includes('?') ? '&' : '?'
    databaseUrl = `${databaseUrl}${separator}uselibpqcompat=true`
  }
  
  process.env.DATABASE_URL = databaseUrl
}

// Unconditionally clean the direct connection string for Migrations
let directUrl = process.env.DIRECT_URL || ''
if (directUrl) {
  directUrl = directUrl.replace(/\r/g, '').trim()
  if (directUrl.startsWith('"') && directUrl.endsWith('"')) {
    directUrl = directUrl.substring(1, directUrl.length - 1)
  } else if (directUrl.startsWith("'") && directUrl.endsWith("'")) {
    directUrl = directUrl.substring(1, directUrl.length - 1)
  }
  directUrl = directUrl.trim()
  
  if (directUrl && !directUrl.includes('connect_timeout=')) {
    const separator = directUrl.includes('?') ? '&' : '?'
    directUrl = `${directUrl}${separator}connect_timeout=30`
  }
  
  if (directUrl && !directUrl.includes('uselibpqcompat=')) {
    const separator = directUrl.includes('?') ? '&' : '?'
    directUrl = `${directUrl}${separator}uselibpqcompat=true`
  }
  
  process.env.DIRECT_URL = directUrl
}

// Determine if running under Prisma CLI (migrations, pushes, generate, etc.)
const isPrismaCli = process.argv.some(arg => 
  ['migrate', 'db', 'push', 'deploy', 'studio', 'generate'].includes(arg.toLowerCase())
)

// Use direct url for Prisma CLI operations to bypass pooler
const activeUrl = (isPrismaCli && directUrl) ? directUrl : databaseUrl

export default {
  schema: 'prisma/schema.prisma',
  migrations: {
    seed: 'npx tsx prisma/seed.ts',
  },
  datasource: {
    url: activeUrl || 'postgresql://postgres:postgres@localhost:5432/postgres',
  },
}
