import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/app_config.dart';
import '../core/theme/design_system.dart';
import '../data/models/store_settings.dart';
import '../providers/store_settings_provider.dart';

class AppUpdateDialog extends StatelessWidget {
  final String targetVersion;
  final String updateUrl;
  final String message;
  final bool isForced;

  const AppUpdateDialog({
    super.key,
    required this.targetVersion,
    required this.updateUrl,
    required this.message,
    required this.isForced,
  });

  static bool _hasPromptedThisSession = false;

  /// Check settings and display update popup if current app version is outdated
  static Future<void> checkAndShow(BuildContext context, WidgetRef ref) async {
    StoreSettings? settings = ref.read(storeSettingsProvider).valueOrNull;
    if (settings == null) {
      try {
        settings = await ref.read(storeSettingsProvider.future);
      } catch (e) {
        return;
      }
    }
    if (settings == null) return;
    final activeSettings = settings;

    const currentVer = AppConfig.appVersion;
    final minVer = activeSettings.minAppVersion;
    final latestVer = activeSettings.latestAppVersion;

    final bool isBelowMin = AppConfig.isVersionLower(currentVer, minVer);
    final bool isBelowLatest = AppConfig.isVersionLower(currentVer, latestVer);

    if (!isBelowMin && !isBelowLatest) {
      return; // Up to date!
    }

    final bool isForced = isBelowMin || activeSettings.appForceUpdate;

    // For soft updates, only prompt once per app launch session
    if (!isForced && _hasPromptedThisSession) {
      return;
    }

    _hasPromptedThisSession = true;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (ctx) => PopScope(
        canPop: !isForced,
        child: AppUpdateDialog(
          targetVersion: isBelowLatest ? latestVer : minVer,
          updateUrl: activeSettings.appUpdateUrl,
          message: activeSettings.appUpdateMessage,
          isForced: isForced,
        ),
      ),
    );
  }

  Future<void> _handleUpdate(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final cleanUrl = updateUrl.trim();
    if (cleanUrl.isEmpty) return;

    final uri = Uri.tryParse(cleanUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('AppUpdateDialog: Failed to launch $cleanUrl: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. TOP BADGE WITH PULSE / ROCKET
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isForced ? AppDesignSystem.rose50 : AppDesignSystem.orange50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isForced ? AppDesignSystem.rose200 : AppDesignSystem.orange200,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isForced ? AppDesignSystem.rose500 : AppDesignSystem.orange500).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isForced ? Icons.system_security_update_rounded : Icons.rocket_launch_rounded,
                  size: 32,
                  color: isForced ? AppDesignSystem.rose600 : AppDesignSystem.orange600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. TITLE
            Text(
              isForced ? 'Update Required' : 'New Update Available! 🚀',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 19),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // 3. VERSION TRANSITION CHIP
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'v${AppConfig.appVersion}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.slate500,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppDesignSystem.slate400),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.green50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppDesignSystem.green200),
                    ),
                    child: Text(
                      'v$targetVersion',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.green700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. MESSAGE / RELEASE NOTES
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.slate100),
              ),
              child: Text(
                message.trim().isNotEmpty
                    ? message.trim()
                    : 'A faster, smoother version of FastKirana is ready for you with important performance improvements.',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate700,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // 5. PRIMARY BUTTON: UPDATE NOW
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.orange600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _handleUpdate(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Download & Update Now',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. DISMISS / LATER BUTTON (ONLY IF NOT FORCED)
            if (!isForced) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  child: Text(
                    'Remind Me Later',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.slate500,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'Please update to continue ordering on FastKirana',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.rose600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
