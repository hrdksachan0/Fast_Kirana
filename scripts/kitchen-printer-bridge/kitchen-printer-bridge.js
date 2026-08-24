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
let supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
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

/// 3. Printing Mechanism (PowerShell Silent Print)
function printKOT(order, items, user) {
  try {
    const lineLength = 40; // Re-adjusted for standard 3-inch (80mm) POS thermal printer rolls
    const thinDivider = '-'.repeat(lineLength);

    const centerText = (text) => {
      if (text.length >= lineLength) return text;
      const pad = Math.floor((lineLength - text.length) / 2);
      return ' '.repeat(pad) + text;
    };

    let lines = [];
    lines.push(centerText('FASTKIRANA ONLINE KOT'));
    lines.push(thinDivider);

    const orderIdText = order.readableId ? `#${order.readableId}` : `#${order.id.slice(0, 8).toUpperCase()}`;
    lines.push(`KOT ID: ${orderIdText}`);

    const dateStr = new Date(order.createdAt).toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata',
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

    lines.push(thinDivider);
    lines.push('\n\n\n'); // Tearing whitespace

    const receiptText = lines.join('\n');
    const tempFilePath = path.join(__dirname, 'temp_kot.txt').replace(/\\/g, '/');
    const psScriptPath = path.join(__dirname, 'print_temp.ps1').replace(/\\/g, '/');
    
    fs.writeFileSync(tempFilePath, receiptText, 'utf8');

    // Calculate dynamic paper height in hundredths of an inch (1 inch = 100 units)
    // 220 units base height for header/meta/footer + 40 units per item
    const calculatedHeight = Math.max(300, 220 + (items.length * 40));

    // Create a temporary PowerShell script using .NET PrintDocument to set minimal margins, custom PaperSize, and Consolas font
    const psScript = `
Add-Type -AssemblyName System.Drawing
$doc = New-Object System.Drawing.Printing.PrintDocument
$doc.PrinterSettings.PrinterName = "${PRINTER_NAME}"

# Set margins to 0 (since we already center align and format in text)
$doc.DefaultPageSettings.Margins.Left = 0
$doc.DefaultPageSettings.Margins.Right = 0
$doc.DefaultPageSettings.Margins.Top = 0
$doc.DefaultPageSettings.Margins.Bottom = 0

# Set dynamic paper size: Width = 312 (3.12 inches for 80mm), Height = ${calculatedHeight} (2.2 inches + 0.4 inches per item)
$paperSize = New-Object System.Drawing.Printing.PaperSize("CustomKOT", 312, ${calculatedHeight})
$doc.DefaultPageSettings.PaperSize = $paperSize

$doc.add_PrintPage({
  param($sender, $e)
  # Consolas size 10 is clean, readable, and stretches properly on 80mm rolls
  $font = New-Object System.Drawing.Font("Consolas", 10)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
  $text = Get-Content -Path "${tempFilePath}" -Raw
  $e.Graphics.DrawString($text, $font, $brush, 0, 0)
})
$doc.Print()
`;
    fs.writeFileSync(psScriptPath, psScript, 'utf8');

    // Execute the PowerShell script silently
    const cmd = `powershell -ExecutionPolicy Bypass -File "${psScriptPath}"`;
    
    exec(cmd, (error) => {
      if (error) {
        console.error(`[Error] Failed to print KOT for Order ${orderIdText}:`, error);
      } else {
        console.log(`[Success] KOT Printed successfully for Order ${orderIdText}`);
      }
      // Clean up temp files
      try { fs.unlinkSync(tempFilePath); } catch (_) {}
      try { fs.unlinkSync(psScriptPath); } catch (_) {}
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

    // Mark as printed (always write to local log to keep history in sync)
    printedOrderIds.add(orderId);
    savePrintedOrderLog();

    // Print
    printKOT(order, items, user);

  } catch (err) {
    console.error(`[Error] handlePrintRequest failed for Order ${orderId}:`, err.message);
  }
}

// 5. Connect to Supabase Realtime Channels with Robust Auto-Reconnect
let channel = null;

function setupSubscription() {
  // Clean up any old channel before reconnecting
  if (channel) {
    console.log('[Realtime] Cleaning up old channel subscription...');
    try {
      supabase.removeChannel(channel);
    } catch (_) {}
    channel = null;
  }

  // Force close old socket and re-create client to guarantee a fresh connection
  console.log('[Realtime] Re-initializing Supabase Client connection...');
  try {
    if (supabase && supabase.realtime) {
      supabase.realtime.disconnect();
    }
  } catch (_) {}

  supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false }
  });

  channel = supabase.channel('restaurant-orders-live');

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
  }

  channel.subscribe((status, err) => {
    if (status === 'SUBSCRIBED') {
      console.log('==================================================');
      console.log('🚀 FastKirana Kitchen Printer Bridge is RUNNING!');
      console.log(`Target Printer  : ${PRINTER_NAME}`);
      console.log(`Mode            : ${AUTO_PRINT_ON_CONFIRM ? 'Auto-Print on Confirm' : 'Manual "Send KOT" Only'}`);
      console.log('Listening for orders... Do not close this window.');
      console.log('==================================================');
    } else if (status === 'CLOSED') {
      console.log('[Realtime] Supabase connection closed. Reconnecting in 5 seconds...');
      setTimeout(() => {
        setupSubscription();
      }, 5000);
    } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
      const errMsg = err ? `: ${err.message}` : '';
      console.error(`[Realtime] Subscription failed (${status})${errMsg}. Reconnecting in 5 seconds...`);
      
      // Auto-retry in 5 seconds
      setTimeout(() => {
        setupSubscription();
      }, 5000);
    }
  });
}

// 6. Global Heartbeat Watchdog (checks every 30s if internet was disconnected and auto-reconnects)
setInterval(() => {
  if (!channel || channel.state !== 'joined') {
    console.log('[Heartbeat Watchdog] Connection dropped or pending. Auto-reconnecting to Supabase...');
    setupSubscription();
  }
}, 30000);

// 7. Process Crash Protections
process.on('uncaughtException', (err) => {
  console.error('[Safety] Uncaught error caught, keeping bridge alive:', err.message);
  setTimeout(() => {
    setupSubscription();
  }, 5000);
});

process.on('unhandledRejection', (reason) => {
  console.warn('[Safety] Unhandled promise rejection caught:', reason);
});

// Start first connection
setupSubscription();
