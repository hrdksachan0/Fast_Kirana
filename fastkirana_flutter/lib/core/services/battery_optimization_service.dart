import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationService {
  static const String _prefKeyDismissed = 'battery_optimization_prompt_dismissed_v1';

  /// Check if the prompt should be shown (only on Android, and if not permanently dismissed)
  static Future<bool> shouldShowPrompt() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return false;

      final prefs = await SharedPreferences.getInstance();
      final isDismissed = prefs.getBool(_prefKeyDismissed) ?? false;
      return !isDismissed;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] check error: $e');
      return false;
    }
  }

  /// Request battery optimization exemption directly via Android system dialog
  static Future<bool> requestExemption() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) return true;

      // Fallback: Open app battery / settings page
      await openAppSettings();
      return false;
    } catch (e) {
      debugPrint('[BatteryOptimizationService] request error: $e');
      try {
        await openAppSettings();
      } catch (_) {}
      return false;
    }
  }

  /// Mark the prompt as dismissed or already configured
  static Future<void> markDismissed({bool permanent = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDismissed, permanent);
    } catch (_) {}
  }
}
