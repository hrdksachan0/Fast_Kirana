# FastKirana Google Sheets Inventory Synchronizer Guide

This guide explains how to connect your **FastKirana** database to a **Google Sheet** so you can manage your inventory (MRP, price, stock levels, and availability) directly from a spreadsheet.

---

## 🛠️ Step 1: Create Your Google Sheet
1. Open [Google Sheets](https://sheets.google.com) and create a **blank spreadsheet**.
2. Name the spreadsheet (e.g., `FastKirana Store Inventory`).
3. You do **not** need to manually type the column headers or product rows; the Apps Script will automatically fetch and format them for you.

---

## 💻 Step 2: Add Google Apps Script
1. In the Google Sheets menu, go to **Extensions** ➡️ **Apps Script**.
2. Delete any default code in the editor (`Code.gs`) and paste the following script:

```javascript
// CONFIGURATION: Set your FastKirana API details here
// 1. If testing locally: Use the Localtunnel URL (see Step 3 below)
// 2. If deployed to production: Use your website's URL (e.g., https://yourwebsite.com/api/admin/inventory/sync)
const API_URL = "YOUR_WEBSITE_OR_TUNNEL_URL/api/admin/inventory/sync";
const API_KEY = "supersecuresynctoken123";

/**
 * Creates a custom menu in Google Sheets on load.
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu("FastKirana Inventory")
    .addItem("⬇️ Fetch Products from Database", "importProducts")
    .addSeparator()
    .addItem("⬆️ Sync Changes to Database", "syncInventory")
    .addToUi();
}

/**
 * Imports products from the database into the current sheet.
 */
function importProducts() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const ui = SpreadsheetApp.getUi();
  
  try {
    ui.showModelessDialog(
      HtmlService.createHtmlOutput("<p style='font-family:sans-serif;'>Fetching products from database, please wait...</p>").setWidth(250).setHeight(80),
      "Importing..."
    );

    const url = API_URL + "?apiKey=" + encodeURIComponent(API_KEY);
    const response = UrlFetchApp.fetch(url, {
      method: "get",
      headers: {
        "bypass-tunnel-reminder": "true"
      },
      muteHttpExceptions: true
    });
    
    const responseCode = response.getResponseCode();
    const responseText = response.getContentText();
    
    if (responseCode !== 200) {
      throw new Error("HTTP Error " + responseCode + ": " + responseText);
    }
    
    const result = JSON.parse(responseText);
    if (!result.success || !result.products) {
      throw new Error("Invalid response format: " + responseText);
    }
    
    const products = result.products;
    
    // Clear entire sheet
    sheet.clear();
    
    // Setup Headers
    const headers = [["Slug", "Name", "Price", "MRP", "Stock", "Available", "Unit"]];
    sheet.getRange(1, 1, 1, 7).setValues(headers)
      .setFontWeight("bold")
      .setBackground("#F1F5F9")
      .setFontColor("#1E293B")
      .setHorizontalAlignment("center");
    
    if (products.length > 0) {
      const rows = products.map(p => [
        p.slug,
        p.name,
        p.price,
        p.mrp,
        p.stock,
        p.isAvailable,
        p.unit
      ]);
      
      sheet.getRange(2, 1, rows.length, 7).setValues(rows);
      
      // Formatting
      sheet.getRange(2, 3, rows.length, 2).setNumberFormat("₹#,##0.00"); // Price & MRP
      sheet.getRange(2, 5, rows.length, 1).setNumberFormat("#,##0"); // Stock
      sheet.getRange(2, 6, rows.length, 1).setHorizontalAlignment("center"); // Available (Boolean)
      sheet.getRange(2, 7, rows.length, 1).setHorizontalAlignment("center"); // Unit
    }
    
    sheet.autoResizeColumns(1, 7);
    
    ui.alert("Success", "Loaded " + products.length + " products from the database successfully!", ui.ButtonSet.OK);
    
  } catch (error) {
    Logger.log(error);
    ui.alert("Error", "Failed to fetch products: " + error.message, ui.ButtonSet.OK);
  }
}

/**
 * Syncs updated prices, MRP, stock, and availability back to the database.
 */
function syncInventory() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const ui = SpreadsheetApp.getUi();
  
  try {
    const lastRow = sheet.getLastRow();
    if (lastRow < 2) {
      ui.alert("Information", "No product rows found to sync.", ui.ButtonSet.OK);
      return;
    }
    
    // Get all product data from the sheet
    const dataRange = sheet.getRange(2, 1, lastRow - 1, 7);
    const values = dataRange.getValues();
    
    const productsToSync = [];
    
    for (let i = 0; i < values.length; i++) {
      const row = values[i];
      const slug = row[0];
      const name = row[1];
      const price = parseFloat(row[2]);
      const mrp = parseFloat(row[3]);
      const stock = parseInt(row[4]);
      const isAvailable = row[5] === true || String(row[5]).toUpperCase() === "TRUE";
      
      if (!slug) continue; // Skip blank rows
      
      productsToSync.push({
        slug: slug,
        price: price,
        mrp: mrp,
        stock: stock,
        isAvailable: isAvailable
      });
    }
    
    if (productsToSync.length === 0) {
      ui.alert("Information", "No products to sync.", ui.ButtonSet.OK);
      return;
    }
    
    // Prompt confirmation
    const confirm = ui.alert(
      "Confirm Sync",
      "Are you sure you want to sync " + productsToSync.length + " products to the database?",
      ui.ButtonSet.YES_NO
    );
    
    if (confirm !== ui.Button.YES) {
      return;
    }
    
    // Send data to server
    const payload = JSON.stringify({
      apiKey: API_KEY,
      products: productsToSync
    });
    
    const options = {
      method: "post",
      contentType: "application/json",
      headers: {
        "bypass-tunnel-reminder": "true"
      },
      payload: payload,
      muteHttpExceptions: true
    };
    
    ui.showModelessDialog(
      HtmlService.createHtmlOutput("<p style='font-family:sans-serif;'>Uploading inventory updates, please wait...</p>").setWidth(250).setHeight(80),
      "Syncing..."
    );
    
    const response = UrlFetchApp.fetch(API_URL, options);
    const responseCode = response.getResponseCode();
    const responseText = response.getContentText();
    
    if (responseCode !== 200) {
      throw new Error("HTTP Error " + responseCode + ": " + responseText);
    }
    
    const result = JSON.parse(responseText);
    if (result.success) {
      ui.alert(
        "Sync Complete",
        "Successfully updated: " + result.updated + " products.\n" +
        "Skipped: " + result.skipped + " products.",
        ui.ButtonSet.OK
      );
    } else {
      throw new Error(result.error || "Unknown server error");
    }
    
  } catch (error) {
    Logger.log(error);
    ui.alert("Error", "Failed to sync inventory: " + error.message, ui.ButtonSet.OK);
  }
}
```

3. Save the script by clicking the 💾 (Save) icon, or press `Ctrl + S`.
4. Close the Apps Script editor tab and reload your Google Sheet.
5. After reloading, you will see a new menu at the top named **FastKirana Inventory**.

---

## 🌐 Step 3: Making Localhost Accessible to Google Sheets
Because Google Sheets runs in the cloud, it cannot access `http://localhost:3000` directly. You need to expose your local Next.js server using a temporary public URL.

### Option A: Using Localtunnel (Easiest, No registration needed)
Open your terminal in the `d:\Fastkirana` folder and run:
```bash
npx localtunnel --port 3000
```
This will print a public URL like:
`https://great-geese-dash.localtunnel.me`

### Option B: Using Ngrok (Highly stable, Free registration required)
1. Download and install ngrok.
2. Run:
```bash
ngrok http 3000
```
This will give you a public URL like:
`https://a1b2-cd34-56ef.ngrok-free.app`

---

## 🔗 Step 4: Connecting the Sheet
1. Copy the public URL you got in **Step 3** (e.g., `https://great-geese-dash.localtunnel.me`).
2. Go back to your Google Sheets tab, open **Extensions** ➡️ **Apps Script**.
3. Replace the `API_URL` line (Line 5) with your new URL, keeping `/api/admin/inventory/sync` at the end:
   ```javascript
   const API_URL = "https://great-geese-dash.localtunnel.me/api/admin/inventory/sync";
   ```
4. Save the script (`Ctrl + S`).

---

## ⚡ Step 5: Start Managing Inventory!

### 1. Load Products from your Database
1. In your Google Sheet, click **FastKirana Inventory** ➡️ **⬇️ Fetch Products from Database**.
2. **First Time Authorization**: Google will request permissions. Click **Continue**, select your Google account, click **Advanced**, click **Go to Untitled project (unsafe)**, and click **Allow**.
3. Re-run the command (**Fetch Products from Database**).
4. All the products from your PostgreSQL database will appear with correct formatting!

### 2. Make Edits
You can edit the following columns:
* **Price**: Change selling price.
* **MRP**: Change Maximum Retail Price (Discount calculations are updated automatically).
* **Stock**: Change stock levels (e.g. set to `0` or add new items).
* **Available**: Double-click to set to `TRUE` (available) or `FALSE` (out of stock/hidden).

*Note: Do not modify the **Slug** or **Name** column as they are used to match the product in the database.*

### 3. Sync Back to Database
1. Go to **FastKirana Inventory** ➡️ **⬆️ Sync Changes to Database**.
2. Confirm the action.
3. Your PostgreSQL database will update in real-time, and you will see a success confirmation box!
