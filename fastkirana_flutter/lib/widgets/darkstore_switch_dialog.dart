import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ultra-premium, agency-grade micro-interstitial HUD dialog shown when
/// switching delivery locations or darkstores (Instamart / Zepto style).
/// Features a frosted backdrop blur, physics bouncing delivery bag with 'F' logo,
/// and clean typography with zero overflow.
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
        barrierColor: Colors.black.withValues(alpha: 0.45),
        routeSettings: const RouteSettings(name: 'darkstore_switch_hud'),
        builder: (_) => DarkstoreSwitchDialog(hubName: hubName, cityName: cityName),
      );
    } catch (_) {}
  }

  @override
  State<DarkstoreSwitchDialog> createState() => _DarkstoreSwitchDialogState();
}

class _DarkstoreSwitchDialogState extends State<DarkstoreSwitchDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _bounceAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.0, end: -12.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOutCubic),
    );

    _scaleAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );

    // Auto-dismiss after 900ms transition
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFFEE2E2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Darkstore Active Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECDD3), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE11D48),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DARKSTORE SWITCH',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Centerpiece: Bouncing Bag with Radar Ripple
                  SizedBox(
                    width: 110,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft Radar Pulse Circle
                        AnimatedBuilder(
                          animation: _animCtrl,
                          builder: (context, _) {
                            return Transform.scale(
                              scale: _pulseAnim.value,
                              child: Container(
                                width: 85,
                                height: 85,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE11D48).withValues(
                                    alpha: (0.18 - (_animCtrl.value * 0.12)).clamp(0.0, 1.0),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Ground Shadow
                        Positioned(
                          bottom: 4,
                          child: AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (context, _) {
                              return Container(
                                width: 68 * (1.1 - (_animCtrl.value * 0.2)),
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(
                                    alpha: (0.12 + (_animCtrl.value * 0.08)).clamp(0.0, 1.0),
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              );
                            },
                          ),
                        ),

                        // Bouncing Red Bag
                        AnimatedBuilder(
                          animation: _animCtrl,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(0, _bounceAnim.value),
                              child: Transform.scale(
                                scaleX: _scaleAnim.value,
                                scaleY: 2.0 - _scaleAnim.value,
                                child: _buildCompactBag(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Store Connection Title
                  Text(
                    'Connecting to $locationLabel Hub...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 4. Subtitle / Inventory check
                  Text(
                    'Checking live inventory & 10-min delivery slots',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Sleek Rounded Progress Bar
                  Container(
                    width: 130,
                    height: 4.5,
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
        ),
      ),
    );
  }

  /// Compact, beautifully detailed 3D delivery bag with peeking veggies & 'F' emblem
  Widget _buildCompactBag() {
    return SizedBox(
      width: 82,
      height: 80,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Peeking Greens & Fruit Tops
          Positioned(
            top: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banana curve
                Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    width: 8,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Apple top
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                // Carrot leaf
                Transform.rotate(
                  angle: 0.25,
                  child: Container(
                    width: 7,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                // Orange top
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Handle
          Positioned(
            top: 14,
            child: Container(
              width: 34,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF991B1B), width: 3.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),

          // Bag Body (Crimson Gradient)
          Positioned(
            bottom: 0,
            child: Container(
              width: 74,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE11D48), // Rose red
                    Color(0xFFBE123C), // Deep crimson
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                // FastMinute Speed 'F' badge
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'F',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFE11D48),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
