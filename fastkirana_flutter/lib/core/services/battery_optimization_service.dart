
class BatteryOptimizationService {
  /// Returns true (no-op, disabled).
  static Future<bool> isIgnoringBatteryOptimizations() async => true;

  /// No-op, disabled.
  static Future<bool> requestIgnoreBatteryOptimizations() async => true;

  /// No-op, disabled.
  static Future<bool> ensureExempt() async => true;
}
