/**
 * High-Performance KOT & Receipt Printing Engine for FastKirana
 * Handles zero-lag, popup-free silent printing via hidden DOM iframe queue.
 */

interface PrintQueueItem {
  id: string
  html: string
  title: string
  timestamp: number
}

let printQueue: PrintQueueItem[] = []
let isPrinting = false

function getPrintingIframe(): HTMLIFrameElement {
  let iframe = document.getElementById('fastkirana-silent-printer') as HTMLIFrameElement | null
  if (!iframe) {
    iframe = document.createElement('iframe')
    iframe.id = 'fastkirana-silent-printer'
    iframe.style.position = 'fixed'
    iframe.style.right = '-9999px'
    iframe.style.bottom = '-9999px'
    iframe.style.width = '80mm'
    iframe.style.height = '3500px'
    iframe.style.minHeight = '3500px'
    iframe.style.opacity = '0.01'
    iframe.style.pointerEvents = 'none'
    iframe.style.border = '0'
    iframe.style.zIndex = '-9999'
    document.body.appendChild(iframe)
  }
  return iframe
}

async function processPrintQueue() {
  const now = Date.now()
  // 🛡️ Auto-flush stale print jobs older than 15 seconds to prevent old orders from printing!
  printQueue = printQueue.filter(item => (now - item.timestamp) < 15000)

  if (printQueue.length === 0) return
  if (isPrinting) {
    // Safety auto-unlock if stuck for over 3 seconds
    setTimeout(() => {
      isPrinting = false
      if (printQueue.length > 0) processPrintQueue()
    }, 3000)
    return
  }
  isPrinting = true

  const item = printQueue.shift()!

  try {
    const isMobile = typeof navigator !== 'undefined' && /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)

    if (isMobile) {
      // Mobile browsers block iframe printing; open printable window
      const printWindow = window.open('', '_blank')
      if (printWindow) {
        printWindow.document.open()
        printWindow.document.write(item.html)
        printWindow.document.close()
        printWindow.focus()
        setTimeout(() => {
          try {
            printWindow.print()
          } catch (e) {
            console.error('Mobile print error:', e)
          }
        }, 400)
      }
    } else {
      const iframe = getPrintingIframe()
      const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document

      if (iframeDoc && iframe.contentWindow) {
        iframeDoc.open()
        iframeDoc.write(item.html)
        iframeDoc.close()

        // 🛡️ Allow full DOM calculation and font metrics layout before triggering print dialog
        await new Promise((resolve) => setTimeout(resolve, 250))

        try {
          iframe.contentWindow.focus()
          iframe.contentWindow.print()
        } catch (printErr) {
          console.warn('Iframe print blocked, falling back to window.open:', printErr)
          const printWindow = window.open('', '_blank', 'width=450,height=800')
          if (printWindow) {
            printWindow.document.write(item.html)
            printWindow.document.close()
            printWindow.focus()
            setTimeout(() => {
              try { printWindow.print() } catch (_) {}
            }, 250)
          }
        }
      } else {
        const printWindow = window.open('', '_blank', 'width=450,height=800')
        if (printWindow) {
          printWindow.document.write(item.html)
          printWindow.document.close()
          printWindow.focus()
          setTimeout(() => {
            try { printWindow.print() } catch (_) {}
          }, 250)
        }
      }
    }
  } catch (err) {
    console.error('Silent print failed:', err)
  } finally {
    setTimeout(() => {
      isPrinting = false
      if (printQueue.length > 0) {
        processPrintQueue()
      }
    }, 150)
  }
}

/**
 * Parse any date representation (UTC string, ISO string, Date object, timestamp) reliably
 */
export function parseOrderDate(dateValue?: string | Date | number | null): Date {
  if (!dateValue) return new Date()
  if (dateValue instanceof Date) {
    return isNaN(dateValue.getTime()) ? new Date() : dateValue
  }
  if (typeof dateValue === 'number') {
    const d = new Date(dateValue)
    return isNaN(d.getTime()) ? new Date() : d
  }

  const s = String(dateValue).trim()
  if (!s) return new Date()

  if (/^\d{4}-\d{2}-\d{2}/.test(s)) {
    if (s.endsWith('Z') || /[+-]\d{2}(:\d{2})?$/.test(s)) {
      const d = new Date(s)
      return isNaN(d.getTime()) ? new Date() : d
    }
    // PostgreSQL UTC timestamp without trailing Z
    const utcIso = s.replace(' ', 'T') + 'Z'
    const d = new Date(utcIso)
    if (!isNaN(d.getTime())) return d
  }

  const fallback = new Date(s)
  return isNaN(fallback.getTime()) ? new Date() : fallback
}

