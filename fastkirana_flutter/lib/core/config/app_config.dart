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

  // ─── Payment Gateway (passed via --dart-define=RAZORPAY_KEY_ID) ──
  // Default is for development only. Override at build time with real keys.
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_placeholder',
  );

  // ─── Brand Assets ───────────────────────────────────────────────
  static const String appIconAsset = 'assets/brand/fastkirana_app_icon.png';
  static const String exactLogoAsset = 'assets/brand/fastkirana_exact_logo.png';

  // ─── Support & Contacts ─────────────────────────────────────────
  static const String supportPhone = '+91 70544 70303';
  static const String supportEmail = 'admin@fastkirana.in';

  // ─── Darkstore Hub Coordinates ──────────────────────────────────
  static const double darkstoreLat = 26.1534185;
  static const double darkstoreLng = 80.1714024;
  static const String darkstoreAddress = 'Ghatampur Market, Kanpur Nagar, UP - 209206';

  // ─── Admin (for internal tooling only — not used in client auth) ─
  // NOTE: Admin credentials are NEVER stored in the client app.
  // All admin operations go through authenticated API endpoints.

  // ─── Build Information ──────────────────────────────────────────
  static const String appName = 'FastKirana';
  static const String buildFlavor = String.fromEnvironment(
    'BUILD_FLAVOR',
    defaultValue: 'prod',
  );

  static bool get isProduction => buildFlavor == 'prod';
  static bool get isDebug => !isProduction;
}
