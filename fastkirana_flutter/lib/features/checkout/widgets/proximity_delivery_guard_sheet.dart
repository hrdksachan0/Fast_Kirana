import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/address.dart';

enum ProximityGuardAction {
  continueWithAddress,
  switchToCurrentLocation,
  orderForSomeoneElse,
}

/// Blinkit-Style Proximity Location Verification Bottom Sheet
/// Matches FastMinute Signature Brand Red (#E20A22)
class ProximityDeliveryGuardSheet extends StatelessWidget {
  final Address address;
  final double distanceMeters;
  final VoidCallback onContinue;
  final VoidCallback onSwitchLocation;
  final VoidCallback onOrderForSomeoneElse;

  const ProximityDeliveryGuardSheet({
    super.key,
    required this.address,
    required this.distanceMeters,
    required this.onContinue,
    required this.onSwitchLocation,
    required this.onOrderForSomeoneElse,
  });

  static Future<ProximityGuardAction?> show({
    required BuildContext context,
    required Address address,
    required double distanceMeters,
  }) {
    return showModalBottomSheet<ProximityGuardAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProximityDeliveryGuardSheet(
        address: address,
        distanceMeters: distanceMeters,
        onContinue: () => Navigator.pop(ctx, ProximityGuardAction.continueWithAddress),
        onSwitchLocation: () => Navigator.pop(ctx, ProximityGuardAction.switchToCurrentLocation),
        onOrderForSomeoneElse: () => Navigator.pop(ctx, ProximityGuardAction.orderForSomeoneElse),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDist = _formatDistance(distanceMeters);
    final label = address.label.isNotEmpty ? address.label : 'Home';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // City Skyline Vector Illustration with Central FastMinute Red Pin
            SizedBox(
              height: 110,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle Gray City Skyline Silhouette
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 80),
                      painter: _SkylineSilhouettePainter(),
                    ),
                  ),

                  // Central FastMinute Brand Red Map Pin
                  Positioned(
                    top: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 58,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppDesignSystem.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Teardrop Pin Shape rotated -45 deg
                              Transform.rotate(
                                angle: -0.785398, // -45 deg
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFE20A22), Color(0xFFB30013)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      topRight: Radius.circular(24),
                                      bottomLeft: Radius.circular(24),
                                      bottomRight: Radius.circular(0),
                                    ),
                                  ),
                                ),
                              ),
                              // Central White Circle Dot
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Pin Ground Shadow
                        Container(
                          width: 20,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Headline
            Text(
              'Are you ordering at the selected address?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
                letterSpacing: -0.3,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),

            // Address Preview Card with Distance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Home / Office Icon Box
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFEF08A)),
                    ),
                    child: Center(
                      child: Text(
                        label.toLowerCase().contains('work') || label.toLowerCase().contains('office')
                            ? '🏢'
                            : '🏠',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Address Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                '$formattedDist away',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address.fullAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppDesignSystem.slate600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Primary Solid FastMinute Red Button
            Bounceable(
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE20A22), Color(0xFFB30013)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE20A22).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Yes, continue with this address',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Outlined Button
            Bounceable(
              onTap: onSwitchLocation,
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.4),
                ),
                child: Center(
                  child: Text(
                    'No, switch to my current location',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE20A22),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Smart Gifting / Someone Else Link
            Bounceable(
              onTap: onOrderForSomeoneElse,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      'Ordering for someone else? ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate600,
                      ),
                    ),
                    Text(
                      '+ Add Receiver Details',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE20A22),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter drawing a minimal city skyline vector behind the pin
class _SkylineSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Building Blocks
    // Building 1 (Left)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.05, size.height * 0.35, 28, size.height * 0.65), const Radius.circular(3)),
      paint,
    );
    // Building 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.15, size.height * 0.50, 24, size.height * 0.50), const Radius.circular(2)),
      paint,
    );

    // Ferris Wheel in Background
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.45), 26, linePaint);
    canvas.drawLine(Offset(size.width * 0.38, size.height * 0.45), Offset(size.width * 0.38, size.height), linePaint);

    // Building 3 (Right Center)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.58, size.height * 0.25, 32, size.height * 0.75), const Radius.circular(3)),
      paint,
    );
    // Building 4
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.70, size.height * 0.45, 26, size.height * 0.55), const Radius.circular(2)),
      paint,
    );
    // Building 5 (Far Right)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.82, size.height * 0.35, 36, size.height * 0.65), const Radius.circular(3)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
