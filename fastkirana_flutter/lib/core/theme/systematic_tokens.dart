import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_gutter/flutter_gutter.dart' hide Gap;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:forui/forui.dart';
import 'package:mix/mix.dart';

export 'package:gap/gap.dart';
export 'package:flutter_gutter/flutter_gutter.dart' hide Gap;
export 'package:shadcn_ui/shadcn_ui.dart';
export 'package:forui/forui.dart';
export 'package:mix/mix.dart';

/// Systematic FastKirana Spacing Tokens (Built on Gap & Gutter)
class AppGaps {
  AppGaps._();

  // Standard Spacing Units
  static const double xsVal = 4.0;
  static const double smVal = 8.0;
  static const double mdVal = 12.0;
  static const double lgVal = 16.0;
  static const double xlVal = 20.0;
  static const double xxlVal = 24.0;
  static const double xxxlVal = 32.0;

  // Flex-aware Gap Widgets (Replaces manual SizedBox)
  static const xs = Gap(xsVal);
  static const sm = Gap(smVal);
  static const md = Gap(mdVal);
  static const lg = Gap(lgVal);
  static const xl = Gap(xlVal);
  static const xxl = Gap(xxlVal);
  static const xxxl = Gap(xxxlVal);

  // Sliver Gaps for CustomScrollView Slivers
  static const sliverXs = SliverGap(xsVal);
  static const sliverSm = SliverGap(smVal);
  static const sliverMd = SliverGap(mdVal);
  static const sliverLg = SliverGap(lgVal);
  static const sliverXl = SliverGap(xlVal);
  static const sliverXxl = SliverGap(xxlVal);
  static const sliverXxxl = SliverGap(xxxlVal);
}

/// Systematic Edge Insets Helpers (Built on Flutter Gutter)
class AppGutters {
  AppGutters._();

  /// Standard Screen Insets (responsive)
  static EdgeInsets screen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    if (width < 600) return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    if (width < 900) return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
  }

  /// Horizontal Screen Insets
  static EdgeInsets screenHorizontal(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return const EdgeInsets.symmetric(horizontal: 10);
    if (width < 600) return const EdgeInsets.symmetric(horizontal: 16);
    if (width < 900) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 32);
  }

  /// Standard Card Internal Insets
  static const card = EdgeInsets.all(AppGaps.mdVal);
  static const cardSm = EdgeInsets.all(AppGaps.smVal);
  static const cardLg = EdgeInsets.all(AppGaps.lgVal);
}

/// Systematic Surface & Card Styling Tokens
class SystematicStyles {
  SystematicStyles._();

  /// Clean elevated white card
  static BoxDecoration get elevatedCard => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  /// Frosted glass surface
  static BoxDecoration get frostedSurface => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// Brand Primary Gradient Button Decoration
  static BoxDecoration get primaryGradient => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE20A22), Color(0xFFC0061A)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE20A22).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );

  /// Food Orange Gradient Decoration
  static BoxDecoration get foodGradient => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5200), Color(0xFFE04700)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5200).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
}
