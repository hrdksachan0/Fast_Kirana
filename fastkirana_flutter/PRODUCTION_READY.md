# FastKirana Production Deployment Guide

This document explains how to build, sign, and deploy the FastKirana Flutter app to production.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | 3.27+ | App framework |
| Java JDK | 17+ | Android builds (for keytool) |
| Android Studio | Hedgehog+ | Android SDK |
| PowerShell | 5.1+ | Build scripts (Windows) |
| Google Play Console account | - | App distribution |

---

## First-Time Setup (One-time)

### 1. Generate Release Keystore

```powershell
cd fastkirana_flutter\scripts
.\generate_keystore.ps1
```

This creates `android/app/fastkirana_release.keystore`. **Save the passwords in a secure password manager** — losing them means you cannot update your app on Play Store.

### 2. Configure Signing

Copy `android/key.template.properties` to `android/key.properties` and fill in the values from step 1.

```properties
storeFile=fastkirana_release.keystore
storePassword=<your_keystore_password>
keyAlias=fastkirana
keyPassword=<your_key_password>
```

`key.properties` is already in `.gitignore` — it will never be committed.

### 3. Verify Firebase Project

The app uses Firebase project `fastkirana-98a68`. Ensure:
- Firebase Crashlytics is enabled in the console
- Firebase Cloud Messaging is configured
- The FCM service account JSON is available for server-side pushes

---

## Build Commands

### Production Release (AAB for Play Store)

```powershell
.\scripts\build_release.ps1
```

Output: `build\app\outputs\bundle\release\app-release.aab`

With code obfuscation (recommended for production):

```powershell
.\scripts\build_obfuscated.ps1
```

Output: `build\app\outputs\bundle\release\app-release.aab`
Debug symbols: `build\debug-info/` — **keep this for crash de-obfuscation**

### Release APK (for direct distribution)

```powershell
.\scripts\build_release.ps1 -Apk
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

### Development Build

```powershell
.\scripts\build_dev.ps1
```

Output: `build\app\outputs\flutter-apk\app-debug.apk`

Install to connected device:

```powershell
.\scripts\build_dev.ps1 -Install
```

---

## Build-Time Variables

All production builds use these `--dart-define` values:

| Variable | Production Value | Dev Value |
|----------|-----------------|-----------|
| `API_BASE_URL` | `https://www.fastkirana.in` | `http://localhost:3000` |
| `WEB_STOREFRONT_URL` | `https://fastkirana.in` | `http://localhost:3000` |
| `RAZORPAY_KEY_ID` | `rzp_live_*` | `rzp_test_placeholder` |
| `BUILD_FLAVOR` | `prod` | `dev` |

---

## What's Configured for Production

### ✅ Security
- HTTPS-only network traffic (cleartext blocked except for localhost)
- Release-signed APK/AAB with proper keystore
- Code obfuscation via R8 (ProGuard rules)
- Secrets injected at build time, never hardcoded

### ✅ Performance
- Minified, shrunk resources (~30-40% smaller APK)
- Portrait orientation locked
- Crashes logged via FlutterError hooks

### ✅ Notifications
- FCM foreground + background handlers
- Topic-based subscriptions (`all_users`, `ghatampur_alerts`, `user_{id}`)
- Notification preferences (order, offers, delivery)
- Auto-dedup across simultaneous broadcasts

### ✅ Deep Linking
- `fastkirana://order/{id}` — order tracking
- `fastkirana://product/{slug}` — product detail

Test deep link:
```bash
adb shell am start -a android.intent.action.VIEW -d "fastkirana://order/test123"
```

### ✅ Permissions
Only essential permissions declared:
- Internet, network state, location, notifications, vibration
- Battery optimization exemption (delivery reliability)

Removed: Bluetooth, WAKE_LOCK, RECORD_AUDIO (unnecessary)

### ✅ User Trust
- Privacy Policy screen (linked from Settings)
- Error boundary with branded fallback UI
- Version info visible in Settings

---

## Play Store Submission Checklist

- [ ] Keystore generated and stored safely
- [ ] `key.properties` configured
- [ ] `flutter build appbundle --obfuscate` succeeds
- [ ] Tested on Android 13+ device (notification permission prompt)
- [ ] Tested on Android 7+ device (min SDK)
- [ ] Crash reporting configured in Firebase
- [ ] Privacy Policy URL hosted (link from Settings)
- [ ] Play Store 512x512 icon present
- [ ] Feature graphic (1024x500) prepared
- [ ] Short description (80 chars) and full description
- [ ] App category: Shopping
- [ ] Target audience: All
- [ ] Content rating: Everyone

---

## Common Issues

### `keytool: command not found`
Install Java JDK 17+ and add to PATH.

### `Build failed: signing config not found`
You need to copy `key.template.properties` to `key.properties` and fill values.

### `Crashlytics couldn't find project`
Enable Crashlytics in the Firebase console for project `fastkirana-98a68`.

### Deep links don't open
1. Verify intent filter in `AndroidManifest.xml`
2. Run `adb shell pm dump com.fastkirana.app | grep fastkirana` to confirm
3. Test with `adb shell am start -a android.intent.action.VIEW -d "fastkirana://order/123"`

---

## Project Structure

```
fastkirana_flutter/
├── android/
│   ├── app/
│   │   ├── build.gradle            # Signing + ProGuard config
│   │   ├── proguard-rules.pro      # R8 rules
│   │   └── src/main/
│   │       ├── AndroidManifest.xml # Permissions + deep links
│   │       └── res/xml/
│   │           └── network_security_config.xml
│   ├── key.template.properties     # Signing template (committed)
│   └── key.properties              # Local signing config (gitignored)
├── lib/
│   ├── core/
│   │   ├── config/app_config.dart  # Build-time constants
│   │   └── services/
│   │       └── notification_service.dart
│   └── features/
│       └── settings/
│           ├── privacy_policy_screen.dart
│           └── settings_screen.dart
├── scripts/
│   ├── generate_keystore.ps1       # Keystore generator
│   ├── build_release.ps1           # AAB release
│   ├── build_dev.ps1               # Dev debug
│   └── build_obfuscated.ps1        # Obfuscated release
└── pubspec.yaml
```

---

## Need Help?

- Email: admin@fastkirana.in
- Phone: +91 70544 70303
