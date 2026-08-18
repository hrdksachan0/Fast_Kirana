# FastKirana Kitchen Printer Bridge 🖨️

This background bridge script allows silent, zero-touch KOT printing directly from the kitchen PC's thermal printer, without depending on open browser tabs or facing tab sleep/throttling.

## Setup Instructions

### 1. Requirements
- The kitchen PC must run **Windows**.
- **Node.js** must be installed. Download & install the LTS version from: [https://nodejs.org/](https://nodejs.org/)

### 2. Printer Setup
- Connect the USB thermal printer to the PC.
- Go to Windows **Settings -> Bluetooth & devices -> Printers & scanners**.
- Make note of the printer's exact name (e.g., `XP-80`, `POS-80`, `Epson TM-T88`).
- Set it as your **Default Printer** if possible.

### 3. Copy files
- Copy this entire `kitchen-printer-bridge` folder onto the kitchen PC (e.g., save it in `C:\FastKiranaPrinter`).

### 4. Configure `config.json`
Open `config.json` on the kitchen PC using Notepad:
```json
{
  "SUPABASE_URL": "https://xzgrwwghfdsrfhbqlzwc.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_SUPABASE_ANON_KEY_HERE",
  "PRINTER_NAME": "XP-80",
  "AUTO_PRINT_ON_CONFIRM": false,
  "RESTAURANT_ID": ""
}
```
1. Replace `YOUR_SUPABASE_ANON_KEY_HERE` with your project's Supabase Anon Key (which you can copy from Vercel env or your Supabase Dashboard).
2. Set `"PRINTER_NAME"` to match your Windows printer name exactly.
3. Keep `"AUTO_PRINT_ON_CONFIRM"` as `false` to print only when the Admin clicks **"Send KOT"** on mobile/PC. Set to `true` if you want automatic printing as soon as orders are confirmed.

### 5. Start the Bridge
- Double-click **`start-bridge.bat`**.
- On first launch, it will auto-install dependencies.
- You will see a success message: `🚀 FastKirana Kitchen Printer Bridge is RUNNING!`.
- Minimize this window and keep it running in the background.

---

### Optional: Run Automatically on Windows Startup
To make the printer bridge start automatically when the computer turns on:
1. Right-click on `start-bridge.bat` and click **Create shortcut**.
2. Press `Win + R` on your keyboard, type `shell:startup`, and press **Enter**. This opens the Windows Startup folder.
3. Drag/Move the newly created shortcut of `start-bridge.bat` into this Startup folder.
4. Now, the printer bridge will launch automatically in the background on boot!
