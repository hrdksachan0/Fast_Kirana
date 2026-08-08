import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/home/main_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/products/product_detail_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/categories/category_products_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../theme/design_system.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/home':
      case '/main':
        return MaterialPageRoute(builder: (_) => const MainShell());
      case '/otp':
        final identifier = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => OtpScreen(identifier: identifier));
      case '/products':
        return MaterialPageRoute(builder: (_) => const ProductsScreen());
      case '/categories':
        return MaterialPageRoute(builder: (_) => const CategoriesScreen());
      case '/cart':
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case '/checkout':
        return MaterialPageRoute(builder: (_) => const CheckoutScreen());
      case '/orders':
        return MaterialPageRoute(builder: (_) => const OrdersScreen());
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case '/search':
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
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