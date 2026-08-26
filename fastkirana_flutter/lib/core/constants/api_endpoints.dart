import '../config/app_config.dart';

class ApiEndpoints {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static String get sendOtp => '$baseUrl/api/auth/otp/send';
  static String get verifyOtp => '$baseUrl/api/auth/otp/verify';
  static String get login => '$baseUrl/api/auth/login';
  static String get signup => '$baseUrl/api/auth/signup';
  static String get emailCheck => '$baseUrl/api/auth/email/check';

  static String get products => '$baseUrl/api/products';
  static String get categories => '$baseUrl/api/categories';
  static String get banners => '$baseUrl/api/banners';
  static String get restaurants => '$baseUrl/api/restaurants';

  static String get cart => '$baseUrl/api/cart';
  static String get validateCoupon => '$baseUrl/api/coupons/validate';

  static String get orders => '$baseUrl/api/orders';
  static String get createOrder => '$baseUrl/api/orders';

  static String get profile => '$baseUrl/api/profile';
  static String get addresses => '$baseUrl/api/addresses';
  static String get settings => '$baseUrl/api/settings';

  static String get search => '$baseUrl/api/search';
}