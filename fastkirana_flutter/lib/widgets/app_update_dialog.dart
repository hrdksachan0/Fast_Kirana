import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/app_config.dart';
import '../data/models/store_settings.dart';
import '../providers/store_settings_provider.dart';

/// Blinkit-style Mandatory Force Update Bottom Sheet (Option 1).
///
/// Only blocks the app when `isBelowMin || appForceUpdate` is true.
/// Optional / soft updates NEVER interrupt the user with popups — instead they
/// appear quietly at the bottom of the Account (Profile) screen.
class AppUpdateDialog extends StatefulWidget {
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

  /// Check settings and display the bottom sheet ONLY for mandatory Force Updates.
  /// Soft updates are handled silently via the Account/Profile screen bottom card.
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

    final currentVer = AppConfig.appVersion;
    final minVer = activeSettings.minAppVersion;
    final latestVer = activeSettings.latestAppVersion;

    final bool isBelowMin = AppConfig.isVersionLower(currentVer, minVer);
    final bool isBelowLatest = AppConfig.isVersionLower(currentVer, latestVer);

    if (!isBelowMin && !isBelowLatest) {
      return; // Up to date!
    }

    // Only interrupt with a blocking sheet when update is genuinely forced.
    final bool isForced = isBelowMin || activeSettings.appForceUpdate;
    if (!isForced) {
      return; // Quietly shown in Account/Profile bottom banner instead of nagging popup
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (ctx) => PopScope(
        canPop: false,
        child: AppUpdateDialog(
          targetVersion: isBelowLatest ? latestVer : minVer,
          updateUrl: activeSettings.appUpdateUrl,
          message: activeSettings.appUpdateMessage,
          isForced: true,
        ),
      ),
    );
  }

  /// Helper to open Play Store / Update URL cleanly (shared by Account quiet update card)
  static Future<void> launchUpdateUrl(String updateUrl) async {
    HapticFeedback.heavyImpact();
    final cleanUrl = updateUrl.trim().isNotEmpty
        ? updateUrl.trim()
        : 'https://play.google.com/store/apps/details?id=com.fastminute.app';
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
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final customMsg = widget.message.trim();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          // 1. Zepto × FastMinute Brand-Red Hero Card with Floating Icon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final dy = -4.5 * (1.0 - (2 * _pulseController.value - 1).abs());
                    return Transform.translate(offset: Offset(0, dy), child: child);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE20A22), Color(0xFFC8081E)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x45E20A22),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'New Version Ready!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF881337),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Text(
                    'v${AppConfig.appVersion}  →  v${widget.targetVersion} · Faster & Smoother',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFBE123C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Crisp Release Note / Description
          Text(
            customMsg.isNotEmpty
                ? customMsg
                : 'Update FastMinute to get live rider map tracking, smoother UPI payments, and instant 0ms menu browsing.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
              height: 1.48,
            ),
          ),
          const SizedBox(height: 18),

          // 3. Zepto × FastMinute Brand Red (#E20A22) Glossy Sheen CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE20A22), Color(0xFFC8081E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4DE20A22),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => AppUpdateDialog.launchUpdateUrl(widget.updateUrl),
                    child: Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _sheenController,
                          builder: (context, _) {
                            final p = _sheenController.value;
                            final x = p < 0.45 ? -1.4 + (p / 0.45) * 3.0 : 2.0;
                            return Positioned.fill(
                              child: IgnorePointer(
                                child: FractionalTranslation(
                                  translation: Offset(x, 0),
                                  child: Container(
                                    width: 90,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.25),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Update Now (Play Store)',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_right_rounded, color: Colors.white, size: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Required to continue placing orders · Cart stays safe',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFBE123C),
            ),
          ),
        ],
      ),
    );
  }
}
