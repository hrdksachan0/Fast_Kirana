/**
 * FastKirana Kitchen Printer Bridge
 * Runs silently in the background on the kitchen PC.
 * Connects directly to Supabase to print KOTs silently.
 */

const { createClient } = require('@supabase/supabase-js');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// 1. Load Configurations
const configPath = path.join(__dirname, 'config.json');
let config = {};

try {
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } else {
    console.error('config.json not found! Please create it based on the README instructions.');
    process.exit(1);
  }
} catch (err) {
  console.error('Error reading config.json:', err);
  process.exit(1);
}

const {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  PRINTER_NAME = 'XP-80',
  RESTAURANT_ID = null,
  AUTO_PRINT_ON_CONFIRM = false
} = config;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('SUPABASE_URL and SUPABASE_ANON_KEY must be configured in config.json.');
  process.exit(1);
}

// 2. Initialize Supabase Client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false }
});

// Load already printed orders to prevent double printing on restart
const logPath = path.join(__dirname, 'printed_orders.json');
let printedOrderIds = new Set();
try {
  if (fs.existsSync(logPath)) {
    const arr = JSON.parse(fs.readFileSync(logPath, 'utf8'));
    printedOrderIds = new Set(arr);
  }
} catch (err) {
  console.warn('Could not load printed_orders.json, starting fresh.', err);
}

function savePrintedOrderLog() {
  try {
    fs.writeFileSync(logPath, JSON.stringify([...printedOrderIds]), 'utf8');
  } catch (err) {
    console.error('Failed to save printed_orders.json:', err);
  }
}

// Word-wrapper helper to keep lines clean
function wrapText(text, limit) {
  const words = text.split(' ');
  let lines = [];
  let currentLine = '';
  
  words.forEach(word => {
    if ((currentLine + (currentLine ? ' ' : '') + word).length <= limit) {
      currentLine += (currentLine ? ' ' : '') + word;
    } else {
      if (currentLine) lines.push(currentLine);
      currentLine = word;
    }
  });
  if (currentLine) {
    lines.push(currentLine);
  }
  return lines;
}

// 3. Printing Mechanism (PowerShell Silent Print)
function printKOT(order, items, user) {
  try {
    const lineLength = 32; // Optimized for 58mm (2-inch) thermal printers
    const divider = '='.repeat(lineLength);
    const thinDivider = '-'.repeat(lineLength);

    const centerText = (text) => {
      if (text.length >= lineLength) return text;
      const pad = Math.floor((lineLength - text.length) / 2);
      return ' '.repeat(pad) + text;
    };

    let lines = [];
    lines.push(divider);
    lines.push(centerText('FASTKIRANA ONLINE'));
    lines.push(centerText('KITCHEN ORDER TICKET'));
    lines.push(divider);

    const orderIdText = order.readableId ? `#${order.readableId}` : `#${order.id.slice(0, 8).toUpperCase()}`;
    lines.push(`KOT ID: ${orderIdText}`);

    const dateStr = new Date(order.createdAt).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    });
    lines.push(`Date  : ${dateStr}`);
    lines.push(`Type  : ${order.deliveryMethod || 'DELIVERY'}`);
    lines.push(`Cust  : ${user?.name || 'Customer'}`);
    lines.push(thinDivider);
    lines.push(`Qty  Item`);
    lines.push(thinDivider);

    items.forEach((item) => {
      const prefix = `[${item.quantity}x] `;
      const availableWidth = lineLength - prefix.length;
      
      const wrappedName = wrapText(item.name, availableWidth);
      if (wrappedName.length > 0) {
        lines.push(`${prefix}${wrappedName[0]}`);
        for (let i = 1; i < wrappedName.length; i++) {
          lines.push(' '.repeat(prefix.length) + wrappedName[i]);
        }
      }
      
      if (item.selectedVariant) {
        lines.push(' '.repeat(prefix.length) + `Var: ${item.selectedVariant}`);
      }
      if (item.notes) {
        lines.push(' '.repeat(prefix.length) + `Note: ${item.notes}`);
      }
    });

    lines.push(divider);
    lines.push(centerText('*** KITCHEN COPY ***'));
    lines.push('\n\n\n'); // Reduced tearing whitespace

    const receiptText = lines.join('\n');
    const tempFilePath = path.join(__dirname, 'temp_kot.txt');
    fs.writeFileSync(tempFilePath, receiptText, 'utf8');

    // Run Windows PowerShell silently to send KOT to the default printer
    const cmd = `powershell -Command "Get-Content -Path '${tempFilePath}' -Raw | Out-Printer -Name '${PRINTER_NAME}'"`;
    
    exec(cmd, (error) => {
      if (error) {
        console.error(`[Error] Failed to print KOT for Order ${orderIdText}:`, error);
      } else {
        console.log(`[Success] KOT Printed successfully for Order ${orderIdText}`);
      }
      try { fs.unlinkSync(tempFilePath); } catch (_) {}
    });

  } catch (err) {
    console.error('Error formatting or printing KOT:', err);
  }
}

