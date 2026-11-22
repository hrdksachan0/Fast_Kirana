import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FASTMINUTE ZEPTO & BLINKIT ULTRA-SMOOTH TRANSITION SYSTEM
/// Designed for 60/120 FPS high-refresh mobile & web quick-commerce experience.
/// Single-pass GPU transforms + native interactive edge-swipe gesture.
/// ─────────────────────────────────────────────────────────────────────────────

/// 1. ZeptoSlideRoute:
/// Ultra-snappy horizontal slide with Apple/Zepto physics and native edge swipe-back.
/// Used for Products, Categories, Profile, Orders, and OTP drill-down screens.
class ZeptoSlideRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  final Widget page;
  final Duration transitionDurationOverride;
  final Duration reverseDurationOverride;

  ZeptoSlideRoute({
    required this.page,
    super.settings,
    this.transitionDurationOverride = const Duration(milliseconds: 250),
    this.reverseDurationOverride = const Duration(milliseconds: 200),
    super.fullscreenDialog = false,
  });

  @override
  Widget buildContent(BuildContext context) => page;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => transitionDurationOverride;

  @override
  Duration get reverseTransitionDuration => reverseDurationOverride;
}

/// 2. SwiggyModalRoute:
/// Smooth bottom-up sheet presentation with deceleration curve and shadow depth.
/// Used for Cart, Checkout, Map Picker, Location, and Filter Modals.
class SwiggyModalRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration transitionDurationOverride;

  SwiggyModalRoute({
    required this.page,
    super.settings,
    this.transitionDurationOverride = const Duration(milliseconds: 280),
    super.maintainState = true,
    super.fullscreenDialog = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Cubic(0.18, 0.9, 0.22, 1.0);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: Curves.easeInCubic,
            );

            final slideUp = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curvedAnimation);

            return SlideTransition(
              position: slideUp,
              child: child,
            );
          },
        );
}

/// 3. FadeThroughRoute:
/// Snappy Material FadeThrough transition for switching major navigation contexts,
/// loading screens, auth transitions, and dashboard swaps.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration transitionDurationOverride;

  FadeThroughRoute({
    required this.page,
    super.settings,
    this.transitionDurationOverride = const Duration(milliseconds: 240),
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );
}

/// 4. SharedAxisRoute:
/// Material SharedAxis transition (Horizontal or Vertical axis).
/// Gives seamless continuity between parent-child or peer catalogs.
class SharedAxisRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SharedAxisTransitionType transitionType;
  final Duration transitionDurationOverride;

  SharedAxisRoute({
    required this.page,
    this.transitionType = SharedAxisTransitionType.horizontal,
    this.transitionDurationOverride = const Duration(milliseconds: 240),
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: transitionType,
              child: child,
            );
          },
        );
}

/// 5. FadeScaleRoute:
/// Snappy fade & scale transition for Search overlay, quick-view modals, and dialogs.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScaleRoute({
    required this.page,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeScaleTransition(
              animation: animation,
              child: child,
            );
          },
        );
}

/// Backward-compatible alias for existing code referencing FadeSlideRoute
class FadeSlideRoute<T> extends ZeptoSlideRoute<T> {
  FadeSlideRoute({required super.page, super.settings});
}

/// Global PageTransitionsBuilder for ThemeData ensuring iOS & Android edge swipe-back
class FastKiranaPageTransitionsBuilder extends PageTransitionsBuilder {
  const FastKiranaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const CupertinoPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
