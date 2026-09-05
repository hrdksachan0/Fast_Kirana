/**
 * High-Performance KOT & Receipt Printing Engine for FastKirana
 * Handles zero-lag, popup-free silent printing via hidden DOM iframe queue.
 */

interface PrintQueueItem {
  id: string
  html: string
  title: string
}

let printQueue: PrintQueueItem[] = []
let isPrinting = false

function getHiddenIframe(): HTMLIFrameElement {
  let iframe = document.getElementById('fastkirana-silent-printer') as HTMLIFrameElement
  if (!iframe) {
    iframe = document.createElement('iframe')
    iframe.id = 'fastkirana-silent-printer'
    iframe.style.position = 'fixed'
    iframe.style.right = '-9999px'
    iframe.style.bottom = '-9999px'
    iframe.style.width = '350px'
    iframe.style.height = '450px'
    iframe.style.opacity = '0.01'
    iframe.style.pointerEvents = 'none'
    iframe.style.border = '0'
    iframe.style.zIndex = '-9999'
    document.body.appendChild(iframe)
  }
  return iframe
}

async function processPrintQueue() {
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
        }, 350)
      }
    } else {
      const iframe = getHiddenIframe()
      const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document

      if (iframeDoc && iframe.contentWindow) {
        iframeDoc.open()
        iframeDoc.write(item.html)
        iframeDoc.close()

        await new Promise((resolve) => setTimeout(resolve, 50))

        try {
          iframe.contentWindow.focus()
          iframe.contentWindow.print()
        } catch (printErr) {
          console.warn('Iframe print blocked, falling back to window.open:', printErr)
          const printWindow = window.open('', '_blank', 'width=450,height=600')
          if (printWindow) {
            printWindow.document.write(item.html)
            printWindow.document.close()
            printWindow.focus()
            printWindow.print()
          }
        }
      } else {
        const printWindow = window.open('', '_blank', 'width=450,height=600')
        if (printWindow) {
          printWindow.document.write(item.html)
          printWindow.document.close()
          printWindow.focus()
          printWindow.print()
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
    }, 50)
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
  
  // Extract strictly restaurant dishes (omit any grocery items)
  let targetItems = (order.restaurantItems && order.restaurantItems.length > 0)
    ? order.restaurantItems
    : (restSub?.items && restSub.items.length > 0)
    ? restSub.items
    : (order.items || [])

  // 1. Primary: Strict ID-wise & Type Filter (Most Reliable & Accurate)
  if (Array.isArray(targetItems) && targetItems.length > 0) {
    const idFiltered = targetItems.filter((it: any) => {
      if (!it) return false
      return (
        Boolean(it.restaurantId) ||
        it.type === 'RESTAURANT' ||
        it.isRestaurantItem === true ||
        Boolean(it.product?.restaurantId) ||
        it.product?.isRestaurantItem === true
      )
    })
    if (idFiltered.length > 0) {
      targetItems = idFiltered
    }
  }

  // 2. Secondary fallback for combined orders where item flags are missing
  if (order.isCombined && (!order.restaurantItems || order.restaurantItems.length === 0) && (!restSub?.items || restSub.items.length === 0)) {
    const cookedFoodWhitelists = [
      'dosa', 'burger', 'pizza', 'sandwich', 'roll', 'frankie', 'chowmein', 'noodles',
      'fried rice', 'paneer', 'manchurian', 'shake', 'cold coffee', 'tea', 'chai', 'coffee',
      'pasta', 'thali', 'roti', 'naan', 'gravy', 'curry', 'biryani', 'pav bhaji', 'fries',
      'momos', 'samosa', 'maggi', 'soup'
    ]
    const pureGroceryCategories = ['personal-care', 'home-cleaning', 'household', 'grocery', 'staples']
    const pureGroceryKeywords = [
      'atta', 'raw rice', 'dal packet', 'mustard oil', 'refined oil', 'washing powder',
      'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner'
    ]
    const filtered = targetItems.filter((it: any) => {
      if (Boolean(it.restaurantId) || it.type === 'RESTAURANT' || it.isRestaurantItem === true) return true
      const name = (it.name || '').toLowerCase()
      if (cookedFoodWhitelists.some((cw) => name.includes(cw))) return true
      const slug = (it.categorySlug || it.category?.slug || '').toLowerCase()
      if (pureGroceryCategories.some((c: string) => slug.includes(c))) return false
      if (pureGroceryKeywords.some((k: string) => name.includes(k))) return false
      return true
    })
    if (filtered.length > 0) {
      targetItems = filtered
    }
  }

  const outletName = restSub?.shopName || order.restaurantName || (order.restaurantId ? order.shopName : null) || shopType
  const orderIdText = restSub?.readableId 
    ? `#${restSub.readableId}` 
    : (order.readableId && order.isCombined)
    ? `#${order.readableId}-R`
    : order.readableId 
    ? `#${order.readableId}` 
    : `#${(order.id || '').slice(0, 8).toUpperCase()}`

  const itemsHtml = targetItems.map((item: any) => `
    <tr style="border-bottom: 1px dashed #ddd;">
      <td style="padding: 6px 0; font-weight: bold; font-size: 15px; vertical-align: top; width: 38px;">[${item.quantity}x]</td>
      <td style="padding: 6px 0; font-size: 13px;">
        <div style="font-weight: bold; font-size: 14px;">
          ${item.name}
          ${item.selectedVariant ? `<span style="font-size: 11px; color: #d97706; margin-left: 4px;">(${item.selectedVariant})</span>` : ''}
        </div>
        ${item.notes ? `<div style="font-size: 11px; color: #444; font-style: italic; margin-top: 2px;">📝 Note: ${item.notes}</div>` : ''}
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
            size: auto;
            margin: 0mm;
          }
          body {
            font-family: 'Courier New', Courier, monospace;
            width: 78mm;
            margin: 0 auto;
            padding: 8px;
            color: #000;
            background: #fff;
          }
          .title {
            font-size: 18px;
            font-weight: 900;
            text-align: center;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 4px;
          }
          .subtitle {
            text-align: center;
            font-size: 12px;
            font-weight: bold;
            margin-top: 2px;
            margin-bottom: 8px;
            border-bottom: 2px dashed #000;
            padding-bottom: 6px;
          }
          .info-table {
            width: 100%;
            font-size: 12px;
            margin-bottom: 8px;
            border-bottom: 2px dashed #000;
            padding-bottom: 8px;
          }
          .items-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 10px;
          }
          .footer {
            text-align: center;
            font-size: 10px;
            margin-top: 12px;
            border-top: 2px dashed #000;
            padding-top: 8px;
            font-weight: bold;
          }
          @media print {
            body {
              width: 100%;
              padding: 4px;
            }
          }
        </style>
      </head>
      <body>
        <div class="title">FASTKIRANA</div>
        <div class="subtitle">KITCHEN ORDER TICKET (${shopType})</div>
        
        <table class="info-table">
          <tr>
            <td style="font-weight: bold; width: 45%;">TICKET ID:</td>
            <td style="text-align: right; font-weight: 900; font-size: 15px; width: 55%;">${orderIdText}</td>
          </tr>
          <tr>
            <td style="width: 45%;">Order Placed:</td>
            <td style="text-align: right; font-weight: bold; width: 55%;">${orderDateStr} <span style="font-size: 10px; color: #555;">(${elapsedText})</span></td>
          </tr>
          <tr>
            <td style="width: 45%;">KOT Printed:</td>
            <td style="text-align: right; width: 55%;">${printDateStr}</td>
          </tr>
          <tr>
            <td style="width: 45%;">Order Type:</td>
            <td style="text-align: right; font-weight: bold; width: 55%;">${order.deliveryMethod || 'DELIVERY'}</td>
          </tr>
          <tr>
            <td style="width: 45%;">Customer:</td>
            <td style="text-align: right; font-weight: bold; width: 55%;">${order.userName || order.user?.name || 'Customer'}</td>
          </tr>
          ${order.notes ? `
          <tr>
            <td style="width: 45%; vertical-align: top;">Order Note:</td>
            <td style="text-align: right; font-weight: bold; color: #b45309; width: 55%;">${order.notes}</td>
          </tr>` : ''}
        </table>

        <div style="font-size: 11px; font-weight: bold; margin-bottom: 6px; text-transform: uppercase;">PREPARATION DISHES:</div>
        
        <table class="items-table">
          ${itemsHtml}
        </table>

        <div class="footer">
          *** FASTKIRANA KITCHEN SYSTEM ***<br/>
          Prompt & Hot Preparation Verified
        </div>
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

  printQueue.push({
    id: order.id,
    html,
    title: `KOT-${orderIdText}`
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
          @page { size: auto; margin: 0mm; }
          body {
            font-family: 'Courier New', Courier, monospace;
            width: 78mm;
            margin: 0 auto;
            padding: 8px;
            color: #000;
            background: #fff;
          }
          .title { font-size: 18px; font-weight: 900; text-align: center; letter-spacing: 1px; }
          .subtitle { text-align: center; font-size: 11px; font-weight: bold; margin-bottom: 8px; border-bottom: 2px dashed #000; padding-bottom: 6px; }
          .info-table { width: 100%; font-size: 11px; margin-bottom: 8px; border-bottom: 2px dashed #000; padding-bottom: 6px; }
          .items-table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
          .summary-table { width: 100%; font-size: 11px; border-top: 2px dashed #000; padding-top: 6px; margin-bottom: 8px; }
          .footer { text-align: center; font-size: 10px; margin-top: 10px; border-top: 2px dashed #000; padding-top: 6px; font-weight: bold; }
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
    title: `INV-${orderIdText}`
  })

  processPrintQueue()
}
