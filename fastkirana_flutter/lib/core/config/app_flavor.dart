/// Application Flavors for FastKirana
///
/// Distinguishes between Customer Storefront and Delivery Rider / Staff editions.
enum AppFlavor {
  customer,
  rider,
}

class FlavorConfig {
  final AppFlavor flavor;
  final String appTitle;
  final String baseUrl;
  final bool isRiderEdition;

  static FlavorConfig? _instance;

  FlavorConfig._internal({
    required this.flavor,
    required this.appTitle,
    required this.baseUrl,
    required this.isRiderEdition,
  });

  static void initialize({
    required AppFlavor flavor,
    String? baseUrl,
  }) {
    _instance = FlavorConfig._internal(
      flavor: flavor,
      appTitle: flavor == AppFlavor.rider ? 'FastKirana Rider' : 'FastKirana',
      baseUrl: baseUrl ?? 'https://fastkirana.vercel.app',
      isRiderEdition: flavor == AppFlavor.rider,
    );
  }

  static FlavorConfig get instance {
    _instance ??= FlavorConfig._internal(
      flavor: AppFlavor.customer,
      appTitle: 'FastKirana',
      baseUrl: 'https://fastkirana.vercel.app',
      isRiderEdition: false,
    );
    return _instance!;
  }

  static bool get isRider => instance.isRiderEdition;
  static bool get isCustomer => !instance.isRiderEdition;
}
