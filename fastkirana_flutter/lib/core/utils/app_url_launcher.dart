import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/logger_service.dart';

/// Robust, crash-proof URL and intent launcher for dialer, WhatsApp, and external links.
/// Prevents PlatformException crashes when dialer, WhatsApp, or browser activities are unavailable.
class AppUrlLauncher {
  AppUrlLauncher._();

  static Future<bool> launchSafely(
    Uri uri, {
    BuildContext? context,
    LaunchMode mode = LaunchMode.platformDefault,
    String? customErrorMessage,
  }) async {
    try {
      final scheme = uri.scheme.toLowerCase();

      // For dialer (tel:), map (geo:) or whatsapp, ALWAYS enforce LaunchMode.externalApplication!
      // Using LaunchMode.platformDefault on Android tries to embed/launch in current activity stack,
      // which freezes the Flutter engine and causes Android proximity sensor screen blackouts/crashes!
      final effectiveMode = (scheme == 'tel' || scheme == 'geo' || (scheme.startsWith('http') && uri.host.contains('wa.me')))
          ? LaunchMode.externalApplication
          : mode;

      // For dialer or WhatsApp, try launching with canLaunch check first
      final can = await canLaunchUrl(uri).catchError((_) => false);
      if (can) {
        return await launchUrl(uri, mode: effectiveMode);
      }

      // Fallback attempt: some Android devices report canLaunchUrl=false for tel/whatsapp but still launch
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;

      if (context != null && context.mounted) {
        _notifyFailure(context, scheme, customErrorMessage);
      }
      return false;
    } on PlatformException catch (e, stack) {
      LoggerService.error('AppUrlLauncher: PlatformException while launching $uri: ${e.message}', e, stack);
      if (context != null && context.mounted) {
        _notifyFailure(context, uri.scheme.toLowerCase(), customErrorMessage);
      }
      return false;
    } catch (e, stack) {
      LoggerService.error('AppUrlLauncher: Unexpected error while launching $uri', e, stack);
      if (context != null && context.mounted) {
        _notifyFailure(context, uri.scheme.toLowerCase(), customErrorMessage);
      }
      return false;
    }
  }

  static Future<bool> launchString(
    String urlString, {
    BuildContext? context,
    LaunchMode mode = LaunchMode.platformDefault,
    String? customErrorMessage,
  }) async {
    final trimmed = urlString.trim();
    if (trimmed.isEmpty) return false;

    // Auto-clean phone numbers to guarantee Android dialer compatibility
    String finalUrl = trimmed;
    if (finalUrl.toLowerCase().startsWith('tel:')) {
      final phonePart = finalUrl.substring(4).replaceAll(RegExp(r'[^0-9+]'), '');
      finalUrl = 'tel:$phonePart';
    }

    final uri = Uri.tryParse(finalUrl);
    if (uri == null) return false;
    return launchSafely(uri, context: context, mode: mode, customErrorMessage: customErrorMessage);
  }

  static void _notifyFailure(BuildContext? context, String scheme, String? customMessage) {
    if (context == null || !context.mounted) return;

    String msg = customMessage ?? 'Could not open action.';
    if (customMessage == null) {
      if (scheme == 'tel') {
        msg = 'Phone dialer is not available on this device.';
      } else if (scheme == 'mailto') {
        msg = 'No email application found.';
      } else if (scheme.startsWith('http') && scheme.contains('wa.me')) {
        msg = 'WhatsApp is not installed on this device.';
      } else {
        msg = 'Could not open link.';
      }
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