/**
 * Format date strictly in Indian Standard Time (IST - Asia/Kolkata)
 * Example output: "01 Sep 2026, 9:28 pm"
 */
export function formatKOTDate(dateValue?: string | Date | number | null): string {
  const d = parseOrderDate(dateValue)

  return new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata',
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  }).format(d)
}

export function getElapsedText(createdAt?: string | Date | number | null): string {
  if (!createdAt) return 'Just now'
  const d = parseOrderDate(createdAt)

  const diffMs = Date.now() - d.getTime()
  const mins = Math.max(0, Math.floor(diffMs / 60000))
  if (mins < 1) return 'Just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  return `${hrs}h ${mins % 60}m ago`
}

/**
 * Generate thermal HTML layout for Kitchen Order Ticket (KOT)
 */
export function generateKOTHtml(order: any, shopType: string = 'RESTAURANT'): string {
  const orderDateStr = formatKOTDate(order.createdAt)
  const printDateStr = formatKOTDate(new Date())
  const elapsedText = getElapsedText(order.createdAt)

  const restSub = order.subOrders?.find((s: any) => s.type === 'RESTAURANT' || s.restaurantId)
  
  const isExplicitRestaurantOrder = 
    order.orderType === 'RESTAURANT' || 
    Boolean(order.restaurantId) || 
    Boolean(order.readableId && String(order.readableId).toUpperCase().endsWith('-R')) ||
    (shopType && shopType !== 'GROCERY' && shopType !== 'FastKirana Grocery' && shopType !== 'FastKirana Dark Store')

  // Extract strictly restaurant dishes (never drop dishes from restaurant orders)
  let targetItems: any[] = []

  if (isExplicitRestaurantOrder && Array.isArray(order.items) && order.items.length > 0) {
    // 1. Dedicated restaurant order — EVERY item in it belongs to the kitchen!
    targetItems = order.items
  } else if (Array.isArray(restSub?.items) && restSub.items.length > 0) {
    // 2. Items from the restaurant sub-order
    targetItems = restSub.items
  } else if (Array.isArray(order.restaurantItems) && order.restaurantItems.length > 0) {
    // 3. Explicit restaurant items array
    targetItems = order.restaurantItems
  } else if (Array.isArray(order.items) && order.items.length > 0) {
    // 4. Combined / un-split order: omit pure packaged grocery items, keep all food dishes
    const pureGroceryCategories = ['personal-care', 'home-cleaning', 'household', 'grocery', 'staples', 'packaged-food']
    const pureGroceryKeywords = [
      'atta', 'raw rice', 'dal packet', 'mustard oil', 'refined oil', 'washing powder',
      'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner',
      'harpic', 'rin', 'tide', 'surf'
    ]

    targetItems = order.items.filter((it: any) => {
      if (!it) return false
      const name = (it.name || '').toLowerCase()
      const slug = (it.categorySlug || it.category?.slug || '').toLowerCase()
      if (pureGroceryCategories.some((c: string) => slug.includes(c))) return false
      if (pureGroceryKeywords.some((k: string) => name === k || name.startsWith(k + ' '))) return false
      return true
    })
  }

  const outletName = restSub?.shopName || order.restaurantName || (order.restaurantId ? order.shopName : null) || shopType
  const orderIdText = restSub?.readableId 
    ? `#${restSub.readableId}` 
    : (order.readableId && order.isCombined && !String(order.readableId).toUpperCase().endsWith('-R'))
    ? `#${order.readableId}-R`
    : order.readableId 
    ? (String(order.readableId).startsWith('#') ? order.readableId : `#${order.readableId}`)
    : `#${(order.id || '').slice(0, 8).toUpperCase()}`

  const customerName = order.userName || order.user?.name || 'Customer'
  const deliveryMethod = (order.deliveryMethod || 'DELIVERY').toUpperCase()
  const deliveryIcon = (deliveryMethod === 'SELF_PICKUP' || deliveryMethod === 'PICKUP') ? '🛍️ PICKUP' : '🛵 DELIVERY'
  const cleanNote = order.notes
    ? String(order.notes).replace(/✨\s*/g, '').replace(/^Note:\s*/i, '').trim()
    : ''

  const totalQty = targetItems.reduce((acc: number, it: any) => acc + (Number(it.quantity) || 1), 0)

  const itemsHtml = targetItems.map((item: any, idx: number) => `
    <tr style="border-bottom: 1px dashed #ccc;">
      <td style="padding: 7px 2px 7px 0; font-weight: 900; font-size: 16px; vertical-align: top; width: 40px; text-align: center; letter-spacing: 0.5px;">${item.quantity}x</td>
      <td style="padding: 7px 0; font-size: 13px;">
        <div style="font-weight: 800; font-size: 14px; line-height: 1.3;">
          ${item.name}
        </div>
        ${item.selectedVariant ? `<div style="font-size: 11px; color: #555; margin-top: 1px;">▸ ${item.selectedVariant}</div>` : ''}
        ${item.notes ? `<div style="font-size: 11px; color: #333; font-style: italic; margin-top: 2px;">📝 ${item.notes}</div>` : ''}
      </td>
    </tr>
  `).join('')

  return `
    <!DOCTYPE html>
    <html>
      <head>
        <title>KOT - ${orderIdText}</title>
        <style>
          @page {
            size: 78mm auto;
            margin: 0mm;
          }
          html, body {
            font-family: 'Courier New', Courier, monospace;
            width: 78mm !important;
            max-width: 78mm !important;
            margin: 0 auto !important;
            padding: 4px 6px !important;
            color: #000;
            background: #fff;
            height: auto !important;
            min-height: 100% !important;
            overflow: visible !important;
            box-sizing: border-box !important;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }
          @media print {
            html, body {
              width: 78mm !important;
              max-width: 78mm !important;
              height: auto !important;
              overflow: visible !important;
              margin: 0 !important;
              padding: 4px 6px !important;
            }
            tr, .footer, .summary-bar {
              page-break-inside: avoid !important;
              break-inside: avoid !important;
            }
          }
        </style>
      </head>
      <body>
        <!-- ═══ HEADER ═══ -->
        <div style="text-align: center; font-size: 20px; font-weight: 900; letter-spacing: 2px; margin: 4px 0 0;">FASTKIRANA</div>
        <div style="text-align: center; font-size: 11px; font-weight: 700; margin: 2px 0 6px; border-bottom: 2px dashed #000; padding-bottom: 6px;">KITCHEN ORDER TICKET</div>

        <!-- ═══ ORDER INFO ═══ -->
        <table style="width: 100%; font-size: 12px; margin-bottom: 6px; border-collapse: collapse;">
          <tr>
            <td style="font-weight: 900; font-size: 18px; padding: 4px 0;" colspan="2">${orderIdText}</td>
          </tr>
          <tr>
            <td style="padding: 2px 0; color: #444;">Outlet</td>
            <td style="text-align: right; font-weight: 700; padding: 2px 0;">${outletName}</td>
          </tr>
          <tr>
            <td style="padding: 2px 0; color: #444;">Type</td>
            <td style="text-align: right; font-weight: 700; padding: 2px 0;">${deliveryIcon}</td>
          </tr>
          <tr>
            <td style="padding: 2px 0; color: #444;">Customer</td>
            <td style="text-align: right; font-weight: 700; padding: 2px 0;">${customerName}</td>
          </tr>
          <tr>
            <td style="padding: 2px 0; color: #444;">Placed</td>
            <td style="text-align: right; font-weight: 600; padding: 2px 0;">${orderDateStr} <span style="font-size: 10px; color: #777;">(${elapsedText})</span></td>
          </tr>
          <tr>
            <td style="padding: 2px 0; color: #444;">Printed</td>
            <td style="text-align: right; padding: 2px 0;">${printDateStr}</td>
          </tr>
        </table>

        ${cleanNote ? `
        <div style="font-size: 11px; border: 1px dashed #999; padding: 4px 6px; margin-bottom: 6px; font-weight: 700; color: #b45309;">
          📝 NOTE: ${cleanNote}
        </div>
        ` : ''}

        <!-- ═══ DISHES ═══ -->
        <div style="border-top: 2px dashed #000; border-bottom: 1px dashed #000; padding: 4px 0; margin-bottom: 2px;">
          <div style="font-size: 12px; font-weight: 900; text-transform: uppercase; letter-spacing: 1px;">🍳 Preparation Dishes</div>
        </div>

        <table style="width: 100%; border-collapse: collapse; margin-bottom: 4px;">
          ${itemsHtml}
        </table>

        <!-- ═══ SUMMARY ═══ -->
        <div class="summary-bar" style="font-weight: 900; font-size: 13px; border-top: 2px dashed #000; border-bottom: 2px dashed #000; padding: 6px 0; display: flex; justify-content: space-between;">
          <span>DISHES: ${targetItems.length}</span>
          <span>TOTAL QTY: ${totalQty}</span>
        </div>

        <!-- ═══ FOOTER ═══ -->
        <div class="footer" style="text-align: center; font-size: 9px; margin-top: 8px; font-weight: 700; color: #555;">
          *** FASTKIRANA KITCHEN ***<br/>
          Jaldi Banao • Garam Serve Karo ✓
        </div>

        <!-- 🛡️ Thermal roll cutter buffer -->
        <div style="height: 50px; min-height: 50px; width: 100%; display: block; clear: both; page-break-inside: avoid;"></div>
      </body>
    </html>
  `
}

