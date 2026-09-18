# FastKirana Kitchen Thermal Printer Bridge (Robust Edition) 🖨️

This background bridge enables 100% resilient, silent, zero-touch KOT printing directly on your kitchen's thermal receipt printer (80mm / 58mm).

## 🛡️ Robust Edition Features

1. **Persistent Database Queue**:
   - Every KOT order is saved in PostgreSQL (`kitchen_kot_queue`).
   - If the kitchen laptop loses internet for 10 minutes or is completely turned off, **the moment internet reconnects, all pending KOTs print out automatically!**
2. **Laptop Sleep & Lid-Close Fix**:
   - Built-in `Keep-Laptop-Awake-And-Lid-Active.bat` tool configures Windows so closing the laptop lid never stops printing.
   - Built-in Windows Keep-Awake prevents laptop sleep mode 24/7 while the bridge is running.
3. **Active Network Health Monitor & Audio Alerts**:
   - Detects kitchen Wi-Fi disconnection within seconds.
   - Emits an audible warning beep so kitchen staff knows the Wi-Fi is down.
   - Emits a recovery chime when internet is restored and immediately drains pending orders.
4. **Auto-Start on Boot**:
   - 1-click `Install-AutoStart-Startup.bat` installer configures Windows to launch the bridge on computer startup/reboot.

---

## Setup Instructions

### 1. Requirements
- The kitchen PC must run **Windows 10 or 11**.
- **Node.js** (LTS version) installed from: [https://nodejs.org/](https://nodejs.org/)
- Thermal printer connected via USB (e.g. POS-80C, XP-80, Epson TM-T82).

### 2. Printer Setup
- In Windows Settings -> **Bluetooth & devices -> Printers & scanners**, find your printer name (e.g. `POS-80C`).
- If your printer name is different, update `"PRINTER_NAME"` in `config.json`.

### 3. Step 1: Run Power & Lid Fix (One-time)
- Double-click **`Keep-Laptop-Awake-And-Lid-Active.bat`**.
- This configures Windows so the laptop never sleeps and closing the laptop lid won't stop the printer.

### 4. Step 2: Install Auto-Start on Boot (One-time)
- Double-click **`Install-AutoStart-Startup.bat`**.
- Now whenever the laptop is turned on or reboots after a power cut, the printer bridge starts automatically in the background!

### 5. Step 3: Start the Bridge
- Double-click **`start-bridge.bat`**.
- You will see: `🚀 FastKirana Kitchen Thermal Printer Bridge is RUNNING & READY!`.
- Keep this window running or minimized.

---

## Configuration (`config.json`)

```json
{
  "SUPABASE_URL": "https://bberzasmxwioxjynbuaf.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "PRINTER_NAME": "POS-80C",
  "AUTO_PRINT_ON_CONFIRM": false,
  "RESTAURANT_ID": "",
  "ENABLE_AUDIO_ALERTS": true,
  "POLL_INTERVAL_SECONDS": 6
}
```

- `"PRINTER_NAME"`: Exact Windows name of your thermal printer.
- `"AUTO_PRINT_ON_CONFIRM"`: If `true`, prints as soon as orders are confirmed. If `false`, prints when "Send KOT" is clicked.
- `"ENABLE_AUDIO_ALERTS"`: `true` enables PC speaker chimes for new orders and network disconnect alerts.
- `"POLL_INTERVAL_SECONDS"`: Frequency of checking persistent database queue for offline orders (default: 6 seconds).
