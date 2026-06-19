const fs = require('fs');
const path = require('path');

const filePath = 'C:/Users/Sooraj/.gemini/antigravity/brain/87945799-4132-4269-bc46-9686195abfd0/.system_generated/steps/720/content.md';
const content = fs.readFileSync(filePath, 'utf8');

const debugPresent = content.includes('fastkirana-db-debug') || content.includes('fastkirana-client-debug') || content.includes('FASTKIRANA CLIENT DEBUG');
console.log('Is debug instrumentation present on the live page?', debugPresent ? 'YES (needs fix)' : 'NO (clean!)');