const recentPrintTimesWeb = new Map<string, number>()

/**
 * Queue KOT print job cleanly without UI lag or blocking popups
 */
export function printKOTReceipt(order: any, shopType: string = 'RESTAURANT', force: boolean = false) {
  const idKey = (order.id || '').toString().trim().replace(/^#/, '')
  const readableKey = (order.readableId || '').toString().trim().replace(/^#/, '')
  const combinedKey = (order.combinedId || '').toString().trim()
  const baseReadableKey = readableKey.replace(/-[GR\d]+$/i, '')
  const now = Date.now()

  if (!force) {
    const lastTimeId = idKey ? recentPrintTimesWeb.get(idKey) : undefined
    const lastTimeReadable = readableKey ? recentPrintTimesWeb.get(readableKey) : undefined
    const lastTimeCombined = combinedKey ? recentPrintTimesWeb.get(combinedKey) : undefined
    const lastTimeBase = baseReadableKey ? recentPrintTimesWeb.get(baseReadableKey) : undefined
    const lastTime = Math.max(lastTimeId || 0, lastTimeReadable || 0, lastTimeCombined || 0, lastTimeBase || 0)

    if (lastTime > 0 && (now - lastTime) < 10000) {
      console.warn(`[KOT Print] 🛡️ Ignored duplicate print for #${readableKey || idKey} (${Math.round((10000 - (now - lastTime))/1000)}s cooldown active)`)
      return
    }
    if (idKey) recentPrintTimesWeb.set(idKey, now)
    if (readableKey) recentPrintTimesWeb.set(readableKey, now)
    if (combinedKey) recentPrintTimesWeb.set(combinedKey, now)
    if (baseReadableKey) recentPrintTimesWeb.set(baseReadableKey, now)
  }

  const html = generateKOTHtml(order, shopType)
  const orderIdText = order.readableId ? `#${order.readableId}` : `#${(order.id || '').slice(0, 8)}`

  // Discard any expired print queue items (>15s)
  printQueue = printQueue.filter(it => (Date.now() - it.timestamp) < 15000)

  printQueue.push({
    id: order.id,
    html,
    title: `KOT-${orderIdText}`,
    timestamp: now,
  })

  processPrintQueue()
}

/**
 * Generate Full Customer Invoice HTML for 80mm thermal printers
 */
export function generateInvoiceHtml(order: any): string {
  const dateStr = formatKOTDate(order.createdAt)

  const orderIdText = order.readableId ? `#${order.readableId}` : `#${(order.id || '').slice(0, 8).toUpperCase()}`

  const itemsHtml = (order.items || []).map((item: any) => `
    <tr style="border-bottom: 1px dotted #ccc;">
      <td style="padding: 4px 0; font-size: 11px; vertical-align: top;">
        <div style="font-weight: bold;">${item.name}</div>
        ${item.selectedVariant ? `<div style="font-size: 10px; color: #555;">Var: ${item.selectedVariant}</div>` : ''}
      </td>
      <td style="padding: 4px 0; text-align: center; font-size: 11px; font-weight: bold;">${item.quantity}</td>
      <td style="padding: 4px 0; text-align: right; font-size: 11px;">₹${(item.price || 0).toFixed(2)}</td>
      <td style="padding: 4px 0; text-align: right; font-size: 11px; font-weight: bold;">₹${((item.price || 0) * item.quantity).toFixed(2)}</td>
    </tr>
  `).join('')

  return `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Invoice - ${orderIdText}</title>
        <style>
          @page { size: 78mm auto; margin: 0mm; }
          html, body {
            font-family: 'Courier New', Courier, monospace;
            width: 78mm !important;
            max-width: 78mm !important;
            margin: 0 auto !important;
            padding: 4px 6px !important;
            color: #000;
            background: #fff;
            height: auto !important;
            min-height: 100% !important;
            overflow: visible !important;
            box-sizing: border-box !important;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }
          .title { font-size: 18px; font-weight: 900; text-align: center; letter-spacing: 1px; }
          .subtitle { text-align: center; font-size: 11px; font-weight: bold; margin-bottom: 8px; border-bottom: 2px dashed #000; padding-bottom: 6px; }
          .info-table { width: 100%; font-size: 11px; margin-bottom: 8px; border-bottom: 2px dashed #000; padding-bottom: 6px; }
          .items-table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
          .summary-table { width: 100%; font-size: 11px; border-top: 2px dashed #000; padding-top: 6px; margin-bottom: 8px; }
          .footer { text-align: center; font-size: 10px; margin-top: 10px; border-top: 2px dashed #000; padding-top: 6px; font-weight: bold; }
          @media print {
            html, body {
              width: 78mm !important;
              max-width: 78mm !important;
              height: auto !important;
              overflow: visible !important;
              margin: 0 !important;
              padding: 4px 6px !important;
            }
            .items-table tr, .info-table tr, .summary-table tr, .footer {
              page-break-inside: avoid !important;
              break-inside: avoid !important;
            }
          }
        </style>
      </head>
      <body>
        <div class="title">FASTKIRANA</div>
        <div class="subtitle">TAX INVOICE / RECEIPT</div>
        
        <table class="info-table">
          <tr>
            <td style="font-weight: bold;">INVOICE NO:</td>
            <td style="text-align: right; font-weight: 900; font-size: 14px;">${orderIdText}</td>
          </tr>
          <tr>
            <td>Date:</td>
            <td style="text-align: right;">${dateStr}</td>
          </tr>
          <tr>
            <td>Payment:</td>
            <td style="text-align: right; font-weight: bold;">${order.paymentMethod || 'COD'} (${order.paymentStatus || 'PENDING'})</td>
          </tr>
          <tr>
            <td>Customer:</td>
            <td style="text-align: right; font-weight: bold;">${order.userName || order.user?.name || 'Customer'}</td>
          </tr>
        </table>

        <table class="items-table">
          <thead>
            <tr style="border-bottom: 1px solid #000; text-align: left; font-size: 10px;">
              <th style="padding-bottom: 4px;">ITEM</th>
              <th style="padding-bottom: 4px; text-align: center;">QTY</th>
              <th style="padding-bottom: 4px; text-align: right;">PRICE</th>
              <th style="padding-bottom: 4px; text-align: right;">AMT</th>
            </tr>
          </thead>
          <tbody>
            ${itemsHtml}
          </tbody>
        </table>

        <table class="summary-table">
          <tr>
            <td>Subtotal:</td>
            <td style="text-align: right;">₹${(order.subtotal || 0).toFixed(2)}</td>
          </tr>
          ${order.discount ? `
            <tr>
              <td>Discount:</td>
              <td style="text-align: right; color: green;">-₹${order.discount.toFixed(2)}</td>
            </tr>
          ` : ''}
          ${order.deliveryFee ? `
            <tr>
              <td>Delivery Fee:</td>
              <td style="text-align: right;">₹${order.deliveryFee.toFixed(2)}</td>
            </tr>
          ` : ''}
          <tr style="font-size: 14px; font-weight: 900; border-top: 1px dashed #000;">
            <td style="padding-top: 4px;">TOTAL AMOUNT:</td>
            <td style="text-align: right; padding-top: 4px;">₹${(order.total || 0).toFixed(2)}</td>
          </tr>
        </table>

        <div class="footer">
          Thank you for ordering with FastKirana!<br/>
          Support: +91 70544 70303
        </div>
        <!-- 🛡️ Thermal roll cutter buffer: feeds paper past the cutter blade before cutting -->
        <div style="height: 50px; min-height: 50px; width: 100%; display: block; clear: both; page-break-inside: avoid;"></div>
      </body>
    </html>
  `
}

/**
 * Queue Invoice print job cleanly
 */
export function printCustomerInvoice(order: any) {
  const html = generateInvoiceHtml(order)
  const orderIdText = order.readableId ? `#${order.readableId}` : `#${(order.id || '').slice(0, 8)}`

  printQueue.push({
    id: order.id,
    html,
    title: `INV-${orderIdText}`,
    timestamp: Date.now(),
  })

  processPrintQueue()
}
