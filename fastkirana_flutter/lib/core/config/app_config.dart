// FastKirana App Configuration & Environment Variables

class AppConfig {
  // Base URLs
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fast-kirana-0ezx.onrender.com',
  );

  static const String webStorefrontUrl = String.fromEnvironment(
    'WEB_STOREFRONT_URL',
    defaultValue: 'https://fastkirana.in',
  );

  // Brand Assets
  static const String appIconAsset = 'assets/brand/fastkirana_app_icon.png';
  static const String exactLogoAsset = 'assets/brand/fastkirana_exact_logo.png';

  // Support & Contacts
  static const String supportPhone = '+91 70544 70303';
  static const String supportEmail = 'admin@fastkirana.in';

  // Darkstore Hub Coordinates (Ghatampur)
  static const double darkstoreLat = 26.1534185;
  static const double darkstoreLng = 80.1714024;
  static const String darkstoreAddress = 'Ghatampur Market, Kanpur Nagar, UP - 209206';

  // Admin Credentials
  static const String defaultAdminEmail = 'admin@fastkirana.in';
  static const String defaultAdminPassword = String.fromEnvironment(
    'ADMIN_PASSWORD',
    defaultValue: 'FastKirana@2026',
  );
}
