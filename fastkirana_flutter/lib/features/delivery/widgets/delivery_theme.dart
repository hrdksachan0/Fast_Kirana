import 'package:flutter/material.dart';

/// Dynamic light/dark theme colors used across the delivery dashboard.
/// Centralized here so extracted widgets (header, banner, tabs, cards) all
/// pull from one source.
class DeliveryTheme {
  final bool isDarkMode;

  const DeliveryTheme({this.isDarkMode = false});

  static const Color emeraldGreen = Color(0xFF00965E);
  static const Color emeraldDark = Color(0xFF045D38);
  static const Color emeraldShadow = Color(0xFF02462A);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color slateSurface = Color(0xFFF8FAFC);

  Color get bgMain => isDarkMode ? const Color(0xFF0A0F1D) : slateSurface;
  Color get cardBg => isDarkMode ? const Color(0xFF131C2E) : Colors.white;
  Color get cardSubtle => isDarkMode ? const Color(0xFF1A263D) : slateSurface;
  Color get borderCol => isDarkMode ? const Color(0xFF23324D) : slateBorder;
  Color get textMain => isDarkMode ? const Color(0xFFF1F5F9) : slateDark;
  Color get textMuted => isDarkMode ? const Color(0xFF94A3B8) : slateMuted;
}