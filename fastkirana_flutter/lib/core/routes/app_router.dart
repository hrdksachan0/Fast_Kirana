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
import '../../features/cafe/restaurant_dashboard.dart';
import '../widgets/contextual_brand_transition_screen.dart';
import '../theme/design_system.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/home':
      case '/main':
        return FadeThroughRoute(page: const MainShell());
      case '/location':
        final autoFetch = (settings.arguments as bool?) ?? false;
        return SwiggyModalRoute(page: DeliveryLocationScreen(autoFetchLocation: autoFetch));
      case '/map-picker':
        return SwiggyModalRoute(page: const MapPickerScreen());
      case '/login':
        return ZeptoSlideRoute(page: const LoginScreen());
      case '/admin':
      case '/admin/login':
        return ZeptoSlideRoute(page: const AdminLoginScreen());
      case '/delivery':
      case '/delivery/dashboard':
        return FadeThroughRoute(page: const DeliveryDashboard());
      case '/delivery/login':
        return ZeptoSlideRoute(page: const DeliveryLoginScreen());
      case '/restaurant':
      case '/restaurant/dashboard':
      case '/kitchen':
        return FadeThroughRoute(page: const RestaurantDashboard());
      case '/otp':
        final identifier = (settings.arguments as String?) ?? '';
        return ZeptoSlideRoute(page: OtpScreen(identifier: identifier));
      case '/products':
        return ZeptoSlideRoute(page: const ProductsScreen());
      case '/categories':
        return ZeptoSlideRoute(page: const CategoriesScreen());
      case '/cart':
        return SwiggyModalRoute(page: const CartScreen());
      case '/checkout':
        return SwiggyModalRoute(page: const CheckoutScreen());
      case '/orders':
        return ZeptoSlideRoute(page: const OrdersScreen());
      case '/profile':
        return ZeptoSlideRoute(page: const ProfileScreen());
      case '/search':
        return FadeScaleRoute(page: const SearchScreen());
      case '/restaurant-loading':
      case '/food-loading':
      case '/cafe-loading':
        return FadeThroughRoute(
          page: ContextualBrandTransitionScreen(
            contextType: TransitionContextType.cafe,
            autoDismissDuration: const Duration(milliseconds: 1300),
            onFinished: () {
              AppRouter.navigatorKey.currentState?.pushReplacementNamed('/home');
            },
          ),
        );
      case '/grocery-loading':
      case '/store-loading':
        return FadeThroughRoute(
          page: ContextualBrandTransitionScreen(
            contextType: TransitionContextType.grocery,
            autoDismissDuration: const Duration(milliseconds: 1300),
            onFinished: () {
              AppRouter.navigatorKey.currentState?.pushReplacementNamed('/home');
            },
          ),
        );
      case '/essentials-loading':
      case '/quick-loading':
        return FadeThroughRoute(
          page: ContextualBrandTransitionScreen(
            contextType: TransitionContextType.essentials,
            autoDismissDuration: const Duration(milliseconds: 1300),
            onFinished: () {
              AppRouter.navigatorKey.currentState?.pushReplacementNamed('/home');
            },
          ),
        );
      case '/checkout-loading':
        return FadeThroughRoute(
          page: ContextualBrandTransitionScreen(
            contextType: TransitionContextType.checkout,
            autoDismissDuration: const Duration(milliseconds: 1300),
            onFinished: () {
              AppRouter.navigatorKey.currentState?.pushReplacementNamed('/orders');
            },
          ),
        );
      case '/locator-loading':
        return FadeThroughRoute(
          page: ContextualBrandTransitionScreen(
            contextType: TransitionContextType.storeFinder,
            autoDismissDuration: const Duration(milliseconds: 1300),
            onFinished: () {
              AppRouter.navigatorKey.currentState?.pushReplacementNamed('/home');
            },
          ),
        );
      default:
        return FadeThroughRoute(
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