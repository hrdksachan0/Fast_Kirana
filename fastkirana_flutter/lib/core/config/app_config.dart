// FastKirana App Configuration & Environment Variables
//
// IMPORTANT: Never hardcode secrets in client code.
// Razorpay key and other sensitive values are passed via --dart-define at build time.

class AppConfig {
  // ─── API Endpoints ──────────────────────────────────────────────
  static const String primaryApiUrl = 'https://www.fastkirana.in';
  static const String secondaryApiUrl = 'https://fastkirana-production-a4b8.up.railway.app';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: primaryApiUrl,
  );

  static const String webStorefrontUrl = String.fromEnvironment(
    'WEB_STOREFRONT_URL',
    defaultValue: 'https://fastkirana.in',
  );

  // ─── Supabase Realtime Configuration ────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bberzasmxwioxjynbuaf.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_txJDOmH1qWQuOLCKrnV69A_RQ1XS4o-',
  );

  // ─── Google Maps Platform ───────────────────────────────────────
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBA-OzFRbcw89zAZeELDWOiRl_Ce0uQYrc',
  );

  // ─── Payment Gateway (passed via --dart-define=RAZORPAY_KEY_ID) ──
  // Default is for development only. Override at build time with real keys.
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_TRvyzlqHiRGWbr',
  );

  // ─── Brand Assets ───────────────────────────────────────────────
  static const String appIconAsset = 'assets/brand/fastkirana_app_icon.webp';
  static const String exactLogoAsset = 'assets/brand/fastkirana_exact_logo.webp';

  // ─── Support & Contacts ─────────────────────────────────────────
  static const String supportPhone = '+91 81128 49854';
  static const String supportEmail = 'fastkiranadelivery@gmail.com';

  // ─── Darkstore Hub Coordinates ──────────────────────────────────
  static const double darkstoreLat = 26.1534185;
  static const double darkstoreLng = 80.1714024;
  static const String darkstoreAddress = 'Ghatampur Market, Kanpur Nagar, UP - 209206';

  // ─── Admin (for internal tooling only — not used in client auth) ─
  // NOTE: Admin credentials are NEVER stored in the client app.
  // All admin operations go through authenticated API endpoints.

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

  /// Compare two semantic versions (e.g. "1.0.0" vs "1.0.1")
  /// Returns true if [current] is strictly lower than [target].
  static bool isVersionLower(String current, String target) {
    try {
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
      final cleanTarget = target.replaceAll(RegExp(r'[^0-9.]'), '').split('.');

      final maxLen = cleanCurrent.length > cleanTarget.length ? cleanCurrent.length : cleanTarget.length;

      for (int i = 0; i < maxLen; i++) {
        final curPart = i < cleanCurrent.length ? int.tryParse(cleanCurrent[i]) ?? 0 : 0;
        final targetPart = i < cleanTarget.length ? int.tryParse(cleanTarget[i]) ?? 0 : 0;

        if (curPart < targetPart) return true;
        if (curPart > targetPart) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
