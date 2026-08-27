import 'dart:io';
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const _channel = MethodChannel('com.fastkirana.app/battery');

  static bool get _isAndroid => Platform.isAndroid;

  /// Returns true if the app is already exempt from battery optimizations.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Launches the system dialog asking the user to exempt FastKirana
  /// from battery optimizations.  Returns true if the dialog was shown.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Checks status and prompts the user once if optimization is active.
  /// Returns true if the app is now exempt (or already was).
  static Future<bool> ensureExempt() async {
    if (!_isAndroid) return true;
    final exempt = await isIgnoringBatteryOptimizations();
    if (exempt) return true;
    return await requestIgnoreBatteryOptimizations();
  }
}
