/**
 * FastKirana Kitchen Thermal Printer Bridge - ROBUST EDITION
 * 
 * Features:
 * 1. Persistent Database Queue: Offline orders are never lost. When internet reconnects, all pending orders auto-print immediately.
 * 2. Hybrid Delivery: 0-second Realtime broadcast + 6-second persistent polling catch-up worker.
 * 3. Windows Keep-Awake: Prevents Windows from going to sleep or suspending the process.
 * 4. Active Network Monitor: Detects internet cuts within seconds, emits kitchen audio alerts, and auto-reconnects.
 * 5. Multi-click & Duplicate Protection: Prevents duplicate prints using persistent local disk cache.
 * 6. Isolated Temp Files: Thread-safe printing without temp file collisions.
 */

const { createClient } = require('@supabase/supabase-js');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// ============================================================================
// 1. CONFIGURATION & STATE
// ============================================================================
const configPath = path.join(__dirname, 'config.json');
let config = {};

try {
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } else {
    console.error('[Error] config.json not found! Please create it based on the README instructions.');
    process.exit(1);
  }
} catch (err) {
  console.error('[Error] Failed reading config.json:', err.message);
  process.exit(1);
}

const {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  PRINTER_NAME = 'POS-80C',
  LINE_LENGTH = 38,
  RESTAURANT_ID = null,
  AUTO_PRINT_ON_CONFIRM = false,
  ENABLE_AUDIO_ALERTS = true,
  POLL_INTERVAL_SECONDS = 6,
} = config;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('[Error] SUPABASE_URL and SUPABASE_ANON_KEY must be set in config.json.');
  process.exit(1);
}

// Local cache of printed orders to avoid reprinting on restart
const logPath = path.join(__dirname, 'printed_orders.json');
let printedOrderIds = new Set();
const recentPrintTimestamps = new Map(); // orderKey -> timestamp
const activePrintLocks = new Set(); // in-flight concurrency lock to prevent duplicate printing
let printMutexPromise = Promise.resolve(); // sequential printer queue (one ticket at a time)

try {
  if (fs.existsSync(logPath)) {
    const raw = JSON.parse(fs.readFileSync(logPath, 'utf8'));
    if (Array.isArray(raw)) {
      printedOrderIds = new Set(raw);
    }
  }
} catch (err) {
  console.warn('[Warning] Could not load printed_orders.json, starting fresh.', err.message);
}

function savePrintedOrderLog() {
  try {
    const arr = [...printedOrderIds].slice(-2000);
    fs.writeFileSync(logPath, JSON.stringify(arr), 'utf8');
  } catch (err) {
    console.error('[Error] Failed to save printed_orders.json:', err.message);
  }
}

// ============================================================================
// 2. WINDOWS KEEP-AWAKE (PREVENTS LAPTOP SLEEP & PROCESS SUSPENSION)
// ============================================================================
function enableWindowsKeepAwake() {
  if (process.platform !== 'win32') return;

  // Uses PowerShell to invoke SetThreadExecutionState:
  // ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x00000001) | ES_AWAYMODE_REQUIRED (0x00000040)
  const psCmd = `powershell -NoProfile -NonInteractive -Command "$w=Add-Type -MemberDefinition '[DllImport(\\"kernel32.dll\\")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name 'SafePower' -Namespace 'FastKirana' -PassThru; [FastKirana.SafePower]::SetThreadExecutionState(0x80000041)"`;
  exec(psCmd, (err) => {
    if (!err) {
      // Successfully refreshed keep-awake
    }
  });
}

setInterval(enableWindowsKeepAwake, 3 * 60 * 1000);
enableWindowsKeepAwake();

