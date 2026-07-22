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
    iframe.style.right = '0'
    iframe.style.bottom = '0'
    iframe.style.width = '0'
    iframe.style.height = '0'
    iframe.style.border = '0'
    iframe.style.visibility = 'hidden'
    document.body.appendChild(iframe)
  }
  return iframe
}

async function processPrintQueue() {
  if (isPrinting || printQueue.length === 0) return
  isPrinting = true

  const item = printQueue.shift()!

  try {
    const iframe = getHiddenIframe()
    const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document

    if (!iframeDoc) {
      // Fallback to popup if iframe document is not accessible
      const printWindow = window.open('', '_blank', 'width=600,height=800')
      if (printWindow) {
        printWindow.document.write(item.html)
        printWindow.document.close()
        printWindow.focus()
        printWindow.print()
        setTimeout(() => printWindow.close(), 1000)
      }
    } else {
      iframeDoc.open()
      iframeDoc.write(item.html)
      iframeDoc.close()

      // Give images/styles a brief moment to render before firing native browser print dialog
      await new Promise((resolve) => setTimeout(resolve, 250))

      if (iframe.contentWindow) {
        iframe.contentWindow.focus()
        iframe.contentWindow.print()
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
    }, 500)
  }
}

/**
 * Generate thermal HTML layout for Kitchen Order Ticket (KOT)
 */
export function generateKOTHtml(order: any, shopType: string = 'RESTAURANT'): string {
  const dateStr = new Date(order.createdAt).toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  })

  const orderIdText = order.readableId ? `#${order.readableId}` : `#${(order.id || '').slice(0, 8).toUpperCase()}`

  const itemsHtml = (order.items || []).map((item: any) => `
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
            <td style="width: 45%;">Date & Time:</td>
            <td style="text-align: right; width: 55%;">${dateStr}</td>
          </tr>
          <tr>
            <td style="width: 45%;">Order Type:</td>
            <td style="text-align: right; font-weight: bold; width: 55%;">${order.deliveryMethod || 'DELIVERY'}</td>
          </tr>
          <tr>
            <td style="width: 45%;">Customer:</td>
            <td style="text-align: right; font-weight: bold; width: 55%;">${order.userName || order.user?.name || 'Customer'}</td>
          </tr>
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

/**
 * Queue KOT print job cleanly without UI lag or blocking popups
 */
export function printKOTReceipt(order: any, shopType: string = 'RESTAURANT') {
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
  const dateStr = new Date(order.createdAt).toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  })

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
