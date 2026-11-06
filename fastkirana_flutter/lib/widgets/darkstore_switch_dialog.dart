import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/splash/widgets/blinkit_animated_bag.dart';

/// Ultra-slick, 900ms micro-interstitial HUD dialog shown when switching delivery locations or darkstores.
/// Provides immediate, reassuring feedback that local darkstore inventory is being reloaded.
class DarkstoreSwitchDialog extends StatefulWidget {
  final String? hubName;
  final String? cityName;

  const DarkstoreSwitchDialog({
    super.key,
    this.hubName,
    this.cityName,
  });

  /// Static helper to trigger the darkstore switch transition dialog
  static Future<void> show(
    BuildContext context, {
    String? hubName,
    String? cityName,
    int durationMs = 850,
  }) async {
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        routeSettings: const RouteSettings(name: 'darkstore_switch_hud'),
        builder: (_) => DarkstoreSwitchDialog(hubName: hubName, cityName: cityName),
      );
    } catch (_) {}
  }

  @override
  State<DarkstoreSwitchDialog> createState() => _DarkstoreSwitchDialogState();
}

class _DarkstoreSwitchDialogState extends State<DarkstoreSwitchDialog> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 850ms
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = widget.cityName?.trim().isNotEmpty == true
        ? widget.cityName!.trim()
        : widget.hubName?.trim().isNotEmpty == true
            ? widget.hubName!.trim()
            : 'Nearest';

    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Darkstore Active Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFE11D48)),
                    const SizedBox(width: 4),
                    Text(
                      'DARKSTORE SWITCH',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: const Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Animated Bag Centerpiece
              SizedBox(
                height: 170,
                child: BlinkitAnimatedBag(
                  title: 'Connecting to $locationLabel Hub...',
                  subtitle: 'Checking live inventory & partner availability',
                ),
              ),

              const SizedBox(height: 8),

              // 3. Shimmer Progress Indicator Bar
              Container(
                width: 140,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE11D48)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
