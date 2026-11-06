import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/address.dart';
import '../../../widgets/address_selector_sheet.dart';

class CheckoutDeliveryAddressCard extends StatefulWidget {
  final Address? selectedAddress;
  final DeliveryTierInfo tier;
  final ValueChanged<Address> onAddressChanged;
  final double? userDistanceMeters;

  const CheckoutDeliveryAddressCard({
    super.key,
    required this.selectedAddress,
    required this.tier,
    required this.onAddressChanged,
    this.userDistanceMeters,
  });

  @override
  State<CheckoutDeliveryAddressCard> createState() => _CheckoutDeliveryAddressCardState();
}

class _CheckoutDeliveryAddressCardState extends State<CheckoutDeliveryAddressCard> {
  bool _isProximityDismissed = false;
  String? _lastAddressId;

  @override
  void didUpdateWidget(covariant CheckoutDeliveryAddressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedAddress?.id != _lastAddressId) {
      _lastAddressId = widget.selectedAddress?.id;
      _isProximityDismissed = false;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} Kms';
    }
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    const slateDark = AppDesignSystem.slate900;
    const slateMuted = AppDesignSystem.slate500;
    final selectedAddress = widget.selectedAddress;
    final tier = widget.tier;

    // Show Zepto-style speech bubble callout ONLY if user is truly far away (> 2.0 km)
    // 533 meters is same neighborhood/walking distance in Ghatampur, so it never triggers!
    final showFarAwayBubble = widget.userDistanceMeters != null &&
        widget.userDistanceMeters! > 2000 &&
        !_isProximityDismissed &&
        selectedAddress != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedAddress == null ? AppDesignSystem.rose300 : AppDesignSystem.slate200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Deliver To Label + Change Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7.5),
                decoration: BoxDecoration(
                  color: selectedAddress == null ? AppDesignSystem.rose50 : AppDesignSystem.orange50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedAddress == null ? AppDesignSystem.rose200 : AppDesignSystem.orange200,
                  ),
                ),
                child: Icon(
                  selectedAddress == null
                      ? Icons.add_location_alt_rounded
                      : (selectedAddress.label.toLowerCase().contains('work')
                          ? Icons.work_rounded
                          : (selectedAddress.label.toLowerCase().contains('current')
                              ? Icons.my_location_rounded
                              : Icons.home_rounded)),
                  size: 17,
                  color: selectedAddress == null ? AppDesignSystem.rose600 : AppDesignSystem.orange600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        () {
                          if (selectedAddress == null ||
                              selectedAddress.label.trim().isEmpty ||
                              selectedAddress.label.trim() == '.') {
                            return 'Select Address';
                          }
                          final clean = selectedAddress.label.replaceAll('📍', '').trim();
                          return clean.isNotEmpty ? clean : 'Delivery Address';
                        }(),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14.5),
                          fontWeight: FontWeight.w900,
                          color: selectedAddress == null ? AppDesignSystem.rose700 : slateDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: slateMuted),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Interactive Change Address Pill
              Bounceable(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await AddressSelectorSheet.show(
                    context,
                    activeAddress: selectedAddress,
                    onAddressSelected: widget.onAddressChanged,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selectedAddress == null ? AppDesignSystem.rose50 : AppDesignSystem.slate100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedAddress == null ? AppDesignSystem.rose300 : AppDesignSystem.slate200,
                      width: 1.1,
                    ),
                  ),
                  child: Text(
                    selectedAddress == null ? 'SELECT' : 'CHANGE',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w800,
                      color: selectedAddress == null ? AppDesignSystem.rose600 : AppDesignSystem.slate700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Full Address Clean Text Line
          Text(
            selectedAddress != null && selectedAddress.fullAddress.isNotEmpty
                ? selectedAddress.fullAddress
                    .replaceAll(RegExp(r'^[.,\s]+'), '')
                    .replaceAll(RegExp(r',\s*,+'), ', ')
                    .trim()
                : 'Please select a delivery address to place your order.',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: selectedAddress == null ? AppDesignSystem.rose600 : AppDesignSystem.slate600,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Row 3: Zepto-Style Far Away Orange Tooltip Callout (Only if > 2.0 km away)
          if (showFarAwayBubble) ...[
            const SizedBox(height: 10),
            // Speech pointer (arrow) pointing up to the address
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: CustomPaint(
                size: const Size(12, 6),
                painter: _SpeechTrianglePainter(color: const Color(0xFFE8590C)),
              ),
            ),
            Bounceable(
              onTap: () async {
                HapticFeedback.selectionClick();
                await AddressSelectorSheet.show(
                  context,
                  activeAddress: selectedAddress,
                  onAddressSelected: widget.onAddressChanged,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8590C), // Exact Zepto warm orange
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8590C).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'You are ${_formatDistance(widget.userDistanceMeters!)} away from this location',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CHANGE',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isProximityDismissed = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Row 4: Distance & Delivery Tier Badge (Subtle Green Pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
            decoration: BoxDecoration(
              color: !tier.isServiceable ? AppDesignSystem.statusCancelled : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: !tier.isServiceable ? AppDesignSystem.rose200 : const Color(0xFFBBF7D0),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  !tier.isServiceable ? Icons.error_outline_rounded : Icons.delivery_dining_rounded,
                  size: 15,
                  color: !tier.isServiceable ? AppDesignSystem.red600 : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    !tier.isServiceable
                        ? (tier.distanceKm > 0.0
                            ? 'Outside 5.0 km Hub (${tier.distanceKm.toStringAsFixed(1)} km) • Delivery Unavailable'
                            : 'Map Location Needed • Tap CHANGE to set location')
                        : '${tier.tierName} (${tier.distanceKm.toStringAsFixed(1)} km) • ${tier.freeDeliveryLabel}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w800,
                      color: !tier.isServiceable ? AppDesignSystem.red600 : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upward triangle pointer for the Zepto-style speech bubble
class _SpeechTrianglePainter extends CustomPainter {
  final Color color;
  _SpeechTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
