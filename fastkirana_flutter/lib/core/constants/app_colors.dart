import 'package:flutter/material.dart';

/// FastKirana Brand Colors synchronized with Web Design System tokens
class AppColors {
  // Brand Primary Palette (Web globals.css: #E20A22)
  static const Color primary = Color(0xFFE20A22); // FastKirana Core Red
  static const Color primaryDark = Color(0xFFB30013);
  static const Color primaryLight = Color(0xFFFF4D62);
  static const Color primaryBg = Color(0xFFFFF5F6);
  static const Color primaryTab = Color(0xFFF33B30); // Vibrant Nav Highlight

  // Gradient Colors
  static const Color gradientStart = Color(0xFFE8153A);
  static const Color gradientMiddle = Color(0xFFFF2D55);
  static const Color gradientEnd = Color(0xFFFF4742);

  // Accent & Semantic
  static const Color accent = Color(0xFF00B140); // Leaf Green (#00B140)
  static const Color accentLight = Color(0xFF3CC070);
  static const Color accentOrange = Color(0xFFF97316); // Cafe / Food Orange
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // Neutrals (Zinc & Slate Palette matching Tailwind)
  static const Color textPrimary = Color(0xFF1A1A2E); // Web Text Primary
  static const Color textSecondary = Color(0xFF6B7280); // Zinc / Gray 500
  static const Color textMuted = Color(0xFF9CA3AF); // Zinc / Gray 400

  static const Color background = Color(0xFFFAFAFA); // Zinc 50
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  static const Color border = Color(0xFFE5E7EB); // Border
  static const Color borderLight = Color(0xFFF3F4F6); // Border Light
}