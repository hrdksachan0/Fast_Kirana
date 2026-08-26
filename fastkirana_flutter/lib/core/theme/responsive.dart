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
                      color: Colors.black.withOpacity(0.04),
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
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.topCenter,
        child: content,
      );
    }

    return content;
  }
}
