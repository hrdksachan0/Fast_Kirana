---
name: thermal-pos-expert
description: Complete architecture, styling, and protocol guide for 58mm & 80mm thermal receipt printing, Kitchen Order Ticket (KOT) generation, ESC/POS commands, thermal layout styling, Bluetooth POS reconnection, and zero-drop kitchen ticketing across Next.js and Flutter.
---

# Thermal POS & Kitchen Order Ticket (KOT) Expert Guide

When this skill is active, the agent acts as an elite **Thermal POS & Kitchen Order Ticket (KOT) Engineer**, specializing in thermal printer layouts (58mm / 80mm), ESC/POS commands, mobile Bluetooth POS printing, and web-based silent printing systems.

---

## 1. Core Principles of Thermal Printing

1. **Zero-Drop Ticket Guarantee**:
   - Every single dish ordered from a restaurant/kitchen MUST appear on the KOT.
   - Dedicated restaurant orders (`orderType === 'RESTAURANT'`, `restaurantId != null`, or readable ID ending with `-R`) must **never** be filtered by restrictive keyword lists or unpopulated database IDs.
   - Unrecognized dish names must always default to inclusion on kitchen tickets. Only explicitly blacklisted packaged grocery items (soaps, atta, detergents) may be filtered on un-split raw combined orders.

2. **Denser, Scannable Monospace Layouts**:
   - Thermal printers use fixed DPI (typically 203 DPI / 8 dots per mm).
   - Monospace typography is mandatory (`Courier New` on Web, `RobotoMono` or `Courier` on Flutter PDF).
   - Dashed dividers (`1px dashed #000` or `- - - - -`) ensure crisp line breaks without excessive thermal head heating.

3. **Duplication Guard & Print Queuing**:
   - Accidental double-taps by busy chefs or kitchen staff must be blocked using a 10-second deduplication hash check based on `orderId` or `readableId`.
   - Always run web printing inside a persistent hidden `<iframe>` to avoid locking the UI thread.

---

## 2. Printer Specifications & Paper Geometry

| Specification | 58mm Roll (Mini POS) | 80mm Roll (Standard POS) |
| :--- | :--- | :--- |
| **Printable Width** | 48 mm (384 dots) | 72 mm (576 dots) |
| **Monospace Columns** | 32 characters (Font A) / 42 (Font B) | 48 characters (Font A) / 64 (Font B) |
| **Web CSS Container** | `width: 54mm; margin: 0 auto;` | `width: 78mm; margin: 0 auto;` |
| **Flutter Page Format** | `PdfPageFormat.roll57` | `PdfPageFormat.roll80` |
| **Margins** | Top/Bottom: 3mm, Left/Right: 2mm | Top/Bottom: 4mm, Left/Right: 4mm |

---

## 3. Standard KOT (Kitchen Order Ticket) Structure

A production-grade KOT must strictly contain the following sections:

```
+------------------------------------------+
|               FASTKIRANA                 |
|       KITCHEN ORDER TICKET (KOT)         |
+ - - - - - - - - - - - - - - - - - - - - -+
| TICKET ID:                      #2071-R  |
| Order Placed:      28 Sep, 08:45 PM (5m) |
| KOT Printed:            28 Sep, 08:50 PM |
| Order Type:                     DELIVERY |
| Customer:                   Rahul Sharma |
| Order Note:        Please make it spicy! |
+ - - - - - - - - - - - - - - - - - - - - -+
| PREPARATION DISHES:                      |
|                                          |
| [2x] Double Cheese Burger                |
|      (Extra Cheese Slice)                |
|      Note: No mayonnaise                 |
| - - - - - - - - - - - - - - - - - - - -  |
| [1x] French Fries / Finger Chips         |
|      (Peri Peri Masala)                  |
| - - - - - - - - - - - - - - - - - - - -  |
| [1x] Cold Coffee with Ice Cream          |
+ - - - - - - - - - - - - - - - - - - - - -+
| TOTAL DISHES: 3            TOTAL QTY: 4  |
+ - - - - - - - - - - - - - - - - - - - - -+
|     *** FASTKIRANA KITCHEN SYSTEM ***    |
|      Prompt & Hot Preparation Verified   |
+------------------------------------------+
```

### Essential Item Fields:
1. **Quantity Badge**: Prominently displayed at the front (e.g., `[2x]`) with high visual contrast.
2. **Dish Name**: Bold, 13–15px font size.
3. **Selected Variant**: Highlighted in parentheses (e.g., `(Regular / Spicy)`).
4. **Chef / Kitchen Note**: Italicized under the item (e.g., `📝 Note: no onion, no garlic`).
5. **Summary Counter**: Summary row showing `TOTAL DISHES` and `TOTAL QTY` so the chef can cross-verify in 1 second.

---

## 4. Standard Customer Bill / Invoice Structure

Customer bills must include clear financial breakdown:
1. **Header**: Store/Restaurant Name, Address, GSTIN, FSSAI License, Phone Number.
2. **Metadata**: Bill No., Order Date & Time, Customer Name & Address, Delivery Partner Name.
3. **Itemized Table**:
   - Columns: Item Name & Variant, Qty, Unit Price, Total Price.
4. **Bill Summary**:
   - Item Subtotal
   - Taxes (GST 5% or 18%)
   - Delivery Fee & Packaging Fee
   - Discounts / Promo Code applied
   - **Grand Total (Big & Bold)**
5. **Payment Method**:
   - `PAID ONLINE (Cashfree / UPI)` OR `COLLECT CASH ON DELIVERY: ₹XXX`
6. **Footer**: Barcode / QR Code for order tracking, "Thank you for ordering with FastKirana".

---

## 5. Next.js Web Silent Printing Architecture (`src/lib/kot-print.ts`)

```typescript
// Pattern: Hidden iframe silent printing queue
const printQueue: Array<{ id: string; html: string; title: string }> = []
let isPrinting = false

export function processPrintQueue() {
  if (isPrinting || printQueue.length === 0) return
  isPrinting = true

  const job = printQueue.shift()!
  const iframe = getHiddenIframe()

  const doc = iframe.contentWindow?.document
  if (doc) {
    doc.open()
    doc.write(job.html)
    doc.close()

    setTimeout(() => {
      iframe.contentWindow?.focus()
      iframe.contentWindow?.print()
      isPrinting = false
      processPrintQueue()
    }, 300)
  }
}
```

---

## 6. Flutter Mobile Bluetooth POS Printing Protocol

When implementing Bluetooth thermal printing on Flutter:
1. **Auto-Discovery & Pairing**:
   - Scan for Bluetooth Classic & BLE devices matching printer service UUIDs (`000018f0-0000-1000-8000-00805f9b34fb`).
   - Store last successfully connected MAC address in `SharedPreferences`.
2. **Connection Resilience**:
   - Implement exponential backoff: if printer disconnects during idle, attempt 3 retries (1s, 2s, 4s).
   - Display a persistent connection badge (🟢 Printer Connected / 🔴 Printer Disconnected) in the vendor/kitchen dashboard.
3. **ESC/POS Command Sequence**:
   - Initialize: `[0x1B, 0x40]` (ESC @)
   - Align Center: `[0x1B, 0x61, 0x01]`
   - Text Size Normal: `[0x1D, 0x21, 0x00]`
   - Text Size Double Height/Width: `[0x1D, 0x21, 0x11]`
   - Line Feed: `[0x0A]`
   - Feed & Cut: `[0x1D, 0x56, 0x42, 0x00]` (GS V 'B' 0)
