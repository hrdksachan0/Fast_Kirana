import 'package:fastminute_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';

/// FastKirana App-Wide Responsive Breakpoints & Helpers
class Responsive {
  /// Breakpoint constants
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1440.0;

  static const double defaultMaxContentWidth = 680.0;
  static const double wideMaxContentWidth = 840.0;
  static const double formMaxContentWidth = 520.0;

  /// Device Type Checks
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 360.0;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint;

  /// Dynamic Grid Columns based on screen width
  static int gridColumns(
    BuildContext context, {
    int smallMobile = 2,
    int mobile = 2,
    int smallTablet = 3,
    int tablet = 4,
    int desktop = 5,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return smallMobile;
    if (width < mobileBreakpoint) return mobile;
    if (width < 800) return smallTablet;
    if (width < tabletBreakpoint) return tablet;
    return desktop;
  }

  /// Dynamic Grid Aspect Ratio (height / width balance)
  static double gridAspectRatio(
    BuildContext context, {
    double smallMobile = 0.65,
    double mobile = 0.68,
    double tablet = 0.72,
    double desktop = 0.76,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return smallMobile;
    if (width < mobileBreakpoint) return mobile;
    if (width < tabletBreakpoint) return tablet;
    return desktop;
  }

  /// Responsive Horizontal Screen Padding
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 10.0;
    if (width < mobileBreakpoint) return 16.0;
    if (width < tabletBreakpoint) return 24.0;
    return 32.0;
  }

  /// Responsive Banner Height
  static double bannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 135.0;
    if (width < mobileBreakpoint) return 155.0;
    if (width < tabletBreakpoint) return 185.0;
    return 210.0;
  }

  /// Content Width clamped to maxWidth
  static double contentWidth(BuildContext context, {double maxWidth = defaultMaxContentWidth}) {
    final width = MediaQuery.of(context).size.width;
    return width > maxWidth ? maxWidth : width;
  }

  /// Dynamic Category Card Aspect Ratio (width / height)
  static double categoryCardAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 0.64;
    if (width < 400) return 0.67;
    if (width < mobileBreakpoint) return 0.69;
    if (width < tabletBreakpoint) return 0.74;
    return 0.78;
  }

  /// Dynamic Product Card Aspect Ratio (Universal Auto-Fit for Any Screen Size — Moto 360dp to Tablet)
  static double productCardAspectRatio(BuildContext context, {bool isCompact = false}) {
    final width = MediaQuery.of(context).size.width;
    if (isCompact) {
      // Used in screens with side category rail (narrower column ~125-155px)
      // Calibrated to cardWidth * 1.12 photo + price + full 3-line title (even at 1.15x font scale) + clean gap
      if (width < 360) return 0.485;
      if (width < 400) return 0.495;
      if (width < mobileBreakpoint) return 0.495;
      if (width < tabletBreakpoint) return 0.54;
      return 0.58;
    }
    // Full width 2-column grid (Search, Wishlist, Subcategory, Category without rail)
    // Calibrated to cardWidth * 1.12 photo + price + full 3-line title (even at 1.15x font scale) + clean gap
    if (width < 360) return 0.52;
    if (width < 400) return 0.525;
    if (width < mobileBreakpoint) return 0.535;
    if (width < tabletBreakpoint) return 0.58;
    return 0.62;
  }

  /// Unified Responsive Product Card Width for horizontal shelves
  /// Blinkit 2.65-card horizontal shelf layout (2 full bold cards + ~65% of 3rd card visible, big hero images)
  static double productCardShelfWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletBreakpoint) return 148.0;
    if (width >= mobileBreakpoint) return 138.0;

    // ~120px on narrow Moto (360dp) to ~130px on OnePlus (392dp) — 2 full cards + generous 3rd card
    final pad = horizontalPadding(context) * 2;
    return ((width - pad - 16.0) / 2.65).clamp(118.0, 134.0);
  }

  /// Unified Responsive Product Shelf Height for horizontal tracks (Compact & proportionate)
  /// Calibrated dynamically to taller 1.12x photo card + 3-line title to prevent bottom clipping on all Android devices
  static double productShelfHeight(BuildContext context, {bool isFood = false}) {
    final width = MediaQuery.of(context).size.width;
    final cardW = productCardShelfWidth(context);

    if (isFood) {
      if (width < 360) return 212.0;
      if (width < 400) return 218.0;
      if (width < mobileBreakpoint) return 226.0;
      if (width < tabletBreakpoint) return 236.0;
      return 244.0;
    }

    // Grocery card: Taller 1.12x Photo + Grey Box Weight Bar (29) + Overhang (15) + Spacing (4) + Price (18) + 3-line Title (up to 48)
    final dynamicHeight = (cardW * 1.12) + 109.0;
    return dynamicHeight.clamp(235.0, 264.0);
  }

  /// Responsive scaled font size with safety clamping
  static double scaledFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width > tabletBreakpoint) return baseSize * 1.1;
    // On small/narrow phones (e.g. Moto ~360dp), never degrade small labels below readable thresholds
    if (width < 360) {
      if (baseSize <= 13.0) return baseSize.clamp(11.0, baseSize);
      return (baseSize * 0.96).clamp(baseSize - 1.0, baseSize);
    }
    return baseSize;
  }

  /// Returns a scale factor (1.0–1.15) for the current screen width relative to a base phone width
  static double uiScale(BuildContext context, {double baseWidth = 375.0, double maxScale = 1.15}) {
    final width = MediaQuery.of(context).size.width;
    return (width / baseWidth).clamp(1.0, maxScale);
  }

  /// Scales any value proportionally to the screen width
  static double scale(BuildContext context, double value, {double baseWidth = 375.0, double maxScale = 1.15}) {
    return value * uiScale(context, baseWidth: baseWidth, maxScale: maxScale);
  }
}

/// Handy BuildContext extension for swift responsive checks
extension ResponsiveExtension on BuildContext {
  bool get isCompact => Responsive.isSmallMobile(this);
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  bool get isWide => Responsive.isWide(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  double get bottomPadding => MediaQuery.of(this).padding.bottom;
  double get topPadding => MediaQuery.of(this).padding.top;
  double get horizontalPadding => Responsive.horizontalPadding(this);
}

/// A clean, centered container widget that prevents UI elements from stretching
/// across giant screens on Tablets, iPads, Foldables, and Desktop Web.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final bool fillHeight;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Responsive.defaultMaxContentWidth,
    this.backgroundColor,
    this.padding,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: isWide
              ? BoxDecoration(
                  color: backgroundColor ?? Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : null,
          child: child,
        ),
      ),
    );

    if (isWide && fillHeight) {
      return Container(
        color: AppDesignSystem.slate100,
        alignment: Alignment.topCenter,
        child: content,
      );
    }

    return content;
  }
}
