import fs from 'fs'
import path from 'path'

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
          let value = (match[2] || '').trim()
          // Remove wrapping quotes
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1)
          } else if (value.startsWith("'") && value.endsWith("'")) {
            value = value.substring(1, value.length - 1)
          }
          process.env[key] = value.trim()
        }
      }
    }
  } catch (err) {
    // Ignore errors loading .env
  }
}

export default {
  schema: 'prisma/schema.prisma',
  migrations: {
    seed: 'npx tsx prisma/seed.ts',
  },
  datasource: {
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/postgres',
  },
}