// ============================================================================
// 3. AUDIO ALERTS (PC SPEAKER / SYSTEM CHIME)
// ============================================================================
function playSound(type) {
  if (!ENABLE_AUDIO_ALERTS || process.platform !== 'win32') return;

  let psBeepCmd = '';
  if (type === 'offline') {
    psBeepCmd = '[Console]::Beep(650, 400); Start-Sleep -Milliseconds 100; [Console]::Beep(650, 600)';
  } else if (type === 'online') {
    psBeepCmd = '[Console]::Beep(1200, 150); Start-Sleep -Milliseconds 80; [Console]::Beep(1600, 250)';
  } else if (type === 'kot') {
    psBeepCmd = '[Console]::Beep(1000, 120); Start-Sleep -Milliseconds 60; [Console]::Beep(1300, 120); Start-Sleep -Milliseconds 60; [Console]::Beep(1800, 250)';
  } else if (type === 'error') {
    psBeepCmd = '[Console]::Beep(450, 800)';
  }

  if (psBeepCmd) {
    exec(`powershell -NoProfile -NonInteractive -Command "${psBeepCmd}"`, () => {});
  }
}

// ============================================================================
// 4. SUPABASE CLIENT & NETWORK MONITOR
// ============================================================================
let supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false },
});

let isOnline = true;
let consecutiveFailures = 0;
let channel = null;

function checkInternetConnectivity() {
  return new Promise((resolve) => {
    try {
      const urlObj = new URL(SUPABASE_URL);
      const client = urlObj.protocol === 'https:' ? https : http;
      
      const req = client.request(
        {
          hostname: urlObj.hostname,
          port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
          path: '/rest/v1/',
          method: 'HEAD',
          headers: { apikey: SUPABASE_ANON_KEY },
          timeout: 3500,
        },
        (res) => {
          resolve(res.statusCode < 500);
        }
      );

      req.on('timeout', () => {
        req.destroy();
        resolve(false);
      });

      req.on('error', () => {
        resolve(false);
      });

      req.end();
    } catch (_) {
      resolve(false);
    }
  });
}

async function networkHealthWatchdog() {
  const healthy = await checkInternetConnectivity();

  if (healthy) {
    if (!isOnline) {
      isOnline = true;
      consecutiveFailures = 0;
      console.log('\n===============================================================');
      console.log('📶 [NETWORK RESTORED] Internet connection is BACK ONLINE!');
      console.log('🔄 Reconnecting Realtime channel and checking missed orders...');
      console.log('===============================================================\n');
      playSound('online');
      setupSubscription();
      drainPendingQueue();
    } else {
      consecutiveFailures = 0;
    }
  } else {
    consecutiveFailures++;
    if (isOnline && consecutiveFailures >= 2) {
      isOnline = false;
      console.log('\n===============================================================');
      console.log('⚠️ [NETWORK ALERT] Kitchen Internet is DISCONNECTED / DOWN!');
      console.log('Bridge will automatically reconnect when internet recovers.');
      console.log('===============================================================\n');
      playSound('offline');
    }
  }
}

setInterval(networkHealthWatchdog, 4000);

