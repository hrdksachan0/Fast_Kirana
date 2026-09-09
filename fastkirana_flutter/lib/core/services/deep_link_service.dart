import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:fastkirana_flutter/core/routes/app_router.dart';
import 'package:fastkirana_flutter/core/services/logger_service.dart';

/// Service to handle universal app links and custom scheme deep links
/// Supports:
/// - fastkirana://order/{id}
/// - fastkirana://product/{slug}
/// - https://fastkirana.in/order/{id}
/// - https://fastkirana.in/orders/{id}
/// - https://www.fastkirana.in/order/{id}
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;

  /// Initialize deep link listener. Call this once during app startup.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Handle incoming links when the app is already running (foreground or background)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        LoggerService.info('DeepLink received (stream): $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        LoggerService.error('DeepLink stream error: $err');
      },
    );

    // 2. Handle cold launch link (when app is launched from a link while terminated)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        LoggerService.info('DeepLink received (initial): $initialUri');
        // Give Navigator a moment to attach before pushing route
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      LoggerService.error('DeepLink initial link error: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _isInitialized = false;
  }

  /// Parse incoming URI and navigate to the matching screen
  void _handleDeepLink(Uri uri) {
    try {
      final scheme = uri.scheme.toLowerCase();
      final host = uri.host.toLowerCase();
      final pathSegments = uri.pathSegments;

      LoggerService.info('Parsing deep link: scheme=$scheme, host=$host, path=$pathSegments');

      // ─── Case 1: Custom Scheme (fastkirana://order/123 or fastkirana://product/milk) ───
      if (scheme == 'fastkirana') {
        if (host == 'order' || host == 'orders') {
          final orderId = pathSegments.isNotEmpty ? pathSegments.first : uri.queryParameters['id'];
          if (orderId != null && orderId.isNotEmpty) {
            _navigateToOrder(orderId);
            return;
          }
        }
        if (host == 'product') {
          final slug = pathSegments.isNotEmpty ? pathSegments.first : uri.queryParameters['slug'];
          if (slug != null && slug.isNotEmpty) {
            _navigateToProducts();
            return;
          }
        }
      }

      // ─── Case 2: Universal HTTPS Links (https://fastkirana.in/order/123) ───
      if (scheme == 'https' || scheme == 'http') {
        if (host.contains('fastkirana.in')) {
          if (pathSegments.isNotEmpty) {
            final firstSegment = pathSegments[0].toLowerCase();

            // Order tracking: /order/{id} or /orders/{id}
            if ((firstSegment == 'order' || firstSegment == 'orders') && pathSegments.length >= 2) {
              final orderId = pathSegments[1];
              if (orderId.isNotEmpty) {
                _navigateToOrder(orderId);
                return;
              }
            }

            // Product listing / detail: /product/{slug} or /products
            if (firstSegment == 'product' || firstSegment == 'products') {
              _navigateToProducts();
              return;
            }

            // Cart: /cart
            if (firstSegment == 'cart') {
              AppRouter.navigatorKey.currentState?.pushNamed('/cart');
              return;
            }
          }
        }
      }
    } catch (e) {
      LoggerService.error('Error handling deep link: $e');
    }
  }

  void _navigateToOrder(String orderId) {
    LoggerService.info('DeepLink navigating to order: $orderId');
    final nav = AppRouter.navigatorKey.currentState;
    if (nav == null) {
      LoggerService.error('DeepLink: Navigator state is null');
      return;
    }
    nav.pushNamed('/orders/track', arguments: orderId);
  }

  void _navigateToProducts() {
    LoggerService.info('DeepLink navigating to products');
    final nav = AppRouter.navigatorKey.currentState;
    nav?.pushNamed('/products');
  }
}
