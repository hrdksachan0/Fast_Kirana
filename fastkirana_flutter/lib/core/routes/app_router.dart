import 'package:flutter/material.dart';
import 'page_transitions.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/home/main_shell.dart';
import '../../features/products/products_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/auth/admin_login.dart';
import '../../features/auth/delivery_login.dart';
import '../../features/delivery/delivery_dashboard.dart';
import '../../features/location/delivery_location_screen.dart';
import '../../features/location/map_picker_screen.dart';
import '../../features/cafe/restaurant_delivery_loading_screen.dart';
import '../../features/splash/grocery_delivery_loading_screen.dart';
import '../theme/design_system.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/home':
      case '/main':
        return FadeSlideRoute(page: const MainShell());
      case '/location':
        return FadeSlideRoute(page: const DeliveryLocationScreen());
      case '/map-picker':
        return FadeSlideRoute(page: const MapPickerScreen());
      case '/login':
        return FadeSlideRoute(page: const LoginScreen());
      case '/admin':
      case '/admin/login':
        return FadeSlideRoute(page: const AdminLoginScreen());
      case '/delivery':
      case '/delivery/dashboard':
        return FadeSlideRoute(page: const DeliveryDashboard());
      case '/delivery/login':
        return FadeSlideRoute(page: const DeliveryLoginScreen());
      case '/otp':
        final identifier = (settings.arguments as String?) ?? '';
        return FadeSlideRoute(page: OtpScreen(identifier: identifier));
      case '/products':
        return FadeSlideRoute(page: const ProductsScreen());
      case '/categories':
        return FadeSlideRoute(page: const CategoriesScreen());
      case '/cart':
        return FadeSlideRoute(page: const CartScreen());
      case '/checkout':
        return FadeSlideRoute(page: const CheckoutScreen());
      case '/orders':
        return FadeSlideRoute(page: const OrdersScreen());
      case '/profile':
        return FadeSlideRoute(page: const ProfileScreen());
      case '/search':
        return FadeSlideRoute(page: const SearchScreen());
      case '/restaurant-loading':
      case '/food-loading':
        return FadeSlideRoute(page: const RestaurantDeliveryLoadingScreen());
      case '/grocery-loading':
      case '/store-loading':
        return FadeSlideRoute(page: const GroceryDeliveryLoadingScreen());
      default:
        return FadeSlideRoute(
          page: Scaffold(
            body: Center(
              child: Text(
                'Route not found: ${settings.name}',
                style: const TextStyle(color: AppDesignSystem.danger),
              ),
            ),
          ),
        );
    }
  }
}