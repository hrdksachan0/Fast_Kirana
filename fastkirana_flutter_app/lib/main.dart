import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/account_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/search_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'models/product.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload cached network image for smoother performance
  CachedNetworkImage.logLevel = CacheManagerLogLevel.none;

  runApp(const FastkiranaApp());
}

class FastkiranaApp extends StatelessWidget {
  const FastkiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()..loadCart()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'FastKirana',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => const HomeScreen());

                case '/product':
                  final product = settings.arguments as Product;
                  return MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  );

                case '/cart':
                  return MaterialPageRoute(builder: (_) => const CartScreen());

                case '/checkout':
                  return MaterialPageRoute(
                    builder: (_) => const CheckoutScreen(),
                  );

                case '/orders':
                  return MaterialPageRoute(builder: (_) => const OrdersScreen());

                case '/order-tracking':
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(
                      orderId: args['orderId'] as String,
                      readableId: args['readableId'] as String?,
                    ),
                  );

                case '/account':
                  return MaterialPageRoute(builder: (_) => const AccountScreen());

                case '/categories':
                  return MaterialPageRoute(
                    builder: (_) => const CategoriesScreen(),
                  );

                case '/search':
                  return MaterialPageRoute(builder: (_) => const SearchScreen());

                default:
                  return MaterialPageRoute(builder: (_) => const HomeScreen());
              }
            },
          );
        },
      ),
    );
  }
}