// ============================================================================
// 5. RECEIPT FORMATTING & POWERSHELL PRINTING
// ============================================================================
function wrapText(text, limit) {
  const words = (text || '').split(' ');
  let lines = [];
  let currentLine = '';

  words.forEach((word) => {
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

function printKOT(order, items, user) {
  return new Promise((resolve) => {
    try {
      const lineLength = LINE_LENGTH || 38;
      const thickDivider = '='.repeat(lineLength);
      const thinDivider = '-'.repeat(lineLength);

      const centerText = (text) => {
        if (text.length >= lineLength) return text;
        const pad = Math.floor((lineLength - text.length) / 2);
        return ' '.repeat(pad) + text;
      };

      let lines = [];
      lines.push(thickDivider);
      lines.push(centerText('FASTKIRANA KOT'));
      lines.push(thickDivider);

      const orderIdText = order.readableId ? `#${order.readableId}` : `#${order.id.slice(0, 8).toUpperCase()}`;
      const customerName = (user?.name || order.userName || order.customerName || '').trim();
      const tokenLine = customerName ? `TOKEN : ${orderIdText} | ${customerName}` : `TOKEN : ${orderIdText}`;
      lines.push(tokenLine);
      lines.push(`TYPE  : ${order.deliveryMethod || 'DELIVERY'}`);

      const printDateStr = new Date().toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      }).replace(',', '');
      lines.push(`Print : ${printDateStr}`);

      if (order.notes && order.notes.trim()) {
        const deliveryInstructions = [
          'ring bell', "don't ring", 'dont ring', 'leave at door', 'leave at gate',
          'call before', 'avoid calling', 'drop at door', 'keep at door', 'deliver to',
          'call when reach', 'call upon arrival', 'gate pe', 'bell bajana', 'doorbell',
        ];
        const lowerNote = order.notes.toLowerCase().trim();
        const isDeliveryNote = deliveryInstructions.some((d) => lowerNote.includes(d));
        if (!isDeliveryNote) {
          lines.push(`Note  : ${order.notes.trim()}`);
        }
      }

      lines.push(thinDivider);
      lines.push('QTY   ITEM');
      lines.push(thinDivider);

      (items || []).forEach((item) => {
        const qtyStr = `${item.quantity || 1}`.padEnd(2, ' ');
        const prefix = `${qtyStr} x  `;
        const availableWidth = lineLength - prefix.length;

        let itemName = item.name || 'Item';
        if (item.selectedVariant) {
          itemName += ` (${item.selectedVariant})`;
        }

        const wrappedName = wrapText(itemName, availableWidth);
        if (wrappedName.length > 0) {
          lines.push(`${prefix}${wrappedName[0]}`);
          for (let i = 1; i < wrappedName.length; i++) {
            lines.push(' '.repeat(prefix.length) + wrappedName[i]);
          }
        }

        if (item.notes) {
          lines.push('      * Note: ' + item.notes);
        }
      });

      lines.push(thinDivider);
      lines.push(centerText('*** FASTKIRANA KITCHEN ***'));
      lines.push(thickDivider);
      lines.push('\r\n\r\n\r\n');

      const receiptText = lines.join('\r\n');
      const uniqueSuffix = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;
      const tempFilePath = path.join(__dirname, `temp_kot_${uniqueSuffix}.txt`).replace(/\\/g, '/');
      const psScriptPath = path.join(__dirname, `print_temp_${uniqueSuffix}.ps1`).replace(/\\/g, '/');

      fs.writeFileSync(tempFilePath, receiptText, 'utf8');

      const calculatedHeight = Math.max(350, (lines.length * 18) + 160);

      const psScript = `
Add-Type -AssemblyName System.Drawing
$doc = New-Object System.Drawing.Printing.PrintDocument
$doc.PrinterSettings.PrinterName = "${PRINTER_NAME}"

$doc.DefaultPageSettings.Margins.Left = 0
$doc.DefaultPageSettings.Margins.Right = 0
$doc.DefaultPageSettings.Margins.Top = 0
$doc.DefaultPageSettings.Margins.Bottom = 0

$paperSize = New-Object System.Drawing.Printing.PaperSize("CustomKOT", 312, ${calculatedHeight})
$doc.DefaultPageSettings.PaperSize = $paperSize

$doc.add_PrintPage({
  param($sender, $e)
  $font = New-Object System.Drawing.Font("Consolas", 10)
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
  $text = Get-Content -Path "${tempFilePath}" -Raw -Encoding UTF8
  $e.Graphics.DrawString($text, $font, $brush, 0, 0)
})
$doc.Print()
`;
      fs.writeFileSync(psScriptPath, psScript, 'utf8');

      const cmd = `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${psScriptPath}"`;
      exec(cmd, (error) => {
        try { fs.unlinkSync(tempFilePath); } catch (_) {}
        try { fs.unlinkSync(psScriptPath); } catch (_) {}

        if (error) {
          console.error(`[Print Error] Failed to print KOT for Order ${orderIdText}:`, error.message);
          playSound('error');
          resolve(false);
        } else {
          console.log(`[Print Success] 🖨️ KOT printed successfully for Order ${orderIdText}`);
          playSound('kot');
          resolve(true);
        }
      });
    } catch (err) {
      console.error('[Error] Exception in printKOT:', err.message);
      resolve(false);
    }
  });
}

// ============================================================================
// 6. PROCESS PRINT REQUEST (DEDUPLICATION & ITEM EXTRACTION)
// ============================================================================
async function handlePrintRequest(orderId, isForceReprint = false, broadcastPayload = {}) {
  const cleanId = (orderId || '').toString().trim().toUpperCase();
  if (!cleanId || cleanId.endsWith('-G')) {
    return false;
  }

  // 1. Permanent Local Deduplication:
  // If this order has ALREADY been printed on this machine and is NOT an intentional manual reprint, skip!
  if (!isForceReprint && printedOrderIds.has(cleanId)) {
    console.log(`[Bridge] 🛡️ Ignored duplicate print: Order #${cleanId} was already printed locally.`);
    return true;
  }

  // 2. Active In-Flight Concurrency Lock:
  // If another thread (e.g. realtime broadcast + queue worker) is currently printing this order, skip!
  if (activePrintLocks.has(cleanId)) {
    console.log(`[Bridge] 🛡️ Ignored concurrent print: Order #${cleanId} is already in the printing pipeline.`);
    return true;
  }

  // 3. Multi-tap Cooldown Window (25 seconds)
  const now = Date.now();
  const lastPrintTime = recentPrintTimestamps.get(cleanId);
  if (!isForceReprint && lastPrintTime && (now - lastPrintTime) < 25000) {
    console.log(`[Bridge] 🛡️ Ignored duplicate multi-tap for #${cleanId} (${Math.round((25000 - (now - lastPrintTime)) / 1000)}s cooldown active)`);
    return true;
  }

  activePrintLocks.add(cleanId);
  recentPrintTimestamps.set(cleanId, now);

  try {
    // 4. Sequential Printer Mutex (Prints tickets one-by-one to prevent printer paper jam/overlap)
    return await (printMutexPromise = printMutexPromise.then(async () => {
      // Re-verify local printed cache inside mutex
      if (!isForceReprint && printedOrderIds.has(cleanId)) {
        return true;
      }

      console.log(`[Bridge] Processing KOT for Order ID: ${orderId}...`);

      let order = null;
      const { data: orderData } = await supabase
        .from('orders')
        .select('*')
        .eq('id', orderId)
        .maybeSingle();

      if (orderData) {
        order = orderData;
      } else {
        const cleanReadable = orderId.replace(/^#/, '');
        const { data: orderByReadable } = await supabase
          .from('orders')
          .select('*')
          .eq('readableId', cleanReadable)
          .maybeSingle();
        if (orderByReadable) order = orderByReadable;
      }

      if (order && order.readableId && order.readableId.toString().trim().toUpperCase().endsWith('-G')) {
        return false;
      }

      if (!order) {
        order = {
          id: orderId,
          readableId: broadcastPayload.readableId || orderId,
          deliveryMethod: broadcastPayload.deliveryMethod || 'DELIVERY',
          createdAt: broadcastPayload.printedAt || new Date().toISOString(),
          notes: broadcastPayload.notes,
          restaurantId: broadcastPayload.restaurantId,
          shopName: broadcastPayload.shopName,
        };
      }

      const readable = (order.readableId || '').toString().trim().toUpperCase();
      const baseReadable = readable.replace(/-[GR\d]+$/i, '');
      const idKey = (order.id || '').toString().trim().toUpperCase();

      // Check if readableId was already printed
      if (!isForceReprint && (
        (readable && printedOrderIds.has(readable)) ||
        (baseReadable && printedOrderIds.has(baseReadable)) ||
        (idKey && printedOrderIds.has(idKey))
      )) {
        console.log(`[Bridge] 🛡️ Ignored duplicate print: #${readable || idKey} was already printed.`);
        return true;
      }

      const lastPrintByReadable = readable ? recentPrintTimestamps.get(readable) : null;
      const lastPrintByBase = baseReadable ? recentPrintTimestamps.get(baseReadable) : null;
      const lastPrintById = idKey ? recentPrintTimestamps.get(idKey) : null;
      const effectiveLastPrint = Math.max(lastPrintByReadable || 0, lastPrintByBase || 0, lastPrintById || 0);

      if (!isForceReprint && effectiveLastPrint > 0 && (now - effectiveLastPrint) < 25000) {
        console.log(`[Bridge] 🛡️ Cooldown active for #${readable || idKey}, skipping duplicate ticket.`);
        return true;
      }

      recentPrintTimestamps.set(idKey, now);
      if (readable) recentPrintTimestamps.set(readable, now);
      if (baseReadable) recentPrintTimestamps.set(baseReadable, now);

      if (RESTAURANT_ID && order.restaurantId && order.restaurantId !== RESTAURANT_ID) {
        return false;
      }

      let items = [];
      const { data: itemsData } = await supabase
        .from('order_items')
        .select('*')
        .eq('orderId', order.id);

      if (itemsData && itemsData.length > 0) {
        items = itemsData;
      } else if (broadcastPayload.items && Array.isArray(broadcastPayload.items) && broadcastPayload.items.length > 0) {
        items = broadcastPayload.items;
      }

      let user = null;
      if (broadcastPayload.customerName) {
        user = { name: broadcastPayload.customerName };
      } else if (order.userName) {
        user = { name: order.userName };
      } else if (order.userId) {
        try {
          const { data: userData } = await supabase
            .from('users')
            .select('name')
            .eq('id', order.userId)
            .maybeSingle();
          if (userData) user = userData;
        } catch (_) {}
      }

      let targetItems = items || [];
      const idFiltered = targetItems.filter((it) => {
        return Boolean(it.restaurantId) || it.type === 'RESTAURANT' || it.isRestaurantItem === true || Boolean(it.product?.restaurantId);
      });

      if (idFiltered.length > 0) {
        targetItems = idFiltered;
      } else {
        const cookedFoodWhitelists = [
          'dosa', 'burger', 'pizza', 'sandwich', 'roll', 'frankie', 'chowmein', 'noodles',
          'fried rice', 'paneer', 'manchurian', 'shake', 'cold coffee', 'tea', 'chai', 'coffee',
          'pasta', 'thali', 'roti', 'naan', 'gravy', 'curry', 'biryani', 'pav bhaji', 'fries',
          'momos', 'samosa', 'maggi', 'soup',
        ];
        const pureGroceryKeywords = [
          'atta', 'raw rice', 'dal', 'mustard oil', 'refined oil', 'ghee', 'washing powder',
          'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner',
          'harpic', 'vim bar', 'rin', 'tide', 'surf', 'namkeen packet', 'chips packet',
        ];

        const filteredRestaurantItems = targetItems.filter((it) => {
          const name = (it.name || '').toLowerCase();
          if (cookedFoodWhitelists.some((cw) => name.includes(cw))) return true;
          return !pureGroceryKeywords.some((k) => name === k || name.startsWith(k + ' '));
        });

        if (filteredRestaurantItems.length > 0) {
          targetItems = filteredRestaurantItems;
        }
      }

      const printSuccess = await printKOT(order, targetItems, user);

      if (printSuccess) {
        printedOrderIds.add(cleanId);
        if (order.id) printedOrderIds.add(order.id.toString().trim().toUpperCase());
        if (order.readableId) printedOrderIds.add(order.readableId.toString().trim().toUpperCase());
        if (baseReadable) printedOrderIds.add(baseReadable);
        savePrintedOrderLog();
        return true;
      }

      return false;
    }));
  } catch (err) {
    console.error(`[Error] Failed handlePrintRequest for Order ${orderId}:`, err.message);
    return false;
  } finally {
    activePrintLocks.delete(cleanId);
  }
}

// ============================================================================
// 7. PERSISTENT OFFLINE QUEUE WORKER (GUARANTEED ZERO-LOSS DELIVERY)
// ============================================================================
let isDrainingQueue = false;

async function drainPendingQueue() {
  if (isDrainingQueue || !isOnline) return;
  isDrainingQueue = true;

  try {
    let query = supabase
      .from('kitchen_kot_queue')
      .select('*')
      .eq('status', 'PENDING')
      .order('created_at', { ascending: true })
      .limit(30);

    if (RESTAURANT_ID) {
      query = query.or(`restaurant_id.eq.${RESTAURANT_ID},restaurant_id.is.null`);
    }

    const { data: pendingJobs, error: queueErr } = await query;

    if (!queueErr && pendingJobs && pendingJobs.length > 0) {
      // 🛡️ Strict Batch Deduplication: Filter duplicate clicks for the SAME order in this batch!
      const uniqueJobs = [];
      const seenKeysInBatch = new Set();

      for (const job of pendingJobs) {
        const oKey = (job.order_id || '').toString().trim().toUpperCase();
        const rKey = (job.readable_id || '').toString().trim().toUpperCase();
        const baseRKey = rKey.replace(/-[GR\d]+$/i, '');

        const alreadyPrintedLocally = printedOrderIds.has(oKey) ||
          (rKey && printedOrderIds.has(rKey)) ||
          (baseRKey && printedOrderIds.has(baseRKey));

        const isDuplicateClick = seenKeysInBatch.has(oKey) ||
          (rKey && seenKeysInBatch.has(rKey)) ||
          (baseRKey && seenKeysInBatch.has(baseRKey));

        if (alreadyPrintedLocally || isDuplicateClick) {
          // Immediately mark duplicate/already-printed row as PRINTED in DB so it doesn't linger or re-trigger
          await supabase
            .from('kitchen_kot_queue')
            .update({ status: 'PRINTED', printed_at: new Date().toISOString() })
            .eq('id', job.id);
          continue;
        }

        seenKeysInBatch.add(oKey);
        if (rKey) seenKeysInBatch.add(rKey);
        if (baseRKey) seenKeysInBatch.add(baseRKey);
        uniqueJobs.push(job);
      }

      if (uniqueJobs.length > 0) {
        console.log(`[Queue Worker] 📥 Found ${uniqueJobs.length} unique pending KOT job(s) in queue...`);

        for (const job of uniqueJobs) {
          const orderId = job.order_id;
          const readableId = job.readable_id || orderId;

          console.log(`[Queue Worker] 🚀 Printing queued order #${readableId} (Enqueued at: ${job.created_at})...`);
          const success = await handlePrintRequest(orderId, false, job.payload || {});

          if (success) {
            // Mark ALL pending rows matching order_id or readable_id as PRINTED
            try {
              await supabase
                .from('kitchen_kot_queue')
                .update({ status: 'PRINTED', printed_at: new Date().toISOString() })
                .or(`order_id.eq.${orderId},readable_id.eq.${readableId}`);
            } catch (_) {
              await supabase
                .from('kitchen_kot_queue')
                .update({ status: 'PRINTED', printed_at: new Date().toISOString() })
                .eq('id', job.id);
            }

            console.log(`[Queue Worker] ✅ Queued order #${readableId} marked PRINTED in database.`);
            // Pause 1 second between tickets for clean cutting
            await new Promise((r) => setTimeout(r, 1000));
          } else {
            await supabase
              .from('kitchen_kot_queue')
              .update({ attempts: (job.attempts || 0) + 1, last_error: 'Printer retry' })
              .eq('id', job.id);
          }
        }
      }
    }

    if (AUTO_PRINT_ON_CONFIRM) {
      const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
      let ordQuery = supabase
        .from('orders')
        .select('id, readableId, status, restaurantId, createdAt')
        .eq('status', 'CONFIRMED')
        .gte('createdAt', twoHoursAgo)
        .order('createdAt', { ascending: true })
        .limit(20);

      if (RESTAURANT_ID) {
        ordQuery = ordQuery.eq('restaurantId', RESTAURANT_ID);
      }

      const { data: recentOrders } = await ordQuery;
      if (recentOrders && recentOrders.length > 0) {
        for (const o of recentOrders) {
          if (!printedOrderIds.has(o.id) && (!o.readableId || !printedOrderIds.has(o.readableId))) {
            console.log(`[Fallback Worker] Auto-printing confirmed order #${o.readableId || o.id}...`);
            await handlePrintRequest(o.id, false);
          }
        }
      }
    }
  } catch (err) {
    console.warn('[Queue Worker] Error while polling queue:', err.message);
  } finally {
    isDrainingQueue = false;
  }
}

const pollIntervalMs = Math.max(3000, (POLL_INTERVAL_SECONDS || 6) * 1000);
setInterval(drainPendingQueue, pollIntervalMs);

// ============================================================================
// 8. SUPABASE REALTIME SUBSCRIPTION (0-SECOND INSTANT PRINTING)
// ============================================================================
function setupSubscription() {
  if (channel) {
    try { supabase.removeChannel(channel); } catch (_) {}
    channel = null;
  }

  try {
    if (supabase && supabase.realtime) {
      supabase.realtime.disconnect();
    }
  } catch (_) {}

  supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
  });

  channel = supabase.channel('restaurant-orders-live');

  channel.on('broadcast', { event: 'reprint-kot' }, async (payload) => {
    const data = payload.payload || {};
    const { orderId } = data;
    if (orderId) {
      console.log(`[Realtime Broadcast] ⚡ Instant reprint received for Order: ${orderId}`);
      await handlePrintRequest(orderId, true, data);
    }
  });

  if (AUTO_PRINT_ON_CONFIRM) {
    channel.on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'orders' },
      (payload) => {
        const oldOrder = payload.old;
        const newOrder = payload.new;
        if (newOrder.status === 'CONFIRMED' && oldOrder.status !== 'CONFIRMED') {
          console.log(`[DB Event] Order status confirmed: ${newOrder.id}`);
          handlePrintRequest(newOrder.id, false);
        }
      }
    );
  }

  channel.subscribe((status, err) => {
    if (status === 'SUBSCRIBED') {
      console.log('===============================================================');
      console.log('🚀 FastKirana Kitchen Thermal Printer Bridge is RUNNING & READY!');
      console.log(`Target Printer  : ${PRINTER_NAME}`);
      console.log(`Queue Polling   : Every ${POLL_INTERVAL_SECONDS || 6}s (Offline Recovery Active)`);
      console.log(`Power Mode      : Windows Sleep Prevention ACTIVE 24/7`);
      console.log(`Mode            : ${AUTO_PRINT_ON_CONFIRM ? 'Auto-Print on Confirm' : 'Manual "Send KOT" Only'}`);
      console.log('Listening for orders... Keep this window open.');
      console.log('===============================================================');
      drainPendingQueue();
    } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
      const errMsg = err ? `: ${err.message}` : '';
      console.warn(`[Realtime] Subscription state: ${status}${errMsg}. Retrying in 5s...`);
      setTimeout(() => {
        if (isOnline) setupSubscription();
      }, 5000);
    }
  });
}

// ============================================================================
// 9. PROCESS CRASH PROTECTIONS
// ============================================================================
process.on('uncaughtException', (err) => {
  console.error('[Safety Guard] Uncaught error caught, keeping bridge alive:', err.message);
  setTimeout(() => {
    if (isOnline) setupSubscription();
  }, 5000);
});

process.on('unhandledRejection', (reason) => {
  console.warn('[Safety Guard] Unhandled promise rejection caught:', reason);
});

console.log('Starting FastKirana Kitchen Printer Bridge...');
setupSubscription();
drainPendingQueue();
