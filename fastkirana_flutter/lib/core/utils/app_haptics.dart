import 'package:flutter/services.dart';

/// Centralized, smooth haptic engine for FastMinute.
/// Engineered to deliver silky-smooth, premium tactile feedback
/// (Swiggy / Zepto / Apple iOS standard) without harsh or erratic buzzing.
class AppHaptics {
  AppHaptics._();

  /// Smooth, crisp mechanical tick for stepper (+ and -) buttons.
  /// Dual-engine: triggers lightImpact() and fallback vibrate() to guarantee vibration across all Android OEM skins.
  static void smoothTick() {
    HapticFeedback.lightImpact();
    HapticFeedback.vibrate();
  }

  /// Satisfying, gentle confirmation pulse when user adds an item to cart (ADD button).
  static void smoothAdd() {
    HapticFeedback.mediumImpact();
    HapticFeedback.vibrate();
  }

  /// Refined alert pulse for max stock / restrictions.
  static void alertPulse() {
    HapticFeedback.heavyImpact();
  }

  /// Subtle touch feedback for general interactive elements.
  static void subtleTap() {
    HapticFeedback.lightImpact();
  }
}
