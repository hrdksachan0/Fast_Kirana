import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'logger_service.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometric hardware and has enrolled fingerprints/face
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      LoggerService.error('[BiometricService] Availability check error: $e');
      return false;
    } catch (e) { LoggerService.error('BiometricService: silent catch', e);
      return false;
    }
  }

  /// Get list of available biometric types (fingerprint, face, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) { LoggerService.error('BiometricService: silent catch', e);
      return [];
    }
  }

  /// Authenticate user via fingerprint or Face ID
  static Future<bool> authenticate({
    required String reason,
    bool stickyAuth = true,
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        LoggerService.info('[BiometricService] Biometrics not available on this device');
        return true; // Graceful fallback if device doesn't have biometric hardware
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      LoggerService.error('[BiometricService] Authentication failed: ${e.message}');
      return false;
    } catch (e) {
      LoggerService.error('[BiometricService] Unexpected auth error: $e');
      return false;
    }
  }
}
