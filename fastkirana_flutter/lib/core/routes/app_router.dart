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
import '../../features/checkout/order_success_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_tracking_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/auth/admin_login.dart';
import '../../features/auth/delivery_login.dart';
import '../../features/auth/vendor_login.dart';
import '../../features/admin/vendor_console_screen.dart';
import '../../features/delivery/delivery_dashboard.dart';
import '../../features/location/delivery_location_screen.dart';
import '../../features/location/map_picker_screen.dart';
import '../../features/cafe/restaurant_dashboard.dart';
import '../widgets/contextual_brand_transition_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final rawRoute = settings.name ?? '';
    final uri = Uri.tryParse(rawRoute);
    final cleanPath = uri?.path ?? rawRoute;

    // Handle deep links like /order/<id>/success or /orders/<id>/success
    final orderSuccessMatch = RegExp(r'^/(?:orders?)/([^/]+)/success/?$').firstMatch(cleanPath);
    if (orderSuccessMatch != null) {
      final orderId = orderSuccessMatch.group(1) ?? '';
      if (orderId.isNotEmpty && orderId != 'success') {
        return FadeSlideRoute(page: OrderSuccessScreen(orderId: orderId));
      }
    }

    // Handle deep links like /order/<id>/track or /orders/<id>/track
    final orderTrackMatch = RegExp(r'^/(?:orders?)/([^/]+)/track/?$').firstMatch(cleanPath);
    if (orderTrackMatch != null) {
      final orderId = orderTrackMatch.group(1) ?? '';
      if (orderId.isNotEmpty && orderId != 'track') {
        return FadeSlideRoute(page: OrderTrackingScreen(orderId: orderId));
      }
    }

    // Handle deep links like /order/<id> or /orders/<id>
    final orderDetailMatch = RegExp(r'^/(?:orders?)/([^/]+)/?$').firstMatch(cleanPath);
    if (orderDetailMatch != null) {
      final orderId = orderDetailMatch.group(1) ?? '';
      if (orderId.isNotEmpty && orderId != 'track' && orderId != 'success') {
        return FadeSlideRoute(page: OrderTrackingScreen(orderId: orderId));
      }
    }

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
      case '/vendor':
      case '/vendor/login':
      case '/staff':
      case '/staff/login':
        return ZeptoSlideRoute(page: const VendorLoginScreen());
      case '/vendor/console':
      case '/vendor/dashboard':
        final args = settings.arguments as Map<String, dynamic>?;
        final vId = args?['vendorId'] as String?;
        return FadeThroughRoute(
          page: VendorConsoleScreen(
            initialVendorId: vId,
            isVendorSelf: true,
          ),
        );
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
      case '/order/track':
      case '/orders/track':
      case '/order-track':
      case '/order-tracking':
        final orderId = (settings.arguments as String?) ?? '';
        return FadeSlideRoute(page: OrderTrackingScreen(orderId: orderId));
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
        debugPrint('[AppRouter] Unrecognized route: ${settings.name}, falling back to MainShell');
        return FadeThroughRoute(page: const MainShell());
    }
  }
}