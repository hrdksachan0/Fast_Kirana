import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';

/// Dynamic light/dark theme colors used across the delivery dashboard.
/// Centralized here so extracted widgets (header, banner, tabs, cards) all
/// pull from one source.
class DeliveryTheme {
  final bool isDarkMode;

  const DeliveryTheme({this.isDarkMode = false});

  static const Color emeraldGreen = AppDesignSystem.emeraldBrand;
  static const Color emeraldDark = AppDesignSystem.emeraldDark;
  static const Color emeraldShadow = AppDesignSystem.emeraldShadow;
  static const Color brandGreen = AppDesignSystem.success;
  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;
  static const Color slateSurface = AppDesignSystem.slate50;

  Color get bgMain => isDarkMode ? AppDesignSystem.darkNavy : slateSurface;
  Color get cardBg => isDarkMode ? AppDesignSystem.darkNavyCard : Colors.white;
  Color get cardSubtle => isDarkMode ? AppDesignSystem.darkNavySubtle : slateSurface;
  Color get borderCol => isDarkMode ? AppDesignSystem.darkNavyBorder : slateBorder;
  Color get textMain => isDarkMode ? AppDesignSystem.slate100 : slateDark;
  Color get textMuted => isDarkMode ? AppDesignSystem.slate400 : slateMuted;
}