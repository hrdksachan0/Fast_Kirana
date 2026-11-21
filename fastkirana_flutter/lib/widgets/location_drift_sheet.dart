import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';
import '../core/utils/app_toast.dart';
import '../data/models/address.dart';
import '../core/services/location_service.dart';
import '../providers/address_provider.dart';

/// Bento-Style Location Drift Intelligence Sheet.
/// Presents a clear, high-contrast Bento grid comparison between detected GPS location
/// and currently selected address, with 1-tap switching and zero modal confusion.
class LocationDriftSheet extends StatelessWidget {
  final LocationDetails newGpsDetails;
  final Address? previousAddress;
  final double driftDistanceKm;

  const LocationDriftSheet({
    super.key,
    required this.newGpsDetails,
    required this.previousAddress,
    required this.driftDistanceKm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required LocationDetails newGpsDetails,
    required Address? previousAddress,
    required double driftDistanceKm,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationDriftSheet(
        newGpsDetails: newGpsDetails,
        previousAddress: previousAddress,
        driftDistanceKm: driftDistanceKm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaText = newGpsDetails.area.isNotEmpty ? newGpsDetails.area : newGpsDetails.city;
    final isServiceable = newGpsDetails.isServiceable;
    final prevLabel = previousAddress?.label ?? previousAddress?.area ?? 'Saved Address';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark Executive Slate Bento Foundation
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // ── Bento Hero Header Tile ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF334155), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pulsing Radar Pin Badge
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0x26EF4444),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0x66EF4444), width: 1.2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.radar_rounded,
                      color: Color(0xFFF87171),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0x33EF4444),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x55EF4444)),
                            ),
                            child: Text(
                              'LOCATION MISMATCH',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFCA5A5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '~${driftDistanceKm.toStringAsFixed(1)} km away',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Different Location Detected',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 16.0),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your device GPS is at a different location than selected address "$prevLabel".',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Bento Location Comparison Cards ──
          // 1. Detected Location Card (Live GPS)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isServiceable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isServiceable ? const Color(0x3310B981) : const Color(0x33F59E0B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      color: isServiceable ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'DETECTED GPS LOCATION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w800,
                              color: isServiceable ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          if (isServiceable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x2610B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '⚡ 10-15 Min Zone',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x26F59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Outside Express Zone',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFBBF24),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        areaText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        newGpsDetails.formattedAddress,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 2. Previously Selected Address Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.home_outlined,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAVED ORDER ADDRESS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        prevLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 12.0),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE2E8F0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Active',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Bento Action Button Grid ──
          Consumer(
            builder: (context, ref, _) {
              return Row(
                children: [
                  // Keep Saved Address Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep $prevLabel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFCBD5E1),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Deliver Here (Switch to Detected GPS Location)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        final gpsAddress = Address(
                          id: 'addr_drift_gps_${DateTime.now().millisecondsSinceEpoch}',
                          userId: 'current',
                          label: 'Current Location',
                          houseNo: newGpsDetails.houseNo,
                          street: newGpsDetails.street,
                          area: newGpsDetails.area,
                          city: newGpsDetails.city,
                          pincode: newGpsDetails.pincode,
                          latitude: newGpsDetails.latitude,
                          longitude: newGpsDetails.longitude,
                          isDefault: true,
                        );

                        ref.read(selectedAddressProvider.notifier).state = gpsAddress;
                        Navigator.pop(context, true);

                        AppToast.showSuccess(
                          context,
                          'Delivery Location Switched',
                          subtitle: 'Now delivering to $areaText 📍',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isServiceable ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                        shadowColor: (isServiceable ? const Color(0xFF10B981) : const Color(0xFFE11D48)).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Deliver Here',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 13.0),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
