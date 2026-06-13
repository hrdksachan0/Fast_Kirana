const { parse } = require('pg-connection-string');
require('dotenv').config();

const url = process.env.DATABASE_URL;
console.log('Raw DATABASE_URL:', url);

try {
  const config = parse(url);
  console.log('Parsed config:', {
    ...config,
    password: config.password ? '[MASKED]' : config.password
  });
} catch (e) {
  console.error('Failed to parse:', e);
}
