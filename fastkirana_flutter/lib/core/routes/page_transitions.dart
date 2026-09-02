import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FASTKIRANA ZEPTO & SWIGGY ULTRA-SMOOTH TRANSITION SYSTEM
/// Designed for 60/120 FPS high-refresh mobile & web quick-commerce experience.
/// ─────────────────────────────────────────────────────────────────────────────

/// 1. ZeptoSlideRoute:
/// Snappy horizontal slide with subtle parallax depth & spring easing.
/// Used for Products, Categories, Profile, Orders, and OTP drill-down screens.
class ZeptoSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration transitionDurationOverride;

  ZeptoSlideRoute({
    required this.page,
    super.settings,
    this.transitionDurationOverride = const Duration(milliseconds: 300),
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Forward animation (Entering Screen):
            // Apple/Zepto spring curve: Cubic(0.16, 1.0, 0.3, 1.0)
            const curve = Cubic(0.16, 1.0, 0.3, 1.0);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: Curves.easeInCubic,
            );

            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation);

            final fadeIn = Tween<double>(
              begin: 0.6,
              end: 1.0,
            ).animate(curvedAnimation);

            // Backward / Secondary animation (Screen underneath when pushing another):
            final secondaryCurved = CurvedAnimation(
              parent: secondaryAnimation,
              curve: curve,
              reverseCurve: Curves.easeInCubic,
            );

            final parallaxSlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.15, 0.0), // subtle 15% parallax shift
            ).animate(secondaryCurved);

            final scaleUnderlay = Tween<double>(
              begin: 1.0,
              end: 0.96, // subtle zoom out depth
            ).animate(secondaryCurved);

            return SlideTransition(
              position: parallaxSlide,
              child: ScaleTransition(
                scale: scaleUnderlay,
                child: SlideTransition(
                  position: slideIn,
                  child: FadeTransition(
                    opacity: fadeIn,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

/// 2. SwiggyModalRoute:
/// Smooth bottom-up sheet presentation with spring deceleration & slight scale.
/// Used for Cart, Checkout, Map Picker, Location, and Filter Modals.
class SwiggyModalRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration transitionDurationOverride;

  SwiggyModalRoute({
    required this.page,
    super.settings,
    this.transitionDurationOverride = const Duration(milliseconds: 320),
    super.maintainState = true,
    super.fullscreenDialog = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Cubic(0.12, 0.95, 0.25, 1.0);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: Curves.easeInCubic,
            );

            final slideUp = Tween<Offset>(
              begin: const Offset(0.0, 0.25),
              end: Offset.zero,
            ).animate(curvedAnimation);

            final scaleUp = Tween<double>(
              begin: 0.95,
              end: 1.0,
            ).animate(curvedAnimation);

            final fadeIn = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(curvedAnimation);

            return SlideTransition(
              position: slideUp,
              child: ScaleTransition(
                scale: scaleUp,
                child: FadeTransition(
                  opacity: fadeIn,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// 3. FadeThroughRoute:
/// Official Material FadeThrough transition for switching major navigation contexts,
/// loading screens, auth transitions, and dashboard swaps.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration transitionDurationOverride;

  FadeThroughRoute({
    required this.page,
    super.settings,
    this.transitionDurationOverride = const Duration(milliseconds: 300),
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 250),
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
    this.transitionDurationOverride = const Duration(milliseconds: 300),
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationOverride,
          reverseTransitionDuration: const Duration(milliseconds: 260),
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
/// Elastic fade & scale transition for Search overlay, quick-view modals, and dialogs.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScaleRoute({
    required this.page,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
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

/// Global PageTransitionsBuilder for ThemeData
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
    const curve = Cubic(0.16, 1.0, 0.3, 1.0);
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: Curves.easeInCubic,
    );

    final slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final fadeIn = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(curvedAnimation);

    return SlideTransition(
      position: slideIn,
      child: FadeTransition(
        opacity: fadeIn,
        child: child,
      ),
    );
  }
}
