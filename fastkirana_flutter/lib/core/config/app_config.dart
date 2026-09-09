// FastKirana App Configuration & Environment Variables
//
// SECURITY: No production secrets are checked into source control.
// Required secrets must be passed via --dart-define at build time:
//
//   flutter build apk --release \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJhb... \
//     --dart-define=GOOGLE_MAPS_API_KEY=AIza... \
//     --dart-define=RAZORPAY_KEY_ID=rzp_live_...
//
// A CI/CD pipeline (GitHub Actions, Codemagic, etc.) should inject these
// from environment variables so they never appear in the repo or build logs.

import 'package:flutter/foundation.dart';

class AppConfig {
  // ─── API Endpoints ──────────────────────────────────────────────
  static const String primaryApiUrl = 'https://www.fastkirana.in';
  static const String secondaryApiUrl =
      'https://fastkirana-production-a4b8.up.railway.app';

  /// Primary URL, overridable at build time via --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: primaryApiUrl,
  );

  /// Public storefront URL (web links shared in notifications, etc.)
  static const String webStorefrontUrl = String.fromEnvironment(
    'WEB_STOREFRONT_URL',
    defaultValue: 'https://fastkirana.in',
  );

  // ─── Supabase Realtime ──────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ─── Google Maps Platform ───────────────────────────────────────
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // ─── Payment Gateway ────────────────────────────────────────────
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_TRvyzlqHiRGWbr',
  );

  // ─── Brand Assets ───────────────────────────────────────────────
  static const String appIconAsset = 'assets/brand/fastkirana_app_icon.webp';
  static const String exactLogoAsset = 'assets/brand/fastkirana_exact_logo.webp';

  // ─── Support ────────────────────────────────────────────────────
  static const String supportPhone = '+91 81128 49854';
  static const String supportEmail = 'fastkiranadelivery@gmail.com';

  // ─── Admin Contact ──────────────────────────────────────────────
  // Loaded from /api/settings at runtime. No hardcoded admin phone.

  // ─── Darkstore Hub ─────────────────────────────────────────────
  /// Initial coordinates — updated at runtime by StoreHubProvider
  /// when the nearest hub is resolved. Do NOT use `const` — these
  /// must be mutable so multi-hub / multi-city deployments work.
  static double darkstoreLat = 26.1534185;
  static double darkstoreLng = 80.1714024;
  static String darkstoreAddress = 'Ghatampur Market, Kanpur Nagar, UP - 209206';
  static String darkstoreId = 'hub-209206';

  /// Update the active darkstore hub coordinates at runtime.
  /// Called by StoreHubProvider after resolving the nearest hub.
  static void updateDarkstore({
    required double lat,
    required double lng,
    required String address,
    String? id,
  }) {
    darkstoreLat = lat;
    darkstoreLng = lng;
    darkstoreAddress = address;
    if (id != null && id.isNotEmpty) {
      darkstoreId = id;
    }
  }

  // ─── Build Information ──────────────────────────────────────────
  static const String appName = 'FastKirana';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;
  static const String buildFlavor = String.fromEnvironment(
    'BUILD_FLAVOR',
    defaultValue: 'prod',
  );

  static bool get isProduction => buildFlavor == 'prod';
  static bool get isDebug => !isProduction;

  // ─── Configuration Validation ───────────────────────────────────
  /// Checks that required secrets are present in the current build.
  /// Call this at startup (in main.dart) — if it returns false, the app
  /// was built without required --dart-define values.
  static bool get isFullyConfigured {
    if (kIsWeb) return true; // Web uses .env files via flutter_dotenv
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsApiKey.isNotEmpty &&
        razorpayKeyId.isNotEmpty;
  }

  /// Returns a list of missing required configuration keys.
  static List<String> get missingConfig {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (googleMapsApiKey.isEmpty) missing.add('GOOGLE_MAPS_API_KEY');
    if (razorpayKeyId.isEmpty) missing.add('RAZORPAY_KEY_ID');
    return missing;
  }

  /// Compare two semantic versions (e.g. "1.0.0" vs "1.0.1")
  /// Returns true if [current] is strictly lower than [target].
  static bool isVersionLower(String current, String target) {
    try {
      final cleanCurrent =
          current.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
      final cleanTarget =
          target.replaceAll(RegExp(r'[^0-9.]'), '').split('.');

      final maxLen =
          cleanCurrent.length > cleanTarget.length
              ? cleanCurrent.length
              : cleanTarget.length;

      for (int i = 0; i < maxLen; i++) {
        final curPart =
            i < cleanCurrent.length ? int.tryParse(cleanCurrent[i]) ?? 0 : 0;
        final targetPart =
            i < cleanTarget.length ? int.tryParse(cleanTarget[i]) ?? 0 : 0;

        if (curPart < targetPart) return true;
        if (curPart > targetPart) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
