const { parse } = require('pg-connection-string');
require('dotenv').config();

console.log('Testing DATABASE_URL connection string parsing...');

try {
  const config = parse(url);
  console.log('Parsed config:', {
    ...config,
    password: config.password ? '[MASKED]' : config.password
  });
} catch (e) {
  console.error('Failed to parse:', e);
}
