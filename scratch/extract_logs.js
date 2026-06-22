const fs = require('fs');
const path = require('path');

const transcriptPath = 'C:\\Users\\Sooraj\\.gemini\\antigravity\\brain\\713e5650-a1c0-4293-953e-6f4c6c97b840\\.system_generated\\logs\\transcript_full.jsonl';

const lines = fs.readFileSync(transcriptPath, 'utf8').split('\n');

for (let i = 0; i < lines.length; i++) {
  if (!lines[i]) continue;
  try {
    const obj = JSON.parse(lines[i]);
    if (obj.type === 'USER_INPUT' && obj.content && obj.content.includes('Copied') && obj.content.includes('logs')) {
      console.log(`Found step at index ${i}`);
      // Extract the logs inside content
      const content = obj.content;
      const logLines = content.split('\n');
      console.log('Total lines in user input content:', logLines.length);
      
      for (const line of logLines) {
        if (line.trim().startsWith('{') && line.trim().endsWith('}')) {
          try {
            const logObj = JSON.parse(line.trim());
            // Filter logs: look for error level or messages containing error/fail/whatsapp
            const msg = logObj.message || '';
            const isError = logObj.level === 'error' || logObj.level === 'warning';
            const isOrders = logObj.requestPath === '/api/orders';
            const mentionsInteresting = msg.toLowerCase().includes('whatsapp') || msg.toLowerCase().includes('order') || msg.toLowerCase().includes('meta') || msg.toLowerCase().includes('fail');
            
            if (isError || isOrders || mentionsInteresting) {
              console.log(`[${logObj.level}] [${logObj.requestPath}] ${msg || JSON.stringify(logObj)}`);
            }
          } catch (e) {
            // not json
          }
        }
      }
    }
  } catch (err) {
    // ignore
  }
}
