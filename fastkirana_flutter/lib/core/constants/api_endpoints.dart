class ApiEndpoints {
  static const String baseUrl = 'https://fast-kirana-0ezx.onrender.com';

  static const String sendOtp = '$baseUrl/api/auth/otp/send';
  static const String verifyOtp = '$baseUrl/api/auth/otp/verify';
  static const String login = '$baseUrl/api/auth/login';
  static const String signup = '$baseUrl/api/auth/signup';
  static const String emailCheck = '$baseUrl/api/auth/email/check';

  static const String products = '$baseUrl/api/products';
  static const String categories = '$baseUrl/api/categories';
  static const String banners = '$baseUrl/api/banners';
  static const String restaurants = '$baseUrl/api/restaurants';

  static const String cart = '$baseUrl/api/cart';
  static const String validateCoupon = '$baseUrl/api/coupons/validate';

  static const String orders = '$baseUrl/api/orders';
  static const String createOrder = '$baseUrl/api/orders/create';

  static const String profile = '$baseUrl/api/profile';
  static const String addresses = '$baseUrl/api/addresses';
  static const String settings = '$baseUrl/api/settings';

  static const String search = '$baseUrl/api/search';
}