// 4. Fetch Details & Execute
async function handlePrintRequest(orderId, isForceReprint = false) {
  try {
    if (!isForceReprint && printedOrderIds.has(orderId)) {
      // Avoid duplicate prints
      return;
    }

    console.log(`[Database] Fetching details for Order ID: ${orderId}...`);
    
    // Fetch Order details
    const { data: order, error: orderErr } = await supabase
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .single();

    if (orderErr || !order) {
      throw new Error(`Order not found or fetch error: ${orderErr?.message}`);
    }

    // Filter by Restaurant ID if configured
    if (RESTAURANT_ID && order.restaurantId !== RESTAURANT_ID) {
      return;
    }

    // Fetch Order Items
    const { data: items, error: itemsErr } = await supabase
      .from('order_items')
      .select('*')
      .eq('orderId', orderId);

    if (itemsErr) {
      throw new Error(`Failed to fetch items: ${itemsErr.message}`);
    }

    // Fetch Customer details
    let user = null;
    if (order.userId) {
      const { data: userData } = await supabase
        .from('users')
        .select('name')
        .eq('id', order.userId)
        .single();
      user = userData;
    }

    // Mark as printed
    if (!isForceReprint) {
      printedOrderIds.add(orderId);
      savePrintedOrderLog();
    }

    // Print
    printKOT(order, items, user);

  } catch (err) {
    console.error(`[Error] handlePrintRequest failed for Order ${orderId}:`, err.message);
  }
}

// 5. Connect to Supabase Realtime Channels
console.log('Connecting to Supabase Realtime...');
const channel = supabase.channel('restaurant-orders-live');

// Subscribe to direct "reprint-kot" broadcast signals (from Admin Mobile Click)
channel.on('broadcast', { event: 'reprint-kot' }, (payload) => {
  const { orderId } = payload.payload || {};
  if (orderId) {
    console.log(`[Broadcast] Received Reprint request for Order: ${orderId}`);
    handlePrintRequest(orderId, true); // True forces print bypassing duplicate filters
  }
});

// Subscribe to DB changes (optional auto-print on status change)
if (AUTO_PRINT_ON_CONFIRM) {
  console.log('[Auto-Print] Listening for status transitions to CONFIRMED in database...');
  channel.on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'orders'
    },
    (payload) => {
      const oldOrder = payload.old;
      const newOrder = payload.new;
      
      // Print when status transitions to CONFIRMED
      if (newOrder.status === 'CONFIRMED' && oldOrder.status !== 'CONFIRMED') {
        console.log(`[DB Event] Order status confirmed: ${newOrder.id}`);
        handlePrintRequest(newOrder.id, false);
      }
    }
  );
} else {
  console.log('[Manual KOT Mode] Auto-print on confirm is DISABLED. Listening to "Send KOT" button clicks only.');
}

channel.subscribe((status) => {
  if (status === 'SUBSCRIBED') {
    console.log('==================================================');
    console.log('🚀 FastKirana Kitchen Printer Bridge is RUNNING!');
    console.log(`Target Printer  : ${PRINTER_NAME}`);
    console.log(`Mode            : ${AUTO_PRINT_ON_CONFIRM ? 'Auto-Print on Confirm' : 'Manual "Send KOT" Only'}`);
    console.log('Listening for orders... Do not close this window.');
    console.log('==================================================');
  } else if (status === 'CLOSED') {
    console.log('[Realtime] Supabase connection closed.');
  } else if (status === 'CHANNEL_ERROR') {
    console.error('[Realtime] Channel error occurred. Retrying connection...');
  }
});
