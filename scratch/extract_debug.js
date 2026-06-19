const fs = require('fs');
const path = require('path');

const filePath = 'C:/Users/Sooraj/.gemini/antigravity/brain/87945799-4132-4269-bc46-9686195abfd0/.system_generated/steps/648/content.md';
const content = fs.readFileSync(filePath, 'utf8');

if (content.includes('FASTKIRANA CLIENT DEBUG')) {
  console.log('FOUND VISIBLE DEBUG BANNER IN SERVER HTML!');
  // Extract lines around it
  const idx = content.indexOf('FASTKIRANA CLIENT DEBUG');
  console.log(content.substring(idx - 100, idx + 400));
} else {
  console.log('Visible debug banner not found in server HTML!');
}
