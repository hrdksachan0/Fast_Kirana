# 📱 Fastkirana Flutter Mobile Application

Independent standalone Flutter Mobile App frontend for **Fastkirana** (10-Minute Grocery Quick Commerce), connected to the Python FastAPI backend.

---

## 🚀 Folder Structure
```
fastkirana_flutter_app/
├── lib/
│   ├── main.dart             # App Entry Point & Providers
│   ├── models/               # Product & Cart Data Models
│   │   ├── product.dart
│   │   └── cart_item.dart
│   ├── services/             # FastAPI REST & WebSocket Client
│   │   └── api_service.dart
│   ├── providers/            # State Management (CartProvider)
│   │   └── cart_provider.dart
│   ├── theme/                # Fastkirana Color Tokens & Theme
│   │   └── app_theme.dart
│   ├── widgets/              # Reusable Product Cards & Cart Bar
│   │   ├── product_card.dart
│   │   └── floating_cart_bar.dart
│   └── screens/              # App Screens (Home, Checkout, Tracker)
│       └── home_screen.dart
└── pubspec.yaml              # Dependencies configuration
```

---

## 🛠️ How to Run & Build APK

### 1. Install Dependencies
```bash
cd fastkirana_flutter_app
flutter pub get
```

### 2. Run App (Emulator / USB Connected Phone)
```bash
flutter run
```

### 3. Build Standalone Release Android APK
```bash
flutter build apk --release
```
📍 **Output File Path**: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔌 FastAPI Connection Config
- **Android Emulator**: `http://10.0.2.2:8000/api`
- **Physical Phone over Wi-Fi**: `http://<YOUR_LAPTOP_IP>:8000/api`
